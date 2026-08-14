"""Resolving a ``${name}`` from a query instead of a literal.

Some parameters are not knowable when a case is written -- the newest batch
that exists on both sides of a migration, the latest loaded partition. Hard
-coding them means editing YAML before every run; computing them client-side
means guessing at what the warehouse actually holds (and getting it wrong,
quietly, when the guess names a partition that does not exist).

A ``param_queries:`` block names a source whose single scalar result becomes
the variable's value::

    param_queries:
      batch_id:
        type: trino
        query_file: sqls/latest_common_batch.sql

Two rules that matter:

* **A query only runs if the name is not already resolved.** ``--param
  batch_id=...`` or ``ROWPARITY_VAR_BATCH_ID`` short-circuits it entirely, so
  pinning a value costs nothing and never fires a redundant query. Automatic
  resolution is the fallback, not a mandate.
* **An empty or NULL result is an error, never an empty string.** Substituting
  "" would produce a query filtering on a partition that cannot exist, return
  zero rows on both sides, and report EQUIVALENT -- a silent pass, which for a
  verification tool is the worst possible outcome.
"""

from __future__ import annotations

from typing import Any, Dict, Mapping, Optional

from .params import ParamError, substitute_spec


def _scalar(table, name: str) -> str:
    """Pull a single value out of a 1x1 result, or explain why it is not one."""
    if table.num_columns != 1:
        raise ParamError(
            f"param_queries['{name}'] must select exactly one column, got "
            f"{table.num_columns}: {table.schema.names}"
        )
    if table.num_rows == 0:
        raise ParamError(
            f"param_queries['{name}'] returned no rows. It cannot be resolved, and "
            f"substituting an empty value would silently compare nothing. Check the "
            f"query, or pass --param {name}=<value> explicitly."
        )
    if table.num_rows > 1:
        raise ParamError(
            f"param_queries['{name}'] returned {table.num_rows} rows; it must return "
            f"exactly one. Add an aggregate or a LIMIT 1 with an explicit ORDER BY."
        )
    value = table.column(0)[0].as_py()
    if value is None:
        raise ParamError(
            f"param_queries['{name}'] returned NULL. Substituting it would compare "
            f"nothing and report a false pass. Check the query, or pass "
            f"--param {name}=<value> explicitly."
        )
    return str(value)


def resolve_param_queries(
    param_queries: Optional[Mapping[str, Any]],
    resolved: Mapping[str, str],
    base_dir: str = ".",
) -> Dict[str, str]:
    """Run the queries for names ``resolved`` does not already cover.

    Returns only the newly-resolved names, so the caller keeps control of
    precedence.
    """
    from .sources import load_source

    out: Dict[str, str] = {}
    for name, spec in (param_queries or {}).items():
        key = str(name).lower()
        if key in resolved:
            continue  # already pinned; do not pay for a query
        if not isinstance(spec, dict) or "type" not in spec:
            raise ParamError(
                f"param_queries['{name}'] must be a source spec with a 'type' key, "
                f"got: {spec!r}"
            )
        # The query itself may reference already-resolved parameters.
        spec = substitute_spec(spec, resolved, where=f"param_queries['{name}']")
        table = load_source(spec, base_dir=base_dir, variables=dict(resolved))
        out[key] = _scalar(table, name)
    return out
