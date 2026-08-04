# rowparity — fingerprint-based data parity testing

A Python framework that lets data and QA teams assert **"these two tables are equivalent"** on real, warehouse-sized data — and run those assertions in CI. Teams write declarative YAML; the framework handles engine differences, type normalization, nested types, and scale.

> **FreeWheel, A Comcast Company** 

---

## Use cases

### 1. dbt model regression testing
Compare a dbt model against a blessed golden snapshot on every PR. Keyed on a business key, you get a row-level diff showing exactly which rows changed and which columns differ.

```yaml
name: daily_revenue_matches_golden
expected:
  type: parquet
  path: data/daily_revenue_golden.parquet
actual:
  type: duckdb
  database: warehouse.duckdb
  query: SELECT day, region, revenue, orders FROM daily_revenue
compare:
  keys: [day, region]
  float_tolerance: 0.001
```

### 2. Migration / backward-compatible view (BCV) validation
Prove a migrated data layout (Redshift → Snowflake, Hive → Iceberg, normalized → denormalized) produces identical data at full scale. Row order is irrelevant by design; nested types (`list<struct>`, `map`) are handled correctly.

```yaml
name: orders_bcv_equals_original
engine: trino          # fingerprinting happens entirely inside Trino — no export step
expected:
  type: trino
  table: hive.qa.orders_golden
actual:
  type: trino
  table: hive.analytics.orders_v2
compare:
  float_tolerance: 0.001
```

### 3. Cross-engine data contract validation
One source in Snowflake, the other in Trino, DuckDB, or a Parquet file — only the `type:` block changes, never the assertions.

```yaml
expected:
  type: snowflake
  table: PROD.ANALYTICS.FACT_ORDERS
actual:
  type: trino
  table: hive.analytics.fact_orders
```

### 4. Schema drift detection
Catch when a column is added, dropped, or retyped between two sources — without fetching a single row. Works across any pair of engines.

```yaml
name: orders_schema_unchanged
schema_check:
  expected:
    type: parquet
    path: snapshots/orders_schema.parquet
  actual:
    type: trino
    table: hive.analytics.orders
  ignore_columns: [loaded_at]
```

### 5. N-to-1 remodel / concept check
After a star-schema-to-wide-table remodel, confirm every business concept from the old tables still has a home in the new wide table — even if columns were renamed or relocated.

```yaml
name: gold_wide_concept_check
concept_check:
  sources:
    orders:    {type: snowflake, table: PROD.orders}
    customers: {type: snowflake, table: PROD.customers}
  target:      {type: snowflake, table: PROD.gold_orders_wide}
  concept_map:
    - from: {source: customers, column: id}
      to: customer_id
```

### 6. CI data quality gate
Non-zero exit code on any diff is the entire CI contract. Failures print a human-readable diff inline in Jenkins, GitHub Actions, or any runner.

```
Case 'daily_revenue_matches_golden': [DIFFERENT] keyed on ['day', 'region'] | expected=4 actual=4 | missing=0 added=0 changed=1
  ~ CHANGED key=(2024-01-02, US): revenue: 2100.75 -> 2101.00
Summary: 0/1 equivalent, 1 failing
```

---

## How it works

Every row is reduced to a **canonical fingerprint** — a Blake2b hash of the row's values after type-aware normalization. Two tables are equivalent when their **multisets of fingerprints match**.

- **Row order never matters** — multiset comparison
- **Column order never matters** — columns sorted alphabetically before hashing
- **Type noise doesn't create false diffs** — `int32 ≡ int64`, `1.10 ≡ 1.1`, `09:00 EST ≡ 14:00 UTC`
- **NULL is distinct** — `NULL ≠ "" ≠ 0 ≠ {}`
- **Nested types follow SQL semantics** — `list` ordered, `struct`/`map` unordered by key

---

## Install

```bash
pip install rowparity[duckdb]      # core + DuckDB (sufficient for local CI)
pip install rowparity[all]         # all drivers
```

| Extra | Enables |
|---|---|
| `duckdb` | `duckdb`/`sql`/`parquet`/`csv`/`arrow`/`inline` + `engine: duckdb` |
| `snowflake` | `snowflake` source + `engine: snowflake` |
| `trino` | `trino` source + `engine: trino` |
| `iceberg` | `iceberg` source |
| `delta` | `delta` source |
| `all` | everything above (manage `pyspark` separately for `spark`) |

---

## Source types

| `type` | Reads from | Notes |
|---|---|---|
| `inline` | rows in the YAML | optional `schema:` for exact typing |
| `csv` | `.csv` file | |
| `parquet` | `.parquet` file or glob | preserves nested types |
| `arrow` | `.arrow` / `.feather` file | |
| `duckdb` / `sql` | SQL query against DuckDB | reads parquet/iceberg locally; ideal for CI |
| `snowflake` | SQL query against Snowflake | key-pair auth; creds from `SNOWFLAKE_*` env vars |
| `trino` | SQL query against Trino | creds from `TRINO_*` env vars |
| `iceberg` | pyiceberg table | optional `row_filter` |
| `delta` | Delta Lake table | no JVM needed; time-travel supported |
| `spark` | Spark SQL query | collected via Arrow bridge |

Any source that accepts `query:` also accepts **`query_file: path/to/file.sql`** for large SQL that doesn't belong inline in YAML.

---

## Push-down engines

For large tables, `engine:` pushes fingerprinting entirely into the warehouse — only diff counts and ≤`max_examples` rows ever cross into Python.

| Engine | When to use | Verified at scale |
|---|---|---|
| *(default)* | Up to ~10M rows; any source mix | — |
| `engine: duckdb` | 10M–100M+ rows; DuckDB-reachable sources | 100M rows, ~50s |
| `engine: snowflake` | Tables already in Snowflake | Live warehouse, scalars + nested |
| `engine: trino` | Tables already in Trino | Unit-tested; validate in your cluster |

```yaml
engine: duckdb           # both sources must be DuckDB-reachable
expected:
  type: parquet
  path: data/orders_golden.parquet
actual:
  type: duckdb
  database: warehouse.duckdb
  query: SELECT * FROM orders
```

---

## Compare options

| Option | Default | Meaning |
|---|---|---|
| `keys` | none | keyed diff — missing / added / changed per key |
| `select` | all common | compare only these columns |
| `ignore_columns` | none | drop volatile columns (e.g. `loaded_at`) |
| `float_tolerance` | `0.0` | quantize floats before comparing |
| `coerce_numeric_to_float` | `false` | treat int / decimal / float as one domain |
| `unordered_list_columns` | none | treat these array columns as multisets |
| `trim_strings` | `false` | strip surrounding whitespace |
| `case_insensitive` | `false` | casefold strings |
| `strict_columns` | `false` | fail if column sets or types differ |
| `max_examples` | `20` | example diffs to show |
| `vectorized` | `false` | ~1.2× speed-up on default engine |

---

## CLI

```bash
rowparity run examples/cases --json reports/qa.json --md reports/qa.md
rowparity run examples/cases --result-sink duckdb:./reports/results.duckdb
rowparity report --result-sink duckdb:./reports/results.duckdb --html reports/report.html
rowparity list examples/cases
```

---

## pytest

```python
import pytest
from rowparity import discover_cases, assert_case

@pytest.mark.parametrize("case", discover_cases("cases"), ids=lambda c: c.name)
def test_case(case):
    if "xfail" in case.tags:
        pytest.xfail("expected failure")
    assert_case(case)   # failure message is the full diff
```

See [FEATURES.md §6](FEATURES.md) for the full pytest guide: inline cases, result sinks from pytest, session fixtures, tag-based filtering.

---

## Result sink + HTML dashboard

Persist every run to DuckDB, Snowflake, or Iceberg. Render a self-contained HTML dashboard with pass-rate trend, sparklines, schema-drift history, and row-level drill-down:

```bash
rowparity report --result-sink duckdb:./results.duckdb --html report.html --days 21
```

---

## Worked examples

```bash
pip install -e ".[test]"
python examples/build_example_data.py   # real dbt-duckdb build for Case 01
python examples/build_tpch_data.py      # TPC-H dataset (Cases A–G, no download needed)
rowparity run examples/cases            # 2 pass, 1 xfail
pytest                                  # full suite
```

TPC-H cases A–G cover: keyed regression, column subset, string normalization, nested BCV (`list<struct>`), schema drift detection, inline fixtures, and unordered list columns — all runnable locally with no cloud account.

---

## Cross-engine gotchas handled automatically

| Gotcha | How |
|---|---|
| Row / column order | Multiset + alphabetical column sort |
| `int32` vs `int64` | Same logical value → same fingerprint |
| Decimal vs float | Exact by default; unify with `coerce_numeric_to_float` |
| Float noise | `float_tolerance` quantization grid |
| Timestamp timezones | Normalized to UTC |
| NULL vs empty | `NULL ≠ "" ≠ 0 ≠ {}` — distinct by design |
| Nested order | `list` ordered, `map`/`struct` unordered (configurable per column) |

---

## Developer setup

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

```bash
pip install -e ".[test,dev]"
pre-commit install    # ruff linting + secrets scanning on every commit
make test
```

## Documentation

| | |
|---|---|
| [FEATURES.md](FEATURES.md) | Full reference for every feature, option, and source type |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Developer setup, project layout, adding sources and cases |
| [`ci/Jenkinsfile`](ci/Jenkinsfile) | CI pipeline reference |
