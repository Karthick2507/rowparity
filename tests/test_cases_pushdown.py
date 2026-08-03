"""End-to-end: a YAML case with engine: duckdb, run through Case.run() exactly
as the CLI/pytest runner would — not calling duckdb_pushdown functions directly.
"""
import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from rowparity.cases import Case, load_cases_from_file


def test_case_with_engine_duckdb_inline_keyed(tmp_path):
    case = Case(
        name="inline_keyed_pushdown",
        expected={"type": "inline", "rows": [{"id": 1, "v": 10}, {"id": 2, "v": 20}]},
        actual={"type": "inline", "rows": [{"id": 1, "v": 10}, {"id": 2, "v": 999}]},
        compare={"keys": ["id"]},
        engine="duckdb",
    )
    result = case.run(base_dir=str(tmp_path))
    assert not result.equivalent
    assert result.changed_count == 1


def test_case_with_engine_duckdb_inline_keyless(tmp_path):
    case = Case(
        name="inline_keyless_pushdown",
        expected={"type": "inline", "rows": [{"x": 1}, {"x": 2}, {"x": 3}]},
        actual={"type": "inline", "rows": [{"x": 3}, {"x": 2}, {"x": 1}]},
        compare={},
        engine="duckdb",
    )
    result = case.run(base_dir=str(tmp_path))
    assert result.equivalent


def test_case_with_engine_duckdb_parquet_sources(tmp_path):
    exp_path = tmp_path / "expected.parquet"
    act_path = tmp_path / "actual.parquet"
    pq.write_table(pa.table({"id": [1, 2, 3], "amount": [10.0, 20.0, 30.0]}), exp_path)
    pq.write_table(pa.table({"id": [1, 2, 3], "amount": [10.0, 20.0, 999.0]}), act_path)

    case = Case(
        name="parquet_pushdown",
        expected={"type": "parquet", "path": "expected.parquet"},
        actual={"type": "parquet", "path": "actual.parquet"},
        compare={"keys": ["id"], "float_tolerance": 0.001},
        engine="duckdb",
    )
    result = case.run(base_dir=str(tmp_path))
    assert not result.equivalent
    assert result.changed_count == 1
    assert result.examples[0].columns[0].column == "amount"


def test_yaml_case_engine_duckdb_round_trip(tmp_path):
    exp_path = tmp_path / "expected.parquet"
    act_path = tmp_path / "actual.parquet"
    pq.write_table(pa.table({"id": [1, 2], "v": [10, 20]}), exp_path)
    pq.write_table(pa.table({"id": [1, 2], "v": [10, 20]}), act_path)

    case_yaml = tmp_path / "case.yaml"
    case_yaml.write_text(
        """
name: pushdown_round_trip
engine: duckdb
expected:
  type: parquet
  path: expected.parquet
actual:
  type: parquet
  path: actual.parquet
compare:
  keys: [id]
"""
    )
    cases = load_cases_from_file(str(case_yaml))
    assert len(cases) == 1
    assert cases[0].engine == "duckdb"
    result = cases[0].run()
    assert result.equivalent


def test_unknown_engine_rejected(tmp_path):
    case_yaml = tmp_path / "case.yaml"
    case_yaml.write_text(
        """
name: bad_engine
engine: spark_sql
expected: {type: inline, rows: [{id: 1}]}
actual: {type: inline, rows: [{id: 1}]}
"""
    )
    with pytest.raises(ValueError, match="unknown engine"):
        load_cases_from_file(str(case_yaml))


def test_pushdown_rejects_unsupported_source_type(tmp_path):
    case = Case(
        name="bad_source",
        expected={"type": "snowflake", "query": "SELECT 1"},
        actual={"type": "inline", "rows": [{"id": 1}]},
        compare={"keys": ["id"]},
        engine="duckdb",
    )
    with pytest.raises(Exception, match="."):
        case.run(base_dir=str(tmp_path))