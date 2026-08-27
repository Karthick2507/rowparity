"""Single-run HTML report (``rowparity run --html``).

The report is the deliverable a reader actually looks at, so the failures worth
guarding are the ones that make it *confidently wrong* rather than broken:

* a case that errored being silently absent, so the page implies everything ran
* a keyless run's MATCHED columns reading as "values agree"
* a value from the compared data breaking out of the inline <script> block
* a Decimal or datetime in an example row raising mid-serialisation, on
  precisely the runs that had something to report
"""
import json
import os
import re

import pyarrow as pa
import pytest

from rowparity.cases import Case
from rowparity.cli import main as cli_main
from rowparity.compare import CompareConfig, compare_tables
from rowparity.run_report import (
    build_payload,
    render_run_report,
    write_run_report,
)

DATA_RE = re.compile(
    r'<script id="rowparity-data" type="application/json">(.*?)</script>', re.S
)


def _result(expected_rows, actual_rows, **cfg):
    return compare_tables(
        pa.Table.from_pylist(expected_rows),
        pa.Table.from_pylist(actual_rows),
        CompareConfig(**cfg),
    )


def _payload_from_html(html: str) -> dict:
    m = DATA_RE.search(html)
    assert m, "no embedded JSON payload in the report"
    return json.loads(m.group(1))


ROWS = [{"id": 1, "v": "a"}, {"id": 2, "v": "b"}]


class TestPayload:
    def test_equivalent_case(self):
        payload = build_payload([("c", _result(ROWS, ROWS, keys=["id"]))])
        case = payload["cases"][0]
        assert case["status"] == "EQUIVALENT"
        assert payload["summary"]["equivalent"] == 1
        assert payload["summary"]["different"] == 0

    def test_different_case_carries_counts_and_columns(self):
        result = _result(ROWS, [{"id": 1, "v": "a"}, {"id": 2, "v": "CHANGED"}], keys=["id"])
        case = build_payload([("c", result)])["cases"][0]
        assert case["status"] == "DIFFERENT"
        assert case["changed"] == 1
        assert case["keys"] == ["id"]
        statuses = {col["column"]: col["status"] for col in case["columns"]}
        assert statuses["v"] == "MATCHED - VALUE DIFF"
        assert statuses["id"] == "MATCHED"

    def test_types_are_present(self):
        case = build_payload([("c", _result(ROWS, ROWS, keys=["id"]))])["cases"][0]
        by_name = {c["column"]: c for c in case["columns"]}
        assert by_name["id"]["expected_type"] == "int64"
        assert by_name["v"]["actual_type"] == "string"

    def test_change_signatures_are_carried(self):
        exp = [{"id": i, "a": i, "b": i} for i in range(10)]
        act = [{"id": i, "a": i + 1 if i % 2 == 0 else i, "b": i} for i in range(10)]
        case = build_payload([("c", _result(exp, act, keys=["id"]))])["cases"][0]
        assert case["change_signatures"]
        assert case["change_signatures"][0]["columns"] == ["a"]
        assert case["change_signatures"][0]["count"] == 5

    def test_timing_is_carried_as_numbers_and_text(self):
        case = build_payload([("c", Case(
            name="t",
            expected={"type": "inline", "rows": ROWS},
            actual={"type": "inline", "rows": ROWS},
            compare={"keys": ["id"]},
        ).run())])["cases"][0]
        assert case["timing"]["total"] > 0
        assert case["timing"]["total_text"].endswith("s")


class TestErroredCasesAreVisible:
    """The failure this report exists to avoid.

    An errored case never produces a ComparisonResult, so it never reaches
    `results` and every other reporter omits it -- the CSV for a run whose only
    case blew up is a header and nothing else. A page that shows two green
    cases and silently drops the third is worse than no page.
    """

    def test_an_error_becomes_a_case(self):
        payload = build_payload([], [("broken", ValueError("boom"))])
        case = payload["cases"][0]
        assert case["status"] == "ERROR"
        assert case["error_type"] == "ValueError"
        assert "boom" in case["error"]

    def test_errors_count_in_the_summary(self):
        payload = build_payload([("ok", _result(ROWS, ROWS))], [("broken", RuntimeError("x"))])
        assert payload["summary"]["total"] == 2
        assert payload["summary"]["errored"] == 1
        assert payload["summary"]["equivalent"] == 1

    def test_errors_render_in_the_html(self):
        html = render_run_report([], [("broken", RuntimeError("connection refused"))])
        assert "connection refused" in html
        assert "broken" in html

    def test_errors_come_after_real_results(self):
        payload = build_payload(
            [("ok", _result(ROWS, ROWS))], [("broken", RuntimeError("x"))]
        )
        assert [c["case"] for c in payload["cases"]] == ["ok", "broken"]


class TestKeylessIsLabelled:
    def test_keyless_case_reports_no_keys(self):
        case = build_payload([("c", _result(ROWS, ROWS))])["cases"][0]
        assert case["keys"] is None

    def test_the_template_explains_what_matched_means_without_a_key(self):
        # Beside a large diff, an unlabelled MATCHED reads as "the columns are
        # fine" -- which is not what a keyless run checked.
        html = render_run_report([("c", _result(ROWS, [{"id": 3, "v": "z"}]))])
        assert "Keyless run" in html
        # Matched against one string literal: the sentence is built by JS
        # concatenation, so a phrase spanning two literals is never contiguous
        # in the source and asserting on it tests the line breaks, not the text.
        assert "present on both sides with the same type" in html

    def test_the_template_warns_when_row_counts_differ(self):
        html = render_run_report([("c", _result(ROWS, [{"id": 3, "v": "z"}]))])
        assert "Row counts differ" in html


class TestHtmlIsSafeAndSelfContained:
    def test_no_external_resources(self):
        # It has to open from a file:// path on a laptop with no network.
        html = render_run_report([("c", _result(ROWS, ROWS, keys=["id"]))])
        external = re.findall(r'(?:src|href)="(?!#)[^"]+"', html)
        assert external == [], f"report references external resources: {external}"

    def test_no_placeholders_survive(self):
        html = render_run_report([("c", _result(ROWS, ROWS))])
        assert re.findall(r"__ROWPARITY_[A-Z_]+__", html) == []

    def test_a_value_containing_a_script_tag_cannot_break_out(self):
        # Cell values are warehouse content: arbitrary, and not ours to trust.
        hostile = "</script><script>alert(1)</script>"
        result = _result([{"id": 1, "v": hostile}], [{"id": 1, "v": "safe"}], keys=["id"])
        html = render_run_report([("c", result)])
        # The payload block must still parse, which it cannot if the value
        # terminated it early.
        payload = _payload_from_html(html)
        assert payload["cases"][0]["changed"] == 1
        assert "</script><script>alert(1)</script>" not in html

    def test_non_json_types_in_example_rows_do_not_raise(self):
        # Decimals, dates and bytes are ordinary warehouse values, and they only
        # reach the serialiser on runs that HAVE differences to show.
        import datetime
        import decimal

        exp = [{"id": 1, "d": decimal.Decimal("1.10"), "t": datetime.date(2026, 1, 1)}]
        act = [{"id": 1, "d": decimal.Decimal("9.99"), "t": datetime.date(2026, 2, 2)}]
        html = render_run_report([("c", _result(exp, act, keys=["id"]))])
        payload = _payload_from_html(html)
        assert payload["cases"][0]["changed"] == 1

    def test_long_values_are_truncated(self):
        from rowparity.run_report import MAX_VALUE_CHARS

        long_value = "x" * (MAX_VALUE_CHARS * 3)
        result = _result([{"id": 1, "v": long_value}], [{"id": 1, "v": "short"}], keys=["id"])
        payload = build_payload([("c", result)])
        rendered = payload["cases"][0]["examples"][0]["columns"][0]["expected"]
        assert len(rendered) <= MAX_VALUE_CHARS


class TestCliIntegration:
    CASE = (
        "name: html_case\n"
        "expected: {type: inline, rows: [{id: 1, v: a}]}\n"
        "actual:   {type: inline, rows: [{id: 1, v: b}]}\n"
        "compare: {keys: [id]}\n"
    )

    def test_run_html_writes_a_file(self, tmp_path, capsys):
        case = tmp_path / "c.yaml"
        case.write_text(self.CASE, encoding="utf-8")
        out = tmp_path / "nested" / "report.html"

        rc = cli_main(["run", str(case), "--quiet", "--html", str(out)])
        assert rc == 1                      # the case differs
        assert out.is_file()                # …and the report was still written
        assert "Wrote HTML report" in capsys.readouterr().out

        payload = _payload_from_html(out.read_text(encoding="utf-8"))
        assert payload["cases"][0]["case"] == "html_case"
        assert payload["run_id"]

    def test_a_run_with_no_html_flag_writes_nothing(self, tmp_path):
        case = tmp_path / "c.yaml"
        case.write_text(self.CASE, encoding="utf-8")
        cli_main(["run", str(case), "--quiet"])
        assert not list(tmp_path.glob("*.html"))

    def test_an_unwritable_path_warns_but_does_not_change_the_verdict(self, tmp_path, capsys):
        # A report is an artifact of the run, not the run. Losing it must not
        # turn a completed comparison into a different answer.
        case = tmp_path / "c.yaml"
        case.write_text(
            "name: ok\n"
            "expected: {type: inline, rows: [{id: 1}]}\n"
            "actual: {type: inline, rows: [{id: 1}]}\n"
            "compare: {keys: [id]}\n",
            encoding="utf-8",
        )
        blocked = tmp_path / "afile"
        blocked.write_text("not a directory", encoding="utf-8")

        rc = cli_main(["run", str(case), "--quiet", "--html", str(blocked / "r.html")])
        assert rc == 0, "a failed report write must not fail an equivalent run"
        assert "could not write HTML report" in capsys.readouterr().err

    def test_errored_case_reaches_the_report(self, tmp_path):
        case = tmp_path / "c.yaml"
        case.write_text(
            "name: boom\n"
            "expected: {type: duckdb, database: nope.duckdb, query: 'SELECT bad syntax('}\n"
            "actual: {type: inline, rows: [{id: 1}]}\n"
            "compare: {}\n",
            encoding="utf-8",
        )
        out = tmp_path / "r.html"
        rc = cli_main(["run", str(case), "--quiet", "--html", str(out)])
        assert rc == 1
        payload = _payload_from_html(out.read_text(encoding="utf-8"))
        assert payload["summary"]["errored"] == 1
        assert payload["cases"][0]["status"] == "ERROR"


class TestTemplateIsPackaged:
    def test_the_template_file_exists_beside_the_module(self):
        from rowparity import run_report

        assert os.path.isfile(run_report._TEMPLATE_PATH)

    def test_package_data_covers_it(self):
        # setuptools ships templates/*.html; a template added outside that glob
        # works from a source checkout and vanishes from the installed wheel.
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(repo, "pyproject.toml"), encoding="utf-8") as fh:
            assert 'rowparity = ["templates/*.html"]' in fh.read()


def test_write_run_report_returns_the_path(tmp_path):
    out = write_run_report(str(tmp_path / "r.html"), [("c", _result(ROWS, ROWS))])
    assert os.path.isfile(out)


@pytest.mark.parametrize("status", ["MATCHED", "MATCHED - TYPE DIFF",
                                    "MATCHED - VALUE DIFF", "MATCHED - EQUIVALENT", "DIFF"])
def test_every_status_has_styling_in_the_template(status):
    # An unstyled status renders as a plain word and stops standing out, which
    # is the whole job of the column table.
    from rowparity.run_report import _TEMPLATE_PATH

    with open(_TEMPLATE_PATH, encoding="utf-8") as fh:
        template = fh.read()
    assert f'"{status}"' in template, f"{status} missing from the template's status map"
