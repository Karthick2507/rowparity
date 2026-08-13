"""Per-column CSV report.

The headline column lists are unreadable once drift runs to hundreds of
columns -- a real staging schema check produced a single 32,000-character
console line. These cover the row-per-column form that replaces it, for both
shapes it has to serve: a schema check (status + type per column) and a row
comparison (which columns differed, and in how many rows).
"""

import csv

from rowparity.compare import ChangeSignature, ComparisonResult
from rowparity.report import (
    MAX_LISTED_COLUMNS,
    render_console,
    to_column_rows,
    write_csv_reports,
)

TYPE_DIFF_COL = "execution_networks__phase_metrics__value"


def _schema_result(n_matched=3, n_src_only=2, n_bcv_only=1, with_type_diff=True):
    matched = [f"c{i}" for i in range(n_matched)]
    src_only = [f"src_only_{i}" for i in range(n_src_only)]
    bcv_only = [f"bcv_extra_{i}" for i in range(n_bcv_only)]
    compared = sorted(matched + ([TYPE_DIFF_COL] if with_type_diff else []))
    exp = {**{c: "varchar" for c in matched}, **{c: "bigint" for c in src_only}}
    act = {**{c: "varchar" for c in matched}, **{c: "double" for c in bcv_only}}
    if with_type_diff:
        exp[TYPE_DIFF_COL] = "array(array(array(bigint)))"
        act[TYPE_DIFF_COL] = "array(array(array(integer)))"
    return ComparisonResult(
        equivalent=False,
        keys=None,
        compared_columns=compared,
        expected_rows=0,
        actual_rows=0,
        columns_only_in_expected=src_only,
        columns_only_in_actual=bcv_only,
        type_mismatches=(
            [(TYPE_DIFF_COL, exp[TYPE_DIFF_COL], act[TYPE_DIFF_COL])] if with_type_diff else []
        ),
        kind="schema",
        expected_schema=exp,
        actual_schema=act,
    )


class TestSchemaShape:
    def test_one_row_per_column_across_all_buckets(self):
        rows = to_column_rows(_schema_result(), "case_a")
        assert len(rows) == 3 + 1 + 2 + 1  # matched + type diff + src-only + bcv-only
        by_status = {}
        for r in rows:
            by_status.setdefault(r["status"], []).append(r["column"])
        assert len(by_status["MATCHED"]) == 3
        assert by_status["MATCHED - TYPE DIFF"] == [TYPE_DIFF_COL]
        assert len(by_status["DIFF"]) == 3

    def test_type_diff_carries_both_types(self):
        row = next(
            r for r in to_column_rows(_schema_result(), "c") if r["status"] == "MATCHED - TYPE DIFF"
        )
        assert row["expected_type"] == "array(array(array(bigint)))"
        assert row["actual_type"] == "array(array(array(integer)))"

    def test_one_sided_column_keeps_the_type_it_does_have(self):
        # Knowing the type of a column BCV is missing is the whole point when
        # deciding whether it can be backfilled.
        rows = to_column_rows(_schema_result(), "c")
        src_only = next(r for r in rows if r["column"] == "src_only_0")
        assert src_only["expected_type"] == "bigint"
        assert src_only["actual_type"] == ""
        bcv_only = next(r for r in rows if r["column"] == "bcv_extra_0")
        assert bcv_only["expected_type"] == ""
        assert bcv_only["actual_type"] == "double"

    def test_type_mismatch_not_in_compared_columns_is_still_reported(self):
        # Defensive: a producer reporting a mismatch without listing the column
        # must not cause the finding to vanish from the report.
        result = _schema_result()
        result.compared_columns = [c for c in result.compared_columns if c != TYPE_DIFF_COL]
        statuses = {r["column"]: r["status"] for r in to_column_rows(result, "c")}
        assert statuses[TYPE_DIFF_COL] == "MATCHED - TYPE DIFF"


class TestRowShape:
    def _row_result(self):
        return ComparisonResult(
            equivalent=False,
            keys=["id"],
            compared_columns=["id", "margin", "revenue", "note"],
            expected_rows=100,
            actual_rows=100,
            changed_count=40,
            change_signatures={
                ("margin",): ChangeSignature(columns=("margin",), count=37),
                ("margin", "revenue"): ChangeSignature(columns=("margin", "revenue"), count=3),
            },
        )

    def test_columns_with_value_diffs_are_flagged_and_counted(self):
        rows = {r["column"]: r for r in to_column_rows(self._row_result(), "c")}
        # margin appears in both signatures: 37 + 3
        assert rows["margin"]["status"] == "MATCHED - VALUE DIFF"
        assert rows["margin"]["diff_rows"] == 40
        assert rows["revenue"]["status"] == "MATCHED - VALUE DIFF"
        assert rows["revenue"]["diff_rows"] == 3

    def test_untouched_columns_stay_matched_with_no_count(self):
        rows = {r["column"]: r for r in to_column_rows(self._row_result(), "c")}
        assert rows["note"]["status"] == "MATCHED"
        assert rows["note"]["diff_rows"] == ""
        assert rows["id"]["status"] == "MATCHED"

    def test_equivalent_result_is_all_matched(self):
        result = ComparisonResult(
            equivalent=True,
            keys=["id"],
            compared_columns=["id", "v"],
            expected_rows=5,
            actual_rows=5,
        )
        assert {r["status"] for r in to_column_rows(result, "c")} == {"MATCHED"}


class TestFileWriting:
    def test_writes_one_file_per_case_with_a_header(self, tmp_path):
        results = [("case_a", _schema_result()), ("case_b", _schema_result(n_matched=1))]
        paths = write_csv_reports(results, str(tmp_path))
        assert len(paths) == 2
        assert {p.split("/")[-1] for p in paths} == {"case_a.csv", "case_b.csv"}

        with open(paths[0], newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        assert rows[0]["case"] == "case_a"
        assert set(rows[0]) == {
            "case",
            "status",
            "column",
            "expected_type",
            "actual_type",
            "diff_rows",
        }

    def test_creates_the_directory(self, tmp_path):
        out = tmp_path / "nested" / "reports"
        write_csv_reports([("c", _schema_result())], str(out))
        assert (out / "c.csv").exists()

    def test_case_names_are_sanitised_into_filenames(self, tmp_path):
        # Case names are author-supplied and become filenames.
        paths = write_csv_reports([("a/b c:d", _schema_result())], str(tmp_path))
        assert paths[0].endswith("a_b_c_d.csv")

    def test_round_trips_every_column(self, tmp_path):
        result = _schema_result(n_matched=50, n_src_only=200, n_bcv_only=10)
        paths = write_csv_reports([("wide", result)], str(tmp_path))
        with open(paths[0], newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        assert len(rows) == 50 + 1 + 200 + 10


class TestConsoleTruncation:
    def test_long_lists_are_summarised_not_dumped(self):
        result = _schema_result(n_matched=2, n_src_only=896, n_bcv_only=36)
        out = render_console(result, "bcv_request_schema")
        longest = max(len(line) for line in out.split("\n"))
        # Was a single 32,000-character line before truncation.
        assert longest < 500
        assert "(896, first 20 shown" in out
        assert "--csv" in out  # points at where the full list lives

    def test_short_lists_are_shown_in_full(self):
        result = _schema_result(n_src_only=2, n_bcv_only=1)
        out = render_console(result, "c")
        assert "columns only in expected (2): src_only_0, src_only_1" in out
        assert "first 20 shown" not in out

    def test_schema_checks_are_not_labelled_keyless_multiset(self):
        # A schema check fetches no rows by design; the old label reported it
        # as a keyless multiset comparison of 0 rows.
        out = render_console(_schema_result(), "c")
        assert "schema-only" in out
        assert "keyless (multiset)" not in out

    def test_row_cases_keep_their_original_summary(self):
        result = ComparisonResult(
            equivalent=True,
            keys=["id"],
            compared_columns=["id"],
            expected_rows=4,
            actual_rows=4,
        )
        assert "keyed on ['id']" in render_console(result, "c")

    def test_many_type_mismatches_are_truncated_too(self):
        result = _schema_result()
        result.type_mismatches = [(f"col_{i}", "bigint", "integer") for i in range(50)]
        result.compared_columns = [f"col_{i}" for i in range(50)]
        out = render_console(result, "c")
        assert f"and {50 - MAX_LISTED_COLUMNS} more type mismatch(es)" in out
