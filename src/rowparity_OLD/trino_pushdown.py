"""SQL push-down comparison via Trino (mirrors snowflake_pushdown.py).

Canonicalize and fingerprint both sides entirely inside Trino, so large
tables already living in the warehouse never need to be exported first.
Structured the same way as duckdb_pushdown.py and snowflake_pushdown.py,
function-for-function.

Type coverage:
  Scalars  — bool, int (tinyint/smallint/integer/bigint), float (real/double),
             decimal(p,s), varchar/char, date, time (plain and with time zone),
             timestamp (plain and with time zone). All dispatched statically
             from the LIMIT-0 schema, same approach as duckdb_pushdown.
  Nested   — array (ordered; array_sort for unordered_list_columns), map
             (unordered by key — map_entries()+transform()+array_sort at
             runtime, same rule as DuckDB push-down), row/struct (unordered by
             field name — fields sorted in Python at SQL-build time from the
             parsed ROW type string, same as DuckDB's struct handling). Nesting
             depth is unbounded via straightforward Python recursion.
  Not covered — varbinary, json, geometry, HyperLogLog, IP address, and other
             specialty types. Exclude via ignore_columns/select or use the
             default (non-push-down) engine for those cases.

Key Trino SQL dialect differences from the other push-down modules:
  MD5         : to_hex(md5(to_utf8(expr))) — Trino's md5() returns VARBINARY
  Concat      : array_join(ARRAY[...], sep, null_replacement) — no concat_ws
  Array map   : transform(arr, x -> ...) for element-wise lambdas
  Struct      : expr."field_name" dot-notation for ROW field access
  Map entries : map_entries(m) → array(row(key K, value V)) + transform + sort
  Dedup agg   : arbitrary(x) — Trino's equivalent of DuckDB any_value /
                Snowflake ANY_VALUE
  Timestamps  : CAST(CAST(x AS TIMESTAMP(6)) AS VARCHAR) for consistent μs repr
  Tz convert  : at_timezone(x, 'UTC') then cast to plain TIMESTAMP(6)
  Null-safe   : IS DISTINCT FROM — supported by Trino
  Filter agg  : COUNT(*) FILTER (WHERE ...) — supported by Trino

Source type: only 'trino' — both expected and actual must be reachable from
one Trino connection (host/catalog/schema). Local-file federation like DuckDB's
read_parquet() doesn't exist in Trino; expose files as external tables/views
instead, or export to Parquet and compare via engine: duckdb.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Sequence, Tuple

import pyarrow as pa

from .compare import CompareConfig, ComparisonResult, compare_tables

PUSHDOWN_SOURCE_TYPES = {"trino"}


class PushdownUnsupportedError(RuntimeError):
    pass


# ---------------------------------------------------------------------------
# Trino type representation
# ---------------------------------------------------------------------------

@dataclass
class _TrinoType:
    id: str                                     # e.g. 'bigint', 'decimal', 'array', 'row'
    precision: int = 0
    scale: int = 0
    raw: str = ""                               # original string from cursor.description
    element: Optional["_TrinoType"] = None      # array element type
    key: Optional["_TrinoType"] = None          # map key type
    value: Optional["_TrinoType"] = None        # map value type
    fields: Optional[List[Tuple[str, "_TrinoType"]]] = None  # row field list, sorted by name


def _find_close_paren(s: str, open_idx: int) -> int:
    depth = 0
    for i in range(open_idx, len(s)):
        if s[i] == "(":
            depth += 1
        elif s[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError(f"unmatched '(' in Trino type string: {s!r}")


def _split_top_level_comma(s: str) -> List[str]:
    """Split on commas that are not inside parentheses."""
    parts: List[str] = []
    depth = 0
    cur: List[str] = []
    for ch in s:
        if ch == "(":
            depth += 1
            cur.append(ch)
        elif ch == ")":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if cur:
        parts.append("".join(cur).strip())
    return parts


def _parse_row_fields(inner: str) -> List[Tuple[str, "_TrinoType"]]:
    """Parse the comma-separated ``name type`` pairs inside a ROW(...)."""
    fields = []
    for part in _split_top_level_comma(inner):
        part = part.strip()
        if not part:
            continue
        if part.startswith('"'):
            end_q = part.index('"', 1)
            name = part[1:end_q]
            type_str = part[end_q + 1:].strip()
        else:
            idx = part.index(" ")
            name = part[:idx]
            type_str = part[idx + 1:].strip()
        fields.append((name, _parse_type(type_str)))
    return fields


def _parse_type(s: str) -> "_TrinoType":
    """Parse a Trino type string (from cursor.description) into a _TrinoType."""
    raw = s
    s = s.strip().lower()

    # Types without parentheses (or with 'with time zone' suffix but no parens)
    if "(" not in s:
        simple_map = {
            "boolean": "boolean",
            "tinyint": "tinyint", "smallint": "smallint",
            "integer": "integer", "bigint": "bigint",
            "real": "real", "double": "double",
            "varchar": "varchar", "char": "varchar",
            "varbinary": "varbinary", "json": "json",
            "date": "date",
            "time": "time",
            "time with time zone": "time_tz",
            "timestamp": "timestamp",
            "timestamp with time zone": "timestamp_tz",
        }
        return _TrinoType(simple_map.get(s, s), raw=raw)

    open_idx = s.index("(")
    close_idx = _find_close_paren(s, open_idx)
    name = s[:open_idx].strip()
    inner = s[open_idx + 1:close_idx].strip()
    suffix = s[close_idx + 1:].strip()  # e.g. "with time zone" after timestamp(6)

    if name in ("varchar", "char"):
        return _TrinoType("varchar", raw=raw)
    if name == "decimal":
        parts = _split_top_level_comma(inner)
        p = int(parts[0])
        sc = int(parts[1]) if len(parts) > 1 else 0
        return _TrinoType("decimal", precision=p, scale=sc, raw=raw)
    if name == "time":
        tid = "time_tz" if "with time zone" in suffix else "time"
        return _TrinoType(tid, raw=raw)
    if name == "timestamp":
        tid = "timestamp_tz" if "with time zone" in suffix else "timestamp"
        return _TrinoType(tid, raw=raw)
    if name == "array":
        return _TrinoType("array", element=_parse_type(inner), raw=raw)
    if name == "map":
        parts = _split_top_level_comma(inner)
        return _TrinoType("map", key=_parse_type(parts[0]), value=_parse_type(parts[1]), raw=raw)
    if name == "row":
        return _TrinoType("row", fields=_parse_row_fields(inner), raw=raw)
    return _TrinoType(name, raw=raw)


# ---------------------------------------------------------------------------
# Type categorisation and canonicalization SQL
# ---------------------------------------------------------------------------

_INT_IDS = {"tinyint", "smallint", "integer", "bigint"}
_FLOAT_IDS = {"real", "double"}


def _category(t: _TrinoType) -> str:
    tid = t.id
    if tid == "boolean":
        return "bool"
    if tid in _INT_IDS:
        return "int"
    if tid in _FLOAT_IDS:
        return "float"
    if tid == "decimal":
        return "decimal"
    if tid == "varchar":
        return "string"
    if tid == "date":
        return "date"
    if tid in ("time", "time_tz"):
        return "time"
    if tid == "timestamp":
        return "timestamp_naive"
    if tid == "timestamp_tz":
        return "timestamp_aware"
    if tid == "array":
        return "array"
    if tid == "map":
        return "map"
    if tid == "row":
        return "struct"
    raise PushdownUnsupportedError(
        f"Trino type '{tid}' (raw: '{t.raw}') isn't canonicalized by Trino "
        f"push-down. Exclude it via ignore_columns/select, or drop "
        f"'engine: trino' to use the default Python engine for this case."
    )


def _quote(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def _peer_decimal_scale(peer: Optional[_TrinoType]) -> int:
    if peer is None or peer.id != "decimal":
        return 0
    return peer.scale or 0


def _float_case_expr(expr: str, tol: float, label: str) -> str:
    if not tol or tol <= 0:
        raise PushdownUnsupportedError(
            f"'{label}': Trino push-down requires float_tolerance > 0 for "
            f"float/decimal (or coerce_numeric_to_float) columns — exact "
            f"IEEE-754 compare isn't implemented in the SQL path."
        )
    return (
        "CASE "
        f"WHEN is_nan({expr}) THEN 'nan' "
        f"WHEN is_infinite({expr}) AND {expr} > 0 THEN 'inf' "
        f"WHEN is_infinite({expr}) THEN '-inf' "
        f"ELSE CAST(CAST(ROUND({expr} / {tol}, 0) AS BIGINT) AS VARCHAR) END"
    )


def _canon_expr(
    expr: str,
    t: _TrinoType,
    cfg: CompareConfig,
    *,
    label: str,
    unordered: bool = False,
    depth: int = 0,
    peer_type: Optional[_TrinoType] = None,
) -> str:
    """Recursive: a full CASE WHEN <expr> IS NULL THEN chr(1) ELSE <body> END
    for any supported Trino type. Same tag scheme as every other canonicalizer
    in this codebase (hashing.py, duckdb_pushdown.py, snowflake_pushdown.py):
    b:/i:/f:/n:/t:/T:/D:/H:/L:/S:/M: prefixes, chr(1) null, chr(3)/chr(4) seps.

    ``unordered`` only affects the outermost array column — never threaded
    into recursive calls, matching hashing.py's rule for unordered_list_columns.
    """
    category = _category(t)
    null_tag = "chr(1)"

    if category == "bool":
        body = f"'b:' || IF({expr}, 'true', 'false')"
    elif category == "int" and not cfg.coerce_numeric_to_float:
        body = f"'i:' || CAST({expr} AS VARCHAR)"
    elif category in ("int", "float"):
        body = f"'f:' || {_float_case_expr(f'CAST({expr} AS DOUBLE)', cfg.float_tolerance, label)}"
    elif category == "decimal" and cfg.coerce_numeric_to_float:
        body = f"'f:' || {_float_case_expr(f'CAST({expr} AS DOUBLE)', cfg.float_tolerance, label)}"
    elif category == "decimal":
        # Widen both sides to the larger of their declared scales so trailing
        # zeros don't create false diffs (1.10 == 1.1), same as hashing.py.
        scale = max(t.scale or 0, _peer_decimal_scale(peer_type) or 0)
        body = f"'n:' || CAST(CAST({expr} AS DECIMAL(38,{scale})) AS VARCHAR)"
    elif category == "string":
        e = expr
        if cfg.trim_strings:
            e = f"TRIM({e})"
        if cfg.case_insensitive:
            e = f"LOWER({e})"
        body = f"'t:' || {e}"
    elif category == "timestamp_naive":
        # CAST to TIMESTAMP(6) normalises precision to microseconds, then
        # CAST to VARCHAR gives a deterministic 'YYYY-MM-DD HH:MM:SS.ffffff'.
        body = f"'T:' || CAST(CAST({expr} AS TIMESTAMP(6)) AS VARCHAR)"
    elif category == "timestamp_aware":
        # Shift to UTC wall-clock time, strip timezone, then format as above.
        body = f"'T:' || CAST(CAST(at_timezone({expr}, 'UTC') AS TIMESTAMP(6)) AS VARCHAR)"
    elif category == "date":
        body = f"'D:' || CAST({expr} AS VARCHAR)"
    elif category == "time":
        body = f"'H:' || CAST({expr} AS VARCHAR)"
    elif category == "array":
        child_t = t.element
        peer_child = peer_type.element if peer_type and peer_type.id == "array" else None
        var = f"__rp_l{depth}"
        elem_expr = _canon_expr(
            var, child_t, cfg, label=f"{label}[]", depth=depth + 1, peer_type=peer_child
        )
        transformed = f"transform({expr}, {var} -> {elem_expr})"
        if unordered:
            transformed = f"array_sort({transformed})"
        body = f"'L:' || array_join({transformed}, chr(3), chr(1))"
    elif category == "struct":
        peer_fields = dict(peer_type.fields) if (peer_type and peer_type.id == "row" and peer_type.fields) else {}
        field_types = dict(t.fields or [])
        field_names = sorted(field_types)  # unordered: sort by name at SQL-build time
        parts = [
            _canon_expr(
                f"{expr}.{_quote(fname)}",
                field_types[fname],
                cfg,
                label=f"{label}.{fname}",
                depth=depth + 1,
                peer_type=peer_fields.get(fname),
            )
            for fname in field_names
        ]
        if parts:
            body = "'S:' || array_join(ARRAY[" + ", ".join(parts) + "], chr(3), chr(1))"
        else:
            body = "'S:'"
    elif category == "map":
        key_t, val_t = t.key, t.value
        peer_key = peer_val = None
        if peer_type and peer_type.id == "map":
            peer_key, peer_val = peer_type.key, peer_type.value
        var = f"__rp_m{depth}"
        # map keys are DATA, not schema — can't be presorted in Python; sort at
        # runtime instead (after canonicalization, keys are strings, so
        # array_sort on the canonicalized key||sep||value strings gives a stable
        # ordering that matches hashing.py's "map = unordered, keys sorted"
        # rule — identical to duckdb_pushdown's map handling).
        key_expr = _canon_expr(
            f"{var}.key", key_t, cfg, label=f"{label}{{key}}", depth=depth + 1, peer_type=peer_key
        )
        val_expr = _canon_expr(
            f"{var}.value", val_t, cfg, label=f"{label}{{value}}", depth=depth + 1, peer_type=peer_val
        )
        entry_expr = f"({key_expr} || chr(4) || {val_expr})"
        sorted_entries = f"array_sort(transform(map_entries({expr}), {var} -> {entry_expr}))"
        body = f"'M:' || array_join({sorted_entries}, chr(3), chr(1))"
    else:  # pragma: no cover — _category() already rejects anything else
        raise PushdownUnsupportedError(f"'{label}': unsupported category '{category}'")

    return f"CASE WHEN {expr} IS NULL THEN {null_tag} ELSE {body} END"


# ---------------------------------------------------------------------------
# Schema introspection
# ---------------------------------------------------------------------------

def _describe_columns(con, sql: str) -> Dict[str, _TrinoType]:
    """Schema-only introspection via LIMIT 0 — Trino optimises away any
    scan, so this is fast regardless of table size."""
    cur = con.cursor()
    cur.execute(f"SELECT * FROM ({sql}) AS __rp_schema_probe LIMIT 0")
    # cursor.description is populated after execute() even with 0 rows.
    return {col[0]: _parse_type(col[1]) for col in (cur.description or [])}


def _resolve_columns(
    exp_types: Dict[str, _TrinoType],
    act_types: Dict[str, _TrinoType],
    cfg: CompareConfig,
):
    exp_cols, act_cols = list(exp_types), list(act_types)
    exp_set, act_set = set(exp_cols), set(act_cols)
    only_exp = [c for c in exp_cols if c not in act_set]
    only_act = [c for c in act_cols if c not in exp_set]
    candidate = cfg.select if cfg.select else [c for c in exp_cols if c in act_set]
    compared = [c for c in candidate if c not in set(cfg.ignore_columns)]
    compared = [c for c in compared if c in exp_set and c in act_set]
    compared = sorted(compared)
    type_mismatches = [
        (c, exp_types[c].raw, act_types[c].raw)
        for c in compared
        if exp_types[c].raw != act_types[c].raw
    ]
    return compared, only_exp, only_act, type_mismatches


# ---------------------------------------------------------------------------
# Fingerprint SQL builders
# ---------------------------------------------------------------------------

def _fingerprint_sql(
    source_sql: str,
    columns: Sequence[str],
    types: Dict[str, _TrinoType],
    peer_types: Dict[str, _TrinoType],
    keys: Sequence[str],
    cfg: CompareConfig,
) -> str:
    fragments = [
        _canon_expr(
            _quote(c), types[c], cfg,
            label=c, unordered=(c in cfg.unordered_list_columns),
            peer_type=peer_types.get(c),
        )
        for c in columns
    ]
    if fragments:
        combined = "array_join(ARRAY[" + ", ".join(fragments) + "], chr(2), chr(1))"
    else:
        combined = "''"
    key_select = ", ".join(_quote(k) for k in keys)
    digest = f"to_hex(md5(to_utf8({combined})))"
    return f"SELECT {key_select}, {digest} AS __rp_fp FROM ({source_sql}) AS __rp_src"


def _fingerprint_sql_full(
    source_sql: str,
    columns: Sequence[str],
    types: Dict[str, _TrinoType],
    peer_types: Dict[str, _TrinoType],
    cfg: CompareConfig,
) -> str:
    """Like _fingerprint_sql but also SELECTs the compared columns alongside
    the digest — keyless mode has no key to re-look-up rows by later."""
    fragments = [
        _canon_expr(
            _quote(c), types[c], cfg,
            label=c, unordered=(c in cfg.unordered_list_columns),
            peer_type=peer_types.get(c),
        )
        for c in columns
    ]
    if fragments:
        combined = "array_join(ARRAY[" + ", ".join(fragments) + "], chr(2), chr(1))"
    else:
        combined = "''"
    col_select = ", ".join(_quote(c) for c in columns)
    digest = f"to_hex(md5(to_utf8({combined})))"
    return f"SELECT {col_select}, {digest} AS __rp_fp FROM ({source_sql}) AS __rp_src"


# ---------------------------------------------------------------------------
# Count helpers
# ---------------------------------------------------------------------------

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
    cur = con.cursor()
    cur.execute(sql)
    return cur.fetchone()[0]


def _row_count(con, source_sql: str) -> int:
    cur = con.cursor()
    cur.execute(f"SELECT COUNT(*) FROM ({source_sql})")
    return cur.fetchone()[0]


def _join_counts(con, exp_source: str, act_source: str, keys: Sequence[str]):
    key_cols = ", ".join(_quote(k) for k in keys)
    sql = f"""
    WITH e AS ({exp_source}), a AS ({act_source})
    SELECT
        COUNT(*) FILTER (WHERE e.__rp_fp IS NOT NULL AND a.__rp_fp IS NULL),
        COUNT(*) FILTER (WHERE a.__rp_fp IS NOT NULL AND e.__rp_fp IS NULL),
        COUNT(*) FILTER (WHERE e.__rp_fp IS NOT NULL AND a.__rp_fp IS NOT NULL
                               AND e.__rp_fp != a.__rp_fp)
    FROM e FULL OUTER JOIN a USING ({key_cols})
    """
    cur = con.cursor()
    cur.execute(sql)
    return cur.fetchone()


def _run_summary_and_examples(
    con,
    expected_sql: str,
    actual_sql: str,
    exp_fp_sql: str,
    act_fp_sql: str,
    keys: Sequence[str],
    max_examples: int,
) -> Tuple[_Counts, List[Tuple]]:
    """Same two-path strategy as duckdb_pushdown: join fingerprints directly
    when keys are already unique (the common case); only pay for the
    dedup-before-join pass when duplicates are actually present."""
    key_cols = ", ".join(_quote(k) for k in keys)

    dup_exp = _duplicate_count(con, expected_sql, keys)
    dup_act = _duplicate_count(con, actual_sql, keys)

    if dup_exp or dup_act:
        # arbitrary() is Trino's equivalent of DuckDB any_value / Snowflake ANY_VALUE
        exp_source = f"SELECT {key_cols}, arbitrary(__rp_fp) AS __rp_fp FROM ({exp_fp_sql}) GROUP BY {key_cols}"
        act_source = f"SELECT {key_cols}, arbitrary(__rp_fp) AS __rp_fp FROM ({act_fp_sql}) GROUP BY {key_cols}"
    else:
        exp_source, act_source = exp_fp_sql, act_fp_sql

    exp_rows = _row_count(con, expected_sql)
    act_rows = _row_count(con, actual_sql)
    missing, added, changed = _join_counts(con, exp_source, act_source, keys)
    counts = _Counts(
        expected_rows=exp_rows, actual_rows=act_rows,
        dup_exp=dup_exp, dup_act=dup_act,
        missing=missing, added=added, changed=changed,
    )

    example_keys: List[Tuple] = []
    if max_examples > 0 and (counts.missing or counts.added or counts.changed):
        examples_sql = f"""
        WITH e AS ({exp_source}), a AS ({act_source})
        SELECT {key_cols}
        FROM e FULL OUTER JOIN a USING ({key_cols})
        WHERE e.__rp_fp IS DISTINCT FROM a.__rp_fp
        LIMIT {int(max_examples)}
        """
        cur = con.cursor()
        cur.execute(examples_sql)
        example_keys = [tuple(row) for row in cur.fetchall()]

    return counts, example_keys


def _fetch_rows(con, sql: str) -> pa.Table:
    cur = con.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    if not rows:
        col_names = [d[0] for d in (cur.description or [])]
        return pa.table({col: [] for col in col_names})
    col_names = [d[0] for d in cur.description]
    return pa.Table.from_pylist([dict(zip(col_names, row)) for row in rows])


def _compare_example_subset(
    con,
    expected_sql: str,
    actual_sql: str,
    compared: Sequence[str],
    cfg: CompareConfig,
    keys: Sequence[str],
    example_keys: List[Tuple],
) -> ComparisonResult:
    """Bounded (<= max_examples) rows — reuse the Python engine for the
    human-readable diff, same approach as both other push-down modules."""
    key_cols = list(keys)
    col_select = ", ".join(_quote(c) for c in sorted(set(compared) | set(key_cols)))
    where = " OR ".join(
        "(" + " AND ".join(
            f"{_quote(k)} = {_sql_literal(v)}" for k, v in zip(key_cols, row)
        ) + ")"
        for row in example_keys
    )
    exp_tbl = _fetch_rows(con, f"SELECT {col_select} FROM ({expected_sql}) WHERE {where}")
    act_tbl = _fetch_rows(con, f"SELECT {col_select} FROM ({actual_sql}) WHERE {where}")
    return compare_tables(exp_tbl, act_tbl, cfg)


def _sql_literal(value) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return repr(value)
    return "'" + str(value).replace("'", "''") + "'"


# ---------------------------------------------------------------------------
# Public compare entry points
# ---------------------------------------------------------------------------

def trino_keyed_compare(
    con, expected_sql: str, actual_sql: str, cfg: CompareConfig
) -> ComparisonResult:
    """Keyed compare_tables() equivalent, computed entirely inside Trino.

    ``con`` is a live Trino DBAPI connection (see open_pushdown_connection);
    ``expected_sql``/``actual_sql`` are SQL queries Trino can execute.
    """
    if not cfg.keys:
        raise PushdownUnsupportedError("Trino push-down requires cfg.keys for keyed compare")

    exp_types = _describe_columns(con, expected_sql)
    act_types = _describe_columns(con, actual_sql)
    for k in cfg.keys:
        if k not in exp_types or k not in act_types:
            raise ValueError(f"key column '{k}' is missing from expected or actual")

    compared, only_exp, only_act, type_mismatches = _resolve_columns(exp_types, act_types, cfg)

    exp_fp_sql = _fingerprint_sql(expected_sql, compared, exp_types, act_types, cfg.keys, cfg)
    act_fp_sql = _fingerprint_sql(actual_sql, compared, act_types, exp_types, cfg.keys, cfg)

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
        result.change_signatures = sub.change_signatures  # approximation: examples only

    if result.total_differences > 0:
        result.equivalent = False
    return result


def trino_keyless_compare(
    con, expected_sql: str, actual_sql: str, cfg: CompareConfig
) -> ComparisonResult:
    """Keyless compare_tables() equivalent (multiset diff), computed in Trino.

    No fast path here — grouping by the full-row digest to count occurrences
    *is* the algorithm, same reasoning as the other push-down modules' keyless
    modes.
    """
    if cfg.keys:
        raise PushdownUnsupportedError("use trino_keyed_compare when cfg.keys is set")

    exp_types = _describe_columns(con, expected_sql)
    act_types = _describe_columns(con, actual_sql)
    compared, only_exp, only_act, type_mismatches = _resolve_columns(exp_types, act_types, cfg)

    exp_fp_sql = _fingerprint_sql_full(expected_sql, compared, exp_types, act_types, cfg)
    act_fp_sql = _fingerprint_sql_full(actual_sql, compared, act_types, exp_types, cfg)

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
    cur = con.cursor()
    cur.execute(counts_sql)
    exp_rows, act_rows, missing, added = cur.fetchone()

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
        cur2 = con.cursor()
        cur2.execute(mismatched_sql)
        digests = [row[0] for row in cur2.fetchall()]
        if digests:
            col_select = ", ".join(_quote(c) for c in compared)
            digest_list = ", ".join(_sql_literal(d) for d in digests)

            def fetch(fp_sql: str) -> pa.Table:
                sql = f"""
                SELECT {col_select}
                FROM (
                    SELECT {col_select},
                           ROW_NUMBER() OVER (PARTITION BY __rp_fp ORDER BY __rp_fp) AS __rp_rn
                    FROM ({fp_sql})
                    WHERE __rp_fp IN ({digest_list})
                )
                WHERE __rp_rn <= 2
                """
                return _fetch_rows(con, sql)

            sub = compare_tables(fetch(exp_fp_sql), fetch(act_fp_sql), cfg)
            result.examples = sub.examples
            result.change_signatures = sub.change_signatures

    if result.total_differences > 0:
        result.equivalent = False
    return result


# ---------------------------------------------------------------------------
# Connection and source resolution
# ---------------------------------------------------------------------------

def resolve_pushdown_sql(spec: Dict[str, Any], base_dir: str = ".") -> str:
    """Turn a 'trino' source spec into a SQL string Trino can execute."""
    kind = spec.get("type")
    if kind != "trino":
        raise PushdownUnsupportedError(
            f"source type '{kind}' isn't supported by Trino push-down (only "
            f"'trino' sources). Both expected and actual must be type: trino. "
            f"To compare files or other sources, export them as Trino external "
            f"tables/views, or use engine: duckdb with local Parquet files instead."
        )
    from .sources import resolve_query
    query = resolve_query(spec, base_dir)
    if not query and spec.get("table"):
        query = f"SELECT * FROM {spec['table']}"
    if not query:
        raise PushdownUnsupportedError("trino source needs a 'query', 'query_file', or 'table'")
    return query


def open_pushdown_connection(specs: Sequence[Dict[str, Any]]):
    """Open one Trino connection reachable by every given source spec.

    Trino doesn't have an ATTACH-equivalent — cross-catalog/cross-schema
    access within one cluster just works via fully-qualified names on one
    connection. Different clusters (hosts) genuinely can't share a connection,
    so that raises rather than guessing.
    """
    from .trino_auth import connect as _trino_connect

    hosts: set = set()
    base_spec = None
    for spec in specs:
        conn = spec.get("connection", {}) or {}
        host = conn.get("host") or os.environ.get("TRINO_HOST")
        if host:
            hosts.add(host)
        if base_spec is None:
            base_spec = spec
    if len(hosts) > 1:
        raise PushdownUnsupportedError(
            f"push-down needs expected/actual reachable from one Trino connection, "
            f"got different hosts: {sorted(hosts)}. Cross-cluster comparison isn't "
            f"supported — export one side and compare via the default engine instead."
        )
    return _trino_connect(base_spec or specs[0])
