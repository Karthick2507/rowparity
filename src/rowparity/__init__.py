"""rowparity — fingerprint-based expected-vs-actual data testing for CI.

Public API::

    from rowparity import compare_tables, CompareConfig
    from rowparity.sources import load_source
    from rowparity.cases import discover_cases
    from rowparity.report import render_console

    result = compare_tables(expected_arrow_table, actual_arrow_table,
                            CompareConfig(keys=["id"], float_tolerance=1e-9))
    assert result.equivalent, render_console(result)
"""
from .compare import (
    ColumnDiff,
    CompareConfig,
    ComparisonResult,
    RowDiff,
    compare_tables,
)
from .hashing import CanonConfig, canon_row, canon_value, row_digest

__all__ = [
    "compare_tables",
    "CompareConfig",
    "ComparisonResult",
    "ColumnDiff",
    "RowDiff",
    "CanonConfig",
    "canon_value",
    "canon_row",
    "row_digest",
]

__version__ = "0.1.0"
