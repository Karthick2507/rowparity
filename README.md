# rowparity — fingerprint-based expected-vs-actual data testing

A small Python framework that lets a QA team assert **"the actual data equals the
expected data"** on real, dbt-sized tables — not toy CSVs — and run those
assertions in CI. QA writes **declarative YAML**, never plumbing code.

It is built for two jobs in particular:

1. **Regression-test a dbt model** — compare the model the pipeline built against
   a blessed snapshot, keyed on a primary/business key, and get a per-row diff.
2. **Prove a backward-compatible view (BCV) reproduces the original data** after
   a migration to a new layout — over complex types (lists, structs, maps),
   **order-independent**, with `list` order preserved but `map`/`struct` key
   order ignored.

## The idea in one paragraph

Every row is reduced to a **canonical fingerprint** (a hash of a normalized form)
and two tables are equivalent when their *multisets* of row fingerprints match.
Because we compare multisets, **row order never matters**. Normalization is
type-aware, so `1.0 == 1`, `1.100 == 1.1` (decimals), tz-aware timestamps compare
as instants, `int32` from one engine equals `int64` from another, and nested
containers follow SQL semantics: **arrays are ordered, maps and structs are
unordered**. `NULL` is its own value and never equals `""` or an empty map.

This is what makes the same case portable across **Snowflake, Spark/Iceberg, and
dbt-duckdb** — the comparison works on Arrow tables, so only the *source* block
changes, never the assertions.

## Install

```bash
pip install -e ".[duckdb]"      # core + local DuckDB engine (great for CI)
pip install -e ".[all]"         # also Snowflake + Iceberg drivers + pytest
```

Heavy drivers are optional extras; install only what your sources use.

## Write a case (YAML)

```yaml
name: daily_revenue_matches_golden
description: dbt model must match the QA-approved snapshot.

expected:                       # where the "known good" data comes from
  type: parquet
  path: ../data/daily_revenue_expected.parquet

actual:                         # what the pipeline just produced
  type: duckdb
  database: ../data/warehouse.duckdb
  query: SELECT day, region, revenue, orders FROM daily_revenue

compare:
  keys: [day, region]           # row-level diff keyed on these columns
  float_tolerance: 0.001        # revenue may carry tiny fp noise
  coerce_numeric_to_float: true # int vs decimal across engines shouldn't diff
```

Point `actual` at Snowflake instead and nothing else changes:

```yaml
actual:
  type: snowflake
  query: SELECT day, region, revenue, orders FROM analytics.daily_revenue
  # credentials from env: SNOWFLAKE_ACCOUNT / _USER / _PASSWORD / _WAREHOUSE / ...
```

Or Iceberg:

```yaml
actual:
  type: iceberg
  table: analytics.daily_revenue
  catalog: prod
  row_filter: "day >= '2024-01-01'"
```

### Keyed vs keyless

- **Give `keys`** when rows have a stable identity — you get *missing / added /
  changed* broken out per key, and for changed rows, exactly which columns differ.
- **Omit `keys`** for a pure multiset comparison ("same set of rows, order aside").
  This is the natural choice for BCV equivalence checks. Duplicates are respected.

## Source types

| `type`      | Reads from                                   | Notes |
|-------------|----------------------------------------------|-------|
| `inline`    | rows written directly in the YAML            | best for small expected fixtures; optional `schema:` for exact typing |
| `csv`       | a `.csv` file                                | |
| `parquet`   | `.parquet` file or glob                      | preserves nested types |
| `arrow`     | `.arrow` / `.feather` file                   | |
| `duckdb` / `sql` | a SQL query against DuckDB              | can read parquet/iceberg locally; ideal for CI |
| `snowflake` | a SQL query against Snowflake                | creds via `connection:` or env vars |
| `iceberg`   | a pyiceberg table (optional `row_filter`)    | |

## Compare options

| Option | Default | Meaning |
|--------|---------|---------|
| `keys` | none | primary/business key → keyed row-level diff |
| `select` | all common | only compare these columns |
| `ignore_columns` | none | drop volatile columns (e.g. `loaded_at`) |
| `float_tolerance` | `0.0` (exact) | quantize floats to this grid before comparing |
| `coerce_numeric_to_float` | `false` | treat int/decimal/float as one numeric domain |
| `unordered_list_columns` | none | compare these array columns as multisets |
| `trim_strings` | `false` | strip surrounding whitespace |
| `case_insensitive` | `false` | casefold strings |
| `strict_columns` | `false` | fail if column sets or logical types differ |
| `max_examples` | `20` | how many example diffs to show |

## Run it

**CLI** (this is what the CI stage calls — non-zero exit on any difference):

```bash
rowparity run examples/cases --json reports/rowparity.json --md reports/rowparity.md
rowparity list examples/cases          # list discovered cases
```

**pytest** (one-line module parametrised over your cases):

```python
import os, pytest
from rowparity.runner import assert_case, load_cases

cases = load_cases(os.environ.get("ROWPARITY_CASES", "cases"))

@pytest.mark.parametrize("case", cases, ids=lambda c: c.name)
def test_case(case):
    assert_case(case)     # failure message is the full diff
```

**Make / nox** (portable entrypoints for Jenkins or any runner):

```bash
make qa          # build data + run cases + write reports/
nox -s qa
nox -s tests
```

**Jenkins**: see [`ci/Jenkinsfile`](ci/Jenkinsfile) — builds the pipeline, runs
the cases, archives the diff reports, fails the build on any difference.

## What a caught regression looks like

```
Case 'orders_bcv_broken_is_detected': [DIFFERENT] keyed on ['order_id'] | expected=3 actual=3 | missing=0 added=0 changed=3
  ~ CHANGED key=(1): total: Decimal('31.98') -> Decimal('30.98')
  ~ CHANGED key=(3): items: [{'sku':'D','qty':1},{'sku':'E','qty':3},{'sku':'F','qty':2}]
                          -> [{'sku':'E','qty':3},{'sku':'D','qty':1},{'sku':'F','qty':2}], total: 72.25 -> 71.25
```

## Worked examples

Run them end to end:

```bash
pip install -e ".[test]"
python examples/build_example_data.py     # runs a real dbt-duckdb build for Case 01; the migration/BCV cases use a lightweight non-dbt stand-in
rowparity run examples/cases               # 2 pass, 1 (broken-view demo) fails on purpose
pytest                                     # the broken-view case is tagged xfail
```

- `examples/cases/01_dbt_model_revenue.yaml` — keyed dbt-model regression.
- `examples/cases/02_backward_compatible_view.yaml` — BCV equals original over
  `list<struct>` + `map`, order-independent.
- `examples/cases/03_broken_view_demo.yaml` — the same check on a broken view, to
  show the diff output (expected to fail).

## Cross-engine gotchas the framework already handles

These are the false-positives that bite hand-rolled comparisons; each is covered
by a unit test in `tests/test_engine.py`:

- **Row & column order** — neutralized by design.
- **Physical type width** — `int32`/`int64`, `string`/`large_string` compare by value.
- **Decimal vs float vs int** — exact by default; unify with `coerce_numeric_to_float`.
- **Float noise** — `float_tolerance` quantization.
- **Timestamp timezones** — normalized to UTC (same instant compares equal).
- **NULL vs empty** — `NULL` ≠ `""` ≠ empty map; kept distinct on purpose.
- **Nested order semantics** — arrays ordered, maps/structs unordered (configurable per column).

## Scaling notes

The engine materializes rows to hash them, which is fine for the "small but big
enough to run through dbt" tables this is built for (tens of thousands to low
millions of rows). For very large tables, push the heavy lifting into SQL first:
filter/aggregate in the `query`, sample deterministically (e.g. `WHERE
abs(hash(id)) % 100 = 0`) for the fast PR gate, and reserve full-table runs for a
nightly job. The keyed mode also lets you shard by key range across parallel CI
workers.
