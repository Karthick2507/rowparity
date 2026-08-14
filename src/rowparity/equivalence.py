"""Classifying a difference as *semantically* equivalent.

During a migration, "no data" is often represented differently on each side --
an empty array where the other stores NULL, a zero where the other stores
nothing. Those are real differences in the data and rowparity reports them as
such: NULL stays a distinct value, never equal to anything else, and nothing
in this module touches ``hashing.py`` or changes a verdict.

What it does is *label* a difference that has already been found, so a report
can separate "these values disagree" from "these values disagree only in how
they spell absence". That is the distinction the BCV analyser drew with its
three-state validation column -- ``Y`` exact, ``E`` equivalent, ``N``
mismatch -- and notably it never claimed ``E`` meant equal either.

Ported from that tool so the classification matches what the team already
reviewed. Two groups, both containing the null-likes, which is why ``0`` is
equivalent to ``null`` and ``[]`` is equivalent to ``null``, but ``0`` is NOT
equivalent to ``[]``:

    null-like / zero / false      \\N  ""  null  none  0  0.0  false
    null-like / empty container   \\N  ""  null  none  []  {}

Matching is case-insensitive. An array whose elements are all null-like is
itself null-like, so ``[None, None]`` is equivalent to ``null`` and to ``[]``.
Two same-length lists are compared element-wise, which covers the common
pattern of ``[[], None]`` against ``[None, None]``; differing lengths are not
equivalent, since that is structural compaction rather than a spelling of
absence.
"""

from __future__ import annotations

from typing import Any, FrozenSet, List

_GROUPS: List[FrozenSet[str]] = [
    frozenset({"\\n", "", "null", "none", "0", "0.0", "false"}),
    frozenset({"\\n", "", "null", "none", "[]", "{}"}),
]

_NULL_LIKE: FrozenSet[str] = frozenset({"\\n", "", "null", "none"})


def _normalize(value: Any) -> str:
    """Canonical lower-case string used for group lookup."""
    if value is None:
        return "null"
    if isinstance(value, (list, tuple)):
        if len(value) == 0:
            return "[]"
        # An array of nothing-but-absence is itself absence.
        if all(_normalize(v) in _NULL_LIKE for v in value):
            return "null"
        return str(value).lower()
    if isinstance(value, dict):
        return "{}" if len(value) == 0 else str(value).lower()
    return str(value).strip().lower()


def _null_safe_equal(a: Any, b: Any) -> bool:
    """Equality that treats two NULLs, and two NaNs, as the same value."""
    if a is None and b is None:
        return True
    if a is None or b is None:
        return False
    try:
        if a != a and b != b:  # NaN != NaN by IEEE-754
            return True
    except (TypeError, ValueError):
        pass
    try:
        return bool(a == b)
    except (TypeError, ValueError):
        return False


def globally_equivalent(a: Any, b: Any) -> bool:
    """True when two values differ only in how they spell absence.

    The equality check is not redundant even though callers arrive here with
    values that already compared unequal: the element-wise recursion below
    reaches sub-values that ARE equal, and without this they would be judged
    different and disqualify the whole row.
    """
    if _null_safe_equal(a, b):
        return True
    na, nb = _normalize(a), _normalize(b)
    if any(na in group and nb in group for group in _GROUPS):
        return True
    if (
        isinstance(a, (list, tuple))
        and isinstance(b, (list, tuple))
        and len(a) == len(b)
        and len(a) > 0
    ):
        return all(globally_equivalent(ai, bi) for ai, bi in zip(a, b))
    return False
