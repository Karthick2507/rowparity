"""Single-run HTML report (``rowparity run --html``).

Distinct from report_html.py, which renders *history* out of a result sink --
pass-rate trends and sparklines across many runs. This renders one run: what
these two sources looked like just now, column by column and row by row.

Same approach as the history report: a static template shipped with the package
plus placeholder substitution, no templating engine.

Two things this carries that the CSV and JSON reports do not:

* **Errored cases.** A case that raises never produces a ComparisonResult, so
  it never reaches ``results`` and is invisible to every other reporter -- the
  CSV for a run where the only case blew up is an empty file with a header. A
  report that silently omits the failure is worse than no report, so errors are
  collected separately and rendered as first-class rows.
* **The keyless caveat.** Without a key, ``MATCHED`` is a statement about
  presence and type, not values -- there is no way to pair rows and so no
  per-row attribution exists. Shown next to a million row differences and
  unlabelled, that reads as "the columns are fine". The report says which mode
  produced it.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence, Tuple

from .compare import ComparisonResult
from .progress import format_duration
from .report import _fmt_key, to_column_rows

_TEMPLATE_PATH = os.path.join(os.path.dirname(__file__), "templates", "run_report.html")

# Example rows carry raw cell values from the compared tables. A 900-column row
# rendered in full would dominate the page and tell nobody anything.
MAX_VALUE_CHARS = 120


def _short(value: Any) -> str:
    text = "NULL" if value is None else str(value)
    return text if len(text) <= MAX_VALUE_CHARS else text[: MAX_VALUE_CHARS - 1] + "…"


def _example_to_dict(diff) -> Dict[str, Any]:
    out: Dict[str, Any] = {"kind": diff.kind, "key": _fmt_key(diff.key)}
    if diff.kind == "changed":
        out["columns"] = [
            {
                "column": c.column,
                "expected": _short(c.expected),
                "actual": _short(c.actual),
                "equivalent": bool(c.equivalent),
            }
            for c in diff.columns
        ]
    else:
        row = diff.expected_row if diff.kind == "missing" else diff.actual_row
        out["row"] = _short(row)
    return out


def _signature_to_dict(sig) -> Dict[str, Any]:
    example = None
    if sig.example is not None:
        example = [
            {"column": c.column, "expected": _short(c.expected), "actual": _short(c.actual)}
            for c in sig.example.columns
        ]
    return {"columns": list(sig.columns), "count": sig.count, "example": example}


def case_to_dict(name: str, result: ComparisonResult) -> Dict[str, Any]:
    columns = to_column_rows(result, name)
    counts: Dict[str, int] = {}
    for row in columns:
        counts[row["status"]] = counts.get(row["status"], 0) + 1

    return {
        "case": name,
        "status": "EQUIVALENT" if result.equivalent else "DIFFERENT",
        "kind": result.kind,
        "keys": list(result.keys) if result.keys else None,
        "expected_rows": result.expected_rows,
        "actual_rows": result.actual_rows,
        "missing": result.missing_count,
        "added": result.added_count,
        "changed": result.changed_count,
        "duplicate_keys_expected": result.duplicate_keys_expected,
        "duplicate_keys_actual": result.duplicate_keys_actual,
        "timing": {
            "expected": result.expected_load_seconds,
            "actual": result.actual_load_seconds,
            "compare": result.compare_seconds,
            "total": result.total_seconds,
            "expected_text": format_duration(result.expected_load_seconds),
            "actual_text": format_duration(result.actual_load_seconds),
            "compare_text": format_duration(result.compare_seconds),
            "total_text": format_duration(result.total_seconds),
        },
        "column_counts": counts,
        "columns": [
            {
                "column": row["column"],
                "status": row["status"],
                "expected_type": row["expected_type"],
                "actual_type": row["actual_type"],
                "diff_rows": row["diff_rows"],
            }
            for row in columns
        ],
        "change_signatures": [_signature_to_dict(s) for s in result.signatures_by_count()],
        "examples": [_example_to_dict(d) for d in result.examples],
    }


def error_to_dict(name: str, exc: BaseException) -> Dict[str, Any]:
    return {
        "case": name,
        "status": "ERROR",
        "error_type": type(exc).__name__,
        "error": str(exc),
    }


def build_payload(
    results: Sequence[Tuple[str, ComparisonResult]],
    errors: Optional[Sequence[Tuple[str, BaseException]]] = None,
    *,
    run_id: str = "",
    generated_at: Optional[datetime] = None,
) -> Dict[str, Any]:
    generated_at = generated_at or datetime.now(tz=timezone.utc)
    cases: List[Dict[str, Any]] = [case_to_dict(n, r) for n, r in results]
    # Errors last: a reader scanning the page should meet real comparisons
    # first, but must not be able to miss that something did not run.
    cases += [error_to_dict(n, e) for n, e in (errors or [])]

    equivalent = sum(1 for c in cases if c["status"] == "EQUIVALENT")
    different = sum(1 for c in cases if c["status"] == "DIFFERENT")
    errored = sum(1 for c in cases if c["status"] == "ERROR")
    total_seconds = sum(c.get("timing", {}).get("total", 0.0) for c in cases)

    return {
        "generated_at": generated_at.strftime("%Y-%m-%d %H:%M UTC"),
        "run_id": run_id,
        "summary": {
            "total": len(cases),
            "equivalent": equivalent,
            "different": different,
            "errored": errored,
            "total_seconds": total_seconds,
            "total_text": format_duration(total_seconds),
        },
        "cases": cases,
    }


def render_run_report(
    results: Sequence[Tuple[str, ComparisonResult]],
    errors: Optional[Sequence[Tuple[str, BaseException]]] = None,
    *,
    run_id: str = "",
    generated_at: Optional[datetime] = None,
) -> str:
    with open(_TEMPLATE_PATH, "r", encoding="utf-8") as fh:
        template = fh.read()

    payload = build_payload(results, errors, run_id=run_id, generated_at=generated_at)
    # Cell values are arbitrary strings from the compared tables and could
    # legitimately contain "</script>". Escaping it stops a value breaking out
    # of the inline <script> block -- standard JSON-in-<script> practice, and
    # here the values are genuinely untrusted warehouse content.
    # default=str: example rows carry raw cells, so Decimal/date/datetime/bytes
    # would otherwise raise mid-serialisation on exactly the failing runs.
    payload_json = json.dumps(payload, default=str).replace("</script", "<\\/script")

    html = template.replace("__ROWPARITY_RUN_JSON__", payload_json)
    html = html.replace("__ROWPARITY_GENERATED_AT__", payload["generated_at"])
    return html


def write_run_report(
    path: str,
    results: Sequence[Tuple[str, ComparisonResult]],
    errors: Optional[Sequence[Tuple[str, BaseException]]] = None,
    *,
    run_id: str = "",
) -> str:
    html = render_run_report(results, errors, run_id=run_id)
    parent = os.path.dirname(os.path.abspath(path))
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(html)
    return path
