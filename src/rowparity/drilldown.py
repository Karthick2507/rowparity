"""Ready-to-run drill-down SQL for a single differing row.

A parity run says *which* aggregate rows disagree. It cannot say *which
underlying transactions* caused it, because the compared query is a GROUP BY
over 83 dimensions and every per-request identifier is collapsed by the
aggregation. That answer lives one query further down, against the raw ``ack``
table, and today an engineer writes it by hand: copy a value out of the report,
paste it into a 40-line WHERE clause, run it on one side, then the other.

This generates those two queries with the row's values already substituted.

**It does not run them.** That is deliberate for the first cut:

* Zero warehouse cost and no new way for a run to fail. Executing two queries
  per differing row turns a report into a query orchestrator, with its own
  timeouts, partial failures and permissions.
* The generated SQL is reviewable. Someone can read it and confirm it is the
  query they would have written, before a single one runs. Executing first and
  showing results would ask them to trust a WHERE clause they never saw.

Running them and diffing the two id sets is the natural next step, and this is
the piece it would be built on.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence

from .params import merge_side_vars
from .sources import resolve_query

# The placeholder the drill-down SQL uses where the row's predicate belongs.
ROW_FILTER = "row_filter"


class DrilldownError(RuntimeError):
    pass


@dataclass
class DrilldownQuery:
    """One side's generated SQL for one differing row."""
    side: str            # the human label: "Hoover" / "Hoover++"
    sql: str


@dataclass
class RowDrilldown:
    kind: str                       # missing | added | changed
    key: str                        # the row's key, for display
    filter_sql: str                 # the predicate that was substituted
    queries: List[DrilldownQuery] = field(default_factory=list)


@dataclass
class DrilldownConfig:
    query_file: str
    bind: List[str]
    max_rows: int = 10

    @classmethod
    def from_yaml(cls, raw: Optional[dict]) -> "Optional[DrilldownConfig]":
        if not raw:
            return None
        known = {"query_file", "bind", "max_rows"}
        unknown = set(raw) - known
        if unknown:
            raise DrilldownError(f"unknown drilldown option(s): {sorted(unknown)}")
        if "query_file" not in raw:
            raise DrilldownError("drilldown needs a 'query_file'")
        bind = raw.get("bind") or []
        if isinstance(bind, str):
            bind = [bind]
        if isinstance(bind, dict):
            # {column: expression} -- the form that matters, because an output
            # alias is rarely the source expression: creative_id is really
            # if(network_is_ad_owner, coalesce(advertisement__creative_id,-1), -1).
            bind = [{"column": k, "expression": v} for k, v in bind.items()]
        else:
            bind = [{"column": c, "expression": c} for c in bind]
        if not bind:
            raise DrilldownError("drilldown needs at least one 'bind' column")
        return cls(query_file=raw["query_file"], bind=bind, max_rows=int(raw.get("max_rows", 10)))


def sql_literal(value: Any) -> str:
    """Render a Python value as a SQL literal.

    Strings are single-quoted with embedded quotes doubled. That is not
    injection defence -- these values came out of the warehouse a moment ago,
    not from a user -- it is so a value containing an apostrophe produces valid
    SQL instead of a syntax error the reader has to debug.
    """
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def build_row_filter(row: dict, bind: Sequence[dict]) -> str:
    """The WHERE fragment pinning this one row.

    ``is null`` rather than ``= null`` when a bound value is absent: ``= null``
    is never true in SQL, so the generated query would silently return nothing
    and look like a clean "not found".
    """
    parts = []
    for item in bind:
        column, expression = item["column"], item["expression"]
        if column not in row:
            raise DrilldownError(
                f"drilldown binds '{column}', which is not a column of the "
                f"compared query. Add it to the SELECT, or bind a column that "
                f"is there."
            )
        value = row[column]
        if value is None:
            parts.append(f"{expression} is null")
        else:
            parts.append(f"{expression} = {sql_literal(value)}")
    return "\n  and ".join(parts)


def generate(
    cfg: DrilldownConfig,
    result,
    sides: Sequence[dict],
    base_dir: str,
    variables: Optional[Dict[str, str]] = None,
) -> List[RowDrilldown]:
    """Render the drill-down SQL for the first ``max_rows`` differing rows.

    ``sides`` is ``[{"label": ..., "spec": ...}, ...]`` -- each side's own
    ``vars:`` supply its catalog and time window, which is why one drill-down
    file serves both. The two sides are deliberately NOT symmetric: the
    migrated side is usually pinned to one hour while the source side is
    searched over a wider window, because which hour a row landed in on the
    other side is exactly what is in question.
    """
    out: List[RowDrilldown] = []
    for diff in result.examples[: cfg.max_rows]:
        row = diff.expected_row if diff.kind != "added" else diff.actual_row
        if not row:
            continue
        filter_sql = build_row_filter(row, cfg.bind)

        queries = []
        for side in sides:
            side_vars = merge_side_vars(side["spec"].get("vars"), variables)
            side_vars[ROW_FILTER] = filter_sql
            spec = dict(side["spec"])
            spec["query_file"] = cfg.query_file
            sql = resolve_query(spec, base_dir, side_vars)
            queries.append(DrilldownQuery(side=side["label"], sql=sql))

        from .report import _fmt_key

        out.append(
            RowDrilldown(
                kind=diff.kind, key=_fmt_key(diff.key), filter_sql=filter_sql, queries=queries
            )
        )
    return out
