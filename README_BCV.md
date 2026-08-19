# README_BCV — Backward-Compatible View verification inside rowparity

Everything about the BCV work: what it is, why each piece exists, how to run it,
and one scenario traced end to end through the code.

**Status: paused, not finished.** The schema half is verified against the live
staging cluster. The value half is built, unit-tested, and has **never completed
a live run** — every attempt so far failed before the comparison began. See
[Verification status](#10-verification-status) before trusting any of it.

Branch: `claude/rowparity-etl-review-rzyk89` · last BCV commit `0fde893`

---

## Table of contents

1. [What this is](#1-what-this-is)
2. [Why it lives inside rowparity](#2-why-it-lives-inside-rowparity)
3. [Scope: what was accepted and rejected](#3-scope-what-was-accepted-and-rejected)
4. [The files](#4-the-files)
5. [How to run it](#5-how-to-run-it)
6. [End-to-end walkthrough](#6-end-to-end-walkthrough-one-scenario-traced-through-the-code)
7. [Data flow and function flow](#7-data-flow-and-function-flow)
8. [Phase history](#8-phase-history)
9. [Bugs found, and what each one taught](#9-bugs-found-and-what-each-one-taught)
10. [Verification status](#10-verification-status)
11. [Open risks and what to do next](#11-open-risks-and-what-to-do-next)
12. [Glossary](#12-glossary)

---

## 1. What this is

A migration re-lays-out a set of wide event tables. The new layout is meant to be
a **backward-compatible view (BCV)** of the old one: same data, different shape.
Verification answers three questions:

| # | Question | How it is answered |
|---|---|---|
| 1 | Does the new layout have the same columns and types? | `schema_check` cases — **zero rows fetched** |
| 2 | For rows in both, do the values agree? | Keyed row comparison on a deterministic sample |
| 3 | Is a difference real, or only a different spelling of "absent"? | Global-equivalence classification |

The source of the design was an existing standalone tool ("BCV Analyzer", Python
+ Presto). That tool was read, decomposed, and its useful semantics
re-implemented inside rowparity. **The original tool has been deleted** — it is
not a dependency, and nothing here imports from it. Its `exclude.csv` file format
is the one artifact adopted verbatim, so an existing file works unchanged.

### The two tables

| Side | Meaning | Example |
|---|---|---|
| SRC / `expected` | The original layout, the source of truth | `mrm_log_flat.default.request` |
| BCV / `actual` | The migrated layout under test | `etl.public_test1.request` |

Catalog and schema are parameters, never literals — pointing at a different
environment is a flag, not an edit.

---

## 2. Why it lives inside rowparity

The instruction was to fit BCV into rowparity's existing design without breaking
its workflow. Concretely that meant:

* **No new top-level folder.** There is no `BCV/` directory. Cases live in
  `examples/cases_bcv/`, modules in `src/rowparity/`, scripts in `scripts/`.
* **Reuse the case shapes rowparity already has** rather than inventing a fourth.
  BCV's schema comparison *is* a `schema_check`; its value validation *is* a
  keyed row comparison.
* **Everything produces a `ComparisonResult`**, so the console reporter, JSON,
  Markdown, CSV, result sink, history, and HTML report all work with no changes.
* **Respect rowparity's canonicalization invariants.** In particular: *NULL is a
  distinct value and is never equal to anything else, including `""`.* BCV
  treated `null`, `""`, `0`, `[]` as interchangeable. That semantic could not be
  imported without corrupting the fingerprint, which is the whole basis of the
  framework — so it became a **classification layer** instead (§3, item 3).

Nothing in `compare.py`, `hashing.py`, or any push-down engine had to change to
support BCV.

---

## 3. Scope: what was accepted and rejected

Five capabilities were identified in the original tool. Three were taken.

### Accepted

**1. Schema comparison** → `examples/cases_bcv/schema_parity.yaml`
Three `schema_check` cases (request, slot, ad). Zero rows fetched — column names
and types come from Trino `DESCRIBE`, a catalog lookup. Safe against
production-sized tables.

**2. Value validation** → `examples/cases_bcv/value_parity.yaml`
Two cases, deliberately separate because they tolerate ingestion lag differently:

* `bcv_request_completeness` — did every sampled SRC transaction reach BCV?
  Key column only, so it is cheap. Reports missing and added honestly.
* `bcv_request_values` — for transactions present in **both**, do values agree?
  Pinned to the intersection, so a not-yet-ingested row cannot masquerade as a
  value defect.

> Run them as a pair. `bcv_request_values` alone *cannot* fail for missing data —
> that is the point of the pinning, and it reproduces the original tool's blind
> spot. Its README said: *"Only rows present in both SRC and BCV are compared;
> unmatched keys are skipped."* It therefore could not detect a dropped
> transaction at all. The completeness case closes that gap.

**3. Global equivalence** → `src/rowparity/equivalence.py`, `null_equivalence: true`
Classification only. A changed row still counts as changed and the case still
reports `DIFFERENT`; the CSV additionally labels which differences are merely a
different spelling of absence (`MATCHED - EQUIVALENT`). This is what makes 800
columns triageable without weakening the comparison.

### Rejected (explicitly, by decision)

**4. Usage analysis / backfill recommendation** — querying ETL/SOS systems to
decide which columns are worth backfilling. Out of scope: a lineage concern, not
a parity one.

**5. Presentation layer** — interactive prompts, Rich panels, spinners, generated
Markdown narrative. rowparity already has console/JSON/Markdown/CSV/HTML
reporters; a second presentation stack would be duplicate surface area.

---

## 4. The files

### Cases and data

| Path | What |
|---|---|
| `examples/cases_bcv/schema_parity.yaml` | 3 schema cases (request, slot, ad) |
| `examples/cases_bcv/value_parity.yaml` | 2 value cases + `param_queries:` for `batch_id` |
| `examples/cases_bcv/exclude.csv` | Per-table column exclusions, BCV's format verbatim |
| `examples/cases_bcv/sqls/src_request_keys.sql` | SRC side, completeness case |
| `examples/cases_bcv/sqls/bcv_request_keys.sql` | BCV side, completeness case |
| `examples/cases_bcv/sqls/src_request_values.sql` | SRC side, values case (intersection-pinned) |
| `examples/cases_bcv/sqls/bcv_request_values.sql` | BCV side, values case (intersection-pinned) |
| `examples/cases_bcv/sqls/latest_common_batch.sql` | Resolves `batch_id` automatically |

### Modules added or extended

| Module | Lines | Role |
|---|---|---|
| `src/rowparity/params.py` | 119 | `${name}` substitution; precedence `vars:` < `ROWPARITY_VAR_*` < `--param` |
| `src/rowparity/param_queries.py` | 90 | Resolve a parameter *from a query* (this is how `batch_id` self-resolves) |
| `src/rowparity/equivalence.py` | 96 | Global-equivalence classification, ported from BCV |
| `src/rowparity/exclusions.py` | 151 | `exclude.csv` loader + merge into `ignore_columns` |
| `src/rowparity/schema_introspect.py` | — | **Added `_describe_trino`** — the gap that blocked everything |
| `src/rowparity/report.py` | — | Per-column CSV reporter; capped console column lists |
| `src/rowparity/cases.py` | — | Parameter plumbing, exclusion keys, `null_equivalence` guard |
| `src/rowparity/schema_check.py` | — | Exclusion keys; rejects unknown block keys |
| `src/rowparity/compare.py` | — | `null_equivalence`, `equivalent` flag, schema-aware `summary()` |
| `src/rowparity/sources.py` | — | `variables` threaded through all 10 handlers |

### Scripts

| Script | What |
|---|---|
| `scripts/run_bcv.sh` | One entry point for all six steps, or any subset |
| `scripts/trino_connectivity_check.py` | 5 independent live checks (DNS → auth → query) |
| `scripts/find_batch_column.py` | Schema-only discovery of the batch column, per side |

### Tests — 178, all offline

| File | Tests |
|---|---|
| `tests/test_exclusions.py` | 33 |
| `tests/test_params.py` | 33 |
| `tests/test_equivalence.py` | 32 |
| `tests/test_bcv_value_cases.py` | 29 |
| `tests/test_csv_report.py` | 16 |
| `tests/test_param_queries.py` | 14 |
| `tests/test_bcv_schema_cases.py` | 11 |
| `tests/test_schema_introspect_trino.py` | 10 |

---

## 5. How to run it

### Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[duckdb,test]"
pip install "trino[sqlalchemy]"          # the Trino driver
```

### Connect

The cluster is reachable only over VPN.

```bash
export TRINO_HOST=presto-gateway.presto.stg.aws.fwmrm.net
export TRINO_PORT=8080
export TRINO_HTTP_SCHEME=https
export TRINO_USER=<your user>
read -rs TRINO_JWT_TOKEN && export TRINO_JWT_TOKEN
```

> **Never paste the token into a command line, a file, or a chat.** `read -rs`
> keeps it out of shell history. The repo runs `detect-secrets` and
> `detect-private-key` as pre-commit hooks precisely because credentials have a
> habit of ending up in git.

### Run everything

```bash
./scripts/run_bcv.sh
```

### Run one step

```bash
./scripts/run_bcv.sh tests demo      # offline, no VPN needed
./scripts/run_bcv.sh connect         # is the cluster reachable and the token good?
./scripts/run_bcv.sh columns         # do the configured batch column names exist?
./scripts/run_bcv.sh schema          # the 3 schema cases
./scripts/run_bcv.sh value           # the 2 value cases
```

| Step | VPN | What it does |
|---|---|---|
| `tests` | no | The 178 unit tests |
| `demo` | no | A/B proof that exclusions work, on inline data |
| `connect` | yes | DNS, TCP, auth, a trivial query |
| `columns` | yes | Verifies the configured batch column exists on each side |
| `schema` | yes | 3 `schema_check` cases, zero rows read |
| `value` | yes | 2 value cases, samples rows |

### Pass extra arguments

Everything after `--` goes to `rowparity run`:

```bash
./scripts/run_bcv.sh value -- --param sample_modulus=1          # whole batch, not 1-in-1000
./scripts/run_bcv.sh value -- --param batch_id=20260813060000   # pin a batch
./scripts/run_bcv.sh schema -- --param bcv_schema=public        # point at the real target
```

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Every step ran. Differences may have been found — that is not a failure |
| 1 | A step **errored**: bad config, no connection, unreadable case |
| 2 | Differences found **and** `--strict` was passed |
| 3 | Usage error or missing prerequisite |

The 0-vs-1 distinction is the point of the script. `rowparity run` returns 1 for
*both* "the tables differ" and "a case errored", and here those mean opposite
things: the migration is genuinely incomplete, so `DIFFERENT` is the honest
expected answer. A runner that fails on it is red on every run and stops being
read. Use `--strict` when you want CI to gate on differences.

### Running without the script

```bash
rowparity run examples/cases_bcv/schema_parity.yaml --csv reports/bcv --json reports/bcv/schema.json
rowparity run examples/cases_bcv/value_parity.yaml  --csv reports/bcv --json reports/bcv/value.json
rowparity list examples/cases_bcv
```

### Where output goes

`reports/bcv/` by default (`--out DIR` to change):

```
reports/bcv/
├── schema.log      console output, kept as evidence
├── schema.json     machine-readable ComparisonResults
├── schema.md       Markdown summary
├── schema/*.csv    per-column status — the file to actually read
├── value.log
├── value.json
├── value.md
└── value/*.csv
```

**The CSV is the one to read.** One row per column:

```csv
case,status,column,expected_type,actual_type,diff_rows
bcv_request_values,MATCHED,request__transaction_id,,,
bcv_request_values,MATCHED - VALUE DIFF,request__referrer,,,17
bcv_request_values,MATCHED - EQUIVALENT,request__tags,,,4
bcv_request_values,DIFF,request__legacy_flag,varchar,,
```

| Status | Meaning |
|---|---|
| `MATCHED` | On both sides, same type, no value differences |
| `MATCHED - TYPE DIFF` | On both sides, types disagree |
| `MATCHED - VALUE DIFF` | On both sides, values differ |
| `MATCHED - EQUIVALENT` | Values differ but only in how they spell "absent" |
| `DIFF` | Present on one side only |

This CSV exists because the console printed a **33,013-character** single line of
column names on real data. It is now 953 characters, with the full detail in the
CSV.

---

## 6. End-to-end walkthrough: one scenario traced through the code

**Scenario:** `bcv_request_completeness` — *did every sampled SRC transaction
reach the BCV table?*

Chosen because it exercises the full machine — parameters, a resolved-by-query
parameter, deterministic sampling, both source loads, the fingerprint core, keyed
comparison, and every reporter — while staying small enough to follow.

### The case

```yaml
# examples/cases_bcv/value_parity.yaml (abridged)
vars:
  src_catalog: mrm_log_flat
  src_schema: default
  bcv_catalog: etl
  bcv_schema: public_test1
  sample_modulus: "1000"
  src_batch_column: process_batch_id
  bcv_batch_column: process_batch_id
  skip_recent_batches: "1"

param_queries:
  batch_id:
    type: trino
    query_file: sqls/latest_common_batch.sql

cases:
  - name: bcv_request_completeness
    expected:
      type: trino
      query_file: sqls/src_request_keys.sql
    actual:
      type: trino
      query_file: sqls/bcv_request_keys.sql
    compare:
      keys: [request__transaction_id]
```

### The SQL

```sql
-- sqls/src_request_keys.sql
SELECT request__transaction_id
FROM ${src_catalog}.${src_schema}.request
WHERE ${src_batch_column} = '${batch_id}'
  AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id)))) % ${sample_modulus} = 0
```

The BCV side is identical apart from `${bcv_catalog}.${bcv_schema}` and
`${bcv_batch_column}`.

**Why the sampling is a hash and not `TABLESAMPLE`:** the two sides are two
independent queries with no coordination. `TABLESAMPLE BERNOULLI` would pick a
*different* random subset on each side, and every row would look missing. A hash
of the join key is a pure function — both sides independently select exactly the
same transactions. `sample_modulus=1` compares the whole batch.

### Step by step

#### 1. CLI entry — `cli.py`

`rowparity run examples/cases_bcv/value_parity.yaml --csv reports/bcv`
parses arguments and calls `discover_cases(path, params_)`.

#### 2. Load and parameterise — `cases.py`

```
discover_cases(path, params_)
└── load_cases_from_file(path, params_, resolve_queries=True)
    ├── yaml.safe_load                       → the raw dict
    ├── params.resolve_variables(...)        → merge vars: / env / --param
    │       precedence: vars: < ROWPARITY_VAR_* < --param
    ├── param_queries.resolve_param_queries(...)   ← batch_id resolved HERE
    └── _build_case(raw, ...)                 for each case
        ├── params.substitute_spec(...)       every ${name} in the whole case
        └── dispatch by shape → Case
```

**`batch_id` resolves itself.** `resolve_param_queries` runs
`sqls/latest_common_batch.sql`, which `INTERSECT`s the batches both sides know
about and picks the newest after skipping `${skip_recent_batches}` — so the
chosen batch is settled, not still landing. `_scalar()` requires exactly one row,
one column, not NULL; anything else is a hard error.

It resolves **once per file**, so both cases compare the same batch. Resolving
per case would let a batch landing mid-run compare two different populations.
Passing `--param batch_id=...` short-circuits the query entirely rather than
running it and discarding the result.

A literal default was deliberately rejected: it would name a batch that may not
exist, return zero rows on both sides, and report `EQUIVALENT` — a silent pass,
the worst possible outcome for a verification tool.

#### 3. Build the comparison config — `Case.config()`

Validates the `compare:` keys, then resolves any exclusion file into
`ignore_columns` (this case has none) and returns a `CompareConfig`.

#### 4. Fetch both sides — `sources.py`

```
Case.run(base_dir)
├── load_source(self.expected, base_dir, variables) → _trino(...)
│   ├── resolve_query(spec, base_dir, variables)
│   │      reads sqls/src_request_keys.sql, substitutes every ${name}
│   ├── trino_auth.connect(spec)     env vars / connection: block; JWT here
│   ├── cur.execute(sql); cur.fetchall()
│   └── pa.Table.from_pylist([...])  → pyarrow.Table
└── load_source(self.actual, ...)   → the same, BCV side
```

Both sides are now `pyarrow.Table`. **Everything downstream is engine-agnostic** —
this is the seam that lets one comparison engine serve Trino, Snowflake, DuckDB,
Parquet, and inline fixtures alike.

#### 5. Compare — `compare.py` → `hashing.py`

```
compare_tables(expected_tbl, actual_tbl, cfg)
├── _resolve_columns(...)        intersect columns, drop ignore_columns
└── _compare_keyed(...)          because cfg.keys is set
    for each row:
    ├── hashing.canon_row(schema, row, columns, canon_cfg)
    │   └── canon_value(dtype, value, cfg) per column
    │         · columns sorted by name        → column order irrelevant
    │         · int32 ≡ int64                 → engine width differences vanish
    │         · decimals: trailing zeros stripped (1.10 ≡ 1.1)
    │         · timestamps → UTC
    │         · floats → quantized to the tolerance grid
    │         · list ORDERED; struct/map UNORDERED (keys sorted)
    │         · NULL is distinct — never equal to "" or {}
    └── hashing.row_digest(canon)  → blake2b(…, digest_size=16)
```

Two rows are the same row when their 16-byte digests match. Keyed on
`request__transaction_id`, this yields:

* **missing** — key in SRC, absent from BCV → *dropped by the migration, or not yet ingested*
* **added** — key in BCV, absent from SRC
* **changed** — key on both sides, digests differ

For this case only the key column is selected, so "changed" cannot occur —
the case is purely about presence.

#### 6. Report — `report.py`

```
render_console(result, case_name)     → stdout
write_reports(results, json, md)      → Markdown FIRST, then JSON
write_csv_reports(results, out_dir)   → one row per column
```

`ComparisonResult` is the universal currency — the same object feeds the console,
JSON, Markdown, CSV, the result sink, and the HTML history report.

#### 7. Exit

`rowparity run` returns 1 if any case is not equivalent. `run_bcv.sh` then reads
the JSON to distinguish "differences found" from "a case errored", and verifies
that no excluded column reached the comparison.

### What you see

```
Case 'bcv_request_completeness': [DIFFERENT] keyed on ['request__transaction_id']
  | expected=1204 actual=1201 | missing=3 added=0 changed=0
  first 3 difference(s):
  - MISSING key=(a3f2...)
  - MISSING key=(b71c...)
  - MISSING key=(c904...)
```

Three sampled transactions did not reach BCV. At `sample_modulus=1000` that
implies roughly 3,000 across the batch — or those three simply had not landed
yet, which is why the case is run alongside the pinned values case rather than
alone.

---

## 7. Data flow and function flow

### Data flow

```
Trino cluster (SRC)                    Trino cluster (BCV)
mrm_log_flat.default.request           etl.public_test1.request
        │                                       │
        │  DESCRIBE (schema cases: metadata only, zero rows)
        │  SELECT   (value cases: sampled rows)
        ▼                                       ▼
   trino_auth.connect() ──────────────── trino_auth.connect()
        │                                       │
        ▼                                       ▼
   pyarrow.Table                           pyarrow.Table
        └───────────────┬───────────────────────┘
                        ▼
              CompareConfig (keys, ignore_columns,
              float_tolerance, null_equivalence)
                        ▼
        canon_row() → canon_value() per column
                        ▼
              row_digest() → blake2b 16 bytes
                        ▼
        multiset / keyed comparison  (row order irrelevant)
                        ▼
                 ComparisonResult
                        ▼
    ┌──────────┬────────────┬──────────┬──────────────┐
  console     JSON      Markdown      CSV        result sink
                                   (per column)   (history → HTML)
```

### Function flow, by case shape

**Schema case** (`schema_check:`) — zero rows, ever:

```
cli.run
└── discover_cases                    cases.py
    └── _build_case → SchemaCheckCase  schema_check.py
        └── .run()
            ├── merge_ignore_columns              exclusions.py
            ├── describe_source(expected)         schema_introspect.py
            │   └── _describe_trino → DESCRIBE <table>
            ├── describe_source(actual)
            └── run_schema_check → ComparisonResult
```

**Value case** (`expected:`/`actual:`) — the walkthrough above:

```
cli.run
└── discover_cases                    cases.py
    ├── resolve_variables             params.py
    ├── resolve_param_queries         param_queries.py    ← batch_id
    └── _build_case → Case
        └── .run()
            ├── config() → merge_ignore_columns   exclusions.py
            ├── load_source(expected) → _trino    sources.py
            ├── load_source(actual)   → _trino
            └── compare_tables                    compare.py
                ├── canon_row / row_digest        hashing.py
                └── globally_equivalent           equivalence.py  (classification)
```

### The three ways a column leaves the comparison

Worth keeping straight, because they are easy to confuse:

| Mechanism | Where | Effect |
|---|---|---|
| `select:` | `compare:` | Only these columns are compared |
| `ignore_columns:` | `compare:` / `schema_check:` | Named columns dropped |
| `ignore_columns_file:` + `ignore_columns_table:` | same | Dropped per `exclude.csv`, unioned with the inline list |

### exclude.csv

BCV's format, unchanged:

```csv
table,column
request,__path__
slot,__path__
request,__offset__
```

Each row says *for this table, skip this column*. Rows for other tables are
ignored, which is what lets one file serve a whole suite — the same four storage
metadata columns (`__path__`, `__offset__`, `__file_size__`, `__footer_size__`)
apply to six tables, and inline lists would be 24 lines drifting apart.

The keys resolve into `ignore_columns` and are then **dropped**, so
`CompareConfig` and every engine reading it stay unaware a file was involved. No
engine needed changing.

**Two deliberate divergences from BCV's loader**, both toward failing loudly:

| Situation | BCV | Here | Why |
|---|---|---|---|
| File missing | empty set | **raises** | A typo'd path silently excludes nothing, discovered much later as a failure on columns believed out of scope |
| Table not in the file | empty set | **raises**, listing known tables | `ignore_columns_table: requests` would otherwise exclude nothing, silently |
| Column doesn't exist | ignored | **ignored** | BCV's file lists the same 4 columns for all 6 tables and they are not all present on every one — an exclusion states intent, not a fact about the schema |

### Global equivalence

`equivalence.py`, enabled with `null_equivalence: true`:

```python
_GROUPS = [
    frozenset({"\\n", "", "null", "none", "0", "0.0", "false"}),
    frozenset({"\\n", "", "null", "none", "[]", "{}"}),
]
```

Two values are "globally equivalent" when both normalise into the same group —
an empty array where the other side has null, a `0` where the other has nothing.

**This is classification only.** Such rows still count as changed and the case
still reports `DIFFERENT`. It separates *"the values disagree"* from *"the values
agree but spell absence differently"* in the CSV. It never touches the
fingerprint, because rowparity's core invariant is that NULL is distinct from
everything — folding equivalence into the hash would corrupt every comparison in
the framework, not just BCV's.

Refused with any push-down engine (`engine: duckdb|snowflake|trino`), which
fingerprints in-warehouse and never sees individual values — accepting the option
there would silently classify nothing.

---

## 8. Phase history

Oldest first.

### Phase 0 — the blocker (`92431ef`, 2026-08-12)

`schema_introspect.py` had **no Trino describer**. `FEATURES.md` claimed Trino
support in §13 and §14, and its headline example compared a Snowflake table
against `type: trino` — that case raised. Every BCV idea was blocked behind it.

Added `_describe_trino`, using `DESCRIBE` for `table:` (the same mechanism the
original tool used, so type strings match) and a `LIMIT 0` probe only for derived
queries. Added `scripts/trino_connectivity_check.py`.
**Verified live** against the 1697-column `request` and 837-column BCV table.

### Phase 1 — schema parity (`770df25`, 2026-08-13)

Three `schema_check` cases. Status mapping from the original tool:

| BCV Analyzer status | rowparity field |
|---|---|
| `DIFF` (bcv_field empty) | `columns_only_in_expected` |
| `DIFF` (src_field empty) | `columns_only_in_actual` |
| `MATCHED - TYPE DIFF` | `type_mismatches` |
| `MATCHED` | `compared_columns` |

Deliberately **not** tagged `xfail`: xfail would make the run green while columns
are missing and red once they finally match — backwards.
**Verified live** on all three tables.

### Phase 2 — parameterisation (`18aaa4e`, 2026-08-13)

`params.py`. `${name}` anywhere in a case, including inside `query_file` contents.
Precedence `vars:` < `ROWPARITY_VAR_*` < `--param`; names case-insensitive; an
unresolved name is a hard error naming the variable and all three ways to supply
it. Pointing at another environment became a flag rather than an edit per case.

### Phase 3 — value parity (`e6a004c`, 2026-08-13)

The two value cases, deterministic hash sampling, and intersection pinning via
semi-join. Sampling was chosen to be **pushed into SQL** and **deterministic**
rather than random — see the walkthrough for why `TABLESAMPLE` cannot work
across two independent queries.

Followed by `4220fab`: `param_queries.py`, so `batch_id` resolves itself from the
warehouse instead of being typed in by hand.

### Phase 4 — global equivalence (`42df683`, 2026-08-14)

`equivalence.py` ported from the original tool via git history, wired as
`null_equivalence: true` — classification only, never in the fingerprint.

### Supporting work

* `cbdecf0` — per-column CSV report, replacing a 33,013-character console line
* `ec9ad7b` — the original tool removed; its validation evidence kept traceable in history
* `5f418b1` — both batch columns confirmed as `process_batch_id` by `DESCRIBE`
* `e79046c` — `exclude.csv` support
* `ab51100` — `scripts/run_bcv.sh`
* `0fde893` — scripts made directly executable

---

## 9. Bugs found, and what each one taught

Every one of these was found by *running* something, not by reading it.

**1. `numpy` undeclared** (`c53d54d`)
`hashing.py` imported it; `pyproject.toml` never declared it (pyarrow 25 declares
no numpy dependency). A fresh install succeeded and then every entry point died.
Fixed by declaring it, plus `tests/test_packaging.py` to guard the whole class of
bug. *Lesson: a passing test suite in a developed environment says nothing about
a fresh install.*

**2. `--json` destroyed both reports** (`92e6f56`)
`json.dump` without `default=`, and JSON was written *before* Markdown — so a
`Decimal` in the data crashed the run and lost the Markdown too. Fixed with
`default=str` and Markdown-first ordering.

**3. `test_history_report` rotting** (`f12abd0`)
Hardcoded a base date against a rolling window. The deeper bug: the fixture
*added* day offsets, making its "outside a 21-day window" assertion unsatisfiable
at any date. Anchored to `now − 2 days` and inverted the offsets to "days ago."

**4. Circular placeholder** (`f18e56b`)
A comment I wrote — `-- Resolve ${batch_id} automatically` — inside
`latest_common_batch.sql` made the resolver demand its own output. Every BCV run
died at load. Fixed plus two guards. *Lesson: prose inside a parameterised file
is still parameterised.*

**5. Wrong batch column, twice** (`b7c83cc`, `dcdf4be`, `5f418b1`)
The batch column was hardcoded from the original tool's README (`batch_id` on the
target). A live run died with `COLUMN_NOT_FOUND` *after* the schema cases had
passed. Parameterised per side and added `find_batch_column.py`. Documentation
then said `process_batch_id`/`batch_id`; `DESCRIBE` proved the target has **no
`batch_id` at all** and both sides use `process_batch_id`. *Lesson: documentation
lost to `DESCRIBE` twice — there is now a test pinning the verified names.*

**6. Equivalence recursion** (Phase 4)
Removing the original's `_null_safe_equal` fast path broke its own README example
(`[[], None]` vs `[None, None]`), because recursion reaches equal sub-values.
Restored, with a test.

**7. A test that split on `"IN ("`** matched a *comment* first — the second
prose-in-SQL bug. Added `_strip_comments` before structural assertions.

**8. A smoke test that proved nothing** — the first parameterisation test had both
variants passing. Re-run with the expected side pinned so only the parameterised
side could move.

**9. Three bugs in `run_bcv.sh` itself** (`ab51100`), all found by running it:
   * The exclusion check **passed vacuously** when every case errored — an empty
     report trivially contains no excluded column. Now an empty report fails.
   * Detecting errors by grepping for `ERROR` would also match a *data* value
     containing the word; a status column holding `'ERROR'` is entirely plausible
     here. Anchored to the CLI's exact line format.
   * `python` is not a guaranteed name; resolved via `python3`/`python`.

---

## 10. Verification status

Be precise about this — it is the difference between "built" and "works."

### Verified against the live cluster

| What | Evidence |
|---|---|
| Trino auth (JWT via gateway) | `trino_connectivity_check.py`, 5/5 steps |
| `_describe_trino` | 1697 SRC columns, 837 BCV columns returned |
| All 3 schema cases | Ran, produced correct buckets |
| Deterministic sampling functions | `xxhash64`/`to_utf8`/`from_big_endian_64` accepted by the cluster |
| Batch column names | `DESCRIBE` on both sides |

### Verified offline only

| What | Evidence |
|---|---|
| Exclusions | 33 tests + an A/B where the same data passes with and fails without |
| Parameters, `param_queries` | 47 tests |
| Global equivalence | 32 tests |
| CSV report | 16 tests |
| `run_bcv.sh` | Every step run; error paths exercised with a dead connection |

### Not verified at all

**The value cases have never completed a live run.** Three attempts, three
failures *before* the comparison began: a circular placeholder, then
`COLUMN_NOT_FOUND` twice. The blockers are fixed and the batch column names are
now confirmed by `DESCRIBE`, but "should work" is not "does work."

Also unverified: `run_bcv.sh`'s `PASS`/`DIFF` classification on a run that
actually reaches the warehouse. The error branch was tested with a dead
connection and the success branch offline; the live combination is untested by
definition.

---

## 11. Open risks and what to do next

When BCV resumes, this is the list — ordered by when a live run will hit it.

**1. `ignore_columns: []` is empty in all four cases.** Deliberate: guessing
which columns to exclude is worse than a noisy first run that names them. The
parent-structure-node columns — a varchar `request__context` sitting alongside
its exploded `request__context__*` children — will show up in the CSV, and the
list gets populated from what is actually there. This is the one piece of
configuration that genuinely needs live data in front of it.

**2. `sources.py:_trino` type inference.** It builds Arrow via
`pa.Table.from_pylist()` with **no explicit schema**. A column that is all-`None`
in the sample can infer as Arrow `null` type and read as a mismatch that is not
one. If the CSV shows a column diffing with nothing visibly wrong, suspect this
first. Fix would be to pass an explicit schema derived from `cur.description`.

**3. The 1,697-column `SELECT *`** in the values case, and **the `INTERSECT`
batch resolver's cost**. Both may be merely slow rather than wrong. The resolver
has a documented `$partitions` swap ready if it drags.

**4. A possible real migration defect.** The schema cases flagged
`array(array(array(bigint)))` → `array(array(array(integer)))` on **both**
`request` and `slot`. That is a **narrowing** conversion, which can silently
truncate. The other 8 slot mismatches widen, which is safe. Worth raising with
the layout owner — this is a finding, not a tooling problem.

**5. `engine: trino` push-down has never run against a live cluster.** The BCV
cases do **not** use it (they use the default engine), so this is not blocking.
But if these comparisons ever outgrow the default engine, note that the Snowflake
push-down history is the cautionary tale: two real bugs there were found only by
running live, and neither could have been caught by a fake-cursor test.

### Related pre-existing TODOs

Not BCV work, but they touch the same files — see `CLAUDE.md` for the full list:
Iceberg push-down source; `schema_mapper.py`/`coverage_cli.py` have no tests;
`coverage_check` cases break `rowparity run` if they sit in a scanned directory.

---

## 12. Glossary

| Term | Meaning |
|---|---|
| **BCV** | Backward-Compatible View — the migrated layout that must reproduce the original's data |
| **SRC** | The original layout, the source of truth; `expected` in a case |
| **Fingerprint** | Blake2b 16-byte digest of a canonical row. Equality of multisets of fingerprints *is* table equality |
| **Canonicalization** | Reducing a value to a comparable form: sorted columns, UTC timestamps, stripped decimal zeros, quantized floats |
| **Keyed comparison** | Match rows on a business key → missing / added / changed |
| **Keyless comparison** | Multiset diff, no key — order-independent by construction |
| **Intersection pinning** | Restricting both sides to keys present in both, via semi-join, so ingestion lag cannot look like a value defect |
| **Deterministic sampling** | Sampling by a hash of the join key, so two independent queries pick the same rows |
| **Global equivalence** | Classifying a difference as "only a different spelling of absence". Never affects the fingerprint |
| **`ComparisonResult`** | The universal output object every case shape produces |
| **Push-down** | Fingerprinting inside the warehouse rather than in Python. Not used by BCV |
| **`schema_check`** | A case shape comparing only column names and types, fetching zero rows |
| **Change signature** | Changed rows grouped by *which* columns differ, so thousands collapse into a few patterns |

---

## Appendix — reference

### Quick command reference

```bash
./scripts/run_bcv.sh --help                    # all options
./scripts/run_bcv.sh tests demo                # offline sanity, no VPN
./scripts/run_bcv.sh                           # everything
./scripts/run_bcv.sh schema --strict           # CI gating on differences
./scripts/find_batch_column.py --table slot    # which column carries the batch
rowparity list examples/cases_bcv              # what cases exist
```

### Environment variables

| Variable | Required | Default |
|---|---|---|
| `TRINO_HOST` | yes | — |
| `TRINO_USER` | yes | OS user |
| `TRINO_PORT` | no | 8080 |
| `TRINO_HTTP_SCHEME` | no | `http` |
| `TRINO_CATALOG` / `TRINO_SCHEMA` | no | — |
| `TRINO_JWT_TOKEN` | for this gateway | — |
| `TRINO_PASSWORD` | alternative (Basic auth) | — |
| `ROWPARITY_VAR_<NAME>` | no | supplies `${name}` |

A per-case `connection:` block overrides any of them.

### Case parameters

| Parameter | Default | What |
|---|---|---|
| `src_catalog` / `src_schema` | `mrm_log_flat` / `default` | SRC location |
| `bcv_catalog` / `bcv_schema` | `etl` / `public_test1` | BCV location |
| `src_batch_column` / `bcv_batch_column` | `process_batch_id` | Batch column per side |
| `sample_modulus` | `1000` | 1 row in N; `1` = whole batch |
| `skip_recent_batches` | `1` | Newest batches to skip when auto-resolving |
| `batch_id` | resolved by query | The batch under comparison |
