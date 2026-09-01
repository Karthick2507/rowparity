"""The comparison engine: expected vs actual, order-independent, nested-aware.

Two modes:

* **Keyed** (``keys=[...]``) — rows are matched on a primary/business key, so the
  result tells you exactly which keys are *missing*, *added*, or *changed*, and
  for changed rows which columns differ. This is what you want for row-level
  regression and reconciliation.

* **Keyless** — no stable key, so the tables are compared as *multisets* of rows.
  You still get order-independence and correct handling of duplicate rows, but a
  difference is reported as "this row is only on one side" rather than a per-key
  change. Ideal for backward-compatible-view checks where you just need
  "same set of rows, order irrelevant".
"""

from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any, Dict, List, Optional, Sequence, Tuple

import pyarrow as pa

from .hashing import CanonConfig, canon_columns_vectorized, canon_row, canon_value, row_digest


class IdenticalSourcesError(RuntimeError):
    """Both sides resolve to the same source, so the comparison proves nothing.

    Sibling of ``EmptyComparisonError``: same failure mode -- a green run that
    verified nothing -- reached from the other direction. There the two sides
    had no rows to disagree about; here they are the same rows, so they cannot.
    """


class EmptyComparisonError(RuntimeError):
    """Both sides returned zero rows, so the comparison proved nothing.

    Raised rather than returned as a difference because it is not a difference:
    it is a configuration or data-availability problem, and it needs to be
    distinguishable from "the tables genuinely disagree".
    """


@dataclass
class CompareConfig:
    keys: Optional[List[str]] = None
    select: Optional[List[str]] = None  # if set, only compare these columns
    ignore_columns: List[str] = field(default_factory=list)
    float_tolerance: float = 0.0
    coerce_numeric_to_float: bool = False
    trim_strings: bool = False
    case_insensitive: bool = False
    unordered_list_columns: List[str] = field(default_factory=list)
    # Label differences that are only a different spelling of absence
    # (null vs 0 vs [] vs false). CLASSIFICATION ONLY: it never changes a
    # verdict, and never makes NULL equal to anything in hashing.py. Off by
    # default -- turning it on trades detection power for tolerance, and that
    # has to be a deliberate, reviewable line in a case file.
    null_equivalence: bool = False
    # If True, a column present on one side only (or with a different logical type)
    # fails the comparison. If False, we compare the intersection and just report.
    strict_columns: bool = False
    max_examples: int = 20
    # Two empty tables are trivially equivalent, and that is the problem: a run
    # over zero rows compares nothing and reports EQUIVALENT with exit 0. It is
    # indistinguishable from a real pass and is almost always a batch that aged
    # out, a mistyped parameter, or a filter that matched nothing. Set True only
    # where an empty result is a legitimate expected outcome.
    allow_empty: bool = False
    # The mirror image of allow_empty: both sides pointing at the same source
    # compare a table with itself and report EQUIVALENT regardless of the data.
    # Set True only where self-comparison is the actual intent.
    allow_identical_sources: bool = False
    # Key column(s) to split the row differences by, so a comparison over a
    # UNION of several branches can say which branch disagrees.
    #
    # Restricted to key columns because a key is the only thing guaranteed
    # identical on both sides of a paired row. Break down by a non-key column
    # and a *changed* row has two different group values -- one per side -- so
    # there is no answer to which group it belongs to, and whichever side the
    # code happened to read would be an arbitrary choice presented as a fact.
    # Keyed comparisons only.
    breakdown_by: Optional[List[str]] = None
    # Look for a single key column whose drift turned one logical row into a
    # missing + added pair. Off by default: the analysis is O(columns x rows)
    # and only means anything for a keyed case that has both.
    near_miss: bool = False
    # Canonicalize whole columns at once (numpy / Arrow compute) instead of
    # dispatching per cell, falling back to the row-wise path for nulls and
    # types that don't vectorize (decimal, date, time, binary, nested). Same
    # results, faster on large scalar-heavy tables. Opt-in since it's newer.
    vectorized: bool = False

    def canon(self) -> CanonConfig:
        return CanonConfig(
            float_tolerance=self.float_tolerance,
            coerce_numeric_to_float=self.coerce_numeric_to_float,
            trim_strings=self.trim_strings,
            case_insensitive=self.case_insensitive,
            unordered_list_columns=frozenset(self.unordered_list_columns),
        )


@dataclass
class ColumnDiff:
    column: str
    expected: Any
    actual: Any
    # Set when null_equivalence is on and this difference is only a different
    # spelling of absence. The values still differ; this only records why.
    equivalent: bool = False


@dataclass
class RowDiff:
    kind: str  # "missing" | "added" | "changed"
    key: Optional[Tuple] = None
    columns: List[ColumnDiff] = field(default_factory=list)
    expected_row: Optional[dict] = None
    actual_row: Optional[dict] = None


@dataclass
class ColumnDelta:
    """How one column moved, across every changed row of one signature.

    A signature says *which* columns move together and how often. It never said
    which direction, by how much, or whether it was consistent -- and those are
    different bugs. "11 -> 10" from a single example cannot distinguish "every
    row loses exactly one" from "the deltas are all over the place"; the first
    is a diagnosis and the second is a starting point.
    """

    column: str
    rows: int = 0
    # Direction tallies. Nulls are counted apart from value moves: "became
    # null" is a different failure from "got smaller", and averaging them
    # together would hide both.
    lower: int = 0  # actual < expected
    higher: int = 0  # actual > expected
    became_null: int = 0
    was_null: int = 0
    numeric: int = 0  # rows where a delta could actually be computed
    min_delta: Optional[float] = None
    max_delta: Optional[float] = None
    # Non-numeric columns get the most common (expected -> actual) pair
    # instead, which is the same idea in the only form strings support.
    top_pair: Optional[Tuple[Any, Any]] = None
    top_pair_count: int = 0

    @property
    def constant_delta(self) -> Optional[float]:
        """The delta, if every numeric row moved by exactly the same amount.

        This is the word the whole feature is for. Four metrics all reporting a
        constant delta in the same direction is not "9 rows changed" -- it is a
        systematic, reproducible loss, stated by the report rather than left in
        the data for someone to notice.
        """
        if self.numeric and self.numeric == self.rows and self.min_delta == self.max_delta:
            return self.min_delta
        return None

    @property
    def direction(self) -> str:
        if self.lower and not self.higher:
            return "lower"
        if self.higher and not self.lower:
            return "higher"
        if self.lower or self.higher:
            return "mixed"
        return "null-only" if (self.became_null or self.was_null) else "other"


@dataclass
class ChangeSignature:
    """All 'changed' rows (keyed mode) that disagree on the same set of columns.

    Row-by-row diffs don't scale past a handful of examples; grouping by
    *which columns differ* turns thousands of changed rows into a handful of
    patterns (e.g. "37 rows differ only in `margin`").
    """

    columns: Tuple[str, ...]
    count: int = 0
    example: Optional[RowDiff] = None
    # Per-column movement across every row in this signature -- see ColumnDelta.
    deltas: Dict[str, ColumnDelta] = field(default_factory=dict)
    # This signature's rows split by the breakdown column, when one is set.
    breakdown: Dict[Any, int] = field(default_factory=dict)
    # How extreme `example` is, so the kept row is the most diagnostic one
    # rather than whichever happened to be read first.
    _example_score: float = -1.0

    def share_of(self, changed_count: int) -> float:
        """Fraction of all changed rows this signature accounts for."""
        return (self.count / changed_count) if changed_count else 0.0


@dataclass
class BreakdownGroup:
    """Row counts for one value of the breakdown column.

    Exists so a run over a UNION of several branches can say *which branch*
    disagrees. The three-way `slot_user_drop_off` union is the motivating case:
    without this, 149 missing and 208 added rows are one undifferentiated pile.
    """

    value: Any
    expected_rows: int = 0
    actual_rows: int = 0
    missing: int = 0
    added: int = 0
    changed: int = 0

    @property
    def differences(self) -> int:
        return self.missing + self.added + self.changed

    @property
    def differing_share(self) -> float:
        """Differences as a fraction of the larger side.

        Ranking by absolute count buries a small branch that is badly broken
        under a large branch that is slightly off. 58 missing from 892 rows is
        a worse signal than 71 from 1,204, and only the ratio says so.
        """
        base = max(self.expected_rows, self.actual_rows)
        return (self.differences / base) if base else 0.0


@dataclass
class ComparisonResult:
    equivalent: bool
    keys: Optional[List[str]]
    compared_columns: List[str]
    expected_rows: int
    actual_rows: int
    missing_count: int = 0  # in expected, not in actual
    added_count: int = 0  # in actual, not in expected
    changed_count: int = 0  # keyed only: same key, different content
    columns_only_in_expected: List[str] = field(default_factory=list)
    columns_only_in_actual: List[str] = field(default_factory=list)
    type_mismatches: List[Tuple[str, str, str]] = field(default_factory=list)
    duplicate_keys_expected: int = 0
    duplicate_keys_actual: int = 0
    examples: List[RowDiff] = field(default_factory=list)
    change_signatures: Dict[Tuple[str, ...], ChangeSignature] = field(default_factory=dict)
    # What was actually compared. "rows" for a data comparison, "schema" for a
    # schema-only check -- summary() and the per-column CSV both need to tell
    # them apart, and 0 rows is not a reliable signal (an empty table is also 0).
    kind: str = "rows"
    # Column -> type, when the producer knows them. Populated by schema checks
    # so a per-column report can name the type of a column that exists on only
    # one side; left empty by row comparisons, which never introspect types.
    expected_schema: Dict[str, str] = field(default_factory=dict)
    actual_schema: Dict[str, str] = field(default_factory=dict)
    # column -> how many changed rows whose difference in that column was
    # classified as merely a different spelling of absence. Populated only
    # when null_equivalence is on. Subtract from the per-column totals in
    # change_signatures to get the count of genuine disagreements.
    equivalent_diff_columns: Dict[str, int] = field(default_factory=dict)
    # How to name the two sides in reports. "expected"/"actual" is accurate but
    # abstract; a reader looking at a migration wants "Hoover" and "Hoover++".
    # Presentation, not comparison -- nothing here reads them.
    expected_label: str = "expected"
    actual_label: str = "actual"
    # How to digest one row for a human: [{label, columns}]. Presentation only,
    # like the two labels above -- nothing in the comparison reads it.
    row_summary: List[Dict[str, Any]] = field(default_factory=list)
    # One drill-down per run: a single query per side covering every differing
    # row, plus the transaction ids each returned. See drilldown.py.
    drilldown: Optional[Any] = None  # drilldown.DrilldownResult
    # Keyless only: columns whose value multiset differs between the two sides.
    # Keyed comparisons attribute differences per row via change_signatures and
    # do not need this. See _compare_keyless for how it is computed.
    column_value_mismatch: List[str] = field(default_factory=list)
    # Row differences split by cfg.breakdown_by, computed over every row rather
    # than over the bounded `examples` list -- a breakdown derived from 50 of
    # 366 differing rows would describe a sample while looking like the whole
    # picture. Empty when no breakdown column is set.
    breakdown_columns: List[str] = field(default_factory=list)
    breakdown: Dict[Any, "BreakdownGroup"] = field(default_factory=dict)
    # Key tuples of every unpaired row, kept so near_miss.analyse() can look
    # for the column that broke the pairing. These are references to tuples the
    # index already holds, so the cost is one pointer each, not a copy.
    missing_keys: List[Tuple] = field(default_factory=list)
    added_keys: List[Tuple] = field(default_factory=list)
    changed_keys: List[Tuple] = field(default_factory=list)
    near_miss: Optional[Any] = None  # near_miss.NearMissResult

    # Wall-clock seconds, filled in by Case.run(). Kept as three numbers rather
    # than one total because "the query was slow" and "the comparison was slow"
    # have nothing in common: the first is a warehouse problem, the second is
    # ours. Zero means "not measured" -- compare_tables() called directly does
    # not set them.
    expected_load_seconds: float = 0.0
    actual_load_seconds: float = 0.0
    compare_seconds: float = 0.0

    @property
    def total_seconds(self) -> float:
        return self.expected_load_seconds + self.actual_load_seconds + self.compare_seconds

    @property
    def total_differences(self) -> int:
        return self.missing_count + self.added_count + self.changed_count

    def signatures_by_count(self) -> List[ChangeSignature]:
        return sorted(self.change_signatures.values(), key=lambda s: s.count, reverse=True)

    def summary(self) -> str:
        head = "EQUIVALENT" if self.equivalent else "DIFFERENT"
        if self.kind == "schema":
            # A schema check fetches no rows by design; reporting it as a
            # keyless multiset comparison of 0 rows is actively misleading.
            return (
                f"[{head}] schema-only | columns: {len(self.compared_columns)} compared, "
                f"{len(self.columns_only_in_expected)} only in expected, "
                f"{len(self.columns_only_in_actual)} only in actual, "
                f"{len(self.type_mismatches)} type mismatch(es)"
            )
        mode = f"keyed on {self.keys}" if self.keys else "keyless (multiset)"
        return (
            f"[{head}] {mode} | expected={self.expected_rows} actual={self.actual_rows} "
            f"| missing={self.missing_count} added={self.added_count} changed={self.changed_count}"
        )


def _resolve_columns(exp: pa.Schema, act: pa.Schema, cfg: CompareConfig):
    exp_cols = list(exp.names)
    act_cols = list(act.names)
    exp_set, act_set = set(exp_cols), set(act_cols)

    only_exp = [c for c in exp_cols if c not in act_set]
    only_act = [c for c in act_cols if c not in exp_set]

    candidate = cfg.select if cfg.select else [c for c in exp_cols if c in act_set]
    compared = [c for c in candidate if c not in set(cfg.ignore_columns)]
    # Keep only columns present on both sides.
    compared = [c for c in compared if c in exp_set and c in act_set]

    type_mismatches = []
    for c in compared:
        et, at = exp.field(c).type, act.field(c).type
        if not et.equals(at):
            type_mismatches.append((c, str(et), str(at)))
    return compared, only_exp, only_act, type_mismatches


def compare_tables(expected: pa.Table, actual: pa.Table, cfg: CompareConfig) -> ComparisonResult:
    compared, only_exp, only_act, type_mismatches = _resolve_columns(
        expected.schema, actual.schema, cfg
    )
    canon_cfg = cfg.canon()
    sorted_cols = sorted(compared)

    result = ComparisonResult(
        equivalent=True,
        keys=cfg.keys,
        compared_columns=sorted_cols,
        expected_rows=expected.num_rows,
        actual_rows=actual.num_rows,
        columns_only_in_expected=only_exp,
        columns_only_in_actual=only_act,
        type_mismatches=type_mismatches,
        # Carry both schemas so reporters can show a column's type on each
        # side. Only schema_check used to fill these, so a row comparison's
        # per-column CSV printed empty type columns for every row -- including
        # for the "present on one side only" rows, where the type is the single
        # most useful thing to know about the missing column.
        expected_schema={f.name: str(f.type) for f in expected.schema},
        actual_schema={f.name: str(f.type) for f in actual.schema},
    )

    # Column-set / type problems only *fail* the run in strict mode, but are always reported.
    if cfg.strict_columns and (only_exp or only_act or type_mismatches):
        result.equivalent = False

    exp_rows = expected.to_pylist()
    act_rows = actual.to_pylist()

    exp_canon = act_canon = None
    if cfg.vectorized:
        canon_columns = sorted(set(sorted_cols) | set(cfg.keys or []))
        exp_canon = canon_columns_vectorized(expected.schema, expected, canon_columns, canon_cfg)
        act_canon = canon_columns_vectorized(actual.schema, actual, canon_columns, canon_cfg)

    if cfg.keys:
        _compare_keyed(
            exp_rows,
            act_rows,
            expected.schema,
            actual.schema,
            sorted_cols,
            cfg,
            canon_cfg,
            result,
            exp_canon,
            act_canon,
        )
    else:
        _compare_keyless(
            exp_rows,
            act_rows,
            expected.schema,
            actual.schema,
            sorted_cols,
            canon_cfg,
            result,
            cfg,
            exp_canon,
            act_canon,
        )

    if cfg.near_miss and cfg.keys and result.missing_keys and result.added_keys:
        from . import near_miss as _near_miss

        result.near_miss = _near_miss.analyse(result.missing_keys, result.added_keys, cfg.keys)

    if result.total_differences > 0:
        result.equivalent = False
    return result


def _key_of(
    row: dict,
    schema: pa.Schema,
    keys: Sequence[str],
    canon_cfg: CanonConfig,
    canon_cache: Optional[Dict[str, list]] = None,
    idx: Optional[int] = None,
) -> Tuple:
    if canon_cache is not None:
        return tuple(canon_cache[k][idx] for k in keys)
    return tuple(canon_value(schema.field(k).type, row.get(k), canon_cfg) for k in keys)


def _compare_keyed(
    exp_rows,
    act_rows,
    exp_schema,
    act_schema,
    cols,
    cfg,
    canon_cfg,
    result,
    exp_canon=None,
    act_canon=None,
):
    keys = cfg.keys
    for k in keys:
        if k not in exp_schema.names or k not in act_schema.names:
            raise ValueError(f"key column '{k}' is missing from expected or actual table")

    # Index by row position rather than the row dict itself — cheap either way,
    # but keeps this in step with the canon cache, which is also positional.
    exp_index: Dict[Tuple, list] = defaultdict(list)
    act_index: Dict[Tuple, list] = defaultdict(list)
    for i, r in enumerate(exp_rows):
        exp_index[_key_of(r, exp_schema, keys, canon_cfg, exp_canon, i)].append(i)
    for i, r in enumerate(act_rows):
        act_index[_key_of(r, act_schema, keys, canon_cfg, act_canon, i)].append(i)

    result.duplicate_keys_expected = sum(len(v) - 1 for v in exp_index.values() if len(v) > 1)
    result.duplicate_keys_actual = sum(len(v) - 1 for v in act_index.values() if len(v) > 1)

    exp_keys, act_keys = set(exp_index), set(act_index)

    # Positions of the breakdown columns within the key tuple. The tuple holds
    # canonicalised *values*, not a hash, so this is a plain lookup -- which is
    # the whole reason the breakdown is restricted to key columns.
    bd_columns = list(cfg.breakdown_by or [])
    # Every breakdown column must be part of the key -- see CompareConfig for
    # why. cases.py checks this before a row is fetched; this is the backstop
    # for compare_tables() called directly.
    for c in bd_columns:
        if c not in keys:
            raise ValueError(
                f"breakdown_by column '{c}' must be one of the key columns; a "
                f"non-key column has a different value on each side of a "
                f"changed row, so the row belongs to no single group"
            )
    result.breakdown_columns = bd_columns

    def _bd(row: dict):
        """Group identity: the raw column value(s) from the row.

        Raw rather than canonical, which is a deliberate trade. The canonical
        form is a type-tagged tuple -- ("s", "Removed") -- so keying on it
        would force every reader of `result.breakdown` through a `.value`
        lookup to find out which group they were holding. Keying on the raw
        value makes `breakdown["Removed"]` mean what it looks like.

        What that costs: with trim_strings on, " A" and "A" are one row to the
        comparison but two groups here. That is rare, and it shows up as two
        near-identical rows in the report rather than as a silently wrong
        number -- the right way round for a mistake to fail.
        """
        raw = [row.get(c) for c in bd_columns]
        return raw[0] if len(raw) == 1 else tuple(raw)

    def _group(key: Tuple, row: Optional[dict] = None) -> Optional[BreakdownGroup]:
        if not bd_columns or row is None:
            return None
        value = _bd(row)
        group = result.breakdown.get(value)
        if group is None:
            group = result.breakdown[value] = BreakdownGroup(value=value)
        return group

    # Side totals per group, so the report can show differences as a share of
    # each branch rather than only as an absolute count.
    for key, idxs in exp_index.items():
        group = _group(key, exp_rows[idxs[0]])
        if group is not None:
            group.expected_rows += len(idxs)
    for key, idxs in act_index.items():
        group = _group(key, act_rows[idxs[0]])
        if group is not None:
            group.actual_rows += len(idxs)

    missing = exp_keys - act_keys
    added = act_keys - exp_keys
    result.missing_keys = list(missing)
    result.added_keys = list(added)

    for key in missing:
        idxs = exp_index[key]
        result.missing_count += len(idxs)
        group = _group(key, exp_rows[idxs[0]])
        if group is not None:
            group.missing += len(idxs)
        _maybe_example(
            result, cfg, RowDiff(kind="missing", key=key, expected_row=exp_rows[idxs[0]])
        )

    for key in added:
        idxs = act_index[key]
        result.added_count += len(idxs)
        group = _group(key, act_rows[idxs[0]])
        if group is not None:
            group.added += len(idxs)
        _maybe_example(result, cfg, RowDiff(kind="added", key=key, actual_row=act_rows[idxs[0]]))

    for key in exp_keys & act_keys:
        ei, ai = exp_index[key][0], act_index[key][0]
        e, a = exp_rows[ei], act_rows[ai]
        if exp_canon is not None:
            e_canon_row = tuple((c, exp_canon[c][ei]) for c in cols)
            a_canon_row = tuple((c, act_canon[c][ai]) for c in cols)
        else:
            e_canon_row = canon_row(exp_schema, e, cols, canon_cfg)
            a_canon_row = canon_row(act_schema, a, cols, canon_cfg)
        e_digest = row_digest(e_canon_row)
        a_digest = row_digest(a_canon_row)
        if e_digest != a_digest:
            result.changed_count += 1
            coldiffs = _column_diffs(
                e, a, exp_schema, act_schema, cols, cfg, canon_cfg, exp_canon, act_canon, ei, ai
            )
            diff = RowDiff(kind="changed", key=key, columns=coldiffs, expected_row=e, actual_row=a)

            for cd in coldiffs:
                if cd.equivalent:
                    result.equivalent_diff_columns[cd.column] = (
                        result.equivalent_diff_columns.get(cd.column, 0) + 1
                    )

            result.changed_keys.append(key)
            group = _group(key, e)
            if group is not None:
                group.changed += 1

            sig = tuple(sorted(c.column for c in coldiffs))
            stats = result.change_signatures.setdefault(sig, ChangeSignature(columns=sig))
            stats.count += 1
            if bd_columns:
                label = _bd(e)
                stats.breakdown[label] = stats.breakdown.get(label, 0) + 1

            score = _accumulate_deltas(stats, coldiffs, cfg)
            # Keep the most extreme row rather than whichever arrived first.
            # An arbitrary example is a fine illustration and a poor lead; the
            # largest movement is the one worth looking at.
            if stats.example is None or score > stats._example_score:
                stats.example = diff
                stats._example_score = score

            _maybe_example(result, cfg, diff)


def _as_number(value) -> Optional[float]:
    """A float for delta arithmetic, or None if this value has no magnitude.

    bool is excluded deliberately: it is an int in Python, and reporting that a
    flag "moved by -1" is worse than saying nothing.
    """
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float, Decimal)):
        try:
            return float(value)
        except (ValueError, OverflowError):
            return None
    return None


def _accumulate_deltas(stats: ChangeSignature, coldiffs, cfg: CompareConfig) -> float:
    """Fold one changed row into the signature's per-column movement profile.

    Returns how extreme this row is, used to pick the example to keep.
    """
    worst = 0.0
    for cd in coldiffs:
        delta = stats.deltas.get(cd.column)
        if delta is None:
            delta = stats.deltas[cd.column] = ColumnDelta(column=cd.column)
        delta.rows += 1

        if cd.expected is None or cd.actual is None:
            # A value appearing or disappearing is not a movement, and folding
            # it into the numeric profile would invent a delta from nothing.
            if cd.actual is None:
                delta.became_null += 1
            else:
                delta.was_null += 1
            continue

        ev, av = _as_number(cd.expected), _as_number(cd.actual)
        if ev is not None and av is not None:
            diff = av - ev
            # Quantise to the tolerance grid first. Without this no float
            # column would ever report a constant delta -- the last bits would
            # differ on every row and the most useful signal would never fire.
            if cfg.float_tolerance > 0:
                diff = round(diff / cfg.float_tolerance) * cfg.float_tolerance
            delta.numeric += 1
            if diff < 0:
                delta.lower += 1
            elif diff > 0:
                delta.higher += 1
            delta.min_delta = diff if delta.min_delta is None else min(delta.min_delta, diff)
            delta.max_delta = diff if delta.max_delta is None else max(delta.max_delta, diff)
            scale = abs(ev) or 1.0
            worst = max(worst, abs(diff) / scale)
        else:
            # Strings and everything else: the dominant (expected -> actual)
            # pair is the closest thing to a delta that they support.
            pair = (cd.expected, cd.actual)
            try:
                if delta.top_pair == pair:
                    delta.top_pair_count += 1
                elif delta.top_pair is None:
                    delta.top_pair, delta.top_pair_count = pair, 1
            except Exception:  # unhashable / uncomparable values
                delta.top_pair, delta.top_pair_count = None, 0
            worst = max(worst, 1.0)
    return worst


def _column_diffs(
    e,
    a,
    exp_schema,
    act_schema,
    cols,
    cfg,
    canon_cfg,
    exp_canon=None,
    act_canon=None,
    ei=None,
    ai=None,
) -> List[ColumnDiff]:
    diffs = []
    for c in cols:
        if exp_canon is not None:
            ce, ca = exp_canon[c][ei], act_canon[c][ai]
        else:
            unordered = c in set(cfg.unordered_list_columns)
            ce = canon_value(
                exp_schema.field(c).type, e.get(c), canon_cfg, unordered_list=unordered
            )
            ca = canon_value(
                act_schema.field(c).type, a.get(c), canon_cfg, unordered_list=unordered
            )
        if ce != ca:
            ev, av = e.get(c), a.get(c)
            equivalent = False
            diffs.append(ColumnDiff(column=c, expected=ev, actual=av, equivalent=equivalent))
    return diffs


_HASH_MASK = (1 << 64) - 1


def _compare_keyless(
    exp_rows,
    act_rows,
    exp_schema,
    act_schema,
    cols,
    canon_cfg,
    result,
    cfg,
    exp_canon=None,
    act_canon=None,
):
    exp_counts: Counter = Counter()
    act_counts: Counter = Counter()
    sample: Dict[bytes, dict] = {}

    # Per-column value fingerprints, so a keyless run can still say WHICH
    # columns differ.
    #
    # Without a key there is no way to pair a missing row with the added row it
    # corresponds to, so no per-row attribution exists -- and the report used to
    # mark all 262 columns MATCHED beside a million row differences, which reads
    # as "the columns are fine" when nothing of the sort was checked.
    #
    # Two columns hold the same multiset of values iff the sum of their value
    # hashes matches (addition, not XOR, so multiplicity is preserved; order is
    # irrelevant because addition commutes -- the same property the row
    # comparison relies on). One integer per column instead of a Counter of a
    # million values, which at 262 columns would not fit in memory.
    #
    # Costs about 16% on a 100k x 263 comparison, measured.
    #
    # These use Python's hash(), which is randomised per process for strings.
    # That is fine because both sides are hashed inside one process and only
    # ever compared with each other -- but it means the values are NOT stable
    # across runs and must never be persisted or compared between processes.
    exp_col_hash = dict.fromkeys(cols, 0)
    act_col_hash = dict.fromkeys(cols, 0)

    for i, r in enumerate(exp_rows):
        canon = (
            tuple((c, exp_canon[c][i]) for c in cols)
            if exp_canon is not None
            else canon_row(exp_schema, r, cols, canon_cfg)
        )
        d = row_digest(canon)
        exp_counts[d] += 1
        sample.setdefault(d, r)
        for c, v in canon:
            exp_col_hash[c] = (exp_col_hash[c] + hash(v)) & _HASH_MASK
    for i, r in enumerate(act_rows):
        canon = (
            tuple((c, act_canon[c][i]) for c in cols)
            if act_canon is not None
            else canon_row(act_schema, r, cols, canon_cfg)
        )
        d = row_digest(canon)
        act_counts[d] += 1
        sample.setdefault(d, r)
        for c, v in canon:
            act_col_hash[c] = (act_col_hash[c] + hash(v)) & _HASH_MASK

    result.column_value_mismatch = [c for c in cols if exp_col_hash[c] != act_col_hash[c]]

    for d in set(exp_counts) | set(act_counts):
        delta = exp_counts[d] - act_counts[d]
        if delta > 0:  # more copies in expected -> missing from actual
            result.missing_count += delta
            _maybe_example(result, cfg, RowDiff(kind="missing", expected_row=sample[d]))
        elif delta < 0:  # more copies in actual -> added
            result.added_count += -delta
            _maybe_example(result, cfg, RowDiff(kind="added", actual_row=sample[d]))


def _maybe_example(result: ComparisonResult, cfg: CompareConfig, diff: RowDiff):
    if len(result.examples) < cfg.max_examples:
        result.examples.append(diff)
