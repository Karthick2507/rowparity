"""``rowparity summarize``: one run of many tests, read back as a whole.

Each test in a scheduled run is its own task and publishes on its own. This is
the step that runs once at the end and sees all of them:

* **Totals and the worst failures**, with each failure's ready-made query.
* **Common causes across tests.** One ETL change usually breaks many queries
  the same way; "impressions is lower in Hoover++ by exactly 1 -- 212 tests" is
  one bug to fix, not 212 to triage. Findings are grouped by their sentence
  with the row counts taken out.
* **Tests that never reported.** Given the list of tests that were meant to run
  (``--expect``), a task that died before publishing shows up as NO RESULT
  instead of silently shrinking the run.
* **Presto upkeep** (``--presto``): register the new partitions of both shared
  tables, dropping expired ones, and create or refresh each test's typed view.

It writes ``_runs/<run_date>_<run_id>/summary.json`` next to the published tests
and exits non-zero if any test did not pass, so the scheduler's run turns red.
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from typing import Any, Callable, Dict, Iterable, List, Optional, Tuple

import pyarrow.fs as pafs

from . import presto_sql
from .findings import _ratio
from .html_report import render_run
from .publish import _filesystem, _uri, _write_bytes

FAILED_SHOWN = 20
CAUSES_SHOWN = 10


class SummarizeError(RuntimeError):
    pass


_PARTITION = re.compile(r"case_name=([^/]+)/run_date=([^/]+)/run_id=([^/]+)/")


def load_run(dest: str, run_id: str, run_date: Optional[str] = None) -> List[Dict[str, Any]]:
    """The result.json of every test that published under ``run_id``."""
    fs, root = _filesystem(dest)
    base = f"{root}/_tables/run_summary"
    try:
        infos = fs.get_file_info(pafs.FileSelector(base, recursive=True, allow_not_found=True))
    except OSError as exc:
        raise SummarizeError(f"could not list {dest}: {exc}") from exc

    records = []
    for info in infos:
        match = _PARTITION.search(info.path.replace("\\", "/") + "/")
        if not match or info.type != pafs.FileType.File:
            continue
        case, date, rid = match.groups()
        if rid != run_id or (run_date and date != run_date):
            continue
        path = f"{root}/runs/{case}/{date}_{rid}/result.json"
        try:
            with fs.open_input_stream(path) as fh:
                record = json.loads(fh.read().decode("utf-8"))
        except (OSError, ValueError) as exc:
            raise SummarizeError(f"could not read {path}: {exc}") from exc
        record["_published_as"] = case
        record["_run_date"] = date
        records.append(record)
    return sorted(records, key=lambda r: r["case"])


def cause_of(finding: Dict[str, Any]) -> str:
    """A finding's sentence with the parts that vary between tests removed."""
    title = finding["title"]
    title = re.sub(r" on [\d,]+ rows?$", "", title)
    title = re.sub(r"by -?[\d,.]+ to -?[\d,.]+", "by varying amounts", title)
    title = re.sub(r" \([^)]*\)$", "", title)
    stripped = re.sub(r"^[\d,]+ rows? ", "", title)
    if stripped != title:
        title = "Rows " + stripped
    return title


def common_causes(records: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Causes seen in two or more tests, most widespread first."""
    tests: Dict[str, set] = defaultdict(set)
    rows: Dict[str, int] = defaultdict(int)
    for record in records:
        for finding in record.get("findings") or []:
            cause = cause_of(finding)
            tests[cause].add(record["case"])
            rows[cause] += int(finding.get("rows") or 0)
    causes = [
        {"cause": c, "tests": sorted(t), "test_count": len(t), "rows": rows[c]}
        for c, t in tests.items()
        if len(t) > 1
    ]
    return sorted(causes, key=lambda c: (-c["test_count"], -c["rows"], c["cause"]))


def presto_statements(records: Iterable[Dict[str, Any]], tables: Optional[str] = None) -> List[str]:
    """Partition syncs for both tables, then every test's view."""
    tables = tables or presto_sql.tables_schema()
    if "." not in tables:
        raise SummarizeError(
            f"tables schema {tables!r} must be catalog.schema (e.g. hive.rowparity) so the "
            f"partition sync can name the catalog's system procedure"
        )
    catalog, schema = tables.split(".", 1)
    statements = [
        f"CALL {catalog}.system.sync_partition_metadata('{schema}', '{table}', 'FULL')"
        for table in ("diffs", "run_summary")
    ]
    for record in records:
        view_sql = (record.get("diffs") or {}).get("view_sql")
        if view_sql:
            statements.append(view_sql)
    return statements


def apply_presto(statements: List[str], connect: Optional[Callable[[], Any]] = None) -> None:
    if connect is None:
        from .trino_auth import connect as trino_connect

        def connect():
            return trino_connect({})

    try:
        con = connect()
    except Exception as exc:
        raise SummarizeError(f"could not connect to Presto: {exc}") from exc
    try:
        for statement in statements:
            try:
                cur = con.cursor()
                cur.execute(statement)
                cur.fetchall()  # the Trino client only finishes a statement once it is read
            except Exception as exc:
                head = statement.strip().splitlines()[0]
                raise SummarizeError(f"Presto rejected `{head}`: {exc}") from exc
    finally:
        try:
            con.close()
        except Exception:
            pass


def build_summary(
    records: List[Dict[str, Any]], run_id: str, expected: Optional[List[str]] = None
) -> Dict[str, Any]:
    names = {r["case"] for r in records}
    no_result = sorted(set(expected or []) - names)
    counts = defaultdict(int)
    for r in records:
        counts[r.get("status", "ERROR")] += 1

    def worst(r):
        order = {"ERROR": 0, "DIFFERENT": 1}
        return (order.get(r.get("status"), 2), -(r.get("diff_ratio") or 0.0), r["case"])

    failed = [r for r in records if not r.get("passed")]
    return {
        "run_id": run_id,
        "run_date": records[0]["_run_date"] if records else None,
        "tests": len(records) + len(no_result),
        "passed": sum(1 for r in records if r.get("passed")),
        "within_tolerance": counts["WITHIN_TOLERANCE"],
        "different": counts["DIFFERENT"],
        "errored": counts["ERROR"],
        "no_result": no_result,
        "passed_cases": sorted(r["case"] for r in records if r.get("passed")),
        "common_causes": common_causes(records),
        "failed": [
            {
                "case": r["case"],
                "status": r.get("status"),
                "diff_ratio": r.get("diff_ratio"),
                "top_finding": (r.get("findings") or [{}])[0].get("title"),
                "error": r.get("error"),
                "query": (r.get("diffs") or {}).get("query"),
            }
            for r in sorted(failed, key=worst)
        ],
    }


def render(summary: Dict[str, Any]) -> str:
    lines = [f"Run {summary['run_date'] or '?'}  run_id {summary['run_id']}"]
    head = f"{summary['tests']} tests | {summary['passed']} passed"
    if summary["within_tolerance"]:
        head += f" ({summary['within_tolerance']} within tolerance)"
    head += f" | {summary['different']} different | {summary['errored']} errored"
    if summary["no_result"]:
        head += f" | {len(summary['no_result'])} no result"
    lines.append(head)

    causes = summary["common_causes"]
    if causes:
        lines += ["", "Common causes across tests:"]
        for c in causes[:CAUSES_SHOWN]:
            lines.append(f"  {c['test_count']:>4} tests  {c['rows']:>9,} rows  {c['cause']}")
        if len(causes) > CAUSES_SHOWN:
            lines.append(f"  +{len(causes) - CAUSES_SHOWN} more (summary.json)")

    if summary["failed"] or summary["no_result"]:
        lines += ["", "Failed, worst first:"]
        width = max([len(f["case"]) for f in summary["failed"]] + [len(n) for n in summary["no_result"]])
        for f in summary["failed"][:FAILED_SHOWN]:
            ratio = _ratio(f["diff_ratio"]) if f["diff_ratio"] else ""
            detail = f["error"] if f["status"] == "ERROR" else (f["top_finding"] or "")
            lines.append(f"  {f['status']:<16} {ratio:>7}  {f['case']:<{width}}  {detail}")
            if f["query"]:
                lines.append(f"  {'':<16} {'':>7}  {'':<{width}}  Rows: {f['query']}")
        if len(summary["failed"]) > FAILED_SHOWN:
            lines.append(f"  +{len(summary['failed']) - FAILED_SHOWN} more (summary.json)")
        for name in summary["no_result"]:
            lines.append(f"  {'NO RESULT':<16} {'':>7}  {name:<{width}}  the task never published a result")
    return "\n".join(lines)


def summarize(
    dest: str,
    run_id: str,
    *,
    run_date: Optional[str] = None,
    expected: Optional[List[str]] = None,
    presto: bool = False,
    connect: Optional[Callable[[], Any]] = None,
) -> Tuple[Dict[str, Any], str, int]:
    """Returns (summary, console text, exit code)."""
    records = load_run(dest, run_id, run_date)
    if not records and not expected:
        raise SummarizeError(f"no published results for run_id {run_id} under {dest}")
    summary = build_summary(records, run_id, expected)
    text = render(summary)

    if presto:
        statements = presto_statements(records)
        apply_presto(statements, connect)
        text += (
            f"\n\nPresto: synced partitions of {presto_sql.tables_schema()}.diffs and .run_summary; "
            f"refreshed {len(statements) - 2} view(s) in {presto_sql.views_schema()}"
        )

    if summary["run_date"]:
        fs, root = _filesystem(dest)
        run_dir = f"_runs/{summary['run_date']}_{run_id}"
        try:
            _write_bytes(fs, f"{root}/{run_dir}/summary.json",
                         json.dumps(summary, indent=2, default=str).encode("utf-8"))
            _write_bytes(fs, f"{root}/{run_dir}/summary.txt", (text + "\n").encode("utf-8"))
            links = {
                r["case"]: f"../../runs/{r['_published_as']}/{r['_run_date']}_{run_id}/report.html"
                for r in records
            }
            _write_bytes(fs, f"{root}/{run_dir}/index.html",
                         render_run(summary, links.get).encode("utf-8"))
        except OSError as exc:
            raise SummarizeError(f"could not write the run summary: {exc}") from exc
        text += f"\nSummary: {_uri(dest, run_dir)}/index.html"

    failed = summary["failed"] or summary["no_result"]
    return summary, text, 1 if failed else 0

