"""Canonical, type-aware fingerprinting of table rows.

The whole framework rests on one idea: reduce every row to a *canonical form*
whose equality matches "these two rows mean the same thing", then hash it. Two
tables are equivalent when their multisets of row hashes match — which makes the
comparison order-independent for free.

Canonicalisation rules (the important part):

* Row order across the table never matters (we compare multisets of hashes).
* Column order never matters (we sort columns by name before hashing).
* ``list`` / ``array`` columns are ORDERED  -> compared as sequences.
* ``struct`` and ``map`` columns are UNORDERED -> keys sorted before hashing.
* ``float`` values are quantised to a tolerance grid so 1.0000000001 == 1.0.
* ``decimal`` values are compared exactly (trailing zeros stripped).
* ``timestamp`` values are normalised to UTC so tz-aware == the same instant.
* ``null`` is a distinct value, never equal to anything else (incl. "").
* Types are read from the Arrow schema, so a ``map`` and a ``list<struct>`` that
  happen to look alike in Python are never confused.

Everything is driven off the Arrow *type*, not the Python object, which is what
makes it robust across engines (Snowflake vs Spark vs DuckDB return the same
logical value with different physical widths — int32 vs int64, string vs
large_string — and they canonicalise identically here).
"""
from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass
from datetime import date, datetime, time
from decimal import Decimal
from typing import Any, Dict, List, Optional, Sequence

import numpy as np
import pyarrow as pa
import pyarrow.compute as pc

# A leaf sentinel for SQL NULL. Tagged so it can never collide with a real value.
_NULL = ("n",)


@dataclass(frozen=True)
class CanonConfig:
    """Knobs that change what "equal" means. Defaults are strict."""

    float_tolerance: float = 0.0
    # Treat int / decimal / float as one numeric domain (recommended across engines,
    # e.g. Snowflake NUMBER(38,0) vs Spark bigint vs a Python int literal).
    coerce_numeric_to_float: bool = False
    # String handling.
    trim_strings: bool = False
    case_insensitive: bool = False
    # Array columns whose element order should be ignored (compared as a multiset).
    # Everything not listed keeps ordered-list semantics.
    unordered_list_columns: frozenset = frozenset()


def _canon_float(value: float, tol: float) -> tuple:
    if math.isnan(value):
        return ("f", "nan")
    if math.isinf(value):
        return ("f", "inf" if value > 0 else "-inf")
    if tol and tol > 0:
        # Quantise onto a grid of width `tol` so values within tol collide.
        return ("f", int(round(value / tol)))
    # Exact: use the IEEE-754 hex form so no precision is lost.
    return ("f", float(value).hex())


def _canon_scalar(value: Any, cfg: CanonConfig) -> tuple:
    """Canonicalise a Python scalar (used when Arrow type detail is unavailable)."""
    if value is None:
        return _NULL
    if isinstance(value, bool):
        return ("b", value)
    if isinstance(value, int):
        if cfg.coerce_numeric_to_float:
            return _canon_float(float(value), cfg.float_tolerance)
        return ("i", value)
    if isinstance(value, float):
        return _canon_float(value, cfg.float_tolerance)
    if isinstance(value, Decimal):
        if cfg.coerce_numeric_to_float:
            return _canon_float(float(value), cfg.float_tolerance)
        # Exact compare, trailing zeros stripped: 1.10 == 1.1, 100 == 100.0
        return ("d", format(value.normalize(), "f"))
    if isinstance(value, str):
        s = value
        if cfg.trim_strings:
            s = s.strip()
        if cfg.case_insensitive:
            s = s.casefold()
        return ("t", s)
    if isinstance(value, bytes):
        return ("x", value.hex())
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            return ("T", value.astimezone(tz=_UTC).isoformat(), True)
        return ("T", value.isoformat(), False)
    if isinstance(value, date):
        return ("D", value.isoformat())
    if isinstance(value, time):
        return ("H", value.isoformat())
    # Fallback: stringify unknown scalar types deterministically.
    return ("o", repr(value))


try:
    from datetime import timezone as _tz

    _UTC = _tz.utc
except Exception:  # pragma: no cover
    _UTC = None


def canon_value(dtype: pa.DataType, value: Any, cfg: CanonConfig, *, unordered_list: bool = False) -> tuple:
    """Canonicalise one value, using its Arrow ``dtype`` to disambiguate containers."""
    if value is None:
        return _NULL

    if pa.types.is_list(dtype) or pa.types.is_large_list(dtype) or pa.types.is_fixed_size_list(dtype):
        vt = dtype.value_type
        elems = [canon_value(vt, e, cfg) for e in value]
        if unordered_list:
            # Multiset semantics: sort the canonicalised elements.
            return ("Lu", tuple(sorted(elems, key=repr)))
        return ("L", tuple(elems))

    if pa.types.is_struct(dtype):
        # value is a dict {field_name: value}. Structs are unordered by field name.
        fields = sorted(dtype, key=lambda f: f.name)
        return (
            "S",
            tuple((f.name, canon_value(f.type, value.get(f.name), cfg)) for f in fields),
        )

    if pa.types.is_map(dtype):
        kt = dtype.key_type
        vt = dtype.item_type
        pairs = _map_pairs(value)
        canon_pairs = tuple(
            sorted(
                ((canon_value(kt, k, cfg), canon_value(vt, v, cfg)) for k, v in pairs),
                key=repr,
            )
        )
        return ("M", canon_pairs)

    if pa.types.is_floating(dtype):
        return _canon_float(float(value), cfg.float_tolerance)

    if pa.types.is_decimal(dtype):
        return _canon_scalar(Decimal(value) if not isinstance(value, Decimal) else value, cfg)

    if pa.types.is_integer(dtype):
        if cfg.coerce_numeric_to_float:
            return _canon_float(float(value), cfg.float_tolerance)
        return ("i", int(value))

    # Dates / times / timestamps / strings / bytes / bool fall through to scalar.
    return _canon_scalar(value, cfg)


def _map_pairs(value: Any) -> Sequence:
    """Arrow maps arrive as a list of (key, value) tuples or a dict, depending on version."""
    if isinstance(value, dict):
        return list(value.items())
    return list(value)


def canon_row(schema: pa.Schema, row: dict, columns: Sequence[str], cfg: CanonConfig) -> tuple:
    """Canonical tuple for a whole row over ``columns`` (already sorted by caller)."""
    out = []
    for name in columns:
        field = schema.field(name)
        unordered = name in cfg.unordered_list_columns
        out.append((name, canon_value(field.type, row.get(name), cfg, unordered_list=unordered)))
    return tuple(out)


def _canon_float_array(np_arr: "np.ndarray", tol: float) -> List[tuple]:
    """Vectorized equivalent of calling _canon_float() on every element."""
    nan_mask = np.isnan(np_arr)
    pos_inf_mask = np.isposinf(np_arr)
    neg_inf_mask = np.isneginf(np_arr)
    normal_mask = ~(nan_mask | pos_inf_mask | neg_inf_mask)

    if tol and tol > 0:
        quantized = np.zeros(np_arr.shape, dtype=np.int64)
        quantized[normal_mask] = np.round(np_arr[normal_mask] / tol).astype(np.int64)
        normal_vals: Any = quantized
    else:
        normal_vals = None  # computed lazily per-element below (no vectorized IEEE hex)

    out: List[tuple] = [None] * len(np_arr)
    for i in range(len(np_arr)):
        if nan_mask[i]:
            out[i] = ("f", "nan")
        elif pos_inf_mask[i]:
            out[i] = ("f", "inf")
        elif neg_inf_mask[i]:
            out[i] = ("f", "-inf")
        elif normal_vals is not None:
            out[i] = ("f", int(normal_vals[i]))
        else:
            out[i] = ("f", float(np_arr[i]).hex())
    return out


def _vectorized_canon_column(dtype: pa.DataType, arr, cfg: CanonConfig) -> Optional[List[tuple]]:
    """Canonicalize a whole column in one pass (numpy / Arrow compute) instead of
    dispatching per cell. Returns None when the dtype/config combination isn't
    covered here — the caller then falls back to per-cell canon_value(), exactly
    like columnar formats fall back to a generic encoding for types their
    specialized codecs don't handle.

    Only handles NULL-free columns: a null forces the per-cell fallback for that
    whole column, keeping the null-sentinel logic in one place (canon_value).
    """
    if arr.null_count:
        return None

    if pa.types.is_boolean(dtype):
        return [("b", v) for v in arr.to_pylist()]

    if pa.types.is_integer(dtype):
        if cfg.coerce_numeric_to_float:
            np_arr = arr.to_numpy(zero_copy_only=False).astype(np.float64)
            return _canon_float_array(np_arr, cfg.float_tolerance)
        return [("i", int(v)) for v in arr.to_numpy(zero_copy_only=False)]

    if pa.types.is_floating(dtype):
        np_arr = arr.to_numpy(zero_copy_only=False).astype(np.float64)
        return _canon_float_array(np_arr, cfg.float_tolerance)

    if (pa.types.is_string(dtype) or pa.types.is_large_string(dtype)) and not cfg.case_insensitive:
        # case_insensitive uses Python's .casefold(), which Arrow's utf8_lower
        # doesn't exactly replicate on some Unicode edge cases -> fall back.
        if cfg.trim_strings:
            arr = pc.utf8_trim_whitespace(arr)
        return [("t", v) for v in arr.to_pylist()]

    if pa.types.is_timestamp(dtype):
        if dtype.tz is not None:
            utc = arr.cast(pa.timestamp(dtype.unit, tz="UTC"))
            return [("T", v.isoformat(), True) for v in utc.to_pylist()]
        return [("T", v.isoformat(), False) for v in arr.to_pylist()]

    return None


def canon_columns_vectorized(
    schema: pa.Schema, table: pa.Table, columns: Sequence[str], cfg: CanonConfig
) -> Dict[str, List[tuple]]:
    """Column-at-a-time equivalent of calling canon_value() for every (row, column)
    pair: for each column, canonicalize the whole Arrow array in bulk where the
    dtype allows it (bool/int/float/string/timestamp), otherwise fall back to
    the per-cell path for that column only (decimal, date, time, binary, nulls,
    list/struct/map). Output is identical, cell-for-cell, to what canon_row()
    would produce for the same columns.
    """
    out: Dict[str, List[tuple]] = {}
    for name in columns:
        field = schema.field(name)
        arr = table.column(name)
        vec = _vectorized_canon_column(field.type, arr, cfg)
        if vec is None:
            unordered = name in cfg.unordered_list_columns
            vec = [canon_value(field.type, v, cfg, unordered_list=unordered) for v in arr.to_pylist()]
        out[name] = vec
    return out


def row_digest(canon: tuple) -> bytes:
    """Stable 16-byte fingerprint for a canonical row."""
    return hashlib.blake2b(repr(canon).encode("utf-8"), digest_size=16).digest()
