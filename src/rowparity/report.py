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
    return s if len(s) <= limit else s[: limit - 3] + "..."


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


def _fmt_delta(value: float) -> str:
    return f"{int(value):+d}" if value == int(value) else f"{value:+g}"


def _render_signature(sig: ChangeSignature, changed_count: int = 0) -> List[str]:
    cols = ", ".join(sig.columns) if sig.columns else "(none)"
    share = f"  [{sig.share_of(changed_count):.0%} of changed]" if changed_count else ""
    lines = [f"    {sig.count}x  {{{cols}}}{share}"]

    if sig.breakdown:
        parts = ", ".join(f"{k} {v}" for k, v in sig.breakdown.items())
        lines.append(f"        by group: {parts}")

    # Direction and magnitude, not just "these columns differ". A constant
    # delta across every row is a systematic loss and says so; a range is a
    # starting point. One example could never distinguish the two.
    for d in sig.deltas.values():
        constant = d.constant_delta
        if constant is not None:
            amount = f"{_fmt_delta(constant)} (constant)"
        elif d.numeric:
            lo, hi = _fmt_delta(d.min_delta), _fmt_delta(d.max_delta)
            # Ends that differ only below display precision -- true of most
            # float deltas with no tolerance set. Shown as a range it reads as
            # a broken report; "~" states what is known without overclaiming.
            amount = f"~{lo}" if lo == hi else f"{lo} to {hi}"
        elif d.top_pair is not None:
            amount = f"{_short(d.top_pair[0])} -> {_short(d.top_pair[1])} in {d.top_pair_count}"
        else:
            amount = ""
        moved = max(d.lower, d.higher) or d.became_null or d.was_null
        lines.append(f"        {d.column}: {d.direction} {moved}/{d.rows}  {amount}".rstrip())

    if sig.example is not None:
        pairs = ", ".join(
            f"{c.column}: {_short(c.expected)} -> {_short(c.actual)}" for c in sig.example.columns
        )
        lines.append(f"        most extreme: key={_fmt_key(sig.example.key)}: {pairs}")
    return lines


def _render_breakdown(result: ComparisonResult) -> List[str]:
    """Which group the differences are in, before anything about which column.

    Over a UNION of several branches this is the first useful question and the
    one nothing else answers: 149 missing rows spread evenly is a different
    problem from 149 concentrated in one branch.
    """
    name = ", ".join(result.breakdown_columns)
    lines = [f"  row differences by {name}:"]
    groups = sorted(
        result.breakdown.values(), key=lambda g: (-g.differing_share, -g.differences)
    )
    width = max((len(str(g.value)) for g in groups), default=1)
    for g in groups:
        lines.append(
            f"    {str(g.value):<{width}}  rows {g.expected_rows}/{g.actual_rows}  "
            f"missing={g.missing} added={g.added} changed={g.changed}  "
            f"differing={g.differing_share:.1%}"
        )
    return lines


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

    if result.total_seconds > 0:
        from .progress import format_duration

        lines.append(
            "  timing: expected {} | actual {} | compare {} | total {}".format(
                format_duration(result.expected_load_seconds),
                format_duration(result.actual_load_seconds),
                format_duration(result.compare_seconds),
                format_duration(result.total_seconds),
            )
        )

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

    if result.breakdown:
        lines.extend(_render_breakdown(result))

    if result.change_signatures:
        lines.append(
            f"  change signatures ({len(result.change_signatures)} distinct, "
            f"{result.changed_count} changed row(s) total):"
        )
        for sig in result.signatures_by_count():
            lines.extend(_render_signature(sig, result.changed_count))

    if result.examples:
        shown = len(result.examples)
        lines.append(f"  first {shown} difference(s):")
        for diff in result.examples:
            lines.append(_render_example(diff))
        if result.total_differences > shown:
            lines.append(f"  ... and {result.total_differences - shown} more")
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
    return {
        "columns": list(sig.columns),
        "count": sig.count,
        "example": example,
        "deltas": [
            {
                "column": d.column,
                "rows": d.rows,
                "direction": d.direction,
                "lower": d.lower,
                "higher": d.higher,
                "became_null": d.became_null,
                "was_null": d.was_null,
                "constant_delta": d.constant_delta,
                "min_delta": d.min_delta,
                "max_delta": d.max_delta,
            }
            for d in sig.deltas.values()
        ],
        "breakdown": {str(k): v for k, v in sig.breakdown.items()},
    }


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
        "breakdown_columns": list(result.breakdown_columns),
        "breakdown": [
            {
                "value": str(g.value),
                "expected_rows": g.expected_rows,
                "actual_rows": g.actual_rows,
                "missing": g.missing,
                "added": g.added,
                "changed": g.changed,
                "differing_share": g.differing_share,
            }
            for g in sorted(
                result.breakdown.values(),
                key=lambda g: (-g.differing_share, -g.differences),
            )
        ],
        # Kept split rather than totalled: a slow warehouse query and a slow
        # comparison need different fixes. Accumulated across runs by the
        # result sink, these answer how many cases fit in a window.
        # Microseconds, not milliseconds: rounding to 3 places turned a fast
        # step into 0.0, which is exactly how an unmeasured step is reported.
        # "instant" and "never ran" must not look alike.
        "timing_seconds": {
            "expected_load": round(result.expected_load_seconds, 6),
            "actual_load": round(result.actual_load_seconds, 6),
            "compare": round(result.compare_seconds, 6),
            "total": round(result.total_seconds, 6),
        },
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
    value_mismatch = set(result.column_value_mismatch)
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
            if column in value_mismatch:
                # Keyless: the column's value multiset differs between the two
                # sides. There is no per-row count to report -- without a key
                # rows cannot be paired -- but "this column's values differ" is
                # the fact that makes 262 columns triageable, and calling it
                # MATCHED beside a million row differences did not.
                status = STATUS_VALUE_DIFF
            elif total == 0:
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
    # Markdown first. These are independent artifacts, and writing JSON first
    # meant a failure there took the Markdown report down with it -- losing
    # both at once, on precisely the runs that had something to report.
    if md_path:
        with open(md_path, "w", encoding="utf-8") as fh:
            fh.write(render_markdown(results))
    if json_path:
        payload = [to_dict(r, name) for name, r in results]
        with open(json_path, "w", encoding="utf-8") as fh:
            # default=str: to_dict() embeds raw cell values from example rows,
            # so any Decimal, date, datetime or bytes in a failing case would
            # otherwise raise mid-write and leave a truncated, unparseable
            # file. result_sink.py already serialises rows this way.
            json.dump(payload, fh, indent=2, default=str)
