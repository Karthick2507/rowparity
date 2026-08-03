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
from typing import Any, Dict, List, Optional, Sequence, Tuple

import pyarrow as pa

from .hashing import CanonConfig, canon_columns_vectorized, canon_row, canon_value, row_digest


@dataclass
class CompareConfig:
    keys: Optional[List[str]] = None
    select: Optional[List[str]] = None          # if set, only compare these columns
    ignore_columns: List[str] = field(default_factory=list)
    float_tolerance: float = 0.0
    coerce_numeric_to_float: bool = False
    trim_strings: bool = False
    case_insensitive: bool = False
    unordered_list_columns: List[str] = field(default_factory=list)
    # If True, a column present on one side only (or with a different logical type)
    # fails the comparison. If False, we compare the intersection and just report.
    strict_columns: bool = False
    max_examples: int = 20
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


@dataclass
class RowDiff:
    kind: str                       # "missing" | "added" | "changed"
    key: Optional[Tuple] = None
    columns: List[ColumnDiff] = field(default_factory=list)
    expected_row: Optional[dict] = None
    actual_row: Optional[dict] = None


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


@dataclass
class ComparisonResult:
    equivalent: bool
    keys: Optional[List[str]]
    compared_columns: List[str]
    expected_rows: int
    actual_rows: int
    missing_count: int = 0          # in expected, not in actual
    added_count: int = 0            # in actual, not in expected
    changed_count: int = 0          # keyed only: same key, different content
    columns_only_in_expected: List[str] = field(default_factory=list)
    columns_only_in_actual: List[str] = field(default_factory=list)
    type_mismatches: List[Tuple[str, str, str]] = field(default_factory=list)
    duplicate_keys_expected: int = 0
    duplicate_keys_actual: int = 0
    examples: List[RowDiff] = field(default_factory=list)
    change_signatures: Dict[Tuple[str, ...], ChangeSignature] = field(default_factory=dict)

    @property
    def total_differences(self) -> int:
        return self.missing_count + self.added_count + self.changed_count

    def signatures_by_count(self) -> List[ChangeSignature]:
        return sorted(self.change_signatures.values(), key=lambda s: s.count, reverse=True)

    def summary(self) -> str:
        head = "EQUIVALENT" if self.equivalent else "DIFFERENT"
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
            exp_rows, act_rows, expected.schema, actual.schema, sorted_cols, cfg, canon_cfg, result,
            exp_canon, act_canon,
        )
    else:
        _compare_keyless(
            exp_rows, act_rows, expected.schema, actual.schema, sorted_cols, canon_cfg, result, cfg,
            exp_canon, act_canon,
        )

    if result.total_differences > 0:
        result.equivalent = False
    return result


def _key_of(
    row: dict, schema: pa.Schema, keys: Sequence[str], canon_cfg: CanonConfig,
    canon_cache: Optional[Dict[str, list]] = None, idx: Optional[int] = None,
) -> Tuple:
    if canon_cache is not None:
        return tuple(canon_cache[k][idx] for k in keys)
    return tuple(canon_value(schema.field(k).type, row.get(k), canon_cfg) for k in keys)


def _compare_keyed(exp_rows, act_rows, exp_schema, act_schema, cols, cfg, canon_cfg, result,
                    exp_canon=None, act_canon=None):
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

    for key in exp_keys - act_keys:
        idxs = exp_index[key]
        result.missing_count += len(idxs)
        _maybe_example(result, cfg, RowDiff(kind="missing", key=key, expected_row=exp_rows[idxs[0]]))

    for key in act_keys - exp_keys:
        idxs = act_index[key]
        result.added_count += len(idxs)
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
            coldiffs = _column_diffs(e, a, exp_schema, act_schema, cols, cfg, canon_cfg, exp_canon, act_canon, ei, ai)
            diff = RowDiff(kind="changed", key=key, columns=coldiffs, expected_row=e, actual_row=a)

            sig = tuple(sorted(c.column for c in coldiffs))
            stats = result.change_signatures.setdefault(sig, ChangeSignature(columns=sig))
            stats.count += 1
            if stats.example is None:
                stats.example = diff

            _maybe_example(result, cfg, diff)


def _column_diffs(e, a, exp_schema, act_schema, cols, cfg, canon_cfg,
                   exp_canon=None, act_canon=None, ei=None, ai=None) -> List[ColumnDiff]:
    diffs = []
    for c in cols:
        if exp_canon is not None:
            ce, ca = exp_canon[c][ei], act_canon[c][ai]
        else:
            unordered = c in set(cfg.unordered_list_columns)
            ce = canon_value(exp_schema.field(c).type, e.get(c), canon_cfg, unordered_list=unordered)
            ca = canon_value(act_schema.field(c).type, a.get(c), canon_cfg, unordered_list=unordered)
        if ce != ca:
            diffs.append(ColumnDiff(column=c, expected=e.get(c), actual=a.get(c)))
    return diffs


def _compare_keyless(exp_rows, act_rows, exp_schema, act_schema, cols, canon_cfg, result, cfg,
                      exp_canon=None, act_canon=None):
    exp_counts: Counter = Counter()
    act_counts: Counter = Counter()
    sample: Dict[bytes, dict] = {}

    for i, r in enumerate(exp_rows):
        canon = tuple((c, exp_canon[c][i]) for c in cols) if exp_canon is not None \
            else canon_row(exp_schema, r, cols, canon_cfg)
        d = row_digest(canon)
        exp_counts[d] += 1
        sample.setdefault(d, r)
    for i, r in enumerate(act_rows):
        canon = tuple((c, act_canon[c][i]) for c in cols) if act_canon is not None \
            else canon_row(act_schema, r, cols, canon_cfg)
        d = row_digest(canon)
        act_counts[d] += 1
        sample.setdefault(d, r)

    for d in set(exp_counts) | set(act_counts):
        delta = exp_counts[d] - act_counts[d]
        if delta > 0:                      # more copies in expected -> missing from actual
            result.missing_count += delta
            _maybe_example(result, cfg, RowDiff(kind="missing", expected_row=sample[d]))
        elif delta < 0:                    # more copies in actual -> added
            result.added_count += -delta
            _maybe_example(result, cfg, RowDiff(kind="added", actual_row=sample[d]))


def _maybe_example(result: ComparisonResult, cfg: CompareConfig, diff: RowDiff):
    if len(result.examples) < cfg.max_examples:
        result.examples.append(diff)
