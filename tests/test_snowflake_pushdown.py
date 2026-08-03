"""snowflake_pushdown.py coverage, split by what's actually verifiable
without a live Snowflake account:

  1. Pure SQL-string generation (_category, _canon_expr, _resolve_columns,
     _fingerprint_sql*) -- these are ordinary Python functions of
     (expr, fake ResultMetadata, CompareConfig) -> str, no connection needed.
  2. Orchestration (snowflake_keyed_compare / snowflake_keyless_compare)
     against a fake connection/cursor that answers canned SQL responses --
     verifies dedup-path selection, ComparisonResult assembly, and
     strict_columns gating. This does NOT prove the generated SQL actually
     runs on Snowflake -- only that the Python control flow around it is
     correct. See CLAUDE.md / the module docstring for that caveat.
"""
from collections import namedtuple

import pytest

from rowparity import snowflake_pushdown as spd
from rowparity.compare import CompareConfig

# Mirrors snowflake.connector.cursor.ResultMetadata's real fields exactly.
FakeMeta = namedtuple(
    "FakeMeta", ["name", "type_code", "display_size", "internal_size", "precision", "scale", "is_nullable"]
)

# Snowflake's FIELD_ID_TO_NAME type codes (from snowflake.connector.constants).
(FIXED, REAL, TEXT, DATE_T, VARIANT_T, TIMESTAMP_LTZ, TIMESTAMP_TZ, TIMESTAMP_NTZ,
 OBJECT_T, ARRAY_T, BINARY_T, TIME_T, BOOLEAN, GEOGRAPHY_T, MAP_T) = (
    0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 17,
)


def meta(name, type_code, precision=None, scale=None):
    return FakeMeta(name, type_code, None, None, precision, scale, True)


# --------------------------------------------------------------------------- #
# _category
# --------------------------------------------------------------------------- #

def test_category_int_vs_decimal_by_scale():
    assert spd._category(meta("n", FIXED, 38, 0)) == "int"
    assert spd._category(meta("n", FIXED, 38, 2)) == "decimal"


def test_category_scalars():
    assert spd._category(meta("n", REAL)) == "float"
    assert spd._category(meta("n", TEXT)) == "string"
    assert spd._category(meta("n", BOOLEAN)) == "bool"
    assert spd._category(meta("n", DATE_T)) == "date"
    assert spd._category(meta("n", TIME_T)) == "time"
    assert spd._category(meta("n", TIMESTAMP_NTZ)) == "timestamp_naive"
    assert spd._category(meta("n", TIMESTAMP_TZ)) == "timestamp_aware"
    assert spd._category(meta("n", TIMESTAMP_LTZ)) == "timestamp_aware"


def test_category_semi_structured_types():
    assert spd._category(meta("n", ARRAY_T)) == "semi_structured"
    assert spd._category(meta("n", OBJECT_T)) == "semi_structured"
    assert spd._category(meta("n", MAP_T)) == "semi_structured"
    assert spd._category(meta("n", VARIANT_T)) == "semi_structured"


def test_category_geography_raises_unsupported():
    with pytest.raises(spd.PushdownUnsupportedError, match="GEOGRAPHY"):
        spd._category(meta("n", GEOGRAPHY_T))


# --------------------------------------------------------------------------- #
# _canon_expr
# --------------------------------------------------------------------------- #

def test_canon_expr_wraps_null_check():
    cfg = CompareConfig()
    sql = spd._canon_expr('"n"', meta("n", FIXED, 38, 0), cfg, label="n")
    assert sql.startswith('CASE WHEN "n" IS NULL THEN chr(1) ELSE')
    assert sql.endswith("END")


def test_canon_expr_int_tag():
    cfg = CompareConfig()
    sql = spd._canon_expr('"n"', meta("n", FIXED, 38, 0), cfg, label="n")
    assert "'i:'" in sql
    assert 'TO_VARCHAR("n")' in sql


def test_canon_expr_float_requires_tolerance():
    cfg = CompareConfig(float_tolerance=0.0)
    with pytest.raises(spd.PushdownUnsupportedError, match="float_tolerance"):
        spd._canon_expr('"n"', meta("n", REAL), cfg, label="n")


def test_canon_expr_float_with_tolerance():
    cfg = CompareConfig(float_tolerance=0.01)
    sql = spd._canon_expr('"n"', meta("n", REAL), cfg, label="n")
    assert "'f:'" in sql
    assert "!= " in sql  # nan check
    assert "'inf'::FLOAT" in sql
    assert "0.01" in sql


def test_canon_expr_decimal_uses_wider_of_two_scales():
    cfg = CompareConfig()
    this_side = meta("n", FIXED, 10, 2)
    peer_side = meta("n", FIXED, 10, 4)
    sql = spd._canon_expr('"n"', this_side, cfg, label="n", peer_meta=peer_side)
    assert "NUMBER(38,4)" in sql  # widened to the peer's larger scale


def test_canon_expr_string_trim_and_case_insensitive():
    cfg = CompareConfig(trim_strings=True, case_insensitive=True)
    sql = spd._canon_expr('"n"', meta("n", TEXT), cfg, label="n")
    assert 'LOWER(TRIM("n"))' in sql


def test_canon_expr_timestamp_aware_converts_to_utc():
    cfg = CompareConfig()
    sql = spd._canon_expr('"n"', meta("n", TIMESTAMP_TZ), cfg, label="n")
    assert "CONVERT_TIMEZONE('UTC'" in sql


def test_canon_expr_unsupported_type_raises_with_guidance():
    cfg = CompareConfig()
    with pytest.raises(spd.PushdownUnsupportedError, match="ignore_columns"):
        spd._canon_expr('"n"', meta("n", GEOGRAPHY_T), cfg, label="n")


# --------------------------------------------------------------------------- #
# Semi-structured (ARRAY/OBJECT/MAP/VARIANT) -- UDF-based canonicalization.
#
# The first design (TYPEOF()/TABLE(FLATTEN(...)) inlined in a scalar
# subquery) was found live to be fundamentally broken -- Snowflake doesn't
# support a correlated table function nested in an arbitrary scalar
# subquery, even for the simplest single flat ARRAY column ("Unsupported
# subquery type cannot be evaluated"). Replaced with a single recursive JS
# UDF call per column; see the module docstring for the full story.
# --------------------------------------------------------------------------- #

def test_variant_udf_js_body_has_correct_tag_scheme():
    js = spd._variant_udf_js_body()
    # exactly one literal backslash + u0001/u0003/u0004 -- these must be JS
    # escape sequences the UDF interprets at runtime, not raw control bytes
    # sitting in the SQL/JS source text (found live: the tool layer that
    # authored this file initially turned -style text into literal
    # control bytes, which is NOT the same thing and had to be fixed).
    assert "'\\u0001'" in js
    assert "'\\u0003'" in js
    assert "'\\u0004'" in js
    assert "\x01" not in js
    assert "\x03" not in js
    assert "\x04" not in js
    for tag in ("'b:'", "'i:'", "'f:'", "'t:'", "'T:'", "'L:'", "'S:'", "'x:'"):
        assert tag in js


def test_variant_udf_js_body_recurses_and_sorts_object_keys():
    js = spd._variant_udf_js_body()
    assert "function canon(v, depth)" in js
    assert "canon(e, depth + 1)" in js  # array elements
    assert "canon(v[k], depth + 1)" in js  # object values
    assert "Object.keys(v).sort()" in js  # struct/map rule: sorted by key
    assert "depth === 0 && UNORDERED" in js  # unordered only applies at the top level


def test_variant_udf_js_body_handles_date_and_nan_inf():
    js = spd._variant_udf_js_body()
    assert "instanceof Date" in js
    assert "isFinite(v)" in js
    assert "isNaN(v)" in js


def test_variant_udf_create_sql_is_idempotent_and_qualified():
    sql = spd._variant_udf_create_sql("MYDB.MYSCHEMA.ROWPARITY_CANON_VARIANT")
    assert "CREATE FUNCTION IF NOT EXISTS MYDB.MYSCHEMA.ROWPARITY_CANON_VARIANT" in sql
    assert "LANGUAGE JAVASCRIPT" in sql
    assert "RETURNS STRING" in sql
    assert "V VARIANT" in sql
    assert spd._variant_udf_js_body() in sql


def test_canon_expr_semi_structured_calls_the_udf():
    cfg = CompareConfig(float_tolerance=0.01)
    sql = spd._canon_expr('"tags"', meta("tags", ARRAY_T), cfg, label="tags",
                           variant_udf_fqn="DB.SCH.ROWPARITY_CANON_VARIANT")
    assert sql == 'DB.SCH.ROWPARITY_CANON_VARIANT("tags", 0.01, FALSE, FALSE, FALSE, FALSE)'
    # works identically for OBJECT/MAP/VARIANT -- same one UDF, no per-type SQL branching needed
    for tc in (OBJECT_T, MAP_T, VARIANT_T):
        sql = spd._canon_expr('"v"', meta("v", tc), cfg, label="v", variant_udf_fqn="DB.SCH.FN")
        assert sql.startswith("DB.SCH.FN(")


def test_canon_expr_semi_structured_passes_config_flags_through():
    cfg = CompareConfig(float_tolerance=0.5, coerce_numeric_to_float=True, trim_strings=True,
                         case_insensitive=True)
    sql = spd._canon_expr('"attrs"', meta("attrs", OBJECT_T), cfg, label="attrs",
                           unordered=True, variant_udf_fqn="FN")
    assert sql == 'FN("attrs", 0.5, TRUE, TRUE, TRUE, TRUE)'


def test_canon_expr_semi_structured_requires_float_tolerance():
    # even a purely-string ARRAY column needs float_tolerance > 0, since the
    # UDF divides by FLOAT_TOL for any nested numeric value regardless of
    # what's actually in the data (see module docstring).
    cfg = CompareConfig(float_tolerance=0.0)
    with pytest.raises(spd.PushdownUnsupportedError, match="float_tolerance"):
        spd._canon_expr('"tags"', meta("tags", ARRAY_T), cfg, label="tags", variant_udf_fqn="FN")


def test_any_semi_structured():
    types = {"id": meta("id", FIXED, 38, 0), "tags": meta("tags", ARRAY_T)}
    assert spd._any_semi_structured(["id", "tags"], types)
    assert not spd._any_semi_structured(["id"], types)


def test_ensure_variant_udf_creates_qualified_function_and_returns_fqn():
    executed = []

    class FakeCur:
        def execute(self, sql):
            executed.append(sql)
            return self

        def fetchone(self):
            return ("MYDB", "MYSCHEMA")

    class FakeCon:
        def cursor(self):
            return FakeCur()

    fqn = spd._ensure_variant_udf(FakeCon())
    assert fqn == "MYDB.MYSCHEMA.ROWPARITY_CANON_VARIANT"
    assert any("CREATE FUNCTION IF NOT EXISTS MYDB.MYSCHEMA.ROWPARITY_CANON_VARIANT" in sql for sql in executed)


def test_resolve_columns_no_longer_raises_for_array_type():
    exp_types = {"tags": meta("tags", ARRAY_T)}
    act_types = {"tags": meta("tags", ARRAY_T)}
    cfg = CompareConfig(float_tolerance=0.01)
    compared, only_exp, only_act, mismatches = spd._resolve_columns(exp_types, act_types, cfg)
    assert compared == ["tags"]
    assert mismatches == []


# --------------------------------------------------------------------------- #
# _resolve_columns
# --------------------------------------------------------------------------- #

def test_resolve_columns_detects_type_mismatch():
    exp_types = {"id": meta("id", FIXED, 38, 0), "amt": meta("amt", FIXED, 10, 2)}
    act_types = {"id": meta("id", FIXED, 38, 0), "amt": meta("amt", REAL)}
    cfg = CompareConfig()
    compared, only_exp, only_act, mismatches = spd._resolve_columns(exp_types, act_types, cfg)
    assert compared == ["amt", "id"]
    assert mismatches == [("amt", "NUMBER(10,2)", "REAL")]


def test_resolve_columns_schema_drift():
    exp_types = {"id": meta("id", FIXED, 38, 0), "old_col": meta("old_col", TEXT)}
    act_types = {"id": meta("id", FIXED, 38, 0), "new_col": meta("new_col", TEXT)}
    cfg = CompareConfig()
    compared, only_exp, only_act, mismatches = spd._resolve_columns(exp_types, act_types, cfg)
    assert compared == ["id"]
    assert only_exp == ["old_col"]
    assert only_act == ["new_col"]


# --------------------------------------------------------------------------- #
# Orchestration, via a fake connection/cursor
# --------------------------------------------------------------------------- #

class FakeCursor:
    def __init__(self, describe_fn, execute_fn):
        self._describe_fn = describe_fn
        self._execute_fn = execute_fn
        self._result = None

    def describe(self, sql):
        return self._describe_fn(sql)

    def execute(self, sql):
        self._result = self._execute_fn(sql)
        return self

    def fetchone(self):
        return self._result["one"]

    def fetchall(self):
        return self._result["all"]

    def fetch_arrow_all(self):
        return self._result["arrow"]


class FakeConnection:
    def __init__(self, describe_fn, execute_fn):
        self._describe_fn = describe_fn
        self._execute_fn = execute_fn

    def cursor(self):
        return FakeCursor(self._describe_fn, self._execute_fn)


EXP_TYPES = {"id": meta("id", FIXED, 38, 0), "amt": meta("amt", FIXED, 10, 2)}
ACT_TYPES = {"id": meta("id", FIXED, 38, 0), "amt": meta("amt", FIXED, 10, 2)}


def _describe_for(expected_sql, actual_sql):
    def describe_fn(sql):
        if "raw_expected" in sql:
            return list(EXP_TYPES.values())
        if "raw_actual" in sql:
            return list(ACT_TYPES.values())
        raise AssertionError(f"unexpected describe() call: {sql}")
    return describe_fn


def test_keyed_compare_no_duplicates_clean_match():
    """No duplicate keys -> fast path; zero diffs -> equivalent."""
    def execute_fn(sql):
        if "__rp_cnt - 1" in sql:  # _duplicate_count
            return {"one": (0,), "all": [], "arrow": None}
        if sql.strip().startswith("SELECT COUNT(*) FROM ("):  # _row_count
            return {"one": (100,), "all": [], "arrow": None}
        if "COUNT_IF" in sql:  # _join_counts
            return {"one": (0, 0, 0), "all": [], "arrow": None}
        raise AssertionError(f"unexpected execute() call: {sql}")

    con = FakeConnection(_describe_for("raw_expected", "raw_actual"), execute_fn)
    cfg = CompareConfig(keys=["id"], float_tolerance=0.01)
    result = spd.snowflake_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)

    assert result.equivalent
    assert result.expected_rows == 100
    assert result.actual_rows == 100
    assert result.missing_count == 0 and result.added_count == 0 and result.changed_count == 0
    assert result.duplicate_keys_expected == 0
    assert result.duplicate_keys_actual == 0


def test_keyed_compare_duplicates_present_takes_dedup_path():
    seen_group_by = {"expected": False, "actual": False}

    def execute_fn(sql):
        if "__rp_cnt - 1" in sql:  # _duplicate_count
            if "raw_expected" in sql:
                return {"one": (3,), "all": [], "arrow": None}
            return {"one": (0,), "all": [], "arrow": None}
        if sql.strip().startswith("SELECT COUNT(*) FROM ("):  # _row_count
            return {"one": (50,), "all": [], "arrow": None}
        if "COUNT_IF" in sql:  # _join_counts -- dedup path means GROUP BY appears in the CTEs
            if "GROUP BY" in sql:
                seen_group_by["expected"] = True
            return {"one": (0, 0, 0), "all": [], "arrow": None}
        raise AssertionError(f"unexpected execute() call: {sql}")

    con = FakeConnection(_describe_for("raw_expected", "raw_actual"), execute_fn)
    cfg = CompareConfig(keys=["id"], float_tolerance=0.01)
    result = spd.snowflake_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)

    assert result.duplicate_keys_expected == 3
    assert result.duplicate_keys_actual == 0
    assert seen_group_by["expected"]  # confirms the dedup (GROUP BY ANY_VALUE) path was actually used


def test_keyed_compare_strict_columns_fails_on_type_mismatch_even_with_zero_row_diffs():
    exp_types = {"id": meta("id", FIXED, 38, 0), "amt": meta("amt", FIXED, 10, 2)}
    act_types = {"id": meta("id", FIXED, 38, 0), "amt": meta("amt", REAL)}

    def describe_fn(sql):
        return list(exp_types.values()) if "raw_expected" in sql else list(act_types.values())

    def execute_fn(sql):
        if "__rp_cnt - 1" in sql:
            return {"one": (0,), "all": [], "arrow": None}
        if sql.strip().startswith("SELECT COUNT(*) FROM ("):
            return {"one": (10,), "all": [], "arrow": None}
        if "COUNT_IF" in sql:
            return {"one": (0, 0, 0), "all": [], "arrow": None}
        raise AssertionError(f"unexpected execute() call: {sql}")

    con = FakeConnection(describe_fn, execute_fn)
    cfg_lenient = CompareConfig(keys=["id"], float_tolerance=0.01, strict_columns=False)
    result_lenient = spd.snowflake_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg_lenient)
    assert result_lenient.equivalent  # type mismatch reported but doesn't fail when lenient
    assert result_lenient.type_mismatches == [("amt", "NUMBER(10,2)", "REAL")]

    cfg_strict = CompareConfig(keys=["id"], float_tolerance=0.01, strict_columns=True)
    result_strict = spd.snowflake_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg_strict)
    assert not result_strict.equivalent  # same data, but strict mode fails on the type drift


def test_keyed_compare_requires_keys():
    con = FakeConnection(lambda sql: [], lambda sql: {"one": None, "all": [], "arrow": None})
    with pytest.raises(spd.PushdownUnsupportedError):
        spd.snowflake_keyed_compare(con, "SELECT 1", "SELECT 1", CompareConfig())


def test_keyless_compare_basic():
    def describe_fn(sql):
        return list(EXP_TYPES.values()) if "raw_expected" in sql else list(ACT_TYPES.values())

    def execute_fn(sql):
        if "SELECT\n        (SELECT COUNT(*) FROM e)" in sql or "(SELECT COUNT(*) FROM e)" in sql:
            return {"one": (20, 20, 0, 0), "all": [], "arrow": None}
        raise AssertionError(f"unexpected execute() call: {sql}")

    con = FakeConnection(describe_fn, execute_fn)
    cfg = CompareConfig(float_tolerance=0.01)
    result = spd.snowflake_keyless_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
    assert result.equivalent
    assert result.keys is None
    assert result.expected_rows == 20 and result.actual_rows == 20


def test_keyless_compare_rejects_keys():
    con = FakeConnection(lambda sql: [], lambda sql: {"one": None, "all": [], "arrow": None})
    with pytest.raises(spd.PushdownUnsupportedError):
        spd.snowflake_keyless_compare(con, "SELECT 1", "SELECT 1", CompareConfig(keys=["id"]))


# --------------------------------------------------------------------------- #
# resolve_pushdown_sql / open_pushdown_connection
# --------------------------------------------------------------------------- #

def test_resolve_pushdown_sql_table_shorthand():
    assert spd.resolve_pushdown_sql({"type": "snowflake", "table": "db.sch.orders"}) == "SELECT * FROM db.sch.orders"


def test_resolve_pushdown_sql_query():
    spec = {"type": "snowflake", "query": "SELECT id FROM orders"}
    assert spd.resolve_pushdown_sql(spec) == "SELECT id FROM orders"


def test_resolve_pushdown_sql_rejects_non_snowflake_source():
    with pytest.raises(spd.PushdownUnsupportedError, match="parquet"):
        spd.resolve_pushdown_sql({"type": "parquet", "path": "x.parquet"})


def test_open_pushdown_connection_rejects_cross_account(monkeypatch):
    monkeypatch.delenv("SNOWFLAKE_ACCOUNT", raising=False)
    specs = [
        {"type": "snowflake", "connection": {"account": "acct_a"}, "table": "t"},
        {"type": "snowflake", "connection": {"account": "acct_b"}, "table": "t"},
    ]
    with pytest.raises(spd.PushdownUnsupportedError, match="different accounts"):
        spd.open_pushdown_connection(specs)


# --------------------------------------------------------------------------- #
# _resolve_cfg_column_casing -- Snowflake uppercases unquoted identifiers,
# but YAML case config isn't written with that in mind. Found live: a
# `keys: [id]` case against a real Snowflake table (column actually named
# ID) raised "key column 'id' is missing" even though the column exists.
# --------------------------------------------------------------------------- #

def test_resolve_cfg_column_casing_resolves_lowercase_keys_to_real_uppercase():
    exp_types = {"ID": meta("ID", FIXED, 38, 0), "AMOUNT": meta("AMOUNT", FIXED, 10, 2)}
    act_types = dict(exp_types)
    cfg = CompareConfig(keys=["id"], select=["amount"])
    resolved = spd._resolve_cfg_column_casing(cfg, exp_types, act_types)
    assert resolved.keys == ["ID"]
    assert resolved.select == ["AMOUNT"]


def test_resolve_cfg_column_casing_resolves_ignore_and_unordered_list_columns():
    exp_types = {"ID": meta("ID", FIXED, 38, 0), "TAGS": meta("TAGS", ARRAY_T)}
    act_types = dict(exp_types)
    cfg = CompareConfig(keys=["id"], ignore_columns=["tags"], unordered_list_columns=["tags"])
    resolved = spd._resolve_cfg_column_casing(cfg, exp_types, act_types)
    assert resolved.ignore_columns == ["TAGS"]
    assert resolved.unordered_list_columns == ["TAGS"]


def test_resolve_cfg_column_casing_preserves_already_correct_case():
    exp_types = {"ID": meta("ID", FIXED, 38, 0)}
    act_types = dict(exp_types)
    cfg = CompareConfig(keys=["ID"])
    resolved = spd._resolve_cfg_column_casing(cfg, exp_types, act_types)
    assert resolved.keys == ["ID"]


def test_resolve_cfg_column_casing_raises_for_truly_missing_column():
    exp_types = {"ID": meta("ID", FIXED, 38, 0)}
    act_types = dict(exp_types)
    cfg = CompareConfig(keys=["does_not_exist"])
    with pytest.raises(ValueError, match="does_not_exist"):
        spd._resolve_cfg_column_casing(cfg, exp_types, act_types)


def test_resolve_cfg_column_casing_falls_back_to_actual_side_if_missing_from_expected():
    # a column that exists (in some casing) on the actual side only should
    # still resolve -- _resolve_columns downstream is what decides whether
    # a one-sided column is real schema drift, not this casing step.
    exp_types = {"ID": meta("ID", FIXED, 38, 0)}
    act_types = {"ID": meta("ID", FIXED, 38, 0), "NEW_COL": meta("NEW_COL", TEXT)}
    cfg = CompareConfig(keys=["id"], ignore_columns=["new_col"])
    resolved = spd._resolve_cfg_column_casing(cfg, exp_types, act_types)
    assert resolved.ignore_columns == ["NEW_COL"]


def test_keyed_compare_with_lowercase_yaml_keys_against_uppercase_columns():
    """End-to-end (via the fake connection) reproduction of the live bug:
    a YAML case writing keys: [id] must work against a real Snowflake
    table where cursor.describe() reports the column as ID."""
    exp_types = {"ID": meta("ID", FIXED, 38, 0), "AMOUNT": meta("AMOUNT", FIXED, 10, 2)}
    act_types = dict(exp_types)

    def describe_fn(sql):
        return list(exp_types.values()) if "raw_expected" in sql else list(act_types.values())

    def execute_fn(sql):
        if "__rp_cnt - 1" in sql:
            return {"one": (0,), "all": [], "arrow": None}
        if sql.strip().startswith("SELECT COUNT(*) FROM ("):
            return {"one": (5,), "all": [], "arrow": None}
        if "COUNT_IF" in sql:
            return {"one": (0, 0, 0), "all": [], "arrow": None}
        raise AssertionError(f"unexpected execute() call: {sql}")

    con = FakeConnection(describe_fn, execute_fn)
    cfg = CompareConfig(keys=["id"], float_tolerance=0.01)  # lowercase, like a human would write it
    result = spd.snowflake_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
    assert result.keys == ["ID"]  # resolved to the real column name
    assert result.equivalent
