"""Every check scripts/cases_biz_service.yaml and its SQL need, in one file.

Mirrors tests/test_insight_plus_sql_sync.py's shape and reasons, adapted for
the biz_service pipeline: one case per batch SQL file, keys classified from
that batch's own conf.yml rather than an aggregate-function scan, no
drilldown block (biz_service cases do not generate one).

Discovers every case in scripts/cases_biz_service.yaml and parametrizes over
the result, so a new batch is covered the moment `python -m prism generate`
folds its cases into that file -- nothing here to edit when a batch is added.

Offline only -- no connection is made, ever.
"""

from __future__ import annotations

import os
import re

import pytest

from rowparity.cases import Case, discover_cases
from rowparity.params import _PLACEHOLDER, ParamError, merge_side_vars
from rowparity.sources import resolve_query

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES_FILE = os.path.join(REPO, "scripts", "cases_biz_service.yaml")

# A syntactically valid batch id, used only to prove substitution WORKS. No
# query here is ever executed against it.
BATCH = "20260812010000"


def _discover(params):
    if not os.path.isfile(CASES_FILE):
        return []
    return discover_cases(CASES_FILE, params, resolve_queries=False)


try:
    _UNPARAMETRISED_CASES = _discover({})
    _DISCOVERY_ERROR = None
except Exception as exc:  # noqa: BLE001 -- reported as a test failure, not swallowed
    _UNPARAMETRISED_CASES = []
    _DISCOVERY_ERROR = exc

CASE_NAMES = [c.name for c in _UNPARAMETRISED_CASES]


def test_the_case_file_loads_at_all():
    """If this fails, every other test in this file was SKIPPED, not run."""
    if _DISCOVERY_ERROR is not None:
        pytest.fail(str(_DISCOVERY_ERROR), pytrace=False)


def _find(name: str, params: dict) -> Case:
    for case in discover_cases(CASES_FILE, params, resolve_queries=False):
        if case.name == name:
            return case
    raise AssertionError(f"case {name!r} not found in {CASES_FILE}")


def _sql_path(case: Case, side: str) -> str:
    spec = case.expected if side == "expected" else case.actual
    qf = spec.get("query_file")
    assert qf, f"{case.name} [{side}]: no query_file -- inline queries aren't covered here"
    base_dir = os.path.dirname(case.source_file)
    return qf if os.path.isabs(qf) else os.path.join(base_dir, qf)


def _raw_sql(case: Case, side: str = "expected") -> str:
    with open(_sql_path(case, side), encoding="utf-8") as fh:
        return fh.read()


def _sql(case: Case, side: str) -> str:
    """One side's SQL, resolved exactly as load_source would."""
    spec = case.expected if side == "expected" else case.actual
    variables = merge_side_vars(spec.get("vars"), case.variables)
    return resolve_query(spec, os.path.dirname(case.source_file), variables)


@pytest.mark.parametrize("name", CASE_NAMES)
class TestWiring:
    def test_case_loads(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        assert case.expected.get("query_file")
        assert case.actual.get("query_file")

    def test_keys_are_non_empty(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        assert case.compare.get("keys"), f"{name}: no compare.keys -- case would be keyless"

    def test_facts_differ_between_sides(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        expected_facts = (case.expected.get("vars") or {}).get("facts")
        actual_facts = (case.actual.get("vars") or {}).get("facts")
        assert expected_facts and actual_facts and expected_facts != actual_facts, (
            f"{name}: expected/actual read the SAME facts catalog -- the run would "
            f"compare a table with itself and always pass"
        )

    def test_both_sides_resolve_with_a_batch_id(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        for side in ("expected", "actual"):
            sql = _sql(case, side)
            assert not _PLACEHOLDER.search(
                sql
            ), f"{name} [{side}]: unresolved placeholder(s) remain after substitution"

    def test_missing_batch_id_raises(self, name):
        case = _find(name, {})
        with pytest.raises(ParamError):
            _sql(case, "expected")


@pytest.mark.parametrize("name", CASE_NAMES)
class TestTheRawTemplate:
    """Scans the SQL TEXT directly -- the one thing case-shape checks can't see."""

    def test_no_hardcoded_facts_catalog_remains(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        raw = _raw_sql(case, "expected")
        assert "mrm_log_flat.default." not in raw, (
            f"{name}: a hardcoded facts reference survived generation -- both sides "
            f"would read the SAME table regardless of ${{facts}}"
        )

    def test_sampling_filter_is_present(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        raw = _raw_sql(case, "expected")
        assert "${sampling_filter}" in raw and "--sampling filter" in raw, (
            f"{name}: no sampling filter marker -- an unsampled read skews the "
            f"aggregate while the totals still look plausible"
        )

    def test_no_data_filter_token_remains(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        raw = _raw_sql(case, "expected")
        assert not re.search(
            r"\$\{DATA_FILTER_[A-Z_]+\}", raw
        ), f"{name}: an unresolved ${{DATA_FILTER_*}} token survived generation"
