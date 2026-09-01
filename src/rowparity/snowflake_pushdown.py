"""SQL push-down comparison via native Snowflake (mirrors duckdb_pushdown.py).

Canonicalize and fingerprint both sides entirely *inside Snowflake*, so a
large table already living in a warehouse never has to be exported to
Parquet or pulled into Python first. Structured the same way as
duckdb_pushdown.py, function-for-function, so the two stay easy to compare —
the difference is SQL dialect, not approach.

Scalars (bool/int/decimal/float/string/date/time/timestamp) work the same
way duckdb_pushdown.py does: cursor.describe() gives static, Python-side-
known types, so _category()/_canon_expr() dispatch once at SQL-build time.

Semi-structured types (ARRAY/OBJECT/MAP/VARIANT) are architecturally
different and use a SEPARATE mechanism: a single recursive JavaScript UDF
(_variant_udf_js_body(), created lazily via _ensure_variant_udf() the first
time a case actually needs it -- CREATE FUNCTION IF NOT EXISTS, idempotent).
Two reasons a UDF, not more SQL:
  1. cursor.describe() gives no field/element schema for ARRAY/OBJECT/MAP
     (no ".children" equivalent to DuckDB's structured types) -- a column
     typed ARRAY or OBJECT describes only as "ARRAY"/"OBJECT", nothing about
     what's inside, so canonicalization has to be resolved at query time,
     not SQL-build time.
  2. A pure-SQL runtime-dispatch design (TYPEOF() + TABLE(FLATTEN(...)))
     was tried FIRST and confirmed broken live: Snowflake doesn't support a
     correlated table function like FLATTEN nested inside an arbitrary
     scalar subquery in a SELECT list -- even the simplest possible case (a
     single flat ARRAY column, no nesting at all) failed with "Unsupported
     subquery type cannot be evaluated". A UDF sidesteps this entirely (no
     subqueries, no table functions, just procedural recursion) and handles
     arbitrary nesting depth naturally with FIXED (not exponential)
     generated SQL size per column, since the whole traversal is one
     function call rather than inlined SQL text.
OBJECT and Snowflake's distinct MAP type are canonicalized IDENTICALLY (sort
key/value pairs, same as a JS object either way) since neither exposes
whether it's "really" a fixed-field struct or a dynamic map -- operationally
that's the same algorithm hashing.py uses for both (sort by key,
canonicalize value, join), so nothing is lost by not distinguishing them.

Corollary: float_tolerance > 0 is required as soon as ANY compared column is
semi-structured, even if that column's actual values never contain a nested
float/decimal -- the UDF divides by FLOAT_TOL for any nested numeric value
regardless of what's actually in the data. Same tradeoff as scalar float
columns, just triggered by column *type* here rather than column *content*.

Needs CREATE FUNCTION granted on the current schema -- a new requirement
beyond what scalar-only push-down needs, only paid (the UDF is only
created) when a case actually has a semi-structured column in scope.

Source types: only 'snowflake' -- both expected and actual must be reachable
via fully-qualified names from ONE Snowflake connection (no equivalent of
DuckDB's local-file federation; Snowflake has no read_parquet()-style local
file access).

IMPORTANT: the scalar-path SQL below (CONVERT_TIMEZONE, TO_VARCHAR format
models, the NaN/Infinity comparison idiom, COUNT_IF,
ARRAY_AGG(OBJECT_CONSTRUCT(...))) was written from Snowflake SQL knowledge
and validated against a live warehouse only for scalars so far. The
semi-structured UDF path has ONE specific unverified detail: whether
Snowflake's VARIANT->JS marshalling hands a nested DATE/TIME/TIMESTAMP
value to the UDF as a native JS Date object (handled via `v instanceof
Date`) or as something else -- documented Snowflake behavior for top-level
DATE/TIMESTAMP arguments, unconfirmed for values nested inside a passed-in
VARIANT. Validate a case with nested temporal values before trusting that
specifically.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, replace
from typing import Any, Dict, List, Sequence, Tuple

import pyarrow as pa

from .compare import CompareConfig, ComparisonResult, compare_tables

PUSHDOWN_SOURCE_TYPES = {"snowflake"}


class PushdownUnsupportedError(RuntimeError):
    pass


def _quote(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def _category(meta) -> str:
    from snowflake.connector.constants import FIELD_ID_TO_NAME

    type_name = FIELD_ID_TO_NAME.get(meta.type_code, str(meta.type_code))
    if type_name == "BOOLEAN":
        return "bool"
    if type_name == "FIXED":
        return "decimal" if meta.scale else "int"
    if type_name == "REAL":
        return "float"
    if type_name == "TEXT":
        return "string"
    if type_name == "DATE":
        return "date"
    if type_name == "TIME":
        return "time"
    if type_name == "TIMESTAMP_NTZ" or type_name == "TIMESTAMP":
        return "timestamp_naive"
    if type_name in ("TIMESTAMP_TZ", "TIMESTAMP_LTZ"):
        return "timestamp_aware"
    if type_name in ("ARRAY", "OBJECT", "MAP", "VARIANT"):
        return "semi_structured"
    raise PushdownUnsupportedError(
        f"type {type_name} isn't canonicalized by Snowflake push-down yet ("
        f"GEOGRAPHY/GEOMETRY/VECTOR/BINARY/FILE/INTERVAL_* aren't covered). "
        f"Exclude it via ignore_columns or select, or use the regular "
        f"(non-push-down) engine for this case."
    )


def _float_case_expr(expr: str, tol: float, label: str) -> str:
    if not tol or tol <= 0:
        raise PushdownUnsupportedError(
            f"'{label}': Snowflake push-down requires float_tolerance > 0 for "
            f"float/decimal (or coerce_numeric_to_float) values -- exact IEEE-754 "
            f"compare isn't supported in the SQL path."
        )
    return (
        "CASE "
        f"WHEN {expr} != {expr} THEN 'nan' "
        f"WHEN {expr} = 'inf'::FLOAT THEN 'inf' "
        f"WHEN {expr} = '-inf'::FLOAT THEN '-inf' "
        f"ELSE TO_VARCHAR(CAST(ROUND({expr} / {tol}, 0) AS NUMBER(38,0))) END"
    )


def _peer_decimal_scale(peer_meta) -> int:
    if peer_meta is None:
        return 0
    from snowflake.connector.constants import FIELD_ID_TO_NAME

    if FIELD_ID_TO_NAME.get(peer_meta.type_code) != "FIXED":
        return 0
    return peer_meta.scale or 0


_VARIANT_UDF_NAME = "ROWPARITY_CANON_VARIANT"


def _variant_udf_js_body() -> str:
    """The recursive canonicalizer, run once per semi-structured value
    entirely inside a single JS UDF call -- see the module docstring for why
    this replaced an earlier SQL-only (TYPEOF()/TABLE(FLATTEN(...))) design:
    Snowflake doesn't support a correlated table function like FLATTEN
    nested inside an arbitrary scalar subquery (found live, confirmed with
    the simplest possible case -- a single flat ARRAY column already failed
    with "Unsupported subquery type cannot be evaluated"). A UDF sidesteps
    the limitation entirely (no subqueries, no table functions -- just
    procedural recursion) and handles arbitrary nesting depth naturally,
    with fixed (not exponential) generated SQL size per column, since the
    whole traversal is one function call rather than SQL text.

    Same tag scheme as every other canonicalizer in this codebase
    (hashing.py, duckdb_pushdown.py's _canon_expr): 'b:'/'i:'/'f:'/'t:'/
    'T:'/'D:'/'H:'/'L:'/'S:' prefixes, chr(1) null tag, chr(3)/chr(4)
    separators. UNORDERED only sorts at the top-level call (depth 0),
    matching hashing.py's rule that unordered_list_columns never applies to
    a list nested inside a struct/map/another list.

    Untested against a live warehouse (see module docstring) in one specific
    respect: whether Snowflake's VARIANT->JS marshalling hands a nested
    DATE/TIME/TIMESTAMP value to this function as a native JS Date object
    (handled below via `v instanceof Date`) or as something else entirely --
    documented Snowflake JS UDF behavior for TOP-level DATE/TIMESTAMP
    arguments, unconfirmed for values nested inside a passed-in VARIANT.
    """
    return r"""
var NULL_TAG = '\u0001';
var LIST_SEP = '\u0003';
var KV_SEP = '\u0004';

function canon(v, depth) {
  if (v === null || v === undefined) return NULL_TAG;
  if (depth > 100) return 'x:' + JSON.stringify(v);  // pathological/circular guard, not a real-world limit
  if (Array.isArray(v)) {
    var parts = v.map(function(e) { return canon(e, depth + 1); });
    if (depth === 0 && UNORDERED) { parts = parts.slice().sort(); }
    return 'L:' + parts.join(LIST_SEP);
  }
  if (v instanceof Date) {
    return 'T:' + v.toISOString();
  }
  var t = typeof v;
  if (t === 'boolean') return 'b:' + (v ? 'true' : 'false');
  if (t === 'number') {
    if (!isFinite(v)) return 'f:' + (isNaN(v) ? 'nan' : (v > 0 ? 'inf' : '-inf'));
    if (!COERCE_FLOAT && Number.isInteger(v)) return 'i:' + v.toString();
    return 'f:' + Math.round(v / FLOAT_TOL).toString();
  }
  if (t === 'string') {
    var s = v;
    if (TRIM_STRINGS) s = s.trim();
    if (CASE_INSENSITIVE) s = s.toLowerCase();
    return 't:' + s;
  }
  if (t === 'object') {
    var keys = Object.keys(v).sort();
    var parts = keys.map(function(k) { return k + KV_SEP + canon(v[k], depth + 1); });
    return 'S:' + parts.join(LIST_SEP);
  }
  return 'x:' + String(v);
}
return canon(V, 0);
""".strip()


def _variant_udf_create_sql(fqn: str) -> str:
    body = _variant_udf_js_body()
    return f"""
CREATE FUNCTION IF NOT EXISTS {fqn}(
    V VARIANT, FLOAT_TOL FLOAT, COERCE_FLOAT BOOLEAN, TRIM_STRINGS BOOLEAN, CASE_INSENSITIVE BOOLEAN, UNORDERED BOOLEAN
)
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
{body}
$$
"""


def _ensure_variant_udf(con) -> str:
    """Idempotent: CREATE FUNCTION IF NOT EXISTS, so repeated calls (one per
    case run) don't re-create it, and concurrent runs don't fight over it.
    Needs CREATE FUNCTION granted on the current schema -- a new requirement
    beyond what scalar-only push-down needs, only paid when a case actually
    has a semi-structured column in scope (see the call site)."""
    cur = con.cursor()
    db, schema = cur.execute("SELECT CURRENT_DATABASE(), CURRENT_SCHEMA()").fetchone()
    fqn = f"{db}.{schema}.{_VARIANT_UDF_NAME}"
    cur.execute(_variant_udf_create_sql(fqn))
    return fqn


def _canon_expr(
    expr: str,
    meta,
    cfg: CompareConfig,
    *,
    label: str,
    peer_meta=None,
    unordered: bool = False,
    variant_udf_fqn: str = None,
) -> str:
    """A full ``CASE WHEN <expr> IS NULL THEN <null tag> ELSE <canonicalized
    body> END`` for any supported type -- same tag scheme as duckdb_pushdown's
    _canon_expr, so the equivalence classes match (digests are ephemeral,
    never compared cross-engine, only the "same vs different" grouping has
    to match hashing.py's rules)."""
    category = _category(meta)
    null_tag = "chr(1)"

    if category == "semi_structured":
        # The UDF handles SQL NULL itself (arrives as JS null) and already
        # returns the fully-tagged canonical string -- no outer CASE/null-tag
        # wrapper needed here, unlike every other category below. Same
        # float_tolerance > 0 requirement as scalars -- the UDF divides by
        # FLOAT_TOL for any nested float/decimal, so a silently-passed 0
        # would produce Infinity/NaN results instead of failing clearly.
        if not cfg.float_tolerance or cfg.float_tolerance <= 0:
            raise PushdownUnsupportedError(
                f"'{label}': Snowflake push-down requires float_tolerance > 0 as soon as "
                f"any compared column is semi-structured (ARRAY/OBJECT/MAP/VARIANT), even "
                f"if its actual values never contain a nested float/decimal -- the "
                f"canonicalizer defensively covers that case regardless of column type."
            )
        tol = repr(cfg.float_tolerance)
        coerce = "TRUE" if cfg.coerce_numeric_to_float else "FALSE"
        trim = "TRUE" if cfg.trim_strings else "FALSE"
        ci = "TRUE" if cfg.case_insensitive else "FALSE"
        unord = "TRUE" if unordered else "FALSE"
        return f"{variant_udf_fqn}({expr}, {tol}, {coerce}, {trim}, {ci}, {unord})"
    if category == "bool":
        body = f"'b:' || CASE WHEN {expr} THEN 'true' ELSE 'false' END"
    elif category == "int" and not cfg.coerce_numeric_to_float:
        body = f"'i:' || TO_VARCHAR({expr})"
    elif category in ("int", "float"):
        body = f"'f:' || {_float_case_expr(f'CAST({expr} AS FLOAT)', cfg.float_tolerance, label)}"
    elif category == "decimal" and cfg.coerce_numeric_to_float:
        body = f"'f:' || {_float_case_expr(f'CAST({expr} AS FLOAT)', cfg.float_tolerance, label)}"
    elif category == "decimal":
        scale = max(meta.scale or 0, _peer_decimal_scale(peer_meta))
        body = f"'n:' || TO_VARCHAR(CAST({expr} AS NUMBER(38,{scale})))"
    elif category == "string":
        e = expr
        if cfg.trim_strings:
            e = f"TRIM({e})"
        if cfg.case_insensitive:
            e = f"LOWER({e})"
        body = f"'t:' || {e}"
    elif category == "timestamp_naive":
        body = f"'T:' || TO_VARCHAR({expr}, 'YYYY-MM-DD\"T\"HH24:MI:SS.FF6')"
    elif category == "timestamp_aware":
        body = (
            f"'T:' || TO_VARCHAR(CONVERT_TIMEZONE('UTC', {expr}), 'YYYY-MM-DD\"T\"HH24:MI:SS.FF6')"
        )
    elif category == "date":
        body = f"'D:' || TO_VARCHAR({expr}, 'YYYY-MM-DD')"
    elif category == "time":
        body = f"'H:' || TO_VARCHAR({expr})"
    else:  # pragma: no cover -- _category() already rejects anything else
        raise PushdownUnsupportedError(f"'{label}': unsupported category '{category}'")

    return f"CASE WHEN {expr} IS NULL THEN {null_tag} ELSE {body} END"


def _describe_columns(con, sql: str) -> Dict[str, Any]:
    cur = con.cursor()
    metadata = cur.describe(sql)
    return {m.name: m for m in metadata}


def _resolve_cfg_column_casing(
    cfg: CompareConfig, exp_types: Dict[str, Any], act_types: Dict[str, Any]
) -> CompareConfig:
    """Snowflake uppercases unquoted identifiers by default (CREATE TABLE t
    (id ...) actually creates a column named ID), but a YAML case's keys/
    select/ignore_columns/unordered_list_columns are written in whatever
    case the author used and were never quoted. Resolve each one to its
    real column name (case-insensitively, matching what an unquoted SQL
    reference to that name would resolve to in Snowflake itself) before it
    reaches any dict lookup or _quote() call downstream -- both currently
    depend on exact-string matches against cursor.describe()'s real casing.
    Not needed by duckdb_pushdown.py: DuckDB preserves whatever case a
    column was declared with, it doesn't re-case unquoted identifiers."""
    exp_map = {name.upper(): name for name in exp_types}
    act_map = {name.upper(): name for name in act_types}

    def resolve_list(names):
        if not names:
            return names
        resolved = []
        for n in names:
            real = exp_map.get(n.upper()) or act_map.get(n.upper())
            if real is None:
                available = sorted(set(exp_types) | set(act_types))
                raise ValueError(
                    f"column '{n}' not found in expected or actual (available: {available})"
                )
            resolved.append(real)
        return resolved

    return replace(
        cfg,
        keys=resolve_list(cfg.keys),
        select=resolve_list(cfg.select),
        ignore_columns=resolve_list(cfg.ignore_columns),
        unordered_list_columns=resolve_list(cfg.unordered_list_columns),
    )


def _resolve_columns(exp_types: Dict[str, Any], act_types: Dict[str, Any], cfg: CompareConfig):
    exp_cols, act_cols = list(exp_types), list(act_types)
    exp_set, act_set = set(exp_cols), set(act_cols)
    only_exp = [c for c in exp_cols if c not in act_set]
    only_act = [c for c in act_cols if c not in exp_set]
    candidate = cfg.select if cfg.select else [c for c in exp_cols if c in act_set]
    compared = [c for c in candidate if c not in set(cfg.ignore_columns)]
    compared = [c for c in compared if c in exp_set and c in act_set]
    compared = sorted(compared)

    from snowflake.connector.constants import FIELD_ID_TO_NAME

    def _type_str(m):
        name = FIELD_ID_TO_NAME.get(m.type_code, str(m.type_code))
        if name == "FIXED":
            return f"NUMBER({m.precision},{m.scale})"
        return name

    type_mismatches = [
        (c, _type_str(exp_types[c]), _type_str(act_types[c]))
        for c in compared
        if _type_str(exp_types[c]) != _type_str(act_types[c])
    ]
    return compared, only_exp, only_act, type_mismatches


def _any_semi_structured(columns: Sequence[str], types: Dict[str, Any]) -> bool:
    return any(_category(types[c]) == "semi_structured" for c in columns)


def _fingerprint_sql(
    source_sql: str,
    columns: Sequence[str],
    types: Dict[str, Any],
    peer_types: Dict[str, Any],
    keys: Sequence[str],
    cfg: CompareConfig,
    variant_udf_fqn: str = None,
) -> str:
    fragments = [
        _canon_expr(
            _quote(c),
            types[c],
            cfg,
            label=c,
            peer_meta=peer_types.get(c),
            unordered=(c in cfg.unordered_list_columns),
            variant_udf_fqn=variant_udf_fqn,
        )
        for c in columns
    ]
    combined = (
        f"ARRAY_TO_STRING(ARRAY_CONSTRUCT({', '.join(fragments)}), chr(2))" if fragments else "''"
    )
    key_select = ", ".join(_quote(k) for k in keys)
    return f"SELECT {key_select}, MD5({combined}) AS __rp_fp FROM ({source_sql}) AS __rp_src"


def _fingerprint_sql_full(
    source_sql: str,
    columns: Sequence[str],
    types: Dict[str, Any],
    peer_types: Dict[str, Any],
    cfg: CompareConfig,
    variant_udf_fqn: str = None,
) -> str:
    """Like _fingerprint_sql, but selects the row's own compared columns
    alongside the digest -- keyless mode has no key to re-look-up rows by
    later, so example-row columns travel with the fingerprint query itself."""
    fragments = [
        _canon_expr(
            _quote(c),
            types[c],
            cfg,
            label=c,
            peer_meta=peer_types.get(c),
            unordered=(c in cfg.unordered_list_columns),
            variant_udf_fqn=variant_udf_fqn,
        )
        for c in columns
    ]
    combined = (
        f"ARRAY_TO_STRING(ARRAY_CONSTRUCT({', '.join(fragments)}), chr(2))" if fragments else "''"
    )
    col_select = ", ".join(_quote(c) for c in columns)
    return f"SELECT {col_select}, MD5({combined}) AS __rp_fp FROM ({source_sql}) AS __rp_src"


@dataclass
class _Counts:
    expected_rows: int
    actual_rows: int
    missing: int
    added: int
    changed: int
    dup_exp: int
    dup_act: int


def _duplicate_count(con, source_sql: str, keys: Sequence[str]) -> int:
    key_cols = ", ".join(_quote(k) for k in keys)
    sql = f"""
    SELECT COALESCE(SUM(__rp_cnt - 1), 0)
    FROM (SELECT COUNT(*) AS __rp_cnt FROM ({source_sql}) GROUP BY {key_cols})
    WHERE __rp_cnt > 1
    """
    return con.cursor().execute(sql).fetchone()[0]


def _row_count(con, source_sql: str) -> int:
    return con.cursor().execute(f"SELECT COUNT(*) FROM ({source_sql})").fetchone()[0]


def _join_counts(con, exp_source: str, act_source: str, keys: Sequence[str]):
    # NOTE: exp_source/act_source may be the deduped-by-key view (when
    # duplicates are present) -- counting FROM THIS QUERY is NOT the same as
    # expected_rows/actual_rows, which are always counted off the raw
    # (un-deduped) fingerprint SQL by the caller.
    key_cols = ", ".join(_quote(k) for k in keys)
    sql = f"""
    WITH e AS ({exp_source}), a AS ({act_source})
    SELECT
        COUNT_IF(e.__rp_fp IS NOT NULL AND a.__rp_fp IS NULL),
        COUNT_IF(a.__rp_fp IS NOT NULL AND e.__rp_fp IS NULL),
        COUNT_IF(e.__rp_fp IS NOT NULL AND a.__rp_fp IS NOT NULL AND e.__rp_fp != a.__rp_fp)
    FROM e FULL OUTER JOIN a USING ({key_cols})
    """
    return con.cursor().execute(sql).fetchone()


def _run_summary_and_examples(
    con,
    expected_sql: str,
    actual_sql: str,
    exp_fp_sql: str,
    act_fp_sql: str,
    keys: Sequence[str],
    max_examples: int,
) -> Tuple[_Counts, List[Tuple]]:
    """Same two-path strategy as duckdb_pushdown: join raw per-row
    fingerprints directly when keys are already unique on both sides (the
    common case); only pay for a dedup-before-join pass when duplicate keys
    are actually present."""
    key_cols = ", ".join(_quote(k) for k in keys)

    dup_exp = _duplicate_count(con, expected_sql, keys)
    dup_act = _duplicate_count(con, actual_sql, keys)

    if dup_exp or dup_act:
        exp_source = f"SELECT {key_cols}, ANY_VALUE(__rp_fp) AS __rp_fp FROM ({exp_fp_sql}) GROUP BY {key_cols}"
        act_source = f"SELECT {key_cols}, ANY_VALUE(__rp_fp) AS __rp_fp FROM ({act_fp_sql}) GROUP BY {key_cols}"
    else:
        exp_source, act_source = exp_fp_sql, act_fp_sql

    exp_rows = _row_count(con, expected_sql)
    act_rows = _row_count(con, actual_sql)
    missing, added, changed = _join_counts(con, exp_source, act_source, keys)
    counts = _Counts(
        expected_rows=exp_rows,
        actual_rows=act_rows,
        dup_exp=dup_exp,
        dup_act=dup_act,
        missing=missing,
        added=added,
        changed=changed,
    )

    example_keys: List[Tuple] = []
    if max_examples > 0 and (counts.missing or counts.added or counts.changed):
        key_object = (
            "OBJECT_CONSTRUCT(" + ", ".join(f"{_sql_literal(k)}, {_quote(k)}" for k in keys) + ")"
        )
        examples_sql = f"""
        WITH e AS ({exp_source}), a AS ({act_source})
        SELECT ARRAY_AGG({key_object}) FROM (
            SELECT {key_cols} FROM e FULL OUTER JOIN a USING ({key_cols})
            WHERE e.__rp_fp IS DISTINCT FROM a.__rp_fp
            LIMIT {int(max_examples)}
        )
        """
        (keys_list,) = con.cursor().execute(examples_sql).fetchone()
        parsed = json.loads(keys_list) if isinstance(keys_list, str) else (keys_list or [])
        example_keys = [tuple(d[k] for k in keys) for d in parsed]

    return counts, example_keys


def _compare_example_subset(
    con,
    expected_sql: str,
    actual_sql: str,
    compared: Sequence[str],
    cfg: CompareConfig,
    keys: Sequence[str],
    example_keys: List[Tuple],
) -> ComparisonResult:
    """Bounded (<= max_examples) rows only -- reuse the existing, already-
    tested Python engine for the human-readable diff instead of
    reimplementing it in SQL."""
    key_cols = list(keys)
    col_select = ", ".join(_quote(c) for c in sorted(set(compared) | set(key_cols)))
    where = " OR ".join(
        "(" + " AND ".join(f"{_quote(k)} = {_sql_literal(v)}" for k, v in zip(key_cols, row)) + ")"
        for row in example_keys
    )
    exp_tbl = (
        con.cursor()
        .execute(f"SELECT {col_select} FROM ({expected_sql}) WHERE {where}")
        .fetch_arrow_all()
    )
    act_tbl = (
        con.cursor()
        .execute(f"SELECT {col_select} FROM ({actual_sql}) WHERE {where}")
        .fetch_arrow_all()
    )
    return compare_tables(exp_tbl or pa.table({}), act_tbl or pa.table({}), cfg)


def _sql_literal(value) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return repr(value)
    return "'" + str(value).replace("'", "''") + "'"


def snowflake_keyed_compare(
    con, expected_sql: str, actual_sql: str, cfg: CompareConfig
) -> ComparisonResult:
    """Keyed compare_tables() equivalent, computed inside Snowflake instead
    of Python. ``con`` is a live Snowflake connection (see
    open_pushdown_connection); expected_sql/actual_sql are SQL Snowflake can
    run (fully-qualified table names, queries, ...)."""
    if not cfg.keys:
        raise PushdownUnsupportedError("Snowflake push-down requires cfg.keys for keyed compare")

    exp_types = _describe_columns(con, expected_sql)
    act_types = _describe_columns(con, actual_sql)
    cfg = _resolve_cfg_column_casing(cfg, exp_types, act_types)
    for k in cfg.keys:
        if k not in exp_types or k not in act_types:
            raise ValueError(f"key column '{k}' is missing from expected or actual")

    compared, only_exp, only_act, type_mismatches = _resolve_columns(exp_types, act_types, cfg)

    variant_udf_fqn = None
    if _any_semi_structured(compared, exp_types) or _any_semi_structured(compared, act_types):
        variant_udf_fqn = _ensure_variant_udf(con)

    exp_fp_sql = _fingerprint_sql(
        expected_sql, compared, exp_types, act_types, cfg.keys, cfg, variant_udf_fqn
    )
    act_fp_sql = _fingerprint_sql(
        actual_sql, compared, act_types, exp_types, cfg.keys, cfg, variant_udf_fqn
    )

    counts, example_keys = _run_summary_and_examples(
        con, expected_sql, actual_sql, exp_fp_sql, act_fp_sql, cfg.keys, cfg.max_examples
    )

    result = ComparisonResult(
        equivalent=True,
        keys=list(cfg.keys),
        compared_columns=compared,
        expected_rows=counts.expected_rows,
        actual_rows=counts.actual_rows,
        missing_count=counts.missing,
        added_count=counts.added,
        changed_count=counts.changed,
        columns_only_in_expected=only_exp,
        columns_only_in_actual=only_act,
        type_mismatches=type_mismatches,
        duplicate_keys_expected=counts.dup_exp,
        duplicate_keys_actual=counts.dup_act,
    )
    if cfg.strict_columns and (only_exp or only_act or type_mismatches):
        result.equivalent = False

    if example_keys:
        sub = _compare_example_subset(
            con, expected_sql, actual_sql, compared, cfg, cfg.keys, example_keys
        )
        result.examples = sub.examples
        result.change_signatures = (
            sub.change_signatures
        )  # approximation: examples only, not full table

    if result.total_differences > 0:
        result.equivalent = False
    return result


def snowflake_keyless_compare(
    con, expected_sql: str, actual_sql: str, cfg: CompareConfig
) -> ComparisonResult:
    """Keyless compare_tables() equivalent (multiset diff), computed in
    Snowflake. No fast path here (same reasoning as duckdb_pushdown's
    keyless mode) -- grouping by the full-row digest to count occurrences
    *is* the algorithm, not an edge case."""
    if cfg.keys:
        raise PushdownUnsupportedError("use snowflake_keyed_compare when cfg.keys is set")

    exp_types = _describe_columns(con, expected_sql)
    act_types = _describe_columns(con, actual_sql)
    cfg = _resolve_cfg_column_casing(cfg, exp_types, act_types)
    compared, only_exp, only_act, type_mismatches = _resolve_columns(exp_types, act_types, cfg)

    variant_udf_fqn = None
    if _any_semi_structured(compared, exp_types) or _any_semi_structured(compared, act_types):
        variant_udf_fqn = _ensure_variant_udf(con)

    exp_fp_sql = _fingerprint_sql_full(
        expected_sql, compared, exp_types, act_types, cfg, variant_udf_fqn
    )
    act_fp_sql = _fingerprint_sql_full(
        actual_sql, compared, act_types, exp_types, cfg, variant_udf_fqn
    )

    counts_sql = f"""
    WITH e AS ({exp_fp_sql}), a AS ({act_fp_sql}),
         ec AS (SELECT __rp_fp, COUNT(*) AS __rp_cnt FROM e GROUP BY __rp_fp),
         ac AS (SELECT __rp_fp, COUNT(*) AS __rp_cnt FROM a GROUP BY __rp_fp)
    SELECT
        (SELECT COUNT(*) FROM e),
        (SELECT COUNT(*) FROM a),
        COALESCE(SUM(GREATEST(COALESCE(ec.__rp_cnt, 0) - COALESCE(ac.__rp_cnt, 0), 0)), 0),
        COALESCE(SUM(GREATEST(COALESCE(ac.__rp_cnt, 0) - COALESCE(ec.__rp_cnt, 0), 0)), 0)
    FROM ec FULL OUTER JOIN ac USING (__rp_fp)
    """
    exp_rows, act_rows, missing, added = con.cursor().execute(counts_sql).fetchone()

    result = ComparisonResult(
        equivalent=True,
        keys=None,
        compared_columns=compared,
        expected_rows=exp_rows,
        actual_rows=act_rows,
        missing_count=missing,
        added_count=added,
        columns_only_in_expected=only_exp,
        columns_only_in_actual=only_act,
        type_mismatches=type_mismatches,
    )
    if cfg.strict_columns and (only_exp or only_act or type_mismatches):
        result.equivalent = False

    if cfg.max_examples > 0 and (missing or added):
        mismatched_sql = f"""
        WITH e AS ({exp_fp_sql}), a AS ({act_fp_sql}),
             ec AS (SELECT __rp_fp, COUNT(*) AS __rp_cnt FROM e GROUP BY __rp_fp),
             ac AS (SELECT __rp_fp, COUNT(*) AS __rp_cnt FROM a GROUP BY __rp_fp)
        SELECT __rp_fp
        FROM ec FULL OUTER JOIN ac USING (__rp_fp)
        WHERE COALESCE(ec.__rp_cnt, 0) != COALESCE(ac.__rp_cnt, 0)
        LIMIT {int(cfg.max_examples)}
        """
        digests = [row[0] for row in con.cursor().execute(mismatched_sql).fetchall()]
        if digests:
            col_select = ", ".join(_quote(c) for c in compared)
            digest_list = ", ".join(_sql_literal(d) for d in digests)

            def fetch(fp_sql):
                sql = f"""
                SELECT {col_select} FROM (
                    SELECT {col_select}, ROW_NUMBER() OVER (PARTITION BY __rp_fp ORDER BY __rp_fp) AS __rp_rn
                    FROM ({fp_sql}) WHERE __rp_fp IN ({digest_list})
                ) WHERE __rp_rn <= 2
                """
                tbl = con.cursor().execute(sql).fetch_arrow_all()
                return tbl if tbl is not None else pa.table({})

            sub = compare_tables(fetch(exp_fp_sql), fetch(act_fp_sql), cfg)
            result.examples = sub.examples
            result.change_signatures = sub.change_signatures

    if result.total_differences > 0:
        result.equivalent = False
    return result


def resolve_pushdown_sql(spec: Dict[str, Any], base_dir: str = ".") -> str:
    """Turn a case's source spec into SQL a Snowflake connection can run.

    Only 'snowflake' sources are supported (see PUSHDOWN_SOURCE_TYPES) --
    unlike DuckDB push-down there's no local-file federation to fall back
    on; both sides must already be Snowflake-queryable.
    """
    kind = spec.get("type")
    if kind != "snowflake":
        raise PushdownUnsupportedError(
            f"source type '{kind}' isn't queryable by Snowflake push-down (only "
            f"'snowflake' is supported). Drop 'engine: snowflake' for this case "
            f"to use the regular (non-push-down) engine."
        )
    from .sources import resolve_query

    query = resolve_query(spec, base_dir)
    if not query and spec.get("table"):
        query = f"SELECT * FROM {spec['table']}"
    if not query:
        raise PushdownUnsupportedError("snowflake source needs a 'query', 'query_file', or 'table'")
    return query


def open_pushdown_connection(specs: Sequence[Dict[str, Any]]):
    """Open one Snowflake connection that can see every given source spec.

    Snowflake has no ATTACH-equivalent -- cross-database/cross-schema access
    within one account just works via fully-qualified names on one
    connection. Different accounts genuinely can't share a connection, so
    that raises rather than guessing.
    """
    from .snowflake_auth import connect as _sf_connect

    accounts = set()
    base_spec = None
    for spec in specs:
        conn = spec.get("connection", {}) or {}
        account = conn.get("account") or os.environ.get("SNOWFLAKE_ACCOUNT")
        if account:
            accounts.add(account)
        if base_spec is None and conn:
            base_spec = spec
    if len(accounts) > 1:
        raise PushdownUnsupportedError(
            f"push-down needs expected/actual reachable from one Snowflake connection, "
            f"got different accounts: {sorted(accounts)}. Cross-account comparison isn't "
            f"supported -- export one side and compare via the default engine instead."
        )
    base_spec = base_spec or specs[0]
    return _sf_connect(base_spec)
