# Developer Setup Guide

Everything you need to go from a fresh clone to a running test suite and a passing pre-commit check.

---

## Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| Python | 3.9 | 3.11+ recommended for speed |
| git | any | |
| make | any | optional; all `make` targets have equivalent manual commands |

---

## 0. Virtual environment (recommended)

Always work inside a virtual environment so project dependencies stay isolated from your system Python. Pick whichever tool fits your workflow:

### `uv` (fastest — recommended)
[uv](https://github.com/astral-sh/uv) is a drop-in replacement for `pip`/`venv` written in Rust. It resolves and installs dependencies ~10–100× faster than pip.

```bash
# Install uv once
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create venv + install the project in one step
uv venv .venv
source .venv/bin/activate
uv pip install -e ".[test,dev]"
```

### `pyenv` + `venv` (precise Python version control)
Use [pyenv](https://github.com/pyenv/pyenv) when you need a specific Python version that isn't installed system-wide.

```bash
pyenv install 3.12.4
pyenv local 3.12.4        # pins .python-version in the repo root
python -m venv .venv
source .venv/bin/activate
pip install -e ".[test,dev]"
```

### `conda` / `mamba`
Good if you already use the Anaconda/conda ecosystem.

```bash
conda create -n rowparity python=3.12
conda activate rowparity
pip install -e ".[test,dev]"      # use pip inside conda for editable installs
```

### Plain `venv` (no extra tools)
```bash
python3 -m venv .venv
source .venv/bin/activate         # Windows: .venv\Scripts\activate
pip install -e ".[test,dev]"
```

> **Tip:** `.venv/` is already in `.gitignore`. All four approaches above use `.venv` as the directory name by default, so nothing extra to configure.

---

## 1. Clone and install

```bash
git clone <repo-url>
cd rowparity

# Install in editable mode with test + dev extras
pip install -e ".[test,dev]"
```

`[test]` adds `pytest`, `duckdb`, and the dbt-duckdb adapter (needed for the example suite).
`[dev]` adds `pre-commit` and `detect-secrets`.

Or let `make` do it:

```bash
make install     # pip install -e ".[test,dev]" + pre-commit install
```

---

## 2. Activate the pre-commit hooks

```bash
pre-commit install
```

This wires three hooks into every `git commit`:

| Hook | What it catches |
|---|---|
| `ruff` | Lint errors + auto-fixable style issues (`E`/`F`/`I`/`B` rules) |
| `ruff-format` | Formatting (line length 100, consistent style) |
| `detect-private-key` | RSA, EC, PEM, OpenSSH private keys |
| `detect-secrets` | API keys, tokens, passwords, connection strings (compared against `.secrets.baseline`) |

Run all hooks manually at any time:
```bash
pre-commit run --all-files
```

If `detect-secrets` flags a real false positive (not an actual secret), add
`# pragma: allowlist secret` to that line and regenerate the baseline:
```bash
detect-secrets scan > .secrets.baseline
```
Commit both the code change and the updated baseline.

---

## 3. Build example data

The test suite needs a small DuckDB warehouse and Parquet fixtures:

```bash
make data        # builds examples/data/warehouse.duckdb + parquet files (Case 01)
make tpch-data   # builds examples/data/tpch.duckdb (Cases A–G, TPC-H scale 0.01)
```

Or directly:
```bash
python examples/build_example_data.py
python examples/build_tpch_data.py
```

These are fast (a few seconds each) and idempotent.

---

## 4. Run the tests

```bash
pytest                          # all tests, quiet output
pytest -v                       # verbose — show each test name
pytest -x                       # stop on first failure
pytest -k "revenue" -xvs        # run tests matching "revenue", verbose + stdout
make test                       # pytest with JUnit XML output → reports/junit.xml
```

The suite is split into:

| File | What it tests |
|---|---|
| `tests/test_engine.py` | 50+ unit tests for comparison semantics (the Python engine) |
| `tests/test_duckdb_pushdown.py` | DuckDB push-down parity against the Python engine |
| `tests/test_duckdb_pushdown_nested_types.py` | DuckDB push-down for `list`/`struct`/`map` |
| `tests/test_trino_pushdown.py` | Trino push-down SQL generation + fake-connection orchestration |
| `tests/test_snowflake_pushdown.py` | Snowflake push-down SQL generation + fake-connection orchestration |
| `tests/DELTE_test_schema_check.py` | `schema_check:` case type |
| `tests/test_concept_check.py` | `concept_check:` case type |
| `tests/test_examples.py` | End-to-end YAML cases (needs `make data` + `make tpch-data`) |
| `tests/test_result_sink.py` | DuckDB/Snowflake/Iceberg result sinks |
| `tests/test_vectorized.py` | Vectorized canonicalization path |

`xfail`-tagged cases (e.g. `tpch_orders_schema_drift`) are expected to fail and do not count against the exit code.

---

## 5. Run the declarative QA cases

```bash
make qa
# or:
rowparity run examples/cases --json reports/rowparity.json --md reports/rowparity.md
```

Exits non-zero if any non-`xfail` case differs. Reports land in `reports/`.

---

## 6. Lint and format manually

```bash
ruff check src/ tests/          # lint
ruff check src/ tests/ --fix    # lint + auto-fix safe issues
ruff format src/ tests/         # format
ruff format src/ tests/ --check # format check only (no writes)
```

The pre-commit hook runs both automatically on every `git commit`.

---

## 7. Project layout

```
src/rowparity/
├── cases.py              YAML case loading + engine dispatch
├── compare.py            CompareConfig, ComparisonResult, compare_tables()
├── hashing.py            canon_value(), row_digest() — the Python engine
├── sources.py            10 pluggable source handlers (all return pyarrow.Table)
├── duckdb_pushdown.py    SQL push-down via DuckDB (engine: duckdb)
├── snowflake_pushdown.py SQL push-down via Snowflake (engine: snowflake)
├── trino_pushdown.py     SQL push-down via Trino (engine: trino)
├── snowflake_auth.py     Shared Snowflake connection builder (key-pair auth only)
├── trino_auth.py         Shared Trino connection builder
├── schema_introspect.py  Column name/type without materializing rows
├── schema_check.py       schema_check: case type (schema-only comparison)
├── concept_check.py      concept_check: case type (N-to-1 remodel validation)
├── report.py             Console, JSON, Markdown reporters
├── report_html.py        HTML trend dashboard generator
├── result_sink.py        DuckDB/Snowflake/Iceberg result persistence
├── history.py            Result sink reader for rowparity report
├── runner.py             pytest helpers: assert_case()
├── cli.py                rowparity run / list / report CLI
└── templates/report.html HTML report template
```

---

## 8. Adding a new source type

1. Add a handler `_mysource(spec, base_dir) -> pa.Table` in `sources.py`
2. Register it in `_HANDLERS` at the bottom of `sources.py`
3. Add a `_describe_mysource(spec, base_dir) -> Dict[str, str]` in `schema_introspect.py` and register it in `_HANDLERS` there
4. Update the `sources:` docstring in `sources.py`
5. Add tests in `tests/`

If the source is a SQL engine and you want push-down support, follow the pattern in `trino_pushdown.py` — it is the most recently written and cleanest reference.

---

## 9. Adding a new comparison case to the test suite

Create a YAML file under `examples/cases/` (or `tests/cases/`):

```yaml
name: my_new_case
description: What this checks and why.
tags: [regression]   # add xfail here if it's expected to fail

expected:
  type: parquet
  path: ../../data/my_golden.parquet

actual:
  type: duckdb
  database: ../../data/warehouse.duckdb
  query: SELECT * FROM my_model

compare:
  keys: [id]
  float_tolerance: 0.001
```

The case is automatically picked up by `discover_cases()` and by `rowparity run` — no Python changes needed.

---

## 10. Credentials for cloud engines (CI)

**Snowflake** — key-pair auth only; password auth is not supported anywhere in the codebase. Required env vars:
```
SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_ROLE, SNOWFLAKE_WAREHOUSE,
SNOWFLAKE_DATABASE, SNOWFLAKE_SCHEMA,
SNOWFLAKE_PRIVATE_KEY_PATH  (or SNOWFLAKE_PRIVATE_KEY for raw PEM)
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE  (optional, if the key is encrypted)
```

**Trino** — env vars:
```
TRINO_HOST, TRINO_PORT (default 8080), TRINO_USER,
TRINO_CATALOG, TRINO_SCHEMA, TRINO_HTTP_SCHEME (default http)
TRINO_PASSWORD       (for Basic auth)
TRINO_JWT_TOKEN      (for JWT auth — preferred for CI service accounts)
```

Store these as CI secrets (GitHub Actions `secrets.*`, Jenkins credentials, etc.) — **never** commit them. The `.gitignore` and `detect-secrets` pre-commit hook are defense-in-depth for this.

---

## 11. Making a release

1. Bump `version` in `pyproject.toml`
2. Run `make test` and `make qa` — both must be green
3. Run `pre-commit run --all-files` — must be clean
4. Tag the commit: `git tag v0.x.y`
5. Build: `python -m build`
6. Publish: `twine upload dist/*`
