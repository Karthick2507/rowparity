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


# Schema drift on a wide table can run to hundreds of columns. Dumping the raw
# list produced a single 32,000-character line -- technically complete, wholly
# unreadable. The full set goes to the CSV report instead.
MAX_LISTED_COLUMNS = 20


def _render_column_list(label: str, columns: List[str]) -> str:
    shown = ", ".join(columns[:MAX_LISTED_COLUMNS])
    if len(columns) <= MAX_LISTED_COLUMNS:
        return f"  {label} ({len(columns)}): {shown}"
    return (
        f"  {label} ({len(columns)}, first {MAX_LISTED_COLUMNS} shown; "
        f"use --csv for the full list): {shown}, ..."
    )


def render_console(result: ComparisonResult, case_name: str = "") -> str:
    lines: List[str] = []
    title = f"Case '{case_name}'" if case_name else "Comparison"
    lines.append(f"{title}: {result.summary()}")

    if result.columns_only_in_expected:
        lines.append(_render_column_list("columns only in expected", result.columns_only_in_expected))
    if result.columns_only_in_actual:
        lines.append(_render_column_list("columns only in actual", result.columns_only_in_actual))
    if result.type_mismatches:
        for col, et, at in result.type_mismatches[:MAX_LISTED_COLUMNS]:
            lines.append(f"  type differs: {col}: expected {et} vs actual {at}")
        if len(result.type_mismatches) > MAX_LISTED_COLUMNS:
            lines.append(
                f"  ... and {len(result.type_mismatches) - MAX_LISTED_COLUMNS} more type mismatch(es)"
            )
    if result.duplicate_keys_expected or result.duplicate_keys_actual:
        lines.append(
            f"  DUPLICATE KEYS: expected={result.duplicate_keys_expected} "
            f"actual={result.duplicate_keys_actual} (keys should be unique)"
        )

    if result.equivalent_diff_columns:
        total = sum(result.equivalent_diff_columns.values())
        cols = sorted(result.equivalent_diff_columns)
        lines.append(
            f"  globally equivalent: {total} column-difference(s) across "
            f"{len(cols)} column(s) differ only in how absence is spelled "
            f"(null / 0 / [] / false). Reported, not excused -- these still count."
        )
        lines.append(_render_column_list("    columns", cols))

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


# --------------------------------------------------------------------------- #
# Per-column CSV
# --------------------------------------------------------------------------- #
# The headline lists (columns_only_in_expected and friends) are fine at a
# handful of columns and unreadable at 900 -- render_console dumps them as one
# enormous line. A row-per-column CSV is the shape that actually scales, and is
# sortable/filterable/diffable between runs.
#
# `status` deliberately reuses the vocabulary of the BCV analyser this replaced,
# so the values are the ones the team already reads:
#
#     MATCHED              present on both sides, same type, no value diffs
#     MATCHED - TYPE DIFF  present on both sides, types disagree
#     MATCHED - VALUE DIFF present on both sides, values differ (row cases)
#     DIFF                 present on one side only
#
# Column names use rowparity's own expected/actual vocabulary rather than BCV's
# src/bcv, because this ships for every case type, not just a migration.

CSV_FIELDS = ("case", "status", "column", "expected_type", "actual_type", "diff_rows")

STATUS_MATCHED = "MATCHED"
STATUS_TYPE_DIFF = "MATCHED - TYPE DIFF"
STATUS_VALUE_DIFF = "MATCHED - VALUE DIFF"
# Every difference in this column was only a different spelling of absence.
# Mirrors the BCV analyser's third validation state: MATCHED is its Y,
# EQUIVALENT its E, VALUE DIFF its N.
STATUS_EQUIVALENT = "MATCHED - EQUIVALENT"
STATUS_DIFF = "DIFF"


def _value_diff_counts(result: ComparisonResult) -> Dict[str, int]:
    """How many changed rows each column took part in.

    Derived from change_signatures, which the default engine computes over the
    full table. Push-down engines build them from the fetched examples only, so
    the counts there are a floor, not a total.
    """
    counts: Dict[str, int] = {}
    for sig in result.change_signatures.values():
        for column in sig.columns:
            counts[column] = counts.get(column, 0) + sig.count
    return counts


def to_column_rows(result: ComparisonResult, case_name: str = "") -> List[Dict[str, Any]]:
    """One row per column: what happened to it, and its type on each side."""
    type_mismatch = {c: (et, at) for c, et, at in result.type_mismatches}
    diff_counts = _value_diff_counts(result)
    equiv_counts = result.equivalent_diff_columns
    exp_schema, act_schema = result.expected_schema, result.actual_schema
    rows: List[Dict[str, Any]] = []

    # A type-mismatched column is normally in compared_columns too, but union
    # them rather than trusting that: a producer that reported a mismatch
    # without listing the column would otherwise drop it from the report
    # silently, which is the worst way to lose a real finding.
    both_sides = list(result.compared_columns)
    both_sides += [c for c in type_mismatch if c not in set(result.compared_columns)]

    for column in both_sides:
        if column in type_mismatch:
            status = STATUS_TYPE_DIFF
            expected_type, actual_type = type_mismatch[column]
        else:
            total = diff_counts.get(column, 0)
            equivalent = equiv_counts.get(column, 0)
            if total == 0:
                status = STATUS_MATCHED
            elif total <= equivalent:
                # Nothing left once the absence-spelling diffs are accounted for.
                status = STATUS_EQUIVALENT
            else:
                status = STATUS_VALUE_DIFF
            expected_type = exp_schema.get(column, "")
            actual_type = act_schema.get(column, "")
        rows.append({
            "case": case_name,
            "status": status,
            "column": column,
            "expected_type": expected_type,
            "actual_type": actual_type,
            "diff_rows": diff_counts.get(column, ""),
        })

    for column in result.columns_only_in_expected:
        rows.append({
            "case": case_name, "status": STATUS_DIFF, "column": column,
            "expected_type": exp_schema.get(column, ""), "actual_type": "", "diff_rows": "",
        })
    for column in result.columns_only_in_actual:
        rows.append({
            "case": case_name, "status": STATUS_DIFF, "column": column,
            "expected_type": "", "actual_type": act_schema.get(column, ""), "diff_rows": "",
        })
    return rows


def write_csv_reports(results: List[Tuple[str, ComparisonResult]], out_dir: str) -> List[str]:
    """Write one <case>.csv per case into ``out_dir``. Returns the paths written."""
    import csv
    import os
    import re

    os.makedirs(out_dir, exist_ok=True)
    written: List[str] = []
    for name, result in results:
        # Case names are author-supplied and end up as filenames.
        safe = re.sub(r"[^A-Za-z0-9._-]", "_", name) or "case"
        path = os.path.join(out_dir, f"{safe}.csv")
        with open(path, "w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(to_column_rows(result, name))
        written.append(path)
    return written


def write_reports(results: List[Tuple[str, ComparisonResult]], *, json_path: str = None, md_path: str = None):
    if json_path:
        payload = [to_dict(r, name) for name, r in results]
        with open(json_path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
    if md_path:
        with open(md_path, "w", encoding="utf-8") as fh:
            fh.write(render_markdown(results))
