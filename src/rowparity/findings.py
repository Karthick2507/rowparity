"""Turn a comparison into a short, ranked list of things a data engineer can act on.

The detailed console output (report.render_console) is complete and hard to
read: near misses, a breakdown table, change signatures and fifty example rows
are separate sections, and the reader has to join them to answer the only
questions that matter -- what is wrong, where, and what to look at next.

A *finding* is one answer to those questions, stated in a sentence, with the
evidence underneath. Everything here is derived from data the comparison has
already computed; no query is run.

Ranking:

* **Blockers first**, whatever their size. Duplicate keys mean only the first
  row per key was compared, so every count below them is suspect.
* **Then by rows affected.** A "moved" row counts once, not once as missing and
  once as added, and is taken out of the "only on one side" findings so no row
  is reported twice.

``build_findings`` produces plain dicts so the same list can be written to
result.json and rendered again later by ``render_case`` without the original
ComparisonResult.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import asdict, dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

from .compare import ColumnDelta, ComparisonResult
from .near_miss import _unwrap
from .progress import format_duration

# A near miss becomes a finding once it explains this share of missing rows.
NEAR_MISS_MIN_SHARE = 0.05
# Difference findings shown before the rest are folded into one line.
MAX_FINDINGS_SHOWN = 5
# Below this many rows a consistent shift is a coincidence, not a pattern.
MIN_ROWS_FOR_PATTERN = 10
MAX_KEY_COLUMNS_SHOWN = 6
MAX_DETAIL_COLUMNS = 5
MAX_VALUE_CHARS = 60

BLOCKER = "blocker"
DIFFERENCE = "difference"


@dataclass
class Finding:
    kind: str  # duplicate_keys | strict_columns | moved | changed | only_expected | only_actual
    severity: str  # blocker | difference
    title: str
    rows: int = 0
    details: List[str] = field(default_factory=list)
    likely: Optional[str] = None  # what the evidence suggests
    next_step: Optional[str] = None  # what to do about it
    columns: List[str] = field(default_factory=list)


# --------------------------------------------------------------------------- #
# Formatting helpers (ASCII only: this ends up in Jenkins and Airflow logs)
# --------------------------------------------------------------------------- #
def _value(value: Any) -> str:
    if value is None:
        return "NULL"
    text = f"'{value}'" if isinstance(value, str) else str(value)
    return text if len(text) <= MAX_VALUE_CHARS else text[: MAX_VALUE_CHARS - 3] + "..."


def _num(value: float) -> str:
    return f"{int(value):,}" if value == int(value) else f"{value:,.6g}"


def _rows(n: int) -> str:
    return f"{n:,} row" if n == 1 else f"{n:,} rows"


def _ratio(ratio: float) -> str:
    """Precise enough to compare against a limit like 0.010%."""
    return f"{ratio:.1%}" if ratio >= 0.01 else f"{ratio:.3%}"


def _pct(ratio: float) -> str:
    """Two significant figures below 10%: 100%, 17%, 4.4%, 0.62%, 0.0059%."""
    percent = ratio * 100
    return f"{percent:.0f}%" if percent >= 10 else f"{percent:.2g}%"


def _column_list(columns: Sequence[str], limit: int = 3) -> str:
    shown = ", ".join(columns[:limit])
    return shown if len(columns) <= limit else f"{shown} +{len(columns) - limit} more"


def _key_text(result: ComparisonResult, key: Optional[Tuple], row: Optional[dict] = None) -> str:
    """One readable line identifying a row.

    A key of 83 dimensions is not readable, so a configured row_summary wins;
    otherwise the first few key columns, named. Breakdown columns are left out:
    the finding has already said which group the rows are in.
    """
    if row is None and key is not None and result.keys:
        # No example row was kept for this key; the key columns still are one.
        row = {c: _unwrap(v) for c, v in zip(result.keys, key)}
    skip = set(result.breakdown_columns)
    if row and result.row_summary:
        parts = []
        for group in result.row_summary:
            values = [
                f"{c}={_value(row[c])}"
                for c in group.get("columns", [])
                if c in row and c not in skip
            ]
            if values:
                parts.append(", ".join(values))
        if parts:
            return " | ".join(parts[:3])
    if row and result.keys:
        pairs = [f"{c}={_value(row.get(c))}" for c in result.keys if c not in skip]
        extra = len(pairs) - MAX_KEY_COLUMNS_SHOWN
        text = ", ".join(pairs[:MAX_KEY_COLUMNS_SHOWN])
        return text + (f", +{extra} more key columns" if extra > 0 else "")
    if row:
        pairs = [f"{c}={_value(v)}" for c, v in sorted(row.items())]
        more = ", ..." if len(pairs) > MAX_KEY_COLUMNS_SHOWN else ""
        return ", ".join(pairs[:MAX_KEY_COLUMNS_SHOWN]) + more
    return ""


# --------------------------------------------------------------------------- #
# "Where": concentration across the breakdown_by column
# --------------------------------------------------------------------------- #
def _group_of_key(result: ComparisonResult, key: Tuple) -> Optional[str]:
    if not result.breakdown_columns or not result.keys:
        return None
    values = [_unwrap(key[result.keys.index(c)]) for c in result.breakdown_columns]
    return str(values[0]) if len(values) == 1 else str(tuple(values))


def _where(result: ComparisonResult, groups: Counter) -> Optional[str]:
    """Where a finding's rows sit, as a share of their group when it is known."""
    if not result.breakdown_columns or not groups:
        return None
    name = ", ".join(result.breakdown_columns)
    total = sum(groups.values())
    sizes = {
        str(g.value): max(g.expected_rows, g.actual_rows) for g in result.breakdown.values()
    }

    def share(value: str, n: int) -> str:
        size = sizes.get(value)
        return f" ({_pct(n / size)} of that group)" if size else ""

    ranked = groups.most_common()
    value, n = ranked[0]
    if len(ranked) == 1:
        return f"All in {name}={value}{share(value, n)}"
    if n / total >= 0.8:
        return f"Mostly in {name}={value}: {n:,} of {total:,}{share(value, n)}"
    parts = ", ".join(f"{v} {c:,}" for v, c in ranked[:3])
    more = f", +{len(ranked) - 3} more" if len(ranked) > 3 else ""
    return f"Spread across {name}: {parts}{more}"


def _groups(result: ComparisonResult, keys: Iterable[Tuple]) -> Counter:
    counter: Counter = Counter()
    for key in keys:
        group = _group_of_key(result, key)
        if group is not None:
            counter[group] += 1
    return counter


# --------------------------------------------------------------------------- #
# Individual findings
# --------------------------------------------------------------------------- #
def _blockers(result: ComparisonResult) -> List[Finding]:
    out = []
    exp, act = result.expected_label, result.actual_label
    if result.duplicate_keys_expected or result.duplicate_keys_actual:
        out.append(
            Finding(
                kind="duplicate_keys",
                severity=BLOCKER,
                title=(
                    f"Key is not unique: {result.duplicate_keys_expected:,} duplicate key(s) in "
                    f"{exp}, {result.duplicate_keys_actual:,} in {act}"
                ),
                rows=result.duplicate_keys_expected + result.duplicate_keys_actual,
                details=[
                    "Only the first row per key was compared, so the other findings are "
                    "not reliable until this is fixed."
                ],
                next_step="Add the missing dimension to compare.keys, or check the query's GROUP BY.",
            )
        )
    if result.strict_column_failure:
        details = []
        if result.columns_only_in_expected:
            details.append(f"Only in {exp}: {_column_list(result.columns_only_in_expected, 8)}")
        if result.columns_only_in_actual:
            details.append(f"Only in {act}: {_column_list(result.columns_only_in_actual, 8)}")
        for col, et, at in result.type_mismatches[:MAX_DETAIL_COLUMNS]:
            details.append(f"{col}: {et} in {exp}, {at} in {act}")
        out.append(
            Finding(
                kind="strict_columns",
                severity=BLOCKER,
                title="Columns or column types differ, and strict_columns is on",
                details=details,
                next_step="Align the two SELECT lists, or drop strict_columns if this is expected.",
            )
        )
    return out


def _moved(result: ComparisonResult) -> Tuple[List[Finding], set, set]:
    """Near misses that explain enough missing rows to be worth a finding.

    Returns the findings plus the missing and added keys they account for, so
    the "only on one side" findings can leave those rows out.
    """
    nm = result.near_miss
    if nm is None or not nm.columns or not nm.missing_rows:
        return [], set(), set()

    findings, used_missing, used_added = [], set(), set()
    for col in nm.columns:
        if col.pairs == 0 or col.pairs / nm.missing_rows < NEAR_MISS_MIN_SHARE:
            continue
        pairs = [(m, a) for m, a in col.paired_keys if m not in used_missing and a not in used_added]
        if not pairs:
            continue
        used_missing.update(m for m, _ in pairs)
        used_added.update(a for _, a in pairs)

        position = result.keys.index(col.column)
        samples = []
        for m, a in pairs[:3]:
            samples.append(f"{_value(_unwrap(m[position]))} -> {_value(_unwrap(a[position]))}")
        details = [f"e.g. {col.column} " + ", ".join(samples)]
        where = _where(result, _groups(result, (m for m, _ in pairs)))
        if where:
            details.append(where)
        details.append("Each is 1 missing + 1 added row with every other key column equal.")
        if col.ambiguous_groups:
            details.append(
                f"{col.ambiguous_groups:,} more missing row(s) match several added rows and "
                f"were left unpaired."
            )
        if nm.truncated:
            details.append("Analysis was capped; the real number may be higher.")
        finding = Finding(
            kind="moved",
            severity=DIFFERENCE,
            title=f"{_rows(len(pairs))} moved, not lost: {col.column} differs between sides",
            rows=len(pairs),
            details=details,
            likely=f"The same rows, keyed differently: {col.column} is derived differently.",
            next_step=f"Compare the {col.column} expression in the two queries.",
            columns=[col.column],
        )
        finding._pairs = pairs  # (missing key, added key); not serialised
        findings.append(finding)
    return findings, used_missing, used_added


def _describe_delta(d: ColumnDelta, exp: str, act: str) -> str:
    constant = d.constant_delta
    if d.became_null == d.rows:
        return f"{d.column} is NULL in {act} but set in {exp}"
    if d.was_null == d.rows:
        return f"{d.column} is set in {act} but NULL in {exp}"
    if constant is not None and d.rows > 1:
        return f"{d.column} is {d.direction} in {act} by exactly {_num(abs(constant))}"
    if constant is not None:
        return f"{d.column} is {d.direction} in {act} by {_num(abs(constant))}"
    if d.numeric and d.direction in ("lower", "higher"):
        lo, hi = sorted((abs(d.min_delta), abs(d.max_delta)))
        return f"{d.column} is {d.direction} in {act}, by {_num(lo)} to {_num(hi)}"
    if d.numeric and d.direction == "mixed":
        return (
            f"{d.column} moves both ways ({d.lower:,} lower, {d.higher:,} higher in {act}; "
            f"{_num(d.min_delta)} to {_num(d.max_delta)})"
        )
    if d.top_pair is not None:
        return f"{d.column} changes, e.g. {_value(d.top_pair[0])} -> {_value(d.top_pair[1])}"
    return f"{d.column} differs"


def _null_note(d: ColumnDelta, act: str) -> Optional[str]:
    if d.became_null and d.became_null != d.rows:
        return f"{d.column} is NULL in {act} on {d.became_null:,} of these rows"
    if d.was_null and d.was_null != d.rows:
        return f"{d.column} is only set in {act} on {d.was_null:,} of these rows"
    return None


def _signature_hint(deltas: Sequence[ColumnDelta], act: str, rows: int) -> Optional[str]:
    if rows < MIN_ROWS_FOR_PATTERN:
        return None
    if deltas and all(d.became_null == d.rows for d in deltas):
        return f"Values disappear in {act}: check joins and COALESCE on that side."
    numeric = [d for d in deltas if d.numeric]
    if numeric and len(numeric) == len(deltas):
        constant = all(d.constant_delta is not None for d in numeric)
        directions = {d.direction for d in numeric}
        if constant and len(directions) == 1:
            return (
                "One systematic cause (a filter, join or dedupe): every row shifts by the "
                "same amount."
            )
        if len(directions) == 1 and directions <= {"lower", "higher"}:
            return (
                f"Contributing events dropped or double counted: always "
                f"{directions.pop()} in {act}, by varying amounts."
            )
    return None


def _changed(result: ComparisonResult) -> List[Finding]:
    exp, act = result.expected_label, result.actual_label
    findings = []
    for sig in result.signatures_by_count():
        deltas = [sig.deltas[c] for c in sig.columns if c in sig.deltas]
        if len(sig.columns) == 1 and deltas:
            title = f"{_describe_delta(deltas[0], exp, act)} on {_rows(sig.count)}"
            details = [n for n in (_null_note(deltas[0], act),) if n]
        else:
            title = (
                f"{_rows(sig.count)} differ in {len(sig.columns)} columns together: "
                f"{_column_list(list(sig.columns))}"
            )
            details = [_describe_delta(d, exp, act) for d in deltas[:MAX_DETAIL_COLUMNS]]
            if len(deltas) > MAX_DETAIL_COLUMNS:
                details.append(f"+{len(deltas) - MAX_DETAIL_COLUMNS} more columns")

        if sig.breakdown:
            where = _where(result, Counter({str(k): v for k, v in sig.breakdown.items()}))
            if where:
                details.append(where)
        if sig.example is not None:
            pairs = ", ".join(
                f"{c.column} {_value(c.expected)} -> {_value(c.actual)}"
                for c in sig.example.columns[:3]
            )
            details.append(f"e.g. {pairs}")
            details.append(f"     at {_key_text(result, sig.example.key, sig.example.expected_row)}")

        findings.append(
            Finding(
                kind="changed",
                severity=DIFFERENCE,
                title=title,
                rows=sig.count,
                details=details,
                likely=_signature_hint(deltas, act, sig.count),
                next_step=(
                    f"Query that row on both sides and compare how "
                    f"{_column_list(list(sig.columns), 2)} "
                    f"{'is' if len(sig.columns) == 1 else 'are'} computed."
                    if sig.example is not None
                    else None
                ),
                columns=list(sig.columns),
            )
        )
    return findings


def _example_row(result: ComparisonResult, kind: str, keys: set) -> Tuple[Optional[Tuple], Optional[dict]]:
    for diff in result.examples:
        if diff.kind != kind:
            continue
        if keys and diff.key not in keys:
            continue
        return diff.key, diff.expected_row if kind == "missing" else diff.actual_row
    return (next(iter(keys)) if keys else None), None


def _only_one_side(result: ComparisonResult, moved_missing: set, moved_added: set) -> List[Finding]:
    exp, act = result.expected_label, result.actual_label
    out = []
    sides = (
        ("missing", "only_expected", result.missing_keys, moved_missing, result.missing_count,
         f"in {exp} are missing from {act}",
         f"{act} drops them: a stricter filter, or an inner join that finds no match."),
        ("added", "only_actual", result.added_keys, moved_added, result.added_count,
         f"in {act} are not in {exp}",
         f"{act} produces extra rows: a looser filter, or a join that fans out."),
    )
    for kind, finding_kind, all_keys, moved, raw_count, phrase, likely in sides:
        if result.keys:
            keys = {k for k in all_keys if k not in moved}
            # Duplicate keys make rows outnumber keys; count rows when nothing moved.
            count = raw_count if not moved else len(keys)
        else:
            keys, count = set(), raw_count
        if not count:
            continue

        details = []
        where = _where(result, _groups(result, keys)) if keys else None
        if where:
            details.append(where)
        key, row = _example_row(result, kind, keys)
        example = _key_text(result, key, row)
        if example:
            details.append(f"e.g. {example}")
        if moved:
            details.append(f"Excludes the {len(moved):,} moved row(s) reported separately.")
        if not result.keys and result.column_value_mismatch:
            details.append(
                f"Columns whose values differ: {_column_list(result.column_value_mismatch, 8)}"
            )

        dd = result.drilldown
        if dd is not None and kind in (dd.kinds or []):
            covers = f"all {dd.kind_rows.get(kind, count):,} {kind} rows"
            if moved:
                covers += ", moved ones included"
            next_step = (
                f"Run the drill-down SQL in result.json to list the {dd.id_column} values "
                f"behind them (it covers {covers})."
            )
        elif dd is not None:
            next_step = f"Add '{kind}' to drilldown.kinds to get the transactions behind them."
        elif result.keys:
            next_step = "Configure a drilldown: block to get the transactions behind them."
        else:
            next_step = "Add compare.keys to see which values changed rather than whole rows."
        if count < MIN_ROWS_FOR_PATTERN:
            likely = None

        out.append(
            Finding(
                kind=finding_kind,
                severity=DIFFERENCE,
                title=f"{_rows(count)} {phrase}",
                rows=count,
                details=details,
                likely=likely,
                next_step=next_step,
            )
        )
    return out


def _notes(result: ComparisonResult) -> List[str]:
    """Non-failing facts worth one line each."""
    notes = []
    if result.keys_inferred and result.total_differences:
        notes.append(
            f"No compare.keys set: rows were paired on inferred key "
            f"{_column_list(result.keys, 6)}. Set compare.keys if that is wrong."
        )
    if result.pairing_note:
        notes.append(result.pairing_note)
    if result.equal_within_tolerance:
        notes.append(
            f"{_rows(result.equal_within_tolerance)} matched only within float_tolerance "
            f"and are not counted as differences."
        )
    if result.strict_column_failure:
        return notes  # schema detail is already a blocker
    exp, act = result.expected_label, result.actual_label
    parts = []
    if result.columns_only_in_expected:
        parts.append(f"{len(result.columns_only_in_expected)} column(s) only in {exp}")
    if result.columns_only_in_actual:
        parts.append(f"{len(result.columns_only_in_actual)} column(s) only in {act}")
    if result.type_mismatches:
        shown = [f"{c} {et} vs {at}" for c, et, at in result.type_mismatches[:3]]
        more = len(result.type_mismatches) - len(shown)
        text = ", ".join(shown) + (f", +{more} more" if more > 0 else "")
        parts.append(f"{len(result.type_mismatches)} type difference(s): {text}")
    if parts:
        notes.append(f"Schema, not failing: {'; '.join(parts)}")
    return notes


# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #
def _ordered(result: ComparisonResult) -> List[Finding]:
    blockers = _blockers(result)
    moved, moved_missing, moved_added = _moved(result) if result.keys else ([], set(), set())
    differences = moved + _changed(result) + _only_one_side(result, moved_missing, moved_added)
    differences.sort(key=lambda f: -f.rows)
    return blockers + differences


def build_findings(result: ComparisonResult) -> Dict[str, Any]:
    """Findings and notes for one result, as JSON-ready dicts."""
    return {
        "findings": [asdict(f) for f in _ordered(result)],
        "notes": _notes(result),
    }


def classify_diff_rows(result: ComparisonResult):
    """(diff_kind, finding_id, pair_id) for each of ``result.diff_rows``, in order.

    finding_id is the 1-based position in the findings list, the number a
    reader sees in the console. A moved row's two halves share a pair_id.
    """
    findings = _ordered(result)
    by_signature: Dict[Tuple[str, ...], int] = {}
    moved_missing: Dict[Tuple, Tuple[int, int]] = {}
    moved_added: Dict[Tuple, Tuple[int, int]] = {}
    only = {}
    pair_id = 0
    for index, f in enumerate(findings, 1):
        if f.kind == "changed":
            by_signature[tuple(f.columns)] = index
        elif f.kind == "moved":
            for m, a in getattr(f, "_pairs", []):
                pair_id += 1
                moved_missing[m] = (index, pair_id)
                moved_added[a] = (index, pair_id)
        elif f.kind in ("only_expected", "only_actual"):
            only[f.kind] = index

    out = []
    for diff in result.diff_rows:
        if diff.kind == "changed":
            sig = tuple(sorted(c.column for c in diff.columns))
            out.append(("changed", by_signature.get(sig), None))
        elif diff.kind == "missing" and diff.key in moved_missing:
            out.append(("moved",) + moved_missing[diff.key])
        elif diff.kind == "added" and diff.key in moved_added:
            out.append(("moved",) + moved_added[diff.key])
        else:
            kind = "only_expected" if diff.kind == "missing" else "only_actual"
            out.append((diff.kind, only.get(kind), None))
    return out


def summary_dict(name: str, result: ComparisonResult) -> Dict[str, Any]:
    """Everything render_case needs, and nothing it does not."""
    return {
        "case": name,
        "status": result.status,
        "expected_label": result.expected_label,
        "actual_label": result.actual_label,
        "expected_rows": result.expected_rows,
        "actual_rows": result.actual_rows,
        "total_differences": result.total_differences,
        "diff_ratio": result.diff_ratio,
        "max_diff_ratio": result.max_diff_ratio,
        "timing": {
            "expected": result.expected_load_seconds,
            "actual": result.actual_load_seconds,
            "compare": result.compare_seconds,
            "total": result.total_seconds,
        },
        **build_findings(result),
    }


def diffs_total(report: Dict[str, Any]) -> int:
    return int(report.get("total_differences") or 0)


def render_case(report: Dict[str, Any], max_findings: int = MAX_FINDINGS_SHOWN) -> str:
    """The console view of one case, from a summary_dict or a loaded result.json."""
    if report.get("status") == "ERROR":
        return f"{report['case']}: ERROR\n  {report.get('error_type', 'Error')}: {report.get('error', '')}"

    exp, act = report["expected_label"], report["actual_label"]
    lines = [f"{report['case']}: {report['status'].replace('_', ' ')}"]

    diffs = report["total_differences"]
    counts = f"  {exp} {report['expected_rows']:,} rows | {act} {report['actual_rows']:,} rows | "
    if diffs:
        limit = report.get("max_diff_ratio") or 0.0
        verdict = ""
        if limit:
            within = report["status"] == "WITHIN_TOLERANCE"
            verdict = f", {'within' if within else 'over'} the {_ratio(limit)} limit"
        verb = "differs" if diffs == 1 else "differ"
        counts += f"{_rows(diffs)} {verb} ({_ratio(report['diff_ratio'])}{verdict})"
    else:
        counts += "no row differences found"
    lines.append(counts)

    run = report.get("run") or {}
    if run.get("run_id"):
        date = f"run {run['run_date']}  " if run.get("run_date") else ""
        lines.append(f"  {date}run_id {run['run_id']}")
    diffs = report.get("diffs") or {}
    if diffs.get("query"):
        lines.append(f"  Rows: {diffs['query']}")
        if not diffs.get("complete", True):
            lines.append(
                f"  (stores the first {diffs.get('stored_rows', 0):,} differing rows; "
                f"the run found {diffs_total(report):,})"
            )

    timing = report.get("timing") or {}
    if timing.get("total"):
        lines.append(
            f"  took {format_duration(timing['total'])} ({exp} {format_duration(timing['expected'])}, "
            f"{act} {format_duration(timing['actual'])}, compare {format_duration(timing['compare'])})"
        )

    findings = report.get("findings") or []
    shown = [f for f in findings if f["severity"] == BLOCKER]
    rest = [f for f in findings if f["severity"] != BLOCKER]
    # Folding one finding into a "+1 more" line saves nothing.
    limit = max_findings if len(rest) > max_findings + 1 else len(rest)
    shown += rest[:limit]
    hidden = rest[limit:]

    for i, f in enumerate(shown, 1):
        lines.append("")
        tag = "[BLOCKER] " if f["severity"] == BLOCKER else ""
        lines.append(f"  {i}. {tag}{f['title']}")
        for detail in f.get("details") or []:
            lines.append(f"     {detail}")
        if f.get("likely"):
            lines.append(f"     Likely: {f['likely']}")
        if f.get("next_step"):
            lines.append(f"     Next:   {f['next_step']}")

    if hidden:
        lines.append("")
        lines.append(
            f"  +{len(hidden)} smaller finding(s) covering {_rows(sum(f['rows'] for f in hidden))}"
            f" (see result.json, or run with --verbose)"
        )

    notes = report.get("notes") or []
    if notes:
        lines.append("")
        lines.extend(f"  {note}" for note in notes)
    return "\n".join(lines)
