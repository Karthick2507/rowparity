# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Idea

**rowparity** is a fingerprint-based expected-vs-actual data testing framework for dbt pipelines and data migrations. It lets QA teams assert "actual data equals expected data" on real warehouse-sized tables and run those assertions in CI. QA writes declarative YAML — no plumbing code.

**Two primary use cases:**
1. **dbt regression testing** — compare a model against a blessed snapshot, keyed on a business key, showing per-row diffs
2. **Backward-compatible view (BCV) validation** — prove a migrated data layout reproduces the original data after schema changes, with order-independent comparison of nested types

**Core innovation:** Every row is reduced to a canonical Blake2b fingerprint. Two tables are equivalent when their multisets of row fingerprints match — making row order irrelevant by design. Type-aware canonicalization handles cross-engine differences (int32 vs int64, trailing zeros in decimals, timezone normalization, float quantization).

## Dev Commands

```bash
# Install for development
pip install -e ".[duckdb]"      # Core + DuckDB (typical CI setup)
pip install -e ".[all]"         # All optional drivers

make install    # pip install -e ".[test,dev]" + pre-commit install (activates the secrets-scanning git hook)
make data       # Build example DuckDB warehouse + Parquet fixtures (runs a real dbt-duckdb build for Case 01, see examples/dbt_project)
make test       # Run pytest with JUnit XML output
make qa         # Run YAML cases and write reports/ directory
make clean      # Remove artifacts

# Nox sessions
nox -s tests    # Unit + example test suite
nox -s qa       # YAML case runner, writes reports/

# Run a single test
pytest tests/test_engine.py::test_order_independent -xvs
pytest tests/test_examples.py -k "revenue" -xvs

# CLI
rowparity run examples/cases --json reports/rowparity.json --md reports/rowparity.md
rowparity list examples/cases
rowparity report --result-sink duckdb:./reports/results.duckdb --html reports/report.html

# Second CLI entry point (pyproject [project.scripts]) — column coverage mapping only
schemaparity coverage examples/cases --json reports/coverage.json --csv reports/coverage.csv
schemaparity list examples/cases

# TPC-H example warehouse for the FEATURES.md worked examples (Cases A–G, examples/cases/tpch/)
python examples/build_tpch_data.py
```

## Pre-commit hooks

`.pre-commit-config.yaml` (activated by `make install`, or manually via `pre-commit install`) blocks commits containing private keys (`detect-private-key`) or likely secrets — API keys, tokens, passwords (`detect-secrets`, baseline in `.secrets.baseline`). This exists because Snowflake key-pair auth work in this repo has repeatedly involved local files (`.env.snowflake`, `~/.snowflake/*.p8`) that must never reach git — `.gitignore` covers the expected locations, the hook is defense in depth for anything that slips through (e.g. a new file that does not match an existing ignore pattern).

If `detect-secrets` flags a real false positive (not an actual secret), do not just delete the finding — either rework the code so it does not look like a secret, or mark the specific line with a trailing `# pragma: allowlist secret` comment and re-run `detect-secrets scan --baseline .secrets.baseline` to update the baseline. Never widen `.pre-commit-config.yaml`'s exclusions to work around a real finding without understanding why it fired first.

## Architecture

All data flows through **PyArrow Tables** — the framework is engine-agnostic by design.

```
YAML Case
  └─► sources.py       # Loads expected/actual → pyarrow.Table
        └─► hashing.py # canon_value() → canon_row() → row_digest() (Blake2b)
              └─► compare.py  # Keyed or keyless multiset comparison → ComparisonResult
                    └─► report.py   # Console / JSON / Markdown output
                    └─► runner.py   # pytest assert_case() or CLI exit code
```

**`src/rowparity/` module layout:**
- `cases.py` — YAML case loading and `assert_case()` dispatch; also picks the execution engine (`engine: duckdb` → `duckdb_pushdown.py`, `engine: snowflake` → `snowflake_pushdown.py`, `engine: trino` → `trino_pushdown.py`, instead of `compare.py`). `_build_case()` also dispatches by case *shape*: `schema_check` in the YAML → `SchemaCheckCase`, `concept_check` → `ConceptCheckCase`, otherwise the normal `expected`/`actual` `Case`. **`coverage_check` is deliberately not handled here** — those cases only load through `schema_mapper.load_coverage_cases()`/the `schemaparity` CLI, so a `coverage_check` YAML sitting in a directory that `rowparity run` scans raises "missing required field 'expected'". Keep coverage cases in their own directory.
- `sources.py` — Eleven pluggable source handlers; all return `pyarrow.Table`; heavy drivers (snowflake, trino, iceberg, delta, spark) use lazy imports. `snowflake` connects via `snowflake_auth.py` (key-pair auth only), `trino` via `trino_auth.py`. Any query-based source also accepts `query_file:` (a `.sql` path resolved relative to the case YAML) as an alternative to inline `query:` — `sources.resolve_query()`; `query:` wins if both are present.
- `hashing.py` — Canonicalization rules and fingerprinting; the type-aware comparison semantics live here
- `compare.py` — `keyed_compare()` (match on business key → missing/added/changed) and `keyless_compare()` (multiset diff)
- `duckdb_pushdown.py` — SQL push-down comparison (Stage A): canonicalizes and fingerprints entirely inside DuckDB instead of materializing to Python, for tables too large for the default engine (verified at 100M rows/side). Same `ComparisonResult` output as `compare.py`. Full type parity with the default engine — bool/int/float/decimal/string/timestamp/date/time, plus recursive list (ordered)/struct (unordered by field name)/map (unordered by key, sorted at runtime since map keys are data not schema) via `_canon_expr`, arbitrarily nested — only blob and exact (non-tolerance) float comparison aren't covered. Uses `con.sql(...).types` (structured `DuckDBPyType`, not `DESCRIBE`'s flat string) so nested-type recursion has real `.id`/`.children` to walk. Source types must be DuckDB-reachable (`duckdb`/`sql`/`parquet`/`csv`/`inline`) — Snowflake/Spark/Iceberg/Delta sources need exporting to Parquet first, not a bespoke SQL dialect per engine.
- `snowflake_auth.py` — the single connection-builder for every Snowflake touchpoint (`sources.py`'s `snowflake` source, `schema_introspect.py`'s Snowflake describe, `snowflake_pushdown.py`, `history.py`'s `_read_snowflake`, `result_sink.py`'s `SnowflakeResultSink`). **Key-pair auth only — password auth isn't supported anywhere in the codebase.** Private key comes from `SNOWFLAKE_PRIVATE_KEY_PATH` (file path), `SNOWFLAKE_PRIVATE_KEY` (raw PEM text, e.g. a CI secret), or a per-case `connection.private_key_path` override, with an optional `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` if the key is encrypted; never accepted as inline key material in YAML. (`history.py`/`result_sink.py`'s Snowflake connections were missed in the original migration — found via a `detect-secrets` pre-commit scan flagging their leftover `SNOWFLAKE_PASSWORD` env-var mapping, fixed to route through this module too.)
- `snowflake_pushdown.py` — SQL push-down comparison natively in Snowflake, mirroring `duckdb_pushdown.py` function-for-function (dialect differs, approach doesn't): canonicalizes and fingerprints entirely in-warehouse via `cursor.describe()` (schema-only) + `MD5()`/`COUNT_IF`/`ARRAY_AGG(OBJECT_CONSTRUCT(...))`. Scalars (bool/int/decimal/float/string/date/time/timestamp) use static, Python-side type dispatch off `cursor.describe()`, same as DuckDB push-down — **verified against a live warehouse** (keyed compare, one deliberate diff, correctly detected). **Semi-structured types (`ARRAY`/`OBJECT`/`MAP`/`VARIANT`) use a different mechanism: a single recursive JavaScript UDF** (`_ensure_variant_udf()`, created lazily via `CREATE FUNCTION IF NOT EXISTS` — needs that privilege granted, only paid when a case actually has a semi-structured column in scope), not more SQL. Two reasons: (1) `cursor.describe()` exposes no field/element schema for these, same reasoning as before; (2) **a pure-SQL design (TYPEOF()/TABLE(FLATTEN(...)) inlined in a scalar subquery) was tried first and found live to be fundamentally broken** — Snowflake doesn't support a correlated table function nested inside an arbitrary scalar subquery in a SELECT list, confirmed with even the simplest single flat ARRAY column ("Unsupported subquery type cannot be evaluated"). The UDF sidesteps this entirely and handles arbitrary depth natively (no size-doubling-per-level concern the SQL version had). `OBJECT` and Snowflake's distinct `MAP` type canonicalize identically (sorted by key) since neither exposes whether it's "really" a struct or a map. `float_tolerance > 0` is required as soon as any compared column is semi-structured, even if its values never contain a nested float. **Verified against a live warehouse**: flat `ARRAY`, flat `OBJECT`, and `ARRAY<OBJECT>` (2-level nesting) all correctly detected a deliberate diff with no false positives on unchanged columns. One specific detail remains unverified: whether Snowflake's VARIANT→JS marshalling hands a nested DATE/TIME/TIMESTAMP value to the UDF as a native JS `Date` (handled via `instanceof Date`) — not yet exercised by the live test data. Source type must be `snowflake` on both sides — no local-file federation like DuckDB push-down has via `read_parquet()`.
- `trino_auth.py` — the single connection-builder for every Trino touchpoint (`sources.py`'s `trino` source, `trino_pushdown.py`). Env vars `TRINO_HOST` (required), `TRINO_PORT` (8080), `TRINO_USER` (OS user), `TRINO_CATALOG`, `TRINO_SCHEMA`, `TRINO_HTTP_SCHEME` (`http`), with a per-case `connection:` block overriding any of them. Three auth modes: none (open dev/test clusters, the default), Basic (`TRINO_PASSWORD`), JWT (`TRINO_JWT_TOKEN`). No key-pair flow — that's a Snowflake-only concern.
- `trino_pushdown.py` — SQL push-down comparison natively in Trino, mirroring `duckdb_pushdown.py`/`snowflake_pushdown.py` function-for-function. Schema comes from a `LIMIT 0` probe, then **everything dispatches statically in Python**, DuckDB-style — including nested types, because Trino's `LIMIT 0` cursor description gives real `array(...)`/`map(...)`/`row(...)` type strings that get parsed and recursed over (this is why Trino needed no UDF, unlike Snowflake). Nested rules: `transform(arr, x -> ...)` for arrays (`array_sort` for `unordered_list_columns`), dot-notation `expr."field"` for `row`/struct with fields sorted at SQL-build time, `map_entries()` + `transform` + runtime sort for maps. Dialect notes: `to_hex(md5(to_utf8(...)))` (Trino's `md5()` returns VARBINARY), `array_join(ARRAY[...], sep, null_replacement)` instead of `concat_ws`, `arbitrary()` instead of `any_value`/`ANY_VALUE`. `float_tolerance > 0` required for `real`/`double`. `varbinary`/`json`/geo/HLL/IP raise a clear error. Both sides must be `type: trino` on one connection; differing `host:` raises. **Not yet verified against a live cluster** — unit-tested with a fake cursor driver, same approach as `test_snowflake_pushdown.py`.
- `schema_check.py` — a case type that asks only "do these two sources agree on column names and types?", with **zero rows fetched** (all through `schema_introspect.py`). YAML `schema_check:` block (sibling to `expected`/`actual`, mutually exclusive with them and with `concept_check`) holds its own `expected:`/`actual:` source specs plus optional `ignore_columns:`. Returns a `ComparisonResult` with `expected_rows`/`actual_rows` always `0`, so report/result_sink/history/HTML all work unchanged. Distinct from `strict_columns: true`, which is a *row* comparison that additionally fails on schema drift.
- `schema_mapper.py` + `coverage_cli.py` — **column coverage mapping**, exposed as a separate `schemaparity` CLI (`schemaparity coverage <path> [--json] [--csv]`, `schemaparity list <path>`), not `rowparity`, because it's a schema/lineage concern rather than a row-parity one. A `coverage_check:` YAML block names the columns a downstream consumer uses (`usage_columns:` inline or `usage_file:` one-per-line text with `#` comments — mutually exclusive) plus one `source:` (any `schema_introspect` type) and an optional `schema_file:` CSV (`column_name,type,description`) whose type/description **override** what the live source reports. Produces `CoverageResult` (`mapped` list of `MappedColumn(usage_name, source_name, source_type, description)`, `unmapped_usage`, `unreferenced_source`); matching is case-insensitive, source casing preserved in output. Exit codes: `0` full coverage, `1` gaps, `2` no cases. Note this path does *not* produce a `ComparisonResult`, so result sink / `rowparity report` history do not cover it.
- `runner.py` — pytest parametrization helpers
- `cli.py` — `rowparity run / list / report` CLI entry points
- `report.py` — Console, JSON, Markdown reporters (single run); also renders `change_signatures` — changed rows (keyed mode) grouped by *which columns differ*, so thousands of changed rows collapse into a handful of patterns instead of a flat example list. Computed in `compare.py` for the default engine (exact, full-table); push-down's version reflects only the fetched example rows (approximation, see TODO)
- `result_sink.py` — persists every run's summary + diff examples to DuckDB/Snowflake/Iceberg (`rowparity run --result-sink duckdb:./results.duckdb`), across `run_id`s over time. `write()` takes an optional `run_ts` override (used for building historical test data; defaults to now).
- `schema_introspect.py` — column name/type for any source spec (all ten `type`s), *without ever materializing a row*: `DESCRIBE (query)` for duckdb, `cursor.describe(sql)` for Snowflake (the connector's own no-execute API), lazy `.schema` for Spark, native table metadata for Iceberg/Delta, Parquet/Arrow file footers only, CSV samples only the first block. Deliberately not a `LIMIT 0` SELECT a case author could forget to add — every path here is structurally incapable of scanning real data (verified: 4ms to introspect a 50M-row DuckDB table). Consumed by `concept_check.py`, `schema_check.py`, and `schema_mapper.py`. **No `trino` describer exists yet** — `_DESCRIBERS` covers duckdb/sql, snowflake, spark, iceberg, delta, parquet, arrow/feather, csv, inline only, so a `type: trino` source in a `schema_check:`/`coverage_check:`/`concept_check:` block raises (FEATURES.md §13/§14 claim otherwise — see TODO).
- `concept_check.py` — a case type for a many-source-to-one-target schema remodel (N old tables collapsing into one wide table), where "drift" means *a business concept has no home in the new table anymore*, not "columns don't match exactly." A YAML `concept_check:` block (sibling to `expected`/`actual`, mutually exclusive with them) names N `sources:`, one `target:`, and an *optional* `concept_map:` for columns that were renamed/relocated — anything not renamed needs no map entry (falls back to same-name matching). Produces a `ComparisonResult` (lost concepts → `columns_only_in_expected`, unaccounted new columns → `columns_only_in_actual`, incompatible types → `type_mismatches`), so `report.py`/`result_sink.py`/`history.py`/the HTML report all work unchanged. `ConceptCheckCase` is duck-type compatible with `cases.Case` (`.name`/`.tags`/`.run(...)`), dispatched in `cases._build_case()` by the presence of `concept_check` in the YAML.
- `history.py` + `report_html.py` + `templates/report.html` — `rowparity report --result-sink ... --html out.html`: reads a result sink's history back out (DuckDB/Snowflake only — Iceberg reading isn't wired up, see TODO), reshapes it to one point per case per calendar day (latest run wins if there were several), derives `change_signatures` from the persisted diffs, and renders a single self-contained HTML page — pass-rate trend, per-case ledger with sparklines, schema-drift history (name *and* type drift, tracked separately per side), and a row-level drill-down. `report_html.py` does plain string-substitution templating (`__ROWPARITY_*__` placeholders in the shipped `templates/report.html`) — no templating engine dependency. Injected JSON is escaped for `</script` so arbitrary diff-value text can't break out of the inline script block.

## Source Types

| Type | When to use |
|------|-------------|
| `inline` | Small expected fixtures in YAML |
| `csv` | Flat CSV files |
| `parquet` | Nested data, glob patterns |
| `arrow` | `.arrow` / `.feather` files |
| `duckdb` / `sql` | Local query engine; ideal for CI; can read parquet/iceberg |
| `snowflake` | Cloud warehouse (key-pair auth via env vars, see `snowflake_auth.py`); large-table comparisons should use `engine: snowflake` instead of this source directly (see Scale Limits) |
| `trino` | Trino cluster query (env vars / `connection:` via `trino_auth.py`); like `snowflake`, materializes to the client — use `engine: trino` for large tables |
| `iceberg` | Iceberg tables with optional row filtering |
| `delta` | Delta Lake / Unity Catalog tables; no Spark/JVM needed; supports time-travel |
| `spark` | Spark SQL query collected to Arrow via PySpark Arrow bridge |

## Canonicalization Semantics (hashing.py)

Key invariants to preserve when modifying:
- Row order: irrelevant (multiset comparison)
- Column order: irrelevant (sorted by name before hashing)
- `list`/`array`: **ORDERED** (sequences)
- `struct` and `map`: **UNORDERED** (keys sorted before hashing)
- Floats: quantized to tolerance grid
- Decimals: trailing zeros stripped (`1.10 ≡ 1.1`)
- Timestamps: normalized to UTC
- NULL: distinct (`NULL ≠ "" ≠ {}`)
- Numeric widths: `int32` from one engine equals `int64` from another

## YAML Case Format

```yaml
name: daily_revenue_matches_golden
engine: duckdb                  # optional; one of duckdb | snowflake | trino | python (or omit
                                 # for the default Python engine, compare.py).
                                 # duckdb → duckdb_pushdown.py; needs DuckDB-reachable sources
                                 # (duckdb/sql/parquet/csv/inline); type coverage matches the
                                 # default engine except blob and exact (non-tolerance) float.
                                 # snowflake/trino → both sides must be that source type.
expected:
  type: parquet
  path: ../data/daily_revenue_expected.parquet
actual:
  type: duckdb
  database: warehouse.duckdb
  query: SELECT day, region, revenue, orders FROM daily_revenue
  # query_file: sqls/daily_revenue.sql   # alternative to query:, path relative to this YAML
compare:
  keys: [day, region]           # Omit for keyless/multiset mode
  ignore_columns: [loaded_at]   # Volatile columns to drop
  float_tolerance: 0.001
  coerce_numeric_to_float: true
  unordered_list_columns: [tags]
  strict_columns: false
  max_examples: 20
  vectorized: true               # canonicalize whole columns at once (~1.2x); opt-in, same results
tags: [xfail]                   # Mark expected failures
```

### Case shapes

A YAML case is exactly one of four shapes, distinguished by which top-level block it has:

| Top-level block | Loaded by | Compares | Fetches rows? |
|---|---|---|---|
| `expected:` + `actual:` | `rowparity run/list`, pytest | Row data | Yes |
| `concept_check:` | `rowparity run/list`, pytest | N old tables' concepts → one wide table | No |
| `schema_check:` | `rowparity run/list`, pytest | Column names + types of two sources | No |
| `coverage_check:` | **`schemaparity` only** | Consumer usage columns → one source table | No |

The first three all yield a `ComparisonResult` and flow through report/result-sink/history unchanged. `coverage_check` does not, and `rowparity run` will *error* on such a file (see `cases.py` note above).

## Testing Patterns

`tests/test_engine.py` — 50+ unit tests for comparison semantics; parametrized by scenario. Add new semantic edge cases here.

`tests/test_examples.py` — End-to-end tests over the YAML example cases. A session fixture builds example data once (`make data`). `xfail`-tagged cases are expected to fail.

pytest parametrization pattern used throughout:
```python
@pytest.mark.parametrize("case", load_cases("cases"), ids=lambda c: c.name)
def test_case(case):
    assert_case(case)
```

## CI (Jenkins)

`ci/Jenkinsfile` runs: install → dbt build / migration → `rowparity run` (exits non-zero on diffs) → archive JSON + Markdown reports. The example project's own "build" step (`examples/build_example_data.py`) now runs a real `dbt build` for Case 01 (`examples/dbt_project`, dbt-duckdb adapter) — a real point of reference for what the "dbt build" stage looks like, not just a description of what a real user's pipeline would do.

Snowflake env vars (key-pair auth only — see `snowflake_auth.py`, no password support): `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_SCHEMA`, `SNOWFLAKE_PRIVATE_KEY_PATH` (or `SNOWFLAKE_PRIVATE_KEY` for raw PEM content), `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` (optional, if the key is encrypted).

## Scale Limits

The default engine (`compare.py`, no `engine:` set) materializes rows to hash them — suitable for tens of thousands to low millions of rows. For larger tables, use `engine: duckdb` (`duckdb_pushdown.py`) instead — canonicalizes and fingerprints entirely inside DuckDB, verified at 100M rows/side. Needs DuckDB-reachable sources (`duckdb`/`sql`/`parquet`/`csv`/`inline`); type coverage matches the default engine (including nested list/struct/map, recursively) except blob and exact (non-tolerance) float. For tables that already live natively in Snowflake — no export-to-Parquet step wanted — `engine: snowflake` (`snowflake_pushdown.py`) canonicalizes and fingerprints entirely in-warehouse instead; both `expected`/`actual` must be `type: snowflake`. Covers scalars (bool/int/decimal/float/string/date/time/timestamp) via static schema dispatch, plus semi-structured types (ARRAY/OBJECT/MAP/VARIANT) via a recursive JavaScript UDF (needs `CREATE FUNCTION` granted) — see the module docstring for why nested types needed a UDF rather than more SQL. **Verified against a live warehouse** for both paths (see the module's docstring/CLAUDE.md TODO for the one remaining unverified detail: nested temporal values inside a VARIANT). Same story for Trino — `engine: trino` (`trino_pushdown.py`) fingerprints in-cluster with both sides `type: trino`, covering scalars *and* nested array/map/row via static schema dispatch off a `LIMIT 0` probe (no UDF needed, unlike Snowflake), `float_tolerance > 0` required for `real`/`double`; **not yet run against a live cluster**, only fake-cursor unit tests. If none of these fit: push filtering into SQL first, use sampling (`WHERE abs(hash(id)) % 100 = 0`), or shard by key across parallel CI workers.

## TODO / Deferred

- **Iceberg push-down source** (`type: iceberg` → DuckDB's native `iceberg_scan()`, not the existing `pyiceberg`-based `sources.py` handler, which materializes to Python and isn't push-down). Deferred: the current hourly (Spark) vs. daily (Snowflake) aggregate reconciliation is small enough to just use the default engine directly against live `snowflake`/`spark` sources — no push-down needed there. Revisit if that comparison stops being small-data, or for the separate migration-playbook (large-table) use case. Two viable approaches already scoped if/when this comes up: (a) DuckDB's catalog-less `iceberg_scan('s3://.../table')` reading a table's storage location directly — works regardless of which engine wrote it, but requires the Snowflake side to actually be a **Snowflake Iceberg External Table** (data in a customer-owned external volume), not a native Snowflake table, which it currently is; (b) a Parquet-landing convenience layer (`COPY INTO` / `df.write.parquet` helpers) for Snowflake/Spark sources generally. Going through Snowflake's own Horizon REST catalog from DuckDB has open limitations as of mid-2026 (see [duckdb/duckdb-iceberg#977](https://github.com/duckdb/duckdb-iceberg/issues/977)) — the direct-storage read is the more robust option.
- **`schema_introspect.py` has no `trino` describer** — but FEATURES.md §13 (Schema Check) and §14 (Coverage Mapping) both list `trino` as a supported source with a "`LIMIT 0` query (schema probe, fast)" mechanism, and §13's headline YAML example compares a Snowflake table against `type: trino`. That case raises today. `trino_pushdown.py` already does exactly this probe for its own schema resolution, so the fix is to factor that out into a `_describe_trino` and register it in `_DESCRIBERS` — until then, treat the docs as aspirational here.
- **`trino_pushdown.py` is unverified against a live cluster** — complete and unit-tested against a fake cursor driver (`tests/test_trino_pushdown.py`, same approach as `test_snowflake_pushdown.py`), but never exercised end-to-end. Deferred by decision, not overlooked: live verification is planned for later, on a real cluster. When that happens, mirror the Snowflake live-testing pass — a scratch schema, one deliberate diff, keyed and keyless, scalars first and then a nested `array`/`map`/`row` column. The Snowflake push-down history is the cautionary tale: two real bugs there were only found by running against a live warehouse, and both were things no fake-cursor test could have caught (server-side static type checking, unsupported correlated table functions). Assume the same class of surprise is still latent here.
- **`schema_mapper.py` / `coverage_cli.py` have no tests** — every other module has a `tests/test_*.py`; the coverage-mapping path (added in `50fc8e0`) has none, and there is no example `coverage_check:` YAML under `examples/` either. Worth adding both before relying on it.
- **`coverage_check` cases break `rowparity run`** if they live in a scanned directory — `cases._build_case()` doesn't know the shape, so it falls through to the `expected`/`actual` required-field check and raises. Either teach `_build_case` to skip/handle it, or keep coverage YAML in a separate directory tree.
- **`duckdb_pushdown.py` perf**: fingerprints are currently computed twice when there are diffs (once for counts, once for the bounded example fetch) — a `MATERIALIZED` CTE was tried to avoid this and OOM'd at 100M rows (see module history), so this needs a different approach (e.g. a real temp table) if it's worth pursuing.
- **`change_signatures`** in `duckdb_pushdown.py` results only reflect the fetched example rows, not a full-table breakdown (unlike `compare.py`'s `change_signatures`, which is exact). Pushing the signature grouping into SQL would close this gap.
- **`rowparity report` doesn't read Iceberg result sinks** — `history.py` supports DuckDB and Snowflake only (`IcebergResultSink` remains write-only). Add an Iceberg reader (via pyiceberg `.scan().to_arrow()`) if Iceberg becomes the primary result-sink backend for a real deployment.
- **`rowparity report`'s diff drill-down only shows column-level "changed" diffs**, not missing/added row examples (those are reflected in the per-day counts, not the row-level table) — a reasonable first cut, not a hard limitation; extending the table to show missing/added key values would need its own layout since they don't have an old/new column pair.
- **`concept_check.py` results print as "keyless (multiset)"** in `report.py`'s console output — cosmetic only (`ComparisonResult.summary()` hardcodes that label whenever `keys` is `None`, which concept_check always is); not worth touching shared code in `compare.py` for a wording nit, but worth fixing if it causes real confusion.
- **`snowflake_pushdown.py` scalar path and semi-structured (UDF) path are both verified against a live warehouse** (XSMALL warehouse, `ROWPARITY_TEST` scratch database): keyed compare correctly detected a deliberate diff for scalars, and separately for flat `ARRAY`, flat `OBJECT`, and `ARRAY<OBJECT>` (2-level nesting) with no false positives on unchanged columns. Two bugs were found and fixed in the process (see git history around this): (1) Snowflake statically type-checks a scalar cast like `expr::BOOLEAN` against the expression's *declared* type even inside a never-taken `CASE` branch, which broke an earlier all-SQL design for `ARRAY`/`OBJECT`/`MAP` columns; (2) a correlated table function (`FLATTEN`) nested inside an arbitrary scalar subquery isn't supported by Snowflake at all, which is what motivated the JS UDF redesign in the first place — see the module docstring for the full story.
- **`snowflake_pushdown.py` one remaining unverified detail**: whether Snowflake's VARIANT→JS marshalling hands a nested `DATE`/`TIME`/`TIMESTAMP` value to the UDF as a native JS `Date` object (the UDF handles this via `instanceof Date`) or as something else — documented Snowflake behavior for top-level `DATE`/`TIMESTAMP` UDF arguments, unconfirmed for values nested inside a passed-in `VARIANT`. The live test data (`scripts/build_snowflake_test_data.py`) doesn't currently include a nested temporal value; add one and re-run `examples/cases_snowflake_live/nested_push_down.yaml` to close this gap.
- **`snowflake_pushdown.py` nested-numeric simplification**: `DECIMAL`/`DOUBLE` values nested inside a semi-structured column always go through the tolerance-quantized float path in the UDF — no "wider of both sides" scale matching the top-level `decimal` category gets, since there's no static schema for a nested decimal's scale.
- **`snowflake_pushdown.py` UDF vectorization**: `_ensure_variant_udf()`'s canonicalizer is a scalar JS UDF — one function invocation per row per semi-structured column, which is real, uncharacterized per-row overhead (JS UDF calls aren't vectorized the way native SQL operations are; only verified correct on 2-row test data so far, never benchmarked at scale). If profiling at a realistic row count shows this is a bottleneck, prefer a Snowflake **vectorized Python UDF** (batches many rows per call via pandas) over resurrecting the `LATERAL FLATTEN`+join pure-SQL rewrite that was set aside earlier — same shape as the current UDF (one function, same recursive logic), just batched. Considered and rejected as a simpler fix: hashing the raw semi-structured value directly (`MD5(TO_VARCHAR(col))`) instead of canonicalizing first — doesn't work in general, since it skips float_tolerance/decimal/trim_strings/case_insensitive normalization entirely (though Snowflake's `OBJECT` key serialization is likely already deterministic, which would solve field-order-independence for free if verified — just not the tolerance/normalization half of the problem).