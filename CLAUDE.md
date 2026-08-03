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
- `cases.py` — YAML case loading and `assert_case()` dispatch; also picks the execution engine (`engine: duckdb` routes to `duckdb_pushdown.py`, `engine: snowflake` routes to `snowflake_pushdown.py`, instead of `compare.py`)
- `sources.py` — Ten pluggable source handlers; all return `pyarrow.Table`; heavy drivers (snowflake, iceberg, delta, spark) use lazy imports. `snowflake` connects via `snowflake_auth.py` (key-pair auth only).
- `hashing.py` — Canonicalization rules and fingerprinting; the type-aware comparison semantics live here
- `compare.py` — `keyed_compare()` (match on business key → missing/added/changed) and `keyless_compare()` (multiset diff)
- `duckdb_pushdown.py` — SQL push-down comparison (Stage A): canonicalizes and fingerprints entirely inside DuckDB instead of materializing to Python, for tables too large for the default engine (verified at 100M rows/side). Same `ComparisonResult` output as `compare.py`. Full type parity with the default engine — bool/int/float/decimal/string/timestamp/date/time, plus recursive list (ordered)/struct (unordered by field name)/map (unordered by key, sorted at runtime since map keys are data not schema) via `_canon_expr`, arbitrarily nested — only blob and exact (non-tolerance) float comparison aren't covered. Uses `con.sql(...).types` (structured `DuckDBPyType`, not `DESCRIBE`'s flat string) so nested-type recursion has real `.id`/`.children` to walk. Source types must be DuckDB-reachable (`duckdb`/`sql`/`parquet`/`csv`/`inline`) — Snowflake/Spark/Iceberg/Delta sources need exporting to Parquet first, not a bespoke SQL dialect per engine.
- `snowflake_auth.py` — the single connection-builder for every Snowflake touchpoint (`sources.py`'s `snowflake` source, `schema_introspect.py`'s Snowflake describe, `snowflake_pushdown.py`, `history.py`'s `_read_snowflake`, `result_sink.py`'s `SnowflakeResultSink`). **Key-pair auth only — password auth isn't supported anywhere in the codebase.** Private key comes from `SNOWFLAKE_PRIVATE_KEY_PATH` (file path), `SNOWFLAKE_PRIVATE_KEY` (raw PEM text, e.g. a CI secret), or a per-case `connection.private_key_path` override, with an optional `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` if the key is encrypted; never accepted as inline key material in YAML. (`history.py`/`result_sink.py`'s Snowflake connections were missed in the original migration — found via a `detect-secrets` pre-commit scan flagging their leftover `SNOWFLAKE_PASSWORD` env-var mapping, fixed to route through this module too.)
- `snowflake_pushdown.py` — SQL push-down comparison natively in Snowflake, mirroring `duckdb_pushdown.py` function-for-function (dialect differs, approach doesn't): canonicalizes and fingerprints entirely in-warehouse via `cursor.describe()` (schema-only) + `MD5()`/`COUNT_IF`/`ARRAY_AGG(OBJECT_CONSTRUCT(...))`. Scalars (bool/int/decimal/float/string/date/time/timestamp) use static, Python-side type dispatch off `cursor.describe()`, same as DuckDB push-down — **verified against a live warehouse** (keyed compare, one deliberate diff, correctly detected). **Semi-structured types (`ARRAY`/`OBJECT`/`MAP`/`VARIANT`) use a different mechanism: a single recursive JavaScript UDF** (`_ensure_variant_udf()`, created lazily via `CREATE FUNCTION IF NOT EXISTS` — needs that privilege granted, only paid when a case actually has a semi-structured column in scope), not more SQL. Two reasons: (1) `cursor.describe()` exposes no field/element schema for these, same reasoning as before; (2) **a pure-SQL design (TYPEOF()/TABLE(FLATTEN(...)) inlined in a scalar subquery) was tried first and found live to be fundamentally broken** — Snowflake doesn't support a correlated table function nested inside an arbitrary scalar subquery in a SELECT list, confirmed with even the simplest single flat ARRAY column ("Unsupported subquery type cannot be evaluated"). The UDF sidesteps this entirely and handles arbitrary depth natively (no size-doubling-per-level concern the SQL version had). `OBJECT` and Snowflake's distinct `MAP` type canonicalize identically (sorted by key) since neither exposes whether it's "really" a struct or a map. `float_tolerance > 0` is required as soon as any compared column is semi-structured, even if its values never contain a nested float. **Verified against a live warehouse**: flat `ARRAY`, flat `OBJECT`, and `ARRAY<OBJECT>` (2-level nesting) all correctly detected a deliberate diff with no false positives on unchanged columns. One specific detail remains unverified: whether Snowflake's VARIANT→JS marshalling hands a nested DATE/TIME/TIMESTAMP value to the UDF as a native JS `Date` (handled via `instanceof Date`) — not yet exercised by the live test data. Source type must be `snowflake` on both sides — no local-file federation like DuckDB push-down has via `read_parquet()`.
- `runner.py` — pytest parametrization helpers
- `cli.py` — `rowparity run / list / report` CLI entry points
- `report.py` — Console, JSON, Markdown reporters (single run); also renders `change_signatures` — changed rows (keyed mode) grouped by *which columns differ*, so thousands of changed rows collapse into a handful of patterns instead of a flat example list. Computed in `compare.py` for the default engine (exact, full-table); push-down's version reflects only the fetched example rows (approximation, see TODO)
- `result_sink.py` — persists every run's summary + diff examples to DuckDB/Snowflake/Iceberg (`rowparity run --result-sink duckdb:./results.duckdb`), across `run_id`s over time. `write()` takes an optional `run_ts` override (used for building historical test data; defaults to now).
- `schema_introspect.py` — column name/type for any source spec (all ten `type`s), *without ever materializing a row*: `DESCRIBE (query)` for duckdb, `cursor.describe(sql)` for Snowflake (the connector's own no-execute API), lazy `.schema` for Spark, native table metadata for Iceberg/Delta, Parquet/Arrow file footers only, CSV samples only the first block. Deliberately not a `LIMIT 0` SELECT a case author could forget to add — every path here is structurally incapable of scanning real data (verified: 4ms to introspect a 50M-row DuckDB table).
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
engine: duckdb                  # optional; omit for the default Python engine (compare.py).
                                 # Routes to duckdb_pushdown.py — needs DuckDB-reachable sources
                                 # (duckdb/sql/parquet/csv/inline); type coverage matches the
                                 # default engine except blob and exact (non-tolerance) float.
expected:
  type: parquet
  path: ../data/daily_revenue_expected.parquet
actual:
  type: duckdb
  database: warehouse.duckdb
  query: SELECT day, region, revenue, orders FROM daily_revenue
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

The default engine (`compare.py`, no `engine:` set) materializes rows to hash them — suitable for tens of thousands to low millions of rows. For larger tables, use `engine: duckdb` (`duckdb_pushdown.py`) instead — canonicalizes and fingerprints entirely inside DuckDB, verified at 100M rows/side. Needs DuckDB-reachable sources (`duckdb`/`sql`/`parquet`/`csv`/`inline`); type coverage matches the default engine (including nested list/struct/map, recursively) except blob and exact (non-tolerance) float. For tables that already live natively in Snowflake — no export-to-Parquet step wanted — `engine: snowflake` (`snowflake_pushdown.py`) canonicalizes and fingerprints entirely in-warehouse instead; both `expected`/`actual` must be `type: snowflake`. Covers scalars (bool/int/decimal/float/string/date/time/timestamp) via static schema dispatch, plus semi-structured types (ARRAY/OBJECT/MAP/VARIANT) via a recursive JavaScript UDF (needs `CREATE FUNCTION` granted) — see the module docstring for why nested types needed a UDF rather than more SQL. **Verified against a live warehouse** for both paths (see the module's docstring/CLAUDE.md TODO for the one remaining unverified detail: nested temporal values inside a VARIANT). If neither fits: push filtering into SQL first, use sampling (`WHERE abs(hash(id)) % 100 = 0`), or shard by key across parallel CI workers.

## TODO / Deferred

- **Iceberg push-down source** (`type: iceberg` → DuckDB's native `iceberg_scan()`, not the existing `pyiceberg`-based `sources.py` handler, which materializes to Python and isn't push-down). Deferred: the current hourly (Spark) vs. daily (Snowflake) aggregate reconciliation is small enough to just use the default engine directly against live `snowflake`/`spark` sources — no push-down needed there. Revisit if that comparison stops being small-data, or for the separate migration-playbook (large-table) use case. Two viable approaches already scoped if/when this comes up: (a) DuckDB's catalog-less `iceberg_scan('s3://.../table')` reading a table's storage location directly — works regardless of which engine wrote it, but requires the Snowflake side to actually be a **Snowflake Iceberg External Table** (data in a customer-owned external volume), not a native Snowflake table, which it currently is; (b) a Parquet-landing convenience layer (`COPY INTO` / `df.write.parquet` helpers) for Snowflake/Spark sources generally. Going through Snowflake's own Horizon REST catalog from DuckDB has open limitations as of mid-2026 (see [duckdb/duckdb-iceberg#977](https://github.com/duckdb/duckdb-iceberg/issues/977)) — the direct-storage read is the more robust option.
- **`duckdb_pushdown.py` perf**: fingerprints are currently computed twice when there are diffs (once for counts, once for the bounded example fetch) — a `MATERIALIZED` CTE was tried to avoid this and OOM'd at 100M rows (see module history), so this needs a different approach (e.g. a real temp table) if it's worth pursuing.
- **`change_signatures`** in `duckdb_pushdown.py` results only reflect the fetched example rows, not a full-table breakdown (unlike `compare.py`'s `change_signatures`, which is exact). Pushing the signature grouping into SQL would close this gap.
- **`rowparity report` doesn't read Iceberg result sinks** — `history.py` supports DuckDB and Snowflake only (`IcebergResultSink` remains write-only). Add an Iceberg reader (via pyiceberg `.scan().to_arrow()`) if Iceberg becomes the primary result-sink backend for a real deployment.
- **`rowparity report`'s diff drill-down only shows column-level "changed" diffs**, not missing/added row examples (those are reflected in the per-day counts, not the row-level table) — a reasonable first cut, not a hard limitation; extending the table to show missing/added key values would need its own layout since they don't have an old/new column pair.
- **`concept_check.py` results print as "keyless (multiset)"** in `report.py`'s console output — cosmetic only (`ComparisonResult.summary()` hardcodes that label whenever `keys` is `None`, which concept_check always is); not worth touching shared code in `compare.py` for a wording nit, but worth fixing if it causes real confusion.
- **`snowflake_pushdown.py` scalar path and semi-structured (UDF) path are both verified against a live warehouse** (XSMALL warehouse, `ROWPARITY_TEST` scratch database): keyed compare correctly detected a deliberate diff for scalars, and separately for flat `ARRAY`, flat `OBJECT`, and `ARRAY<OBJECT>` (2-level nesting) with no false positives on unchanged columns. Two bugs were found and fixed in the process (see git history around this): (1) Snowflake statically type-checks a scalar cast like `expr::BOOLEAN` against the expression's *declared* type even inside a never-taken `CASE` branch, which broke an earlier all-SQL design for `ARRAY`/`OBJECT`/`MAP` columns; (2) a correlated table function (`FLATTEN`) nested inside an arbitrary scalar subquery isn't supported by Snowflake at all, which is what motivated the JS UDF redesign in the first place — see the module docstring for the full story.
- **`snowflake_pushdown.py` one remaining unverified detail**: whether Snowflake's VARIANT→JS marshalling hands a nested `DATE`/`TIME`/`TIMESTAMP` value to the UDF as a native JS `Date` object (the UDF handles this via `instanceof Date`) or as something else — documented Snowflake behavior for top-level `DATE`/`TIMESTAMP` UDF arguments, unconfirmed for values nested inside a passed-in `VARIANT`. The live test data (`scripts/build_snowflake_test_data.py`) doesn't currently include a nested temporal value; add one and re-run `examples/cases_snowflake_live/nested_push_down.yaml` to close this gap.
- **`snowflake_pushdown.py` nested-numeric simplification**: `DECIMAL`/`DOUBLE` values nested inside a semi-structured column always go through the tolerance-quantized float path in the UDF — no "wider of both sides" scale matching the top-level `decimal` category gets, since there's no static schema for a nested decimal's scale.
- **`snowflake_pushdown.py` UDF vectorization**: `_ensure_variant_udf()`'s canonicalizer is a scalar JS UDF — one function invocation per row per semi-structured column, which is real, uncharacterized per-row overhead (JS UDF calls aren't vectorized the way native SQL operations are; only verified correct on 2-row test data so far, never benchmarked at scale). If profiling at a realistic row count shows this is a bottleneck, prefer a Snowflake **vectorized Python UDF** (batches many rows per call via pandas) over resurrecting the `LATERAL FLATTEN`+join pure-SQL rewrite that was set aside earlier — same shape as the current UDF (one function, same recursive logic), just batched. Considered and rejected as a simpler fix: hashing the raw semi-structured value directly (`MD5(TO_VARCHAR(col))`) instead of canonicalizing first — doesn't work in general, since it skips float_tolerance/decimal/trim_strings/case_insensitive normalization entirely (though Snowflake's `OBJECT` key serialization is likely already deterministic, which would solve field-order-independence for free if verified — just not the tolerance/normalization half of the problem).