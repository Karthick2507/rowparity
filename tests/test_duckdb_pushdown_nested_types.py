"""Parity tests for the types push-down originally excluded: date, time,
list, struct, map — including nesting and recursion. Every case here checks
push-down against compare_tables() (the default engine) on the SAME data,
since that's the actual correctness bar: two execution strategies, one
semantic. See CLAUDE.md for why the original exclusion wasn't justified —
DuckDB's own list_transform/struct_extract/map_entries+list_sort give a
direct, non-hacky way to implement hashing.py's exact rules (list ordered,
struct/map unordered-by-key) as SQL.
"""
from datetime import date, time
from decimal import Decimal

import duckdb
import pyarrow as pa
import pytest

from rowparity import CompareConfig, compare_tables
from rowparity.duckdb_pushdown import duckdb_keyed_compare, duckdb_keyless_compare


@pytest.fixture
def con():
    c = duckdb.connect(":memory:")
    yield c
    c.close()


def _sql(con, name, table: pa.Table) -> str:
    con.register(name, table)
    return f"SELECT * FROM {name}"


def assert_same_outcome(con, a: pa.Table, b: pa.Table, cfg_kwargs):
    cfg = CompareConfig(**cfg_kwargs)
    r_py = compare_tables(a, b, cfg)
    exp_sql = _sql(con, "exp_t", a)
    act_sql = _sql(con, "act_t", b)
    r_sql = duckdb_keyed_compare(con, exp_sql, act_sql, cfg) if cfg.keys else duckdb_keyless_compare(con, exp_sql, act_sql, cfg)

    assert r_py.equivalent == r_sql.equivalent, f"py={r_py.summary()} sql={r_sql.summary()}"
    assert r_py.missing_count == r_sql.missing_count
    assert r_py.added_count == r_sql.added_count
    assert r_py.changed_count == r_sql.changed_count
    return r_py, r_sql


# --------------------------------------------------------------------------- #
# date / time
# --------------------------------------------------------------------------- #

def test_date_matching_and_differing(con):
    a = pa.table({"id": [1, 2], "d": pa.array([date(2024, 1, 1), date(2024, 1, 2)])})
    b = pa.table({"id": [1, 2], "d": pa.array([date(2024, 1, 1), date(2024, 1, 3)])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


def test_time_matching_and_differing(con):
    a = pa.table({"id": [1, 2], "t": pa.array([time(9, 0, 0), time(13, 30, 0)])})
    b = pa.table({"id": [1, 2], "t": pa.array([time(9, 0, 0), time(14, 30, 0)])})
    assert_same_outcome(con, a, b, {"keys": ["id"]})


# --------------------------------------------------------------------------- #
# list — ORDERED by default
# --------------------------------------------------------------------------- #

def test_list_of_int_ordered_matching(con):
    a = pa.table({"id": [1], "tags": pa.array([[1, 2, 3]])})
    b = pa.table({"id": [1], "tags": pa.array([[1, 2, 3]])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent


def test_list_reordered_is_a_real_change_when_ordered(con):
    a = pa.table({"id": [1], "tags": pa.array([[1, 2, 3]])})
    b = pa.table({"id": [1], "tags": pa.array([[3, 2, 1]])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


def test_list_reordered_equivalent_when_unordered_list_columns(con):
    a = pa.table({"id": [1], "tags": pa.array([[1, 2, 3]])})
    b = pa.table({"id": [1], "tags": pa.array([[3, 2, 1]])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"], "unordered_list_columns": ["tags"]})
    assert r_sql.equivalent


def test_list_of_string(con):
    a = pa.table({"id": [1], "tags": pa.array([["a", "b"]])})
    b = pa.table({"id": [1], "tags": pa.array([["a", "c"]])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


# --------------------------------------------------------------------------- #
# struct — UNORDERED by field name
# --------------------------------------------------------------------------- #

def test_struct_matching_and_field_value_change(con):
    struct_type = pa.struct([("color", pa.string()), ("size", pa.string())])
    a = pa.table({"id": [1], "attrs": pa.array([{"color": "red", "size": "m"}], type=struct_type)})
    b = pa.table({"id": [1], "attrs": pa.array([{"color": "red", "size": "l"}], type=struct_type)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


def test_struct_field_order_in_the_type_does_not_matter(con):
    # struct is unordered BY FIELD NAME -- declaring fields in a different
    # order in the two schemas must not cause a false "changed" verdict.
    t_a = pa.struct([("color", pa.string()), ("size", pa.string())])
    t_b = pa.struct([("size", pa.string()), ("color", pa.string())])
    a = pa.table({"id": [1], "attrs": pa.array([{"color": "red", "size": "m"}], type=t_a)})
    b = pa.table({"id": [1], "attrs": pa.array([{"size": "m", "color": "red"}], type=t_b)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent


# --------------------------------------------------------------------------- #
# map — UNORDERED, keys sorted before hashing
# --------------------------------------------------------------------------- #

def test_map_key_order_does_not_matter(con):
    map_type = pa.map_(pa.string(), pa.int64())
    a = pa.table({"id": [1], "prefs": pa.array([[("a", 1), ("b", 2)]], type=map_type)})
    b = pa.table({"id": [1], "prefs": pa.array([[("b", 2), ("a", 1)]], type=map_type)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent


def test_map_value_change_detected(con):
    map_type = pa.map_(pa.string(), pa.int64())
    a = pa.table({"id": [1], "prefs": pa.array([[("a", 1)]], type=map_type)})
    b = pa.table({"id": [1], "prefs": pa.array([[("a", 2)]], type=map_type)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


# --------------------------------------------------------------------------- #
# recursion: list<struct>, struct<list>, struct<decimal> with differing scale
# --------------------------------------------------------------------------- #

def test_list_of_struct_matches_the_tpch_nested_bcv_shape(con):
    # exactly the line_items: list<struct<...>> shape from the nested BCV
    # example case -- reordering elements is a real change (list is ordered).
    item_type = pa.struct([("linenumber", pa.int64()), ("qty", pa.int64())])
    a = pa.table({"id": [1], "line_items": pa.array(
        [[{"linenumber": 1, "qty": 5}, {"linenumber": 2, "qty": 3}]], type=pa.list_(item_type)
    )})
    b_same = pa.table({"id": [1], "line_items": pa.array(
        [[{"linenumber": 1, "qty": 5}, {"linenumber": 2, "qty": 3}]], type=pa.list_(item_type)
    )})
    b_reordered = pa.table({"id": [1], "line_items": pa.array(
        [[{"linenumber": 2, "qty": 3}, {"linenumber": 1, "qty": 5}]], type=pa.list_(item_type)
    )})

    r_py, r_sql = assert_same_outcome(con, a, b_same, {"keys": ["id"]})
    assert r_sql.equivalent

    r_py2, r_sql2 = assert_same_outcome(con, a, b_reordered, {"keys": ["id"]})
    assert r_sql2.changed_count == 1


def test_struct_containing_a_list(con):
    t = pa.struct([("name", pa.string()), ("scores", pa.list_(pa.int64()))])
    a = pa.table({"id": [1], "profile": pa.array([{"name": "a", "scores": [1, 2]}], type=t)})
    b = pa.table({"id": [1], "profile": pa.array([{"name": "a", "scores": [2, 1]}], type=t)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1  # nested list still ordered even inside a struct


def test_struct_with_decimal_field_differing_scale_across_sides(con):
    # the peer_dtype threading: a decimal NESTED inside a struct should still
    # get the wider-of-both-sides scale, same as a top-level decimal column.
    t_a = pa.struct([("amount", pa.decimal128(10, 2))])
    t_b = pa.struct([("amount", pa.decimal128(10, 4))])
    a = pa.table({"id": [1], "line": pa.array([{"amount": Decimal("1.10")}], type=t_a)})
    b = pa.table({"id": [1], "line": pa.array([{"amount": Decimal("1.1000")}], type=t_b)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent  # 1.10 == 1.1000, trailing zeros don't matter, at any nesting depth


# --------------------------------------------------------------------------- #
# NULLs at every level
# --------------------------------------------------------------------------- #

def test_null_top_level_list_column(con):
    a = pa.table({"id": [1, 2], "tags": pa.array([[1, 2], None])})
    b = pa.table({"id": [1, 2], "tags": pa.array([[1, 2], None])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent


def test_null_list_element(con):
    a = pa.table({"id": [1], "tags": pa.array([[1, None, 3]])})
    b = pa.table({"id": [1], "tags": pa.array([[1, None, 3]])})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent

    c = pa.table({"id": [1], "tags": pa.array([[1, 2, 3]])})  # 2 instead of NULL
    r_py2, r_sql2 = assert_same_outcome(con, a, c, {"keys": ["id"]})
    assert r_sql2.changed_count == 1


def test_null_struct_field(con):
    t = pa.struct([("color", pa.string()), ("size", pa.string())])
    a = pa.table({"id": [1], "attrs": pa.array([{"color": "red", "size": None}], type=t)})
    b = pa.table({"id": [1], "attrs": pa.array([{"color": "red", "size": None}], type=t)})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent

    c = pa.table({"id": [1], "attrs": pa.array([{"color": "red", "size": ""}], type=t)})
    r_py2, r_sql2 = assert_same_outcome(con, a, c, {"keys": ["id"]})
    assert r_sql2.changed_count == 1  # NULL != "" per hashing.py's NULL-is-distinct rule


# --------------------------------------------------------------------------- #
# keyless mode with nested types
# --------------------------------------------------------------------------- #

def test_keyless_with_list_and_struct(con):
    t = pa.struct([("k", pa.string())])
    a = pa.table({"tags": pa.array([[1, 2]]), "meta": pa.array([{"k": "x"}], type=t)})
    b = pa.table({"tags": pa.array([[1, 2]]), "meta": pa.array([{"k": "y"}], type=t)})
    r_py, r_sql = assert_same_outcome(con, a, b, {})
    assert not r_sql.equivalent