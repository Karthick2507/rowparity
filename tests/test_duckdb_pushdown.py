"""Stage A: DuckDB SQL push-down. Parity tests against compare_tables() — the
SQL fingerprint path must reach the same verdict as the row-wise Python
engine, since it's an alternative execution strategy, not a semantic change.
"""
from datetime import datetime, timezone

import duckdb
import pyarrow as pa
import pytest

from rowparity import CompareConfig, compare_tables
from rowparity.duckdb_pushdown import (
    PushdownUnsupportedError,
    duckdb_keyed_compare,
    duckdb_keyless_compare,
)


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
    r_sql = duckdb_keyed_compare(con, exp_sql, act_sql, cfg)

    assert r_py.equivalent == r_sql.equivalent
    assert r_py.expected_rows == r_sql.expected_rows, "expected_rows mismatch"
    assert r_py.actual_rows == r_sql.actual_rows, "actual_rows mismatch"
    assert r_py.missing_count == r_sql.missing_count
    assert r_py.added_count == r_sql.added_count
    assert r_py.changed_count == r_sql.changed_count
    assert r_py.duplicate_keys_expected == r_sql.duplicate_keys_expected
    assert r_py.duplicate_keys_actual == r_sql.duplicate_keys_actual
    return r_py, r_sql


def test_missing_added_changed(con):
    a = pa.table({"id": [1, 2, 3], "v": [10, 20, 30]})
    b = pa.table({"id": [2, 3, 4], "v": [20, 999, 40]})
    assert_same_outcome(con, a, b, {"keys": ["id"]})


def test_float_tolerance_and_nan_inf(con):
    a = pa.table({"id": [1, 2, 3, 4], "f": [1.0, 1.0, float("nan"), float("inf")]})
    b = pa.table({"id": [1, 2, 3, 4], "f": [1.0004, 1.002, float("nan"), float("inf")]})
    assert_same_outcome(con, a, b, {"keys": ["id"], "float_tolerance": 0.001})


def test_string_trim_and_case_insensitive(con):
    a = pa.table({"id": [1, 2, 3], "s": [" Abc ", "def", "GHI"]})
    b = pa.table({"id": [1, 2, 3], "s": ["abc", "DEF", "ghi"]})
    assert_same_outcome(con, a, b, {"keys": ["id"], "trim_strings": True, "case_insensitive": True})


def test_timestamp_naive(con):
    a = pa.table({"id": [1, 2], "t": pa.array([datetime(2020, 1, 1, 0, 0, 0), datetime(2020, 1, 1, 7, 30, 0)])})
    b = pa.table({"id": [1, 2], "t": pa.array([datetime(2020, 1, 1, 0, 0, 0), datetime(2020, 1, 1, 7, 30, 1)])})
    assert_same_outcome(con, a, b, {"keys": ["id"]})


def test_timestamp_aware_utc_normalization(con):
    aware_a = pa.array([datetime(2020, 1, 1, 12, 0, 0, tzinfo=timezone.utc)])
    aware_b = pa.array([datetime(2020, 1, 1, 12, 0, 0, tzinfo=timezone.utc)])
    a = pa.table({"id": [1], "t": aware_a})
    b = pa.table({"id": [1], "t": aware_b})
    assert_same_outcome(con, a, b, {"keys": ["id"]})


def test_duplicate_keys(con):
    a = pa.table({"id": [1, 1, 2], "v": [10, 10, 20]})
    b = pa.table({"id": [1, 2], "v": [10, 20]})
    assert_same_outcome(con, a, b, {"keys": ["id"]})


def test_ignore_columns_and_select(con):
    a = pa.table({"id": [1, 2], "v": [10, 20], "note": ["x", "y"]})
    b = pa.table({"id": [1, 2], "v": [10, 99], "note": ["z", "y"]})
    assert_same_outcome(con, a, b, {"keys": ["id"], "ignore_columns": ["note"]})
    assert_same_outcome(con, a, b, {"keys": ["id"], "select": ["id", "v"]})


def test_equivalent_tables_report_no_diff(con):
    a = pa.table({"id": [1, 2, 3], "v": [10, 20, 30]})
    b = pa.table({"id": [1, 2, 3], "v": [10, 20, 30]})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent is True


def test_examples_are_populated_for_changed_rows(con):
    a = pa.table({"id": [1, 2, 3], "v": [10, 20, 30]})
    b = pa.table({"id": [1, 2, 3], "v": [10, 20, 999]})
    _, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert len(r_sql.examples) == 1
    assert r_sql.examples[0].kind == "changed"
    assert r_sql.examples[0].columns[0].column == "v"
    assert (r_sql.examples[0].columns[0].expected, r_sql.examples[0].columns[0].actual) == (30, 999)


def test_requires_keys(con):
    a = pa.table({"id": [1], "v": [10]})
    exp_sql = _sql(con, "e2", a)
    act_sql = _sql(con, "a2", a)
    with pytest.raises(PushdownUnsupportedError):
        duckdb_keyed_compare(con, exp_sql, act_sql, CompareConfig())


def test_float_without_tolerance_raises_unsupported(con):
    a = pa.table({"id": [1], "f": [1.0]})
    exp_sql = _sql(con, "e4", a)
    act_sql = _sql(con, "a4", a)
    with pytest.raises(PushdownUnsupportedError):
        duckdb_keyed_compare(con, exp_sql, act_sql, CompareConfig(keys=["id"]))


# --------------------------------------------------------------------------- #
# Keyless / multiset mode — the "no natural key" case
# --------------------------------------------------------------------------- #
def assert_same_outcome_keyless(con, a: pa.Table, b: pa.Table, cfg_kwargs):
    cfg = CompareConfig(**cfg_kwargs)
    r_py = compare_tables(a, b, cfg)
    exp_sql = _sql(con, "kl_exp", a)
    act_sql = _sql(con, "kl_act", b)
    r_sql = duckdb_keyless_compare(con, exp_sql, act_sql, cfg)

    assert r_py.equivalent == r_sql.equivalent
    assert r_py.expected_rows == r_sql.expected_rows, "expected_rows mismatch"
    assert r_py.actual_rows == r_sql.actual_rows, "actual_rows mismatch"
    assert r_py.missing_count == r_sql.missing_count
    assert r_py.added_count == r_sql.added_count
    return r_py, r_sql


def test_keyless_multiset_basic(con):
    a = pa.table({"x": [1, 2, 2, 3], "y": ["a", "b", "b", "c"]})
    b = pa.table({"x": [3, 2, 1, 1], "y": ["c", "b", "a", "a"]})
    assert_same_outcome_keyless(con, a, b, {})


def test_keyless_duplicate_row_counts_matter(con):
    # same distinct rows, but 'a' has 3 copies of one row and 'b' has 1 ->
    # multiset semantics must catch the count mismatch, not just set membership.
    a = pa.table({"x": [1, 1, 1, 2]})
    b = pa.table({"x": [1, 2]})
    r_py, r_sql = assert_same_outcome_keyless(con, a, b, {})
    assert r_sql.missing_count == 2
    assert r_sql.added_count == 0


def test_keyless_float_tolerance(con):
    a = pa.table({"amount": [10.0, 20.0, 30.0]})
    b = pa.table({"amount": [10.0004, 20.0, 999.0]})
    assert_same_outcome_keyless(con, a, b, {"float_tolerance": 0.001})


def test_keyless_string_trim_case_insensitive(con):
    a = pa.table({"note": [" Abc ", "def"]})
    b = pa.table({"note": ["abc", "DEF"]})
    assert_same_outcome_keyless(con, a, b, {"trim_strings": True, "case_insensitive": True})


def test_keyless_equivalent_tables(con):
    a = pa.table({"x": [1, 2, 3]})
    b = pa.table({"x": [3, 2, 1]})
    r_py, r_sql = assert_same_outcome_keyless(con, a, b, {})
    assert r_sql.equivalent is True


def test_keyless_examples_populated(con):
    a = pa.table({"x": [1, 2, 3], "note": ["a", "b", "c"]})
    b = pa.table({"x": [1, 2, 999], "note": ["a", "b", "z"]})
    _, r_sql = assert_same_outcome_keyless(con, a, b, {})
    assert len(r_sql.examples) > 0
    kinds = {e.kind for e in r_sql.examples}
    assert kinds <= {"missing", "added"}


def test_keyless_rejects_keys(con):
    a = pa.table({"id": [1], "v": [10]})
    exp_sql = _sql(con, "kl_e2", a)
    act_sql = _sql(con, "kl_a2", a)
    with pytest.raises(PushdownUnsupportedError):
        duckdb_keyless_compare(con, exp_sql, act_sql, CompareConfig(keys=["id"]))


# --------------------------------------------------------------------------- #
# Decimal support
# --------------------------------------------------------------------------- #
def test_decimal_trailing_zeros_are_equal(con):
    from decimal import Decimal
    a = pa.table({"id": [1], "amt": pa.array([Decimal("1.10")], type=pa.decimal128(10, 2))})
    b = pa.table({"id": [1], "amt": pa.array([Decimal("1.1")], type=pa.decimal128(10, 1))})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent is True


def test_decimal_different_scales_across_sides_still_compare_correctly(con):
    # expected has more precision than actual declares -> must not truncate
    # expected down to actual's scale and hide a real difference.
    from decimal import Decimal
    a = pa.table({"id": [1, 2], "amt": pa.array([Decimal("1.123456"), Decimal("2.000000")], type=pa.decimal128(18, 6))})
    b = pa.table({"id": [1, 2], "amt": pa.array([Decimal("1.12"), Decimal("2.00")], type=pa.decimal128(10, 2))})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1  # row 1 genuinely differs beyond scale 2; row 2 matches


def test_decimal_negative_and_integer_values(con):
    from decimal import Decimal
    a = pa.table({"id": [1, 2], "amt": pa.array([Decimal("-1.50"), Decimal("100")], type=pa.decimal128(10, 2))})
    b = pa.table({"id": [1, 2], "amt": pa.array([Decimal("-1.5"), Decimal("100.00")], type=pa.decimal128(10, 2))})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent is True


def test_decimal_genuine_mismatch_detected(con):
    from decimal import Decimal
    a = pa.table({"id": [1], "amt": pa.array([Decimal("10.00")], type=pa.decimal128(10, 2))})
    b = pa.table({"id": [1], "amt": pa.array([Decimal("10.01")], type=pa.decimal128(10, 2))})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


def test_decimal_coerce_numeric_to_float(con):
    from decimal import Decimal
    a = pa.table({"id": [1], "amt": pa.array([Decimal("10.00")], type=pa.decimal128(10, 2))})
    b = pa.table({"id": [1], "amt": pa.array([10.0004], type=pa.float64())})
    r_py, r_sql = assert_same_outcome(
        con, a, b, {"keys": ["id"], "coerce_numeric_to_float": True, "float_tolerance": 0.001}
    )
    assert r_sql.equivalent is True


def test_decimal_keyless(con):
    from decimal import Decimal
    a = pa.table({"amt": pa.array([Decimal("1.10"), Decimal("2.00")], type=pa.decimal128(10, 2))})
    b = pa.table({"amt": pa.array([Decimal("2.0"), Decimal("1.1")], type=pa.decimal128(10, 1))})
    assert_same_outcome_keyless(con, a, b, {})


# --------------------------------------------------------------------------- #
# Edge cases: composite keys, empty tables, all-null columns, max_examples=0
# --------------------------------------------------------------------------- #
def test_composite_key_changed_row(con):
    a = pa.table({"day": ["d1", "d1", "d2"], "region": ["e", "w", "e"], "v": [10, 20, 30]})
    b = pa.table({"day": ["d1", "d1", "d2"], "region": ["e", "w", "e"], "v": [10, 999, 30]})
    _, r_sql = assert_same_outcome(con, a, b, {"keys": ["day", "region"]})
    assert r_sql.examples[0].key == (("t", "d1"), ("t", "w"))


def test_composite_key_duplicates():
    # Regression: expected_rows/actual_rows must reflect raw row counts, not
    # the distinct-key count, even when the duplicate-key dedup path is taken.
    con = duckdb.connect(":memory:")
    a = pa.table({"day": ["d1", "d1", "d2"], "region": ["e", "e", "w"], "v": [1, 1, 2]})
    b = pa.table({"day": ["d1", "d2"], "region": ["e", "w"], "v": [1, 2]})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["day", "region"]})
    assert r_sql.expected_rows == 3
    assert r_sql.actual_rows == 2
    assert r_sql.duplicate_keys_expected == 1
    con.close()


def test_both_sides_empty_keyed(con):
    a = pa.table({"id": pa.array([], type=pa.int64()), "v": pa.array([], type=pa.int64())})
    b = pa.table({"id": pa.array([], type=pa.int64()), "v": pa.array([], type=pa.int64())})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent is True


def test_both_sides_empty_keyless(con):
    a = pa.table({"v": pa.array([], type=pa.int64())})
    b = pa.table({"v": pa.array([], type=pa.int64())})
    r_py, r_sql = assert_same_outcome_keyless(con, a, b, {})
    assert r_sql.equivalent is True


def test_one_side_empty_keyed(con):
    a = pa.table({"id": [1, 2], "v": [10, 20]})
    b = pa.table({"id": pa.array([], type=pa.int64()), "v": pa.array([], type=pa.int64())})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.missing_count == 2


def test_all_null_column_matches(con):
    a = pa.table({"id": [1, 2], "v": pa.array([None, None], type=pa.int64())})
    b = pa.table({"id": [1, 2], "v": pa.array([None, None], type=pa.int64())})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.equivalent is True


def test_null_vs_value_detected(con):
    a = pa.table({"id": [1, 2], "v": pa.array([None, 5], type=pa.int64())})
    b = pa.table({"id": [1, 2], "v": pa.array([None, 6], type=pa.int64())})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"]})
    assert r_sql.changed_count == 1


def test_max_examples_zero_suppresses_examples_but_keeps_counts(con):
    a = pa.table({"id": [1, 2], "v": [10, 20]})
    b = pa.table({"id": [1, 2], "v": [10, 999]})
    r_py, r_sql = assert_same_outcome(con, a, b, {"keys": ["id"], "max_examples": 0})
    assert r_sql.changed_count == 1
    assert r_sql.examples == []


def test_strict_columns_catches_type_drift(con):
    # Regression: strict_columns must fail on a genuine cross-side type
    # difference through push-down too, not just the Python engine.
    a = pa.table({"id": [1, 2], "v": pa.array([10, 20], type=pa.int32())})
    b = pa.table({"id": [1, 2], "v": pa.array([10, 20], type=pa.int64())})
    exp_sql = _sql(con, "sc_e", a)
    act_sql = _sql(con, "sc_a", b)
    cfg = CompareConfig(keys=["id"], strict_columns=True)
    r_py = compare_tables(a, b, cfg)
    r_sql = duckdb_keyed_compare(con, exp_sql, act_sql, cfg)
    assert r_py.equivalent is False
    assert r_sql.equivalent is False
    assert len(r_sql.type_mismatches) == 1
    assert r_sql.type_mismatches[0][0] == "v"


def test_type_drift_without_strict_columns_still_reported_but_passes(con):
    a = pa.table({"id": [1, 2], "v": pa.array([10, 20], type=pa.int32())})
    b = pa.table({"id": [1, 2], "v": pa.array([10, 20], type=pa.int64())})
    exp_sql = _sql(con, "sc2_e", a)
    act_sql = _sql(con, "sc2_a", b)
    cfg = CompareConfig(keys=["id"])  # strict_columns defaults to False
    r_sql = duckdb_keyed_compare(con, exp_sql, act_sql, cfg)
    assert r_sql.equivalent is True
    assert len(r_sql.type_mismatches) == 1


def test_nested_type_drift_detected_like_the_default_engine(con):
    # list/struct/map are now fully canonicalized by push-down (see the
    # dedicated nested-type test file) -- a genuine element-type drift is
    # just a normal changed row + type_mismatch, exactly like compare_tables().
    a = pa.table({"id": [1], "tags": pa.array([[1, 2]], type=pa.list_(pa.int64()))})
    b = pa.table({"id": [1], "tags": pa.array([["x", "y"]], type=pa.list_(pa.string()))})
    exp_sql = _sql(con, "nt_e", a)
    act_sql = _sql(con, "nt_a", b)

    r_py = compare_tables(a, b, CompareConfig(keys=["id"]))
    r_sql = duckdb_keyed_compare(con, exp_sql, act_sql, CompareConfig(keys=["id"]))
    assert r_py.changed_count == r_sql.changed_count == 1
    assert len(r_sql.type_mismatches) == 1
    assert r_sql.type_mismatches[0][0] == "tags"
