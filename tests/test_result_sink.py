"""result_sink.py had zero test coverage before this — these lock in the
write path, the injectable run_ts (needed to build historical test data at
all), and the schema-drift columns added for the historical HTML report."""
import json
from datetime import datetime, timezone

import duckdb
import pytest

from rowparity.compare import ColumnDiff, ComparisonResult, RowDiff
from rowparity.result_sink import DuckDBResultSink


@pytest.fixture
def db_path(tmp_path):
    return str(tmp_path / "results.duckdb")


def test_write_roundtrip_basic_fields(db_path):
    sink = DuckDBResultSink(db_path, run_id="run-1", table_prefix="rp")
    result = ComparisonResult(
        equivalent=False, keys=["id"], compared_columns=["id", "v"],
        expected_rows=10, actual_rows=9, missing_count=1, added_count=0, changed_count=2,
    )
    sink.write("my_case", ["tpch", "regression"], result, run_ts=datetime(2026, 7, 1, tzinfo=timezone.utc))
    sink.close()

    con = duckdb.connect(db_path)
    row = con.execute("SELECT * FROM rp_run_summary").fetchone()
    cols = [d[0] for d in con.description]
    con.close()
    d = dict(zip(cols, row))

    assert d["run_id"] == "run-1"
    assert d["case_name"] == "my_case"
    assert json.loads(d["tags"]) == ["tpch", "regression"]
    assert d["equivalent"] is False
    assert d["missing_count"] == 1
    assert d["changed_count"] == 2


def test_schema_drift_fields_persisted(db_path):
    sink = DuckDBResultSink(db_path, run_id="run-1")
    result = ComparisonResult(
        equivalent=False, keys=["id"], compared_columns=["id", "v"],
        expected_rows=10, actual_rows=10,
        columns_only_in_expected=["old_col"],
        columns_only_in_actual=["new_col"],
        type_mismatches=[("v", "int32", "int64")],
    )
    sink.write("case_a", [], result, run_ts=datetime(2026, 7, 1, tzinfo=timezone.utc))
    sink.close()

    con = duckdb.connect(db_path)
    row = con.execute(
        "SELECT columns_only_in_expected, columns_only_in_actual, type_mismatches FROM rowparity_run_summary"
    ).fetchone()
    con.close()

    assert json.loads(row[0]) == ["old_col"]
    assert json.loads(row[1]) == ["new_col"]
    assert json.loads(row[2]) == [{"column": "v", "expected": "int32", "actual": "int64"}]


def test_diffs_table_persists_examples(db_path):
    sink = DuckDBResultSink(db_path, run_id="run-1")
    result = ComparisonResult(
        equivalent=False, keys=["id"], compared_columns=["id", "v"],
        expected_rows=10, actual_rows=10, changed_count=1,
    )
    result.examples = [
        RowDiff(kind="changed", key=(("i", 5),), columns=[ColumnDiff(column="v", expected=1, actual=2)])
    ]
    sink.write("case_a", [], result, run_ts=datetime(2026, 7, 1, tzinfo=timezone.utc))
    sink.close()

    con = duckdb.connect(db_path)
    row = con.execute("SELECT diff_kind, key_json, column_diffs FROM rowparity_run_diffs").fetchone()
    con.close()

    assert row[0] == "changed"
    assert json.loads(row[1]) == ["5"]
    assert json.loads(row[2]) == [{"column": "v", "expected": "1", "actual": "2"}]


def test_old_db_missing_new_columns_migrates_forward(db_path):
    # Simulate a .duckdb file written before columns_only_in_* existed.
    con = duckdb.connect(db_path)
    con.execute("""
        CREATE TABLE rowparity_run_summary (
            run_id VARCHAR, run_ts TIMESTAMPTZ, case_name VARCHAR, tags VARCHAR,
            equivalent BOOLEAN, expected_rows BIGINT, actual_rows BIGINT,
            missing_count BIGINT, added_count BIGINT, changed_count BIGINT,
            compared_columns VARCHAR, keys VARCHAR, type_mismatches VARCHAR
        )
    """)
    con.close()

    sink = DuckDBResultSink(db_path, run_id="run-1")  # must not raise on the old schema
    result = ComparisonResult(equivalent=True, keys=["id"], compared_columns=["id"], expected_rows=1, actual_rows=1)
    sink.write("case_a", [], result, run_ts=datetime(2026, 7, 1, tzinfo=timezone.utc))
    sink.close()

    con = duckdb.connect(db_path)
    cols = {d[0] for d in con.execute("DESCRIBE rowparity_run_summary").fetchall()}
    con.close()
    assert {"columns_only_in_expected", "columns_only_in_actual"} <= cols