"""Build a rowparity suite from the generated hoover SQL corpus.

The corpus (vulcan-docs/sqls/regression) is one normalised SELECT per query
shape, with every raw hoover table left as ``{{bcv_<table>}}`` and the partition
filter lifted into the header. This turns that into a runnable suite:

    build_hoover_suite.py --corpus ../vulcan-docs/sqls --out suites/hoover

What it changes, and why each change is safe to make automatically:

* ``{{bcv_ack}}`` -> ``${bcv_ack}``, so rowparity binds each of the seven tables
  per side. The literal ``{{bcv_<table>}}`` in the header comment is left alone.
* ``CURRENT_TIMESTAMP`` / ``CURRENT_DATE`` / ``NOW()`` -> ``${as_of_ts}`` /
  ``${as_of_date}``. Both sides then read the same instant; otherwise a column
  like ``CURRENT_TIMESTAMP AS updated`` differs on every run by construction.
* Trailing ``LIMIT n`` (and the ``ORDER BY`` that fed it) is removed: without a
  total order it keeps an arbitrary subset, and rowparity compares rows as a set
  anyway. Nested limits are left alone unless listed in DROP_NESTED_LIMITS.
* Files that cannot agree across two runs (TABLESAMPLE, RAND(), approx_percentile)
  are not written at all. They go to excluded.csv with the reason, so they are
  visibly skipped, not quietly missing.
* Every case lands in exactly one suite (see suite_for), listed one case per
  line in suites/<suite>.txt for a scheduler to run with rowparity_flow.sh --cases.

Everything about *where* the tables are lives in one config (``--tables``), so
the real schema and view names are a one-line change: see TABLES_TEMPLATE.
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from collections import Counter
from typing import Any, Dict, List, Optional, Tuple

import yaml

TABLES = ("ack", "ad", "auction", "candidate", "request", "slot", "transaction")

# The cluster refuses to read these tables without a slice: "Please have at
# least one of *_event_date or bounded process_batch_id in your query". An
# equality on process_batch_id is bounded, so that alone satisfies it and keeps
# the read to one batch.
#
# The literal is quoted because process_batch_id is a string column; drop the
# quotes in the config if it is numeric on your cluster.
#
# Batch ids are YYYYMMDDHHMMSS. Override the predicate per table under
# "slices" in a --tables config if one of them needs a different window.
TIME_COLUMN = {
    "ack": "ack__timestamp",
    "ad": "request__timestamp",
    "auction": "request__timestamp",
    "candidate": "request__timestamp",
    "request": "request__timestamp",
    "slot": "request__timestamp",
    "transaction": "request__timestamp",
}
BATCH_TS = "date_parse('${batch_id}', '%Y%m%d%H%i%s')"

# One event-hour, assembled from the batches that can carry it.
#
# A batch holds events from several hours, and an hour's events land across
# several batches, so pinning the batch alone compares a complete *batch* --
# self-consistent, but not a quantity the queries' owners can read. The hour
# equality plus the batch list compares a complete *hour*, which is.
#
# ${batch_id} is that hour (YYYYMMDDHH0000); the two preceding batches are
# separate placeholders rather than arithmetic on it because the cluster prunes
# partitions only on a bounded process_batch_id, and literals are certain to
# satisfy that. batch_params.py, generated beside the suite, renders all three
# for a run date so the scheduler and this slice cannot drift apart.
HOUR = "date_trunc('HOUR', CAST({column} AS timestamp)) = date_trunc('HOUR', " + BATCH_TS + ")"
SLICE = "process_batch_id IN ('${batch_id_prev2}', '${batch_id_prev1}', '${batch_id}')"
# Both sides carry the full population, so both are sampled down by bit 59 --
# the same predicate on each side, so the sample itself can never be the
# difference. Run both unsampled with --param sampling_filter=true.
SAMPLED = HOUR + " AND ${sampling_filter} AND " + SLICE

# Placeholders for the real names: one edit here re-points the whole suite.
TABLES_TEMPLATE = {
    "expected": {
        "label": "Hoover",
        "schema": "mrm_log_flat.default",
        "slice": SAMPLED,
        "views": {t: t for t in TABLES},
    },
    "actual": {
        "label": "Hoover++",
        "schema": "etl.public_test1",
        "slice": SAMPLED,
        # transaction's view is still being built: its cases generate disabled.
        "views": {t: t for t in TABLES if t != "transaction"} | {"transaction": None},
    },
    # Tables Hoover++ does not change: both sides read the hoover one. A case
    # that reads nothing else is written disabled -- it would compare a table
    # with itself -- but it stays in the suite, ready for when that changes.
    "shared": [],
    # A table with no view on either side maps to None in "views"; cases that
    # read it are disabled with the reason instead of failing at run time.
    # Defaults so the suite resolves offline (`rowparity list --check`). A real
    # run overrides the three batch ids per run date; see batch_params.py.
    "vars": {
        "batch_id": "20260918080000",
        "batch_id_prev1": "20260918070000",
        "batch_id_prev2": "20260918060000",
        # bit 59 = 576460752303423488; `true` compares the whole population.
        "sampling_filter": "bitwise_and(request__bit_flags, 576460752303423488) > 0",
        "as_of_ts": "2026-09-15 00:00:00",
        "as_of_date": "2026-09-15",
    },
    # The hour of the run date every batch is measured against, and how many
    # batches back can still be writing events into it.
    "batch_hour": 8,
    "batch_lookback": 2,
    # 25 example rows: the report lists them, the rest are in Presto.
    "compare": {"float_tolerance": 0.0001, "max_diff_ratio": 0.0001, "max_examples": 25},
}


BATCH_PARAMS = '''#!/usr/bin/env python3
"""Generated by scripts/build_hoover_suite.py -- the batch ids for one run.

rowparity.yaml slices every table to one event-hour: the __HH__:00 batch of the
run date, plus the __LOOKBACK__ before it, which between them hold every event
stamped in that hour. This prints those ids as name=value lines.

    $ python batch_params.py 2026-09-18
    batch_id=20260918__HH__0000
    batch_id_prev1=...
    batch_id_prev2=...

The scheduler resolves them once per run and pins them on every case with
--param, so one run measures one hour and the cases stay comparable to each
other. Keep this file and rowparity.yaml's slice in step: regenerate both.

A full batch id (YYYYMMDDHHMMSS) works too, and uses that hour rather than
__HH__:00 -- pin one to re-measure an hour that already ran. Pinning batch_id
by hand instead would leave the earlier ids on their defaults, slicing one hour
out of another hour's batches. With no argument it uses today, UTC.
"""
import sys
from datetime import datetime, timedelta, timezone

HOUR = __HOUR__
LOOKBACK = __LOOKBACK__


def batch_ids(base):
    """The run hour's batch id first, then each earlier batch, newest first."""
    return [(base - timedelta(hours=back)).strftime("%Y%m%d%H%M%S")
            for back in range(LOOKBACK + 1)]


def base_hour(argument):
    """The hour to measure: a date takes __HH__:00, a batch id keeps its own."""
    if argument is None:
        today = datetime.now(timezone.utc).date()
        return datetime(today.year, today.month, today.day, HOUR)
    if len(argument) == 14 and argument.isdigit():
        return datetime.strptime(argument, "%Y%m%d%H%M%S")
    day = datetime.strptime(argument, "%Y-%m-%d")
    return datetime(day.year, day.month, day.day, HOUR)


def main(argv):
    if len(argv) > 2:
        print("usage: batch_params.py [YYYY-MM-DD | YYYYMMDDHHMMSS]", file=sys.stderr)
        return 2
    try:
        base = base_hour(argv[1] if len(argv) == 2 else None)
    except ValueError:
        print(f"not a YYYY-MM-DD date or a YYYYMMDDHHMMSS batch id: {argv[1]}",
              file=sys.stderr)
        return 2
    ids = batch_ids(base)
    print(f"batch_id={ids[0]}")
    for index, value in enumerate(ids[1:], start=1):
        print(f"batch_id_prev{index}={value}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
'''


def weekly_schedule(members, days=7):
    """Spread the runnable suites over the week, evening out the daily load.

    Longest-processing-time first: the biggest suite goes to the emptiest day.
    Sorted by size then name, so regenerating an unchanged corpus produces the
    same calendar; a corpus change can move a suite to a different day.
    """
    sizes = sorted(((len(cases), name) for name, cases in members.items()
                    if name != "hoover_disabled"),
                   key=lambda pair: (-pair[0], pair[1]))
    plan = {day: [] for day in range(days)}
    load = {day: 0 for day in range(days)}
    for count, name in sizes:
        day = min(range(days), key=lambda d: (load[d], d))
        plan[day].append(name)
        load[day] += count
    return plan, load


# Nested LIMITs to drop as well: a guard rail or an unordered subset, not intent.
# A nested LIMIT that expresses a real top-N (sa-pqm/transaction_dfdf059b.sql)
# is deliberately absent -- dropping it would compare a different question.
DROP_NESTED_LIMITS = {
    "regression/sa-presto-tier2/ad_candidate_67612dc2.sql",
    "regression/sa-presto-tier2/auction_4263ad98.sql",
    "regression/sa-presto-tier2/auction_b2da0f20.sql",
    "regression/ychan375/arena_batch_42373da1.sql",
}

BLOCK, LINE, STR = re.compile(r"/\*.*?\*/", re.S), re.compile(r"--[^\n]*"), re.compile(r"'(?:''|[^'])*'", re.S)
NOT_COMPARABLE = [
    ("tablesample", re.compile(r"\btablesample\s+(?:bernoulli|system)\s*\(", re.I),
     "TABLESAMPLE draws a different row set on every execution"),
    ("rand", re.compile(r"\b(?:rand|random)\s*\(\s*\)", re.I),
     "RAND()/RANDOM() draws a different row set on every execution"),
    ("approx_percentile", re.compile(r"\bapprox_percentile\s*\(", re.I),
     "approx_percentile (t-digest) depends on input order: the sides can differ on identical data"),
]
RISK_TAGS = [
    ("sample_rate", re.compile(r"\bnetwork_sample_info\b|\bsample_rate\b", re.I)),
    ("bit59_sampled", re.compile(r"bitwise_and\s*\([^()]*bit_flags[^()]*,\s*576460752303423488", re.I)),
]

# Suites follow the hoover table a case reads, not the account that wrote it: a
# difference almost always traces to one Hoover++ table, so a suite per table
# points straight at it.
#
# Publisher reports are a handful of templates run once per network. Each one
# is its own suite, so a scheduler can run it less often than the table suites.
# Keyed on the header's skeleton hash, which is identical across the networks.
TEMPLATE_SUITES = {
    "aa21ead7c0b7815ebdc131f7beb18836": "hoover_publisher_audience_ack",
    "4096c9ea2055b6bfbd9750e110d7ea32": "hoover_publisher_keyvalue_click",
    "15ac9a67b235bdc04652f3a520fc0b12": "hoover_publisher_keyvalue_click",
    "4a928b3df5617860586cdf1914fcf8d7": "hoover_publisher_slot_inventory",
    "a82bfe491c7c8524655e47d22c6f56d1": "hoover_publisher_slot_inventory",
}
# ack reads outnumber every other table, so they split by what the query
# measures. The first match wins; the rest are delivery counts and events.
ACK_SUITES = [
    ("hoover_ack_partner_audience", re.compile(r"\bpartners__\w+|\bmatched_segment_pk_ids\b|audience_partner", re.I)),
    ("hoover_ack_revenue_deal", re.compile(r"\w*(?:revenue|price|deal|bid)\w*", re.I)),
]


def suite_for(tables: List[str], disabled: bool, skeleton: str, code: str) -> str:
    """The one suite a case belongs to; the first rule that matches wins."""
    if disabled:
        return "hoover_disabled"
    if len(tables) > 1:
        # A join can break where the tables meet even when each passes alone.
        return "hoover_join"
    if skeleton in TEMPLATE_SUITES:
        return TEMPLATE_SUITES[skeleton]
    if tables == ["ack"]:
        return next((suite for suite, rx in ACK_SUITES if rx.search(code)), "hoover_ack_delivery_events")
    return f"hoover_{tables[0]}"


def strip_sql(text: str) -> str:
    """SQL with comments and string bodies blanked out, same length as the input.

    Offsets found here index straight into the original text, so a rewrite can
    be applied by position. Replacing a comment with a single space instead
    would shift every offset after it -- which silently truncated files mid
    header the first time this ran.
    """
    def blank(match: "re.Match") -> str:
        return "".join("\n" if ch == "\n" else " " for ch in match.group(0))

    text = BLOCK.sub(blank, text)
    text = LINE.sub(blank, text)
    return STR.sub(lambda m: "'" + " " * (len(m.group(0)) - 2) + "'", text)


def replace_spans(text: str, spans: List[Tuple[int, int, str]]) -> str:
    """Apply (start, end, replacement) edits to *text*, last first."""
    for start, end, replacement in sorted(spans, reverse=True):
        text = text[:start] + replacement + text[end:]
    return text


def drop_trailing_limit(sql: str) -> Tuple[str, Optional[str]]:
    """Remove a trailing ``[ORDER BY ...] LIMIT n``. Returns (sql, what was removed)."""
    code = strip_sql(sql)
    match = None
    for m in re.finditer(r"\blimit\s+\d+\b", code, re.I):
        tail = code[m.end():].strip()
        depth = code[: m.start()].count("(") - code[: m.start()].count(")")
        if tail in ("", ";") and depth == 0:
            match = m
    if match is None:
        return sql, None

    start, removed = match.start(), sql[match.start(): match.end()]
    order = None
    for m in re.finditer(r"\border\s+by\b", code[:start], re.I):
        depth = code[: m.start()].count("(") - code[: m.start()].count(")")
        if depth == 0:
            order = m
    if order is not None and not re.search(r"\)\s*$", code[order.end():start].strip() or ")"):
        start = order.start()
        removed = re.sub(r"\s+", " ", sql[start: match.end()]).strip()
    return sql[:start].rstrip() + "\n", removed


def drop_all_limits(sql: str) -> Tuple[str, int]:
    """Remove every ``LIMIT n`` in the SQL body, nested ones included."""
    code = strip_sql(sql)
    spans = [(m.start(), m.end(), "") for m in re.finditer(r"\blimit\s+\d+\b", code, re.I)]
    return replace_spans(sql, spans), len(spans)


def repair_literal_tables(sql: str, schema: str) -> Tuple[str, List[str]]:
    """Rewrite a hard-coded hoover table to its placeholder.

    Normalisation missed a few: the file reads mrm_log_flat.default."request"
    directly, so both sides would run byte-identical SQL and the comparison
    would prove nothing (rowparity refuses it outright).
    """
    code = strip_sql(sql)
    names = "|".join(TABLES)
    # Either "request" quoted whole, or bare request not followed by more word
    # characters -- so request_id is left alone.
    pattern = re.compile(
        re.escape(schema) + rf'\.(?:"({names})"|({names})(?![\w$]))', re.I
    )
    spans, repaired = [], []
    for m in pattern.finditer(code):
        table = (m.group(1) or m.group(2)).lower()
        spans.append((m.start(), m.end(), "${bcv_" + table + "}"))
        repaired.append(table)
    return replace_spans(sql, spans), sorted(set(repaired))


def transform(sql: str, relpath: str, hoover_schema: str = "") -> Tuple[str, Dict[str, object]]:
    notes: Dict[str, object] = {}
    if hoover_schema:
        sql, repaired = repair_literal_tables(sql, hoover_schema)
        if repaired:
            notes["repaired"] = repaired
    # Placeholders in the SQL body only: the header's {{bcv_<table>}} is prose.
    code = strip_sql(sql)
    spans, seen = [], set()
    for table in TABLES:
        for m in re.finditer(r"\{\{bcv_" + table + r"\}\}", code):
            spans.append((m.start(), m.end(), "${bcv_" + table + "}"))
            seen.add(table)
    # A repaired literal is read like any placeholder, so it counts as a table.
    seen.update(notes.get("repaired", []))
    if spans:
        sql = replace_spans(sql, spans)
    if seen:
        notes["tables"] = sorted(seen)

    # Time functions, in the SQL body only: the header comment says what the
    # original query did and must keep saying it.
    code = strip_sql(sql)
    spans = []
    for pattern, replacement in (
        (r"\bCURRENT_TIMESTAMP\b", "CAST('${as_of_ts}' AS TIMESTAMP)"),
        (r"\bLOCALTIMESTAMP\b", "CAST('${as_of_ts}' AS TIMESTAMP)"),
        (r"\bNOW\s*\(\s*\)", "CAST('${as_of_ts}' AS TIMESTAMP)"),
        (r"\bCURRENT_DATE\b", "CAST('${as_of_date}' AS DATE)"),
    ):
        spans += [(m.start(), m.end(), replacement) for m in re.finditer(pattern, code, re.I)]
    if spans:
        sql = replace_spans(sql, spans)
        notes["time_functions"] = len(spans)

    sql, removed = drop_trailing_limit(sql)
    if removed:
        notes["dropped_trailing"] = removed
    if relpath in DROP_NESTED_LIMITS:
        sql, n = drop_all_limits(sql)
        notes["dropped_nested"] = n
    return sql, notes


def header_fields(sql: str) -> Dict[str, str]:
    return {
        k.strip().lower(): v.strip()
        for k, v in re.findall(r"^--\s+([a-z][a-z ]*?):\s+(.+?)\s*$", sql[:3000], re.M | re.I)
    }


def side_vars(config: Dict[str, object], side_name: str) -> Dict[str, str]:
    """Bind each table to a sliced subquery, so the partition filter reaches the scan."""
    side = config[side_name]
    shared = set(config.get("shared") or ())
    out = {}
    for table in TABLES:
        # A shared table is not migrated, so the actual side reads the hoover one.
        source = config["expected"] if table in shared else side
        view = source["views"].get(table)
        if not view:
            continue
        qualified = view if "." in view else f"{source['schema']}.{view}"
        slices = source.get("slices") or {}
        # replace, not str.format: the template also holds ${batch_id}, which
        # format would read as a field name.
        slice_ = slices.get(table, source["slice"]).replace("{column}", TIME_COLUMN[table])
        out[f"bcv_{table}"] = f"(SELECT * FROM {qualified} WHERE {slice_})"
    return out


def unavailable(config: Dict[str, object]) -> List[str]:
    """Tables with no view on one side yet."""
    return sorted(
        t for t in TABLES
        if not config["expected"]["views"].get(t) or not config["actual"]["views"].get(t)
    )


def build(corpus: str, out: str, config: Dict[str, object]) -> Dict[str, int]:
    regression = os.path.join(corpus, "regression")
    if not os.path.isdir(regression):
        sys.exit(f"no regression/ folder under {corpus}")
    sql_out = os.path.join(out, "sql")
    os.makedirs(sql_out, exist_ok=True)

    counts: Counter = Counter()
    missing_views = unavailable(config)
    excluded: List[Dict[str, str]] = []
    written: List[Dict[str, str]] = []

    for dirpath, _, names in os.walk(regression):
        for name in sorted(names):
            if not name.endswith(".sql"):
                continue
            path = os.path.join(dirpath, name)
            relpath = os.path.relpath(path, corpus)
            raw = open(path, encoding="utf-8", errors="replace").read()
            code = strip_sql(raw)
            header = header_fields(raw)
            account = header.get("account") or os.path.basename(dirpath)

            reasons = [why for _id, rx, why in NOT_COMPARABLE if rx.search(code)]
            if reasons:
                counts["excluded"] += 1
                excluded.append({"file": relpath, "account": account,
                                 "reason": "; ".join(reasons)})
                continue

            sql, notes = transform(raw, relpath, config["expected"]["schema"])
            if "${bcv_" not in sql:
                counts["excluded"] += 1
                excluded.append({
                    "file": relpath, "account": account,
                    "reason": "no hoover table: both sides would run identical SQL",
                })
                continue
            if notes.get("repaired"):
                counts["repaired"] += 1
            case_dir = os.path.join(sql_out, account)
            os.makedirs(case_dir, exist_ok=True)
            with open(os.path.join(case_dir, name), "w", encoding="utf-8") as fh:
                fh.write(sql)
            counts["written"] += 1
            if notes.get("dropped_trailing"):
                counts["limit_dropped"] += 1
            if notes.get("dropped_nested"):
                counts["nested_limit_dropped"] += 1
            if notes.get("time_functions"):
                counts["time_bound"] += 1

            used = set(notes.get("tables", []))
            blocked = sorted(used & set(missing_views))
            # Reads nothing that Hoover++ changes: both sides would be identical.
            unchanged = bool(used) and used <= set(config.get("shared") or ())
            tags = [t for t, rx in RISK_TAGS if rx.search(code)]
            if blocked:
                tags.append("awaiting_bcv")
            if unchanged:
                tags.append("unmigrated_only")
            why = header.get("in suite", "").replace(" ", "_")
            if why:
                tags.append(why)
            if blocked or unchanged:
                counts["disabled"] += 1
            if tags or notes.get("dropped_trailing") or blocked or unchanged:
                override = {"tags": tags} if tags else {}
                if blocked:
                    override["enabled"] = False
                    override["description"] = (
                        f"disabled: {config['actual']['label']} has no view for "
                        f"{', '.join(blocked)} yet"
                    )
                elif unchanged:
                    override["enabled"] = False
                    override["description"] = (
                        f"disabled: reads only {', '.join(sorted(used))}, which "
                        f"{config['actual']['label']} does not change, so both sides "
                        f"would run identical SQL"
                    )
                if notes.get("dropped_trailing") and not (blocked or unchanged):
                    override["description"] = (
                        f"{header.get('hoover', '')} | {header.get('kind', '')} | "
                        f"dropped for comparison: {notes['dropped_trailing'][:80]}"
                    )
                with open(os.path.join(case_dir, name[:-4] + ".yaml"), "w", encoding="utf-8") as fh:
                    yaml.safe_dump(override, fh, sort_keys=False)
            suite_name = suite_for(sorted(used), bool(blocked or unchanged),
                                   header.get("skeleton", ""), code)
            written.append({"case": f"{account}.{name[:-4]}", "file": relpath,
                            "tables": ",".join(notes.get("tables", [])), "tags": ",".join(tags),
                            "suite": suite_name})

    suite: Dict[str, Any] = {
        "suite": {
            "sql_dir": "sql",  # stated rather than defaulted: the folder this suite runs
            "expected_label": config["expected"]["label"],
            "actual_label": config["actual"]["label"],
            "expected": {"type": "trino", "vars": side_vars(config, "expected")},
            "actual": {"type": "trino", "vars": side_vars(config, "actual")},
            "compare": config["compare"],
            "tags": ["hoover"],
        },
        "vars": config["vars"],
    }
    with open(os.path.join(out, "rowparity.yaml"), "w", encoding="utf-8") as fh:
        fh.write("# Generated by scripts/build_hoover_suite.py -- edit tables.yaml and regenerate.\n")
        if config.get("shared"):
            fh.write(f"# Shared, not migrated: {', '.join(config['shared'])} -- both sides read "
                     f"the {config['expected']['label']} table.\n")
        yaml.safe_dump(suite, fh, sort_keys=False, width=200)
    for name, rows, fields in (
        ("excluded.csv", excluded, ["file", "account", "reason"]),
        ("cases.csv", written, ["case", "file", "tables", "tags", "suite"]),
    ):
        with open(os.path.join(out, name), "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)

    # One list per runnable suite. Disabled cases get none: --cases runs a
    # case even when it is disabled, and these would fail on a missing view.
    suites_dir = os.path.join(out, "suites")
    os.makedirs(suites_dir, exist_ok=True)
    for stale in os.listdir(suites_dir):
        if stale.endswith(".txt"):
            os.remove(os.path.join(suites_dir, stale))
    members: Dict[str, List[str]] = {}
    for row in written:
        members.setdefault(row["suite"], []).append(row["case"])
    for suite_name, cases in sorted(members.items()):
        counts[f"suite:{suite_name}"] = len(cases)
        if suite_name == "hoover_disabled":
            continue
        with open(os.path.join(suites_dir, suite_name + ".txt"), "w", encoding="utf-8") as fh:
            fh.write("".join(case + "\n" for case in sorted(cases)))

    # Which suites run on which weekday. Every suite runs once a week and no
    # suite shares a day with a rerun of itself, so a day's failures point at
    # the tables that day covered.
    plan, load = weekly_schedule(members)
    days = ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    with open(os.path.join(out, "schedule.yaml"), "w", encoding="utf-8") as fh:
        fh.write("# Generated by scripts/build_hoover_suite.py -- regenerate, do not edit.\n")
        fh.write("# Weekday -> the suites that run that day. 0 = Monday, matching\n")
        fh.write("# Python's date.weekday(), which is what the Airflow DAG asks for.\n#\n")
        for day in sorted(plan):
            listed = ", ".join(plan[day]) or "(nothing)"
            fh.write(f"#   {days[day]:<9} {load[day]:>3} cases  {listed}\n")
        fh.write(f"#   {'total':<9} {sum(load.values()):>3} cases\n")
        yaml.safe_dump({day: plan[day] for day in sorted(plan)}, fh, sort_keys=True)
    for day in sorted(plan):
        counts[f"weekday:{day}"] = load[day]

    # The run's batch ids, rendered from the run date by the same rules the
    # slice in rowparity.yaml expects. Generated together so they cannot drift.
    params_path = os.path.join(out, "batch_params.py")
    with open(params_path, "w", encoding="utf-8") as fh:
        fh.write(BATCH_PARAMS
                 .replace("__HH__", f"{config['batch_hour']:02d}")
                 .replace("__HOUR__", str(config["batch_hour"]))
                 .replace("__LOOKBACK__", str(config["batch_lookback"])))
    os.chmod(params_path, 0o755)
    return counts


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--corpus", required=True, help="vulcan-docs/sqls")
    parser.add_argument("--out", required=True, help="suite directory to write")
    parser.add_argument("--tables", help="YAML config of schemas, view names and slices")
    args = parser.parse_args(argv)

    config = dict(TABLES_TEMPLATE)
    if args.tables:
        with open(args.tables, encoding="utf-8") as fh:
            config.update(yaml.safe_load(fh) or {})

    counts = build(args.corpus, args.out, config)
    print(f"wrote {counts['written']} cases to {args.out}/sql/")
    print(f"  {counts['limit_dropped']} trailing LIMIT clauses dropped")
    print(f"  {counts['nested_limit_dropped']} files with nested LIMITs dropped")
    print(f"  {counts['time_bound']} files bound to ${{as_of_ts}} / ${{as_of_date}}")
    print(f"  {counts['repaired']} files had a hard-coded hoover table rewritten to its placeholder")
    print(f"  {counts['excluded']} excluded (see {args.out}/excluded.csv)")
    if counts["disabled"]:
        reasons = []
        if unavailable(config):
            reasons.append(f"no view yet for {', '.join(unavailable(config))}")
        if config.get("shared"):
            reasons.append(f"read only unmigrated tables ({', '.join(config['shared'])})")
        print(f"  {counts['disabled']} disabled: {'; '.join(reasons)}")
    print(f"suites in {args.out}/suites/:")
    for key in sorted(k for k in counts if k.startswith("suite:")):
        note = "  (no list: disabled)" if key == "suite:hoover_disabled" else ""
        print(f"  {counts[key]:4d}  {key[len('suite:'):]}{note}")
    if not args.tables:
        print("\nNOTE: using placeholder schemas "
              f"({config['expected']['schema']} / {config['actual']['schema']}). "
              "Pass --tables once the real names are known.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
