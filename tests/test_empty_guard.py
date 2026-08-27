"""A comparison over zero rows must not report success.

Two empty tables are trivially equivalent, and that is exactly the problem: the
run reports EQUIVALENT and exits 0, indistinguishable in every visible way from
a real pass.

This is not hypothetical. A live run spent eight minutes of warehouse time,
returned zero rows on both sides because the batch had aged out of staging, and
finished with a green "1/1 equivalent". The queries, the parameters and the
framework were all working correctly; the data was simply gone. A verification
tool that reports success for having verified nothing is worse than one that
crashes, because nobody investigates a pass.
"""
import pytest

from rowparity.cases import Case
from rowparity.compare import CompareConfig, ComparisonResult, EmptyComparisonError, compare_tables
from rowparity.schema_check import SchemaCheckCase


def _case(expected_rows, actual_rows, **compare):
    return Case(
        name="c",
        expected={"type": "inline", "rows": expected_rows},
        actual={"type": "inline", "rows": actual_rows},
        compare=compare,
    )


ROW = [{"id": 1, "v": "a"}]


class TestBothSidesEmpty:
    def test_it_raises_instead_of_reporting_equivalent(self):
        with pytest.raises(EmptyComparisonError):
            _case([], []).run()

    def test_the_message_explains_why_and_how_to_proceed(self):
        with pytest.raises(EmptyComparisonError) as exc:
            _case([], []).run()
        msg = str(exc.value)
        assert "case 'c'" in msg
        assert "0 rows" in msg
        # Must say what it would otherwise have done, or the reader has no idea
        # what was at stake.
        assert "EQUIVALENT" in msg
        # And name the usual culprits, since the fix is never in the framework.
        assert "batch" in msg and "parameter" in msg
        assert "allow_empty" in msg

    def test_it_applies_to_keyed_comparisons_too(self, tmp_path):
        # Via duckdb rather than inline rows: an empty inline source carries no
        # schema at all, so a keyed case fails on the missing key column before
        # reaching the guard. A warehouse returns zero rows WITH its columns --
        # cursor.description is populated either way -- and that is the shape
        # the live failure had.
        import duckdb

        db = tmp_path / "w.duckdb"
        con = duckdb.connect(str(db))
        con.execute("CREATE TABLE t AS SELECT 1 AS id, 10 AS v")
        con.close()
        empty = {"type": "duckdb", "database": str(db), "query": "SELECT * FROM t WHERE id = 999"}
        case = Case(name="c", expected=dict(empty), actual=dict(empty), compare={"keys": ["id"]})
        with pytest.raises(EmptyComparisonError):
            case.run()

    def test_a_zero_row_result_still_reports_its_columns(self, tmp_path):
        # Establishes the premise of the test above: the guard has to fire on a
        # result that looks complete apart from having no rows.
        import duckdb

        from rowparity.sources import load_source

        db = tmp_path / "w.duckdb"
        con = duckdb.connect(str(db))
        con.execute("CREATE TABLE t AS SELECT 1 AS id, 10 AS v")
        con.close()
        tbl = load_source(
            {"type": "duckdb", "database": str(db), "query": "SELECT * FROM t WHERE id = 999"},
            base_dir=".",
        )
        assert tbl.num_rows == 0
        assert tbl.num_columns == 2


class TestWhatMustStillWork:
    def test_one_side_empty_is_a_real_difference(self):
        # Not the trap: an empty side against a populated one is a genuine,
        # correctly reported finding. Guarding it would suppress real results.
        result = _case([], ROW).run()
        assert not result.equivalent
        assert result.added_count == 1

    def test_the_other_side_empty_is_also_reported(self):
        result = _case(ROW, []).run()
        assert not result.equivalent
        assert result.missing_count == 1

    def test_populated_and_equal_still_passes(self):
        assert _case(ROW, ROW).run().equivalent

    def test_allow_empty_opts_out(self):
        result = _case([], [], allow_empty=True).run()
        assert result.equivalent
        assert result.expected_rows == 0

    def test_compare_tables_directly_is_unguarded(self):
        # The guard belongs to the case runner, not the comparison primitive.
        # A library caller comparing two empty tables gets the literal answer.
        import pyarrow as pa

        empty = pa.table({"id": pa.array([], type=pa.int64())})
        result = compare_tables(empty, empty, CompareConfig())
        assert result.equivalent


class TestOtherCaseShapesAreNotGuarded:
    """schema_check and concept_check report zero rows by design -- fetching
    none is the entire point of them. Guarding on row count alone would make
    every one of them fail."""

    def test_schema_check_reports_zero_rows_and_passes(self):
        case = SchemaCheckCase(
            name="schema",
            expected={"type": "inline", "rows": ROW},
            actual={"type": "inline", "rows": ROW},
        )
        result = case.run()
        assert result.expected_rows == 0 and result.actual_rows == 0
        assert result.equivalent

    def test_the_guard_keys_off_kind_not_row_count(self):
        # Directly: a zero-row result of a non-row kind is left alone.
        case = _case(ROW, ROW)
        for kind in ("schema", "concept"):
            result = ComparisonResult(
                equivalent=True, keys=None, compared_columns=[],
                expected_rows=0, actual_rows=0, kind=kind,
            )
            case._guard_empty(result, CompareConfig())  # must not raise


class TestCliBehaviour:
    def test_it_fails_the_run_rather_than_crashing_it(self, tmp_path, capsys):
        # The CLI turns a case exception into a reported failure and exit 1,
        # so an empty comparison is visible without taking the whole run down.
        from rowparity.cli import main as cli_main

        path = tmp_path / "c.yaml"
        path.write_text(
            "name: empty_both\n"
            "expected: {type: inline, rows: []}\n"
            "actual: {type: inline, rows: []}\n"
            "compare: {}\n",
            encoding="utf-8",
        )
        rc = cli_main(["run", str(path), "--quiet"])
        out = capsys.readouterr().out
        assert rc == 1
        assert "EmptyComparisonError" in out
        assert "EQUIVALENT] " not in out
