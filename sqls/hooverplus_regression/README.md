# Hoover vs Hoover++ regression suite

Generated — do not edit by hand. Regenerate after the corpus changes:

```bash
python scripts/build_hoover_suite.py --corpus ../vulcan-docs/sqls --out sqls/hooverplus_regression
```

The source is `vulcan-docs/sqls/regression/`: one normalised SELECT per query
shape, with every raw hoover table left as `{{bcv_<table>}}` and the partition
filter lifted into the header.

## Running it

An external Airflow runs the suites; `schedule.yaml` says which run when, and
this repo provides the lists and one command to run them by hand.

### The week

`schedule.yaml` maps weekday to suites, evening out the daily case count so no
day is twice the length of another. Every case runs once a week:

| Day | Cases | Suites |
|---|---|---|
| Monday | 56 | `hoover_auction` |
| Tuesday | 54 | `hoover_candidate` |
| Wednesday | 57 | `hoover_ack_delivery_events`, `hoover_slot` |
| Thursday | 59 | `hoover_ack_partner_audience`, `hoover_ack_revenue_deal` |
| Friday | 66 | `hoover_ad`, `hoover_join` |
| Saturday | 59 | `hoover_request`, `hoover_publisher_keyvalue_click` |
| Sunday | 65 | `hoover_publisher_audience_ack`, `hoover_publisher_slot_inventory` |

A day runs whole suites rather than a slice of every suite, so a day's failures
point at the tables that day covered. It is generated, so a corpus change can
move a suite to a different day; regenerating an unchanged corpus does not.

### Suites

Every runnable case is in exactly one list under `suites/`, and `cases.csv`
records the suite for every case. Suites follow the hoover table a case reads,
not the account that wrote it, because a difference almost always traces to one
Hoover++ table.

| Suite | Cases | What's in it |
|---|---|---|
| `hoover_ack_delivery_events` | 48 | ack only: counts, event filters |
| `hoover_ack_partner_audience` | 47 | ack only: `partners__*` unnests, audience segments |
| `hoover_ack_revenue_deal` | 12 | ack only: revenue, price, deal, bid columns |
| `hoover_ad` | 37 | ad only |
| `hoover_auction` | 56 | auction only |
| `hoover_candidate` | 54 | candidate only |
| `hoover_request` | 37 | request only |
| `hoover_slot` | 9 | slot only |
| `hoover_join` | 29 | two or more tables; can break where the tables meet |
| `hoover_publisher_audience_ack` | 33 | one publisher template, once per network |
| `hoover_publisher_keyvalue_click` | 22 | two publisher templates, once per network |
| `hoover_publisher_slot_inventory` | 32 | two publisher templates, once per network and timezone |

The publisher suites repeat the same SQL for different networks, so they can run
less often than the table suites. The 46 cases that read `transaction` are
disabled until Hoover++ has a view for it; `cases.csv` marks them
`hoover_disabled`, and they get no list, because `--cases` runs a case even when
it is disabled. Once the view exists, regenerating puts them in `hoover_transaction`
and `hoover_join`.

The rules are in `suite_for` in `scripts/build_hoover_suite.py`. They depend only
on each file's SQL, so regenerating an unchanged corpus leaves every case where it was.

### One suite

```bash
scripts/rowparity_flow.sh sqls/hooverplus_regression/rowparity.yaml \
  --cases sqls/hooverplus_regression/suites/hoover_ack_revenue_deal.txt \
  --workers 5 --run-id "<scheduler run id>-hoover_ack_revenue_deal" \
  --publish s3://<bucket>/rowparity --presto
```

| Option | Meaning |
|---|---|
| `--workers N` | cases running at once (default 5) |
| `--batch <id>` | pin the batch; pass the same one to several suites to make them comparable |
| `--client-tags TAGS` | Presto gateway tags choosing the cluster: the flag, else `TRINO_CLIENT_TAGS`, else `hoover_regression`. A case's own `connection.client_tags` still wins for that case. |
| `--limit N` | only the first N cases of the list |

Exit code: `0` all passed, `1` something differed or never reported, `2` could not
run. A scheduler should retry `2` at most, never `1`: a rerun of a real difference
only repeats two heavy queries.

### A few cases

```bash
# In parallel, with a summary
scripts/rowparity_flow.sh sqls/hooverplus_regression/rowparity.yaml \
  --cases <(printf '%s\n' sa-presto-tier2.ad_f02b6641 xyli.request_7f82fe51) \
  --publish s3://<bucket>/rowparity-sandbox --presto
# One after another in one process, no summary
rowparity run sqls/hooverplus_regression/rowparity.yaml \
  --select sa-presto-tier2.ad_f02b6641 xyli.request_7f82fe51 --param batch_id=20260812010000
```

`--group` is ignored when `--cases` is given: a suite list runs whole.

## The hour

Every case reads **one event-hour**, and every case in a run reads the same one:
comparing tests to each other only means something if they measured the same
data.

The hour is 08:00 on the run date. A batch holds events from several hours and
an hour's events land across several batches, so the slice is the hour equality
plus the three batches that can carry it:

```sql
date_trunc('HOUR', CAST(request__timestamp AS timestamp))
    = date_trunc('HOUR', date_parse('20260918080000', '%Y%m%d%H%i%s'))
  AND bitwise_and(request__bit_flags, 576460752303423488) > 0   -- is sampled
  AND process_batch_id IN ('20260918060000', '20260918070000', '20260918080000')
```

Pinning the batch alone would compare a complete *batch* -- self-consistent,
but not a number the queries' owners can read. This compares a complete *hour*.

`batch_params.py` renders the three ids from a run date; the runner resolves
them **once** and pins them on every case with `--param`, because resolving per
case would leave half the suite on another hour.

```bash
python batch_params.py 2026-09-18      # the scheduled hour for that date
python batch_params.py 20260918140000  # a different hour, for a re-measure
python batch_params.py                 # today, UTC
```

* **Automatic**: `scripts/rowparity_flow.sh` calls it for `--date` (default
  today); the Airflow DAG calls it through `ROWPARITY_PARAMS_CMD`.
* **Pinned**: `--batch 20260918140000` re-measures one hour. Two runs on the
  same hour are directly comparable -- the same rows, so any difference is the
  code, not the data -- which is what you want while chasing a regression. It
  ages out of retention eventually, and it stops proving anything about fresh
  data. Pass it to `--batch`, never straight to `--param batch_id=`: that would
  leave `batch_id_prev1`/`_prev2` on their defaults and slice one hour out of
  another hour's batches.

Each run records the ids it used in `result.json` (`run.params`) and in
`rowparity.run_summary`, so a result always says which data it judged.

`sandbox10.txt` is a starter set of ten cases: one per hoover table Hoover++ has
a view for, plus a four-table join, a publisher template case and the
`CURRENT_DATE` one. It is the right first run against a cluster.

```bash
rowparity list sqls/hooverplus_regression/rowparity.yaml --check      # resolves offline, no cluster
scripts/rowparity_flow.sh sqls/hooverplus_regression/rowparity.yaml \
  --cases sqls/hooverplus_regression/sandbox10.txt \
  --publish s3://<bucket>/rowparity-sandbox --presto
rowparity run  sqls/hooverplus_regression/rowparity.yaml --select sa-pqm.transaction_dfdf059b \
  --param batch_id=20260812010000 --publish s3://<bucket>/rowparity-sandbox
scripts/rowparity_flow.sh sqls/hooverplus_regression/rowparity.yaml --limit 10 --presto
```

Both sides run the same SQL; only the table binding differs. Each of the seven
hoover tables binds to a sliced subquery, so the partition filter reaches the
scan:

```yaml
# Hoover
bcv_ack: (SELECT * FROM mrm_log_flat.default.ack WHERE <the slice above>)
# Hoover++
bcv_ack: (SELECT * FROM etl.public_test1.ack     WHERE <the same slice>)
```

The predicate is identical on both sides, sampling included, so the sample can
never be the difference. `ack` slices on `ack__timestamp`; every other table on
`request__timestamp`. Compare the whole population with
`--param sampling_filter=true`.

**The schema names, view names and slice predicate in `rowparity.yaml` are
placeholders.** Change them there (or in a `--tables` config) and regenerate.

## What the generator changed, and why

| Change | Files | Why |
|---|---|---|
| `{{bcv_<table>}}` → `${bcv_<table>}` | 462 | Rowparity binds each table per side. The header comment's literal is left alone. |
| Trailing `LIMIT n` and the `ORDER BY` feeding it, removed | 116 | Without a total order it keeps an arbitrary subset; rowparity compares rows as a set anyway. |
| Nested `LIMIT` removed | 4 | Guard rails or unordered subsets inside a CTE. A real top-N (`sa-pqm/transaction_dfdf059b`) is kept. |
| `CURRENT_TIMESTAMP` / `CURRENT_DATE` → `${as_of_ts}` / `${as_of_date}` | 3 | Both sides must read the same instant; `CURRENT_TIMESTAMP AS updated` differs by construction otherwise. |
| Literal `mrm_log_flat.default."request"` → `${bcv_request}` | 1 | Normalisation missed it, so both sides would have run identical SQL. |

## Not here

`excluded.csv` lists the 24 shapes that cannot be compared:

- `RAND()` (9) and `TABLESAMPLE BERNOULLI` (5) draw a different row set on every
  execution, so the two sides can never agree.
- `approx_percentile` (10): a t-digest depends on input order, so the two sides
  can differ on identical data. A pass or a fail would say nothing.

Kept, but tagged: `bit59_sampled` (1 shape) applies the bit-59 sampling filter.
It is deterministic, so it compares like any other case.

`cases.csv` maps every generated case back to its corpus file, tables, tags and suite.
