"""``rowparity compare-runs``: the last N runs side by side, as totals.

``summarize`` looks at one run. This looks across runs: for each of the last N
it adds up how many rows were compared, how many each side returned and how
many did not match, so a trend (a fix landing, a regression starting) shows in
one table.

It reads only the published ``_tables/run_summary`` Parquet -- one small file
per test per run -- so it needs no Presto and re-runs no query.

* **Rows compared** per test is the larger of the two sides, the same base
  rowparity's mismatch ratio uses, so the percentages here match the reports.
* **Errored tests** have no counts; they are counted but add no rows.
* **--cases** narrows to a list of tests, e.g. one suite. The hoover schedule
  runs each suite once a week, so without it the last 7 runs are one week of
  different suites; with it they are 7 weeks of the same tests.

With ``--publish-html`` the page goes to ``_compare/<name>.html``, overwritten
each time, so a suite's comparison keeps one link.
"""
from __future__ import annotations

import csv
import io
import json
import os
from collections import defaultdict
from typing import Any, Dict, Iterable, List, Optional, Tuple

import pyarrow.fs as pafs
import pyarrow.parquet as pq

from .findings import _ratio
from .publish import _filesystem, _uri, _write_bytes
from .result_json import safe_name
from .summarize import _PARTITION

DEFAULT_LAST = 7

COLUMNS = ["status", "passed", "expected_rows", "actual_rows", "total_differences", "run_ts"]

CSV_FIELDS = [
    "run_date", "run_id", "tests", "passed", "errored", "rows_compared",
    "expected_rows", "actual_rows", "rows_mismatching", "mismatch_ratio",
]


class CompareRunsError(RuntimeError):
    pass


def _summary_files(fs: pafs.FileSystem, root: str, cases: Optional[Iterable[str]]) -> List[str]:
    """Every run_summary Parquet file, or only those of ``cases``."""
    base = f"{root}/_tables/run_summary"
    bases = [f"{base}/case_name={safe_name(c)}" for c in cases] if cases is not None else [base]
    files = []
    for directory in bases:
        try:
            infos = fs.get_file_info(pafs.FileSelector(directory, recursive=True, allow_not_found=True))
        except OSError as exc:
            raise CompareRunsError(f"could not list {directory}: {exc}") from exc
        files.extend(i.path for i in infos if i.type == pafs.FileType.File and i.path.endswith(".parquet"))
    return files


def load_rows(dest: str, cases: Optional[Iterable[str]] = None) -> List[Dict[str, Any]]:
    """One dict per test per run, with its partition values."""
    fs, root = _filesystem(dest)
    rows = []
    for path in _summary_files(fs, root, cases):
        match = _PARTITION.search(path.replace("\\", "/"))
        if not match:
            continue
        case, run_date, run_id = match.groups()
        try:
            with fs.open_input_file(path) as fh:
                table = pq.ParquetFile(fh).read(columns=COLUMNS)
        except (OSError, ValueError) as exc:
            raise CompareRunsError(f"could not read {path}: {exc}") from exc
        for row in table.to_pylist():
            row.update(case=case, run_date=run_date, run_id=run_id)
            rows.append(row)
    return rows


def totals(rows: Iterable[Dict[str, Any]]) -> Dict[str, Any]:
    """One run's totals. Rows compared is the larger side, test by test."""
    out = {"tests": 0, "passed": 0, "errored": 0, "rows_compared": 0,
           "expected_rows": 0, "actual_rows": 0, "rows_mismatching": 0}
    for row in rows:
        out["tests"] += 1
        out["passed"] += bool(row.get("passed"))
        exp, act = row.get("expected_rows"), row.get("actual_rows")
        if row.get("status") == "ERROR" or exp is None or act is None:
            out["errored"] += 1
            continue
        out["rows_compared"] += max(exp, act)
        out["expected_rows"] += exp
        out["actual_rows"] += act
        out["rows_mismatching"] += int(row.get("total_differences") or 0)
    compared = out["rows_compared"]
    out["mismatch_ratio"] = out["rows_mismatching"] / compared if compared else 0.0
    return out


def compare_runs(rows: Iterable[Dict[str, Any]], last: int = DEFAULT_LAST) -> List[Dict[str, Any]]:
    """The last ``last`` runs, oldest first, each with its totals."""
    if last < 1:
        raise CompareRunsError("--last must be at least 1")
    by_run: Dict[Tuple[str, str], List[Dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_run[(row["run_date"], row["run_id"])].append(row)

    def started(key):
        stamps = [r["run_ts"] for r in by_run[key] if r.get("run_ts") is not None]
        return (key[0], min(stamps).isoformat() if stamps else "", key[1])

    keys = sorted(by_run, key=started)[-last:]
    return [{"run_date": d, "run_id": rid, **totals(by_run[(d, rid)])} for d, rid in keys]


# Metric label, key, formatter. Labels take the suite's side names.
def _metrics(expected_label: str, actual_label: str):
    count = lambda v: f"{v:,}"  # noqa: E731
    return [
        ("tests", "tests", count),
        ("passed", "passed", count),
        ("errored", "errored", count),
        ("rows compared", "rows_compared", count),
        (f"{expected_label} rows", "expected_rows", count),
        (f"{actual_label} rows", "actual_rows", count),
        ("rows mismatching", "rows_mismatching", count),
        ("mismatch %", "mismatch_ratio", _ratio),
    ]


def render(runs: List[Dict[str, Any]], title: str, expected_label: str = "expected",
           actual_label: str = "actual") -> str:
    """The console table: one column per run, oldest on the left."""
    if not runs:
        return f"{title}\n  No published runs found."
    header = [""] + [r["run_date"] for r in runs]
    body = [[label] + [fmt(r[key]) for r in runs] for label, key, fmt in _metrics(expected_label, actual_label)]
    widths = [max(len(line[i]) for line in [header] + body) for i in range(len(header))]
    lines = [title, ""]
    for line in [header] + body:
        cells = [line[0].ljust(widths[0])] + [c.rjust(w) for c, w in zip(line[1:], widths[1:])]
        lines.append("  " + "   ".join(cells).rstrip())
    dates = [r["run_date"] for r in runs]
    if len(set(dates)) < len(dates):
        lines.append("\n  Some dates ran more than once; run ids: " + ", ".join(r["run_id"] for r in runs))
    return "\n".join(lines)


def to_csv(runs: List[Dict[str, Any]]) -> str:
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=CSV_FIELDS, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    writer.writerows(runs)
    return out.getvalue()


def side_labels(dest: str, rows: List[Dict[str, Any]]) -> Tuple[str, str]:
    """The suite's names for its two sides, from the newest test's result.json."""
    if not rows:
        return "expected", "actual"
    newest = max(rows, key=lambda r: (r["run_date"], r["run_id"], r["case"]))
    fs, root = _filesystem(dest)
    path = f"{root}/runs/{newest['case']}/{newest['run_date']}_{newest['run_id']}/result.json"
    try:
        with fs.open_input_stream(path) as fh:
            record = json.loads(fh.read().decode("utf-8"))
    except (OSError, ValueError):
        return "expected", "actual"
    return record.get("expected_label") or "expected", record.get("actual_label") or "actual"


def page_name(cases_file: Optional[str], last: int) -> str:
    """``hoover_ad`` for ``--cases suites/hoover_ad.txt``, else ``last_7_runs``."""
    if cases_file and cases_file != "-":
        return safe_name(os.path.splitext(os.path.basename(cases_file))[0])
    return f"last_{last}_runs"


def run(
    dest: str,
    last: int = DEFAULT_LAST,
    cases: Optional[List[str]] = None,
    cases_file: Optional[str] = None,
    publish_html: bool = False,
) -> Tuple[List[Dict[str, Any]], str, Optional[str]]:
    """Load, total and render; with ``publish_html`` also write the page.

    Returns the runs, the console text and the page's URI (or None).
    """
    rows = load_rows(dest, cases)
    runs = compare_runs(rows, last)
    kept = {(r["run_date"], r["run_id"]) for r in runs}
    labels = side_labels(dest, [r for r in rows if (r["run_date"], r["run_id"]) in kept])
    name = page_name(cases_file, last)
    scope = f"{name} ({len(cases):,} tests)" if cases is not None else "all tests"
    title = f"Last {len(runs)} of up to {last} runs: {scope}"
    text = render(runs, title, *labels)

    uri = None
    if publish_html and runs:
        from .html_report import render_compare

        fs, root = _filesystem(dest)
        relative = f"_compare/{name}.html"
        try:
            _write_bytes(fs, f"{root}/{relative}", render_compare(runs, title, *labels).encode("utf-8"))
        except OSError as exc:
            raise CompareRunsError(f"could not write {relative}: {exc}") from exc
        uri = _uri(dest, relative)
    return runs, text, uri
