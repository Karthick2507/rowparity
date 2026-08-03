"""Human-readable and machine-readable reporting.

``render_console`` is what a QA engineer reads in the pytest output when a case
fails: the headline counts plus a handful of concrete example rows showing
exactly what differs. ``render_markdown`` / ``to_dict`` produce the CI artifacts
(a diff report you can publish from Jenkins, and a JSON summary for dashboards).
"""
from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple

from .compare import ChangeSignature, ComparisonResult, RowDiff


def _short(value: Any, limit: int = 80) -> str:
    s = repr(value)
    return s if len(s) <= limit else s[: limit - 1] + "…"


def _fmt_key(key) -> str:
    if key is None:
        return ""
    # key elements are canonical tuples like ('i', 5) or ('t', 'abc'); show the payload.
    parts = []
    for el in key:
        parts.append(str(el[1]) if isinstance(el, tuple) and len(el) >= 2 else str(el))
    return "(" + ", ".join(parts) + ")"


def _render_example(diff: RowDiff) -> str:
    if diff.kind == "changed":
        cols = ", ".join(
            f"{c.column}: {_short(c.expected)} -> {_short(c.actual)}" for c in diff.columns
        )
        return f"  ~ CHANGED key={_fmt_key(diff.key)}: {cols}"
    if diff.kind == "missing":
        row = diff.expected_row
        tag = f"key={_fmt_key(diff.key)}" if diff.key else _short(row)
        return f"  - MISSING (in expected, absent from actual): {tag}"
    if diff.kind == "added":
        row = diff.actual_row
        tag = f"key={_fmt_key(diff.key)}" if diff.key else _short(row)
        return f"  + ADDED   (in actual, absent from expected): {tag}"
    return f"  ? {diff.kind}"


def _render_signature(sig: ChangeSignature) -> str:
    cols = ", ".join(sig.columns) if sig.columns else "(none)"
    detail = ""
    if sig.example is not None:
        pairs = ", ".join(
            f"{c.column}: {_short(c.expected)} -> {_short(c.actual)}" for c in sig.example.columns
        )
        detail = f" — e.g. key={_fmt_key(sig.example.key)}: {pairs}"
    return f"    {sig.count}x  {{{cols}}}{detail}"


def render_console(result: ComparisonResult, case_name: str = "") -> str:
    lines: List[str] = []
    title = f"Case '{case_name}'" if case_name else "Comparison"
    lines.append(f"{title}: {result.summary()}")

    if result.columns_only_in_expected:
        lines.append(f"  columns only in expected: {result.columns_only_in_expected}")
    if result.columns_only_in_actual:
        lines.append(f"  columns only in actual:   {result.columns_only_in_actual}")
    if result.type_mismatches:
        for col, et, at in result.type_mismatches:
            lines.append(f"  type differs: {col}: expected {et} vs actual {at}")
    if result.duplicate_keys_expected or result.duplicate_keys_actual:
        lines.append(
            f"  DUPLICATE KEYS: expected={result.duplicate_keys_expected} "
            f"actual={result.duplicate_keys_actual} (keys should be unique)"
        )

    if result.change_signatures:
        lines.append(
            f"  change signatures ({len(result.change_signatures)} distinct, "
            f"{result.changed_count} changed row(s) total):"
        )
        for sig in result.signatures_by_count():
            lines.append(_render_signature(sig))

    if result.examples:
        shown = len(result.examples)
        lines.append(f"  first {shown} difference(s):")
        for diff in result.examples:
            lines.append(_render_example(diff))
        if result.total_differences > shown:
            lines.append(f"  … and {result.total_differences - shown} more")
    return "\n".join(lines)


def _signature_to_dict(sig: ChangeSignature) -> Dict[str, Any]:
    example = None
    if sig.example is not None:
        example = {
            "key": _fmt_key(sig.example.key),
            "columns": [
                {"column": c.column, "expected": c.expected, "actual": c.actual}
                for c in sig.example.columns
            ],
        }
    return {"columns": list(sig.columns), "count": sig.count, "example": example}


def to_dict(result: ComparisonResult, case_name: str = "") -> Dict[str, Any]:
    return {
        "case": case_name,
        "equivalent": result.equivalent,
        "keys": result.keys,
        "expected_rows": result.expected_rows,
        "actual_rows": result.actual_rows,
        "missing": result.missing_count,
        "added": result.added_count,
        "changed": result.changed_count,
        "columns_only_in_expected": result.columns_only_in_expected,
        "columns_only_in_actual": result.columns_only_in_actual,
        "type_mismatches": [
            {"column": c, "expected": e, "actual": a} for c, e, a in result.type_mismatches
        ],
        "duplicate_keys_expected": result.duplicate_keys_expected,
        "duplicate_keys_actual": result.duplicate_keys_actual,
        "compared_columns": result.compared_columns,
        "change_signatures": [_signature_to_dict(s) for s in result.signatures_by_count()],
    }


def render_markdown(results: List[Tuple[str, ComparisonResult]]) -> str:
    lines = ["# Data QA report", ""]
    passed = sum(1 for _, r in results if r.equivalent)
    lines.append(f"**{passed}/{len(results)} cases equivalent**")
    lines.append("")
    lines.append("| Case | Result | Expected | Actual | Missing | Added | Changed |")
    lines.append("|------|--------|----------|--------|---------|-------|---------|")
    for name, r in results:
        status = "✅ equivalent" if r.equivalent else "❌ different"
        lines.append(
            f"| {name} | {status} | {r.expected_rows} | {r.actual_rows} "
            f"| {r.missing_count} | {r.added_count} | {r.changed_count} |"
        )
    lines.append("")
    for name, r in results:
        if not r.equivalent:
            lines.append(f"## ❌ {name}")
            lines.append("```")
            lines.append(render_console(r, name))
            lines.append("```")
            lines.append("")
    return "\n".join(lines)


def write_reports(results: List[Tuple[str, ComparisonResult]], *, json_path: str = None, md_path: str = None):
    if json_path:
        payload = [to_dict(r, name) for name, r in results]
        with open(json_path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
    if md_path:
        with open(md_path, "w", encoding="utf-8") as fh:
            fh.write(render_markdown(results))
