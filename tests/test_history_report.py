"""End-to-end: real data through DuckDBResultSink -> history.py's reader/
transform -> report_html.py's HTML render -> `rowparity report`'s CLI path.
"""

import json
import re
from datetime import datetime, timedelta, timezone

import pytest

from rowparity.cli import main as cli_main
from rowparity.compare import ColumnDiff, ComparisonResult, RowDiff
from rowparity.history import build_case_histories, read_raw_history
from rowparity.report_html import render_html_report, render_report_from_sink
from rowparity.result_sink import DuckDBResultSink

BASE = datetime(2026, 6, 30, tzinfo=timezone.utc)


def _write_days(db_path, case_name, tags, day_results):
    """day_results: list of (offset_days, ComparisonResult)."""
    for i, (offset, result) in enumerate(day_results):
        sink = DuckDBResultSink(db_path, run_id=f"{case_name}-{i}")
        sink.write(case_name, tags, result, run_ts=BASE + timedelta(days=offset))
        sink.close()


def _r(**kwargs):
    defaults = dict(
        equivalent=True,
        keys=["id"],
        compared_columns=["id", "v"],
        expected_rows=100,
        actual_rows=100,
    )
    defaults.update(kwargs)
    return ComparisonResult(**defaults)


@pytest.fixture
def db_path(tmp_path):
    return str(tmp_path / "results.duckdb")


def test_read_raw_history_respects_window(db_path):
    _write_days(
        db_path,
        "case_a",
        [],
        [
            (0, _r()),
            (1, _r()),
            (40, _r()),  # 40 days out -> outside a 21-day window
        ],
    )
    summary_rows, _ = read_raw_history(f"duckdb:{db_path}", days=21)
    assert len(summary_rows) == 2  # the 40-day-old run is excluded


def test_build_case_histories_one_point_per_day_latest_wins(db_path):
    # two runs on the SAME day -- the transform should pick the later one
    sink = DuckDBResultSink(db_path, run_id="run-early")
    sink.write("case_a", [], _r(changed_count=0), run_ts=BASE)
    sink.close()
    sink = DuckDBResultSink(db_path, run_id="run-late")
    sink.write(
        "case_a", [], _r(equivalent=False, changed_count=5), run_ts=BASE + timedelta(hours=6)
    )
    sink.close()

    summary_rows, diffs_rows = read_raw_history(f"duckdb:{db_path}", days=30)
    cases = build_case_histories(summary_rows, diffs_rows)
    assert len(cases) == 1
    assert len(cases[0]["history"]) == 1  # one calendar day, not two runs
    assert cases[0]["history"][0]["changed_count"] == 5  # the later run won


def test_build_case_histories_change_signatures_grouped():
    result = _r(equivalent=False, changed_count=2)
    result.examples = [
        RowDiff(
            kind="changed", key=(("i", 1),), columns=[ColumnDiff(column="v", expected=1, actual=2)]
        ),
        RowDiff(
            kind="changed", key=(("i", 2),), columns=[ColumnDiff(column="v", expected=3, actual=4)]
        ),
    ]
    summary_rows = [
        {
            "run_id": "r1",
            "run_ts": BASE,
            "case_name": "case_a",
            "tags": "[]",
            "equivalent": False,
            "expected_rows": 100,
            "actual_rows": 100,
            "missing_count": 0,
            "added_count": 0,
            "changed_count": 2,
            "compared_columns": "[]",
            "keys": '["id"]',
            "type_mismatches": "[]",
            "columns_only_in_expected": "[]",
            "columns_only_in_actual": "[]",
        }
    ]
    from rowparity.result_sink import _build_diffs_batch

    diffs_table = _build_diffs_batch("r1", "case_a", result)
    diffs_rows = diffs_table.to_pylist()

    cases = build_case_histories(summary_rows, diffs_rows)
    assert len(cases) == 1
    sigs = cases[0]["signatures"]
    assert len(sigs) == 1
    assert sigs[0]["columns"] == ["v"]
    assert sigs[0]["count"] == 2


def test_schema_drift_carried_in_history(db_path):
    _write_days(
        db_path,
        "case_a",
        [],
        [
            (0, _r()),
            (1, _r(equivalent=False, columns_only_in_actual=["new_col"])),
        ],
    )
    summary_rows, diffs_rows = read_raw_history(f"duckdb:{db_path}", days=30)
    cases = build_case_histories(summary_rows, diffs_rows)
    history = cases[0]["history"]
    assert history[0]["schema_drifted"] is False
    assert history[1]["schema_drifted"] is True
    assert history[1]["schema"]["onlyActual"] == ["new_col"]


def test_render_html_report_contains_case_data_and_valid_json():
    cases = [
        {
            "name": "demo_case",
            "tags": ["t"],
            "keys": ["id"],
            "history": [
                {
                    "date": "2026-07-01",
                    "run_id": "r1",
                    "equivalent": True,
                    "expected_rows": 10,
                    "actual_rows": 10,
                    "missing_count": 0,
                    "added_count": 0,
                    "changed_count": 0,
                    "schema": {"onlyExpected": [], "onlyActual": [], "typeMismatches": []},
                    "schema_drifted": False,
                },
            ],
            "signatures": [],
            "diffs": [],
        }
    ]
    html = render_html_report(
        cases, days=21, generated_at=datetime(2026, 7, 21, 12, 0, tzinfo=timezone.utc)
    )

    assert "demo_case" in html
    assert "__ROWPARITY_" not in html  # every placeholder got substituted
    assert "2026-07-21 12:00 UTC" in html

    m = re.search(r"var CASES = (\[.*?\]);\s*\n\s*var WINDOW_DAYS", html, re.S)
    assert m is not None
    parsed = json.loads(m.group(1))
    assert parsed == cases


def test_render_html_report_escapes_script_close_in_data():
    # a diff value that happens to contain "</script>" must not break out of
    # the inline <script> block.
    cases = [
        {
            "name": "demo_case",
            "tags": [],
            "keys": ["id"],
            "history": [
                {
                    "date": "2026-07-01",
                    "run_id": "r1",
                    "equivalent": False,
                    "expected_rows": 1,
                    "actual_rows": 1,
                    "missing_count": 0,
                    "added_count": 0,
                    "changed_count": 1,
                    "schema": {"onlyExpected": [], "onlyActual": [], "typeMismatches": []},
                    "schema_drifted": False,
                }
            ],
            "signatures": [
                {
                    "columns": ["v"],
                    "count": 1,
                    "example": "key=(1): v: a -> </script><script>alert(1)",
                }
            ],
            "diffs": [
                {"key": "(1)", "column": "v", "oldv": "a", "newv": "</script><script>alert(1)"}
            ],
        }
    ]
    html = render_html_report(cases, days=21)
    assert "</script><script>alert(1)" not in html
    assert "<\\/script><script>alert(1)" in html  # escaped, safe as a JS string literal
    assert (
        html.count("</script>") == 1
    )  # only the report's own closing tag -- nothing closed it early


def test_cli_report_command_end_to_end(db_path, tmp_path, capsys):
    _write_days(
        db_path, "case_a", ["demo"], [(0, _r()), (1, _r(equivalent=False, changed_count=1))]
    )
    out_html = str(tmp_path / "out.html")

    rc = cli_main(
        ["report", "--result-sink", f"duckdb:{db_path}", "--html", out_html, "--days", "30"]
    )
    assert rc == 0
    content = open(out_html).read()
    assert "case_a" in content

    captured = capsys.readouterr()
    assert "Wrote" in captured.out


def test_render_report_from_sink_pipeline(db_path):
    _write_days(db_path, "case_a", [], [(0, _r())])
    html = render_report_from_sink(f"duckdb:{db_path}", days=30)
    assert "case_a" in html
