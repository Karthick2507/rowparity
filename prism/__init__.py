"""PRISM — derive a rowparity case from the query it compares.

You write the parity SQL. PRISM reads it and generates the case YAML, the two
test files and the drill-down skeleton, because all four are implied by the
query: the keys ARE its GROUP BY dimensions, the breakdown column IS the one
dimension that is a distinct literal per UNION branch, the unordered arrays ARE
the ones reaching the output from a source column.

Separate from ``rowparity`` on purpose. rowparity runs comparisons; PRISM writes
the files that describe one. Nothing in ``src/rowparity`` imports this, so the
existing flow is untouched whether PRISM works or not.
"""

from .analyse import QueryProfile, analyse
from .generate import planned_outputs, render_all
from .rules import derive_row_summary

__all__ = [
    "analyse", "QueryProfile", "render_all", "planned_outputs", "derive_row_summary",
]
