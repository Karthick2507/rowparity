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


class TestSideLabels:
    """The two sides are named, not called "expected" and "actual".

    A reader opening a migration report should not have to remember which of
    two abstract words is their source of truth. Labels are per-case config
    rather than hardcoded, because the template ships with the framework and
    every project names its sides differently.
    """

    def _labelled(self, **labels):
        case = Case(
            name="c",
            expected={"type": "inline", "rows": [{"id": 1, "v": "a"}]},
            actual={"type": "inline", "rows": [{"id": 2, "v": "b"}]},
            compare={"keys": ["id"]},
            **labels,
        )
        return case.run()

    def test_labels_default_to_expected_and_actual(self):
        result = self._labelled()
        assert result.expected_label == "expected"
        assert result.actual_label == "actual"

    def test_labels_reach_the_result(self):
        result = self._labelled(expected_label="Hoover", actual_label="Hoover++")
        assert result.expected_label == "Hoover"
        assert result.actual_label == "Hoover++"

    def test_labels_reach_the_payload(self):
        case = build_payload([("c", self._labelled(
            expected_label="Hoover", actual_label="Hoover++"))])["cases"][0]
        assert case["expected_label"] == "Hoover"
        assert case["actual_label"] == "Hoover++"

    def test_labels_are_read_from_yaml(self, tmp_path):
        from rowparity.cases import discover_cases

        path = tmp_path / "c.yaml"
        path.write_text(
            "name: labelled\n"
            "expected_label: Hoover\n"
            "actual_label: Hoover++\n"
            "expected: {type: inline, rows: [{id: 1}]}\n"
            "actual: {type: inline, rows: [{id: 1}]}\n"
            "compare: {keys: [id]}\n",
            encoding="utf-8",
        )
        case = discover_cases(str(path), {})[0]
        assert case.expected_label == "Hoover"
        assert case.actual_label == "Hoover++"

    def test_the_template_builds_metric_labels_from_them(self):
        from rowparity.run_report import _TEMPLATE_PATH

        with open(_TEMPLATE_PATH, encoding="utf-8") as fh:
            template = fh.read()
        for fragment in ('"Rows in "', '"Missing in "', '"Added in "', '", not in "'):
            assert fragment in template, f"{fragment} missing from the metric labels"

    def test_the_shipped_case_names_hoover(self):
        # The report is the deliverable; unlabelled it would read
        # "expected"/"actual" to whoever it gets forwarded to.
        import yaml as _yaml

        path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "scripts", "cases_insight_plus", "f_demand_portfolio_hourly.yaml",
        )
        if not os.path.isfile(path):
            pytest.skip("insight_plus case not present")
        with open(path, encoding="utf-8") as fh:
            case = _yaml.safe_load(fh)["cases"][0]
        assert case["expected_label"] == "Hoover"
        assert case["actual_label"] == "Hoover++"


class TestEncoding:
    """Mojibake in the rendered page.

    A report showed "Row examples a-tilde-euro-quote 50 shown" -- a real em dash
    read as Windows-1252 because the template declared no charset and the
    browser guessed. Two defences, because this report gets forwarded, saved and
    re-encoded by tools nobody controls:

      1. the template declares utf-8, which is the actual fix
      2. its own text is ASCII, so there is nothing left to mangle
    """

    TEMPLATES = ["run_report.html", "report.html"]

    @pytest.mark.parametrize("name", TEMPLATES)
    def test_template_declares_a_charset_first(self, name):
        path = os.path.join(
            os.path.dirname(os.path.abspath(__import__("rowparity").__file__)),
            "templates", name,
        )
        with open(path, encoding="utf-8") as fh:
            head = fh.read(200)
        assert '<meta charset="utf-8">' in head, f"{name} does not declare its encoding"

    @pytest.mark.parametrize("name", TEMPLATES)
    def test_template_text_is_ascii(self, name):
        path = os.path.join(
            os.path.dirname(os.path.abspath(__import__("rowparity").__file__)),
            "templates", name,
        )
        with open(path, encoding="utf-8") as fh:
            content = fh.read()
        offenders = sorted({c for c in content if ord(c) > 127})
        assert not offenders, f"{name} contains non-ASCII: {offenders}"

    def test_rendered_report_declares_its_charset(self):
        html = render_run_report([("c", _result(ROWS, ROWS, keys=["id"]))])
        assert html.lstrip().startswith('<meta charset="utf-8">')

    def test_truncation_marker_is_ascii(self):
        from rowparity.run_report import MAX_VALUE_CHARS, _short

        truncated = _short("x" * (MAX_VALUE_CHARS * 2))
        assert truncated.endswith("...")
        assert all(ord(c) < 128 for c in truncated)

    def test_a_non_ascii_data_value_still_round_trips(self):
        # Data may legitimately be non-ASCII -- that is what the charset
        # declaration is for. Only the template's own text is held to ASCII.
        result = _result([{"id": 1, "v": "café — ünïcode"}],
                         [{"id": 1, "v": "plain"}], keys=["id"])
        payload = _payload_from_html(render_run_report([("c", result)]))
        assert payload["cases"][0]["changed"] == 1


class TestErrorBlockRendering:
    """A driver error is mostly useless without its shape.

    DuckDB, Trino and Snowflake all report syntax and binder errors as several
    lines ending in a caret under the offending token:

        Binder Error: Referenced column "nope" not found in FROM clause!
        Candidate bindings: "group_id"

        LINE 1: SELECT nope FROM hoover
                       ^

    Collapsed onto one line, the caret points at nothing and the part of the
    message that says WHERE the problem is has been thrown away.
    """

    MULTILINE = (
        'Binder Error: Referenced column "nope" not found in FROM clause!\n'
        'Candidate bindings: "group_id"\n'
        '\n'
        'LINE 1: SELECT nope FROM hoover\n'
        '               ^'
    )

    def test_newlines_survive_into_the_payload(self):
        payload = build_payload([], [("broken", ValueError(self.MULTILINE))])
        assert "\n" in payload["cases"][0]["error"]
        assert payload["cases"][0]["error"].count("\n") == 4

    def test_newlines_survive_into_the_html(self):
        html = render_run_report([], [("broken", ValueError(self.MULTILINE))])
        payload = _payload_from_html(html)
        assert payload["cases"][0]["error"].endswith("^")

    def test_the_error_is_rendered_in_a_pre_block(self):
        from rowparity.run_report import _TEMPLATE_PATH

        with open(_TEMPLATE_PATH, encoding="utf-8") as fh:
            template = fh.read()
        assert 'el("pre", "err"' in template, "error text is not rendered in a <pre>"

    def test_the_pre_block_does_not_wrap(self):
        # pre-wrap would re-flow long lines and move the caret away from the
        # token it points at, which is the whole reason to keep the shape.
        from rowparity.run_report import _TEMPLATE_PATH

        with open(_TEMPLATE_PATH, encoding="utf-8") as fh:
            template = fh.read()
        block = template.split("pre.err {", 1)[1].split("}", 1)[0]
        # Comments out first: the rule carries one explaining why pre-wrap is
        # wrong here, and searching raw text finds the explanation rather than
        # a declaration. Same trap as prose inside a SQL file.
        declarations = re.sub(r"/\*.*?\*/", "", block, flags=re.S)
        assert "white-space: pre;" in declarations
        assert "pre-wrap" not in declarations
        assert "overflow-x: auto" in declarations, "no horizontal scroll; long lines get cut off"

    def test_no_stray_punctuation_icon(self):
        # The ERROR badge in the header already marks it. A bare "!" left over
        # from an icon reads as leftover punctuation, not a warning.
        from rowparity.run_report import _TEMPLATE_PATH

        with open(_TEMPLATE_PATH, encoding="utf-8") as fh:
            template = fh.read()
        assert 'el("div", null, "!")' not in template

    def test_the_headline_says_no_verdict_was_reached(self):
        # The distinction that matters: an errored case is neither a pass nor a
        # difference, and a reader skimming badges should not file it as either.
        html = render_run_report([], [("broken", ValueError("x"))])
        assert "This case did not run." in html
        assert "no verdict" in html

    def test_the_exception_type_is_shown_with_the_message(self):
        payload = build_payload([], [("broken", ValueError("boom"))])
        case = payload["cases"][0]
        assert case["error_type"] == "ValueError"
        assert case["error"] == "boom"
