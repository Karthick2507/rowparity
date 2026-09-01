# HeadFirst — rowparity, start to end

The single document to read before touching this repo. It covers what rowparity
does, how a run flows through the code, how the fingerprint works, how to add a
new case, and how to read every line of the report it produces.

Written against the code as it stands. Where a documented feature has been
removed or is currently dead, §10 says so rather than leaving you to find out.

---

## Table of contents

1. [What rowparity is](#1-what-rowparity-is)
2. [Install and imports](#2-install-and-imports)
3. [Your first run](#3-your-first-run)
4. [Code flow — one command, end to end](#4-code-flow--one-command-end-to-end)
5. [The fingerprint](#5-the-fingerprint)
6. [DuckDB in this project](#6-duckdb-in-this-project)
7. [Adding a new case](#7-adding-a-new-case)
8. [Reading the report, line by line](#8-reading-the-report-line-by-line)
9. [Reference tables](#9-reference-tables)
10. [Traps and dead options](#10-traps-and-dead-options)

---

## 1. What rowparity is

A fingerprint-based expected-vs-actual data test. You declare two data sets in
YAML, and rowparity tells you whether they hold the same rows — and when they do
not, exactly which rows and which columns.

The core idea is one sentence:

> Reduce every row to a canonical Blake2b fingerprint. Two tables are equivalent
> when their fingerprints agree.

Everything else follows from that. Row order cannot matter, because a fingerprint
does not know its own position. Column order cannot matter, because columns are
sorted by name before hashing. `int32` from one engine equals `int64` from
another, because both canonicalise to the same integer.

The working example throughout is the **Hoover / Hoover++** parity case: one
2,000-line Presto aggregate run against two catalogs, 262 output columns, keyed
on 83 dimensions. Anywhere the path differs for another source type, it is
called out.

### The two questions a run answers

| Question | Reported as |
|---|---|
| Does this dimension combination exist on both sides? | `missing` / `added` |
| Do the metrics agree for a combination that exists on both? | `changed` |

Keeping those separate is the whole reason the case is **keyed**. See §7.3.

---

## 2. Install and imports

### 2.1 Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[trino]"       # the Hoover case needs this one
```

Extras are per driver. Install only what your case actually reads:

| Extra | Pulls in | Install when your case uses |
|---|---|---|
| `duckdb` | `duckdb>=0.10` | `type: duckdb`, `type: sql`, `engine: duckdb` |
| `trino` | `trino>=0.320` | `type: trino`, `engine: trino` |
| `snowflake` | `snowflake-connector-python[pandas]` | `type: snowflake`, `engine: snowflake` |
| `iceberg` | `pyiceberg[pyarrow]` | `type: iceberg` |
| `delta` | `deltalake` | `type: delta` |
| `spark` | `pyspark>=3.3` | `type: spark` |
| `dbt` | `dbt-core`, `dbt-duckdb` | building the example warehouse |
| `test` | `pytest`, `duckdb`, dbt | running the test suite |
| `dev` | `pre-commit`, `detect-secrets` | committing to this repo |
| `all` | everything above | you do not care |

```bash
pip install -e ".[all]"      # everything
make install                 # ".[test,dev]" + activates the git hooks
```

`make install` also runs `pre-commit install`, which activates the secret
scanners. Do that once before your first commit — see §10.4.

### 2.2 The two ways to import

**As a CLI.** `pyproject.toml` maps one console script:

```toml
[project.scripts]
rowparity = "rowparity.cli:main"
```

That is the normal way in. Nothing else needs importing.

**As a library**, for a pytest suite or a notebook:

```python
import pyarrow as pa
from rowparity import CompareConfig, compare_tables      # the public API
from rowparity.cases import discover_cases, load_cases_from_file
from rowparity.runner import assert_case                 # pytest entry point
```

`rowparity/__init__.py` re-exports the three things most callers need —
`compare_tables`, `CompareConfig`, and the hashing primitives. Everything else is
imported from its module.

The standard pytest pattern:

```python
import pytest
from rowparity.cases import discover_cases
from rowparity.runner import assert_case

@pytest.mark.parametrize("case", discover_cases("scripts/cases_insight_plus"),
                         ids=lambda c: c.name)
def test_case(case):
    assert_case(case)
```

### 2.3 What each driver is imported for

Heavy drivers are **lazy imports** inside their handler function, not at module
top level. Importing `rowparity` does not import Trino, Snowflake, Spark or
Iceberg. That is why `pip install -e ".[trino]"` alone is a working install:
nothing forces you to have the drivers you do not use.

### 2.4 Environment for the Hoover case

```bash
export TRINO_HOST=presto-gateway.presto.stg.aws.fwmrm.net
export TRINO_PORT=8080
export TRINO_HTTP_SCHEME=https
export TRINO_USER=your.user

read -rs TRINO_JWT_TOKEN && export TRINO_JWT_TOKEN    # paste, no echo, no history
```

`read -rs` matters: it keeps the token out of your shell history and off your
screen. **Secrets are read from the environment only.** There is no code path
that reads a token or password out of a case file, because case files are
committed to git.

---

## 3. Your first run

```bash
rowparity run scripts/cases_insight_plus \
    --param arena.presto.var.process_batch_id=20260827010000 \
    --csv reports/insight_plus \
    --html reports/insight_plus/run.html
```

Before that, two cheap commands that touch no warehouse:

```bash
rowparity list scripts/cases_insight_plus     # what would run, and its description
python scripts/trino_connectivity_check.py    # proves the connection works first
```

`rowparity list` passes `resolve_queries=False`, so listing never opens a
connection. Run it after every YAML edit — it catches a malformed case in a
second instead of after a warehouse has spent an hour.

**The batch parameter is required and has no default.** A default would name a
batch that may not exist, both sides would return zero rows, and the run would
report EQUIVALENT — a green result proving nothing. Unresolved is a hard error
instead.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | every case equivalent |
| 1 | a case differed, or a case errored |
| 2 | cases could not be loaded (bad `--param`, unreadable YAML, no cases found) |

`2` is deliberately distinct from `1`. It is what lets CI tell "the tool could
not run" from "the data disagrees".

---

## 4. Code flow — one command, end to end

### 4.1 Process start

The shell invokes **`cli.main()`**, which builds the argparse tree and ends at
`return args.func(args)` → **`cli._run(args)`**.

### 4.2 `_run` starts up

**Progress first, before anything can be slow.**

```python
progress.configure(enabled=not getattr(args, "quiet", False),
                   heartbeat_seconds=getattr(args, "heartbeat", None))
```

Deliberately the first statement. `progress` is off by default so library and
pytest use stay silent and no heartbeat threads are created; the CLI switches it
on. Output goes to **stderr**, every write flushed — which is why
`2>&1 | tee run.log` shows heartbeats as they happen, and why
`rowparity run > results.txt` keeps stdout clean.

**Then parameters, then cases.**

```python
try:
    cli_params = parse_cli_params(getattr(args, "param", None))
    cases = discover_cases(args.path, cli_params)
except ParamError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    return 2
```

`params.parse_cli_params()` splits on the **first** `=` only, so a value
containing `=` survives intact.

### 4.3 Loading the case

**`cases.discover_cases()`** globs `**/*.yml` and `**/*.yaml` recursively, sorts
for a stable order, and calls `load_cases_from_file` on each.

**`cases.load_cases_from_file()`**:

```python
doc           = yaml.safe_load(fh) or {}
multi         = "cases" in doc
file_vars     = doc.get("vars", {}) if multi else {}
param_queries = doc.get("param_queries", {}) or {}
raw_cases     = doc["cases"] if multi else [doc]
```

A `param_queries:` block — a parameter resolved by *querying the warehouse*
rather than being typed in — resolves **once per file here**, never per case. Two
cases keying off "the latest batch" must see the *same* batch; resolving per case
would let a batch landing mid-run compare two different populations, which looks
exactly like a data defect.

**`cases._build_case()` — where `${…}` disappears**:

```python
case_vars = raw.pop("vars", None) or {}
variables = params.resolve_variables(file_vars, case_vars, cli_params)
raw       = params.substitute_spec(raw, variables, where=f"case '{raw['name']}' …")
```

`params.resolve_variables()` merges four sources, later winning:

```
file vars:   <   case vars:   <   ROWPARITY_VAR_*   <   --param
```

All names are lower-cased, so `${BATCH_ID}` and `${batch_id}` are one name.
Dotted names are recognised (`${arena.presto.var.process_batch_id}`) — query
files templated by another system carry namespaced names, and a placeholder that
is neither substituted *nor* reported unresolved reaches the engine as literal
text inside quotes: a valid predicate matching nothing.

`params.substitute_spec()` walks the **entire raw case dict** before any shape
dispatch, so no spec can reach an engine still holding a placeholder.

**One block is deliberately excluded from this pass:** `drilldown:`. Its
placeholders (`${batch_hour}` and friends) do not exist until the drill-down is
generated, after the comparison. Substituting them at load time would fail
`rowparity list`.

Then shape dispatch:

| Top-level block | Built as |
|---|---|
| `expected:` + `actual:` | `Case` — the normal row comparison |
| `concept_check:` | `ConceptCheckCase` — N old tables' concepts → one wide table |

The `Case` carries `variables` forward. **The SQL files have not been read yet** —
`query_file` contents are resolved at run time.

### 4.4 Per-case execution

```python
for case in cases:
    is_xfail = "xfail" in case.tags
    try:
        result = case.run(result_sink=result_sink)
    except Exception as exc:
        print(f"Case '{case.name}': ERROR - {type(exc).__name__}: {exc}\n")
        failures += 1
        continue
    results.append((case.name, result))
    print(render_console(result, case.name))
```

**That `try/except` is why one failing case does not kill the run.** It turns an
`EmptyComparisonError`, a `ParamError` from a `query_file`, or a Trino
`COLUMN_NOT_FOUND` into a reported line plus `failures += 1`.

**`Case.config()`** rejects unknown keys rather than ignoring them:

```python
unknown = set(self.compare) - _COMPARE_KEYS
if unknown:
    raise ValueError(f"case '{self.name}': unknown compare option(s): {sorted(unknown)}")
```

A typo'd `ignore_colums:` would otherwise silently do nothing. It also normalises
`breakdown_by` from a string to a list, so everything downstream sees one shape.

**`Case.run()`** — note what happens *before* any connection opens:

```python
self._check_breakdown(cfg)                   # ← before a single row is fetched
progress.emit(f"Case '{self.name}'")
self._guard_identical_sides(base_dir, cfg)   # ← likewise

with progress.step(f"expected  ({self.expected.get('type','?')})") as st:
    expected_tbl = load_source(self.expected, base_dir=base_dir, variables=self.variables)
    st.result(progress.describe_table(expected_tbl))
# …same for actual…
with progress.step("comparing") as st:
    result = compare_tables(expected_tbl, actual_tbl, cfg)
```

Both guards run before any connection is opened, so a misconfigured case fails in
the first second rather than after the warehouse has produced an answer that
proves nothing.

- **`_check_breakdown()`** rejects a `breakdown_by` naming a non-key column. A key
  is the only thing guaranteed identical on both sides of a paired row, so a
  non-key column would put a changed row in two groups at once. It also rejects
  `breakdown_by` on a push-down engine, which aggregates in-warehouse and never
  sees a row.
- **`_guard_identical_sides()`** fires when both sides name the same `query_file`
  *and* resolve it to the same text — which means a per-side `vars:` block was
  copy-pasted and one value never changed. Left alone that runs the full
  aggregate twice against one catalog and reports EQUIVALENT with exit 0,
  indistinguishable from a real pass.

Each `progress.step()` prints `-> …`, starts a daemon heartbeat thread, runs the
body, then prints `OK … <elapsed> <summary>`. On exception it prints
`FAILED … <elapsed>` and re-raises untouched — "it failed after four minutes" is
still worth being told.

### 4.5 Fetching each side

`sources.load_source()` dispatches on `spec["type"]`. For `type: trino` that is
`sources._trino()`:

```python
if spec.get("vars"):                                  # ← per-side vars merged HERE
    variables = merge_side_vars(spec["vars"], variables)
query = resolve_query(spec, base_dir, variables)      # ← the SQL file is read HERE
con = _trino_connect(spec)
try:
    cur = con.cursor()
    cur.execute(query)
    col_names  = [d[0] for d in (cur.description or [])]
    batch_rows = int(spec.get("fetch_batch_rows") or _trino_batch_rows(len(col_names)))
    tables = []
    while True:
        rows = cur.fetchmany(batch_rows)               # ← batched, not fetchall()
        if not rows:
            break
        tables.append(pa.Table.from_pylist([dict(zip(col_names, r)) for r in rows]))
    return pa.concat_tables(tables, promote_options="permissive")
finally:
    con.close()
```

Three details worth knowing:

- **Rows arrive in batches.** `fetchall()` built the whole result as Python tuples
  and then a second full copy as dicts before Arrow saw anything. Measured at 262
  columns: 0.51 GB at 25k rows, 0.97 GB at 50k, 1.92 GB at 100k. Batched, peak is
  **flat at 0.15 GB** across all three, because only one batch is ever in Python
  and what accumulates is columnar Arrow. Batch size follows a cell budget rather
  than a row count, since a 262-column row is two orders of magnitude heavier
  than a 1-column one.
- **The zero-row branch preserves columns** from `cursor.description`. Without it
  an empty result would lose its schema entirely.
- **`from_pylist` has no explicit schema**, so Arrow infers types per batch — a
  hazard batching introduces. A column all-`NULL` in one batch infers as `null`
  while a later batch infers `int64`. `promote_options="permissive"` unifies
  those, so batching cannot turn a memory problem into a correctness one. A
  column `NULL` in *every* batch still lands as `null` type.

**`params.merge_side_vars()`** overlays this side's own `vars:` block on the case
variables, for this side only. It is what lets both sides share one `query_file`
and still run different queries — `from ${facts}.ad` becomes
`from mrm_log_flat.default.ad` for Hoover and `from etl.public_test1.ad` for
Hoover++.

A side var **outranks `--param`**, inverting the precedence used everywhere else.
A `--param` reaching both sides would point them at the same catalog, and
comparing a table with itself passes regardless of the data. A side var is not a
knob; it is half of what makes the two sides different.

**`sources.resolve_query()`** resolves `query_file` relative to the YAML's
directory, reads it, and substitutes into the **file contents**. An unresolved
name raises `ParamError` here.

**`trino_auth.connect()`** merges a case's `connection:` block over `TRINO_*`
environment variables (**YAML wins**), requires `host`, and picks an auth mode:

| Mode | Trigger | Wire format |
|---|---|---|
| JWT | `TRINO_JWT_TOKEN` | `Authorization: Bearer <token>` |
| Basic | `TRINO_PASSWORD` | HTTP Basic |
| None | neither | no auth header |

Both sides are now `pyarrow.Table`. **Nothing downstream knows the data came from
Trino.**

### 4.6 The comparison

`compare.compare_tables()`.

**Column resolution — `compare._resolve_columns()`:**

```python
only_exp  = [c for c in exp_cols if c not in act_set]
only_act  = [c for c in act_cols if c not in exp_set]
candidate = cfg.select if cfg.select else [c for c in exp_cols if c in act_set]
compared  = [c for c in candidate if c not in set(cfg.ignore_columns)]
type_mismatches = [(c, str(et), str(at)) for c in compared if not et.equals(at)]
```

One function produces all three column states:

| Result field | Reported as |
|---|---|
| `compared_columns` | `MATCHED` |
| `columns_only_in_expected` / `columns_only_in_actual` | `DIFF` (unmatched) |
| `type_mismatches` | `MATCHED - TYPE DIFF` |

A separate zero-row schema pass is therefore unnecessary — column status falls
out of the row comparison for free.

**Keyed comparison — `compare._compare_keyed()`:**

```python
for k in keys:
    if k not in exp_schema.names or k not in act_schema.names:
        raise ValueError(f"key column '{k}' is missing from expected or actual table")

for i, r in enumerate(exp_rows):
    exp_index[_key_of(r, exp_schema, keys, canon_cfg, exp_canon, i)].append(i)
# …same for actual…

result.duplicate_keys_expected = sum(len(v)-1 for v in exp_index.values() if len(v) > 1)
```

`compare._key_of()` canonicalises **only the key columns** into a tuple, used
**raw as a dict key** — the key is *not* hashed (see §5.3). Canonicalisation
applies here too, so `unordered_list_columns` affects which rows pair up: `[7, 12]`
and `[12, 7]` land in the same bucket only if that column is declared unordered.

Then three set operations:

```python
missing = exp_keys - act_keys        # in expected only
added   = act_keys - exp_keys        # in actual only
for key in exp_keys & act_keys:      # paired — now compare the values
    e_digest = row_digest(canon_row(exp_schema, e, cols, canon_cfg))
    a_digest = row_digest(canon_row(act_schema, a, cols, canon_cfg))
    if e_digest != a_digest:
        result.changed_count += 1
        coldiffs = _column_diffs(...)
```

The three key lists are kept on the result (`missing_keys`, `added_keys`,
`changed_keys`) — the near-miss analysis and the drill-down both read them.

**The empty guard — `Case._guard_empty()`:**

```python
if cfg.allow_empty or result.kind != "rows":   return
if result.expected_rows or result.actual_rows: return
raise EmptyComparisonError(...)
```

Two empty tables are trivially equivalent, so a run that fetched nothing would
report `EQUIVALENT` and exit 0 — indistinguishable from a real pass. It keys off
`ComparisonResult.kind`, not the row count, because `concept_check` reports zero
rows *by design*.

### 4.7 Reporting and exit

```python
if args.json or args.md:
    write_reports(results, json_path=args.json, md_path=args.md)
if getattr(args, "csv", None):
    paths = write_csv_reports(results, args.csv)
if getattr(args, "html", None):
    write_run_report(args.html, results, errors, run_id=run_id)
return 1 if failures else 0
```

Markdown is written **before** JSON: they are independent artifacts, and writing
JSON first meant a failure there took the Markdown report down with it — losing
both on precisely the runs that had something to report.

### 4.8 The whole path

```
shell
 └─ cli.main ──► argparse ──► args.func = cli._run
     ├─ progress.configure                    progress.py
     ├─ params.parse_cli_params
     ├─ cases.discover_cases
     │   └─ cases.load_cases_from_file
     │       ├─ yaml.safe_load
     │       ├─ param_queries.resolve_param_queries   (once per file)
     │       └─ cases._build_case
     │           ├─ params.resolve_variables    vars < env < --param
     │           └─ params.substitute_spec      ${…} over the case, minus drilldown:
     └─ for case in cases:  try:
         └─ Case.run
             ├─ Case.config                   ──► CompareConfig
             ├─ Case._check_breakdown         ──► breakdown_by must be a key
             ├─ Case._guard_identical_sides   ──► refuse a self-comparison
             ├─ progress.step "expected"
             │   └─ sources.load_source → sources._trino
             │       ├─ params.merge_side_vars  ──► ${facts} → this side's catalog
             │       ├─ sources.resolve_query   ──► ${…} → 20260827010000
             │       ├─ trino_auth.connect      ──► JWT / Basic / none
             │       └─ execute → fetchmany loop → concat_tables → pa.Table
             ├─ progress.step "actual"        ──► same file, other catalog
             ├─ progress.step "comparing"
             │   └─ compare.compare_tables
             │       ├─ compare._resolve_columns  ──► MATCHED / DIFF / TYPE DIFF
             │       └─ compare._compare_keyed
             │           ├─ compare._key_of       ──► key tuple, not hashed
             │           ├─ hashing.canon_row → hashing.row_digest  ──► blake2b 16B
             │           ├─ compare._column_diffs ──► which columns differ
             │           └─ compare._accumulate_deltas ──► direction, constant?
             ├─ near_miss.analyse             ──► which key column drifted
             ├─ drilldown.generate            ──► two ready-to-run queries
             └─ Case._guard_empty
         └─ report.render_console → write_csv_reports → write_run_report → exit 0/1/2
```

### 4.9 Three seams worth knowing

**`pyarrow.Table` at the end of §4.5.** Everything after it is engine-agnostic.
This is what lets one comparison engine serve Trino, Snowflake, DuckDB, Parquet
and inline fixtures — a new source type only has to return an Arrow table.

**`ComparisonResult` at the end of §4.6.** Every reporter consumes the same
object: console, JSON, Markdown, CSV, HTML, the result sink. A new field is
visible everywhere at once; a new reporter needs no changes elsewhere.

**The `try/except` in §4.4.** One case's failure never takes down the run, which
is what makes a directory of cases a suite rather than a fragile chain.

---

## 5. The fingerprint

### 5.1 What is actually stored

Two functions, in `hashing.py`:

```python
def canon_row(schema, row, columns, cfg):
    return tuple((name, canon_value(schema.field(name).type,
                                    row.get(name), cfg,
                                    unordered_list=name in cfg.unordered_list_columns))
                 for name in columns)          # columns pre-sorted by caller

def row_digest(canon):
    return hashlib.blake2b(repr(canon).encode("utf-8"), digest_size=16).digest()
```

A row becomes a **16-byte Blake2b digest**. Not a Python `hash()`, not a
`hashmap` — a cryptographic digest, chosen because it is stable across processes
and runs (Python's `hash()` is salted per process and would make two runs
incomparable).

### 5.2 The canonicalisation rules

`hashing.canon_value()` applies every invariant *before* hashing. These are the
semantics of the whole tool:

| Rule | Why |
|---|---|
| Columns sorted by name | column order is not data |
| `int32` ≡ `int64` | engines disagree on width |
| Decimals: trailing zeros stripped | `1.10` ≡ `1.1` |
| Timestamps → UTC | same instant, different session zone |
| Floats quantised to the tolerance grid | non-associative `SUM` gives last-digit noise |
| `list` / `array` **ORDERED** | a sequence's order is data |
| `struct` / `map` **UNORDERED** | field order is not data; keys sorted first |
| **NULL distinct** | never equal to `""`, `0`, `[]`, or `-1` |

`unordered_list_columns:` opts a specific array column out of the ordered rule,
for arrays whose element order the engine does not guarantee.

### 5.3 Where the digest is used — and where it is not

This is the part people get wrong. **In a keyed comparison the key is not
hashed.**

```
key columns   ──► canon_value() ──► tuple ──► used RAW as a dict key
all columns   ──► canon_value() ──► tuple ──► blake2b ──► 16-byte digest
```

The key tuple is a type-tagged Python tuple used directly as a dictionary key:

```python
('i', 516429), ('t', 'midroll'), ('L', (('i', 34007),)), ...
```

`'i'` integer, `'t'` text, `'L'` list. The tag is there so `1` and `"1"` never
collide.

Two reasons the key stays unhashed:

1. **A digest collision would silently pair two different rows.** 16 bytes makes
   that vanishingly unlikely, but a raw tuple makes it impossible.
2. **The key must be readable back out.** The report prints the key of every
   missing row, the near-miss analysis drops one element at a time and re-pairs,
   and the drill-down reads `creative_id` out of position 11 of the tuple. None
   of that works on a digest.

The **digest** is used for exactly one thing: deciding whether two rows that
*already paired on their key* hold the same values. One 16-byte comparison
instead of 262 per-column comparisons — and only when it differs does
`_column_diffs()` do the expensive per-column work to say which columns moved.

### 5.4 Why this makes row order irrelevant

Nothing in the pipeline records a row's position. `exp_index` is a dict keyed by
the key tuple; `missing = exp_keys - act_keys` is a set operation. Sorting the
input would change nothing about the output. Order-independence is not a feature
that was added — it is a property of the representation.

---

## 6. DuckDB in this project

**Your Hoover run does not use DuckDB.** The case sets no `engine:`, so it takes
the default Python engine. DuckDB has three unrelated roles in this repo, and
mixing them up causes confusion:

### 6.1 As a source — `type: duckdb` / `type: sql`

A local query engine, used by the example cases and handy in CI because it needs
no cluster:

```yaml
actual:
  type: duckdb
  database: warehouse.duckdb
  query: SELECT day, region, revenue FROM daily_revenue
```

It can read Parquet, CSV and Iceberg in place, so it doubles as "run SQL over
files".

### 6.2 As a push-down engine — `engine: duckdb`

`duckdb_pushdown.py`. This is the interesting one. Instead of fetching rows into
Python and hashing them there, it **builds the canonicalisation and the
fingerprint as SQL** and runs the whole comparison inside DuckDB:

```yaml
engine: duckdb        # → duckdb_pushdown.py instead of compare.py
```

- Verified at **100M rows per side**, where the default engine would not fit in
  memory.
- Produces the same `ComparisonResult`, so every reporter works unchanged.
- Reads schema via `con.sql(...).types` — structured `DuckDBPyType` objects with
  real `.id`/`.children`, not `DESCRIBE`'s flat strings — which is what lets it
  recurse into nested types.
- Full type parity with the default engine: bool, int, float, decimal, string,
  timestamp, date, time, plus recursive list (ordered), struct (unordered by
  field name) and map (unordered by key, sorted at runtime since map keys are
  data, not schema), arbitrarily nested. Only **blob** and **exact
  (non-tolerance) float** are not covered.
- **Sources must be DuckDB-reachable**: `duckdb`, `sql`, `parquet`, `csv`,
  `inline`. A Snowflake or Spark source has to be exported to Parquet first —
  there is no bespoke SQL dialect per engine.

Two known limits: fingerprints are computed twice when there are diffs (once for
counts, once for the bounded example fetch — a `MATERIALIZED` CTE was tried and
OOM'd at 100M rows), and `change_signatures` reflect only the fetched example
rows rather than a full-table breakdown.

`breakdown_by` and `null_equivalence` are **rejected** on a push-down engine
rather than silently ignored: they are computed per row by the default engine,
and a push-down engine never sees a row.

### 6.3 As a result sink

```bash
rowparity run cases/ --result-sink duckdb:./reports/results.duckdb
rowparity report --result-sink duckdb:./reports/results.duckdb --html trend.html
```

Every run's summary and diff examples are appended to a DuckDB file, and
`rowparity report` reads that history back out into a trend page. Unrelated to
either use above.

### 6.4 Choosing an engine

| Situation | Use |
|---|---|
| Tens of thousands to low millions of rows | default (no `engine:`) |
| Larger, and the data is in files or DuckDB | `engine: duckdb` |
| Larger, and the data lives in Snowflake | `engine: snowflake` |
| Larger, and the data lives in Trino | `engine: trino` |
| None of these fit | filter in SQL, sample (`WHERE abs(hash(id)) % 100 = 0`), or shard by key across CI workers |

Push-down needs **both sides on the same engine and connection**. `engine: trino`
is complete and unit-tested but has **not yet been run against a live cluster**;
`engine: snowflake` has been verified live for both its scalar and its
semi-structured paths.

---

## 7. Adding a new case

The Hoover case is the worked example. Adding a second query means four files, in
this order.

### 7.1 The SQL — one file, not two

Put the query at `sql/<project>/<name>.sql` and template every place the two
sides differ:

```sql
select ...
from ${facts}.ad          -- ← the ONE thing that differs between sides
where ${sampling_filter}  -- ← shared, defined once, used by both
  and process_batch_id = '${arena.presto.var.process_batch_id}'
```

**One file serves both sides.** There were two near-identical copies of the Hoover
query once, kept in step by a test that diffed them. The file is 185 KB, so
"identical apart from three lines" was a promise a test had to keep rather than
something you could see. One file cannot drift from itself.

Rules:

- Anything that differs per side is `${a_placeholder}`, resolved by that side's
  `vars:`.
- Anything that must **never** differ (the sampling filter) goes in the
  case-level `vars:`, defined once and used by both. Then the bug is not
  expressible.
- **Do not write `${...}` in a comment** unless you mean it. Substitution does not
  know what a comment is. Write placeholder names bare in header comments.

### 7.2 The YAML

```yaml
cases:
  - name: my_new_aggregate
    expected_label: Hoover              # report says "Hoover", not "expected"
    actual_label: Hoover++
    description: >-
      One sentence on what must be true for this to pass.

    vars:                               # shared by BOTH sides
      sampling_filter: "bitwise_and(...) > 0"

    expected:
      type: trino
      query_file: ../../sql/insight_plus/my_new_aggregate.sql
      vars: {facts: mrm_log_flat.default}    # ← the only per-side difference

    actual:
      type: trino
      query_file: ../../sql/insight_plus/my_new_aggregate.sql
      vars: {facts: etl.public_test1}

    compare:
      keys: [...]                       # every GROUP BY dimension
      unordered_list_columns: [global_advertiser_ids, global_brand_ids]
      max_examples: 50
      breakdown_by: slot_user_drop_off  # must be one of the keys
      near_miss: true

    row_summary:                        # how a diff row is digested in the report
      - {label: Branch,  columns: [slot_user_drop_off]}
      - {label: Batch,   columns: [process_batch_id, event_date]}

    drilldown:
      query_file: ../../sql/insight_plus/my_new_aggregate_drilldown.sql
      bind: {creative_id: "if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1)"}
      id_column: request__transaction_id
      kinds: [missing]
      time: {param: arena.presto.var.process_batch_id, format: "%Y%m%d%H%M%S",
             hours_before: 1, hours_after: 3}
      vars:
        expected: {time_filter: "... >= timestamp '${batch_hour_start}' and ... < timestamp '${batch_hour_end}'"}
        actual:   {time_filter: "... = timestamp '${batch_hour}'"}

    tags: [insight_plus, hoover]
```

### 7.3 Choosing the keys — the decision that matters most

**Key on every GROUP BY dimension.** Not on a "business key" — nobody would call
83 columns one — but the dimensions are unique by construction after the outer
aggregation, which is all a key has to be.

The Hoover case ran keyless first and the result was undiagnosable: 158 missing +
217 added, with no way to tell whether those were the same logical rows with
drifting metrics or genuinely different groups. Without a key nothing pairs a
missing row with the added row it corresponds to, so every difference surfaces as
missing + added and never as "changed" — and the per-column report flagged all
262 columns, because one side had 59 extra rows and so every column's value
multiset differed. True, and useless.

Keyed on the dimensions, the same run separates the two questions:

```
missing / added  → dimension combinations absent from one side  (structural)
changed          → same dimensions, different metrics           (value drift)
```

If the keys turn out not to be unique, rowparity reports `duplicate_keys_*`
rather than guessing — and that is itself a finding.

### 7.4 The drill-down SQL

`sql/<project>/<name>_drilldown.sql`, against the raw table, with two
placeholders rowparity fills in:

```sql
select request__transaction_id, event_date, creative_id
from ${facts}.ack
where ${time_filter}
  and ${row_filter}          -- ← rowparity substitutes the generated IN-list
```

`${row_filter}` becomes a single IN-list over every differing row's bound column:

```sql
and if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1) in (
        214174352,
        330895668,
        ...
    )
```

Design decisions baked in:

- **Two queries total, not two per row.** Twenty near-identical 40-line queries
  are twenty things to copy, twenty results to reconcile, and twenty scans of the
  same partition — when one scan answers all of them.
- **Generated, never executed.** Running both sides was tried and taken back out:
  against the real cluster the two scans dominated the parity run they were meant
  to annotate. Run them yourself when you want the ids; the tedious part —
  pasting values into a 40-line WHERE — is what was worth automating.
- **`kinds:` selects which differing rows contribute**, defaulting to `[missing]`.
  See §8.8.
- **The time window is derived from the batch parameter**, never typed in. A
  hardcoded date goes stale the moment you drill a different batch, and nothing
  in the output says the window was wrong — the query just returns rows from some
  other hour and they look like an answer.
- **The windows are deliberately asymmetric**: Hoover++ pinned to the batch hour,
  Hoover searched one hour before to three after, because "the event_date shifted
  between the two layouts" is the hypothesis under test. Pinning both sides to
  the same hour would assume the answer.

### 7.5 The validation tests

Every new case should get a `tests/test_<name>_case.py`. The existing
`test_insight_plus_case.py` is the template — these are the assertions worth
copying, all of which run without a warehouse:

| Assertion | Catches |
|---|---|
| the case loads at all | a YAML typo |
| it is a row case, not a schema check | the wrong shape |
| no `engine:` is set (or the right one is) | an accidental push-down |
| both sides share one `query_file` | the two-copies-drift problem returning |
| the sides differ **only** in the fact catalog | a copy-paste that left both on one catalog |
| no side var holds a `${placeholder}` | a placeholder that would never resolve |
| `rowparity list` works without `--param` | load-time substitution reaching a run-time value |
| both sides carry the sampling filter | the 409× sampling-ratio bug returning |
| the batch parameter substitutes on both sides | a half-templated query |
| omitting the batch **raises** rather than running | a green run over zero rows |
| the YAML ships no default batch | the same, from the other direction |
| `keys` == exactly the query's GROUP BY dimensions | a column added to the SELECT without updating `keys` |
| no metric is used as a key | a sum() in the key |
| `keys` are unique names | a duplicated dimension |
| arrays that may reorder are in `unordered_list_columns` | a pure ordering difference read as data |
| the case is keyed, not keyless | someone deleting `keys:` |

And a `test_<name>_sql_sync.py` asserting the SQL side:

| Assertion | Catches |
|---|---|
| the template has exactly the placeholders expected | a stray or missing `${...}` |
| **every** fact table reference goes through `${facts}` | one hardcoded catalog in 2,000 lines |

That last one is the highest-value test in the file. A single missed
`from mrm_log_flat.default.ad` makes one side read the wrong catalog for one
branch of a union, and nothing in the output would say so.

### 7.6 The loop

```bash
rowparity list scripts/cases_insight_plus              # 1. does it parse?
pytest tests/test_my_new_case.py -xvs                  # 2. is it wired right?
rowparity run scripts/cases_insight_plus \             # 3. run it
    --param arena.presto.var.process_batch_id=... \
    --html reports/run.html
```

Steps 1 and 2 touch no warehouse. Do not skip to step 3.

---

## 8. Reading the report, line by line

`rowparity run --html reports/run.html` writes one self-contained page. Sections
appear in this order, and the order is the intended reading order: each one
narrows the answer from the one above.

### 8.1 The metric tiles

```
Rows in Hoover   Rows in Hoover++   Missing in Hoover++   Added in Hoover++   Changed
       2,719            2,778                  149                 208            18
```

Named after your two sides, not "expected" and "actual" — a reader should not
have to remember which abstract word is the source of truth.

- **Missing in Hoover++** — a key combination Hoover produced and Hoover++ did not.
- **Added in Hoover++** — the reverse.
- **Changed** — the key exists on both sides, but at least one metric differs.

A balanced missing/added pair (149 vs 208) is suspicious. Real data loss is
rarely symmetric; **balance is the signature of a key that stopped matching**.
That is what §8.6 investigates.

### 8.2 Row differences by `slot_user_drop_off`

```
slot_user_drop_off   Rows in Hoover   Rows in Hoover++   Missing   Added   Changed   Differing
Removed                         412                381        41      12         3      13.6% ███
Included                      1,904              1,998        87     171        11       6.7% █▌
Not Applicable                  403                399        21      25         4       4.9% █
TOTAL                         2,719              2,778       149     208        18
```

**Triage. Which branch of the union is wrong?**

The query is a 3-way `UNION ALL` and `slot_user_drop_off` is a hardcoded literal
in each branch — `'Included'` from `${facts}.ad`, `'Removed'` from the
`ads_in_slot__*` array inside `${facts}.ack`, `'Not Applicable'` from ad-level
acks and error events. So it partitions the output exactly, and because it is
also a key its value is available for missing, added and changed rows alike at no
cost.

Without it, 149 missing + 208 added are one undifferentiated pile and the first
question has no answer. With it: differences concentrated in `Removed` point at
the nested-array unnest (the structurally fragile branch); an even spread points
at the shared predicates or the outer aggregate.

**Sorted by share, not by count** — a small group that is badly wrong outranks a
large one that is slightly off. The bar is scaled to the worst group, so the
comparison between rows is the point rather than the absolute number.

Counted over **every** row, not only the examples below.

### 8.3 Dimensions — 83

The key columns. This table answers **presence and type only**, and deliberately
carries no "diff rows" column.

Why: a key column *cannot* differ in value. If it did, the rows would not pair,
and the difference shows up as missing + added instead. Eighty-three zeroes in a
"Diff rows" column would read as "all 83 verified identical" when it actually
means "not applicable".

What to look for: a dimension present on one side only, or with a type mismatch.
Either breaks pairing for every row.

### 8.4 Metrics — 179

Everything not in the key. **Sorted worst first.** This is where value drift
lives, with a per-column status:

| Status | Meaning |
|---|---|
| `MATCHED` | on both sides, same type, values agree |
| `MATCHED - TYPE DIFF` | on both sides, types disagree |
| `MATCHED - VALUE DIFF` | on both sides, types agree, values differ |
| `DIFF` | present on one side only |

Search and filter this table rather than scrolling it — at 179 metrics the
useful question is "which ones moved", and the sort already answers it.

### 8.5 Near misses — one key column apart

```
Likely cause: dropping event_date pairs 137 of 149 missing rows with added
rows (91.9%). Those rows were not lost — they moved.

Drop from key    Pairs formed   Explains   Ambiguous   Example
event_date                137      91.9%           4   2026-08-27  ->  2026-08-26
process_batch_id            0          -           -
network_id                  0          -           -
```

**The diagnosis for a balanced missing/added split.** A key column that drifts
destroys the pairing, so one logical row is reported as a missing row *and* an
added row. Dropping each key column in turn and re-pairing shows which one is
responsible.

- **Pairs formed** — missing rows that find exactly one added-row partner once
  that column is ignored.
- **Explains** — that as a share of all missing rows. High means "this column is
  the whole story".
- **Ambiguous** — several added rows matched on the remaining columns, so no
  single pairing is known. Reported, never counted as a pair.
- **Example** — the actual pair of values, so you can see the drift.

**No query is run for this.** It re-pairs key tuples already in memory, so it
costs no warehouse time. The analysis caps at 20,000 missing rows and says so
when it does; the added side is never capped, because it is the lookup index and
truncating both would discard each kept row's partner at random and confidently
report "0 pairs".

### 8.6 Change signatures — 3 distinct pattern(s)

```
11x   filled_ads, filled_ads_duration, placed_ads, selected_ads      61.1% of changed rows
      by group:  Included 8  -  Removed 3

      Column                  Direction        Rows
      filled_ads              Hoover++ lower   11 / 11
      filled_ads_duration     Hoover++ lower   11 / 11
      placed_ads              Hoover++ lower   11 / 11
      selected_ads            Hoover++ lower   11 / 11

      most extreme row:  filled_ads 2 -> 1   |   filled_ads_duration 60 -> 30
```

**Changed rows grouped by *which columns* differ.** Thousands of changed rows
collapse into a handful of patterns instead of a flat example list.

Reading it:

- **`11x`** — eleven changed rows share this exact set of drifting columns. Not
  "eleven of something"; eleven *rows*. It is the group size.
- **the column list** — the signature itself: these four columns move together
  and nothing else moved in these rows. Four metrics that always move as a set
  is one bug, not four.
- **`61.1% of changed rows`** — this pattern's share of all 18 changed rows. Tells
  you whether you are looking at the main event or a footnote.
- **`by group: Included 8 - Removed 3`** — the same breakdown as §8.2, applied to
  this signature. Eight from one union branch, three from another.
- **Direction** — `Hoover++ lower` on 11 of 11 rows. A consistent direction is a
  systematic loss; `mixed` is scattered drift. These are different bugs and the
  distinction is the point of the column.
- **Rows** — `11 / 11` means every row in the signature moved in that column.
- **most extreme row** — the single largest movement, so you have one concrete
  case to chase.

There is deliberately **no Delta column**. It only ever rendered a range like
`-3 to -1`, which read as noise. The one case where the number is genuinely
diagnostic — every row moving by an *identical* amount — is surfaced as a
sentence instead, and only when it actually holds:

> Every row moved by the same amount: placed_ads -1, selected_ads -1 — a
> systematic shift, not scattered drift.

For the example above: two ads became one, sixty seconds of duration became
thirty. Per-ad duration is preserved — so this is not a duration bug, it is one
ad going missing and taking its duration with it.

### 8.7 Row examples — 50 shown

The individual rows, bounded by `max_examples`. Two columns:

**Kind** — named after your side, because "missing" only reads correctly if you
already know which side is the source of truth:

| Kind | Means |
|---|---|
| `Missing in Hoover++` | Hoover produced this row, Hoover++ did not |
| `Added in Hoover++` | Hoover++ produced a row Hoover did not |
| `Changed` | both produced it; a metric differs |

**Detail** — the row digested by your `row_summary:` groups rather than a
262-column dict truncated after the first four:

```
Branch    Included
Batch     20260827010000, 2026-08-27
Network   516429, 34007, 91024
Ad        349617594, 214174352, ...
Fill      filled, filled
```

Expand `all 262 columns` for the full row when you need it.

**One caveat worth knowing.** At live proportions — 149 missing, 208 added, 18
changed, `max_examples: 50` — the examples list fills **entirely with missing
rows** before an added or changed row is ever reached. Verified: the list is
`Counter({'missing': 50})`. The examples are a sample of the first thing
encountered, not a balanced sample of the problem. That is exactly why the
drill-down draws from the full key lists instead (§8.8), and why §8.2, §8.5 and
§8.6 are all computed over every row.

### 8.8 Drill-down SQL — `request__transaction_id`

```
Drill-down SQL - request__transaction_id for rows missing in Hoover++

ONE query per side, not one per row: the creative_id of every row missing in
Hoover++ goes into a single IN-list, so one scan per side covers all 149 of
them. Values are taken from every such row.

Not in this filter: 149 creative_id value(s) from rows added in Hoover++,
18 creative_id value(s) from rows changed. Add them with drilldown.kinds.
```

**Two ready-to-run queries — Hoover and Hoover++ — that you run yourself.** The
parity run says *which aggregate rows* disagree; it cannot say *which underlying
transactions* caused it, because the compared query is a GROUP BY over 83
dimensions and per-request identifiers are collapsed by the aggregation. That
answer lives one query further down, against the raw `ack` table.

How to use it: run both, then compare the two lists of `request__transaction_id`.
**The ids on one side only are the transactions that differ** — and that list is
what ENG needs to debug.

The scope line matters. The IN-list is built from **missing rows only** by
default. Merging all three kinds was the first shape and read badly: with an
83-column key one `creative_id` spans many aggregate rows, so missing + added +
changed collapses into a long list that looks like the whole column and says
nothing about why any id is in it — and `added` rows are largely the missing ones
again under a shifted `event_date`, contributing the same ids twice over.

The kinds left out are still counted and named, so a narrowed filter is visible
rather than something you have to know about: "no rows found" and "never asked
for" must not look identical. Widen it in the case file:

```yaml
drilldown:
  kinds: [missing, added, changed]
```

Values come from **every** differing row of the selected kinds, not from the
bounded examples list of §8.7 — possible because the bound column is part of the
key, so its value sits in the key tuple of every unpaired row.

### 8.9 The reading order, in one line

> Which branch (§8.2) → is the key drifting (§8.5) → what pattern do the changes
> follow (§8.6) → show me one (§8.7) → give me the transaction ids (§8.8).

---

## 9. Reference tables

### 9.1 Source types

| Type | Use for |
|---|---|
| `inline` | small expected fixtures written in the YAML |
| `csv` | flat CSV files |
| `parquet` | nested data, glob patterns |
| `arrow` / `feather` | `.arrow` / `.feather` files |
| `duckdb` / `sql` | local query engine; ideal for CI; reads parquet/iceberg |
| `snowflake` | key-pair auth via env vars; large tables should use `engine: snowflake` |
| `trino` | Trino/Presto cluster; large tables should use `engine: trino` |
| `iceberg` | Iceberg tables with optional row filtering |
| `delta` | Delta Lake / Unity Catalog; no Spark/JVM needed; supports time travel |
| `spark` | Spark SQL collected to Arrow via the PySpark Arrow bridge |

Any query-based source also accepts `query_file:` (a `.sql` path relative to the
case YAML) instead of inline `query:`. `query:` wins if both are present.

### 9.2 `compare:` options

| Option | Effect |
|---|---|
| `keys` | key columns; omit for keyless multiset mode |
| `select` | compare only these columns |
| `ignore_columns` | drop volatile columns (`loaded_at`) |
| `float_tolerance` | quantisation grid for floats |
| `coerce_numeric_to_float` | compare int and float columns as float |
| `trim_strings` | strip whitespace before hashing |
| `case_insensitive` | lower-case strings before hashing |
| `unordered_list_columns` | treat these arrays as sets, not sequences |
| `strict_columns` | fail when a column exists on one side only |
| `max_examples` | how many diff rows to keep (default 20) |
| `vectorized` | canonicalise whole columns at once (~1.2×; identical results) |
| `allow_empty` | permit a zero-row comparison |
| `allow_identical_sources` | permit both sides resolving to the same query |
| `breakdown_by` | split every difference by this key column |
| `near_miss` | run the one-key-column-apart analysis |

Unknown options **raise**. That is the point.

### 9.3 CLI

```bash
rowparity list  <path>
rowparity run   <path> [--param NAME=VALUE] [--select NAME ...] [--json F]
                       [--md F] [--html F] [--csv DIR] [--quiet]
                       [--heartbeat SECONDS] [--result-sink BACKEND:TARGET]
rowparity report --result-sink BACKEND:TARGET --html F
```

`--param` is repeatable and overrides both the case's `vars:` block and
`ROWPARITY_VAR_*` — but **not** a per-side `vars:` block (§4.5).

### 9.4 Where things live

| Module | Holds |
|---|---|
| `cases.py` | YAML loading, case shapes, `Case.run()`, the pre-flight guards |
| `sources.py` | the source handlers, twelve `type:` names; all return `pyarrow.Table` |
| `hashing.py` | canonicalisation rules and the Blake2b fingerprint |
| `compare.py` | keyed and keyless comparison → `ComparisonResult` |
| `near_miss.py` | which key column drifted |
| `drilldown.py` | the two investigation queries |
| `params.py` | `${…}` resolution, precedence, side vars |
| `run_report.py` + `templates/run_report.html` | the single-run HTML report |
| `report.py` | console, JSON, Markdown, CSV |
| `report_html.py` + `templates/report.html` | multi-run history from a result sink |
| `duckdb_pushdown.py` / `snowflake_pushdown.py` / `trino_pushdown.py` | in-warehouse engines |
| `trino_auth.py` / `snowflake_auth.py` | the single connection-builder per warehouse |
| `progress.py` | step timing and the heartbeat |
| `result_sink.py` / `history.py` | persisting and re-reading runs |

**Two HTML templates, two different commands.** `run_report.html` is one run
(`rowparity run --html`); `report.html` is pass-rate history across runs
(`rowparity report --html`). Do not confuse them.

---

## 10. Traps and dead options

### 10.1 Options that are currently dead

Both are still accepted by `compare:` and both now do **nothing**, because the
modules implementing them were deleted:

| Option | What happens now |
|---|---|
| `null_equivalence: true` | accepted, classifies nothing — `equivalence.py` is gone, and `_column_diffs` hardcodes `equivalent = False` |
| `ignore_columns_file:` / `ignore_columns_table:` | accepted, then silently discarded — `exclusions.py` is gone, so the named columns are still compared |

The second is the dangerous one: you name an exclusion file, no error is raised,
and the columns you meant to exclude are compared anyway. **Do not use either
until they are removed from `_COMPARE_KEYS` or reimplemented.**

Also broken: `pyproject.toml` still declares
`schemaparity = "rowparity.coverage_cli:main"`, but `coverage_cli.py` was
deleted — running `schemaparity` raises `ImportError`.

### 10.2 Case shapes that no longer exist

`schema_check:` and `coverage_check:` are gone. A YAML carrying either will fall
through to the `expected`/`actual` requirement and raise *"missing required field
'expected'"*, which does not name the real problem. The two surviving shapes are
`expected:`+`actual:` and `concept_check:`.

### 10.3 Substitution traps

- **`${...}` inside a SQL comment is a real substitution site.** Write placeholder
  names bare in header comments.
- **Spec values substitute at load time; `query_file` contents at run time.** A
  run-time value (like a derived batch hour) placed in a side `vars:` block
  breaks `rowparity list`. That is why the `drilldown:` block is excluded from
  load-time substitution.
- **A side `vars:` beats `--param`.** Intentional (§4.5), and surprising the first
  time.

### 10.4 Committing

`.pre-commit-config.yaml` runs four hooks: `ruff`, `ruff-format`,
`detect-private-key`, `detect-secrets`.

**`ruff-format` fails the commit when it reformats a file.** That is by design,
not an error: the hook rewrites your files, aborts the commit so you can review,
and leaves the changes unstaged. Re-stage and commit again:

```bash
git add -A && git commit -m "..."
```

Some files in this repo do not currently satisfy `ruff format`, so this can fire
on a file you only touched slightly.

If `detect-secrets` flags a real false positive, do **not** delete the finding and
do **not** widen the exclusions. Either rework the code so it does not look like a
secret, or mark the line `# pragma: allowlist secret` and re-run
`detect-secrets scan --baseline .secrets.baseline`.

### 10.5 Things that look like passes but are not

Each of these has a guard; know why the guard exists.

| Looks like | Actually | Guard |
|---|---|---|
| EQUIVALENT, exit 0 | both sides fetched zero rows | `_guard_empty` |
| EQUIVALENT, exit 0 | both sides ran the same query against one catalog | `_guard_identical_sides` |
| EQUIVALENT, exit 0 | the batch parameter defaulted to a batch that does not exist | no default is shipped |
| a 409× row-count ratio | one side sampled, the other not | the sampling filter lives in the shared `vars:` |
| every one of 262 columns flagged | the case is keyless and one side has extra rows | key on the dimensions |

---

*Function names here are taken from the source at the time of writing. Line
numbers are not quoted anywhere, because they drift.*
