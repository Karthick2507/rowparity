# Code flow — what happens when you run a case

A line-by-line walkthrough of one command, from the shell to the exit code.

```bash
rowparity run scripts/cases_insight_plus \
    --param arena.presto.var.process_batch_id=20260812010000 \
    --csv reports/insight_plus 2>&1 | tee run.log
```

The example is the Hoover / Hoover++ parity case — two Trino queries, keyed on
83 columns — but the path is the same for every row-comparison case. Where a
step behaves differently for another source type or case shape, that is called
out.

> Function names in this document are checked against the source by
> `tests/test_code_flow_doc.py`, so a rename breaks a test rather than leaving
> the doc quietly wrong. Line numbers are indicative and drift with edits.

---

## Table of contents

1. [Process start](#1-process-start)
2. [`_run` starts up](#2-_run-starts-up)
3. [Loading the case](#3-loading-the-case)
4. [Per-case execution](#4-per-case-execution)
5. [Fetching each side](#5-fetching-each-side)
6. [The comparison](#6-the-comparison)
7. [Reporting and exit](#7-reporting-and-exit)
8. [The whole path](#8-the-whole-path)
9. [Three seams worth knowing](#9-three-seams-worth-knowing)

---

## 1. Process start

`pyproject.toml` maps the console script:

```toml
[project.scripts]
rowparity = "rowparity.cli:main"
```

The shell invokes **`cli.main()`**, which builds the argparse tree and ends at:

```python
return args.func(args)     # → _run(args)
```

The three arguments land as `args.path="scripts/cases_insight_plus"`,
`args.param=["arena.presto.var.process_batch_id=20260812010000"]`,
`args.csv="reports/insight_plus"`.

---

## 2. `_run` starts up

`cli._run()`.

### 2.1 Progress first, before anything can be slow

```python
progress.configure(enabled=not getattr(args, "quiet", False),
                   heartbeat_seconds=getattr(args, "heartbeat", None))
```

Deliberately the **first statement**. `progress` is off by default so library
and pytest use stay silent and no heartbeat threads are created; the CLI
switches it on.

Output goes to **stderr**, every write flushed. That is why `2>&1 | tee run.log`
shows heartbeats as they happen instead of in one burst at the end — and why
`rowparity run > results.txt` keeps stdout clean and parseable.

### 2.2 Parse `--param`, then load cases

```python
try:
    cli_params = parse_cli_params(getattr(args, "param", None))
    cases = discover_cases(args.path, cli_params)
except ParamError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    return 2
```

`params.parse_cli_params()` splits on the **first** `=` only, so a value
containing `=` survives intact. You get
`{"arena.presto.var.process_batch_id": "20260812010000"}`.

The whole block is wrapped: a bad parameter exits **2** (a configuration
problem), which stays distinct from **1** (a case differed). That distinction
propagates all the way out and is what lets CI tell "the tool could not run"
from "the data disagrees".

---

## 3. Loading the case

### 3.1 `cases.discover_cases()`

`args.path` is a directory, so it globs `**/*.yml` and `**/*.yaml` recursively,
sorts for a stable order, and calls `load_cases_from_file` on each.

### 3.2 `cases.load_cases_from_file()`

```python
doc = yaml.safe_load(fh) or {}
multi         = "cases" in doc
file_vars     = doc.get("vars", {}) if multi else {}
param_queries = doc.get("param_queries", {}) or {}
raw_cases     = doc["cases"] if multi else [doc]
```

A `param_queries:` block — a parameter resolved by *querying the warehouse*
rather than being typed in — resolves **once per file here**, never per case.
Two cases keying off "the latest batch" must see the *same* batch: resolving
per case would let a batch landing mid-run compare two different populations,
which is exactly the kind of difference that looks like a data defect.

`rowparity list` passes `resolve_queries=False` so merely listing cases never
touches a warehouse.

### 3.3 `cases._build_case()` — where `${…}` disappears

```python
case_vars = raw.pop("vars", None) or {}
variables = params.resolve_variables(file_vars, case_vars, cli_params)
raw = params.substitute_spec(raw, variables, where=f"case '{raw['name']}' …")
```

`params.resolve_variables()` merges four sources, later winning:

```
file vars:   <   case vars:   <   ROWPARITY_VAR_*   <   --param
```

All names are lower-cased, so `${BATCH_ID}` and `${batch_id}` are one name.
Dotted names are recognised too (`${arena.presto.var.process_batch_id}`) —
query files templated by another system carry namespaced names, and a
placeholder that is neither substituted *nor* reported unresolved reaches the
engine as literal text inside quotes: a valid predicate matching nothing.

`params.substitute_spec()` walks the **entire raw case dict** before any shape
dispatch, so every case type gets substitution for free and no spec can reach
an engine still holding a placeholder.

Then shape dispatch:

| Top-level block | Built as |
|---|---|
| `schema_check:` | `SchemaCheckCase` |
| `concept_check:` | `ConceptCheckCase` |
| `expected:` + `actual:` | `Case` |

The `Case` carries `variables` forward for later. **The SQL files have not been
read yet** — `query_file` contents are resolved at run time.

---

## 4. Per-case execution

`cli._run()`'s loop:

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

### 4.1 `Case.config()`

```python
unknown = set(self.compare) - _COMPARE_KEYS
if unknown:
    raise ValueError(f"case '{self.name}': unknown compare option(s): {sorted(unknown)}")
options = {k: v for k, v in self.compare.items() if k not in _EXCLUSION_KEYS}
```

Unknown keys are **rejected**, not ignored — a typo'd `ignore_colums:` would
otherwise silently do nothing.

The exclusion keys (`ignore_columns_file` / `ignore_columns_table`) resolve into
`ignore_columns` and are then **dropped**, so `CompareConfig` and every engine
reading it stay unaware a file was involved. No engine needed changing to
support exclusion files.

### 4.2 `Case.run()`

```python
progress.emit(f"Case '{self.name}'")

if self.engine in ("duckdb", "snowflake", "trino"):
    ...push-down: fingerprinting happens inside the warehouse...
else:
    with progress.step(f"expected  ({self.expected.get('type','?')})") as st:
        expected_tbl = load_source(self.expected, base_dir=base_dir, variables=self.variables)
        st.result(progress.describe_table(expected_tbl))
    expected_seconds = st.elapsed
    # …same for actual…
    with progress.step("comparing") as st:
        result = compare_tables(expected_tbl, actual_tbl, cfg)
```

With no `engine:` set, this takes the **default engine** branch: fetch both
sides into memory, compare in Python.

Each `progress.step()` prints `-> …`, starts a daemon heartbeat thread, runs the
body, then prints `OK … <elapsed> <summary>`. On exception it prints
`FAILED … <elapsed>` and re-raises untouched — "it failed after four minutes" is
still worth being told.

---

## 5. Fetching each side

`sources.load_source()` dispatches on `spec["type"]` through `_HANDLERS`. For
`type: trino` that is `sources._trino()`:

```python
query = resolve_query(spec, base_dir, variables)     # ← the SQL file is read HERE
con = _trino_connect(spec)
try:
    cur = con.cursor()
    cur.execute(query)
    rows = cur.fetchall()
    if not rows:
        col_names = [d[0] for d in (cur.description or [])]
        return pa.table({col: [] for col in col_names})
    col_names = [d[0] for d in cur.description]
    return pa.Table.from_pylist([dict(zip(col_names, row)) for row in rows])
finally:
    con.close()
```

**`sources.resolve_query()`** resolves `query_file` relative to the YAML's
directory, reads it, and calls `params.substitute()` on the **file contents**.
This is where `${arena.presto.var.process_batch_id}` becomes
`20260812010000`. An unresolved name raises `ParamError` here — caught by the
loop above, reported, exit 1.

**`trino_auth.connect()`** merges a case's `connection:` block over `TRINO_*`
environment variables (**YAML wins**), requires `host`, and picks an auth mode:

| Mode | Trigger | Wire format |
|---|---|---|
| JWT | `TRINO_JWT_TOKEN` | `Authorization: Bearer <token>` |
| Basic | `TRINO_PASSWORD` | HTTP Basic |
| None | neither | no auth header |

Secrets are read from the **environment only** — there is no code path that
reads a token or password out of a case file, because case files are committed
to git.

Three details in `_trino` worth knowing:

* **`fetchall()` materialises everything.** No streaming or batching, so memory
  scales with the result. Comfortable at ~100k rows × 262 columns; not at
  millions.
* **The zero-row branch preserves columns** from `cursor.description`. Without
  it an empty result would lose its schema entirely.
* **`from_pylist` has no explicit schema**, so Arrow infers types from Python
  values. A column that is entirely `NULL` can infer as Arrow `null` type — the
  one latent trap on this path.

Both sides are now `pyarrow.Table`. **Nothing downstream knows the data came
from Trino.**

---

## 6. The comparison

`compare.compare_tables()`.

### 6.1 Column resolution — `compare._resolve_columns()`

```python
only_exp  = [c for c in exp_cols if c not in act_set]
only_act  = [c for c in act_cols if c not in exp_set]
candidate = cfg.select if cfg.select else [c for c in exp_cols if c in act_set]
compared  = [c for c in candidate if c not in set(cfg.ignore_columns)]
type_mismatches = [(c, str(et), str(at)) for c in compared if not et.equals(at)]
```

**This one function produces the three column states:**

| Result field | Reported as |
|---|---|
| `compared_columns` | `MATCHED` |
| `columns_only_in_expected` / `columns_only_in_actual` | `DIFF` (unmatched) |
| `type_mismatches` | `MATCHED - TYPE DIFF` |

A separate zero-row schema pass is therefore unnecessary for a row comparison —
column status falls out of it for free.

`compare_tables` also stores both Arrow schemas on the result so reporters can
print each column's type on each side.

### 6.2 Materialise and dispatch

```python
exp_rows = expected.to_pylist()
act_rows = actual.to_pylist()
if cfg.keys:  _compare_keyed(...)
else:         _compare_keyless(...)
```

### 6.3 Keyed — `compare._compare_keyed()`

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
**raw as a dict key** — the key is *not* hashed. Canonicalisation applies here
too, so `unordered_list_columns` affects which rows pair up: `[7, 12]` and
`[12, 7]` land in the same bucket only if that column is declared unordered.

Then three set operations:

```python
for key in exp_keys - act_keys:  result.missing_count += len(idxs)   # expected only
for key in act_keys - exp_keys:  result.added_count   += len(idxs)   # actual only
for key in exp_keys & act_keys:                                       # paired
    e_digest = row_digest(canon_row(exp_schema, e, cols, canon_cfg))
    a_digest = row_digest(canon_row(act_schema, a, cols, canon_cfg))
    if e_digest != a_digest:
        result.changed_count += 1
        coldiffs = _column_diffs(...)
```

### 6.4 Keyless — `compare._compare_keyless()`

No key, so no pairing. Every row becomes a fingerprint and the two **bags** are
subtracted:

```python
canon = canon_row(schema, row, cols, canon_cfg)
d     = row_digest(canon)
exp_counts[d] += 1
...
delta = exp_counts[d] - act_counts[d]
if delta > 0:   result.missing_count += delta
elif delta < 0: result.added_count   += -delta
```

`changed_count` stays 0 by construction — without a key nothing can pair a
missing row with the added row it corresponds to.

To recover *some* attribution, the same pass accumulates an order-independent
value fingerprint per column: the sum of the hashes of that column's canonical
values. Two columns hold the same multiset iff their sums match. Addition, not
XOR, so multiplicity survives — `[1,1,2]` and `[1,2,2]` hold the same set and
different multisets. One integer per column rather than a `Counter` of a million
values, which at hundreds of columns would not fit in memory.

| | Keyless | Keyed |
|---|---|---|
| What identifies a row | its full-row digest | the key tuple |
| Is the key hashed? | n/a | **no** — used raw as a dict key |
| Detects any difference | yes | yes |
| Reports `changed` | never | yes |
| Names the drifting columns | whole-column multisets only | exactly, per row |

### 6.5 The fingerprint — `hashing`

```python
def canon_row(schema, row, columns, cfg):
    return tuple((name, canon_value(schema.field(name).type,
                                    row.get(name), cfg,
                                    unordered_list=name in cfg.unordered_list_columns))
                 for name in columns)          # columns pre-sorted by caller

def row_digest(canon):
    return hashlib.blake2b(repr(canon).encode("utf-8"), digest_size=16).digest()
```

`hashing.canon_value()` applies every invariant before hashing:

| Rule | Why |
|---|---|
| Columns sorted by name | column order is not data |
| `int32` ≡ `int64` | engines disagree on width |
| Decimals: trailing zeros stripped | `1.10` ≡ `1.1` |
| Timestamps → UTC | same instant, different session zone |
| Floats quantised to the tolerance grid | non-associative `SUM` gives last-digit noise |
| `list` **ordered** | a sequence's order is data |
| `struct` / `map` **unordered** | field order is not data |
| **NULL distinct** | never equal to `""`, `0`, `[]`, or anything else |

### 6.6 The empty guard — `Case._guard_empty()`

```python
if cfg.allow_empty or result.kind != "rows":   return
if result.expected_rows or result.actual_rows: return
raise EmptyComparisonError(...)
```

Two empty tables are trivially equivalent, so a run that fetched nothing would
report `EQUIVALENT` and exit 0 — indistinguishable from a real pass. It keys off
`ComparisonResult.kind`, not the row count, because `schema_check` and
`concept_check` report zero rows *by design*.

---

## 7. Reporting and exit

```python
if args.json or args.md:
    write_reports(results, json_path=args.json, md_path=args.md)
if getattr(args, "csv", None):
    paths = write_csv_reports(results, args.csv)
    print(f"Wrote {len(paths)} per-column CSV report(s) to {args.csv}/")
...
return 1 if failures else 0
```

`report.write_csv_reports()` → `report.to_column_rows()` maps the result onto
five statuses:

| Status | Meaning |
|---|---|
| `MATCHED` | on both sides, same type, values agree |
| `MATCHED - TYPE DIFF` | on both sides, types disagree |
| `MATCHED - VALUE DIFF` | on both sides, types agree, values differ |
| `MATCHED - EQUIVALENT` | differs only in how it spells "absent" |
| `DIFF` | present on one side only |

Markdown is written **before** JSON: they are independent artifacts, and writing
JSON first meant a failure there took the Markdown report down with it — losing
both on precisely the runs that had something to report.

**Exit codes**

| Code | Meaning |
|---|---|
| 0 | every case equivalent |
| 1 | a case differed, or a case errored |
| 2 | cases could not be loaded (bad `--param`, unreadable YAML, no cases found) |

---

## 8. The whole path

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
     │           └─ params.substitute_spec      ${…} over the whole case
     └─ for case in cases:  try:
         └─ Case.run
             ├─ Case.config              ──► CompareConfig
             ├─ progress.step "expected"
             │   └─ sources.load_source → sources._trino
             │       ├─ sources.resolve_query   ──► ${…} → 20260812010000
             │       ├─ trino_auth.connect      ──► JWT / Basic / none
             │       └─ execute → fetchall → pa.Table
             ├─ progress.step "actual"   ──► same, other catalog
             ├─ progress.step "comparing"
             │   └─ compare.compare_tables
             │       ├─ compare._resolve_columns  ──► MATCHED / DIFF / TYPE DIFF
             │       └─ compare._compare_keyed    (or _compare_keyless)
             │           ├─ compare._key_of       ──► key tuple, not hashed
             │           ├─ hashing.canon_row → hashing.row_digest  ──► blake2b 16B
             │           └─ compare._column_diffs ──► change_signatures
             └─ Case._guard_empty
         └─ report.render_console → report.write_csv_reports → exit 0/1/2
```

---

## 9. Three seams worth knowing

**`pyarrow.Table` at the end of §5.** Everything after it is engine-agnostic.
This is what lets one comparison engine serve Trino, Snowflake, DuckDB, Parquet
and inline fixtures — a new source type only has to return an Arrow table.

**`ComparisonResult` at the end of §6.** Every reporter consumes the same
object: console, JSON, Markdown, CSV, the result sink, and the HTML history
report. A new field is visible everywhere at once; a new reporter needs no
changes elsewhere.

**The `try/except` in §4.** One case's failure never takes down the run, which
is what makes a directory of cases usable as a suite rather than a fragile
chain.
