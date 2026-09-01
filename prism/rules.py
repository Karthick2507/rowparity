"""The judgement calls, isolated.

Everything in ``analyse.py`` is a derivation: the keys ARE the GROUP BY
dimensions, the breakdown column IS the one that is a distinct literal per
branch. Those have one right answer and it is in the SQL.

What lives here does not. Grouping 83 dimensions into labelled buckets for a
report is a presentation choice, and two reasonable people would produce two
different groupings. Keeping it in a separate module with one entry point is
what makes it swappable later -- a model trained on a corpus of reviewed
groupings would replace ``derive_row_summary`` and touch nothing else.

Until then it is a rules table, and PRISM says so in the output rather than
presenting the result as derived fact.
"""

from __future__ import annotations

import re
from typing import Dict, List

# Ordered: the first pattern that claims a column wins, so specific groups come
# before general ones. `Reseller` before `Network` because a reseller id is also
# a network id in this schema, and the more specific label is the useful one.
SUMMARY_RULES = [
    ("Branch",      [r"_drop_off$", r"^process_stage$", r"^partition_key$"]),
    ("Batch",       [r"batch_id$", r"^event_date$"]),
    ("Reseller",    [r"^reseller_"]),
    ("Network",     [r"^network_id$", r"^content_owner_id$", r"^distributor_id$",
                     r"^site_id$", r"^site_section_id$"]),
    ("Ad identity", [r"^ad_id$", r"^creative_id$", r"^placement_id$", r"^deal_id$",
                     r"^dsp_id$", r"^market_ad_id$"]),
    ("Fill",        [r"fill_status$"]),
    ("Order",       [r"order_id$", r"^priority_", r"^sales_"]),
    ("Placement",   [r"time_position", r"^supply_source", r"ad_unit_ids$"]),
]

# A group with more than this many columns stops being a summary. The report's
# Detail column has one line per group; five values on a line is already dense.
MAX_PER_GROUP = 5


def derive_row_summary(dimensions: List[str],
                       max_per_group: int = MAX_PER_GROUP) -> List[Dict]:
    """Group dimensions into labelled buckets for the report's Detail column.

    Without this the report prints a 262-column dict truncated after the first
    four, which tells a reader nothing about which row they are looking at.

    Returns ``[{"label": str, "columns": [str]}]``. A column is claimed by at
    most one group; anything no rule matches is simply left out, because a
    summary that lists everything is not a summary.

    **This is the ML seam.** A classifier replacing this function would take the
    same argument and return the same shape. Nothing else in PRISM would change.
    """
    claimed, out = set(), []
    for label, patterns in SUMMARY_RULES:
        cols = [
            d for d in dimensions
            if d not in claimed and any(re.search(p, d, re.I) for p in patterns)
        ]
        if cols:
            cols = cols[:max_per_group]
            claimed.update(cols)
            out.append({"label": label, "columns": cols})
    return out


def coverage(dimensions: List[str], summary: List[Dict]) -> float:
    """Fraction of dimensions the rules managed to place.

    Reported rather than acted on. Low coverage is not an error -- a summary is
    meant to be selective -- but it is the number that would justify replacing
    these rules with something trained.
    """
    if not dimensions:
        return 0.0
    placed = sum(len(g["columns"]) for g in summary)
    return placed / len(dimensions)
