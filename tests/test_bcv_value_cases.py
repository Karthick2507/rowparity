"""The shipped BCV value-parity cases, checked without a cluster.

What can be verified offline is the part most likely to be wrong: the SQL the
cases generate. In particular the correctness argument for independent
sampling rests entirely on both sides applying an IDENTICAL, deterministic
predicate -- if those two expressions ever drift apart, every row looks
missing and the failure looks like a data defect rather than a bug here.
"""

import os
import re

import pytest

from rowparity.cases import Case, discover_cases
from rowparity.params import ParamError
from rowparity.sources import resolve_query

CASES_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "examples", "cases_bcv"
)
BATCH = "20260812130000"
PARAMS = {"batch_id": BATCH}

# The deterministic sample: a pure function of the join key.
SAMPLE_RE = re.compile(
    r"abs\(from_big_endian_64\(xxhash64\(to_utf8\(request__transaction_id\)\)\)\)\s*%\s*(\d+)\s*=\s*0"
)


def _case(name, params=PARAMS) -> Case:
    for case in discover_cases(CASES_DIR, params):
        if case.name == name:
            return case
    raise AssertionError(f"case {name!r} not found")


def _sql(case, side):
    spec = getattr(case, side)
    return resolve_query(spec, os.path.dirname(case.source_file), case.variables)


class TestBatchIdResolution:
    """batch_id is never defaulted to a literal. It is either pinned by the
    caller or resolved by querying the warehouse for the newest batch present
    on both sides. A literal default would name a batch that may not exist,
    return zero rows on both sides, and report EQUIVALENT -- a silent pass.
    """

    def test_a_param_query_is_declared_for_it(self):
        import yaml

        doc = yaml.safe_load(open(os.path.join(CASES_DIR, "value_parity.yaml")))
        assert "batch_id" in doc["param_queries"]
        assert doc["param_queries"]["batch_id"]["type"] == "trino"
        # And it is NOT also a literal default, which would shadow the query.
        assert "batch_id" not in doc["vars"]

    def test_pinning_it_short_circuits_the_query(self, monkeypatch):
        # --param must skip the query entirely rather than run it and discard
        # the answer. Any connection attempt here is a failure.
        import socket

        def _boom(*args, **kwargs):
            raise AssertionError("the param query ran despite batch_id being pinned")

        monkeypatch.setattr(socket.socket, "connect", _boom)
        names = {c.name for c in discover_cases(CASES_DIR, PARAMS)}
        assert {"bcv_request_completeness", "bcv_request_values"} <= names

    def test_without_it_the_sql_still_cannot_reach_an_engine_unresolved(self, monkeypatch):
        # With query resolution disabled and nothing pinned, the placeholder in
        # the .sql file must raise rather than be substituted with anything.
        import socket

        def _boom(*args, **kwargs):
            raise AssertionError("a connection was attempted before validating parameters")

        monkeypatch.setattr(socket.socket, "connect", _boom)

        cases = discover_cases(CASES_DIR, {}, resolve_queries=False)
        case = next(c for c in cases if c.name == "bcv_request_values")
        with pytest.raises(ParamError) as exc:
            case.run()
        message = str(exc.value)
        assert "batch_id" in message
        assert "src_request_values.sql" in message  # names the offending file

    def test_listing_never_runs_the_query(self, monkeypatch):
        # `rowparity list` passes resolve_queries=False for exactly this reason.
        import socket

        def _boom(*args, **kwargs):
            raise AssertionError("listing cases attempted a connection")

        monkeypatch.setattr(socket.socket, "connect", _boom)
        cases = discover_cases(CASES_DIR, {}, resolve_queries=False)
        assert {c.name for c in cases} >= {"bcv_request_values", "bcv_request_schema"}


class TestSamplingIsIdenticalOnBothSides:
    @pytest.mark.parametrize("case_name", ["bcv_request_completeness", "bcv_request_values"])
    def test_both_sides_use_the_same_modulus(self, case_name):
        case = _case(case_name)
        exp_moduli = SAMPLE_RE.findall(_sql(case, "expected"))
        act_moduli = SAMPLE_RE.findall(_sql(case, "actual"))
        assert exp_moduli, "expected side lost its sampling predicate"
        assert act_moduli, "actual side lost its sampling predicate"
        # Every occurrence, on both sides, must agree -- including the ones
        # inside the semi-join subquery.
        assert set(exp_moduli) == set(act_moduli) == {"1000"}

    def test_modulus_is_parameterised(self):
        case = _case("bcv_request_values", {**PARAMS, "sample_modulus": "50"})
        assert set(SAMPLE_RE.findall(_sql(case, "expected"))) == {"50"}
        assert set(SAMPLE_RE.findall(_sql(case, "actual"))) == {"50"}

    def test_sampling_keys_off_the_join_key(self):
        # Sampling on anything else would not be reproducible across the sides.
        for side in ("expected", "actual"):
            sql = _sql(_case("bcv_request_values"), side)
            assert "xxhash64(to_utf8(request__transaction_id))" in sql


class TestBatchColumnsDifferPerSide:
    def test_src_uses_process_batch_id_and_bcv_uses_batch_id(self):
        case = _case("bcv_request_values")
        src, bcv = _sql(case, "expected"), _sql(case, "actual")
        assert f"process_batch_id = '{BATCH}'" in src
        assert f"batch_id = '{BATCH}'" in bcv
        # The BCV side must not use SRC's column name.
        bcv_body = bcv.split("IN (")[0]
        assert "process_batch_id" not in bcv_body


class TestIntersectionPinning:
    def test_value_case_pins_each_side_to_the_other(self):
        case = _case("bcv_request_values")
        src, bcv = _sql(case, "expected"), _sql(case, "actual")
        # SRC side semi-joins to BCV, and vice versa.
        assert "IN (" in src and "etl.public_test1.request" in src
        assert "IN (" in bcv and "mrm_log_flat.default.request" in bcv

    def test_completeness_case_does_not_pin(self):
        # Pinning here would define away the very thing it measures.
        case = _case("bcv_request_completeness")
        for side in ("expected", "actual"):
            assert "IN (" not in _sql(case, side)

    def test_completeness_reads_only_the_key_column(self):
        case = _case("bcv_request_completeness")
        for side in ("expected", "actual"):
            sql = _sql(case, side)
            assert "SELECT request__transaction_id" in sql
            assert "SELECT *" not in sql

    def test_value_case_selects_star_so_the_intersection_decides(self):
        # Naming 800 columns here would need re-editing whenever BCV gains one;
        # rowparity compares the intersection instead.
        case = _case("bcv_request_values")
        for side in ("expected", "actual"):
            assert "SELECT *" in _sql(case, side)


class TestCaseConfiguration:
    def test_both_cases_are_keyed_on_the_transaction_id(self):
        for name in ("bcv_request_completeness", "bcv_request_values"):
            assert _case(name).compare["keys"] == ["request__transaction_id"]

    def test_both_sides_are_trino_sources(self):
        for name in ("bcv_request_completeness", "bcv_request_values"):
            case = _case(name)
            assert case.expected["type"] == "trino"
            assert case.actual["type"] == "trino"

    def test_default_engine_not_pushdown(self):
        # Push-down has never been run against a live cluster; the sampled
        # populations here are small enough not to need it.
        for name in ("bcv_request_completeness", "bcv_request_values"):
            assert _case(name).engine is None

    def test_neither_case_is_tagged_xfail(self):
        for name in ("bcv_request_completeness", "bcv_request_values"):
            assert "xfail" not in _case(name).tags

    def test_value_case_leaves_float_tolerance_exact(self):
        # Both sides come from one engine; loosening this would mask findings.
        assert "float_tolerance" not in _case("bcv_request_values").compare

    def test_catalogs_are_switchable(self):
        case = _case("bcv_request_values", {**PARAMS, "bcv_schema": "public"})
        assert "etl.public.request" in _sql(case, "actual")
