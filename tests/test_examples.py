"""End-to-end test over the shipped YAML example cases.

This is the pattern a QA team copies into their own repo: point ``CASES_DIR`` at
their cases folder and let pytest parametrise over every case. Cases tagged
``xfail`` are expected to differ (they demonstrate a caught regression).
"""
import os
import subprocess
import sys

import pytest

from rowparity.runner import assert_case, load_cases

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CASES_DIR = os.environ.get("ROWPARITY_CASES", os.path.join(ROOT, "examples", "cases"))


@pytest.fixture(scope="session", autouse=True)
def _build_example_data():
    """Build all example warehouses + parquet snapshots once before any case runs."""
    subprocess.run(
        [sys.executable, os.path.join(ROOT, "examples", "build_example_data.py")],
        check=True,
    )
    subprocess.run(
        [sys.executable, os.path.join(ROOT, "examples", "build_tpch_data.py")],
        check=True,
    )


def _all_cases():
    return load_cases(CASES_DIR)


@pytest.mark.parametrize("case", _all_cases(), ids=lambda c: c.name)
def test_case(case, request):
    if "xfail" in case.tags:
        result = case.run()
        assert not result.equivalent, (
            f"case '{case.name}' is tagged xfail but the tables were equivalent"
        )
    else:
        assert_case(case)
