"""Glue for running cases under pytest.

QA writes essentially no Python: a one-line test module parametrises over the
YAML cases and calls :func:`assert_case`. On failure the assertion message is the
full human-readable diff, so the pytest output alone tells you what broke.
"""
from __future__ import annotations

from typing import List

from .cases import Case, discover_cases
from .compare import ComparisonResult
from .report import render_console


def load_cases(path: str) -> List[Case]:
    return discover_cases(path)


def assert_case(case: Case) -> ComparisonResult:
    """Run a case and fail loudly (with a full diff) if the tables are not equivalent."""
    result = case.run()
    if not result.equivalent:
        try:
            import pytest

            pytest.fail(render_console(result, case.name), pytrace=False)
        except ImportError:  # pragma: no cover - allow use outside pytest
            raise AssertionError(render_console(result, case.name)) from None
    return result
