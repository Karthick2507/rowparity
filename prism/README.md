# PRISM

**You write the parity SQL. PRISM writes the other four files.**

```bash
python -m prism generate sql/insight_plus/f_supply_portfolio_hourly.sql
```

```
                    f_supply_portfolio_hourly.sql          ← you write this
                                 │
                              PRISM
                                 │
        ┌────────────────┬───────┴────────┬──────────────────────┐
        ▼                ▼                ▼                      ▼
  cases_insight_plus/  tests/          tests/            sql/insight_plus/
  ..._hourly.yaml      test_..._      test_..._          ..._drilldown.sql
                       case.py        sql_sync.py
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

**Not a dependency.** Nothing in `src/rowparity/` imports this package, and the
files PRISM generates do not import it either — the SELECT-list parser is
*inlined* into the generated test so your suite never depends on a code
generator at run time.

**Not an owner.** Every generated file says it was generated, from what, and
that it is meant to be edited. `generate` refuses to overwrite an existing file
without `--force`. The moment you edit one, you own it.

## Install

Nothing. Layer 1 is Python standard library only — `re`, `os`, `argparse`,
`dataclasses`, `typing`, `difflib`, `datetime`. `pyyaml` is used by the tests,
not by PRISM itself.

## Commands

```bash
python -m prism inspect  <file.sql>     # what it read; writes nothing
python -m prism generate <file.sql>     # write the four files
python -m prism verify   <file.sql>     # diff what it would write against disk
```

| Flag | |
|---|---|
| `--root DIR` | repo root (default `.`) — generate into a scratch tree first |
| `--dry-run` | say what would be written |
| `--force` | overwrite files that exist |
| `--only case sql_sync_test case_test drilldown` | regenerate a subset |
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
| dimensions / metrics | a `sum()` in the SELECT item makes it a metric | exact |
| `keys` | every dimension, sorted | exact |
| branch count | `UNION ALL` occurrences, comments stripped first | exact |
| `breakdown_by` | the one dimension that is a distinct literal in every branch | exact |
| `unordered_list_columns` | `array[...]` = constructed = ordered; anything else yielding an array = passed through = unordered | exact |
| the three test counts | `${facts}.`, sampling markers, batch predicates | exact |
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

28/28 generated tests pass against the real 185 KB query
```

`row_summary` differs, as it is meant to: rules produce 8 groups where the human
chose 7. `prism/tests/test_roundtrip.py` asserts the match on everything else and
asserts the *difference* here, because a test that pretended otherwise would be
lying about where the uncertainty lives.

## Layout

```
prism/
  __main__.py      python -m prism
  analyse.py       .sql → QueryProfile.  Deterministic. Stdlib only.
  rules.py         the ONE judgement call, isolated so it is swappable
  generate.py      QueryProfile → four files.  Pure templating.
  cli.py           inspect | generate | verify
  tests/
    test_analyse.py    the parser, against known-correct numbers
    test_roundtrip.py  PRISM vs the hand-written case
```

`QueryProfile` is the seam. All the risk is on the analysis side of it — a
mis-parsed SELECT list makes all four files wrong — so analysis is separately
testable, and rendering that reads a dataclass is hard to get subtly wrong. A
fifth output would cost one function.

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

# 3. generate into a scratch tree first if you want to see it whole
python -m prism generate sql/insight_plus/f_supply_portfolio_hourly.sql --root /tmp/try

# 4. for real
python -m prism generate sql/insight_plus/f_supply_portfolio_hourly.sql

# 5. the checks that cost nothing
rowparity list scripts/cases_insight_plus
rowparity list scripts/cases_insight_plus --check \
    --param arena.presto.var.process_batch_id=20260812010000
pytest tests/test_f_supply_portfolio_hourly_case.py \
       tests/test_f_supply_portfolio_hourly_sql_sync.py -q

# 6. finish the drill-down's TODO(you) branch predicates, then run it
rowparity run scripts/cases_insight_plus --select f_supply_portfolio_hourly \
    --param arena.presto.var.process_batch_id=20260812010000 \
    --html reports/insight_plus/supply.html
```

Step 6's `TODO(you)` markers are the honest part: the drill-down's branch
predicates must be copied verbatim from the parity query's WHERE clause, and no
parser knows which branch you care about. PRISM fills in the boring 80% and
labels the rest rather than producing a file that looks finished and is not.
