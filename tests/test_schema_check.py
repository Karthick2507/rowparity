"""schema_check.py — schema-only parity between two sources."""
import os
import tempfile

import pytest

from rowparity.cases import load_cases_from_file
from rowparity.schema_check import (
    SchemaCheckCase,
    SchemaCheckError,
    build_schema_check_case,
    run_schema_check,
)

# ---------------------------------------------------------------------------
# run_schema_check — pure logic, no connection needed
# ---------------------------------------------------------------------------

def _inline(schema: dict) -> dict:
    """Inline source spec whose schema is explicitly declared."""
    return {"type": "inline", "rows": [], "schema": schema}


class TestRunSchemaCheck:
    def test_identical_schemas_are_equivalent(self):
        result = run_schema_check(
            _inline({"id": "int64", "name": "string"}),
            _inline({"id": "int64", "name": "string"}),
        )
        assert result.equivalent
        assert result.columns_only_in_expected == []
        assert result.columns_only_in_actual == []
        assert result.type_mismatches == []

    def test_column_only_in_expected(self):
        result = run_schema_check(
            _inline({"id": "int64", "old_col": "string"}),
            _inline({"id": "int64"}),
        )
        assert not result.equivalent
        assert result.columns_only_in_expected == ["old_col"]
        assert result.columns_only_in_actual == []

    def test_column_only_in_actual(self):
        result = run_schema_check(
            _inline({"id": "int64"}),
            _inline({"id": "int64", "new_col": "string"}),
        )
        assert not result.equivalent
        assert result.columns_only_in_actual == ["new_col"]
        assert result.columns_only_in_expected == []

    def test_type_mismatch_detected(self):
        result = run_schema_check(
            _inline({"id": "int64", "amount": "int64"}),
            _inline({"id": "int64", "amount": "double"}),
        )
        assert not result.equivalent
        assert result.type_mismatches == [("amount", "int64", "double")]

    def test_multiple_drifts_all_reported(self):
        result = run_schema_check(
            _inline({"id": "int64", "a": "string", "gone": "bool"}),
            _inline({"id": "int64", "a": "int64", "new": "string"}),
        )
        assert not result.equivalent
        assert result.columns_only_in_expected == ["gone"]
        assert result.columns_only_in_actual == ["new"]
        assert result.type_mismatches == [("a", "string", "int64")]

    def test_ignore_columns_excluded_from_all_checks(self):
        result = run_schema_check(
            _inline({"id": "int64", "loaded_at": "string", "val": "int64"}),
            _inline({"id": "int64", "val": "double"}),
            ignore_columns=["loaded_at"],
        )
        # loaded_at is only in expected but ignored — should not appear in only_exp
        assert "loaded_at" not in result.columns_only_in_expected
        # val type mismatch still caught
        assert result.type_mismatches == [("val", "int64", "double")]

    def test_ignore_columns_type_mismatch_suppressed(self):
        result = run_schema_check(
            _inline({"id": "int64", "ts": "string"}),
            _inline({"id": "int64", "ts": "timestamp[us]"}),
            ignore_columns=["ts"],
        )
        assert result.equivalent

    def test_no_rows_are_reported(self):
        result = run_schema_check(
            _inline({"id": "int64"}),
            _inline({"id": "int64"}),
        )
        assert result.expected_rows == 0
        assert result.actual_rows == 0
        assert result.missing_count == 0
        assert result.added_count == 0
        assert result.changed_count == 0

    def test_compared_columns_is_intersection(self):
        result = run_schema_check(
            _inline({"id": "int64", "a": "string", "b": "int64"}),
            _inline({"id": "int64", "a": "string", "c": "int64"}),
        )
        assert sorted(result.compared_columns) == ["a", "id"]

    def test_empty_both_sides_equivalent(self):
        result = run_schema_check(_inline({}), _inline({}))
        assert result.equivalent

    def test_column_order_irrelevant(self):
        result = run_schema_check(
            _inline({"b": "string", "a": "int64"}),
            _inline({"a": "int64", "b": "string"}),
        )
        assert result.equivalent

    def test_results_sorted_alphabetically(self):
        result = run_schema_check(
            _inline({"z": "string", "a": "string", "m": "string"}),
            _inline({"z": "int64", "a": "int64"}),
        )
        assert result.columns_only_in_expected == ["m"]
        assert result.type_mismatches == [("a", "string", "int64"), ("z", "string", "int64")]


# ---------------------------------------------------------------------------
# SchemaCheckCase.run() — verifies the dataclass wiring
# ---------------------------------------------------------------------------

class TestSchemaCheckCase:
    def _make(self, exp_schema, act_schema, ignore=None):
        return SchemaCheckCase(
            name="test",
            expected=_inline(exp_schema),
            actual=_inline(act_schema),
            ignore_columns=ignore or [],
        )

    def test_equivalent_returns_equivalent_result(self):
        case = self._make({"id": "int64"}, {"id": "int64"})
        result = case.run()
        assert result.equivalent

    def test_drift_returns_non_equivalent(self):
        case = self._make({"id": "int64", "old": "string"}, {"id": "int64"})
        result = case.run()
        assert not result.equivalent
        assert "old" in result.columns_only_in_expected

    def test_ignore_columns_forwarded(self):
        case = self._make(
            {"id": "int64", "loaded_at": "string"},
            {"id": "int64"},
            ignore=["loaded_at"],
        )
        result = case.run()
        assert result.equivalent

    def test_result_sink_called(self):
        written = []

        class FakeSink:
            def write(self, name, tags, result):
                written.append((name, tags, result))

        case = self._make({"id": "int64"}, {"id": "int64"})
        case.run(result_sink=FakeSink())
        assert len(written) == 1
        assert written[0][0] == "test"

    def test_base_dir_resolved_from_source_file(self):
        # base_dir defaults to the directory of source_file
        with tempfile.TemporaryDirectory() as tmp:
            sql_dir = os.path.join(tmp, "sqls")
            os.makedirs(sql_dir)
            # Write a tiny parquet file to use as expected source
            import pyarrow as pa
            import pyarrow.parquet as pq
            tbl = pa.table({"id": [1]})
            pq.write_table(tbl, os.path.join(tmp, "expected.parquet"))

            case = SchemaCheckCase(
                name="t",
                expected={"type": "parquet", "path": "expected.parquet"},
                actual=_inline({"id": "int64"}),
                source_file=os.path.join(tmp, "case.yaml"),
            )
            result = case.run()
            # int32 from parquet vs int64 from inline — types differ but the check runs
            assert result.compared_columns == ["id"]


# ---------------------------------------------------------------------------
# build_schema_check_case — YAML parsing
# ---------------------------------------------------------------------------

class TestBuildSchemaCheckCase:
    def test_builds_from_minimal_yaml(self):
        raw = {
            "name": "my_check",
            "schema_check": {
                "expected": {"type": "inline", "rows": [], "schema": {"id": "int64"}},
                "actual": {"type": "inline", "rows": [], "schema": {"id": "int64"}},
            },
        }
        case = build_schema_check_case(raw, "test.yaml")
        assert case.name == "my_check"
        assert case.ignore_columns == []

    def test_ignore_columns_parsed(self):
        raw = {
            "name": "c",
            "schema_check": {
                "expected": {"type": "inline", "rows": []},
                "actual": {"type": "inline", "rows": []},
                "ignore_columns": ["loaded_at", "_ts"],
            },
        }
        case = build_schema_check_case(raw, "test.yaml")
        assert case.ignore_columns == ["loaded_at", "_ts"]

    def test_description_and_tags_parsed(self):
        raw = {
            "name": "c",
            "description": "my desc",
            "tags": ["ci", "schema"],
            "schema_check": {
                "expected": {"type": "inline", "rows": []},
                "actual": {"type": "inline", "rows": []},
            },
        }
        case = build_schema_check_case(raw, "test.yaml")
        assert case.description == "my desc"
        assert case.tags == ["ci", "schema"]

    def test_missing_expected_raises(self):
        raw = {
            "name": "c",
            "schema_check": {"actual": {"type": "inline", "rows": []}},
        }
        with pytest.raises(SchemaCheckError, match="expected"):
            build_schema_check_case(raw, "test.yaml")

    def test_missing_actual_raises(self):
        raw = {
            "name": "c",
            "schema_check": {"expected": {"type": "inline", "rows": []}},
        }
        with pytest.raises(SchemaCheckError, match="actual"):
            build_schema_check_case(raw, "test.yaml")


# ---------------------------------------------------------------------------
# End-to-end: load from YAML file
# ---------------------------------------------------------------------------

class TestLoadFromYaml:
    def test_schema_check_loaded_from_yaml_file(self, tmp_path):
        yaml_content = """
name: schema_drift_check
schema_check:
  expected:
    type: inline
    rows: []
    schema: {id: int64, name: string}
  actual:
    type: inline
    rows: []
    schema: {id: int64, name: int64}
  ignore_columns: []
"""
        case_file = tmp_path / "check.yaml"
        case_file.write_text(yaml_content)
        cases = load_cases_from_file(str(case_file))
        assert len(cases) == 1
        case = cases[0]
        assert isinstance(case, SchemaCheckCase)
        assert case.name == "schema_drift_check"
        result = case.run()
        assert not result.equivalent
        assert result.type_mismatches == [("name", "string", "int64")]

    def test_schema_check_equivalent_exits_clean(self, tmp_path):
        yaml_content = """
name: schema_ok
schema_check:
  expected:
    type: inline
    rows: []
    schema: {id: int64, amount: double}
  actual:
    type: inline
    rows: []
    schema: {id: int64, amount: double}
"""
        case_file = tmp_path / "ok.yaml"
        case_file.write_text(yaml_content)
        result = load_cases_from_file(str(case_file))[0].run()
        assert result.equivalent
