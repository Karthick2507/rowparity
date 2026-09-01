# HeadFirst — rowparity

**The single source of truth for this codebase.** Written for someone who has to
own it: what problem it solves, how it is built and why that way, what its
guarantees actually are, how to operate it, and where it will let you down.

Derived by reading `src/rowparity/` (7,700 lines, 25 modules) directly. Every
claim below is from the code as it stands, not from an earlier document.

---

## Contents

1. [The problem, and the bet](#1-the-problem-and-the-bet)
2. [Architecture](#2-architecture)
3. [The equality contract](#3-the-equality-contract)
4. [Keyed vs keyless — the modelling decision](#4-keyed-vs-keyless--the-modelling-decision)
5. [Execution engines and scale](#5-execution-engines-and-scale)
6. [Parameterisation](#6-parameterisation)
7. [The correctness guards](#7-the-correctness-guards)
8. [Diagnostics: reading a run](#8-diagnostics-reading-a-run)
9. [Building a new case](#9-building-a-new-case)
10. [Operating it](#10-operating-it)
11. [Limitations register](#11-limitations-register)
12. [Execution trace — one command, end to end](#12-execution-trace--one-command-end-to-end)
    · [12.1 Process start](#121-process-start)
    · [12.2 `_run` starts up](#122-_run-starts-up)
    · [12.3 Loading the case](#123-loading-the-case)
    · [12.4 Per-case execution](#124-per-case-execution)
    · [12.5 Fetching each side](#125-fetching-each-side)
    · [12.6 The comparison](#126-the-comparison)
    · [12.7 Reporting and exit](#127-reporting-and-exit)
    · [12.8 The whole path](#128-the-whole-path)
    · [12.9 Three seams worth knowing](#129-three-seams-worth-knowing)
13. [Worked example — adding `f_supply_portfolio_hourly`](#13-worked-example--adding-f_supply_portfolio_hourly)
14. [LiveWire — stepping through one successful run](#14-livewire--stepping-through-one-successful-run)
15. [Does my run use DuckDB? — and what a result sink is](#15-does-my-run-use-duckdb--and-what-a-result-sink-is)

---

## 1. The problem, and the bet

### 1.1 The problem

You are migrating a data layout — a schema remodel, a new pipeline, a warehouse
move — and you have to prove the new one produces the same data as the old one.
At warehouse scale, on tables nobody can eyeball, across engines that disagree
about types.

The naive approaches all fail in the same place:

| Approach | Fails because |
|---|---|
| `EXCEPT` / `MINUS` in SQL | needs both sides in one engine; tells you *that* rows differ, not *which columns*; no tolerance for float or type width |
| Row counts and checksums | a pass proves almost nothing; a failure localises nothing |
| Sampling and eyeballing | finds the obvious, misses the systematic |
| A bespoke Python script per migration | every migration rewrites the comparison, and each one has its own bugs |

### 1.2 The bet

rowparity makes one architectural bet and derives everything from it:

> **Reduce every row to a canonical form whose equality means "these two rows
> mean the same thing", hash that form, and compare the resulting multisets.**

Three properties fall out of the representation rather than being implemented:

- **Row order is irrelevant.** Nothing in the pipeline records a row's position.
  `missing = exp_keys - act_keys` is a set operation. Sorting the input would
  change nothing.
- **Column order is irrelevant.** Columns are sorted by name before hashing.
- **Engine differences vanish.** `int32` from Spark and `int64` from Snowflake
  canonicalise to `('i', 42)`. This is why the tool works across engines at all.

### 1.3 What the deliverable actually is

Not a boolean. A run produces a `ComparisonResult` that answers, in order:

1. Do both sides have the same columns, with the same types?
2. Which key combinations exist on one side only? (**structural** difference)
3. For combinations on both sides, which columns disagree? (**value** drift)
4. Which branch / partition / segment do the differences concentrate in?
5. Is a *key column* drifting, making one logical row look like two problems?
6. What pattern do the value differences follow, and in which direction?
7. Give me the exact SQL to find the underlying records.

Questions 4–7 are what separate this from a diff. A tool that says "375 rows
differ" has handed the problem back to you.

---

## 2. Architecture

### 2.1 The pipeline

```
YAML case
   │  cases.py          load, merge defaults, resolve ${…}, dispatch by shape
   ▼
Source spec ×2
   │  sources.py        12 handlers, all returning pyarrow.Table
   ▼
════ WAIST 1: pyarrow.Table ════════════════════════════════
   │  hashing.py        canonical form  →  Blake2b(16)
   │  compare.py        keyed pairing or keyless multiset
   ▼
════ WAIST 2: ComparisonResult ═════════════════════════════
   │  near_miss.py      which key column drifted   (no I/O)
   │  drilldown.py      investigation SQL          (no I/O)
   ▼
report.py (console/JSON/MD/CSV) · run_report.py (HTML) · result_sink.py (history)
```

### 2.2 The two waists, and why they matter

This is the load-bearing design decision in the codebase, and it is worth
stating plainly because it is what makes the thing extensible.

**Waist 1 — `pyarrow.Table`.** Every source handler returns one. `compare.py`
has no idea whether the data came from Trino, a Parquet file, or a literal in
the YAML. Consequences:

- A new source type is one function returning an Arrow table. Nothing else
  changes.
- The comparison is written once, not once per engine.
- Arrow's type system is what canonicalisation dispatches on, so type-awareness
  comes free rather than being re-derived per source.

**Waist 2 — `ComparisonResult`.** Every reporter consumes the same object:
console, JSON, Markdown, CSV, HTML, the result sink, the history page. Adding a
field makes it visible everywhere at once. Adding a reporter changes nothing
upstream.

`concept_check.py` exploits this deliberately: it does a completely different
kind of analysis (business-concept coverage across a table remodel) and emits a
`ComparisonResult`, so every reporter works on it unchanged.

> §12 is the concrete counterpart to this diagram: the same pipeline walked
> statement by statement, with the output of a real run.

### 2.3 Module map

| Module | Lines | Responsibility |
|---|---|---|
| `hashing.py` | 277 | canonicalisation rules and the fingerprint — **the semantics of the tool** |
| `compare.py` | 776 | keyed/keyless comparison, signatures, breakdown, deltas |
| `cases.py` | 524 | YAML loading, case shapes, orchestration, the guards |
| `sources.py` | 397 | 12 source handlers → Arrow |
| `params.py` | 157 | `${…}` resolution and precedence |
| `near_miss.py` | 159 | which key column broke the pairing |
| `drilldown.py` | 431 | generated investigation SQL |
| `duckdb_pushdown.py` | 626 | in-DuckDB comparison |
| `snowflake_pushdown.py` | 792 | in-Snowflake comparison |
| `trino_pushdown.py` | 781 | in-Trino comparison |
| `report.py` | 469 | console, JSON, Markdown, CSV |
| `run_report.py` + `templates/run_report.html` | 397 + template | single-run HTML |
| `report_html.py` + `templates/report.html` | 42 + template | multi-run history HTML |
| `result_sink.py` / `history.py` | 324 / 196 | persist runs / read them back |
| `progress.py` | 176 | step timing, heartbeat |
| `param_queries.py` | 90 | a parameter resolved by querying |
| `concept_check.py` | 157 | N-tables-to-one-wide-table coverage |
| `trino_auth.py` / `snowflake_auth.py` | 80 / 90 | one connection-builder per warehouse |
| `schema_introspect.py` | 227 | schema without reading a row |
| `cli.py` / `runner.py` | 233 / 30 | CLI, pytest entry point |

**Note the two HTML templates.** `run_report.html` is *one run*
(`rowparity run --html`). `report.html` is *pass-rate history across runs*
(`rowparity report --html`). Different commands, different questions.

### 2.4 Dependency posture

Heavy drivers are **lazy imports inside their handler**, not module-level. Importing
`rowparity` does not import Trino, Snowflake, Spark, Iceberg or Delta. This is
why `pip install -e ".[trino]"` is a complete, working install — you are never
forced to carry drivers you do not use. Only `pyarrow`, `numpy` and `pyyaml` are
unconditional.

---

## 3. The equality contract

This is the section to read twice. Everything rowparity claims rests on it, and
every surprising result traces back to a rule here.

### 3.1 The two functions

```python
def canon_row(schema, row, columns, cfg):
    return tuple((name, canon_value(schema.field(name).type, row.get(name), cfg,
                                    unordered_list=name in cfg.unordered_list_columns))
                 for name in columns)          # columns pre-sorted by caller

def row_digest(canon):
    return hashlib.blake2b(repr(canon).encode("utf-8"), digest_size=16).digest()
```

**Blake2b, 16 bytes.** Not Python's `hash()` — that is salted per process, so
two runs would not be comparable and nothing could be persisted.

### 3.2 Canonicalisation dispatches on the Arrow type, not the Python value

```python
canon_value(dtype: pa.DataType, value, cfg, *, unordered_list=False)
```

This is deliberate and it matters: a `map` and a `list<struct<key,value>>` look
identical once they reach Python, and they have **different equality semantics**
(one is unordered, the other ordered). Reading the schema keeps them apart.

### 3.3 The rules, exhaustively

| Arrow type | Canonical form | Semantics |
|---|---|---|
| NULL | `("n",)` | **distinct** — never equal to `""`, `0`, `[]`, `false` |
| bool | `("b", v)` | exact |
| int | `("i", int(v))` | **width-independent**: int8 ≡ int64 |
| float, `tolerance = 0` | `("f", v.hex())` | exact IEEE-754 |
| float, `tolerance > 0` | `("f", int(round(v/tol)))` | quantised to a grid |
| float NaN / ±Inf | `("f","nan")` / `("f","inf")` / `("f","-inf")` | NaN **equals** NaN here |
| decimal | `("d", format(v.normalize(),"f"))` | trailing zeros stripped: `1.10 ≡ 1.1` |
| string | `("t", s)` | optional `.strip()`, optional `.casefold()` |
| binary | `("x", v.hex())` | exact |
| timestamp, tz-aware | `("T", utc.isoformat(), True)` | normalised to UTC |
| timestamp, naive | `("T", v.isoformat(), False)` | **not** equal to a tz-aware one |
| date / time | `("D", …)` / `("H", …)` | ISO |
| **list** | `("L", (elems…))` | **ORDERED** — order is data |
| list, opted out | `("Lu", sorted(elems))` | multiset — via `unordered_list_columns` |
| **struct** | `("S", ((name, v)…))` | **UNORDERED** — fields sorted by name |
| **map** | `("M", sorted((k,v) pairs))` | **UNORDERED** — sorted by canonical form |
| anything else | `("o", repr(v))` | deterministic fallback |

Four consequences a data engineer should internalise:

1. **Arrays are ordered by default.** If your engine does not guarantee element
   order (Presto's `array_agg` does not), an ordering difference reads as a data
   difference until you list the column in `unordered_list_columns`.
2. **A naive timestamp never equals a tz-aware one**, even for the same instant.
   The flag is part of the canonical form. Normalise in SQL if the two sides
   disagree about tz-awareness.
3. **`coerce_numeric_to_float` collapses int, decimal and float into one
   domain.** Necessary when one side reports `NUMBER(38,0)` and the other
   `bigint`; it also means you lose the ability to detect an int-vs-decimal
   change.
4. **Float tolerance is a grid, not an epsilon.** `int(round(v/tol))` means two
   values straddling a grid boundary can differ by less than `tol` and still
   compare unequal. That is the price of an O(1) canonical form — a true
   epsilon comparison is not transitive and cannot be hashed.

### 3.4 The type tag is not decoration

Every canonical leaf is `(tag, payload)`. The tag is what stops `1` and `"1"`
and `1.0` from colliding when the digest is taken over `repr()`. It also makes
the key tuple self-describing, which the near-miss analysis and the drill-down
both depend on (§8.5, §8.8).

### 3.5 The vectorized path

`compare.vectorized: true` swaps per-cell dispatch for column-at-a-time
canonicalisation (`canon_columns_vectorized`). It covers bool, int, float,
string (unless `case_insensitive`, because Arrow's `utf8_lower` is not Python's
`.casefold()` on Unicode edge cases) and timestamp — and **falls back per column**
for decimal, date, time, binary, nested types, and **any column containing a
null** (`if arr.null_count: return None`).

Same results, cell for cell — roughly 1.2× on scalar-heavy tables. Opt-in.
Do not expect a speedup on a table where most columns are nullable.

---

## 4. Keyed vs keyless — the modelling decision

This is the decision that most determines whether a run is useful, and it is
made in one line of YAML.

### 4.1 Keyless

No `keys:`. Every row is fingerprinted and the two **bags of digests** are
subtracted:

```python
delta = exp_counts[d] - act_counts[d]
if delta > 0:   result.missing_count += delta
elif delta < 0: result.added_count   += -delta
```

- Detects any difference, correctly, including duplicate-row multiplicity.
- `changed_count` is **0 by construction** — nothing pairs a missing row with the
  added row it corresponds to.
- Column attribution is limited to an order-independent per-column value
  fingerprint: the **sum** of the hashes of that column's canonical values.
  Addition, not XOR, so multiplicity survives (`[1,1,2]` and `[1,2,2]` have the
  same set, different multisets). One integer per column instead of a `Counter`
  of a million values. Costs ~16% on a 100k × 263 comparison, measured.
  **Those hashes use Python's process-salted `hash()` and must never be
  persisted or compared across processes** — both sides are hashed inside one
  run and only ever compared with each other.

### 4.2 Keyed

`keys: [...]`. Each side is indexed by the canonicalised key tuple, then three
set operations:

```
missing = exp_keys - act_keys      # structural: absent from actual
added   = act_keys - exp_keys      # structural: absent from expected
paired  = exp_keys & act_keys      # → compare digests → changed
```

**The key tuple is used raw as a dict key. It is never hashed.** Two reasons:

1. A digest collision would silently pair two different rows. Vanishingly
   unlikely at 16 bytes; impossible with a raw tuple.
2. **The key must be readable back out.** The report prints the key of every
   missing row; near-miss drops one element at a time and re-pairs; the
   drill-down reads a specific column out of a specific tuple position. None of
   that works on a digest.

The digest is used for exactly one thing: deciding whether two rows that
*already paired on their key* hold the same values. One 16-byte comparison
instead of N per-column comparisons — and only when it differs does
`_column_diffs()` do the expensive work of naming which columns moved.

### 4.3 What you lose without a key

Both modes detect the same set of differences. The difference is **diagnosis**.

| | Keyless | Keyed |
|---|---|---|
| Row identity | full-row digest | the key tuple |
| Reports `changed` | never | yes |
| Names drifting columns | whole-column multisets only | exactly, per row |
| `breakdown_by` | unavailable | yes |
| `near_miss` | unavailable | yes |
| Drill-down bound column | examples only | every differing row |

A concrete measurement from this repo's live case. Run keyless, the result was
**158 missing + 217 added, and all 262 columns flagged** — because one side had
59 extra rows, so every column's value multiset differed. True, and useless.

Keyed on the same data, the run separates the two questions and names the four
metrics that actually moved.

### 4.4 How to choose a key when there is no business key

Key on **whatever makes a row unique by construction**. For an aggregate, that
is every `GROUP BY` dimension — 83 of them in the live case. Nobody would call
that a business key, but uniqueness is the only property a key needs.

If the choice is wrong, rowparity reports `duplicate_keys_expected` /
`duplicate_keys_actual` rather than guessing, and the HTML report raises the
loudest note on the page. That is a finding, not a failure.

---

## 5. Execution engines and scale

### 5.1 The default engine

No `engine:` key. Both sides are fetched into Python as Arrow, then compared in
`compare.py`. Suitable for **tens of thousands to low millions of rows**.

Its cost is that `to_pylist()` materialises both sides as Python dicts.

### 5.2 The fetch is already the hard part

Before push-down is even considered, the Trino source solves a memory problem
worth understanding, because it recurs in any client-side comparison:

```python
batch_rows = spec.get("fetch_batch_rows") or _trino_batch_rows(len(col_names))
while True:
    rows = cur.fetchmany(batch_rows)
    if not rows: break
    tables.append(pa.Table.from_pylist([dict(zip(col_names, r)) for r in rows]))
return pa.concat_tables(tables, promote_options="permissive")
```

`fetchall()` built the whole result as Python tuples and then a *second* full
copy as dicts before Arrow saw anything. Measured at 262 columns:

| Rows | `fetchall()` peak | Batched peak |
|---|---|---|
| 25,000 | 0.51 GB | 0.15 GB |
| 50,000 | 0.97 GB | 0.15 GB |
| 100,000 | 1.92 GB | 0.15 GB |

Flat, because only one batch is ever in Python and what accumulates is columnar
Arrow.

Two details that matter operationally:

- **Batch size follows a cell budget** (2,000,000 cells, clamped to 1k–100k
  rows), not a row count — a 262-column row is two orders of magnitude heavier
  than a 1-column one.
- **`promote_options="permissive"` is a correctness requirement, not a
  convenience.** Types are inferred per batch, so a column all-NULL in one batch
  infers as `null` and as `int64` in the next. Without promotion those batches
  cannot concatenate at all — batching would have converted a memory problem
  into a correctness one.

### 5.3 Push-down

`engine: duckdb | snowflake | trino` moves canonicalisation *and* fingerprinting
into the warehouse. Only the bounded example rows (`max_examples`) cross into
Python.

| | DuckDB | Snowflake | Trino |
|---|---|---|---|
| Scalars | full | full | full |
| Nested types | full, recursive | via a recursive JS UDF | full, recursive |
| How schema is read | `con.sql(...).types` | `cursor.describe()` | `LIMIT 0` probe |
| Sources accepted | duckdb/sql/parquet/csv/inline | both sides `type: snowflake` | both sides `type: trino` |
| Live-verified | 100M rows/side, ~12s | yes, both paths | **no — unit tests only** |

Notes a senior engineer will want:

- **DuckDB push-down federates.** It reads Parquet and CSV in place, so the
  standard pattern for a huge Snowflake or Spark table is `COPY INTO` /
  `df.write.parquet` and then compare the files. There is no per-engine SQL
  dialect layer.
- **DuckDB requires `float_tolerance > 0` for floats** — exact IEEE-754 hex
  comparison is not implemented in SQL. Blob is not covered.
- **Snowflake needed a UDF for semi-structured types.** A pure-SQL design
  (`TYPEOF()` + `TABLE(FLATTEN(...))` in a scalar subquery) was built first and
  found, live, to be impossible: Snowflake does not support a correlated table
  function nested in an arbitrary scalar subquery. The UDF needs `CREATE
  FUNCTION` granted, and is only created when a case actually has a
  semi-structured column in scope.
- **Push-down rejects `breakdown_by` and `null_equivalence`** rather than
  accepting them and silently producing nothing. Both are per-row computations;
  a push-down engine never sees a row.
- **`change_signatures` under push-down reflect only the fetched example rows**,
  not the full table. The default engine's are exact.

### 5.4 The decision

| Situation | Engine |
|---|---|
| ≤ a few million rows | default |
| Large, data in files or DuckDB-reachable | `engine: duckdb` |
| Large, data native in Snowflake | `engine: snowflake` |
| Large, data native in Trino | `engine: trino` (unverified live) |
| You need `breakdown_by` / `near_miss` / exact signatures | default, and shrink the population first |

If none fit: push the filter into SQL, sample deterministically
(`WHERE abs(hash(id)) % 100 = 0` — **the same predicate on both sides**), or
shard by key range across parallel CI workers.

---

## 6. Parameterisation

### 6.1 Why it exists

A case file is otherwise static, which fails for anything that changes per run:
a batch id, a partition date, a catalog name while a migration is in flight.

### 6.2 Precedence

```
file vars:   <   case vars:   <   ROWPARITY_VAR_<NAME>   <   --param NAME=VALUE
```

Names are lower-cased throughout, so `${BATCH_ID}` and `${batch_id}` are one
name. Dotted names are recognised — `${arena.presto.var.process_batch_id}` —
because real query files arrive pre-templated by another system with namespaced
names.

**That last point is not cosmetic.** Before dotted names were recognised, the
name did not match, so it was neither substituted *nor* reported unresolved: the
literal text reached Presto inside quotes as a valid string matching no batch.
Both sides returned zero rows and the run reported EQUIVALENT. A clean pass
proving nothing.

**An unresolved placeholder is a hard error, never a passthrough.** Same
reasoning.

### 6.3 Per-side vars invert the precedence — deliberately

```yaml
expected: { type: trino, query_file: q.sql, vars: { facts: mrm_log_flat.default } }
actual:   { type: trino, query_file: q.sql, vars: { facts: etl.public_test1 } }
```

One SQL file serves both sides. This is the pattern that makes a 2,000-line,
185 KB query maintainable: before it, "same query, different catalog" meant two
near-identical copies kept in step by a test. That works for one query and does
not survive a hundred — the files drift, the run still succeeds, and it reports
*SQL* differences as *data* differences.

**A side var beats `--param` and the environment**, inverting the rule
everywhere else. A side var is not a knob; it is half of what makes the two
sides different. Letting `--param facts=x` reach both sides would point them at
the same catalog and produce a confident EQUIVALENT for comparing a table with
itself. A case that *wants* a side overridable says so by templating the value:
`vars: {facts: "${old_catalog}"}`.

### 6.4 Two timings, and the trap between them

| What | Substituted |
|---|---|
| Spec dicts (`expected:`, `actual:`, `compare:`) | **load time**, over the whole raw case |
| `query_file` contents | **run time**, when the file is read |
| The `drilldown:` block | **generation time**, after the comparison |

`drilldown:` is explicitly popped out before load-time substitution, because its
placeholders (`${batch_hour}` and friends) are *derived from* the batch
parameter and do not exist yet — and because `rowparity list` must be able to
enumerate a case without being handed a batch id.

The trap: put a run-time value in a side `vars:` block and `rowparity list`
breaks.

### 6.5 `param_queries:` — a parameter resolved by querying

```yaml
param_queries:
  batch_id:
    type: trino
    query_file: sqls/latest_common_batch.sql
```

Two rules that matter:

- **Resolved once per file, never per case.** Two cases keying off "the latest
  batch" must see the *same* batch; resolving per case would let a batch landing
  mid-run compare two different populations — exactly the kind of difference
  that looks like a data defect.
- **A query only runs if the name is not already resolved.** `--param` or the
  env var short-circuits it entirely.
- **An empty or NULL result is an error, never an empty string.** Substituting
  `""` would filter on a partition that cannot exist, return zero rows on both
  sides, and report EQUIVALENT.

`rowparity list` passes `resolve_queries=False` and substitutes each name to its
own literal placeholder, so listing never touches a warehouse — and those
stand-in values are then *dropped* from the case, so a run still gets the real
"unresolved parameter" error rather than a fabricated one.

---

## 7. The correctness guards

A verification tool that reports success for having verified nothing is worse
than one that crashes. Four failure modes produce a **green run with exit 0**,
and each has a guard. Understanding them is most of understanding this codebase's
character.

### 7.1 Both sides empty — `EmptyComparisonError`

Two empty tables are trivially equivalent. A live run did exactly this: eight
minutes of warehouse time, both sides empty because the batch had aged out of
staging, and a green `1/1 equivalent` at the end.

```python
if cfg.allow_empty or result.kind != "rows":   return
if result.expected_rows or result.actual_rows: return
raise EmptyComparisonError(...)
```

Keys off `result.kind`, not the row count — `concept_check` reports zero rows by
design.

### 7.2 Both sides identical — `IdenticalSourcesError`

The mirror image. One SQL file parameterised per side removes the risk of two
copies drifting; it introduces the risk of both sides resolving to the *same*
catalog because a `vars:` block was copy-pasted and half-edited. The run
succeeds, every row matches, EQUIVALENT, exit 0.

Fires only when both sides name the same `query_file` **and** resolve it to
identical text. Scoped that narrowly on purpose: two sides naming the same
Parquet path are a hand-written fixture whose author can see both sides at once.
Pointing both sides at one file has exactly one purpose — to parameterise them
differently — so a run where that produced no difference is a bug every time.

### 7.3 A breakdown that cannot be computed

`breakdown_by` must name a **key** column. A key is the only thing guaranteed
identical on both sides of a paired row; break down by a non-key column and a
*changed* row has two group values, one per side, so whichever side the code
read would be an arbitrary choice presented as a fact.

Also rejected on push-down engines, which never see a row.

### 7.4 Sampling asymmetry — a guard you must build yourself

Not in the code; it belongs in your case design. The live case's first run
returned 2,719 rows on one side and 1,113,423 on the other — a ratio of 409,
which is a sampling difference, not a migration defect. Every sum was over a
different number of underlying rows, so the run measured the sampling and
nothing else.

The fix is structural: put the sampling predicate in the **case-level `vars:`**,
used by both sides. Defined once and used by both, the bug is not expressible.

### 7.5 Where the guards run

`_check_breakdown()` and `_guard_identical_sides()` both run **before any
connection is opened**. A misconfigured case fails in the first second rather
than after the warehouse has spent an hour producing an answer that proves
nothing.

### 7.6 Failure isolation

```python
for case in cases:
    try:
        result = case.run(result_sink=result_sink)
    except Exception as exc:
        print(f"Case '{case.name}': ERROR - {type(exc).__name__}: {exc}")
        errors.append((case.name, exc)); failures += 1; continue
```

One case's failure never takes down the run — which is what makes a directory of
cases a suite rather than a fragile chain. Errored cases are collected
separately and rendered in the HTML report: a report that silently omits the
case that blew up is worse than no report.

**Exit codes**, and the distinction CI depends on:

| Code | Meaning |
|---|---|
| 0 | every case equivalent |
| 1 | a case differed, or a case errored |
| 2 | cases could not be **loaded** — bad `--param`, unreadable YAML, none found |

`2` says "the tool could not run". `1` says "the data disagrees". Do not
collapse them.

The `xfail` tag inverts the expectation for a case: a difference confirms it, and
an *unexpected pass* counts as a failure.

---

## 8. Diagnostics: reading a run

The HTML report's section order is the intended diagnostic order. Each section
narrows the answer from the one above.

### 8.1 The tiles

```
Rows in Hoover   Rows in Hoover++   Missing in Hoover++   Added in Hoover++   Changed
       2,719            2,778                  149                 208            18
```

Named after your two sides via `expected_label:` / `actual_label:`, not
"expected"/"actual" — a reader should not have to remember which abstract word
is the source of truth.

**Read the balance first.** 149 against 208 is suspiciously symmetric for real
data loss. **Balance is the signature of a key that stopped matching**, not of
rows that stopped existing. §8.5 tests that.

### 8.2 Notes

Conditional warnings, loudest first:

- **Duplicate keys** — the key is not unique, so rows were paired arbitrarily and
  *every count above is unreliable*. Fix this before reading anything else.
- **Keyless run** — `MATCHED` below means present with the same type, not that
  values agree.
- **Row counts differ (keyless)** — one side has extra rows, so every column has
  extra values and every column reads VALUE DIFF. Correct, and it localises
  nothing.

### 8.3 Row differences by *(breakdown column)*

```
slot_user_drop_off   Rows Hoover   Rows Hoover++   Missing   Added   Changed   Differing
Removed                      412             381        41      12         3     13.6% ███
Included                   1,904           1,998        87     171        11      6.7% █▌
Not Applicable               403             399        21      25         4      4.9% █
TOTAL                      2,719           2,778       149     208        18
```

**Triage: which branch of the query is wrong?**

The live query is a 3-way `UNION ALL` and `slot_user_drop_off` is a hardcoded
literal per branch, so it partitions the output exactly. Because it is also a
key, its value is available for missing, added *and* changed rows at no cost.

**Sorted by share, not count** — `differing_share` is differences over
`max(expected_rows, actual_rows)`. 58 missing from 892 rows is a worse signal
than 71 from 1,204, and only the ratio says so. The bar is scaled to the worst
group, so the comparison *between* rows is the point.

Computed over **every** row, not the bounded examples.

One caveat: the group label is the **raw** column value, not the canonical form,
so `breakdown["Removed"]` means what it looks like. With `trim_strings` on,
`" A"` and `"A"` are one row to the comparison but two groups here — visible as
two near-identical rows rather than a silently wrong number.

### 8.4 Dimensions / Metrics

The column table splits on key membership.

**Dimensions** are the key. This table answers **presence and type only** and
deliberately carries no "diff rows" column: a key column *cannot* differ in
value — if it did the rows would not pair, and the difference appears as
missing + added. Eighty-three zeroes would read as "all verified" when they mean
"not applicable". What to look for here is a dimension present on one side only,
or with a type mismatch — either breaks pairing for every row.

**Metrics** are everything else, sorted worst first, with four statuses:

| Status | Meaning |
|---|---|
| `MATCHED` | on both sides, same type, values agree |
| `MATCHED - TYPE DIFF` | on both sides, types disagree |
| `MATCHED - VALUE DIFF` | on both sides, types agree, values differ |
| `DIFF` | present on one side only |

`MATCHED` is hidden by default — at 262 columns a full dump buries the few that
need attention.

### 8.5 Near misses — one key column apart

```
Likely cause: dropping event_date pairs 137 of 149 missing rows with added
rows (91.9%). Those rows were not lost — they moved.

Drop from key      Pairs   Explains   Ambiguous   Example
event_date           137      91.9%           4   2026-08-27  ->  2026-08-26
process_batch_id       0          -           -
```

**The diagnosis for §8.1's balance.** If one key column drifts, the pair is
destroyed and the same logical row is counted twice — once missing, once added —
with nothing in the output saying they are related.

The analysis drops each key column in turn, re-indexes both sides on the
remaining columns, and counts unambiguous pairings.

- **Pairs** — missing rows finding *exactly one* added-row partner.
- **Ambiguous** — several added rows matched on the remaining columns, so no
  single pairing is decidable. Counted separately, **never** as pairs: claiming
  one would be a guess presented as a finding.

**No query is run.** It works on key tuples already in memory.

Three honest limits, all in the code:

- One column at a time. Two columns drifting together are not found.
- Requires ≥2 key columns — dropping the only one pairs everything with
  everything.
- Capped at 20,000 **missing** rows, and it says so. The added side is *never*
  capped: it is the lookup index, and truncating both would discard each kept
  row's partner at random and confidently report "0 pairs".

### 8.6 Change signatures

```
11x   filled_ads, filled_ads_duration, placed_ads, selected_ads   61.1% of changed rows
      by group:  Included 8  -  Removed 3

      Column                 Direction         Rows
      filled_ads             Hoover++ lower    11 / 11
      filled_ads_duration    Hoover++ lower    11 / 11
      placed_ads             Hoover++ lower    11 / 11
      selected_ads           Hoover++ lower    11 / 11

      Every row moved by the same amount: placed_ads -1, selected_ads -1
      — a systematic shift, not scattered drift.

      most extreme row:  filled_ads 2 -> 1  |  filled_ads_duration 60 -> 30
```

**Changed rows grouped by *which columns* differ.** Thousands collapse into a
handful of patterns.

| Element | Reading |
|---|---|
| `11x` | eleven changed **rows** share this exact set of drifting columns — the group size |
| the column list | the signature: these four move together and nothing else moved in these rows. Four metrics always moving as a set is **one** bug, not four |
| `61.1% of changed rows` | this pattern's share of all changed rows — headline or footnote? |
| `by group:` | the §8.3 breakdown applied to this signature |
| Direction | `lower` / `higher` / `mixed`, plus `became null` / `was null` counted **separately** — a value disappearing is a different failure from one getting smaller |
| `11 / 11` | rows in the signature that moved in that column |
| the constant-delta sentence | printed **only when true**: every numeric row moved by an identical amount |
| most extreme row | the largest movement, kept in preference to whichever arrived first |

**There is no Delta column, on purpose.** It only rendered a range like
`-3 to -1`, which read as noise. The one case where the number is genuinely
diagnostic — an identical delta on every row — gets a sentence instead.

For the example above: two ads became one, sixty seconds became thirty. Per-ad
duration is preserved, so this is not a duration bug — it is one ad going
missing and taking its duration with it.

### 8.7 Row examples

Individual rows, bounded by `max_examples` (default 20). **Kind** is named after
your side; **Detail** is the row digested by your `row_summary:` groups rather
than a 262-column dict truncated after four.

**A caveat with operational consequences.** `_maybe_example` appends in
encounter order — missing, then added, then changed. At live proportions (149 /
208 / 18 with `max_examples: 50`) the list fills **entirely with missing rows**:
verified as `Counter({'missing': 50})`.

The examples are a sample of the first thing encountered, not a balanced sample
of the problem. That is precisely why §8.3, §8.5, §8.6 and the drill-down are all
computed over every row instead.

### 8.8 Drill-down SQL

```
Drill-down SQL - request__transaction_id for rows missing in Hoover++

ONE query per side, not one per row: the creative_id of every row missing in
Hoover++ goes into a single IN-list, so one scan per side covers all 149.

Not in this filter: 149 creative_id value(s) from rows added in Hoover++,
18 from rows changed. Add them with drilldown.kinds.
```

The parity run says which *aggregate rows* disagree. It cannot say which
*underlying transactions* caused it — the compared query is a `GROUP BY` over 83
dimensions, so per-request identifiers are collapsed. That answer lives one
query further down, against the raw table.

**Use:** run both, compare the two lists of ids. The ids on one side only are
the transactions that differ.

Four design decisions:

- **Two queries total, not two per row.** Twenty near-identical 40-line queries
  are twenty things to copy, twenty results to reconcile, and twenty scans of
  the same partition — when one scan answers all of them.
- **Generated, never executed.** Running both sides was tried and removed:
  against the real cluster the two scans dominated the parity run they were
  meant to annotate. A drill-down is an aid to *reading* a result, not part of
  producing one. Failures here are reported and swallowed — losing a parity run
  because a helper template has a typo is the wrong trade.
- **`kinds:` selects which differing rows contribute, defaulting to
  `[missing]`.** With an 83-column key one bound value spans many aggregate
  rows, so merging all three kinds produces a long list that looks like the
  whole column and says nothing about why any value is in it. The excluded kinds
  are still counted and named: "no rows found" and "never asked for" must not
  look identical.
- **The time window is derived from the batch parameter**, never typed in. A
  hardcoded date goes stale the moment you drill a different batch, and nothing
  in the output says the window was wrong — the query just returns rows from
  some other hour and they look like an answer.

Values come from **every** differing row of the selected kinds, not from §8.7's
bounded list — possible because the bound column is part of the key.

### 8.9 The workflow in one line

> Which branch (§8.3) → is a key drifting (§8.5) → what pattern do the changes
> follow (§8.6) → show me one (§8.7) → give me the transaction ids (§8.8).

---

## 9. Building a new case

### 9.1 The SQL — one file, templated per side

```sql
select ...
from ${facts}.ad             -- the ONE thing that differs between sides
where ${sampling_filter}     -- shared: defined once, used by both
  and process_batch_id = '${arena.presto.var.process_batch_id}'
```

Rules:

- Anything that differs per side → a placeholder resolved by that side's `vars:`.
- Anything that must **never** differ → the case-level `vars:`. Then the bug is
  not expressible (§7.4).
- **`${...}` in a comment is a real substitution site.** Substitution does not
  know what a comment is. Write placeholder names bare in header comments.

### 9.2 The YAML

```yaml
cases:
  - name: my_aggregate_parity
    expected_label: Hoover
    actual_label: Hoover++
    description: >-
      One sentence stating what must be true for this to pass.

    vars:                                    # shared by BOTH sides
      sampling_filter: "bitwise_and(...) > 0"

    expected:
      type: trino
      query_file: ../../sql/insight_plus/my_aggregate.sql
      vars: {facts: mrm_log_flat.default}    # the only per-side difference
    actual:
      type: trino
      query_file: ../../sql/insight_plus/my_aggregate.sql
      vars: {facts: etl.public_test1}

    compare:
      keys: [...]                            # every GROUP BY dimension
      unordered_list_columns: [global_advertiser_ids, global_brand_ids]
      max_examples: 50
      breakdown_by: slot_user_drop_off       # must be one of the keys
      near_miss: true

    row_summary:
      - {label: Branch, columns: [slot_user_drop_off]}
      - {label: Batch,  columns: [process_batch_id, event_date]}

    drilldown:
      query_file: ../../sql/insight_plus/my_aggregate_drilldown.sql
      bind: {creative_id: "if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1)"}
      id_column: request__transaction_id
      kinds: [missing]
      time: {param: arena.presto.var.process_batch_id, format: "%Y%m%d%H%M%S",
             hours_before: 1, hours_after: 3}
      vars:
        expected: {time_filter: "... >= timestamp '${batch_hour_start}' and ... < timestamp '${batch_hour_end}'"}
        actual:   {time_filter: "... = timestamp '${batch_hour}'"}

    tags: [insight_plus]
```

A `defaults:` block at document level is shallow-merged into every case, with
`compare:` merged one level deeper — useful for shared connection settings.

Note the drill-down's `bind` maps an **output alias to its source expression**.
`creative_id` in the parity output is really the `if(...)`; that expression, not
the alias, is what must appear in a predicate against the raw table.

### 9.3 Choosing keys

Key on every `GROUP BY` dimension. See §4.4 for why, and §4.3 for the measured
consequence of not doing it.

### 9.4 The validation tests — the highest-leverage thing you will write

Every case deserves a `tests/test_<name>_case.py`. All of these run in
milliseconds with **no warehouse**:

| Assertion | Catches |
|---|---|
| the case loads | a YAML typo |
| the expected engine (or none) is set | an accidental push-down |
| both sides share one `query_file` | the two-copies-drift problem returning |
| the sides differ **only** in the catalog var | a half-edited copy-paste |
| no side var holds a `${placeholder}` | a name that could never resolve |
| `rowparity list` works without `--param` | a run-time value in a load-time slot |
| both sides carry the sampling filter | the 409× sampling bug returning |
| the batch parameter substitutes on both sides | a half-templated query |
| omitting the batch **raises** | a green run over zero rows |
| the YAML ships no default batch | the same, from the other side |
| `keys` == exactly the query's dimensions | a column added to the SELECT without updating `keys` |
| no metric is used as a key | a `sum()` in the key |
| arrays that may reorder are declared unordered | an ordering difference read as data |

And a SQL-side test:

| Assertion | Catches |
|---|---|
| the template has exactly the expected placeholders | a stray or missing `${...}` |
| **every** fact-table reference goes through `${facts}` | one hardcoded catalog in 2,000 lines |

That last one is the highest-value test in the file. A single missed
`from mrm_log_flat.default.ad` makes one side read the wrong catalog for one
branch of a union, and nothing in the output would say so.

### 9.5 The loop

```bash
rowparity list scripts/cases_insight_plus          # 1. does the YAML parse? no warehouse
rowparity list scripts/cases_insight_plus --check \
    --param arena.presto.var.process_batch_id=...  # 2. does the SQL resolve? local files only
pytest tests/test_my_case.py -xvs                  # 3. is it wired right?  no warehouse
python scripts/trino_connectivity_check.py         # 4. can we connect?
rowparity run scripts/cases_insight_plus \         # 5. run it
    --param arena.presto.var.process_batch_id=20260827010000 \
    --html reports/run.html
```

Do not skip to step 5.

### 9.6 Extending the framework

| To add | Do this | Touches |
|---|---|---|
| a source type | write `_x(spec, base_dir, variables) -> pa.Table`, register in `_HANDLERS` | `sources.py` only |
| a comparison option | add a field to `CompareConfig`, add the name to `_COMPARE_KEYS` | `compare.py`, `cases.py` |
| a reporter | consume `ComparisonResult` | your new module only |
| a case shape | dispatch in `_build_case`, emit a `ComparisonResult` | `cases.py` + your module |
| a push-down engine | mirror `duckdb_pushdown.py`'s function set | your new module + one branch in `Case.run` |

Adding a comparison option that a push-down engine cannot implement? **Reject it
there explicitly**, as `breakdown_by` does. Accepting an option and silently not
honouring it is the failure mode this codebase works hardest to avoid.

---

## 10. Operating it

### 10.1 Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[trino]"        # or [duckdb] / [snowflake] / [all]
make install                     # ".[test,dev]" + activates the git hooks
```

| Extra | For |
|---|---|
| `duckdb` | `type: duckdb`/`sql`, `engine: duckdb` |
| `trino` | `type: trino`, `engine: trino` |
| `snowflake` | `type: snowflake`, `engine: snowflake` |
| `iceberg` / `delta` / `spark` | those source types |
| `dbt` | building the example warehouse |
| `test` / `dev` | pytest / pre-commit |
| `all` | everything |

### 10.2 Library use

```python
import pyarrow as pa
from rowparity import CompareConfig, compare_tables      # __all__: also
                                                          # ComparisonResult, ColumnDiff,
                                                          # RowDiff, CanonConfig,
                                                          # canon_value, canon_row, row_digest
from rowparity.cases import discover_cases
from rowparity.runner import assert_case
```

pytest suite in five lines:

```python
@pytest.mark.parametrize("case", discover_cases("scripts/cases_insight_plus"),
                         ids=lambda c: c.name)
def test_case(case):
    assert_case(case)
```

### 10.3 Secrets

**Read from the environment only.** There is no code path that reads a token or
password out of a case file, because case files are committed to git.

```bash
export TRINO_HOST=... TRINO_PORT=8080 TRINO_HTTP_SCHEME=https TRINO_USER=...
read -rs TRINO_JWT_TOKEN && export TRINO_JWT_TOKEN     # no echo, no shell history
```

Trino picks an auth mode by what is present: `TRINO_JWT_TOKEN` → Bearer,
`TRINO_PASSWORD` → HTTP Basic, neither → no auth header. A case's `connection:`
block overrides the environment (**YAML wins**) for non-secret settings.

**Snowflake is key-pair only.** No password path exists anywhere in the
codebase. The key comes from `SNOWFLAKE_PRIVATE_KEY_PATH`, `SNOWFLAKE_PRIVATE_KEY`
(raw PEM, for CI), or a per-case `connection.private_key_path` — never as inline
key material in YAML.

### 10.4 Committing

Four pre-commit hooks: `ruff`, `ruff-format`, `detect-private-key`,
`detect-secrets`.

**`ruff-format` failing the commit is the hook working, not an error.** It
rewrites your files, aborts so you can review, and leaves the changes unstaged.
Re-stage and commit again:

```bash
git add -A && git commit -m "..."
```

Some files here do not currently satisfy `ruff format`, so this can fire on a
file you barely touched.

If `detect-secrets` flags a false positive: rework the code so it does not look
like a secret, or mark the line `# pragma: allowlist secret` and re-run
`detect-secrets scan --baseline .secrets.baseline`. Do **not** delete the
finding, and do **not** widen the exclusions.

### 10.5 CI

```bash
# cheap pre-flight: fails in milliseconds, opens no connection
rowparity list cases/ --check --param batch_id="$BATCH" || exit 2

rowparity run cases/ --param batch_id="$BATCH" \
                     --json reports/rowparity.json \
                     --md reports/rowparity.md \
                     --html reports/run.html \
                     --csv reports/columns
```

- Exit 1 fails the stage; exit 2 means the stage is misconfigured. Alert on
  them differently.
- Archive all four artifacts. The CSV is the readable form when schema drift
  runs to hundreds of columns.
- Markdown is written **before** JSON, deliberately: they are independent
  artifacts, and writing JSON first meant a failure there took the Markdown
  report down with it — losing both on precisely the runs that had something to
  report.
- HTML-report failures are caught and warned, never fatal. A report is an
  artifact of the run, not the run.

### 10.6 Observability

Progress goes to **stderr**, every write flushed, so `2>&1 | tee run.log` shows
heartbeats live and `rowparity run > results.txt` keeps stdout parseable. Off by
default — library and pytest use stay silent, and no heartbeat threads are
created.

Timings are kept as **three** numbers, not one: expected load, actual load,
compare. "The query was slow" is a warehouse problem; "the comparison was slow"
is ours.

For history across runs:

```bash
rowparity run cases/ --result-sink duckdb:./reports/results.duckdb
rowparity report --result-sink duckdb:./reports/results.duckdb --html trend.html
```

Two tables per run: `<prefix>_run_summary` (one row per case) and
`<prefix>_run_diffs` (one row per diff example). That gives you failure trends,
consecutive-failure alerting, a row-level audit trail, and row-count SLA
monitoring — from the same data the report already produces.

---

## 11. Limitations register

Know these before you rely on the tool.

### 11.1 Semantic

| Limitation | Impact |
|---|---|
| Float tolerance is a **grid**, not an epsilon | two values under `tol` apart can straddle a boundary and compare unequal |
| NaN equals NaN | intentional for parity work; not IEEE-754 |
| Naive ≠ tz-aware timestamps | normalise in SQL if the sides disagree |
| `unordered_list_columns` applies to the **top level only** | a list nested inside a struct stays ordered |
| A column NULL in *every* Trino batch lands as Arrow `null` type | reads as a type mismatch; needs an explicit schema from `cursor.description` to fix |
| Breakdown groups key on the **raw** value | with `trim_strings`, `" A"` and `"A"` are two groups |

### 11.2 Analytical

| Limitation | Impact |
|---|---|
| Near-miss tries **one** column at a time | two columns drifting together are not found |
| Near-miss caps at 20,000 missing rows | reported as truncated; counts describe a subset |
| Examples fill in encounter order | at skewed proportions the list is 100% one kind (§8.7) |
| Push-down `change_signatures` cover example rows only | not a full-table breakdown |
| Keyless per-column hashes use `hash()` | process-salted; never persist or compare across processes |

### 11.3 Operational

| Limitation | Impact |
|---|---|
| Default engine materialises both sides | plan for push-down past low millions of rows |
| `engine: trino` is **not** live-verified | unit-tested against a fake cursor only; expect surprises of the class that bit Snowflake twice |
| Snowflake nested types need a JS UDF | requires `CREATE FUNCTION`; scalar UDF, one call per row per column, never benchmarked at scale |
| DuckDB push-down fingerprints twice when there are diffs | a `MATERIALIZED` CTE was tried and OOM'd at 100M rows |
| `rowparity report` reads DuckDB and Snowflake only | `IcebergResultSink` is write-only |
| Push-down needs both sides on one engine and connection | export to Parquet for cross-engine comparisons |

### 11.4 Currently dead — verified by running them

The following are still accepted by `compare:` but their implementing modules
have been deleted. **They fail silently.**

| Option | What happens |
|---|---|
| `null_equivalence: true` | accepted, classifies nothing — `_column_diffs` hardcodes `equivalent = False` |
| `ignore_columns_file:` / `ignore_columns_table:` | accepted, then discarded — **the columns you named are still compared** |

Also: `pyproject.toml` declares `schemaparity = "rowparity.coverage_cli:main"`,
but `coverage_cli.py` is gone — running `schemaparity` raises `ModuleNotFoundError`.

And `schema_check:` / `coverage_check:` are no longer case shapes. A YAML
carrying either falls through to the `expected`/`actual` check and raises
*"missing required field 'expected'"*, which does not name the real problem. The
two surviving shapes are `expected:` + `actual:` and `concept_check:`.

**Recommendation:** remove the three dead keys from `_COMPARE_KEYS` and the
`schemaparity` entry point. It is a ten-line change and it converts four silent
failures into clear errors.

---

## 12. Execution trace — one command, end to end

Sections 1–11 are organised around decisions. This one is organised around
control flow: what actually happens, statement by statement, between typing the
command and getting an exit code.

The worked example is a small case with one of each kind of difference, so every
branch below is exercised and the output at the end is real, not illustrative:

```bash
rowparity run scripts/cases_insight_plus \
    --param arena.presto.var.process_batch_id=20260827010000 \
    --csv reports/insight_plus \
    --html reports/insight_plus/run.html 2>&1 | tee run.log
```

Where a step behaves differently for another source type, engine or case shape,
it is called out.

---

### 12.1 Process start

`pyproject.toml` maps one console script:

```toml
[project.scripts]
rowparity = "rowparity.cli:main"
```

The shell invokes **`cli.main()`**, which builds an argparse tree with three
required-choice subcommands and dispatches through a `func` default:

| Subcommand | Handler | Purpose |
|---|---|---|
| `run` | `cli._run` | run cases, exit non-zero on any difference |
| `list` | `cli._list` | enumerate cases — **never touches a warehouse**; `--check` also resolves each `query_file` from disk |
| `report` | `cli._report` | render pass-rate history from a result sink |

```python
args = parser.parse_args(argv)
return args.func(args)          # → _run(args)
```

`sub.add_parser(..., required=True)` means `rowparity` with no subcommand is an
argparse error, not a silent no-op.

For our command the arguments land as:

```python
args.path   = "scripts/cases_insight_plus"
args.param  = ["arena.presto.var.process_batch_id=20260827010000"]   # action="append"
args.csv    = "reports/insight_plus"
args.html   = "reports/insight_plus/run.html"
args.select = None
args.quiet  = False
args.heartbeat = None          # → progress.DEFAULT_HEARTBEAT_SECONDS (30.0)
args.result_sink = None
args.result_sink_prefix = "rowparity"
```

`--param` is `action="append"`, so it is repeatable. `--select` is `nargs="*"`,
so it takes a list of case names.

---

### 12.2 `_run` starts up

#### Progress first, before anything can be slow

```python
progress.configure(
    enabled=not getattr(args, "quiet", False),
    heartbeat_seconds=getattr(args, "heartbeat", None),
)
```

Deliberately the **first statement in the function**. The comment in the source
says why: a case that runs two multi-minute warehouse queries prints nothing at
all until both finish, and from a terminal that is indistinguishable from a
hang — the only way to tell them apart was to open the cluster's web UI and look
for a running query.

Three properties of `progress` that matter operationally:

- **Off by default** (`_enabled = False` at module scope). Importing rowparity
  as a library or running it under pytest stays silent, and **no heartbeat
  threads are created**. Only the CLI switches it on.
- **Writes to `sys.stderr`, flushed on every line.** That is why
  `2>&1 | tee run.log` shows heartbeats as they happen instead of in one burst
  at the end, and why `rowparity run > results.txt` keeps stdout clean and
  parseable.
- **`emit()` swallows every exception.** A closed pager or a full disk is not a
  comparison error; progress reporting must never be the reason a run fails.

#### Parse parameters, then load cases — both inside one guard

```python
try:
    cli_params = parse_cli_params(getattr(args, "param", None))
    cases = discover_cases(args.path, cli_params)
except ParamError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    return 2
if not cases:
    print(f"No cases found at {args.path}", file=sys.stderr)
    return 2
```

`params.parse_cli_params()` splits on the **first `=` only**:

```python
name, value = item.split("=", 1)
```

so a value containing `=` survives intact. An item with no `=`, or an empty
name, raises `ParamError`. Our one argument becomes:

```python
{"arena.presto.var.process_batch_id": "20260827010000"}
```

**Why the whole block is wrapped.** Case loading happens *before* the per-case
`try/except` in §12.4, so without this a bad `--param` or an unresolved
`${name}` would surface as a raw traceback — the opposite of the clear message
`ParamError` goes to the trouble of composing. And it returns **2**, not 1:
"the tool could not run" stays distinct from "the data disagrees" all the way
out to CI (§7.6).

#### Run id and result sink

```python
run_id = str(uuid.uuid4())

if args.result_sink:
    try:
        result_sink = make_result_sink(args.result_sink, run_id,
                                       table_prefix=args.result_sink_prefix)
        print(f"Result sink: {args.result_sink}  run_id={run_id}")
    except Exception as exc:
        print(f"WARNING: could not initialise result sink: {exc}", file=sys.stderr)
```

One `run_id` for the whole invocation, so every case in this run is one
correlatable batch in the history tables. A sink that fails to initialise is a
**warning, not a failure** — persistence is an artifact of the run, not the run.

---

### 12.3 Loading the case

#### `cases.discover_cases()`

```python
if os.path.isdir(path):
    files = []
    for ext in ("*.yml", "*.yaml"):
        files.extend(glob.glob(os.path.join(path, "**", ext), recursive=True))
    for f in sorted(files):
        cases.extend(load_cases_from_file(f, params_, resolve_queries))
```

Recursive glob over both extensions, **sorted** for a stable, reproducible case
order. A single file path is loaded directly.

`resolve_queries` defaults to `True` here; `rowparity list` passes `False`
(§12.3, `param_queries`).

#### `cases.load_cases_from_file()`

```python
doc = yaml.safe_load(fh) or {}
if not isinstance(doc, dict):
    raise ValueError(f"{path}: top level must be a mapping")
defaults      = doc.get("defaults", {}) or {}
multi         = "cases" in doc
file_vars     = (doc.get("vars", {}) or {}) if multi else {}
param_queries = doc.get("param_queries", {}) or {}
raw_cases     = doc["cases"] if multi else [doc]
```

`yaml.safe_load`, never `load` — a case file must not be able to construct
arbitrary Python objects.

**One file, one or many cases.** With a `cases:` list, a sibling `vars:` block
is *file-level* and applies to all of them. Without it, the document **is** the
case, and its `vars:` belongs to that case — `_build_case` picks it up there
instead. That is the whole meaning of the `multi` flag.

**`param_queries:` resolves once per file, not per case:**

```python
if param_queries and resolve_queries:
    seed = params.resolve_variables(file_vars, {}, params_)
    query_vars = resolve_param_queries(param_queries, seed,
                                       base_dir=os.path.dirname(path) or ".")
elif param_queries:
    query_vars = {str(n).lower(): "${" + str(n) + "}" for n in param_queries}
    deferred   = frozenset(query_vars)
```

Two cases keying off "the latest batch" must see the **same** batch. Resolving
per case would let a batch landing mid-run compare two different populations —
exactly the kind of difference that looks like a data defect.

The `elif` is the `rowparity list` path. Resolution is off, but these names are
legitimately declared, so failing with "unresolved parameter" would be wrong and
would stop listing cases at all. Each name is substituted to **its own literal
placeholder** — a single pass, so the text is unchanged and *visibly* still
unresolved rather than a fabricated value. Those stand-ins are then dropped again
in `_build_case` (below), so a real run still gets the proper error.

#### `_merge_defaults()`

```python
out = dict(defaults or {})
for k, v in case.items():
    if k == "compare" and isinstance(v, dict) and isinstance(out.get("compare"), dict):
        merged = dict(out["compare"]); merged.update(v)
        out["compare"] = merged
    else:
        out[k] = v
```

Shallow merge, **with one exception**: `compare:` merges one level deeper, so a
`defaults:` block can set a shared comparison policy (`float_tolerance`,
`max_examples`) and an individual case can add `keys:` without clobbering it.
Everything else — `expected:`, `actual:`, `connection:` — replaces wholesale.

#### `cases._build_case()` — where `${…}` disappears

```python
raw = dict(raw)
case_vars     = raw.pop("vars", None) or {}
raw.pop("param_queries", None)                 # resolved once per file, above
drilldown_raw = raw.pop("drilldown", None)     # substituted later — see below
variables = params.resolve_variables(file_vars, case_vars, cli_params)
for name, value in (query_vars or {}).items():
    variables.setdefault(name, value)          # query-resolved sits below --param/env
raw = params.substitute_spec(raw, variables, where=f"case '{raw['name']}' ({source_file})")
for name in deferred_names:
    variables.pop(name, None)
```

`params.resolve_variables()` merges four sources, later winning:

```
file vars:   <   case vars:   <   ROWPARITY_VAR_*   <   --param
```

Every name is lower-cased (`_stringify`), so `${BATCH_ID}` and `${batch_id}` are
one name — necessary because the env-var form has to be upper-cased and silently
failing to match would be a nasty footgun. YAML ints, bools and `None` are
stringified, since placeholders substitute as text.

`query_vars` go in with `setdefault`, which is what places them **below**
`--param` and the environment (those short-circuit the query entirely) and
**above** a `vars:` default.

`params.substitute_spec()` recurses through the **entire raw case dict** —
strings, dicts and lists — before any shape dispatch. So every case type gets
substitution for free and no spec can reach an engine still holding a
placeholder. The placeholder pattern is:

```python
_PLACEHOLDER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_.]*)\}")
```

Dots are inside the character class on purpose. Query files arrive pre-templated
by another system with namespaced names like
`${arena.presto.var.process_batch_id}`. Before dots were recognised the name did
not match, so it was **neither substituted nor reported unresolved** — the
literal text reached Presto inside quotes as a valid string matching no batch,
both sides returned zero rows, and the run reported EQUIVALENT.

**Two blocks are deliberately excluded from this pass:**

- `param_queries:` — already resolved, once, per file.
- `drilldown:` — its placeholders (`${batch_hour}`, `${batch_hour_start}`, …) are
  *derived from* the batch parameter and do not exist yet. Leaving it in would
  also mean `rowparity list` could not enumerate a case without being handed a
  batch id, which listing has no business needing.

The final `variables.pop(name)` loop removes the `list`-mode stand-ins. They
stood in for themselves so listing worked; they must not survive onto the case,
because `query_file` contents are substituted at **run** time and a literal
`"${batch_id}"` reaching an engine is precisely the failure this design exists
to prevent.

#### Shape dispatch

```python
if "concept_check" in raw:
    return build_concept_check_case(raw, source_file)

for required in ("expected", "actual"):
    if required not in raw:
        raise ValueError(f"{source_file}: case is missing required field '{required}'")

engine = raw.get("engine")
if engine not in _ENGINES:          # {None, "python", "duckdb", "snowflake", "trino"}
    raise ValueError(f"... unknown engine {engine!r} (known: ...)")
```

| Top-level block | Built as |
|---|---|
| `concept_check:` | `ConceptCheckCase` |
| `expected:` + `actual:` | `Case` |

An unknown `engine:` is rejected here, at load time, before anything connects.

The `Case` carries `variables` forward for later. **No SQL file has been read
yet** — `query_file` contents are resolved at run time, in §12.5.

---

### 12.4 Per-case execution

```python
for case in cases:
    if only and case.name not in only:            # --select
        continue
    is_xfail = "xfail" in case.tags
    try:
        result = case.run(result_sink=result_sink)
    except Exception as exc:
        print(f"Case '{case.name}': ERROR - {type(exc).__name__}: {exc}\n")
        errors.append((case.name, exc))
        failures += 1
        continue
    results.append((case.name, result))
    print(render_console(result, case.name))
    if is_xfail:
        if result.equivalent:
            print("  [XFAIL-UNEXPECTED-PASS] ...")
            xfail_unexpected_pass += 1; failures += 1
        else:
            print("  [XFAIL] expected failure confirmed")
            xfail_confirmed += 1
    elif not result.equivalent:
        failures += 1
```

**That `try/except` is why one failing case does not kill the run.** It turns an
`EmptyComparisonError`, an `IdenticalSourcesError`, a `ParamError` from a
`query_file`, or a Trino `COLUMN_NOT_FOUND` into a reported line plus
`failures += 1`. This is what makes a directory of cases a suite rather than a
fragile chain.

**Errored cases are collected separately** (`errors`), because they never produce
a `ComparisonResult` and are therefore invisible to every reporter that walks
`results`. `write_run_report` takes them as a second argument: a report that
silently omits the case that blew up is worse than no report.

**`xfail` inverts the expectation.** A tagged case that differs is confirmed; a
tagged case that *passes* is `XFAIL-UNEXPECTED-PASS` and counts as a failure —
usually meaning the defect it pinned has been fixed and the tag should go.

#### `Case.config()` → `CompareConfig`

```python
unknown = set(self.compare) - _COMPARE_KEYS
if unknown:
    raise ValueError(f"case '{self.name}': unknown compare option(s): {sorted(unknown)}")

options = {k: v for k, v in self.compare.items() if k not in _EXCLUSION_KEYS}
if isinstance(options.get("breakdown_by"), str):
    options["breakdown_by"] = [options["breakdown_by"]]
return CompareConfig(**options)
```

**Unknown keys are rejected, not ignored.** A typo'd `ignore_colums:` would
otherwise silently do nothing and the run would look clean.

`breakdown_by` is normalised from a string to a list here, so everything
downstream sees one shape and never has to ask which it got.

#### `Case.run()` — note the ordering

```python
cfg = self.config(base_dir)

if cfg.null_equivalence and self.engine in ("duckdb", "snowflake", "trino"):
    raise ValueError(...)                     # refuse rather than quietly differ

self._check_breakdown(cfg)                    # ← before a single row is fetched
progress.emit(f"Case '{self.name}'")
self._guard_identical_sides(base_dir, cfg)    # ← likewise

if self.engine in ("duckdb", "snowflake", "trino"):
    runner = {"duckdb": self._run_duckdb_pushdown,
              "snowflake": self._run_snowflake_pushdown,
              "trino": self._run_trino_pushdown}[self.engine]
    with progress.step(f"{self.engine} push-down") as st:
        result = runner(base_dir, cfg)
    result.compare_seconds = st.elapsed
else:
    ... default engine, three timed steps ...

result.expected_label = self.expected_label
result.actual_label   = self.actual_label
result.row_summary    = self.row_summary
self._generate_drilldowns(result, base_dir)
self._guard_empty(result, cfg)
if result_sink:
    result_sink.write(self.name, self.tags, result)
```

Both configuration guards run **before any connection is opened**, so a
misconfigured case fails in the first second rather than after the warehouse has
spent an hour producing an answer that proves nothing. See §7 for what each one
prevents.

Under push-down there is no per-side load to time separately — the whole
operation is one step — which is why only `compare_seconds` is set.

`_generate_drilldowns` runs **after** the comparison (it needs the diff) and
**before** `_guard_empty`. It is a no-op when the case has no `drilldown:` block
or when the result is equivalent, and it swallows its own exceptions:

```python
except Exception as exc:
    progress.emit(f"  drill-down SQL not generated: {type(exc).__name__}: {exc}")
    return
```

Losing a whole parity run because a helper template has a typo would be entirely
the wrong trade.

#### The default-engine branch, timed in three parts

```python
with progress.step(f"expected  ({self.expected.get('type','?')})") as st:
    expected_tbl = load_source(self.expected, base_dir=base_dir, variables=self.variables)
    st.result(progress.describe_table(expected_tbl))
expected_seconds = st.elapsed
# …same for actual…
with progress.step("comparing") as st:
    result = compare_tables(expected_tbl, actual_tbl, cfg)
    st.result(f"{len(result.compared_columns)} columns compared")
result.expected_load_seconds = expected_seconds
result.actual_load_seconds   = actual_seconds
result.compare_seconds       = st.elapsed
```

Three numbers, not one total, and kept apart on purpose: *"the query was slow"*
is a warehouse problem, *"the comparison was slow"* is ours.

`progress.step()` is a context manager that emits `-> label ...`, starts a
**daemon** heartbeat thread, times the body, and then emits either
`OK label 71.4s 87,412 rows x 262 cols` or, on exception,
`FAILED label 4m12s TrinoUserError: ...` **and re-raises untouched** — "it failed
after four minutes" is still worth being told. The thread is a daemon that only
ever writes to the stream, so it cannot keep the process alive and cannot fail
the run; `stop()` joins it with a one-second bound so a wedged stream cannot
block.

---

### 12.5 Fetching each side

`sources.load_source()` validates the spec and dispatches on `type` through
`_HANDLERS` (12 names, 10 distinct functions — `sql` aliases `duckdb`, `feather`
aliases `arrow`):

```python
if not isinstance(spec, dict) or "type" not in spec:
    raise SourceError(...)
handler = _HANDLERS.get(spec["type"])
if handler is None:
    raise SourceError(f"unknown source type '{kind}'. Known: {sorted(_HANDLERS)}")

if spec.get("vars"):
    from .params import merge_side_vars
    variables = merge_side_vars(spec["vars"], variables)
return handler(spec, base_dir, variables)
```

Note the truthiness test on `spec.get("vars")` rather than a `is not None`
check. The comment explains it: `resolve_query` reads `variables is not None` as
"substitution is in play", so replacing `None` with an empty dict would start
rejecting `${…}` in query files that previously passed through untouched.

#### `params.merge_side_vars()` — the inverted precedence

```python
merged = dict(variables or {})
merged.update(_stringify(side_vars))       # side var LAST → side var WINS
```

This is what lets both sides share one `query_file` and still run different
queries: `from ${facts}.ad` becomes `from mrm_log_flat.default.ad` on one side
and `from etl.public_test1.ad` on the other.

**A side var outranks `--param` and the environment**, inverting the precedence
everywhere else in `params.py`. A side var is not a knob; it is half of what
makes the two sides different, and letting `--param facts=x` reach both sides
would point them at the same catalog and produce a confident EQUIVALENT for
comparing a table with itself. A case that *wants* a side overridable says so by
templating the value: `vars: {facts: "${old_catalog}"}`.

#### `sources.resolve_query()` — where the SQL file is finally read

```python
if spec.get("query"):
    return spec["query"]                       # inline query wins
qf = spec.get("query_file")
if qf:
    path = _resolve_path(qf, base_dir)         # relative to the YAML's directory
    sql = open(path, encoding="utf-8").read().strip()
    if variables is not None:
        sql = substitute(sql, variables, where=path)
    return sql
```

This is where `${arena.presto.var.process_batch_id}` becomes `20260827010000`
and `${facts}` becomes this side's catalog. An unresolved name raises
`ParamError` **here**, naming the file, and is caught by the per-case handler in
§12.4.

#### `sources._trino()` — the batched fetch

```python
con = _trino_connect(spec)
try:
    cur = con.cursor()
    cur.execute(query)
    col_names  = [d[0] for d in (cur.description or [])]
    batch_rows = int(spec.get("fetch_batch_rows") or _trino_batch_rows(len(col_names)))

    tables, fetched = [], 0
    while True:
        rows = cur.fetchmany(batch_rows)
        if not rows:
            break
        tables.append(pa.Table.from_pylist([dict(zip(col_names, r)) for r in rows]))
        fetched += len(rows)
        progress.emit(f"     ... fetched {fetched:,} rows")

    if not tables:
        return pa.table({col: [] for col in col_names})   # keep the schema
    if len(tables) == 1:
        return tables[0]
    return pa.concat_tables(tables, promote_options="permissive")
finally:
    con.close()
```

Five things here earn their place:

1. **`fetchmany`, not `fetchall`.** See §5.2 for the measured numbers — peak
   Python memory goes from 1.92 GB to a flat 0.15 GB at 100k × 262.
2. **Batch size follows a cell budget**, not a row count:
   `_TRINO_TARGET_CELLS = 2_000_000`, clamped to `[1_000, 100_000]` rows. A
   262-column row is two orders of magnitude heavier than a 1-column one, so a
   fixed row count is either wasteful on narrow results or enormous on wide ones.
   `fetch_batch_rows:` in the spec overrides it.
3. **`promote_options="permissive"` is a correctness requirement.** Types are
   inferred per batch, so a column all-NULL in one batch infers as Arrow `null`
   and as `int64` in the next; without promotion those batches cannot be
   concatenated at all. Batching would have converted a memory problem into a
   correctness one.
4. **The zero-row branch preserves columns** from `cursor.description`, which is
   populated even for an empty result. A table with no columns loses the schema
   entirely, and every downstream column report would be blank.
5. **The row-count heartbeat.** A multi-minute fetch otherwise shows only "still
   running"; a growing row count says whether it is progressing or stuck.

#### `trino_auth.connect()`

`resolve_connection_args()` merges the case's `connection:` block over the
`TRINO_*` environment variables — **the YAML block wins** — for `host`, `port`,
`user`, `catalog`, `schema` and `http_scheme`. A missing `host` raises with the
two ways to set it named.

Auth mode is then chosen by what is present in the **environment only**:

| Mode | Trigger | Wire format |
|---|---|---|
| JWT | `TRINO_JWT_TOKEN` | `trino.auth.JWTAuthentication` → Bearer |
| Basic | `TRINO_PASSWORD` | `trino.auth.BasicAuthentication` |
| None | neither | no auth header (open dev/test clusters) |

**Secrets are never read from a case file**, because case files are committed to
git. The `connection:` block carries non-secret settings only.

Both sides are now a `pyarrow.Table`. **Nothing downstream knows the data came
from Trino.**

---

### 12.6 The comparison

`compare.compare_tables()`.

#### Column resolution

```python
only_exp  = [c for c in exp_cols if c not in act_set]
only_act  = [c for c in act_cols if c not in exp_set]
candidate = cfg.select if cfg.select else [c for c in exp_cols if c in act_set]
compared  = [c for c in candidate if c not in set(cfg.ignore_columns)]
compared  = [c for c in compared if c in exp_set and c in act_set]
type_mismatches = [(c, str(et), str(at)) for c in compared if not et.equals(at)]
```

One function produces all three column states:

| Result field | Reported as |
|---|---|
| `compared_columns` | `MATCHED` |
| `columns_only_in_expected` / `columns_only_in_actual` | `DIFF` |
| `type_mismatches` | `MATCHED - TYPE DIFF` |

A separate zero-row schema pass is therefore unnecessary — column status falls
out of the row comparison for free.

Column-set and type problems only *fail* the run under `strict_columns: true`,
but they are **always reported**:

```python
if cfg.strict_columns and (only_exp or only_act or type_mismatches):
    result.equivalent = False
```

Both Arrow schemas are stored on the result, so a reporter can print a column's
type on each side — including for a column present on one side only, where the
type is the single most useful thing to know about it.

#### Materialise, optionally pre-canonicalise, dispatch

```python
exp_rows = expected.to_pylist()
act_rows = actual.to_pylist()

if cfg.vectorized:
    canon_columns = sorted(set(sorted_cols) | set(cfg.keys or []))
    exp_canon = canon_columns_vectorized(expected.schema, expected, canon_columns, canon_cfg)
    act_canon = canon_columns_vectorized(actual.schema, actual, canon_columns, canon_cfg)

if cfg.keys: _compare_keyed(...)
else:        _compare_keyless(...)
```

The vectorized cache is **positional** — `exp_canon[column][row_index]` — which
is why the keyed index below stores row positions rather than the row dicts.
Note the union with `cfg.keys`: key columns are canonicalised even if they are
not in the compared set.

#### Keyed

```python
for k in keys:
    if k not in exp_schema.names or k not in act_schema.names:
        raise ValueError(f"key column '{k}' is missing from expected or actual table")

for i, r in enumerate(exp_rows):
    exp_index[_key_of(r, exp_schema, keys, canon_cfg, exp_canon, i)].append(i)
# …same for actual…

result.duplicate_keys_expected = sum(len(v) - 1 for v in exp_index.values() if len(v) > 1)
result.duplicate_keys_actual   = sum(len(v) - 1 for v in act_index.values() if len(v) > 1)
```

`_key_of()` canonicalises **only the key columns** and returns the tuple, which
is used **raw as a dict key** — never hashed (§4.2 for the two reasons).
Canonicalisation applies here too, so `unordered_list_columns` affects which rows
*pair*: `[7, 12]` and `[12, 7]` land in the same bucket only if that column is
declared unordered.

Duplicate keys are counted as *excess* rows per key (`len(v) - 1`), not as
duplicate groups.

Then the breakdown positions are validated as a backstop for
`compare_tables()` called directly, and the three set operations run:

```python
missing = exp_keys - act_keys
added   = act_keys - exp_keys
result.missing_keys = list(missing)
result.added_keys   = list(added)

for key in missing:            # counts rows, not keys: += len(idxs)
for key in added:              # likewise
for key in exp_keys & act_keys:
    e_digest = row_digest(canon_row(exp_schema, e, cols, canon_cfg))
    a_digest = row_digest(canon_row(act_schema, a, cols, canon_cfg))
    if e_digest != a_digest:
        result.changed_count += 1
        coldiffs = _column_diffs(...)
        result.changed_keys.append(key)
        sig = tuple(sorted(c.column for c in coldiffs))
        stats = result.change_signatures.setdefault(sig, ChangeSignature(columns=sig))
        stats.count += 1
        score = _accumulate_deltas(stats, coldiffs, cfg)
        if stats.example is None or score > stats._example_score:
            stats.example, stats._example_score = diff, score
```

Four things happen in that last loop that are easy to miss:

- **The digest is the fast path.** One 16-byte comparison decides whether the row
  changed; `_column_diffs()` — which canonicalises every column — only runs when
  it did.
- **The signature is the sorted tuple of differing column names.** That is the
  entire grouping key behind §8.6.
- **`_accumulate_deltas` folds the row into a per-column movement profile** and
  returns how *extreme* it was, which is how the kept example ends up being the
  most diagnostic row rather than whichever arrived first. Deltas are quantised
  to the tolerance grid first — without that no float column would ever report a
  constant delta, because the last bits would differ on every row.
- **`became_null` / `was_null` are counted apart from `lower` / `higher`.** A
  value appearing or disappearing is not a movement, and folding it into the
  numeric profile would invent a delta from nothing.

The breakdown is accumulated alongside, keyed on the **raw** column value
(§8.3), and covers side totals as well as differences so the report can show a
share rather than only a count.

#### Keyless

No key, so no pairing. Every row is fingerprinted and the two bags subtracted;
`changed_count` stays 0 by construction. The per-column value fingerprint
described in §4.1 is accumulated in the same pass.

#### Near-miss and the final verdict

```python
if cfg.near_miss and cfg.keys and result.missing_keys and result.added_keys:
    result.near_miss = near_miss.analyse(result.missing_keys, result.added_keys, cfg.keys)

if result.total_differences > 0:
    result.equivalent = False
return result
```

Guarded on **both** lists being non-empty — with nothing on one side there is
nothing to pair, and the analysis would be a wasted O(columns × rows) pass.

---

### 12.7 Reporting and exit

```python
if result_sink:
    result_sink.close()

if args.json or args.md:
    write_reports(results, json_path=args.json, md_path=args.md)
if getattr(args, "csv", None):
    paths = write_csv_reports(results, args.csv)
    print(f"Wrote {len(paths)} per-column CSV report(s) to {args.csv}/")
if getattr(args, "html", None):
    try:
        write_run_report(args.html, results, errors, run_id=run_id)
        print(f"Wrote HTML report to {args.html}")
    except Exception as exc:
        print(f"WARNING: could not write HTML report: {exc}", file=sys.stderr)
```

**Markdown is written before JSON**, deliberately: they are independent
artifacts, and writing JSON first meant a failure there took the Markdown report
down with it — losing both on precisely the runs that had something to report.

**The HTML report is wrapped and warned, never fatal.** A report is an artifact
of the run, not the run; losing it must not change the verdict the comparison
already reached. Note it is the only reporter that receives `errors` as well as
`results`.

`write_csv_reports` → `to_column_rows` maps each column onto a status
(§8.4) and writes one `<case>.csv` per case — the readable form when schema
drift runs to hundreds of columns.

#### The summary line and the exit code

```python
total   = len(results)
n_xfail = xfail_confirmed + xfail_unexpected_pass
passed  = sum(1 for _, r in results if r.equivalent) - xfail_unexpected_pass
summary = f"Summary: {passed}/{total - n_xfail} equivalent"
...
return 1 if failures else 0
```

The denominator excludes `xfail` cases, so a suite with known-failing cases
still reads as "N of M equivalent" over the cases that were expected to pass.

| Code | Meaning | Raised where |
|---|---|---|
| 0 | every case equivalent | end of `_run` |
| 1 | a case differed, or a case errored | end of `_run` |
| 2 | cases could not be **loaded** — bad `--param`, unreadable YAML, none found | the guard in §12.2 |

#### A real run

The output below is from an actual run of a three-row case with one of each
difference — a missing row, an added row (the same logical row with a drifted
`day`), and a changed row:

```
Case 'demo_parity'
  -> expected  (inline) ...
  OK expected  (inline)  0.8s  3 rows x 4 cols
  -> actual    (inline) ...
  OK actual    (inline)  0.0s  3 rows x 4 cols
  -> comparing ...
  OK comparing  0.0s  4 columns compared
Case 'demo_parity': [DIFFERENT] keyed on ['day', 'region'] | expected=3 actual=3 | missing=1 added=1 changed=1
  timing: expected 0.8s | actual 0.0s | compare 0.0s | total 0.8s
  near misses (one key column apart, no query run):
    drop day: pairs 1 (100% of missing)
        e.g. 2026-08-28 -> 2026-08-29
    => 1 of 1 missing rows are not missing: they pair with an added row once 'day' is dropped from the key.
  row differences by region:
    north  rows 2/2  missing=1 added=1 changed=0  differing=100.0%
    south  rows 1/1  missing=0 added=0 changed=1  differing=100.0%
  change signatures (1 distinct, 1 changed row(s) total):
    1x  {orders, revenue}  [100% of changed]
        by group: south 1
        orders: lower 1/1  -1 (constant)
        revenue: lower 1/1  -10 (constant)
        most extreme: key=(2026-08-27, south): orders: 7 -> 6, revenue: 200 -> 190
  first 3 difference(s):
  - MISSING (in expected, absent from actual): key=(2026-08-28, north)
  + ADDED   (in actual, absent from expected): key=(2026-08-29, north)
  ~ CHANGED key=(2026-08-27, south): orders: 7 -> 6, revenue: 200 -> 190

Summary: 0/1 equivalent, 1 failing
```

Everything above the summary is one `render_console(result, case_name)` call
except the four `->` / `OK` lines, which are `progress` writing to **stderr** as
the steps happen. In a terminal they interleave; in
`rowparity run > out.txt` only the stdout half lands in the file.

Read the near-miss block first: it says the missing row and the added row are the
**same logical row** whose `day` drifted, so the real count of lost rows is zero.
Without it this reads as three separate problems.

---

### 12.8 The whole path

```
shell
 └─ cli.main ──► argparse (run | list | report) ──► args.func = cli._run
     ├─ progress.configure                      FIRST statement, stderr, flushed
     ├─ params.parse_cli_params                 split on first '=' only
     ├─ cases.discover_cases                    **/*.yml + **/*.yaml, sorted
     │   └─ cases.load_cases_from_file          one file, one or many cases
     │       ├─ yaml.safe_load
     │       ├─ param_queries.resolve_param_queries    ONCE per file
     │       ├─ cases._merge_defaults           defaults:, compare: merged deeper
     │       └─ cases._build_case
     │           ├─ pop vars: / param_queries: / drilldown:
     │           ├─ params.resolve_variables    file < case < env < --param
     │           ├─ params.substitute_spec      ${…} over the whole case
     │           └─ shape dispatch              concept_check | expected+actual
     ├─ make_result_sink                        one run_id for the invocation
     └─ for case in cases:  try:                ← one failure never kills the run
         └─ Case.run
             ├─ Case.config                     unknown compare option → raise
             ├─ Case._check_breakdown           breakdown_by must be a key
             ├─ Case._guard_identical_sides     refuse a self-comparison
             │                                  ↑ both before any connection
             ├─ progress.step "expected"
             │   └─ sources.load_source → sources._trino
             │       ├─ params.merge_side_vars  ${facts} → this side's catalog
             │       ├─ sources.resolve_query   reads the .sql, substitutes
             │       ├─ trino_auth.connect      YAML over env; JWT | Basic | none
             │       └─ fetchmany loop → concat_tables(permissive) → pa.Table
             ├─ progress.step "actual"          same file, other catalog
             ├─ progress.step "comparing"
             │   └─ compare.compare_tables
             │       ├─ _resolve_columns        MATCHED / DIFF / TYPE DIFF
             │       ├─ canon_columns_vectorized    (only if vectorized: true)
             │       └─ _compare_keyed  (or _compare_keyless)
             │           ├─ _key_of             key tuple, used RAW
             │           ├─ canon_row → row_digest       blake2b, 16 bytes
             │           ├─ _column_diffs       only for rows whose digest differs
             │           ├─ _accumulate_deltas  direction, constant?, extremeness
             │           └─ breakdown groups    raw value, over EVERY row
             │       └─ near_miss.analyse       which key column drifted (no I/O)
             ├─ labels + row_summary onto the result
             ├─ Case._generate_drilldowns       SQL only; failures swallowed
             ├─ Case._guard_empty               zero rows ≠ equivalent
             └─ result_sink.write
         └─ render_console  →  write_reports (md then json)
                            →  write_csv_reports
                            →  write_run_report (results + errors)
                            →  exit 0 | 1 | 2
```

---

### 12.9 Three seams worth knowing

If you are going to change this codebase, these are the three places where a
change stays local. Everywhere else, it does not.

**Seam 1 — `pyarrow.Table`, at the end of §12.5.** Everything after it is
engine-agnostic. One comparison engine serves Trino, Snowflake, DuckDB, Parquet,
Delta, Iceberg, Spark and inline fixtures because a source's entire contract is
*return an Arrow table*. Adding a source type is one function and one line in
`_HANDLERS`; nothing else in the codebase learns about it.

The corollary is a constraint worth stating: **anything a source cannot express
in Arrow does not exist downstream.** That is why type-awareness lives in
`hashing.py` dispatching on `pa.DataType` rather than in each source.

**Seam 2 — `ComparisonResult`, at the end of §12.6.** Every reporter consumes
the same object: console, JSON, Markdown, CSV, the single-run HTML page, the
result sink and the history page. Add a field and it is available to all of them
at once; add a reporter and nothing upstream changes.

`concept_check.py` is the proof: it performs a completely different analysis —
business-concept coverage across a table remodel, fetching no rows at all — and
emits a `ComparisonResult`. Every reporter works on it unchanged, which is why it
is 157 lines instead of a parallel reporting stack.

The corollary: `ComparisonResult` has to carry presentation-only fields
(`expected_label`, `actual_label`, `row_summary`) that the comparison never
reads. That is the price of one object, and it is worth paying.

**Seam 3 — the `try/except` in §12.4.** One case's failure is a reported line and
a `failures += 1`, never a dead run. This is what makes a directory of cases
usable as a suite: a new case that cannot connect yet, a case whose batch has
aged out, a case with a typo in its SQL — none of them stop the other twenty from
producing results.

The corollary is the reason `errors` exists as a separate list: a case that never
produced a `ComparisonResult` is invisible to every reporter that walks
`results`, so it has to be carried alongside and rendered explicitly.

---

## 13. Worked example — adding `f_supply_portfolio_hourly`

§9 states the rules. This section does the work: every file, in order, with the
reason for each and the traps between them. It assumes you are adding a second
parity case alongside `f_demand_portfolio_hourly`.

### 13.0 What already exists, and what a second case adds

`f_demand_portfolio_hourly` is six files. Five belong to it; one is shared.

```
sql/insight_plus/
    f_demand_portfolio_hourly.sql              ← the parity query  (185 KB)
    f_demand_portfolio_hourly_drilldown.sql    ← the investigation query
scripts/cases_insight_plus/
    f_demand_portfolio_hourly.yaml             ← the case definition
scripts/
    trino_connectivity_check.py                ← SHARED, no change needed
tests/
    test_insight_plus_case.py                  ← wiring assertions
    test_insight_plus_sql_sync.py              ← SQL template assertions
```

**The headline: you edit nothing. All five files are new.**

That is not an accident. `cases.discover_cases()` globs `**/*.yaml` recursively
and sorts, so dropping a YAML into `scripts/cases_insight_plus/` registers it —
there is no manifest, no registry, no import to update. Verified:

```
$ rowparity list scripts/cases_insight_plus
f_supply_portfolio_hourly [insight_plus]  (scripts/cases_insight_plus/f_supply_portfolio_hourly.yaml)
f_demand_portfolio_hourly [insight_plus, hoover]  (scripts/cases_insight_plus/f_demand_portfolio_hourly.yaml)
```

The two test files are **copied, not edited**. Both are pinned to the demand case
by module-level constants (`CASE_FILE`, `HOOVER_SQL`, `SQL`, `CASE`) and by
`_case()` matching on the case name, plus hard counts (262 columns, 83
dimensions, 179 metrics) that are specific to that query. Adding supply
assertions to them would fight those constants; a sibling pair is cleaner and
lets the two cases evolve apart.

### 13.1 The build order, and why it is this order

| # | File | New / edit | Cost of getting it wrong |
|---|---|---|---|
| 1 | `sql/insight_plus/f_supply_portfolio_hourly.sql` | **new** | everything downstream is built on it |
| 2 | `scripts/cases_insight_plus/f_supply_portfolio_hourly.yaml` | **new** | the case cannot load |
| 3 | `tests/test_supply_sql_sync.py` | **new** | a bad placeholder is found by a live run, not a test |
| 4 | `tests/test_supply_case.py` | **new** | keys drift from the query silently |
| 5 | `sql/insight_plus/f_supply_portfolio_hourly_drilldown.sql` | **new** | no transaction ids; the parity result still works |
| 6 | *(nothing)* | — | — |

Order matters for one reason: **steps 3 and 4 are the only offline checks that a
run is worth starting.** Writing them after the first live run means paying
warehouse time to learn what a millisecond of pytest would have told you.

Step 5 is deliberately last. The drill-down is an aid to *reading* a result. You
cannot design it until you have seen which dimensions differ, and the case runs
fine without a `drilldown:` block.

---

### Step 1 — the parity SQL

`sql/insight_plus/f_supply_portfolio_hourly.sql`

**One file serves both sides.** Take your existing supply query and replace, in
this order:

**1a. Every fact-table reference → `${facts}`.**

```sql
from mrm_log_flat.default.ack      →      from ${facts}.ack
```

Do this for **every** occurrence, in every `UNION ALL` branch, in every subquery.
One missed reference means that branch reads the same catalog on both sides and
silently agrees — the single most dangerous mistake available here, and the
reason step 3 exists.

**1b. Dimension tables stay literal.**

```sql
left join db.default.d_network nw on ...       -- unchanged, on purpose
```

`d_network`, `d_ad_unit` and friends are shared reference data. Template them and
a dimension difference masquerades as a migration defect.

**1c. The sampling predicate → `${sampling_filter}`, on every branch.**

```sql
and ${sampling_filter} --sampling filter
```

Keep the trailing marker comment: step 3 counts it to prove no branch was
missed. This predicate goes in the **case-level** `vars:` (step 2), never a
per-side one — that is what makes "one side sampled, one not" structurally
impossible. The demand case learned this the expensive way: a 77-minute run
returning 2,719 rows against 1,113,423, a ratio of 409, which measured the
sampling and nothing else.

**1d. The batch predicate.**

```sql
and process_batch_id = '${arena.presto.var.process_batch_id}'
```

Dotted name, quoted in SQL, no default anywhere.

**1e. Do not write `${...}` in a comment.**

`params.substitute()` operates on text and does not know what a comment is. A
placeholder in a header comment is a real substitution site. Write the names
bare:

```sql
-- Placeholders: facts, sampling_filter, arena.presto.var.process_batch_id
```

> **Checkpoint.** Every fact table templated, dimension tables literal, one
> sampling marker per branch, no `${}` in comments.

---

### Step 2 — the case YAML

`scripts/cases_insight_plus/f_supply_portfolio_hourly.yaml`

```yaml
cases:
  - name: f_supply_portfolio_hourly
    expected_label: Hoover
    actual_label: Hoover++
    description: >-
      The f_supply_portfolio_hourly aggregate must produce identical rows
      whether built from the Hoover layout or the Hoover++ layout. Both sides
      are queries; neither is materialised.

    # Shared by BOTH sides. The one thing that must never differ.
    vars:
      sampling_filter: "bitwise_and(coalesce(request__bit_flags, BIGINT '0'),bitwise_left_shift(BIGINT '1', 59)) > 0"

    expected:
      type: trino
      query_file: ../../sql/insight_plus/f_supply_portfolio_hourly.sql
      vars: {facts: mrm_log_flat.default}

    actual:
      type: trino
      query_file: ../../sql/insight_plus/f_supply_portfolio_hourly.sql
      vars: {facts: etl.public_test1}

    compare:
      keys:
        - event_date
        - network_id
        # ... every GROUP BY dimension, one per line, alphabetical
      unordered_list_columns: []      # any array whose order the engine may vary
      max_examples: 50
      breakdown_by: <a key column that partitions the UNION>
      near_miss: true

    row_summary:
      - {label: Batch,   columns: [process_batch_id, event_date]}
      - {label: Network, columns: [network_id, content_owner_id]}

    tags: [insight_plus]
```

Five things to get right:

1. **`query_file` is relative to the YAML's directory.** From
   `scripts/cases_insight_plus/` up two levels is the repo root, hence
   `../../sql/...`.
2. **`keys` must be exactly the GROUP BY dimensions** — no `sum()` columns. See
   §4.4. If they turn out not to be unique, rowparity reports `duplicate_keys_*`
   rather than guessing.
3. **`breakdown_by` must be one of `keys`.** If your supply query is not a union,
   omit it — a breakdown over a single group is a table with one row.
4. **`unordered_list_columns` for arrays the engine may reorder.** A
   single-element `array[...]` construction cannot vary and does not need
   listing; an `array_agg` does.
5. **No `engine:` key.** The default Python engine is what supports
   `breakdown_by` and `near_miss`; push-down rejects them (§5.3).

Now the first checkpoint that costs nothing:

```bash
rowparity list scripts/cases_insight_plus
```

Both cases must appear, **without `--param`**. If this needs a batch id, a
run-time value has leaked into a load-time slot (§6.4).

Plain `list` proves the **YAML** parses. It proves nothing about the SQL, because
`query_file` contents are read at *run* time — a `${oops_undefined}` in your
`.sql` lists perfectly cleanly and fails only once the run starts. Use `--check`
to close that gap without opening a connection:

```bash
rowparity list scripts/cases_insight_plus --check \
    --param arena.presto.var.process_batch_id=20260827010000
```

It resolves both sides' query files against exactly the variables a run would
use, reads local files only, and exits **2** listing every name that will not
resolve:

```
  f_supply_portfolio_hourly [expected]: unresolved parameter(s) ['oops_undefined']
  in .../f_supply_portfolio_hourly.sql. Define them in the case's vars: block,
  set ROWPARITY_VAR_OOPS_UNDEFINED, or pass --param oops_undefined=<value>.
  Known: ['arena.presto.var.process_batch_id', 'facts', 'sampling_filter']
ERROR: 2 query file(s) will not resolve.
```

`--check` is opt-in rather than part of plain `list` because the batch parameter
legitimately has no default: checking without it reports the batch as unresolved
on every case, which is a false alarm on the one name that is *supposed* to be
supplied per run. Pass the same `--param` you would pass to `run`.

Step 3 pins the same property as a pytest assertion, so CI catches it without
anyone remembering to type `--check`.

---

### Step 3 — the SQL template test

`tests/test_supply_sql_sync.py` — copy `tests/test_insight_plus_sql_sync.py` and
change the constants at the top:

```python
SQL  = os.path.join(ROOT, "sql", "insight_plus", "f_supply_portfolio_hourly.sql")
CASE = os.path.join(ROOT, "scripts", "cases_insight_plus", "f_supply_portfolio_hourly.yaml")

HOOVER      = "mrm_log_flat.default"
HOOVER_PLUS = "etl.public_test1"

SAMPLING_MARKER       = "--sampling filter"
EXPECTED_SAMPLING_LINES = <how many UNION ALL branches your query has>
EXPECTED_FACT_REFS      = <how many ${facts}. references it should have>
EXPECTED_BATCH_REFS     = <how many batch predicates it should have>
```

**Three counts, and they are counts on purpose.** A *set* of placeholder names
cannot see a template that is half converted: hardcode the batch in one of three
branches and the set still contains `arena.presto.var.process_batch_id`, because
the other two branches supply it. One branch pinned to a stale batch reads a
different hour than the other two, **on both sides**, so the totals stay
plausible, nothing errors, and the drift reads as a migration defect.

The assertions you inherit, and what each one catches:

| Test | Catches |
|---|---|
| `test_it_has_exactly_the_placeholders_we_expect` | **Trap A above** — a placeholder nothing supplies, offline |
| `test_every_fact_table_goes_through_the_placeholder` | **step 1a missed one** — the highest-value test in the file |
| `test_every_batch_predicate_goes_through_the_placeholder` | **step 1d missed one branch** — a *count*, because the placeholder-set test is blind to a partially converted file |
| `test_no_batch_id_is_hardcoded` | a batch predicate written with a literal in the first place |
| `test_no_catalog_is_hardcoded_any_more` | a literal `mrm_log_flat.default` left in the template |
| `test_the_dimension_catalog_stays_literal` | step 1b templated by accident |
| `test_each_side_reads_only_its_own_catalog` | cross-contamination between the two renders |
| `test_the_two_renders_differ_only_in_the_catalog` | any other difference between the sides |
| `test_a_render_leaves_no_placeholder_behind` | an unrecognised `${...}` surviving substitution |
| `test_the_filter_is_case_level_not_per_side` | someone moving the sampling filter into a side's `vars:` |
| `test_every_union_branch_is_sampled` | **step 1c missed a branch** |
| `test_the_filter_reaches_every_branch_when_rendered` | the same, after substitution |

Only two numbers need changing: the branch count and the fact-reference count.

```bash
pytest tests/test_supply_sql_sync.py -q      # no warehouse, milliseconds
```

---

### Step 4 — the wiring test

`tests/test_supply_case.py` — copy `tests/test_insight_plus_case.py`:

```python
CASE_FILE = os.path.join(CASES_DIR, "f_supply_portfolio_hourly.yaml")

def _case(params=PARAMS) -> Case:
    for case in discover_cases(CASES_DIR, params):
        if case.name == "f_supply_portfolio_hourly":      # ← the name
            return case
    raise AssertionError(f"case not found in {CASES_DIR}")

HOOVER_SQL = os.path.join(REPO, "sql", "insight_plus", "f_supply_portfolio_hourly.sql")
```

Then update the three hard counts in `test_the_parser_accounts_for_every_output_column`
to your query's numbers:

```python
assert len(dims) + len(metrics) == <your total output columns>
assert len(dims)                == <your dimension count>
assert len(metrics)             == <your metric count>
```

That test is a guard on the guard: it asserts the SELECT-list parser accounted
for every column. If it fails, every assertion below it is measuring the wrong
thing.

The rest carries over unchanged and gives you, offline:

| Test | Catches |
|---|---|
| `test_case_loads` | a YAML typo |
| `test_it_is_a_row_case_not_a_schema_check` | the wrong case shape |
| `test_default_engine_not_pushdown` | an `engine:` key that would disable breakdown/near-miss |
| `test_the_two_sides_share_one_query_file` | the two-copies-drift problem returning |
| `test_the_sides_differ_only_in_the_fact_catalog` | a half-edited copy-paste |
| `test_side_vars_carry_no_placeholder` | a side var that could never resolve |
| `test_listing_works_without_the_batch_parameter` | a run-time value in a load-time slot |
| `test_each_side_reads_its_own_catalog` | both sides on one catalog |
| `test_both_sides_carry_the_sampling_filter` | the 409× bug |
| `test_it_substitutes_on_both_sides` | a half-templated query |
| `test_omitting_it_raises_rather_than_running` | **a green run over zero rows** |
| `test_the_yaml_ships_no_default_batch` | the same, from the other direction |
| `test_keys_are_exactly_the_dimensions` | a column added to the SELECT without updating `keys` |
| `test_no_metric_is_used_as_a_key` | a `sum()` in the key |
| `test_keys_are_unique_names` | a duplicated dimension |
| `test_the_case_is_keyed_not_keyless` | someone deleting `keys:` |

```bash
pytest tests/test_supply_case.py tests/test_supply_sql_sync.py -q
```

> **Trap, verified.** Both test files call
> `discover_cases(CASES_DIR, PARAMS)`, which loads **every** YAML in that
> directory. A malformed `f_supply_portfolio_hourly.yaml` therefore fails the
> *demand* case's tests too:
>
> ```
> FAILED tests/test_insight_plus_case.py::...::test_keys_are_unique_names
> FAILED tests/test_insight_plus_case.py::...::test_the_case_is_keyed_not_keyless
> ```
>
> The pytest **summary** lines name only the tests, not the cause. The file is in
> the traceback one line up — `ValueError: .../f_supply_portfolio_hourly.yaml:
> case is missing required field 'expected'` — so read the failure, not the
> summary. **If tests you did not touch start failing, suspect the YAML you just
> added**, and run `rowparity list`, which now reports it cleanly and exits 2.
>
> The corollary: your new case must be loadable with only the batch parameter,
> the same as the demand case.

---

### Step 5 — the drill-down SQL (optional, and last)

`sql/insight_plus/f_supply_portfolio_hourly_drilldown.sql`

Only worth writing once a real run has shown you which dimension the differences
cluster on. The structure:

```sql
-- Placeholders filled in by rowparity: facts, row_filter, time_filter
-- (written without the dollar-brace on purpose -- see Step 1e)

select
    request__transaction_id,
    <the dimensions you want to see>,
    date_trunc('HOUR', cast(ack__timestamp as timestamp)) as event_date,
    process_batch_id,
    count(*) as n
from ${facts}.ack
<the same unnest / joins the parity query uses>
where
    ${time_filter}
    and ${row_filter}
    -- the branch predicates, copied VERBATIM from the parity query
    and ...
group by 1,2,3,...
order by 1
```

Three rules, all learned from the demand version:

1. **The branch predicates must be copied verbatim** from the parity query. If
   they drift, this looks at a different population than the row it is supposed
   to explain, and the mismatch is invisible.
2. **The sampling filter is NOT applied here.** This query hunts specific
   transactions behind one already-identified row; excluding 511/512 of them
   would usually return nothing and read as "the row does not exist".
3. **The time window is asymmetric, on purpose.** Hoover++ pinned to the batch
   hour; Hoover searched wider — because "the `event_date` shifted between the
   layouts" is the hypothesis under test. Pinning both sides assumes the answer.

Then add the block to the YAML from step 2:

```yaml
    drilldown:
      query_file: ../../sql/insight_plus/f_supply_portfolio_hourly_drilldown.sql
      bind:
        creative_id: "if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1)"
      id_column: request__transaction_id
      kinds: [missing]
      time:
        param: arena.presto.var.process_batch_id
        format: "%Y%m%d%H%M%S"
        hours_before: 1
        hours_after: 3
      vars:
        expected:
          time_filter: >-
            date_trunc('HOUR', cast(ack__timestamp as timestamp)) >= timestamp '${batch_hour_start}'
            and date_trunc('HOUR', cast(ack__timestamp as timestamp)) < timestamp '${batch_hour_end}'
        actual:
          time_filter: >-
            date_trunc('HOUR', cast(ack__timestamp as timestamp)) = timestamp '${batch_hour}'
```

Note `bind` maps an **output alias to its source expression**. `creative_id` in
the parity output is really the `if(...)`; that expression, not the alias, is
what must appear in a predicate against the raw table. Exactly one column may be
bound — the generated predicate is an IN-list over its values.

The `time:` block derives `${batch_hour}`, `${batch_hour_start}`,
`${batch_hour_end}`, `${batch_date}` and `${batch_id}` from the run's batch
parameter. `20260827010000` yields the hour `2026-08-27 01:00:00`, a start of
`00:00:00` and an end of `04:00:00`.

The drill-down is **generated, never executed** (§8.8). Failures generating it
are reported and swallowed — a helper template typo must not cost you a parity
run.

---

### 13.2 Running it

```bash
# 0. credentials — once per shell
export TRINO_HOST=presto-gateway.presto.stg.aws.fwmrm.net
export TRINO_PORT=8080 TRINO_HTTP_SCHEME=https
export TRINO_USER=your.user
read -rs TRINO_JWT_TOKEN && export TRINO_JWT_TOKEN     # no echo, no history

# 1. does it parse?                       no warehouse, instant
rowparity list scripts/cases_insight_plus

# 1b. will the SQL resolve?               reads local files only, no connection
rowparity list scripts/cases_insight_plus --check \
    --param arena.presto.var.process_batch_id=20260827010000

# 2. is it wired right?                   no warehouse, milliseconds
pytest tests/test_supply_case.py tests/test_supply_sql_sync.py -q

# 3. can we connect?                      one trivial query
python scripts/trino_connectivity_check.py

# 4. run just the new case
rowparity run scripts/cases_insight_plus \
    --select f_supply_portfolio_hourly \
    --param arena.presto.var.process_batch_id=20260827010000 \
    --csv reports/insight_plus \
    --html reports/insight_plus/supply.html 2>&1 | tee supply.log
```

**`--select` is not optional once there are two cases.** Without it,
`rowparity run scripts/cases_insight_plus` runs **both**, and the demand query is
the expensive one.

Then read `reports/insight_plus/supply.html` in the order §8.9 gives:

> which branch (§8.3) → is a key drifting (§8.5) → what pattern (§8.6) →
> show me one (§8.7) → give me the transaction ids (§8.8)

Once it is stable, drop `--select` to run the pair in CI.

### 13.3 If something goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| `missing required field 'expected'` | wrong case shape, or `expected:` mis-indented | check the YAML nesting under `cases:` |
| `unknown compare option(s): [...]` | typo in `compare:` | §9.2 for the valid set |
| `breakdown_by names [...] not in compare.keys` | breakdown column is not a key | add it to `keys`, or drop the breakdown |
| `ParamError: unresolved parameter(s)` on the run, 0.0s | placeholder in the `.sql` nothing supplies | add it to `vars:`; `rowparity list --check` and step 3 both catch this offline |
| `IdenticalSourcesError` | both sides resolved to the same catalog | a copy-pasted side `vars:` where one value was never changed |
| `EmptyComparisonError` | both sides returned zero rows | the batch does not exist on both sides, or a predicate matched nothing |
| Tests fail in files you did not touch | your new YAML is malformed | **Trap in step 4** — run `rowparity list` for the real error |
| Row counts differ by a large ratio | the two sides sample differently | the filter must be case-level, not per-side |
| `duplicate_keys_expected > 0` | the keys are not unique | a `GROUP BY` dimension is missing from `keys` |
| Every column flagged | the case is running keyless | `keys:` is missing or empty |

### 13.4 The whole thing, at a glance

```
 1. sql/insight_plus/f_supply_portfolio_hourly.sql            NEW
       ${facts} everywhere · dimensions literal
       ${sampling_filter} per branch · batch predicate
                     │
 2. scripts/cases_insight_plus/f_supply_portfolio_hourly.yaml NEW
       both sides → the same query_file, different facts:
       keys = the GROUP BY dimensions
                     │
       ── rowparity list ──────────► both cases listed, no --param
       ── rowparity list --check ──► the SQL's placeholders all resolve
                     │
 3. tests/test_supply_sql_sync.py                             NEW  (copy)
       placeholders · fact refs · one sampling marker per branch
 4. tests/test_supply_case.py                                 NEW  (copy)
       wiring · batch cannot be skipped · keys == dimensions
                     │
       ── pytest ──────────────────► green, in milliseconds
                     │
       ── trino_connectivity_check ► connection proven
                     │
       ── rowparity run --select ──► reports/insight_plus/supply.html
                     │
 5. sql/insight_plus/f_supply_portfolio_hourly_drilldown.sql  NEW  (last)
       + a drilldown: block in the YAML from step 2

    NOTHING ELSE IS EDITED.
```

---

*Verified against the source. Function and option names are quoted from the
code; line numbers are deliberately not, because they drift.*

---

## 14. LiveWire — stepping through one successful run

§12 walks the control flow by reading the code. **This section is the debugger
view**: every function the process actually entered, in the order it entered
them, with the real values in scope at each step.

It was not written by reading. A `sys.settrace` hook recorded every frame that
entered `src/rowparity/` during a real run — **267 frames, 83 distinct
functions** — and the call tree below is that recording, pruned only where a hot
loop repeats. The values are printouts from the same run.

### 14.0 The run

```bash
rowparity run scripts/cases_insight_plus \
    --param arena.presto.var.process_batch_id=20260812010000 \
    --result-sink duckdb:./reports/results.duckdb \
    --html reports/insight_plus/run.html
```

**A positive success case**: both sides return the same rows, the verdict is
`EQUIVALENT`, and the exit code is 0. Which stages that *skips* is itself worth
teaching — see §14.9.

To keep it reproducible on a laptop the trace was taken against a case with the
same **shape** as the Hoover one — one SQL file, per-side `vars:` supplying
`${facts}`, a case-level `${sampling_filter}`, a required batch parameter, keyed
compare with `breakdown_by` and `near_miss` — but reading two Parquet files
through DuckDB instead of two Presto catalogs. Every frame below is identical
for the real case except `sources._duckdb` in place of `sources._trino`.

Real output:

```
Result sink: duckdb:./reports/results.duckdb  run_id=dd5d189f-e1c1-4b5a-8d26-b0ddd0803dea
Case 'f_portfolio_hourly'
  -> expected  (duckdb) ...
  OK expected  (duckdb)  0.0s  3 rows x 4 cols
  -> actual    (duckdb) ...
  OK actual    (duckdb)  0.0s  3 rows x 4 cols
  -> comparing ...
  OK comparing  0.0s  4 columns compared
Case 'f_portfolio_hourly': [EQUIVALENT] keyed on ['event_date', 'network_id'] | expected=3 actual=3 | missing=0 added=0 changed=0
  timing: expected 0.0s | actual 0.0s | compare 0.0s | total 0.0s
  row differences by network_id:
    101  rows 1/1  missing=0 added=0 changed=0  differing=0.0%
    102  rows 1/1  missing=0 added=0 changed=0  differing=0.0%
    103  rows 1/1  missing=0 added=0 changed=0  differing=0.0%

Wrote HTML report to reports/insight_plus/run.html
Summary: 1/1 equivalent
```

---

### 14.1 Frames 1–4 — entry, progress, parameters

```
cli.py:225  main(argv=None)
  cli.py:49    _run(args=Namespace(cmd='run', path='...', param=[...], ...))
    progress.py:51  configure(enabled=True, stream=None)
    params.py:53    parse_cli_params(items=['arena.presto.var.process_batch_id=20260812010000'])
```

Four frames before anything can fail slowly.

`configure(enabled=True)` flips the module-global `_enabled` and stores the
heartbeat interval. **Nothing has been opened, read or connected.** This is
first so that the next thing — which may take minutes — is not silent.

`parse_cli_params` splits on the first `=` only and returns:

```python
{"arena.presto.var.process_batch_id": "20260812010000"}
```

> **Step-into note.** `progress.emit()` appears nowhere in the trace as a frame
> even though it runs constantly — the tracer skipped it deliberately, the way
> you would step *over* a logging call. Every `-> ...` and `OK ...` line in the
> output above came from it.

---

### 14.2 Frames 5–30 — loading the case

```
    cli.py:37  _load_cases(path='.../cases', cli_params={'arena...batch_id': '20260812010000'})
      cases.py:502  discover_cases(path=..., params_=...)
        cases.py:442  load_cases_from_file(path='.../cases/portfolio.yaml', params_=...)
          cases.py:365   _merge_defaults(case={'name': 'f_portfolio_hourly', ...}, defaults={})
          cases.py:377   _build_case(raw={'name': 'f_portfolio_hourly', ...}, source_file=...)
            params.py:72   resolve_variables(file_vars={}, case_vars={'sampling_filter': 'bit_flags > 0'})
            params.py:145  substitute_spec(value={'name': 'f_portfolio_hourly', ...}, variables={...})
              params.py:145  substitute_spec(value='f_portfolio_hourly', ...)
                params.py:120  substitute(text='f_portfolio_hourly', ...)
              params.py:145  substitute_spec(value='Hoover', ...)
                params.py:120  substitute(text='Hoover', ...)
              params.py:145  substitute_spec(value='duckdb', ...)
              params.py:145  substitute_spec(value=':memory:', ...)
              params.py:145  substitute_spec(value="read_parquet('.../old.parquet')", ...)
              params.py:145  substitute_spec(value="read_parquet('.../new.parquet')", ...)
              ... 20 more substitute_spec / substitute pairs
```

**This is the recursion worth showing a peer.** `substitute_spec` calls itself
once per string, dict and list in the case — including `'f_portfolio_hourly'`
and `'Hoover'`, which contain no placeholders at all. It walks *everything*
rather than only the fields it expects to be templated, which is why every case
shape gets substitution for free.

After `resolve_variables`, the merged mapping is exactly:

```python
case.variables = {
    "sampling_filter":                   "bit_flags > 0",          # from the case's vars:
    "arena.presto.var.process_batch_id": "20260812010000",         # from --param
}
```

Note what is **not** there: `facts`. It lives in each side's own `vars:` block
and is merged in per side, later, at §14.4.

Note also what **did not happen**: no frame entered `sources.py`. The
`query_file` has not been opened. The case object carries the path and the
variables and nothing else.

```python
case.expected = {'type': 'duckdb', 'database': ':memory:',
                 'query_file': '../sql/portfolio.sql',
                 'vars': {'facts': "read_parquet('.../old.parquet')"}}
```

---

### 14.3 Frame 31 — the result sink opens

```
    result_sink.py:301  make_result_sink(spec='duckdb:./reports/results.duckdb', run_id='dd5d189f-...')
      result_sink.py:158   __init__()
        result_sink.py:131   __init__()
        result_sink.py:171   _bootstrap()
```

`_bootstrap()` is the `CREATE TABLE IF NOT EXISTS` pass. After it, the DuckDB
file holds two tables:

```
rowparity_run_summary        one row per case per run
rowparity_run_diffs          one row per diff example
```

One `run_id` was minted in `_run` before this and is passed in, so every case in
this invocation lands as one correlatable batch.

> **Failure note.** This whole block sits in a `try/except` that only *warns*. A
> sink that cannot open does not stop the run — persistence is an artifact of
> the run, not the run.

---

### 14.4 Frames 32–45 — the guards, before any I/O

```
    cases.py:107  run(base_dir=None)
      cases.py:95    config(base_dir='.../cases')
      cases.py:202   _check_breakdown(cfg=CompareConfig(keys=['event_date', 'network_id'], ...))
      cases.py:245   _guard_identical_sides(base_dir='.../cases')
        params.py:91    merge_side_vars(side_vars={'facts': "read_parquet('.../old.parquet')"}, variables={...})
        sources.py:76   resolve_query(spec={'type': 'duckdb', ...}, base_dir='.../cases')
          sources.py:72    _resolve_path(path='../sql/portfolio.sql', base_dir='.../cases')
          params.py:120    substitute(text='-- Placeholders: facts, sampling_filter, ...', variables={...})
            params.py:124    _replace(match=<re.Match span=(179, 187) '${facts}'>)
            params.py:124    _replace(match=<re.Match span=(194, 212) '${sampling_filter}'>)
            ... _replace once per placeholder occurrence
        params.py:91    merge_side_vars(side_vars={'facts': "read_parquet('.../new.parquet')"}, ...)
        sources.py:76   resolve_query(...)                       ← the OTHER side
```

Three things a peer should take from this block.

**`config()` runs first and can reject the case outright.** It diffs
`set(self.compare)` against `_COMPARE_KEYS` and raises on any unknown option, so
a typo'd `ignore_colums:` dies here rather than doing nothing quietly.

**`_guard_identical_sides` reads and renders BOTH SQL files** — you can see
`resolve_query` called twice — and then compares the two strings. That is real
work done before any connection, deliberately: if the two renders were
identical, the run would compare a source with itself and report EQUIVALENT no
matter what the data held.

**`_replace` is called once per placeholder occurrence**, not once per name.
This is the frame that would raise `ParamError` on an unresolved name; it
appends to a `missing` list and `substitute` raises after the whole pass, so the
error names *every* missing placeholder rather than only the first.

The rendered SQL at the end of this block, expected side:

```sql
select
    event_date,
    network_id,
    sum(requests) as requests,
    sum(revenue)  as revenue
from read_parquet('.../old.parquet')     -- ${facts}, from THIS side's vars:
where bit_flags > 0                      -- ${sampling_filter}, case-level
  and process_batch_id = '20260812010000'  -- ${arena...batch_id}, from --param
group by 1, 2
```

The actual side is byte-identical except for `new.parquet`. The guard sees they
differ, and returns.

---

### 14.5 Frames 46–70 — fetching each side

```
      progress.py:139  step(label='expected  (duckdb)', heartbeat_seconds=None)
        progress.py:101   start()                                  ← daemon heartbeat thread
      sources.py:41    load_source(spec={'type': 'duckdb', ...})
        params.py:91     merge_side_vars(...)                      ← AGAIN, per side
        sources.py:178   _duckdb(spec=..., base_dir='.../cases')
          sources.py:76    resolve_query(...)                      ← the file is read a SECOND time
            sources.py:72    _resolve_path(path='../sql/portfolio.sql', ...)
            params.py:120    substitute(text='-- Placeholders: ...', ...)
              params.py:124    _replace(...)  ×3
      progress.py:171  describe_table(table=pyarrow.Table event_date: date32[day] ...)
      progress.py:130  result(summary='3 rows x 4 cols')
      progress.py:155  step(...)                                   ← context manager exiting
        progress.py:113   stop()                                   ← heartbeat joined, 1s bound
        progress.py:134   summary()
      [the same 12 frames again for the actual side]
```

**The SQL file is read and substituted twice per side** — once by the guard,
once by the real load. Four reads total for two sides. Cheap, and it keeps the
guard from having to hand state forward to the loader.

`progress.step` appears twice per step in the trace because it is a
`@contextmanager`: once entering, once resuming after the `yield`. Between them
sit the frames that did the work. `start()` spawns the daemon heartbeat;
`stop()` sets the event and joins with a one-second bound so a wedged stream
cannot block the run.

After this block both sides are Arrow:

```
['event_date', 'network_id', 'requests', 'revenue'] | 3 rows
event_date: date32[day], network_id: int32, requests: decimal128, revenue: decimal128
```

**Nothing downstream knows DuckDB was involved.** This is seam 1 (§12.9).

---

### 14.6 Frames 71–120 — the comparison

```
      compare.py:354  compare_tables(expected=pyarrow.Table..., actual=pyarrow.Table...)
        compare.py:333   _resolve_columns(exp=<schema>, act=<schema>)
        compare.py:97    canon()                                   ← CompareConfig → CanonConfig
        compare.py:442   _compare_keyed(exp_rows=[{...}, ...], act_rows=[{...}, ...])

          compare.py:429   _key_of(row={'event_date': date(2026,8,12), 'network_id': 101, ...})
            hashing.py:117   canon_value(dtype=DataType(date32[day]), value=date(2026, 8, 12))
              hashing.py:71    _canon_scalar(value=date(2026, 8, 12), cfg=CanonConfig(...))
            hashing.py:117   canon_value(dtype=DataType(int32), value=101)
          compare.py:429   _key_of(row={... 'network_id': 102 ...})
          ... _key_of once per row per side  (6 calls: 3 rows × 2 sides)

          compare.py:506   _group(key=(('D', '2026-08-12'), ('i', 101)), row={...})
            compare.py:489    _bd(row={...})                       ← RAW value, not canonical
          compare.py:506   _group(key=(('D', '2026-08-12'), ('i', 102)), row={...})
          ... _group once per key per side

          hashing.py:172   canon_row(schema=<schema>, row={...})
            hashing.py:117    canon_value(dtype=DataType(date32[day]), value=date(2026,8,12))
              hashing.py:71     _canon_scalar(...)
            hashing.py:117    canon_value(dtype=DataType(int32), value=101)
            hashing.py:117    canon_value(dtype=DataType(decimal128), value=Decimal('5'))
              hashing.py:71     _canon_scalar(value=Decimal('5'), ...)
          hashing.py:172   canon_row(...)                          ← the OTHER side, same key
          hashing.py:275   row_digest(canon=(('event_date', ('D','2026-08-12')), ...))
          hashing.py:275   row_digest(...)                         ← the OTHER side
          ... canon_row / row_digest once per PAIRED key per side

        compare.py:308   total_differences()
```

This is the heart of the tool, so slow down here.

**`_key_of` is called once per row per side, and it canonicalises only the key
columns.** For row 0:

```
raw    {'event_date': datetime.date(2026, 8, 12), 'network_id': 101}
canon  (('D', '2026-08-12'), ('i', 101))
```

That tuple is used **raw as a dict key**. No hashing. `'D'` is the date tag,
`'i'` the integer tag — the tags are what stop `1` and `'1'` from colliding
(§5.4).

**`_group` runs on the same pass**, calling `_bd(row)` to read the breakdown
value **from the raw row**, not from the canonical key — so
`result.breakdown[101]` means what it looks like.

**`canon_row` + `row_digest` run only for keys present on BOTH sides.** They are
the last step, not the first: a key that exists on one side only never reaches
them, because a missing row has nothing to compare against.

Row 0, both sides:

```
canon_row →  event_date  ('D', '2026-08-12')
             network_id  ('i', 101)
             requests    ('d', '5')          ← decimal, trailing zeros stripped
             revenue     ('d', '12.5')
row_digest → bd76f12947d5414b7508d4c08f8c3081     (blake2b, 16 bytes)
```

Both sides produce the identical digest, so `_column_diffs` is **never called**.
That is the fast path: one 16-byte comparison per paired row decides the
question, and the expensive per-column work only happens for rows that already
failed it.

`total_differences()` returns 0, so `result.equivalent` stays `True`.

---

### 14.7 Frames 121–140 — the post-comparison stages

```
      cases.py:174  _generate_drilldowns(result=ComparisonResult(equivalent=True, ...))
      cases.py:296  _guard_empty(result=ComparisonResult(equivalent=True, ...))
      result_sink.py:136  write(case_name='f_portfolio_hourly')
        result_sink.py:75    _build_summary_batch(run_id='dd5d189f-...', run_ts=datetime(2026,9,1,8,32,...))
        result_sink.py:101   _build_diffs_batch(run_id='dd5d189f-...', case_name='f_portfolio_hourly')
        result_sink.py:194   _write_batches(summary=pyarrow.Table run_id: string ...)
```

**Two frames that enter and immediately return** — and that is the lesson:

- `_generate_drilldowns` hits `if not self.drilldown or result.equivalent: return`
  on its first line. No drill-down SQL is generated for a passing run, because
  there is nothing to investigate.
- `_guard_empty` hits `if result.expected_rows or result.actual_rows: return`.
  Three rows a side, so it passes.

Note the tracer shows them as **entered**. Stepping in and returning on line one
is a real frame, and a peer reading a stack trace should expect to see them.

`result_sink.write()` builds two Arrow batches. What actually landed:

```
rowparity_run_summary
   run_id                   dd5d189f-e1c1-4b5a-8d26-b0ddd0803dea
   run_ts                   2026-09-01 08:32:46.675527+00:00
   case_name                f_portfolio_hourly
   tags                     ["livewire"]
   equivalent               True
   expected_rows            3
   actual_rows              3
   missing_count            0
   added_count              0
   changed_count            0
   compared_columns         ["event_date", "network_id", "requests", "revenue"]
   keys                     ["event_date", "network_id"]
   type_mismatches          []
   columns_only_in_expected []
   columns_only_in_actual   []

rowparity_run_diffs
   0 rows        ← a success case has no diff examples to persist
```

`_build_diffs_batch` still runs and still returns a (empty) batch. The summary
row is what makes a green run visible in `rowparity report` history: without it,
the trend line would only ever plot failures.

---

### 14.8 Frames 141–160 — reporting and exit

```
    report.py:154  render_console(result=ComparisonResult(equivalent=True, ...), case_name='f_portfolio_hourly')
      compare.py:315   summary()
      compare.py:304   total_seconds()
      report.py:116    _render_breakdown(result=...)
        compare.py:223    differing_share()
          compare.py:219     differences()
        ... once per breakdown group

    result_sink.py:201  close()

    run_report.py:384  write_run_report(path='reports/insight_plus/run.html', results=[('f_portfolio_hourly', ComparisonResult(...))])
      run_report.py:360   render_run_report()
        run_report.py:327    build_payload()
          run_report.py:254     case_to_dict()
            run_report.py:184      _breakdown_to_dict()
              run_report.py:41        _short()
            run_report.py:237      _drilldown_to_dict()
```

`render_console` is one call producing the whole block of stdout. `summary()`
and `total_seconds()` are `@property` reads that show up as frames — worth
knowing when you are counting frames in a profiler.

**`result_sink.close()` runs BEFORE the reports.** Persistence is flushed first;
if the HTML writer then throws, the history is already durable.

`write_run_report` → `render_run_report` → `build_payload` → `case_to_dict`
is the whole chain: the `ComparisonResult` is turned into a JSON payload, which
is string-substituted into `templates/run_report.html`. `_drilldown_to_dict` is
entered and returns `None` on its first line (`if dd is None: return None`),
exactly like `_generate_drilldowns` did.

Result: a 39 KB self-contained page, and:

```
Summary: 1/1 equivalent
exit 0
```

---

### 14.9 What a success case skips

This is the part most worth teaching, because a green run exercises noticeably
less code than a failing one. Everything below **did not execute**:

| Never entered | Guard that stopped it |
|---|---|
| `_column_diffs` | the two digests matched, per paired row |
| `_accumulate_deltas` | only called from inside the changed branch |
| `ChangeSignature` construction | ditto |
| `near_miss.analyse` | `if cfg.near_miss and ... result.missing_keys and result.added_keys` — both empty |
| `drilldown.generate` | `_generate_drilldowns` returned on `result.equivalent` |
| `_maybe_example` | no `RowDiff` was ever constructed |
| `report._render_near_miss` / `_render_signature` | nothing to render |

`near_miss: true` was set in the case file and the analysis still never ran.
**A configured feature that produces no output is not necessarily broken** — on
a passing run there is nothing for it to pair.

To see those frames, change one value on one side and re-run. The trace then
gains, in order: `_column_diffs` → `_accumulate_deltas` → `_maybe_example` →
`near_miss.analyse` → `drilldown.generate` → `_render_signature`.

---

### 14.10 The whole stack, one page

```
main                                          cli.py       argparse → args.func
└─ _run                                       cli.py
   ├─ progress.configure                      progress.py  FIRST. stderr, flushed
   ├─ parse_cli_params                        params.py    split on first '='
   ├─ _load_cases → discover_cases            cli/cases    glob **/*.yaml, sorted
   │  └─ load_cases_from_file                 cases.py
   │     ├─ yaml.safe_load
   │     ├─ _merge_defaults                   cases.py     compare: merges deeper
   │     └─ _build_case                       cases.py
   │        ├─ resolve_variables              params.py    file<case<env<--param
   │        └─ substitute_spec ↻               params.py    recurses the WHOLE dict
   ├─ make_result_sink → _bootstrap           result_sink  CREATE TABLE IF NOT EXISTS
   └─ Case.run                                cases.py
      ├─ config                               cases.py     unknown option → raise
      ├─ _check_breakdown                     cases.py     breakdown_by ⊆ keys
      ├─ _guard_identical_sides               cases.py     renders BOTH sides, compares
      │  ├─ merge_side_vars ×2                params.py    side var beats --param
      │  └─ resolve_query ×2                  sources.py   reads + substitutes the .sql
      ├─ progress.step "expected"             progress.py  heartbeat thread starts
      │  └─ load_source → _duckdb             sources.py   ( _trino for the real case )
      │     └─ resolve_query                  sources.py   file read again
      ├─ progress.step "actual"               progress.py  same, other side
      ├─ progress.step "comparing"
      │  └─ compare_tables                    compare.py
      │     ├─ _resolve_columns               compare.py   MATCHED / DIFF / TYPE DIFF
      │     ├─ CompareConfig.canon            compare.py   → CanonConfig
      │     └─ _compare_keyed                 compare.py
      │        ├─ _key_of ↻                   compare.py   per row per side
      │        │  └─ canon_value ↻            hashing.py   ('D','2026-08-12'), ('i',101)
      │        ├─ _group / _bd ↻              compare.py   RAW value as the group label
      │        ├─ canon_row ↻                 hashing.py   paired keys only
      │        └─ row_digest ↻                hashing.py   blake2b, 16 bytes
      ├─ _generate_drilldowns                 cases.py     RETURNS: equivalent
      ├─ _guard_empty                         cases.py     RETURNS: rows > 0
      └─ result_sink.write                    result_sink  summary batch + empty diffs
   ├─ render_console                          report.py    → stdout
   ├─ result_sink.close                       result_sink  flushed BEFORE the reports
   └─ write_run_report                        run_report   → build_payload → case_to_dict
      └─ exit 0
```

### 14.11 Reproducing this trace yourself

The tracer is fifteen lines. Point it at your own case and read the real answer
instead of trusting this document:

```python
import os, sys
SRC = os.path.abspath("src/rowparity")
depth = [0]

def tr(frame, event, arg):
    code = frame.f_code
    if not code.co_filename.startswith(SRC):
        return None                                  # step OVER everything else
    if event == "call":
        args = {k: frame.f_locals.get(k) for k in code.co_varnames[:code.co_argcount]}
        print(f"{'  ' * depth[0]}{os.path.basename(code.co_filename)}:"
              f"{frame.f_lineno} {code.co_name}({list(args)})")
        depth[0] += 1
        return tr
    if event == "return":
        depth[0] -= 1
    return tr

sys.argv = ["rowparity", "run", "scripts/cases_insight_plus",
            "--param", "arena.presto.var.process_batch_id=20260812010000"]
from rowparity.cli import main
sys.settrace(tr)
try:
    main()
finally:
    sys.settrace(None)
```

Two knobs: the `startswith(SRC)` test is your "step over library code", and
adding names to a skip set is your "step over this function" — `emit`,
`format_duration` and the dataclass `__init__`s are the ones worth muting first,
or the signal drowns.

---

## 15. Does my run use DuckDB? — and what a result sink is

A question that comes up every time someone reads §14, because §14's trace is
DuckDB-backed. It deserves a straight answer with evidence, because "is this
thing in my pipeline?" is exactly the kind of question a document should settle
rather than leave to inference.

### 15.1 The short answer

**No. The Hoover parity run does not use DuckDB at any point.**

```
$ python -c "..."
engine:             None      → default Python engine (compare.py)
expected  type=trino          handler=_trino
actual    type=trino          handler=_trino
```

And it is not merely unused — it is never imported. After importing every module
the run touches:

```python
>>> 'duckdb' in sys.modules
False
```

Heavy drivers are lazy imports inside their own handler (§2.4), so a driver you
do not use is never loaded. That is also why `pip install -e ".[trino]"` alone is
a complete install for this case.

### 15.2 Then why is §14's trace DuckDB-backed?

So it reproduces on a laptop, with no Presto cluster and no credentials. The
traced case has the Hoover case's **shape** — one SQL file, per-side `vars:`
supplying `${facts}`, a case-level `${sampling_filter}`, a required batch
parameter, keyed compare with `breakdown_by` and `near_miss` — reading two
Parquet files instead of two Presto catalogs.

**Exactly one frame differs:**

| §14's trace | Your run |
|---|---|
| `sources.py:178  _duckdb(...)` | `sources.py:288  _trino(...)` |

Everything above it is identical (`cli` → `cases` → `params` → the guards), and
everything below it is identical (`compare` → `hashing` → `result_sink` →
`run_report`) — because both handlers return a `pyarrow.Table` and **nothing
downstream knows where the data came from**. That is seam 1 (§12.9), and this is
the clearest demonstration of it in the whole document: you can swap the source
engine and 95% of the call tree is unchanged.

What `_trino` adds inside that one frame, which `_duckdb` does not have:
`trino_auth.connect()`, the `fetchmany` batching loop with its
`... fetched N rows` heartbeat, and `pa.concat_tables(promote_options="permissive")`.
See §12.5.

### 15.3 DuckDB's three unrelated roles

Mixing these up is the source of the confusion. §6 covers them as reference;
here is which of them touches *your* case:

| Role | Declared by | Yours? |
|---|---|---|
| **Source** — a local query engine reading files or a `.duckdb` database | `type: duckdb` / `type: sql` | **No** — you use `type: trino` |
| **Push-down engine** — canonicalise and fingerprint inside DuckDB | `engine: duckdb` | **No** — you set no `engine:`, so you get the default Python engine |
| **Result sink** — where run history is written | `--result-sink duckdb:...` | **Only if you pass the flag** |

The third is the real answer to "does it use DuckDB", and it is worth
understanding on its own terms.

### 15.4 What `--result-sink duckdb:./reports/results.duckdb` means

**Append a permanent record of this run to a local DuckDB file.** It has nothing
to do with comparing your data: `result_sink.write()` runs *after* the comparison
has already reached its verdict (§14.7).

Two tables, created on first use by `_bootstrap()`:

```
rowparity_run_summary        one row per case per run
rowparity_run_diffs          one row per diff example
```

Here is what three real runs produced — two passing, then one with a value
changed on the actual side:

```
rowparity_run_summary
   9ea9d3ee  09:06:50  f_portfolio_hourly  equivalent=True   3/3  miss=0 add=0 chg=0
   c3586a00  09:06:55  f_portfolio_hourly  equivalent=True   3/3  miss=0 add=0 chg=0
   a418ffd7  09:06:55  f_portfolio_hourly  equivalent=False  3/3  miss=0 add=0 chg=1

rowparity_run_diffs
   1 row — only the failing run contributed
      run_id        a418ffd7-…
      case_name     f_portfolio_hourly
      diff_kind     changed
      key_json      ["2026-08-12", "103"]
      expected_row  {"event_date":"2026-08-12","network_id":103,"requests":"9",…}
      actual_row    {"event_date":"2026-08-12","network_id":103,"requests":"8",…}
      column_diffs  [{"column":"requests","expected":"9","actual":"8"}, …]
```

**Passing runs are recorded too, and that is the point.** Without them a trend
line could only ever plot failures, and "this case has passed every day for three
weeks" would be unanswerable.

`run_id` is one UUID per `rowparity run` invocation, minted in `_run` before any
case executes, so every case in a run lands as one correlatable batch.

### 15.5 What you get for it

**The history report:**

```bash
rowparity report --result-sink duckdb:./reports/results.duckdb --html trend.html
```

Reads the same two tables back out, reshapes them to one point per case per
calendar day (latest run wins if there were several), and renders a pass-rate
trend, a per-case ledger with sparklines, schema-drift history and a row-level
drill-down. Against the three runs above: a 40 KB self-contained page.

**Or just query it.** It is a plain DuckDB file, so nothing obliges you to go
through rowparity at all:

```sql
-- pass rate per case
select case_name, count(*) runs, sum(equivalent::int) passed,
       round(100.0*sum(equivalent::int)/count(*), 1) as pct
from rowparity_run_summary group by 1;
--   ('f_portfolio_hourly', 3, 2, 66.7)

-- which columns drift most often, across every run ever recorded
select json_extract_string(cd, '$.column') as column_name, count(*) as times
from (select unnest(from_json(column_diffs, '["JSON"]')) as cd
      from rowparity_run_diffs)
group by 1 order by 2 desc;
--   ('requests', 1)   ('revenue', 1)

-- row-count SLA: has either side's volume moved?
select case_name, min(expected_rows), max(expected_rows),
       min(actual_rows), max(actual_rows)
from rowparity_run_summary group by 1;

-- consecutive-failure alerting
select case_name, run_ts, equivalent
from rowparity_run_summary order by run_ts desc limit 5;
```

That last one is the practical CI use: alert when a case has failed N runs in a
row, rather than on every individual red build.

### 15.6 Three things to know before you turn it on

| | |
|---|---|
| **`duckdb:` is one of three backends** | `snowflake:MY_DB.QA_SCHEMA` for a shared team warehouse, `iceberg:qa_results` for a lakehouse. But `rowparity report` reads **DuckDB and Snowflake only** — `IcebergResultSink` is write-only today (§11.3) |
| **The file accumulates, it is not overwritten** | three runs, three summary rows. It is a build artifact: do not commit it |
| **A sink failure never fails your run** | `make_result_sink` is wrapped in a `try/except` that only warns. And `result_sink.close()` runs *before* the reports are written (§14.8), so history is already durable if the HTML writer throws |

`--result-sink-prefix` renames both tables if `rowparity_*` collides with
something in a shared schema.

### 15.7 The summary a peer should leave with

> The comparison is Trino end to end. DuckDB appears in this pipeline in exactly
> one place — the local file your run history is *written to* — and only when you
> ask for it with `--result-sink`. It never reads, hashes or compares your data.
>
> If you want the trend page and the ability to ask "how long has this been
> failing", turn it on. If you only ever look at one run's HTML report, you do
> not need it.

---

*Verified against the source. Function and option names are quoted from the code.
Sections 1–13 deliberately quote no line numbers, because they drift.*

*§14 is the exception, and it has to be: a debugger view without line numbers is
not a debugger view. Its call tree, its `file:line` pairs and its printed values
are a recording of one real run — every one of the 27 line numbers was
re-checked against the source when this was written. **They will drift.** Treat
them as "roughly here", and if one is wrong, re-run the fifteen-line tracer in
§14.11 rather than trusting the page.*

*§15's tables, row counts and query results are output from three real runs, not
illustrations.*
