"""Pair unmatched rows in a keyless comparison.

A keyless comparison can only say "this row is on one side only". For two
semantically identical aggregate queries that is the least useful thing to say:
one metric moving turns every affected group into a missing row *and* an added
row, the ratio double counts, and "impressions is lower by exactly 1" -- the
finding that points at a cause -- cannot be stated at all.

So after the multiset comparison, rows left over on each side are paired:

1. **Infer a key.** For a GROUP BY the dimensions are unique by construction.
   Candidates are non-float, non-nested columns, ordered by how often their
   values among unmatched missing rows also appear among unmatched added rows
   (dimensions carry over; changed metrics do not), then by cardinality. Add
   them in that order until the combination is unique on the expected side,
   then drop every column the uniqueness does not need.
2. **Pair on it.** A missing and an added row with the same inferred key are
   one row that changed. If every column that differs is a float within
   ``float_tolerance``, they are not a difference at all -- this is also what
   stops a value rounding to either side of a tolerance grid step from
   failing a query.

Pairing is an inference and is labelled as one in the report. It is skipped
when there are too many unmatched rows to be worth it, or no unique key exists.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any, Dict, List, Optional, Sequence, Tuple

import pyarrow as pa
import pyarrow.compute as pc

from .hashing import CanonConfig, canon_value

MAX_UNMATCHED = 20_000


def within_tolerance(arrow_type: pa.DataType, expected: Any, actual: Any, tolerance: float) -> bool:
    """True when two float values are equal to within ``tolerance``.

    The canonical form quantises floats onto a grid, which is what makes
    hashing possible but means 74.06654999 and 74.06655001 round apart. A
    difference that small is not one.
    """
    if tolerance <= 0 or not pa.types.is_floating(arrow_type):
        return False
    if expected is None or actual is None:
        return False
    try:
        return abs(float(expected) - float(actual)) <= tolerance * (1 + 1e-9)
    except (TypeError, ValueError):
        return False


def _key_candidates(schema: pa.Schema, columns: Sequence[str]) -> List[str]:
    out = []
    for c in columns:
        t = schema.field(c).type
        if pa.types.is_floating(t) or pa.types.is_nested(t) or pa.types.is_binary(t):
            continue
        out.append(c)
    return out


def _is_unique(table: pa.Table, columns: List[str]) -> bool:
    try:
        return table.select(columns).group_by(columns).aggregate([]).num_rows == table.num_rows
    except (pa.ArrowInvalid, pa.ArrowNotImplementedError, pa.ArrowTypeError):
        return False


def infer_key(
    expected: pa.Table,
    columns: Sequence[str],
    missing_rows: Sequence[dict],
    added_rows: Sequence[dict],
) -> Optional[List[str]]:
    candidates = _key_candidates(expected.schema, columns)
    if not candidates or expected.num_rows == 0:
        return None

    def carry_over(c: str) -> float:
        added_values = set()
        for row in added_rows:
            try:
                added_values.add(row.get(c))
            except TypeError:
                return 0.0
        hits = sum(1 for row in missing_rows if row.get(c) in added_values)
        return hits / len(missing_rows) if missing_rows else 0.0

    distinct = {c: pc.count_distinct(expected[c], mode="all").as_py() for c in candidates}
    ordered = sorted(candidates, key=lambda c: (-carry_over(c), distinct[c], c))

    key: List[str] = []
    for c in ordered:
        key.append(c)
        if _is_unique(expected, key):
            break
    else:
        return None
    for c in list(reversed(key)):
        trial = [k for k in key if k != c]
        if trial and _is_unique(expected, trial):
            key = trial
    return key


def _canon_key(schema: pa.Schema, row: dict, key: Sequence[str], canon_cfg: CanonConfig) -> Tuple:
    return tuple(canon_value(schema.field(k).type, row.get(k), canon_cfg) for k in key)


def pair_rows(
    expected: pa.Table,
    actual: pa.Table,
    columns: Sequence[str],
    canon_cfg: CanonConfig,
    missing: Sequence[Tuple[dict, int]],
    added: Sequence[Tuple[dict, int]],
    float_tolerance: float,
) -> Optional[Dict[str, Any]]:
    """Pair unmatched rows. None when pairing was not attempted.

    ``missing``/``added`` are (row, copies) for each distinct unmatched row.
    Returns the inferred key and the paired / unpaired rows, with the columns
    that differ for each changed pair.
    """
    if not missing or not added:
        return None
    if len(missing) > MAX_UNMATCHED or len(added) > MAX_UNMATCHED:
        return {"skipped": f"{max(len(missing), len(added)):,} unmatched rows"}

    key = infer_key(expected, columns, [r for r, _ in missing], [r for r, _ in added])
    if key is None:
        return None

    exp_schema, act_schema = expected.schema, actual.schema
    by_key_missing: Dict[Tuple, List[Tuple[dict, int]]] = defaultdict(list)
    by_key_added: Dict[Tuple, List[Tuple[dict, int]]] = defaultdict(list)
    for row, n in missing:
        by_key_missing[_canon_key(exp_schema, row, key, canon_cfg)].append((row, n))
    for row, n in added:
        by_key_added[_canon_key(act_schema, row, key, canon_cfg)].append((row, n))

    def one_to_one(k: Tuple) -> bool:
        rows, partners = by_key_missing[k], by_key_added.get(k, [])
        return len(rows) == 1 and len(partners) == 1 and rows[0][1] == 1 and partners[0][1] == 1

    paired = {k for k in by_key_missing if one_to_one(k)}
    value_columns = [c for c in columns if c not in set(key)]
    changed, equal = [], 0
    for k in paired:
        e, a = by_key_missing[k][0][0], by_key_added[k][0][0]
        diffs = []
        for c in value_columns:
            et, at = exp_schema.field(c).type, act_schema.field(c).type
            ev, av = e.get(c), a.get(c)
            if canon_value(et, ev, canon_cfg) == canon_value(at, av, canon_cfg):
                continue
            if within_tolerance(et, ev, av, float_tolerance) and within_tolerance(at, ev, av, float_tolerance):
                continue
            diffs.append((c, ev, av))
        if diffs:
            changed.append((k, e, a, diffs))
        else:
            equal += 1

    unpaired_missing = [
        (k, row, n) for k, rows in by_key_missing.items() if k not in paired for row, n in rows
    ]
    unpaired_added = [
        (k, row, n) for k, rows in by_key_added.items() if k not in paired for row, n in rows
    ]

    return {
        "key": key,
        "changed": changed,
        "equal_within_tolerance": equal,
        "unpaired_missing": unpaired_missing,
        "unpaired_added": unpaired_added,
    }
