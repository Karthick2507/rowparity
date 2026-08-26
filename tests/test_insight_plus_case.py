"""The shipped Hoover / Hoover++ parity case.

Offline only -- no connection is made. These assert the wiring: that the case
loads, that each side resolves to the right query against the right catalog,
and that the batch parameter cannot be skipped.

That last one carries the most weight. The query files are templated by another
system and carry ``${arena.presto.var.process_batch_id}``. Until dotted names
were recognised, that placeholder matched nothing, so it was neither
substituted nor reported unresolved -- the literal text reached Presto inside
quotes as a syntactically valid predicate matching no batch. Both sides
returned zero rows, the multiset diff found nothing missing and nothing added,
and the run reported EQUIVALENT. A green result proving nothing is the worst
outcome available to a verification tool, so it gets tests.
"""
import os

import pytest
import yaml

from rowparity.cases import Case, discover_cases
from rowparity.params import ParamError
from rowparity.sources import resolve_query

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES_DIR = os.path.join(REPO, "scripts", "cases_insight_plus")
CASE_FILE = os.path.join(CASES_DIR, "f_demand_portfolio_hourly.yaml")
BATCH = "20260812010000"
BATCH_PARAM = "arena.presto.var.process_batch_id"
PARAMS = {BATCH_PARAM: BATCH}


def _case(params=PARAMS) -> Case:
    for case in discover_cases(CASES_DIR, params):
        if case.name == "f_demand_portfolio_hourly":
            return case
    raise AssertionError(f"case not found in {CASES_DIR}")


def _sql(case: Case, side: str) -> str:
    spec = case.expected if side == "expected" else case.actual
    return resolve_query(spec, os.path.dirname(case.source_file), case.variables)


@pytest.fixture(scope="module")
def sql_files_present():
    if not os.path.isdir(os.path.join(REPO, "sql", "insight_plus")):
        pytest.skip("sql/insight_plus not present")


class TestWiring:
    def test_case_loads(self, sql_files_present):
        assert _case().name == "f_demand_portfolio_hourly"

    def test_it_is_a_row_case_not_a_schema_check(self, sql_files_present):
        # Column status falls out of the row comparison; a separate zero-row
        # schema pass would be a second execution of a 2000-line aggregate for
        # information the row result already carries.
        case = _case()
        assert isinstance(case, Case)
        assert case.expected["type"] == "trino"
        assert case.actual["type"] == "trino"

    def test_default_engine_not_pushdown(self, sql_files_present):
        # Push-down re-executes the source query about four times per side.
        # For an aggregate this expensive that is the wrong trade, and the
        # Trino push-down path has never been run against a live cluster.
        assert _case().engine is None

    def test_each_side_reads_its_own_catalog(self, sql_files_present):
        case = _case()
        expected, actual = _sql(case, "expected"), _sql(case, "actual")
        assert "mrm_log_flat.default" in expected
        assert "etl.public_test1" not in expected
        assert "etl.public_test1" in actual
        assert "mrm_log_flat.default" not in actual

    def test_both_sides_carry_the_sampling_filter(self, sql_files_present):
        # Hoover++ was originally unsampled, on the understanding that its
        # source was already the bit-59 sample. A live run disproved that:
        # 2,719 rows against 1,113,423, a ratio of 409. Comparing a sampled
        # side against an unsampled one measures the sampling, not the
        # migration.
        case = _case()
        assert _sql(case, "expected").count("--sampling filter") == 3
        assert _sql(case, "actual").count("--sampling filter") == 3


class TestBatchParameter:
    def test_it_substitutes_on_both_sides(self, sql_files_present):
        case = _case()
        for side in ("expected", "actual"):
            sql = _sql(case, side)
            assert f"process_batch_id = '{BATCH}'" in sql, side
            assert BATCH_PARAM not in sql, f"{side} still carries the placeholder"

    def test_omitting_it_raises_rather_than_running(self, sql_files_present):
        # The false-pass guard. Silence here is what produced a green run over
        # zero rows.
        case = _case(params={})
        with pytest.raises(ParamError) as exc:
            _sql(case, "expected")
        assert BATCH_PARAM in str(exc.value)

    def test_the_yaml_ships_no_default_batch(self, sql_files_present):
        # A literal default would name a batch that ages out, and an aged-out
        # batch returns zero rows on both sides -- equivalent, and meaningless.
        with open(CASE_FILE, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
        assert BATCH_PARAM not in (doc.get("vars") or {})
        for case in doc["cases"]:
            assert BATCH_PARAM not in (case.get("vars") or {})


class TestComparisonSettings:
    def test_keyless(self, sql_files_present):
        # An aggregate: no row-level identifier survives the GROUP BY. Keyless
        # detects any difference but reports it as missing + added, never as
        # "changed", because without a key rows cannot be paired.
        assert "keys" not in _case().compare
        assert _case().config().keys is None

    def test_source_ordered_arrays_are_compared_unordered(self, sql_files_present):
        # rowparity treats list as ORDERED. These two reach the output straight
        # from the source, where Presto guarantees no element order, so without
        # this an ordering difference reads as a data difference.
        unordered = set(_case().config().unordered_list_columns)
        assert {"global_advertiser_ids", "global_brand_ids"} <= unordered

    def test_float_tolerance_is_unset(self, sql_files_present):
        # Deliberately exact until a live run shows whether the metrics are
        # DECIMAL. Loosening later is easy; discovering it was loosened for no
        # reason is not.
        assert "float_tolerance" not in _case().compare

    def test_examples_are_bounded(self, sql_files_present):
        # 100k rows of diff would be unreadable and would bloat every report.
        assert _case().config().max_examples == 50
