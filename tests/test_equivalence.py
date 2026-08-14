"""Global equivalence: classifying a difference as only a spelling of absence.

Two things are being pinned here.

1. The classification itself, against the exact table the BCV analyser's
   README published, so the behaviour the team already reviewed is preserved.
2. That it is classification ONLY. rowparity's core invariant is that NULL is
   a distinct value, never equal to anything else. Turning this on must not
   make a case pass, must not change a count, and must not alter a single
   fingerprint.
"""

import pyarrow as pa
import pytest

from rowparity.compare import CompareConfig, compare_tables
from rowparity.equivalence import globally_equivalent
from rowparity.hashing import CanonConfig, canon_value


class TestBcvEquivalenceTable:
    """The scenarios BCV's README tabulated, verbatim."""

    @pytest.mark.parametrize(
        "a,b",
        [
            ([], None),  # [] vs null            -> E
            ([[], []], [None, None]),  # [[],[]] vs [None,None] -> E
            (0, None),  # 0 vs null             -> E
            (None, 0),  # order must not matter
            (False, None),  # false vs null
            ("", None),  # empty string vs null
            ({}, None),  # empty object vs null
            ([None, None], None),  # all-null array is itself null-like
            ([None, None], []),
        ],
    )
    def test_equivalent_pairs(self, a, b):
        assert globally_equivalent(a, b) is True

    @pytest.mark.parametrize(
        "a,b",
        [
            ([["data"], []], [["data"]]),  # different lengths -> N (compaction)
            ("FIRST_PRICE", None),  # not in any group   -> N
            (0, []),  # zero and empty container share no group
            (False, []),
            (1, None),
            ("a", "b"),
            ([1, 2], [2, 1]),
        ],
    )
    def test_non_equivalent_pairs(self, a, b):
        assert globally_equivalent(a, b) is False

    def test_element_wise_recursion_for_same_length_lists(self):
        # The common BCV pattern: [] where the other side stores None.
        assert globally_equivalent([[], None, [1, 2]], [None, None, [1, 2]]) is True
        # One genuinely different element is enough to disqualify the row.
        assert globally_equivalent([[], None, [1, 2]], [None, None, [9, 9]]) is False

    def test_numerically_equal_values_of_different_types_classify_as_equivalent(self):
        # A consequence of the null-safe equality step, and the same behaviour
        # BCV had. rowparity's canonicalisation treats int 1 and float 1.0 as
        # different (distinct type tags), so they surface as a difference; this
        # then labels that difference as not-a-real-disagreement. Documented
        # rather than accidental -- and it only ever labels, never excuses.
        assert globally_equivalent(1, 1.0) is True

    def test_matching_is_case_insensitive(self):
        assert globally_equivalent("NULL", 0) is True
        assert globally_equivalent("False", None) is True


class TestHashingIsUntouched:
    def test_null_still_fingerprints_differently_from_zero(self):
        cfg = CanonConfig()
        assert canon_value(pa.int64(), None, cfg) != canon_value(pa.int64(), 0, cfg)

    def test_null_still_fingerprints_differently_from_empty_string(self):
        cfg = CanonConfig()
        assert canon_value(pa.string(), None, cfg) != canon_value(pa.string(), "", cfg)


def _tables(expected_v, actual_v, ty=None):
    ty = ty or pa.int64()
    schema = pa.schema([pa.field("id", pa.int64()), pa.field("v", ty)])
    exp = pa.Table.from_pylist([{"id": 1, "v": expected_v}], schema=schema)
    act = pa.Table.from_pylist([{"id": 1, "v": actual_v}], schema=schema)
    return exp, act


class TestClassificationInAComparison:
    def test_off_by_default(self):
        exp, act = _tables(None, 0)
        result = compare_tables(exp, act, CompareConfig(keys=["id"]))
        assert result.changed_count == 1
        assert result.equivalent_diff_columns == {}

    def test_on_labels_the_difference_but_still_counts_it(self):
        exp, act = _tables(None, 0)
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        # Labelled...
        assert result.equivalent_diff_columns == {"v": 1}
        # ...and still a difference. This is 3A: classify, never excuse.
        assert result.changed_count == 1
        assert result.equivalent is False

    def test_a_real_difference_is_not_labelled(self):
        exp, act = _tables(1, 2)
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        assert result.equivalent_diff_columns == {}
        assert result.changed_count == 1

    def test_counts_are_identical_with_and_without_the_option(self):
        exp, act = _tables(None, 0)
        off = compare_tables(exp, act, CompareConfig(keys=["id"]))
        on = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        for attr in ("changed_count", "missing_count", "added_count", "equivalent"):
            assert getattr(off, attr) == getattr(on, attr), attr

    def test_the_column_diff_carries_the_label(self):
        exp, act = _tables(None, 0)
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        diff = result.examples[0].columns[0]
        assert diff.equivalent is True
        # The underlying values are still reported as they are.
        assert diff.expected is None
        assert diff.actual == 0

    def test_nested_list_equivalence_through_a_real_comparison(self):
        exp, act = _tables([[], None], [None, None], ty=pa.list_(pa.list_(pa.int64())))
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        assert result.equivalent_diff_columns == {"v": 1}


class TestPushdownRejectsIt:
    def test_engine_pushdown_refuses_rather_than_silently_ignoring(self):
        from rowparity.cases import Case

        case = Case(
            name="c",
            expected={"type": "duckdb", "query": "SELECT 1"},
            actual={"type": "duckdb", "query": "SELECT 1"},
            compare={"keys": ["id"], "null_equivalence": True},
            engine="duckdb",
        )
        with pytest.raises(ValueError, match="not supported with engine: duckdb"):
            case.run()

    def test_the_default_engine_accepts_it(self):
        from rowparity.cases import Case

        case = Case(
            name="c",
            expected={"type": "inline", "rows": [{"id": 1, "v": None}]},
            actual={"type": "inline", "rows": [{"id": 1, "v": 0}]},
            compare={"keys": ["id"], "null_equivalence": True},
        )
        assert case.run().equivalent_diff_columns == {"v": 1}


class TestCsvStatus:
    def test_a_column_whose_diffs_are_all_equivalent_reads_as_equivalent(self):
        from rowparity.report import to_column_rows

        exp, act = _tables(None, 0)
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        statuses = {r["column"]: r["status"] for r in to_column_rows(result, "c")}
        # BCV's E, distinct from its N.
        assert statuses["v"] == "MATCHED - EQUIVALENT"
        assert statuses["id"] == "MATCHED"

    def test_a_column_with_a_real_diff_still_reads_as_value_diff(self):
        from rowparity.report import to_column_rows

        exp, act = _tables(1, 2)
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        statuses = {r["column"]: r["status"] for r in to_column_rows(result, "c")}
        assert statuses["v"] == "MATCHED - VALUE DIFF"


class TestConsole:
    def test_equivalent_diffs_are_surfaced_and_not_described_as_excused(self):
        from rowparity.report import render_console

        exp, act = _tables(None, 0)
        result = compare_tables(exp, act, CompareConfig(keys=["id"], null_equivalence=True))
        out = render_console(result, "c")
        assert "globally equivalent" in out
        assert "still count" in out
