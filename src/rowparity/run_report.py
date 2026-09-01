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
    # ASCII "..." rather than a single-character ellipsis: this text is embedded
    # in the page's JSON and travels wherever the report is forwarded. The
    # template declares utf-8, but a report that survives being emailed,
    # re-saved, or piped through a tool that re-encodes should not sprout
    # mojibake on the way.
    text = "NULL" if value is None else str(value)
    return text if len(text) <= MAX_VALUE_CHARS else text[: MAX_VALUE_CHARS - 3] + "..."


def _kind_label(kind: str, expected_label: str, actual_label: str) -> str:
    """Name the side, not the direction.

    "missing" is only unambiguous if you already know which side is the source
    of truth. "Missing in Hoover++" is the same fact with the ambiguity removed,
    and it matches the metric tiles at the top of the page.
    """
    return {
        "missing": f"Missing in {actual_label}",
        "added": f"Added in {actual_label}",
        "changed": "Changed",
    }.get(kind, kind)


def _row_summary(row: Optional[dict], groups: Sequence[dict]) -> List[Dict[str, Any]]:
    """A labelled digest of one row, driven by the case's row_summary config.

    Replaces dumping repr(row) truncated to 120 characters, which on a
    262-column row cut off after four columns -- all of them key columns the
    reader already had in the Key field. It managed to be both too long to read
    and too short to contain anything new.
    """
    if not row:
        return []
    out = []
    for group in groups:
        parts = []
        for column in group.get("columns", []):
            if column in row:
                parts.append(f"{column} {_short(row[column])}")
        if parts:
            out.append({"label": group.get("label", ""), "text": ", ".join(parts)})
    return out


def _all_columns(row: Optional[dict]) -> List[Dict[str, str]]:
    """Every column of the row, name = value, for the expander."""
    if not row:
        return []
    return [{"column": k, "value": _short(v)} for k, v in sorted(row.items())]


def _example_to_dict(diff, result, summary_groups: Sequence[dict]) -> Dict[str, Any]:
    row = diff.expected_row if diff.kind != "added" else diff.actual_row
    out: Dict[str, Any] = {
        "kind": diff.kind,
        "kind_label": _kind_label(diff.kind, result.expected_label, result.actual_label),
        "key": _fmt_key(diff.key),
        "summary": _row_summary(row, summary_groups),
        "all_columns": _all_columns(row),
    }
    # The engineers' drill-down starts from creative_id, so it is pulled out
    # rather than left somewhere in a list of 262.
    for name in ("sample_transaction_id", "request__transaction_id"):
        if row and name in row:
            out["transaction_id"] = _short(row[name])
            break
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
    return out


def _fmt_delta(value: float) -> str:
    """A delta as a human reads it: signed, and without float noise."""
    if value == int(value):
        return f"{int(value):+d}"
    return f"{value:+g}"


def _delta_to_dict(delta) -> Dict[str, Any]:
    constant = delta.constant_delta
    out: Dict[str, Any] = {
        "column": delta.column,
        "rows": delta.rows,
        "direction": delta.direction,
        "moved": max(delta.lower, delta.higher),
        "became_null": delta.became_null,
        "was_null": delta.was_null,
        "constant": constant is not None,
        # Pre-rendered so the template never has to decide how a number looks.
        "amount": "",
    }
    if constant is not None:
        out["amount"] = _fmt_delta(constant)
    elif delta.numeric:
        lo, hi = _fmt_delta(delta.min_delta), _fmt_delta(delta.max_delta)
        # "+0.07 to +0.07" is a range whose ends differ only below display
        # precision -- true of almost any float delta without a tolerance set.
        # Printing it as a range reads as a bug in the report; "~+0.07" says
        # what is actually known without claiming the exactness of "constant".
        out["amount"] = lo if lo == hi else f"{lo} to {hi}"
        out["approx"] = lo == hi
    elif delta.top_pair is not None:
        exp, act = delta.top_pair
        out["amount"] = f"{_short(exp)} -> {_short(act)}"
        out["pair_count"] = delta.top_pair_count
    return out


def _signature_to_dict(sig, changed_count: int) -> Dict[str, Any]:
    example = None
    if sig.example is not None:
        example = [
            {"column": c.column, "expected": _short(c.expected), "actual": _short(c.actual)}
            for c in sig.example.columns
        ]
    return {
        "columns": list(sig.columns),
        "count": sig.count,
        "example": example,
        # A signature covering 6 of 9 changed rows is the pattern to chase; the
        # same 6 out of 6,000 is noise, and the count alone cannot tell them
        # apart without the reader doing the arithmetic.
        "share": sig.share_of(changed_count),
        "deltas": [_delta_to_dict(d) for d in sig.deltas.values()],
        "breakdown": [{"value": _short(k), "count": v} for k, v in sig.breakdown.items()],
    }


# A high-cardinality breakdown column would render thousands of rows nobody
# reads. Show the worst, then say how much was left out rather than silently
# truncating.
MAX_BREAKDOWN_GROUPS = 20


def _breakdown_to_dict(result) -> Dict[str, Any]:
    groups = sorted(
        result.breakdown.values(),
        key=lambda g: (-g.differing_share, -g.differences),
    )
    shown = groups[:MAX_BREAKDOWN_GROUPS]
    hidden = groups[MAX_BREAKDOWN_GROUPS:]
    return {
        "columns": list(result.breakdown_columns),
        "groups": [
            {
                "value": _short(g.value),
                "expected_rows": g.expected_rows,
                "actual_rows": g.actual_rows,
                "missing": g.missing,
                "added": g.added,
                "changed": g.changed,
                "differences": g.differences,
                "share": g.differing_share,
            }
            for g in shown
        ],
        "hidden_groups": len(hidden),
        "hidden_differences": sum(g.differences for g in hidden),
    }


def _near_miss_to_dict(nm) -> Dict[str, Any]:
    return {
        "missing_rows": nm.missing_rows,
        "added_rows": nm.added_rows,
        "truncated": nm.truncated,
        "columns": [
            {
                "column": c.column,
                "pairs": c.pairs,
                "ambiguous": c.ambiguous_groups,
                "share": c.share_of(nm.missing_rows),
                "examples": [
                    {"expected": _short(e.expected_value), "actual": _short(e.actual_value)}
                    for e in c.examples
                ],
            }
            for c in nm.columns
        ],
    }


# A report is for reading. Past a few dozen values the IN-list stops informing
# and starts padding; the full list is in the SQL below it either way.
MAX_SHOWN_VALUES = 50


def _drilldown_to_dict(dd) -> Optional[Dict[str, Any]]:
    if dd is None:
        return None
    return {
        "column": dd.column,
        "id_column": dd.id_column,
        "values": [_short(v) for v in dd.values[:MAX_SHOWN_VALUES]],
        "value_count": len(dd.values),
        "complete": dd.complete,
        "rows_covered": dd.rows_covered,
        "sides": [{"label": s.label, "sql": s.sql} for s in dd.sides],
    }


def case_to_dict(name: str, result: ComparisonResult) -> Dict[str, Any]:
    columns = to_column_rows(result, name)
    key_set = set(result.keys or ())
    summary_groups = getattr(result, "row_summary", None) or []
    counts: Dict[str, int] = {}
    for row in columns:
        counts[row["status"]] = counts.get(row["status"], 0) + 1

    return {
        "case": name,
        "status": "EQUIVALENT" if result.equivalent else "DIFFERENT",
        "kind": result.kind,
        "keys": list(result.keys) if result.keys else None,
        "expected_label": result.expected_label,
        "actual_label": result.actual_label,
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
                # Dimensions are the key, metrics are everything else. They
                # answer different questions -- "is the key sound?" versus "do
                # the numbers agree?" -- and merging them under one shared
                # "diff rows" column is what made 262 flagged columns
                # unreadable. Keyless cases have no key, so everything is a
                # metric and the split collapses to today's single table.
                "kind": "dimension" if row["column"] in key_set else "metric",
            }
            for row in columns
        ],
        "change_signatures": [
            _signature_to_dict(s, result.changed_count) for s in result.signatures_by_count()
        ],
        "breakdown": _breakdown_to_dict(result) if result.breakdown else None,
        "near_miss": _near_miss_to_dict(result.near_miss)
        if getattr(result, "near_miss", None) and result.near_miss.columns
        else None,
        "examples": [
            _example_to_dict(d, result, summary_groups) for d in result.examples
        ],
        "drilldown": _drilldown_to_dict(getattr(result, "drilldown", None)),
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
