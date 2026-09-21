# PRISM

**You write the parity SQL. PRISM writes three more files. A fourth --
the wiring test -- you never write at all.**

```bash
python -m prism generate sql/insight_plus/f_supply_portfolio_hourly.sql
```

```
                    f_supply_portfolio_hourly.sql          ← you write this
                                 │
                              PRISM
                                 │
                         prism/output/   ← never your source tree
        ┌────────────────┬────────────────┬──────────────────────┐
        ▼                ▼                ▼                      ▼
  scripts/             tests/       sql/insight_plus/    sql/insight_plus/
  cases_insight_plus/  test_..._    ..._drilldown.sql     f_supply..._.sql
  ..._hourly.yaml      sql_sync.py                        (copy of yours)

                        review it, then  cp -r prism/output/* .
                                 │
                    tests/test_case_wiring.py already covers it --
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
| `EXPECTED_FACT_REFS = 3` | count of `${facts}.` in the file |
| `EXPECTED_SAMPLING_LINES = 3` | count of the sampling marker |
| `assert len(dims) == 83` | the SELECT list |

None of those is a judgement call. Today a human transcribes them by hand, and
every transcription is a chance for the list to drift from the query — which is
exactly what the generated tests exist to catch. PRISM removes the transcription
step, and the drift with it.

## What it is not

**Not an entry point.** There is no `[project.scripts]` line for PRISM and there
will not be. rowparity is the product; PRISM is an external utility that writes
files for it. Run it with `python -m prism` from the repo root.

**Not a dependency.** Nothing in `src/rowparity/` imports this package, and
neither do the files PRISM generates, nor `tests/test_case_wiring.py` — the
SELECT-list parser is *inlined* there too, so your suite never depends on a
code generator at run time. `prism/tests/test_roundtrip.py` guards that copy
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
python -m prism generate <file.sql>     # write the three files into prism/output/
python -m prism verify   <file.sql>     # diff what it would write against the repo
```

### Where the files land

**`prism/output/`, never your source tree.** A generator that writes straight
into `tests/` on a first run is one you have to `git checkout` your way out of.
You generate, read what came out, and copy it into place yourself.

```
prism/output/
  scripts/cases_insight_plus/f_supply_portfolio_hourly.yaml
  tests/test_f_supply_portfolio_hourly_sql_sync.py
  sql/insight_plus/f_supply_portfolio_hourly_drilldown.sql
  sql/insight_plus/f_supply_portfolio_hourly.sql        ← your source, copied in
```

**No `test_<name>_case.py`.** A generated one was identical in shape to every
other case's -- eleven of the same tests, differing only in a constants block
the `Case` object and its own SQL already carry. `tests/test_case_wiring.py`
derives that block itself and is parametrized over every case
`discover_cases()` finds under `scripts/cases_insight_plus/`, so a case dropped
in beside this one is covered the moment PRISM finishes -- nothing to generate,
nothing to copy, nothing to keep in sync by hand. See §"Why one shared wiring
test" below.

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
| `--only case sql_sync_test drilldown` | regenerate a subset |
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
| the sql_sync test counts | `${facts}.`, sampling markers, batch predicates | exact |
| the wiring checks | not generated at all — `tests/test_case_wiring.py` derives them live from the `Case` object | exact, and automatic |
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

11/11 generated sql_sync tests pass against the real 185 KB query
18/18 tests/test_case_wiring.py tests pass against the real case -- the SAME
      18, unmodified, that pass for every other case in the directory
```

`row_summary` differs, as it is meant to: rules produce 8 groups where the human
chose 7. `prism/tests/test_roundtrip.py` asserts the match on everything else and
asserts the *difference* here, because a test that pretended otherwise would be
lying about where the uncertainty lives.

## Why one shared wiring test

A generated `test_<name>_case.py` had eleven tests, and every one of them
existed only because the `Case` object hadn't been asked directly: `CASE_NAME`
is `case.name`, `EXPECTED_FACTS`/`ACTUAL_FACTS` are `case.expected["vars"]`/
`case.actual["vars"]`, `BATCH_PARAM` is `case.drilldown["time"]["param"]`,
`EXPECTED_DIMENSIONS`/`METRICS` are one SQL parse away. Nothing in that
constants block was a judgement call PRISM made -- it was a restatement of
facts already sitting on the case, retyped once per case.

`tests/test_case_wiring.py` asks the `Case` object instead of restating it. A
generated `test_<name>_case.py` had 17 tests; the shared file has 18 -- one
more (`test_both_sides_sample_identically`), because deriving from the case
rather than a hand-typed constant made a check worth adding cheap.

It discovers every case under `scripts/cases_insight_plus/` at collection time
and parametrizes over the result, so it is proven twice over in this repo:
against `f_demand_portfolio_hourly` (18/18) and, during development, against a
second case cloned from it under a different name -- same 18 tests, `[36
passed]` for the pair, and when one clone's `keys:` was deliberately broken,
exactly one test failed, named to the clone, with the original untouched.
(`pytest tests/test_case_wiring.py -q` collects 19 items, not 18 -- the 18
per-case tests plus one always-collected guard, `test_the_case_directory_loads_at_all`,
described below.)

Dropping a new case's `.yaml`/`.sql` in beside an existing one is enough. There
is no fifth file to generate, copy, or keep in sync by hand.

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
  generate.py      QueryProfile → three files.  Pure templating.
  cli.py           inspect | generate | verify
  tests/
    test_analyse.py    the parser, against known-correct numbers
    test_roundtrip.py  PRISM vs the hand-written case, and the drift guard
                       on tests/test_case_wiring.py's inlined parser

tests/
  test_case_wiring.py   shared, parametrized wiring test -- NOT generated,
                        NOT per-case. Covers every case PRISM writes for.
```

`QueryProfile` is the seam. All the risk is on the analysis side of it — a
mis-parsed SELECT list makes every output wrong — so analysis is separately
testable, and rendering that reads a dataclass is hard to get subtly wrong. A
fourth generated output would cost one function; a case that needs nothing
generated at all — the wiring test — cost removing one instead.

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

# 5. install, then the checks that cost nothing
cp -r prism/output/* .
pytest tests/test_f_supply_portfolio_hourly_sql_sync.py -q   # this case's SQL checks
pytest tests/test_case_wiring.py -q                          # every case, incl. this one

# 6. finish the drill-down's TODO(you) branch predicates, then run it
rowparity run scripts/cases_insight_plus --select f_supply_portfolio_hourly \
    --param arena.presto.var.process_batch_id=20260812010000 \
    --html reports/insight_plus/supply.html
```

Step 6's `TODO(you)` markers are the honest part: the drill-down's branch
predicates must be copied verbatim from the parity query's WHERE clause, and no
parser knows which branch you care about. PRISM fills in the boring 80% and
labels the rest rather than producing a file that looks finished and is not.
