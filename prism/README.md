# PRISM

**You write the parity SQL. PRISM writes two more files. Everything that
used to be a third and fourth generated file -- the SQL-template checks and
the wiring checks -- lives in one file you never touch:
`tests/test_insight_plus_sql_sync.py`.**

```bash
python -m prism generate sql/insight_plus/f_supply_portfolio_hourly.sql
```

```
                    f_supply_portfolio_hourly.sql          ← you write this
                                 │
                              PRISM
                                 │
                         prism/output/   ← never your source tree
              ┌──────────────────┬──────────────────────┐
              ▼                  ▼                       ▼
        scripts/           sql/insight_plus/    sql/insight_plus/
        cases_insight_plus/ ..._drilldown.sql    f_supply..._.sql
        ..._hourly.yaml                          (copy of yours)

                        review it, then  cp -r prism/output/* .
                                 │
                tests/test_insight_plus_sql_sync.py already covers it --
                nothing to generate, nothing to copy for that part.
```

## Why this can work at all

A rowparity case is not *authored* so much as it is *implied* by the query it
compares:

| The case file says | Where that fact already lives |
|---|---|
| `keys: [83 columns]` | the query's GROUP BY dimensions |
| `breakdown_by: slot_user_drop_off` | the one dimension that is a distinct literal per UNION branch |
| `unordered_list_columns: [...]` | which arrays come from a source column vs are built inline |
| every branch references `${facts}` or its batch parameter | a per-branch scan of the file, not a count typed once |
| `assert len(dims) == 83` | the SELECT list |

None of those is a judgement call. Today a human transcribes them by hand, and
every transcription is a chance for the list to drift from the query — which is
exactly what the checks in `tests/test_insight_plus_sql_sync.py` exist to
catch. PRISM removes the transcription step, and the drift with it.

## What it is not

**Not an entry point.** There is no `[project.scripts]` line for PRISM and there
will not be. rowparity is the product; PRISM is an external utility that writes
files for it. Run it with `python -m prism` from the repo root.

**Not a dependency.** Nothing in `src/rowparity/` imports this package, and
neither do the files PRISM generates, nor `tests/test_insight_plus_sql_sync.py`
— the SELECT-list parser is *inlined* there too, so your suite never depends on
a code generator at run time. `prism/tests/test_roundtrip.py` guards that copy
against drift from `prism/analyse.py`'s real one.

**Not an owner.** Every generated file says it was generated, from what, and
that it is meant to be edited. `generate` refuses to overwrite an existing file
without `--force`, and writes into `prism/output/` rather than your source tree.
The moment you copy one into place and edit it, you own it.

## Install

Nothing. Layer 1 is Python standard library only — `re`, `os`, `argparse`,
`dataclasses`, `typing`, `difflib`, `datetime`. `pyyaml` is used by the tests,
not by PRISM itself.

## Commands

```bash
python -m prism inspect  <file.sql>     # what it read; writes nothing
python -m prism generate <file.sql>     # write the two files into prism/output/
python -m prism verify   <file.sql>     # diff what it would write against the repo
```

### Where the files land

**`prism/output/`, never your source tree.** A generator that writes straight
into `tests/` on a first run is one you have to `git checkout` your way out of.
You generate, read what came out, and copy it into place yourself.

```
prism/output/
  scripts/cases_insight_plus/f_supply_portfolio_hourly.yaml
  sql/insight_plus/f_supply_portfolio_hourly_drilldown.sql
  sql/insight_plus/f_supply_portfolio_hourly.sql        ← your source, copied in
```

**No `test_<name>_case.py`, and no `test_<name>_sql_sync.py` either.** Both
used to be generated per case -- one restating facts the `Case` object already
carries (`CASE_NAME` is `case.name`, and so on), the other counting
`${facts}.` references and batch predicates in that case's own SQL text. Every
one of those numbers is now derived at test time instead of typed once per
case: `tests/test_insight_plus_sql_sync.py` discovers every case under
`scripts/cases_insight_plus/` and parametrizes over the result, so a case
dropped in beside this one is covered the moment PRISM finishes -- nothing to
generate, nothing to copy, nothing to keep in sync by hand. See "Why one
shared test" below.

The output **mirrors the repo layout** rather than being a flat dump, and that
is forced rather than chosen: the generated YAML carries
`query_file: ../../sql/insight_plus/<name>.sql`, so the case file has to sit two
levels under a root that also holds `sql/insight_plus/`. Flatten it and the path
breaks — and you could not even run `rowparity list` on the output to review it.

Your parity `.sql` is copied in for the same reason, which makes the output a
**complete, runnable preview**:

```bash
rowparity list prism/output/scripts/cases_insight_plus
rowparity list prism/output/scripts/cases_insight_plus --check --param <batch>=...
```

Both work against the output tree, before anything touches your repo. When you
are happy:

```bash
cp -r prism/output/* .
```

`prism/output/` is gitignored — it is regenerable, and the files that matter are
the ones you copied.

| Flag | |
|---|---|
| `--root DIR` | override the destination. `generate` defaults to `prism/output`; `verify` defaults to the repo root, because its job is diffing the case actually in use |
| `--no-copy-source` | do not copy the parity `.sql` into the output (the copy is what makes the preview runnable) |
| `--dry-run` | say what would be written |
| `--force` | overwrite files that exist |
| `--only case drilldown` | regenerate a subset |
| `--expected-facts` / `--actual-facts` | the two catalogs (defaults are this project's) |
| `--show-diff` | on `verify`, print the unified diff |

### `verify` is the one that matters

Regenerates in memory and diffs against what is on disk. Point it at a case a
human already wrote and the diff shows where PRISM's derivation disagrees with
judgement — either a PRISM bug or a decision worth writing down.

It is also the CI hook. Add a column to the SELECT and forget `keys:`, and
`prism verify` goes red before `rowparity run` ever touches the cluster:

```bash
python -m prism verify sql/insight_plus/f_demand_portfolio_hourly.sql \
    --only case --show-diff || exit 1
```

## What it derives, and how

| Output | Derivation | Certainty |
|---|---|---|
| dimensions / metrics | outermost call is an aggregate → metric; else dimension | exact |
| `keys` | every dimension, sorted | exact |
| branch count | `UNION ALL` occurrences, comments stripped first | exact |
| `breakdown_by` | the one dimension that is a distinct literal in every branch | exact |
| `unordered_list_columns` | `array[...]` = constructed = ordered; anything else yielding an array = passed through = unordered | exact |
| the SQL-template checks | not generated -- `tests/test_insight_plus_sql_sync.py` derives its own expectations per case: every UNION branch references the batch parameter, neither side's catalog is hardcoded, the placeholder set is exactly what the case's own `vars:` block declares | exact, and automatic |
| the wiring checks | not generated either -- the same file derives them live from the `Case` object | exact, and automatic |
| `row_summary` | **column-name rules** in `rules.py` | **a guess — review it** |

That last row is the only one PRISM guesses at, and it always says so in the
output.

## The issues list is a deliverable

`inspect` and `generate` both end with what PRISM could not decide, or decided
against the odds:

```
  1 thing(s) PRISM wants you to look at:
    - row_summary came from column-name rules (prism/rules.py), not from the
      query -- it is a presentation choice. 8 group(s) covering 35% of
      dimensions; review them.
```

Others it will raise: no `${facts}` placeholder (both sides would read the same
tables), fewer sampling markers than branches (an unsampled branch skews the
aggregate while the total still looks plausible), fewer batch predicates than
branches (a branch pinned to a different window, **on both sides**, so nothing
errors and the drift reads as a migration defect), UNION branches with nothing to
partition them, a literal catalog left in the template.

A generator that silently guesses is worse than one that says what it guessed.

## Verified against the real thing

`f_demand_portfolio_hourly` has a hand-written case beside it, derived by a
person and verified against a live cluster. That makes it a known-correct answer
that predates PRISM:

```
13/13 semantic fields match
   compare.keys (83 dimensions) · breakdown_by · unordered_list_columns
   near_miss · max_examples · vars.sampling_filter
   expected/actual .type and .vars.facts
   drilldown .bind, .kinds, .time

24/24 tests/test_insight_plus_sql_sync.py tests pass against the real case --
      the SAME 24, unmodified, that pass for every other case in the directory
```

`row_summary` differs, as it is meant to: rules produce 8 groups where the human
chose 7. `prism/tests/test_roundtrip.py` asserts the match on everything else and
asserts the *difference* here, because a test that pretended otherwise would be
lying about where the uncertainty lives.

## Why one shared test

Two things used to be generated per case, and both had the same problem.

A `test_<name>_case.py` had eleven-plus tests, and every one of them existed
only because the `Case` object hadn't been asked directly: `CASE_NAME` is
`case.name`, `EXPECTED_FACTS`/`ACTUAL_FACTS` are `case.expected["vars"]`/
`case.actual["vars"]`, `BATCH_PARAM` is `case.drilldown["time"]["param"]`.
Nothing in that constants block was a judgement call PRISM made -- it was a
restatement of facts already sitting on the case, retyped once per case.

A `test_<name>_sql_sync.py` had eight-plus tests, and its constants were a
different kind of restatement: `EXPECTED_FACT_REFS = 6`, `EXPECTED_BATCH_REFS
= 7`, counted out of that case's own SQL once at generation time and frozen.
That freezing is exactly the failure mode a regression guard needs to avoid --
if a later edit reverts *one* of several `UNION` branches to a hardcoded
literal, a whole-document count catches it only if the count happens to
change; a per-branch check catches it regardless. So instead of a count typed
once, `tests/test_insight_plus_sql_sync.py` splits each case's SQL on
`UNION ALL` and asserts the batch placeholder reaches every branch, and that
neither side's catalog string appears anywhere in the raw template outside
`${facts}`. Proven, not just asserted: with one of a 7-branch query's batch
predicates reverted to a stale literal, the case-shape checks alone (the old
`test_<name>_case.py`'s equivalent) ran fully green -- 16 passed, 2 skipped, no
failures -- while the per-branch checks caught it immediately, naming the
branch and the literal.

`tests/test_insight_plus_sql_sync.py` asks the `Case` object and the raw SQL
text instead of restating either. It discovers every case under
`scripts/cases_insight_plus/` at collection time and parametrizes over the
result, so it is proven twice over in this repo: against
`f_demand_portfolio_hourly` and `f_demand_mpe_hourly` together -- 49 items
collected (24 tests × 2 cases + 1 always-collected guard test), 47 passed, 2
skipped (a case with no source-order arrays and no sampling filter has nothing
for those two checks to do) -- the SAME 24 tests, unmodified, run against both.

Dropping a new case's `.yaml`/`.sql` in beside an existing one is enough. There
is nothing else to generate, copy, or keep in sync by hand.

Parametrizing at module scope carries a hazard: computing the parametrize list
by calling `discover_cases()` at import time means a broken case YAML raises
*during collection*, and pytest's default reaction to a collection error is to
abort the whole session -- every unrelated test file, not just this one. Fixed
by catching the exception at module scope, storing it, and leaving the
parametrize list empty on failure (zero test items, not an error) while a
dedicated, always-collected test -- `test_the_case_directory_loads_at_all` --
re-raises it as an ordinary failure. A broken case YAML now fails exactly that
one test; the rest of the suite runs normally.

## Layout

```
prism/
  __main__.py      python -m prism
  analyse.py       .sql → QueryProfile.  Deterministic. Stdlib only.
  rules.py         the ONE judgement call, isolated so it is swappable
  generate.py      QueryProfile → two files.  Pure templating.
  cli.py           inspect | generate | verify
  tests/
    test_analyse.py    the parser, against known-correct numbers
    test_roundtrip.py  PRISM vs the hand-written case, and the drift guard
                       on tests/test_insight_plus_sql_sync.py's inlined parser

tests/
  test_insight_plus_sql_sync.py   the ONLY test file for this case directory
                        -- NOT generated, NOT per-case. Covers wiring and
                        SQL-template checks for every case PRISM writes for.
```

`QueryProfile` is the seam. All the risk is on the analysis side of it — a
mis-parsed SELECT list makes every output wrong — so analysis is separately
testable, and rendering that reads a dataclass is hard to get subtly wrong. A
third and fourth generated output would each have cost one function; a case
that needs nothing generated for either -- the SQL-template checks and the
wiring checks -- cost removing two functions instead, and folding what they
checked into one already-shared file.

## Where a model would go later

`rules.derive_row_summary(dimensions) -> [{"label", "columns"}]` is the only
fuzzy function in the package, and it is alone in its own module for that reason.
A classifier trained on reviewed groupings would replace that one function and
touch nothing else.

Two conditions before that is worth doing: a corpus (~20 hand-reviewed groupings
— the 130 biz_service queries would provide it), and a held-out measurement
showing the model beats the rules. Until both exist, rules ship.

The boundary is fixed regardless: **nothing that decides what "equal" means —
`keys`, `breakdown_by`, `unordered_list_columns`, the test counts — will ever be
model-derived.** A wrong `row_summary` label is cosmetic. A wrong key silently
redefines "the same row".

## Adding a case with PRISM

```bash
# 1. write the SQL: ${facts} everywhere, dimensions literal,
#    ${sampling_filter} per branch, the batch predicate
vim sql/insight_plus/f_supply_portfolio_hourly.sql

# 2. look before you leap
python -m prism inspect sql/insight_plus/f_supply_portfolio_hourly.sql

# 3. generate — lands in prism/output/, touches nothing else
python -m prism generate sql/insight_plus/f_supply_portfolio_hourly.sql

# 4. review it where it stands; the output tree is runnable
rowparity list prism/output/scripts/cases_insight_plus
rowparity list prism/output/scripts/cases_insight_plus --check \
    --param arena.presto.var.process_batch_id=20260812010000

# 5. install, then the one check that covers it -- and every other case
cp -r prism/output/* .
pytest tests/test_insight_plus_sql_sync.py -q

# 6. finish the drill-down's TODO(you) branch predicates, then run it
rowparity run scripts/cases_insight_plus --select f_supply_portfolio_hourly \
    --param arena.presto.var.process_batch_id=20260812010000 \
    --html reports/insight_plus/supply.html
```

Step 6's `TODO(you)` markers are the honest part: the drill-down's branch
predicates must be copied verbatim from the parity query's WHERE clause, and no
parser knows which branch you care about. PRISM fills in the boring 80% and
labels the rest rather than producing a file that looks finished and is not.
