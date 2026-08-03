"""trino_pushdown.py and trino_auth.py coverage, split by what is
verifiable without a live Trino cluster:

  1. Pure Python functions (_parse_type, _category, _canon_expr,
     _fingerprint_sql*, _resolve_columns) — no connection needed, just
     strings and _TrinoType objects in, SQL strings out.
  2. Orchestration (trino_keyed_compare / trino_keyless_compare) against a
     fake cursor/connection that answers canned SQL responses — verifies
     dedup-path selection, ComparisonResult assembly, and strict_columns
     gating without a real cluster.
  3. Connection helpers (resolve_pushdown_sql, open_pushdown_connection) and
     trino_auth.resolve_connection_args.
"""

import pytest

from rowparity import trino_pushdown as tpd
from rowparity.compare import CompareConfig
from rowparity.trino_pushdown import (
    PushdownUnsupportedError,
    _canon_expr,
    _category,
    _fingerprint_sql,
    _fingerprint_sql_full,
    _parse_type,
    _resolve_columns,
    _TrinoType,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _t(type_str: str) -> _TrinoType:
    return _parse_type(type_str)


def _types(**cols) -> dict:
    return {name: _parse_type(type_str) for name, type_str in cols.items()}


# ---------------------------------------------------------------------------
# _parse_type
# ---------------------------------------------------------------------------

class TestParseType:
    def test_simple_scalars(self):
        for s, expected_id in [
            ("boolean", "boolean"),
            ("tinyint", "tinyint"), ("smallint", "smallint"),
            ("integer", "integer"), ("bigint", "bigint"),
            ("real", "real"), ("double", "double"),
            ("varchar", "varchar"), ("char", "varchar"),
            ("varbinary", "varbinary"), ("json", "json"),
            ("date", "date"), ("time", "time"),
            ("timestamp", "timestamp"),
            ("time with time zone", "time_tz"),
            ("timestamp with time zone", "timestamp_tz"),
        ]:
            assert _parse_type(s).id == expected_id, f"failed for {s!r}"

    def test_varchar_with_length_normalises_to_varchar(self):
        assert _parse_type("varchar(255)").id == "varchar"
        assert _parse_type("char(10)").id == "varchar"

    def test_decimal_precision_and_scale(self):
        t = _parse_type("decimal(18, 4)")
        assert t.id == "decimal"
        assert t.precision == 18
        assert t.scale == 4

    def test_decimal_no_scale_defaults_to_zero(self):
        t = _parse_type("decimal(10)")
        assert t.scale == 0

    def test_timestamp_with_precision(self):
        assert _parse_type("timestamp(6)").id == "timestamp"
        assert _parse_type("timestamp(3)").id == "timestamp"

    def test_timestamp_with_precision_and_tz(self):
        assert _parse_type("timestamp(6) with time zone").id == "timestamp_tz"

    def test_time_with_precision_and_tz(self):
        assert _parse_type("time(3) with time zone").id == "time_tz"

    def test_array_element_type(self):
        t = _parse_type("array(integer)")
        assert t.id == "array"
        assert t.element.id == "integer"

    def test_array_of_varchar(self):
        t = _parse_type("array(varchar)")
        assert t.element.id == "varchar"

    def test_map_key_and_value(self):
        t = _parse_type("map(varchar, bigint)")
        assert t.id == "map"
        assert t.key.id == "varchar"
        assert t.value.id == "bigint"

    def test_row_fields_parsed_and_named(self):
        t = _parse_type("row(id bigint, name varchar)")
        assert t.id == "row"
        assert len(t.fields) == 2
        names = {f[0] for f in t.fields}
        assert names == {"id", "name"}

    def test_row_field_types_parsed_correctly(self):
        t = _parse_type("row(score double, ts timestamp)")
        field_map = dict(t.fields)
        assert field_map["score"].id == "double"
        assert field_map["ts"].id == "timestamp"

    def test_nested_array_of_map(self):
        t = _parse_type("array(map(varchar, integer))")
        assert t.id == "array"
        assert t.element.id == "map"
        assert t.element.key.id == "varchar"
        assert t.element.value.id == "integer"

    def test_nested_row_containing_array(self):
        t = _parse_type("row(tags array(varchar), score double)")
        field_map = dict(t.fields)
        assert field_map["tags"].id == "array"
        assert field_map["tags"].element.id == "varchar"
        assert field_map["score"].id == "double"

    def test_deeply_nested_row_in_array(self):
        t = _parse_type("array(row(k varchar, v bigint))")
        assert t.id == "array"
        assert t.element.id == "row"
        field_map = dict(t.element.fields)
        assert field_map["k"].id == "varchar"
        assert field_map["v"].id == "bigint"

    def test_raw_field_preserved(self):
        raw = "decimal(10,2)"
        assert _parse_type(raw).raw == raw

    def test_row_with_quoted_field_name(self):
        t = _parse_type('row("my field" bigint, other varchar)')
        field_map = dict(t.fields)
        assert "my field" in field_map
        assert field_map["my field"].id == "bigint"


# ---------------------------------------------------------------------------
# _category
# ---------------------------------------------------------------------------

class TestCategory:
    def test_all_supported_categories(self):
        assert _category(_t("boolean")) == "bool"
        for tid in ("tinyint", "smallint", "integer", "bigint"):
            assert _category(_t(tid)) == "int"
        assert _category(_t("real")) == "float"
        assert _category(_t("double")) == "float"
        assert _category(_t("decimal(10,2)")) == "decimal"
        assert _category(_t("varchar")) == "string"
        assert _category(_t("varchar(50)")) == "string"
        assert _category(_t("date")) == "date"
        assert _category(_t("time")) == "time"
        assert _category(_t("time with time zone")) == "time"
        assert _category(_t("timestamp")) == "timestamp_naive"
        assert _category(_t("timestamp with time zone")) == "timestamp_aware"
        assert _category(_t("array(integer)")) == "array"
        assert _category(_t("map(varchar, bigint)")) == "map"
        assert _category(_t("row(a bigint)")) == "struct"

    def test_unsupported_type_raises_with_guidance(self):
        with pytest.raises(PushdownUnsupportedError, match="ignore_columns"):
            _category(_TrinoType("varbinary", raw="varbinary"))

    def test_json_unsupported(self):
        with pytest.raises(PushdownUnsupportedError):
            _category(_TrinoType("json", raw="json"))


# ---------------------------------------------------------------------------
# _canon_expr
# ---------------------------------------------------------------------------

class TestCanonExpr:
    def _cfg(self, **kw):
        return CompareConfig(**kw)

    def test_null_wrapping_present_on_all_scalar_types(self):
        cfg = self._cfg(float_tolerance=0.01)
        for type_str in ("boolean", "bigint", "varchar", "date", "time", "timestamp"):
            sql = _canon_expr('"x"', _t(type_str), cfg, label="x")
            assert 'CASE WHEN "x" IS NULL THEN chr(1) ELSE' in sql
            assert sql.endswith("END")

    def test_bool_tag_and_if_expr(self):
        sql = _canon_expr('"b"', _t("boolean"), self._cfg(), label="b")
        assert "'b:'" in sql
        assert "IF(" in sql
        assert "'true'" in sql and "'false'" in sql

    def test_int_tag_cast_varchar(self):
        sql = _canon_expr('"n"', _t("bigint"), self._cfg(), label="n")
        assert "'i:'" in sql
        assert 'CAST("n" AS VARCHAR)' in sql

    def test_int_coerced_to_float(self):
        sql = _canon_expr('"n"', _t("bigint"), self._cfg(coerce_numeric_to_float=True, float_tolerance=0.01), label="n")
        assert "'f:'" in sql
        assert "is_nan" in sql

    def test_float_tag_with_tolerance(self):
        sql = _canon_expr('"f"', _t("double"), self._cfg(float_tolerance=0.001), label="f")
        assert "'f:'" in sql
        assert "is_nan" in sql
        assert "is_infinite" in sql
        assert "0.001" in sql

    def test_float_without_tolerance_raises(self):
        with pytest.raises(PushdownUnsupportedError, match="float_tolerance"):
            _canon_expr('"f"', _t("double"), self._cfg(float_tolerance=0.0), label="f")

    def test_float_zero_tolerance_raises(self):
        with pytest.raises(PushdownUnsupportedError):
            _canon_expr('"f"', _t("real"), self._cfg(), label="f")

    def test_decimal_tag_and_scale(self):
        sql = _canon_expr('"d"', _t("decimal(10,2)"), self._cfg(), label="d")
        assert "'n:'" in sql
        assert "DECIMAL(38,2)" in sql

    def test_decimal_widens_to_peer_scale(self):
        this = _t("decimal(10,2)")
        peer = _t("decimal(10,4)")
        sql = _canon_expr('"d"', this, self._cfg(), label="d", peer_type=peer)
        assert "DECIMAL(38,4)" in sql

    def test_decimal_coerce_to_float(self):
        sql = _canon_expr('"d"', _t("decimal(10,2)"),
                          self._cfg(coerce_numeric_to_float=True, float_tolerance=0.01), label="d")
        assert "'f:'" in sql

    def test_string_tag_plain(self):
        sql = _canon_expr('"s"', _t("varchar"), self._cfg(), label="s")
        assert "'t:'" in sql

    def test_string_trim_and_case_insensitive(self):
        sql = _canon_expr('"s"', _t("varchar"),
                          self._cfg(trim_strings=True, case_insensitive=True), label="s")
        assert "TRIM(" in sql
        assert "LOWER(" in sql

    def test_string_trim_only(self):
        sql = _canon_expr('"s"', _t("varchar"), self._cfg(trim_strings=True), label="s")
        assert "TRIM(" in sql
        assert "LOWER(" not in sql

    def test_timestamp_naive_cast_to_varchar(self):
        sql = _canon_expr('"ts"', _t("timestamp"), self._cfg(), label="ts")
        assert "'T:'" in sql
        assert "TIMESTAMP(6)" in sql
        assert "at_timezone" not in sql

    def test_timestamp_aware_uses_at_timezone_utc(self):
        sql = _canon_expr('"ts"', _t("timestamp with time zone"), self._cfg(), label="ts")
        assert "'T:'" in sql
        assert "at_timezone" in sql
        assert "'UTC'" in sql
        assert "TIMESTAMP(6)" in sql

    def test_date_tag(self):
        sql = _canon_expr('"d"', _t("date"), self._cfg(), label="d")
        assert "'D:'" in sql
        assert 'CAST("d" AS VARCHAR)' in sql

    def test_time_tag(self):
        sql = _canon_expr('"t"', _t("time"), self._cfg(), label="t")
        assert "'H:'" in sql

    def test_array_uses_transform_and_array_join(self):
        sql = _canon_expr('"tags"', _t("array(varchar)"), self._cfg(), label="tags")
        assert "'L:'" in sql
        assert "transform(" in sql
        assert "array_join(" in sql
        assert "chr(3)" in sql

    def test_array_unordered_adds_array_sort(self):
        sql = _canon_expr('"tags"', _t("array(varchar)"), self._cfg(), label="tags", unordered=True)
        assert "array_sort(" in sql

    def test_array_ordered_no_sort(self):
        sql = _canon_expr('"tags"', _t("array(varchar)"), self._cfg(), label="tags", unordered=False)
        assert "array_sort(" not in sql

    def test_array_null_replacement_in_join(self):
        # array_join must use the three-argument form so null elements use the null tag
        sql = _canon_expr('"tags"', _t("array(varchar)"), self._cfg(), label="tags")
        assert "chr(1)" in sql  # null replacement arg present

    def test_struct_fields_sorted_alphabetically(self):
        sql = _canon_expr('"row_col"', _t("row(z_col bigint, a_col varchar)"), self._cfg(), label="row_col")
        # a_col must appear before z_col in the generated SQL
        a_pos = sql.index("a_col")
        z_pos = sql.index("z_col")
        assert a_pos < z_pos

    def test_struct_uses_dot_notation_for_fields(self):
        sql = _canon_expr('"row_col"', _t("row(id bigint, name varchar)"), self._cfg(), label="row_col")
        assert '"row_col"."id"' in sql or '"row_col"."name"' in sql

    def test_struct_tag_and_array_join(self):
        sql = _canon_expr('"s"', _t("row(a bigint, b varchar)"), self._cfg(), label="s")
        assert "'S:'" in sql
        assert "array_join(ARRAY[" in sql
        assert "chr(3)" in sql

    def test_map_uses_map_entries_transform_sort(self):
        sql = _canon_expr('"m"', _t("map(varchar, bigint)"), self._cfg(), label="m")
        assert "'M:'" in sql
        assert "map_entries(" in sql
        assert "transform(" in sql
        assert "array_sort(" in sql
        assert "chr(4)" in sql  # key/value separator
        assert "chr(3)" in sql  # entry separator

    def test_nested_array_of_map_recurses(self):
        sql = _canon_expr('"v"', _t("array(map(varchar, integer))"), self._cfg(), label="v")
        # outer array
        assert "'L:'" in sql
        assert "transform(" in sql
        # inner map
        assert "'M:'" in sql
        assert "map_entries(" in sql

    def test_nested_row_in_array_recurses(self):
        sql = _canon_expr('"v"', _t("array(row(k varchar, score double))"),
                          self._cfg(float_tolerance=0.01), label="v")
        assert "'L:'" in sql
        assert "'S:'" in sql
        # struct fields are accessed on the lambda variable
        assert ".\"k\"" in sql or '."score"' in sql


# ---------------------------------------------------------------------------
# _fingerprint_sql and _fingerprint_sql_full
# ---------------------------------------------------------------------------

class TestFingerprintSql:
    def test_keyed_fingerprint_includes_md5_and_key_columns(self):
        types = _types(id="bigint", val="varchar")
        sql = _fingerprint_sql("SELECT * FROM t", ["val"], types, types, ["id"], CompareConfig())
        assert "to_hex(md5(to_utf8(" in sql
        assert '"id"' in sql
        assert "__rp_fp" in sql

    def test_keyed_fingerprint_uses_array_join(self):
        types = _types(id="bigint", val="varchar")
        sql = _fingerprint_sql("SELECT * FROM t", ["val"], types, types, ["id"], CompareConfig())
        assert "array_join(ARRAY[" in sql
        assert "chr(2)" in sql

    def test_full_fingerprint_includes_column_select(self):
        types = _types(id="bigint", val="varchar")
        sql = _fingerprint_sql_full("SELECT * FROM t", ["id", "val"], types, types, CompareConfig())
        assert '"id"' in sql
        assert '"val"' in sql
        assert "__rp_fp" in sql

    def test_empty_columns_produces_empty_string_digest(self):
        types = _types(id="bigint")
        sql = _fingerprint_sql("SELECT * FROM t", [], types, types, ["id"], CompareConfig())
        assert "to_hex(md5(to_utf8(''))" in sql or "to_utf8('')" in sql

    def test_column_names_are_double_quoted(self):
        types = _types(id="bigint", **{"my col": "varchar"})
        sql = _fingerprint_sql("SELECT * FROM t", ["my col"], types, types, ["id"], CompareConfig())
        assert '"my col"' in sql


# ---------------------------------------------------------------------------
# _resolve_columns
# ---------------------------------------------------------------------------

class TestResolveColumns:
    def test_common_columns_compared_sorted(self):
        exp = _types(id="bigint", amt="decimal(10,2)", note="varchar")
        act = _types(id="bigint", amt="decimal(10,2)", note="varchar")
        compared, only_exp, only_act, mismatches = _resolve_columns(exp, act, CompareConfig())
        assert compared == sorted(compared)
        assert only_exp == [] and only_act == [] and mismatches == []

    def test_schema_drift_detected(self):
        exp = _types(id="bigint", old_col="varchar")
        act = _types(id="bigint", new_col="varchar")
        compared, only_exp, only_act, _ = _resolve_columns(exp, act, CompareConfig())
        assert compared == ["id"]
        assert only_exp == ["old_col"]
        assert only_act == ["new_col"]

    def test_type_mismatch_reported(self):
        exp = _types(id="bigint", amt="decimal(10,2)")
        act = _types(id="bigint", amt="double")
        _, _, _, mismatches = _resolve_columns(exp, act, CompareConfig())
        assert len(mismatches) == 1
        name, exp_type, act_type = mismatches[0]
        assert name == "amt"
        assert "decimal" in exp_type
        assert "double" in act_type

    def test_ignore_columns_excluded(self):
        exp = _types(id="bigint", val="varchar", loaded_at="timestamp")
        act = _types(id="bigint", val="varchar", loaded_at="timestamp")
        cfg = CompareConfig(ignore_columns=["loaded_at"])
        compared, _, _, _ = _resolve_columns(exp, act, cfg)
        assert "loaded_at" not in compared

    def test_select_restricts_to_named_columns(self):
        exp = _types(id="bigint", val="varchar", extra="double")
        act = _types(id="bigint", val="varchar", extra="double")
        cfg = CompareConfig(select=["id", "val"])
        compared, _, _, _ = _resolve_columns(exp, act, cfg)
        assert compared == ["id", "val"]


# ---------------------------------------------------------------------------
# resolve_pushdown_sql
# ---------------------------------------------------------------------------

class TestResolvePushdownSql:
    def test_query_passthrough(self):
        spec = {"type": "trino", "query": "SELECT id FROM orders"}
        assert tpd.resolve_pushdown_sql(spec) == "SELECT id FROM orders"

    def test_table_shorthand(self):
        spec = {"type": "trino", "table": "hive.analytics.orders"}
        assert tpd.resolve_pushdown_sql(spec) == "SELECT * FROM hive.analytics.orders"

    def test_rejects_non_trino_source(self):
        with pytest.raises(PushdownUnsupportedError, match="parquet"):
            tpd.resolve_pushdown_sql({"type": "parquet", "path": "x.parquet"})

    def test_rejects_snowflake_source(self):
        with pytest.raises(PushdownUnsupportedError, match="snowflake"):
            tpd.resolve_pushdown_sql({"type": "snowflake", "query": "SELECT 1"})

    def test_missing_query_and_table_raises(self):
        with pytest.raises(PushdownUnsupportedError):
            tpd.resolve_pushdown_sql({"type": "trino"})


# ---------------------------------------------------------------------------
# open_pushdown_connection
# ---------------------------------------------------------------------------

class TestOpenPushdownConnection:
    def test_rejects_different_hosts(self, monkeypatch):
        monkeypatch.delenv("TRINO_HOST", raising=False)
        specs = [
            {"type": "trino", "connection": {"host": "cluster-a.example.com"}, "query": "SELECT 1"},
            {"type": "trino", "connection": {"host": "cluster-b.example.com"}, "query": "SELECT 1"},
        ]
        with pytest.raises(PushdownUnsupportedError, match="different hosts"):
            tpd.open_pushdown_connection(specs)

    def test_same_host_does_not_raise_during_auth_attempt(self, monkeypatch):
        monkeypatch.setenv("TRINO_HOST", "cluster.example.com")
        specs = [
            {"type": "trino", "connection": {"host": "cluster.example.com"}, "query": "SELECT 1"},
            {"type": "trino", "connection": {"host": "cluster.example.com"}, "query": "SELECT 2"},
        ]
        # Will fail at actual connect (missing driver or no real cluster) — we
        # only test that the multi-host guard doesn't fire.
        from rowparity.sources import SourceError
        try:
            tpd.open_pushdown_connection(specs)
        except PushdownUnsupportedError as exc:
            if "different hosts" in str(exc):
                raise
        except (SourceError, Exception):
            pass  # expected: driver not installed or no real cluster


# ---------------------------------------------------------------------------
# Fake connection / orchestration tests
# ---------------------------------------------------------------------------

# Column metadata as 7-tuples matching DBAPI2 cursor.description format
# (name, type_code, display_size, internal_size, precision, scale, null_ok)
def _col(name: str, type_str: str):
    return (name, type_str, None, None, None, None, True)


EXP_COLS = [_col("id", "bigint"), _col("amt", "decimal(10,2)")]
ACT_COLS = [_col("id", "bigint"), _col("amt", "decimal(10,2)")]


class FakeCursor:
    """Simulates a Trino DBAPI cursor driven by a callback.

    The callback receives the SQL string and returns a dict:
      {"description": [...], "rows": [...]}
    Setting "description" on execute() mirrors how Trino (DBAPI2) populates
    cursor.description after execute() even when 0 rows are fetched.
    """

    def __init__(self, handle_fn):
        self._handle_fn = handle_fn
        self._rows = []
        self.description = None

    def execute(self, sql):
        result = self._handle_fn(sql)
        self.description = result.get("description")
        self._rows = result.get("rows", [])
        return self

    def fetchone(self):
        return self._rows[0] if self._rows else None

    def fetchall(self):
        return list(self._rows)


class FakeConnection:
    def __init__(self, handle_fn):
        self._handle_fn = handle_fn

    def cursor(self):
        return FakeCursor(self._handle_fn)


def _make_keyed_handler(*, dup_exp=0, dup_act=0, row_count=100,
                        missing=0, added=0, changed=0, example_keys=None):
    """Build a fake execute handler covering the full keyed-compare SQL sequence."""
    def handler(sql):
        # Schema introspection — LIMIT 0 query
        if "LIMIT 0" in sql:
            cols = EXP_COLS if "raw_expected" in sql else ACT_COLS
            return {"description": cols, "rows": []}
        # _duplicate_count
        if "__rp_cnt - 1" in sql:
            count = dup_exp if "raw_expected" in sql else dup_act
            return {"rows": [(count,)]}
        # _row_count
        if sql.strip().startswith("SELECT COUNT(*) FROM ("):
            return {"rows": [(row_count,)]}
        # _join_counts
        if "COUNT(*) FILTER" in sql and "FULL OUTER JOIN" in sql:
            return {"rows": [(missing, added, changed)]}
        # Example keys fetch
        if "IS DISTINCT FROM" in sql and "LIMIT" in sql:
            keys = example_keys or []
            return {"rows": keys}
        # Example rows fetch (for _compare_example_subset)
        if "WHERE (" in sql or "WHERE" in sql and "__rp_fp" not in sql:
            return {"rows": []}
        raise AssertionError(f"unexpected SQL in fake handler:\n{sql}")
    return handler


def _make_keyless_handler(*, exp_rows=20, act_rows=20, missing=0, added=0):
    """Build a fake execute handler for the keyless-compare SQL sequence."""
    def handler(sql):
        if "LIMIT 0" in sql:
            cols = EXP_COLS if "raw_expected" in sql else ACT_COLS
            return {"description": cols, "rows": []}
        # The single big counts CTE query
        if "(SELECT COUNT(*) FROM e)" in sql:
            return {"rows": [(exp_rows, act_rows, missing, added)]}
        # Mismatched-digest fetch
        if "__rp_fp" in sql and "LIMIT" in sql:
            return {"rows": []}
        raise AssertionError(f"unexpected SQL in fake handler:\n{sql}")
    return handler


class TestTrinoKeyedCompare:
    def test_equivalent_tables(self):
        con = FakeConnection(_make_keyed_handler())
        cfg = CompareConfig(keys=["id"])
        result = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert result.equivalent
        assert result.expected_rows == 100 and result.actual_rows == 100
        assert result.missing_count == 0 and result.added_count == 0 and result.changed_count == 0

    def test_diffs_reported_and_not_equivalent(self):
        con = FakeConnection(_make_keyed_handler(missing=2, added=1, changed=3))
        cfg = CompareConfig(keys=["id"])
        result = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert not result.equivalent
        assert result.missing_count == 2
        assert result.added_count == 1
        assert result.changed_count == 3

    def test_row_counts_populated(self):
        con = FakeConnection(_make_keyed_handler(row_count=500))
        cfg = CompareConfig(keys=["id"])
        result = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert result.expected_rows == 500
        assert result.actual_rows == 500

    def test_duplicate_keys_take_dedup_path(self):
        seen_arbitrary = {"seen": False}

        def handler(sql):
            if "arbitrary" in sql:
                seen_arbitrary["seen"] = True
            return _make_keyed_handler(dup_exp=5)(sql)

        con = FakeConnection(handler)
        cfg = CompareConfig(keys=["id"])
        result = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert result.duplicate_keys_expected == 5
        assert seen_arbitrary["seen"], "dedup path using arbitrary() was not taken"

    def test_no_duplicates_skips_dedup_path(self):
        seen_arbitrary = {"seen": False}

        def handler(sql):
            if "arbitrary" in sql:
                seen_arbitrary["seen"] = True
            return _make_keyed_handler()(sql)

        con = FakeConnection(handler)
        cfg = CompareConfig(keys=["id"])
        tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert not seen_arbitrary["seen"], "dedup path was taken despite no duplicates"

    def test_strict_columns_fails_on_type_mismatch(self):
        # actual side has 'double' for amt — needs float_tolerance so the
        # fingerprint SQL builder doesn't raise on the float column.
        act_cols_mismatched = [_col("id", "bigint"), _col("amt", "double")]

        def handler(sql):
            if "LIMIT 0" in sql:
                cols = EXP_COLS if "raw_expected" in sql else act_cols_mismatched
                return {"description": cols, "rows": []}
            return _make_keyed_handler()(sql)

        con = FakeConnection(handler)
        lenient = CompareConfig(keys=["id"], strict_columns=False, float_tolerance=0.01)
        r = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", lenient)
        assert r.equivalent  # data matches, type mismatch not fatal in lenient mode
        assert r.type_mismatches != []

        strict = CompareConfig(keys=["id"], strict_columns=True, float_tolerance=0.01)
        r2 = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", strict)
        assert not r2.equivalent

    def test_requires_keys(self):
        con = FakeConnection(lambda sql: {"rows": [], "description": []})
        with pytest.raises(PushdownUnsupportedError):
            tpd.trino_keyed_compare(con, "SELECT 1", "SELECT 1", CompareConfig())

    def test_missing_key_column_raises(self):
        def handler(sql):
            if "LIMIT 0" in sql:
                return {"description": [_col("id", "bigint")], "rows": []}
            return {"rows": []}

        con = FakeConnection(handler)
        cfg = CompareConfig(keys=["nonexistent_key"])
        with pytest.raises(ValueError, match="nonexistent_key"):
            tpd.trino_keyed_compare(con, "SELECT * FROM t", "SELECT * FROM t", cfg)

    def test_keys_is_none_on_result(self):
        # result.keys must be the list of key column names, not None
        con = FakeConnection(_make_keyed_handler())
        cfg = CompareConfig(keys=["id"])
        result = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert result.keys == ["id"]

    def test_compared_columns_sorted(self):
        con = FakeConnection(_make_keyed_handler())
        cfg = CompareConfig(keys=["id"])
        result = tpd.trino_keyed_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert result.compared_columns == sorted(result.compared_columns)


class TestTrinoKeylessCompare:
    def test_equivalent_tables(self):
        con = FakeConnection(_make_keyless_handler())
        cfg = CompareConfig()
        result = tpd.trino_keyless_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert result.equivalent
        assert result.keys is None
        assert result.expected_rows == 20 and result.actual_rows == 20

    def test_missing_and_added_reported(self):
        con = FakeConnection(_make_keyless_handler(missing=3, added=1))
        cfg = CompareConfig()
        result = tpd.trino_keyless_compare(con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual", cfg)
        assert not result.equivalent
        assert result.missing_count == 3
        assert result.added_count == 1

    def test_rejects_cfg_with_keys(self):
        con = FakeConnection(lambda sql: {"rows": [], "description": []})
        with pytest.raises(PushdownUnsupportedError):
            tpd.trino_keyless_compare(con, "SELECT 1", "SELECT 1", CompareConfig(keys=["id"]))

    def test_strict_columns_on_schema_drift(self):
        act_drift = [_col("id", "bigint"), _col("new_col", "varchar")]

        def handler(sql):
            if "LIMIT 0" in sql:
                cols = EXP_COLS if "raw_expected" in sql else act_drift
                return {"description": cols, "rows": []}
            if "(SELECT COUNT(*) FROM e)" in sql:
                return {"rows": [(10, 10, 0, 0)]}
            return {"rows": []}

        con = FakeConnection(handler)
        r_strict = tpd.trino_keyless_compare(
            con, "SELECT * FROM raw_expected", "SELECT * FROM raw_actual",
            CompareConfig(strict_columns=True),
        )
        assert not r_strict.equivalent
        assert "amt" in r_strict.columns_only_in_expected or "new_col" in r_strict.columns_only_in_actual


# ---------------------------------------------------------------------------
# trino_auth — resolve_connection_args
# ---------------------------------------------------------------------------

class TestTrinoAuth:
    def test_env_vars_populate_connection_args(self, monkeypatch):
        from rowparity.trino_auth import resolve_connection_args

        monkeypatch.setenv("TRINO_HOST", "trino.example.com")
        monkeypatch.setenv("TRINO_PORT", "8443")
        monkeypatch.setenv("TRINO_USER", "ci_user")
        monkeypatch.setenv("TRINO_CATALOG", "hive")
        monkeypatch.setenv("TRINO_SCHEMA", "analytics")
        monkeypatch.setenv("TRINO_HTTP_SCHEME", "https")

        args = resolve_connection_args({})
        assert args["host"] == "trino.example.com"
        assert args["port"] == 8443
        assert args["user"] == "ci_user"
        assert args["catalog"] == "hive"
        assert args["schema"] == "analytics"
        assert args["http_scheme"] == "https"

    def test_spec_overrides_env_var(self, monkeypatch):
        from rowparity.trino_auth import resolve_connection_args

        monkeypatch.setenv("TRINO_HOST", "env.example.com")
        args = resolve_connection_args({"connection": {"host": "spec.example.com"}})
        assert args["host"] == "spec.example.com"

    def test_port_converted_to_int(self, monkeypatch):
        from rowparity.trino_auth import resolve_connection_args

        monkeypatch.setenv("TRINO_HOST", "h")
        monkeypatch.setenv("TRINO_PORT", "8080")
        args = resolve_connection_args({})
        assert isinstance(args["port"], int)

    def test_missing_host_raises(self, monkeypatch):
        from rowparity.sources import SourceError
        from rowparity.trino_auth import resolve_connection_args

        monkeypatch.delenv("TRINO_HOST", raising=False)
        with pytest.raises(SourceError, match="TRINO_HOST"):
            resolve_connection_args({})

    def test_no_password_field_set(self, monkeypatch):
        """Password must never be passed as a plain connection argument."""
        from rowparity.trino_auth import resolve_connection_args

        monkeypatch.setenv("TRINO_HOST", "h")
        args = resolve_connection_args({})
        assert "password" not in args
