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
rowparity list scripts/cases_insight_plus          # 1. does it parse? no warehouse
pytest tests/test_my_case.py -xvs                  # 2. is it wired right? no warehouse
python scripts/trino_connectivity_check.py         # 3. can we connect?
rowparity run scripts/cases_insight_plus \         # 4. run it
    --param arena.presto.var.process_batch_id=20260827010000 \
    --html reports/run.html
```

Do not skip to step 4.

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
rowparity run cases/ --json reports/rowparity.json \
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

*Verified against the source. Function and option names are quoted from the
code; line numbers are deliberately not, because they drift.*
