"""The shipped BCV schema-parity cases, exercised end to end without a cluster.

Loads examples/cases_bcv/schema_parity.yaml through the real discovery and
case-building path, then runs it against a stubbed describe_source. That
covers everything except the network hop: YAML shape, schema_check dispatch,
ignore_columns handling, and -- the point of the exercise -- that a
ComparisonResult buckets columns the same way BCV Analyzer's status column
does.

The status mapping asserted here was validated against the BCV analyser's own
output before that tool was removed from the repo -- BCV/output/request_result.csv
as of commit 9e9281a, whose 1728 rows split 936 DIFF / 790 MATCHED / 2 TYPE
DIFF, with 901 DIFFs having an empty bcv_field and 35 an empty src_field:

    DIFF (bcv_field empty)  -> columns_only_in_expected
    DIFF (src_field empty)  -> columns_only_in_actual
    MATCHED - TYPE DIFF     -> type_mismatches
    MATCHED                 -> compared_columns
"""

import os

import pytest

from rowparity import schema_check as sc
from rowparity.cases import discover_cases
from rowparity.schema_check import SchemaCheckCase

# The schema case FILE, not the directory. cases_bcv/ also holds value_parity
# .yaml, whose param_queries: block resolves ${batch_id} by querying the
# warehouse -- loading the whole directory here would try to reach Trino.
CASES_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "examples",
    "cases_bcv",
    "schema_parity.yaml",
)

# Shaped after the live staging probe: a shared core, a SRC-only column, a
# BCV-only column, and the real nested int-width mismatch that run found.
SRC_SCHEMA = {
    "request__transaction_id": "varchar",
    "request__timestamp": "timestamp(3)",
    "request__context__network_id": "bigint",
    "execution_networks__phase_metrics__value": "array(array(array(bigint)))",
    "data_partition": "varchar",
    "__file_size__": "bigint",
}
BCV_SCHEMA = {
    "request__transaction_id": "varchar",
    "request__timestamp": "timestamp(3)",
    "request__context__network_id": "bigint",
    "execution_networks__phase_metrics__value": "array(array(array(integer)))",
    "bcv_only_marker": "varchar",
}


@pytest.fixture
def stub_describe(monkeypatch):
    """Answer describe_source() from the table name, no connection made."""
    seen = []

    def _fake(spec, base_dir=".", variables=None):
        seen.append(spec)
        table = spec.get("table", "")
        if table.startswith("mrm_log_flat."):
            return dict(SRC_SCHEMA)
        if table.startswith("etl."):
            return dict(BCV_SCHEMA)
        raise AssertionError(f"unexpected table: {table!r}")

    monkeypatch.setattr(sc, "describe_source", _fake)
    return seen


def _case(name: str) -> SchemaCheckCase:
    for case in discover_cases(CASES_FILE):
        if case.name == name:
            return case
    raise AssertionError(f"case {name!r} not found in {CASES_FILE}")


def _schema_cases():
    return discover_cases(CASES_FILE)


class TestShippedCasesLoad:
    def test_all_three_tables_are_discovered(self):
        names = {c.name for c in _schema_cases()}
        assert names == {"bcv_request_schema", "bcv_slot_schema", "bcv_ad_schema"}

    def test_they_build_as_schema_check_cases(self):
        for case in _schema_cases():
            assert isinstance(case, SchemaCheckCase), case.name

    def test_request_case_points_at_the_right_tables(self):
        case = _case("bcv_request_schema")
        assert case.expected == {"type": "trino", "table": "mrm_log_flat.default.request"}
        assert case.actual == {"type": "trino", "table": "etl.public_test1.request"}
        assert "bcv" in case.tags

    def test_catalog_and_schema_are_switchable_without_editing_yaml(self):
        # The BCV target may be a test table today and the real one later;
        # that has to be a flag, not an edit per case.
        cases = {c.name: c for c in discover_cases(CASES_FILE, {"bcv_schema": "public"})}
        assert cases["bcv_request_schema"].actual["table"] == "etl.public.request"
        assert cases["bcv_slot_schema"].actual["table"] == "etl.public.slot"
        # The SRC side is untouched by that override.
        assert cases["bcv_request_schema"].expected["table"] == "mrm_log_flat.default.request"

    def test_no_case_is_tagged_xfail(self):
        # xfail would invert the signal: green while columns are missing, red
        # once the migration finally completes. See the note in the YAML.
        for case in _schema_cases():
            assert "xfail" not in case.tags, case.name


class TestStatusMapping:
    def test_buckets_match_bcv_analyzer_statuses(self, stub_describe):
        result = _case("bcv_request_schema").run()

        # DIFF with an empty bcv_field -> SRC has it, BCV does not.
        # __file_size__ is also SRC-only but is excluded via exclude.csv, so it
        # does not appear here -- see TestStorageMetadataExclusion below.
        assert result.columns_only_in_expected == ["data_partition"]
        # DIFF with an empty src_field -> BCV has it, SRC does not.
        assert result.columns_only_in_actual == ["bcv_only_marker"]
        # MATCHED - TYPE DIFF
        assert result.type_mismatches == [
            (
                "execution_networks__phase_metrics__value",
                "array(array(array(bigint)))",
                "array(array(array(integer)))",
            )
        ]
        # MATCHED (the type-diff column is common, so it is compared too --
        # matching BCV, which also feeds TYPE DIFF columns into validation).
        assert result.compared_columns == [
            "execution_networks__phase_metrics__value",
            "request__context__network_id",
            "request__timestamp",
            "request__transaction_id",
        ]

    def test_storage_metadata_is_excluded_not_reported(self, stub_describe):
        # __file_size__ exists on SRC and has no place in the BCV layout. Left
        # in, it is a permanent DIFF on every table that never gets resolved --
        # which is why BCV kept exclude.csv. Proven by removing the exclusion
        # below, so this cannot pass because the stub forgot the column.
        result = _case("bcv_request_schema").run()
        assert "__file_size__" not in result.columns_only_in_expected
        assert "__file_size__" not in result.compared_columns
        assert "__file_size__" not in result.expected_schema

        case = _case("bcv_request_schema")
        case.ignore_columns_file = None
        case.ignore_columns_table = None
        bare = case.run()
        assert "__file_size__" in bare.columns_only_in_expected

    def test_reports_different_while_bcv_lags(self, stub_describe):
        # The honest answer during a migration: not equivalent yet.
        assert _case("bcv_request_schema").run().equivalent is False

    def test_fetches_zero_rows(self, stub_describe):
        result = _case("bcv_request_schema").run()
        assert result.expected_rows == 0
        assert result.actual_rows == 0

    def test_only_describe_is_used_and_only_twice(self, stub_describe):
        _case("bcv_request_schema").run()
        assert len(stub_describe) == 2
        assert all(spec["type"] == "trino" for spec in stub_describe)

    def test_ignore_columns_narrows_to_unresolved_gaps(self, stub_describe, tmp_path):
        # The exclude.csv equivalent: accepted gaps drop out of the report.
        case = _case("bcv_request_schema")
        case.ignore_columns = ["__file_size__", "data_partition", "bcv_only_marker"]
        result = case.run()
        assert result.columns_only_in_expected == []
        assert result.columns_only_in_actual == []
        # The type mismatch is a real finding and must survive.
        assert len(result.type_mismatches) == 1
        assert result.equivalent is False
