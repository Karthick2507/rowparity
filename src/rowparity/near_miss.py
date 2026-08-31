"""Which single key column stopped two rows from pairing.

A keyed comparison pairs rows on the whole key. If one key column drifts, the
pair is destroyed: the row cannot match, so it is reported as **one missing row
plus one added row** -- the same logical row, counted twice, as a structural
difference. Nothing in the output says the two are related.

That failure is easy to spot in aggregate once you know to look. A run
reporting 149 missing against 208 added is suspiciously balanced for genuine
data loss, and balance is the signature of a key that stopped matching rather
than rows that stopped existing.

This finds the column responsible. For each key column in turn, drop it and
re-pair what is left. If dropping ``event_date`` suddenly pairs 137 of the 149
missing rows with added rows, the answer is not "137 rows were lost", it is
"137 rows moved to a different hour" -- a completely different defect, with a
completely different fix.

**No warehouse query is involved.** It works on the key tuples the comparison
already built, so it costs a few hundred set operations and answers a question
that would otherwise take a round of manual drill-down queries per row.

Two honest limits:

* It only tries dropping **one** column at a time. Two columns drifting
  together are not found, and saying so is better than silently reporting
  nothing.
* A pairing is only reported when it is unambiguous. If dropping a column makes
  three missing rows match three added rows as a group, no individual pairing
  is claimed -- the count of ambiguous groups is reported separately instead.
"""
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence, Tuple


def _unwrap(value: Any) -> Any:
    """Canonical form -> something readable.

    Key elements are type-tagged tuples: ``('i', 516429)``, ``('t', 'midroll')``,
    ``('L', (('i', 34007),))``. Reported raw they are unreadable, and the tag is
    noise to anyone reading a report rather than debugging the hasher.
    """
    if isinstance(value, tuple) and len(value) >= 2 and isinstance(value[0], str):
        tag, payload = value[0], value[1]
        if tag in ("L", "Lu", "M", "S"):
            return [_unwrap(v) for v in payload] if isinstance(payload, tuple) else payload
        return payload
    return value


@dataclass
class NearMissPair:
    """One missing row and one added row that differ in a single key column."""
    column: str
    expected_value: Any
    actual_value: Any


@dataclass
class NearMissColumn:
    """What dropping one column from the key achieved."""
    column: str
    pairs: int = 0
    ambiguous_groups: int = 0
    examples: List[NearMissPair] = field(default_factory=list)

    def share_of(self, missing_count: int) -> float:
        return (self.pairs / missing_count) if missing_count else 0.0


@dataclass
class NearMissResult:
    columns: List[NearMissColumn] = field(default_factory=list)
    missing_rows: int = 0
    added_rows: int = 0
    # True when only the first max_rows missing rows were examined, so the
    # pair counts describe a subset of them. The added side is never capped --
    # see analyse() for why.
    truncated: bool = False

    @property
    def best(self) -> Optional[NearMissColumn]:
        return self.columns[0] if self.columns else None

    def explained(self, missing_count: int) -> float:
        return self.best.share_of(missing_count) if self.best else 0.0


# Analysis is O(columns x rows). At 83 columns and a few hundred rows that is
# nothing; at 83 columns and a million rows it is a stall with no progress
# output. Cap it and say so rather than appearing to hang.
MAX_ROWS = 20_000
MAX_EXAMPLES = 5


def analyse(
    missing_keys: Sequence[Tuple],
    added_keys: Sequence[Tuple],
    key_columns: Sequence[str],
    *,
    max_rows: int = MAX_ROWS,
    max_examples: int = MAX_EXAMPLES,
) -> NearMissResult:
    """Find key columns whose removal pairs missing rows with added rows."""
    result = NearMissResult(missing_rows=len(missing_keys), added_rows=len(added_keys))
    if not missing_keys or not added_keys or len(key_columns) < 2:
        # Nothing to pair, or a single-column key -- dropping it would pair
        # everything with everything, which is true and useless.
        return result

    # Cap the MISSING side only. The added side is the lookup index, and both
    # lists come from unordered sets -- truncating both independently would
    # discard each kept missing row's partner at random and report "0 pairs",
    # which is worse than slow: it is a confident wrong answer. Capping one
    # side keeps every examined row's chance of pairing intact, so the number
    # means "of the N examined, X paired".
    if len(missing_keys) > max_rows:
        missing_keys = list(missing_keys)[:max_rows]
        result.truncated = True

    for position, column in enumerate(key_columns):
        stats = NearMissColumn(column=column)

        # Index both sides by the key with this one column removed. A row from
        # each side landing in the same bucket means they agree on the other 82
        # columns and differ only here.
        added_by_rest: Dict[Tuple, List[Tuple]] = defaultdict(list)
        for key in added_keys:
            added_by_rest[key[:position] + key[position + 1:]].append(key)

        for key in missing_keys:
            rest = key[:position] + key[position + 1:]
            candidates = added_by_rest.get(rest)
            if not candidates:
                continue
            if len(candidates) > 1:
                # Several added rows agree on the other columns, so which one
                # this missing row "is" cannot be decided. Counting it as a
                # pair would be a guess presented as a finding.
                stats.ambiguous_groups += 1
                continue
            stats.pairs += 1
            if len(stats.examples) < max_examples:
                stats.examples.append(
                    NearMissPair(
                        column=column,
                        expected_value=_unwrap(key[position]),
                        actual_value=_unwrap(candidates[0][position]),
                    )
                )

        if stats.pairs or stats.ambiguous_groups:
            result.columns.append(stats)

    result.columns.sort(key=lambda c: (-c.pairs, -c.ambiguous_groups, c.column))
    return result
