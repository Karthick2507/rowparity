"""Parity tests for CompareConfig(vectorized=True): the column-at-a-time
canonicalization path (hashing.canon_columns_vectorized) must produce the same
comparison outcome as the row-at-a-time path for every scenario below, since
it's an internal performance opt-in, not a change in semantics.
"""
from datetime import date, datetime, timezone
from decimal import Decimal

import pyarrow as pa
import pytest

from rowparity import CompareConfig, compare_tables


def tbl(data, schema=None):
    return pa.table(data, schema=schema)


def assert_same_outcome(a, b, cfg_kwargs):
    r_row = compare_tables(a, b, CompareConfig(**cfg_kwargs, vectorized=False))
    r_vec = compare_tables(a, b, CompareConfig(**cfg_kwargs, vectorized=True))

    assert r_row.equivalent == r_vec.equivalent
    assert r_row.missing_count == r_vec.missing_count
    assert r_row.added_count == r_vec.added_count
    assert r_row.changed_count == r_vec.changed_count
    assert r_row.duplicate_keys_expected == r_vec.duplicate_keys_expected
    assert r_row.duplicate_keys_actual == r_vec.duplicate_keys_actual
    assert {s.columns: s.count for s in r_row.signatures_by_count()} == \
           {s.columns: s.count for s in r_vec.signatures_by_count()}
    return r_row, r_vec


def test_keyed_float_tolerance_and_changes():
    a = tbl({"id": [1, 2, 3, 4], "revenue": [10.0, 10.0, 10.0, 10.0], "margin": [1.0, 1.0, 1.0, 1.0]})
    b = tbl({"id": [1, 2, 3, 4], "revenue": [10.0, 10.0, 10.0, 99.0], "margin": [1.0004, 1.002, 1.002, 2.0]})
    assert_same_outcome(a, b, {"keys": ["id"], "float_tolerance": 0.001})


def test_float_nan_inf_and_exact_compare():
    a = tbl({"id": [1, 2, 3], "f": [float("nan"), float("inf"), 1.0]})
    b = tbl({"id": [1, 2, 3], "f": [float("nan"), float("inf"), 1.0000001]})
    # exact compare (no tolerance) -> row 3 differs
    assert_same_outcome(a, b, {"keys": ["id"]})


def test_coerce_numeric_to_float():
    a = tbl({"id": [1, 2], "v": pa.array([10, 20], type=pa.int64())})
    b = tbl({"id": [1, 2], "v": pa.array([10.0, 20.0004], type=pa.float64())})
    assert_same_outcome(a, b, {"keys": ["id"], "coerce_numeric_to_float": True, "float_tolerance": 0.001})


def test_string_trim_and_case_insensitive():
    a = tbl({"id": [1, 2, 3], "s": [" Abc ", "def", "GHI"]})
    b = tbl({"id": [1, 2, 3], "s": ["abc", "DEF", "ghi"]})
    assert_same_outcome(a, b, {"keys": ["id"], "trim_strings": True, "case_insensitive": True})


def test_timestamp_naive_and_aware():
    a = tbl({
        "id": [1, 2],
        "t": pa.array([datetime(2020, 1, 1, 0, 0, 0), datetime(2020, 1, 1, 7, 30, 0)]),
    })
    aware = pa.array(
        [datetime(2020, 1, 1, 0, 0, 0, tzinfo=timezone.utc), datetime(2020, 1, 1, 7, 30, 0, tzinfo=timezone.utc)]
    )
    b = tbl({"id": [1, 2], "t": aware})
    # naive vs aware are distinct canonically -> both rows differ
    assert_same_outcome(a, b, {"keys": ["id"]})


def test_nulls_mixed_with_typed_values():
    a = tbl({"id": [1, 2, 3], "v": pa.array([1.0, None, 3.0])})
    b = tbl({"id": [1, 2, 3], "v": pa.array([1.0, None, 3.5])})
    assert_same_outcome(a, b, {"keys": ["id"], "float_tolerance": 0.001})


def test_decimal_date_untouched_types_fall_back_correctly():
    a = tbl({
        "id": [1, 2],
        "d": pa.array([Decimal("1.10"), Decimal("2.00")], type=pa.decimal128(10, 2)),
        "day": pa.array([date(2020, 1, 1), date(2020, 1, 2)]),
    })
    b = tbl({
        "id": [1, 2],
        "d": pa.array([Decimal("1.1"), Decimal("2.005")], type=pa.decimal128(10, 3)),
        "day": pa.array([date(2020, 1, 1), date(2020, 1, 3)]),
    })
    assert_same_outcome(a, b, {"keys": ["id"]})


def test_unordered_list_columns():
    a = tbl({"id": [1, 2], "tags": pa.array([["a", "b"], ["x", "y"]])})
    b = tbl({"id": [1, 2], "tags": pa.array([["b", "a"], ["y", "x"]])})
    assert_same_outcome(a, b, {"keys": ["id"], "unordered_list_columns": ["tags"]})


def test_duplicate_keys():
    a = tbl({"id": [1, 1, 2], "v": [10, 10, 20]})
    b = tbl({"id": [1, 2], "v": [10, 20]})
    assert_same_outcome(a, b, {"keys": ["id"]})


def test_missing_and_added_keyed():
    a = tbl({"id": [1, 2, 3], "v": [10, 20, 30]})
    b = tbl({"id": [2, 3, 4], "v": [20, 30, 40]})
    assert_same_outcome(a, b, {"keys": ["id"]})


def test_keyless_multiset():
    a = tbl({"x": [1, 2, 2, 3], "y": ["a", "b", "b", "c"]})
    b = tbl({"x": [3, 2, 1, 1], "y": ["c", "b", "a", "a"]})
    assert_same_outcome(a, b, {})


def test_keyless_with_float_tolerance_and_strings():
    a = tbl({"amount": [10.0, 20.0004, 30.0], "note": [" a ", "b", "C"]})
    b = tbl({"amount": [10.0002, 20.0, 30.5], "note": ["a", "b", "c"]})
    assert_same_outcome(a, b, {"float_tolerance": 0.001, "trim_strings": True, "case_insensitive": True})


@pytest.mark.parametrize("select", [None, ["id", "v"]])
@pytest.mark.parametrize("ignore", [[], ["note"]])
def test_select_and_ignore_columns_combinations(select, ignore):
    a = tbl({"id": [1, 2], "v": [10, 20], "note": ["x", "y"]})
    b = tbl({"id": [1, 2], "v": [10, 99], "note": ["z", "y"]})
    assert_same_outcome(a, b, {"keys": ["id"], "select": select, "ignore_columns": ignore})
