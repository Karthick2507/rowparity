"""Reads historical run data back out of a result sink, for `rowparity report`.

Complements result_sink.py (which writes): this reads the same
`<prefix>_run_summary` / `<prefix>_run_diffs` tables back out and reshapes
them into one entry per case, with one history point per calendar day (the
latest run that day, if there was more than one) plus change_signatures and
example diffs derived from the most recent run.

DuckDB is the primary, fully local, credential-free backend. Snowflake
follows the same query shape. Iceberg reading isn't wired up yet — see
CLAUDE.md's TODO section; IcebergResultSink is currently write-only.
"""
from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

READABLE_BACKENDS = {"duckdb", "snowflake"}


def _parse_spec(spec: str) -> Tuple[str, str]:
    if ":" not in spec:
        raise ValueError(f"--result-sink must be <backend>:<target>, got: {spec!r}")
    backend, target = spec.split(":", 1)
    return backend.lower().strip(), target


def _read_duckdb(target: str, summary_table: str, diffs_table: str, since: datetime):
    import duckdb

    con = duckdb.connect(target, read_only=True)
    try:
        cur = con.execute(f"SELECT * FROM {summary_table} WHERE run_ts >= ? ORDER BY run_ts", [since])
        summary_cols = [d[0] for d in cur.description]
        summary_rows = [dict(zip(summary_cols, r)) for r in cur.fetchall()]

        cur = con.execute(
            f"SELECT * FROM {diffs_table} WHERE run_id IN "
            f"(SELECT DISTINCT run_id FROM {summary_table} WHERE run_ts >= ?)",
            [since],
        )
        diffs_cols = [d[0] for d in cur.description]
        diffs_rows = [dict(zip(diffs_cols, r)) for r in cur.fetchall()]
    finally:
        con.close()
    return summary_rows, diffs_rows


def _read_snowflake(target: str, summary_table: str, diffs_table: str, since: datetime,
                     connection: Optional[dict] = None):
    from .snowflake_auth import connect as _sf_connect

    conn = dict(connection or {})
    if target and "." in target:
        db, sch = target.split(".", 1)
        conn.setdefault("database", db)
        conn.setdefault("schema", sch)

    con = _sf_connect({"connection": conn})
    try:
        cur = con.cursor()
        cur.execute(f"SELECT * FROM {summary_table} WHERE run_ts >= %s ORDER BY run_ts", [since])
        summary_cols = [d[0].lower() for d in cur.description]
        summary_rows = [dict(zip(summary_cols, r)) for r in cur.fetchall()]

        cur.execute(
            f"SELECT * FROM {diffs_table} WHERE run_id IN "
            f"(SELECT DISTINCT run_id FROM {summary_table} WHERE run_ts >= %s)",
            [since],
        )
        diffs_cols = [d[0].lower() for d in cur.description]
        diffs_rows = [dict(zip(diffs_cols, r)) for r in cur.fetchall()]
    finally:
        con.close()
    return summary_rows, diffs_rows


def read_raw_history(spec: str, table_prefix: str = "rowparity", days: int = 21):
    """Returns (summary_rows, diffs_rows) as lists of plain dicts, column names
    lower-cased, covering runs from the last `days` days."""
    backend, target = _parse_spec(spec)
    if backend not in READABLE_BACKENDS:
        raise ValueError(
            f"reading history from backend '{backend}' isn't supported yet "
            f"(supported: {sorted(READABLE_BACKENDS)})"
        )
    summary_table = f"{table_prefix}_run_summary"
    diffs_table = f"{table_prefix}_run_diffs"
    since = datetime.now(tz=timezone.utc) - timedelta(days=days)

    if backend == "duckdb":
        return _read_duckdb(target, summary_table, diffs_table, since)
    return _read_snowflake(target, summary_table, diffs_table, since)


def _parse_json_field(value, default):
    if value is None:
        return default
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return default


def _day_of(run_ts) -> str:
    # DuckDB/Snowflake drivers hand back TIMESTAMPTZ localized to the system
    # timezone, not UTC (same instant, different wall-clock date near
    # midnight) -- normalize to UTC before taking the date, or a run just
    # after UTC midnight can land on the wrong calendar day.
    if hasattr(run_ts, "astimezone"):
        return run_ts.astimezone(timezone.utc).date().isoformat()
    return str(run_ts)[:10]


def build_case_histories(summary_rows: List[dict], diffs_rows: List[dict]) -> List[Dict[str, Any]]:
    """Reshape raw sink rows into one entry per case: a day-by-day history,
    plus change_signatures and example diffs derived from the latest run."""
    by_case: Dict[str, List[dict]] = defaultdict(list)
    for row in summary_rows:
        by_case[row["case_name"]].append(row)

    diffs_by_run: Dict[str, List[dict]] = defaultdict(list)
    for d in diffs_rows:
        diffs_by_run[d["run_id"]].append(d)

    cases = []
    for case_name, rows in sorted(by_case.items()):
        by_day: Dict[str, dict] = {}
        for row in rows:
            day = _day_of(row["run_ts"])
            if day not in by_day or row["run_ts"] > by_day[day]["run_ts"]:
                by_day[day] = row

        history = []
        for day in sorted(by_day):
            row = by_day[day]
            only_exp = _parse_json_field(row.get("columns_only_in_expected"), [])
            only_act = _parse_json_field(row.get("columns_only_in_actual"), [])
            tm_raw = _parse_json_field(row.get("type_mismatches"), [])
            type_mismatches = [[t["column"], t["expected"], t["actual"]] for t in tm_raw]
            history.append({
                "date": day,
                "run_id": row["run_id"],
                "equivalent": bool(row["equivalent"]),
                "expected_rows": row["expected_rows"],
                "actual_rows": row["actual_rows"],
                "missing_count": row["missing_count"],
                "added_count": row["added_count"],
                "changed_count": row["changed_count"],
                "schema": {
                    "onlyExpected": only_exp,
                    "onlyActual": only_act,
                    "typeMismatches": type_mismatches,
                },
                "schema_drifted": bool(only_exp or only_act or type_mismatches),
            })

        latest_row = by_day[sorted(by_day)[-1]]
        latest_diffs = diffs_by_run.get(latest_row["run_id"], [])

        sig_map: Dict[Tuple[str, ...], dict] = {}
        diffs_out = []
        for d in latest_diffs:
            col_diffs = _parse_json_field(d.get("column_diffs"), [])
            key_parts = _parse_json_field(d.get("key_json"), None)
            key_str = ", ".join(str(p) for p in key_parts) if key_parts else ""
            if d["diff_kind"] == "changed" and col_diffs:
                cols = tuple(sorted(c["column"] for c in col_diffs))
                if cols not in sig_map:
                    detail = ", ".join(f"{c['column']}: {c['expected']} -> {c['actual']}" for c in col_diffs)
                    sig_map[cols] = {
                        "columns": list(cols),
                        "count": 0,
                        "example": f"key=({key_str}): {detail}",
                    }
                sig_map[cols]["count"] += 1
                for c in col_diffs:
                    diffs_out.append({
                        "key": f"({key_str})",
                        "column": c["column"], "oldv": c["expected"], "newv": c["actual"],
                    })
            # missing/added examples aren't column-level value diffs -- they're
            # already reflected in this day's missing_count/added_count on the
            # ledger row; the drill-down table here is specifically the
            # column-level "what changed" view.

        cases.append({
            "name": case_name,
            "tags": _parse_json_field(latest_row.get("tags"), []),
            "keys": _parse_json_field(latest_row.get("keys"), None),
            "history": history,
            "signatures": sorted(sig_map.values(), key=lambda s: -s["count"]),
            "diffs": diffs_out,
        })
    return cases