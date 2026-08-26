"""Per-column attribution for keyless comparisons, and schema reporting.

A live run compared two 262-column aggregates, found 1,114,550 row differences,
and produced a per-column CSV in which **every one of the 262 columns said
MATCHED** with empty type columns. Both halves of that were wrong:

* Keyless comparisons had no per-column attribution at all, so the CSV fell
  through to MATCHED for every shared column. Beside a million row differences
  that reads as "the columns are fine" -- a clean-looking answer to a question
  nobody asked.
* compare_tables never populated expected_schema/actual_schema, so the type
  columns were blank even for columns present on only one side, where the type
  is the most useful thing to know.

A report that looks confident and says nothing is worse than no report.
"""
import pyarrow as pa
import pytest

from rowparity.cases import Case
from rowparity.compare import CompareConfig, compare_tables
from rowparity.report import (
    STATUS_DIFF,
    STATUS_MATCHED,
    STATUS_TYPE_DIFF,
    STATUS_VALUE_DIFF,
    to_column_rows,
)


def _compare(expected_rows, actual_rows, **cfg):
    return compare_tables(
        pa.Table.from_pylist(expected_rows),
        pa.Table.from_pylist(actual_rows),
        CompareConfig(**cfg),
    )


def _status(result, column):
    for row in to_column_rows(result, "c"):
        if row["column"] == column:
            return row["status"]
    raise AssertionError(f"{column!r} absent from the report")


class TestKeylessAttribution:
    def test_the_differing_column_is_named(self):
        result = _compare(
            [{"id": 1, "good": "a", "bad": 10}, {"id": 2, "good": "b", "bad": 20}],
            [{"id": 1, "good": "a", "bad": 999}, {"id": 2, "good": "b", "bad": 20}],
        )
        assert result.column_value_mismatch == ["bad"]

    def test_identical_tables_name_nothing(self):
        rows = [{"id": 1, "v": "a"}, {"id": 2, "v": "b"}]
        assert _compare(rows, rows).column_value_mismatch == []

    def test_row_order_is_irrelevant(self):
        # The sum commutes, which is the same reason the row comparison does
        # not care about order. A checksum that did care would flag every
        # column on any reordering.
        rows = [{"id": 1, "v": "a"}, {"id": 2, "v": "b"}, {"id": 3, "v": "c"}]
        result = _compare(rows, list(reversed(rows)))
        assert result.column_value_mismatch == []
        assert result.equivalent

    def test_multiplicity_is_preserved(self):
        # The reason for addition rather than XOR: these two columns hold the
        # same SET of values and different multisets. XOR would call them equal.
        result = _compare(
            [{"v": 1}, {"v": 1}, {"v": 2}],
            [{"v": 1}, {"v": 2}, {"v": 2}],
        )
        assert result.column_value_mismatch == ["v"]

    def test_several_differing_columns_are_all_named(self):
        result = _compare(
            [{"a": 1, "b": 2, "c": 3}],
            [{"a": 9, "b": 2, "c": 9}],
        )
        assert sorted(result.column_value_mismatch) == ["a", "c"]

    def test_a_column_differing_only_by_null_is_caught(self):
        # NULL is a distinct value in this framework, never equal to anything.
        result = _compare([{"v": 1}], [{"v": None}])
        assert result.column_value_mismatch == ["v"]

    def test_ignored_columns_are_not_attributed(self):
        result = _compare(
            [{"id": 1, "noise": "x"}],
            [{"id": 1, "noise": "y"}],
            ignore_columns=["noise"],
        )
        assert result.column_value_mismatch == []
        assert result.equivalent

    def test_differing_row_counts_flag_every_column(self):
        # Not a defect: if one side has more rows, every column's value
        # multiset genuinely differs. Reporting all of them is the honest
        # answer -- and it is what the live run should have said instead of
        # marking all 262 MATCHED.
        result = _compare(
            [{"a": 1, "b": 2}],
            [{"a": 1, "b": 2}, {"a": 3, "b": 4}],
        )
        assert sorted(result.column_value_mismatch) == ["a", "b"]


class TestKeyedIsUnaffected:
    def test_keyed_comparisons_do_not_use_the_checksum(self):
        # Keyed mode pairs rows and attributes differences exactly, per row,
        # via change_signatures. The checksum would be redundant there.
        result = _compare(
            [{"id": 1, "v": 10}],
            [{"id": 1, "v": 20}],
            keys=["id"],
        )
        assert result.column_value_mismatch == []
        assert result.changed_count == 1
        assert _status(result, "v") == STATUS_VALUE_DIFF


class TestSchemasAreReported:
    def test_row_comparison_carries_both_schemas(self):
        result = _compare([{"id": 1, "v": "a"}], [{"id": 1, "v": "a"}])
        assert result.expected_schema["id"] == "int64"
        assert result.actual_schema["v"] == "string"

    def test_types_appear_in_the_csv(self):
        rows = to_column_rows(_compare([{"id": 1}], [{"id": 1}]), "c")
        assert rows[0]["expected_type"] == "int64"
        assert rows[0]["actual_type"] == "int64"

    def test_a_column_on_one_side_only_still_shows_its_type(self):
        # The case where the type matters most: you cannot judge a missing
        # column without knowing what it held.
        result = _compare([{"id": 1, "gone": "x"}], [{"id": 1}])
        rows = {r["column"]: r for r in to_column_rows(result, "c")}
        assert rows["gone"]["status"] == STATUS_DIFF
        assert rows["gone"]["expected_type"] == "string"
        assert rows["gone"]["actual_type"] == ""


class TestCsvStatuses:
    def test_keyless_value_difference_is_not_reported_as_matched(self):
        # The regression this whole module exists for.
        result = _compare(
            [{"keep": 1, "drift": "a"}],
            [{"keep": 1, "drift": "b"}],
        )
        assert _status(result, "drift") == STATUS_VALUE_DIFF
        assert _status(result, "keep") == STATUS_MATCHED

    def test_type_difference_still_wins_over_value_difference(self):
        # A column whose type differs is reported as a type problem; saying
        # "values differ" about columns of different types is not useful.
        result = _compare([{"v": 1}], [{"v": "1"}])
        assert _status(result, "v") == STATUS_TYPE_DIFF

    def test_every_column_matched_only_when_nothing_differs(self):
        rows = [{"a": 1, "b": "x"}, {"a": 2, "b": "y"}]
        result = _compare(rows, rows)
        statuses = {r["status"] for r in to_column_rows(result, "c")}
        assert statuses == {STATUS_MATCHED}
        assert result.equivalent


class TestTheLiveFailureShape:
    """Reproduces the shape of the run that exposed this: one side a small
    sample of the other, many columns, keyless."""

    def test_a_sampled_side_against_a_full_side(self):
        full = [{"dim": i % 7, "metric": i, "label": f"r{i}"} for i in range(200)]
        sample = [r for i, r in enumerate(full) if i % 40 == 0]
        result = _compare(sample, full)

        assert not result.equivalent
        assert result.added_count > 0
        # Before the fix, this list was empty and the CSV said MATCHED for all
        # three columns while reporting 195 added rows.
        assert sorted(result.column_value_mismatch) == ["dim", "label", "metric"]
        for column in ("dim", "metric", "label"):
            assert _status(result, column) == STATUS_VALUE_DIFF

    def test_case_run_end_to_end_populates_everything(self):
        case = Case(
            name="live_shape",
            expected={"type": "inline", "rows": [{"a": 1, "b": "x"}]},
            actual={"type": "inline", "rows": [{"a": 1, "b": "y"}]},
            compare={},
        )
        result = case.run()
        assert result.column_value_mismatch == ["b"]
        assert result.expected_schema and result.actual_schema
        assert result.total_seconds > 0


@pytest.mark.parametrize("vectorized", [False, True])
def test_both_canonicalisation_paths_agree(vectorized):
    # vectorized: true canonicalises whole columns at once; it must produce the
    # same attribution as the row-at-a-time path or the option changes results.
    result = _compare(
        [{"id": 1, "same": "a", "differs": 1.0}, {"id": 2, "same": "b", "differs": 2.0}],
        [{"id": 1, "same": "a", "differs": 1.0}, {"id": 2, "same": "b", "differs": 9.0}],
        vectorized=vectorized,
    )
    assert result.column_value_mismatch == ["differs"]
