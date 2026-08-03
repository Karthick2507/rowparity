"""Unit tests for the comparison semantics — the contract QA relies on."""
import pyarrow as pa
import pytest

from rowparity import CompareConfig, compare_tables


def tbl(data, schema=None):
    return pa.table(data, schema=schema)


# --------------------------------------------------------------------------- #
# Order independence
# --------------------------------------------------------------------------- #
def test_row_order_does_not_matter_keyless():
    a = tbl({"x": [1, 2, 3], "y": ["a", "b", "c"]})
    b = tbl({"x": [3, 1, 2], "y": ["c", "a", "b"]})
    assert compare_tables(a, b, CompareConfig()).equivalent


def test_row_order_does_not_matter_keyed():
    a = tbl({"id": [1, 2, 3], "y": ["a", "b", "c"]})
    b = tbl({"id": [3, 2, 1], "y": ["c", "b", "a"]})
    assert compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_column_order_does_not_matter():
    a = tbl({"x": [1], "y": ["a"]})
    b = tbl({"y": ["a"], "x": [1]})
    assert compare_tables(a, b, CompareConfig(keys=["x"])).equivalent


# --------------------------------------------------------------------------- #
# Duplicates are respected (multiset, not set)
# --------------------------------------------------------------------------- #
def test_keyless_is_a_multiset():
    a = tbl({"x": [1, 1, 2]})
    b = tbl({"x": [1, 2, 2]})
    r = compare_tables(a, b, CompareConfig())
    assert not r.equivalent
    assert r.missing_count == 1  # one extra '1' expected
    assert r.added_count == 1    # one extra '2' actual


# --------------------------------------------------------------------------- #
# Lists ordered, maps/structs unordered
# --------------------------------------------------------------------------- #
def test_list_columns_are_ordered():
    t = pa.schema([("id", pa.int64()), ("xs", pa.list_(pa.int64()))])
    a = tbl({"id": [1], "xs": [[1, 2, 3]]}, schema=t)
    b = tbl({"id": [1], "xs": [[3, 2, 1]]}, schema=t)
    assert not compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_list_columns_can_be_made_unordered():
    t = pa.schema([("id", pa.int64()), ("xs", pa.list_(pa.int64()))])
    a = tbl({"id": [1], "xs": [[1, 2, 3]]}, schema=t)
    b = tbl({"id": [1], "xs": [[3, 2, 1]]}, schema=t)
    cfg = CompareConfig(keys=["id"], unordered_list_columns=["xs"])
    assert compare_tables(a, b, cfg).equivalent


def test_map_columns_are_unordered():
    t = pa.schema([("id", pa.int64()), ("m", pa.map_(pa.string(), pa.int64()))])
    a = tbl({"id": [1], "m": [[("a", 1), ("b", 2)]]}, schema=t)
    b = tbl({"id": [1], "m": [[("b", 2), ("a", 1)]]}, schema=t)
    assert compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_struct_fields_are_unordered():
    t = pa.schema([("id", pa.int64()),
                   ("s", pa.struct([("a", pa.int64()), ("b", pa.string())]))])
    a = tbl({"id": [1], "s": [{"a": 1, "b": "x"}]}, schema=t)
    b = tbl({"id": [1], "s": [{"b": "x", "a": 1}]}, schema=t)
    assert compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_nested_list_of_struct_with_map():
    inner = pa.struct([("sku", pa.string()), ("qty", pa.int64())])
    t = pa.schema([("id", pa.int64()),
                   ("items", pa.list_(inner)),
                   ("attrs", pa.map_(pa.string(), pa.string()))])
    a = tbl({"id": [1], "items": [[{"sku": "A", "qty": 2}, {"sku": "B", "qty": 1}]],
             "attrs": [[("c", "red"), ("s", "L")]]}, schema=t)
    # same items order, map keys reversed -> still equal
    b = tbl({"id": [1], "items": [[{"sku": "A", "qty": 2}, {"sku": "B", "qty": 1}]],
             "attrs": [[("s", "L"), ("c", "red")]]}, schema=t)
    assert compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


# --------------------------------------------------------------------------- #
# Numeric handling
# --------------------------------------------------------------------------- #
def test_float_tolerance():
    a = tbl({"id": [1], "v": [1.0]})
    b = tbl({"id": [1], "v": [1.0 + 1e-12]})
    assert not compare_tables(a, b, CompareConfig(keys=["id"])).equivalent  # exact by default
    assert compare_tables(a, b, CompareConfig(keys=["id"], float_tolerance=1e-9)).equivalent


def test_decimal_trailing_zeros_equal():
    from decimal import Decimal
    t = pa.schema([("id", pa.int64()), ("v", pa.decimal128(10, 3))])
    a = tbl({"id": [1], "v": [Decimal("1.100")]}, schema=t)
    b = tbl({"id": [1], "v": [Decimal("1.1")]}, schema=t)
    assert compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_int_width_is_engine_agnostic():
    a = tbl({"id": pa.array([1], pa.int32()), "v": pa.array([5], pa.int32())})
    b = tbl({"id": pa.array([1], pa.int64()), "v": pa.array([5], pa.int64())})
    # values match even though physical widths differ (int32 vs int64).
    assert compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_coerce_numeric_matches_int_and_float():
    a = tbl({"id": [1], "v": pa.array([5], pa.int64())})
    b = tbl({"id": [1], "v": pa.array([5.0], pa.float64())})
    assert not compare_tables(a, b, CompareConfig(keys=["id"])).equivalent
    assert compare_tables(a, b, CompareConfig(keys=["id"], coerce_numeric_to_float=True)).equivalent


# --------------------------------------------------------------------------- #
# Null semantics (classic data-quality gotchas)
# --------------------------------------------------------------------------- #
def test_null_is_not_empty_string():
    t = pa.schema([("id", pa.int64()), ("s", pa.string())])
    a = tbl({"id": [1], "s": [None]}, schema=t)
    b = tbl({"id": [1], "s": [""]}, schema=t)
    assert not compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


def test_null_map_is_not_empty_map():
    t = pa.schema([("id", pa.int64()), ("m", pa.map_(pa.string(), pa.int64()))])
    a = tbl({"id": [1], "m": [None]}, schema=t)
    b = tbl({"id": [1], "m": [[]]}, schema=t)
    assert not compare_tables(a, b, CompareConfig(keys=["id"])).equivalent


# --------------------------------------------------------------------------- #
# Keyed diff detail
# --------------------------------------------------------------------------- #
def test_keyed_missing_added_changed():
    a = tbl({"id": [1, 2, 3], "v": [10, 20, 30]})
    b = tbl({"id": [2, 3, 4], "v": [20, 999, 40]})
    r = compare_tables(a, b, CompareConfig(keys=["id"]))
    assert not r.equivalent
    assert r.missing_count == 1   # id=1 only in expected
    assert r.added_count == 1     # id=4 only in actual
    assert r.changed_count == 1   # id=3 value changed
    changed = [e for e in r.examples if e.kind == "changed"][0]
    assert changed.columns[0].column == "v"
    assert (changed.columns[0].expected, changed.columns[0].actual) == (30, 999)


def test_change_signatures_group_rows_by_which_columns_differ():
    # rows 1,2,3 differ only in 'margin'; row 4 differs in both columns.
    a = tbl({"id": [1, 2, 3, 4], "revenue": [10, 10, 10, 10], "margin": [1, 1, 1, 1]})
    b = tbl({"id": [1, 2, 3, 4], "revenue": [10, 10, 10, 99], "margin": [2, 2, 2, 2]})
    r = compare_tables(a, b, CompareConfig(keys=["id"]))
    assert r.changed_count == 4
    assert len(r.change_signatures) == 2

    sigs = {s.columns: s.count for s in r.signatures_by_count()}
    assert sigs[("margin",)] == 3
    assert sigs[("margin", "revenue")] == 1

    margin_only = r.change_signatures[("margin",)]
    assert margin_only.example.columns[0].column == "margin"


def test_duplicate_keys_are_reported():
    a = tbl({"id": [1, 1], "v": [10, 10]})
    b = tbl({"id": [1], "v": [10]})
    r = compare_tables(a, b, CompareConfig(keys=["id"]))
    assert r.duplicate_keys_expected == 1


# --------------------------------------------------------------------------- #
# Column selection / schema policy
# --------------------------------------------------------------------------- #
def test_ignore_columns():
    a = tbl({"id": [1], "v": [10], "loaded_at": ["2024-01-01"]})
    b = tbl({"id": [1], "v": [10], "loaded_at": ["2025-12-31"]})
    assert compare_tables(a, b, CompareConfig(keys=["id"], ignore_columns=["loaded_at"])).equivalent


def test_select_only_named_columns():
    a = tbl({"id": [1], "v": [10], "note": ["x"]})
    b = tbl({"id": [1], "v": [10], "note": ["y"]})
    assert compare_tables(a, b, CompareConfig(keys=["id"], select=["id", "v"])).equivalent


def test_strict_columns_flags_extra_column():
    a = tbl({"id": [1], "v": [10]})
    b = tbl({"id": [1], "v": [10], "extra": [1]})
    r = compare_tables(a, b, CompareConfig(keys=["id"], strict_columns=True))
    assert not r.equivalent
    assert r.columns_only_in_actual == ["extra"]


def test_strict_columns_flags_missing_column():
    a = tbl({"id": [1], "v": [10], "note": ["x"]})
    b = tbl({"id": [1], "v": [10]})
    r = compare_tables(a, b, CompareConfig(keys=["id"], strict_columns=True))
    assert not r.equivalent
    assert r.columns_only_in_expected == ["note"]


def test_strict_columns_catches_list_element_type_drift():
    a = pa.table({"id": [1], "tags": pa.array([[1, 2]], type=pa.list_(pa.int64()))})
    b = pa.table({"id": [1], "tags": pa.array([["x", "y"]], type=pa.list_(pa.string()))})
    r = compare_tables(a, b, CompareConfig(keys=["id"], strict_columns=True))
    assert not r.equivalent
    assert r.type_mismatches == [("tags", "list<item: int64>", "list<item: string>")]


def test_strict_columns_catches_struct_field_added():
    a = pa.table({"id": [1], "attrs": pa.array(
        [{"color": "red", "size": "m"}],
        type=pa.struct([("color", pa.string()), ("size", pa.string())]),
    )})
    b = pa.table({"id": [1], "attrs": pa.array(
        [{"color": "red", "size": "m", "weight": 1.0}],
        type=pa.struct([("color", pa.string()), ("size", pa.string()), ("weight", pa.float64())]),
    )})
    r = compare_tables(a, b, CompareConfig(keys=["id"], strict_columns=True))
    assert not r.equivalent
    assert r.type_mismatches == [(
        "attrs",
        "struct<color: string, size: string>",
        "struct<color: string, size: string, weight: double>",
    )]


def test_strict_columns_catches_map_value_type_drift():
    a = pa.table({"id": [1], "prefs": pa.array([[("a", 1)]], type=pa.map_(pa.string(), pa.int64()))})
    b = pa.table({"id": [1], "prefs": pa.array([[("a", "x")]], type=pa.map_(pa.string(), pa.string()))})
    r = compare_tables(a, b, CompareConfig(keys=["id"], strict_columns=True))
    assert not r.equivalent
    assert r.type_mismatches == [("prefs", "map<string, int64>", "map<string, string>")]


def test_nested_type_drift_reported_but_non_strict_does_not_fail():
    # type_mismatches is always populated; only strict_columns turns it into a
    # failure -- isolate that with empty (schema-only) tables so there's no
    # row content that could independently make the case non-equivalent.
    exp_schema = pa.schema([pa.field("id", pa.int64()), pa.field("tags", pa.list_(pa.int64()))])
    act_schema = pa.schema([pa.field("id", pa.int64()), pa.field("tags", pa.list_(pa.string()))])
    a = pa.Table.from_arrays([pa.array([], type=f.type) for f in exp_schema], schema=exp_schema)
    b = pa.Table.from_arrays([pa.array([], type=f.type) for f in act_schema], schema=act_schema)

    r = compare_tables(a, b, CompareConfig(keys=["id"]))  # strict_columns defaults to False
    assert r.type_mismatches == [("tags", "list<item: int64>", "list<item: string>")]
    assert r.equivalent


def test_nonstrict_extra_column_is_tolerated_but_reported():
    a = tbl({"id": [1], "v": [10]})
    b = tbl({"id": [1], "v": [10], "extra": [1]})
    r = compare_tables(a, b, CompareConfig(keys=["id"]))
    assert r.equivalent
    assert r.columns_only_in_actual == ["extra"]


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
