"""Two queries that name the transactions behind every differing row.

A parity run says *which* aggregate rows disagree. It cannot say *which
underlying transactions* caused it: the compared query is a GROUP BY over 83
dimensions, so per-request identifiers are collapsed by the aggregation. That
answer lives one query further down, against the raw ``ack`` table.

**Two queries total, not two per row.** Every differing row's ``creative_id``
goes into a single ``IN (...)`` list, so one query per side covers the whole
run::

    if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1) in (
        214174352, 330895668, 331265097, ...
    )

Per-row queries were the obvious first shape and the wrong one. Twenty near
identical 40-line queries are twenty things to copy, twenty results to reconcile
by hand, and twenty scans of the same partition -- when one scan answers all of
them and Presto is far better at a large IN-list than at twenty round trips.

Both queries are then run, and the two sets of ``request__transaction_id`` are
diffed. Ids on one side only are the specific transactions that went missing,
which is what an engineer needs to open a request and look at it.

The values come from **every** differing row, not from the bounded ``examples``
list -- possible because the bound column is part of the key, so its value sits
in the key tuple of every unpaired row. That matters here: at realistic
proportions the examples list fills entirely with ``missing`` rows before an
``added`` or ``changed`` row is ever reached, so drawing from it would silently
cover one third of the problem.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence

from .params import merge_side_vars, substitute
from .sources import resolve_query

# Placeholder the drill-down SQL uses where the generated predicate belongs.
ROW_FILTER = "row_filter"

# A very long IN-list stops being a query and starts being a problem for the
# parser. Well past anything a readable report would show, but bounded.
MAX_VALUES = 1000

# Ids fetched per side. The point is to see which side is missing which
# transactions, not to page a million rows into a report.
MAX_IDS = 500


class DrilldownError(RuntimeError):
    pass


@dataclass
class SideDrilldown:
    """One side's query, and what it returned."""
    label: str
    sql: str
    transaction_ids: List[Any] = field(default_factory=list)
    executed: bool = False
    error: Optional[str] = None
    truncated: bool = False
    seconds: float = 0.0


@dataclass
class DrilldownResult:
    column: str                       # the bound column, e.g. creative_id
    values: List[Any] = field(default_factory=list)
    id_column: str = "request__transaction_id"
    sides: List[SideDrilldown] = field(default_factory=list)
    # True when values came from every differing row rather than the bounded
    # examples list. False means the report is describing a subset.
    complete: bool = True
    rows_covered: int = 0
    only_expected: List[Any] = field(default_factory=list)
    only_actual: List[Any] = field(default_factory=list)
    in_both: int = 0

    @property
    def executed(self) -> bool:
        return any(s.executed for s in self.sides)


@dataclass
class DrilldownConfig:
    query_file: str
    bind: List[Dict[str, str]]
    id_column: str = "request__transaction_id"
    max_values: int = MAX_VALUES
    max_ids: int = MAX_IDS
    # {param, format, hours_before, hours_after} -- how to turn the run's batch
    # parameter into ${batch_hour} and friends.
    time: Optional[Dict[str, Any]] = None
    # {expected: {...}, actual: {...}} -- per-side values for the drill-down
    # SQL's placeholders. Kept here rather than in the sides' own vars: because
    # these may reference the derived time variables, which do not exist until
    # generation time.
    vars: Dict[str, Dict[str, str]] = field(default_factory=dict)
    # Running two extra queries is cheap next to the parity run itself, and the
    # ids are the actual deliverable, so this defaults on. Set false to review
    # the generated SQL without touching the warehouse.
    execute: bool = True

    @classmethod
    def from_yaml(cls, raw: Optional[dict]) -> "Optional[DrilldownConfig]":
        if not raw:
            return None
        known = {"query_file", "bind", "id_column", "max_values", "max_ids",
                 "execute", "time", "vars"}
        unknown = set(raw) - known
        if unknown:
            raise DrilldownError(f"unknown drilldown option(s): {sorted(unknown)}")
        if "query_file" not in raw:
            raise DrilldownError("drilldown needs a 'query_file'")

        bind = raw.get("bind") or []
        if isinstance(bind, str):
            bind = [bind]
        if isinstance(bind, dict):
            # {column: expression}. The form that matters: an output alias is
            # rarely the source expression -- creative_id in the parity output
            # is really if(network_is_ad_owner, coalesce(...), -1), which is
            # what has to appear in a predicate against the raw table.
            bind = [{"column": k, "expression": v} for k, v in bind.items()]
        else:
            bind = [{"column": c, "expression": c} for c in bind]
        if len(bind) != 1:
            # One column, because the predicate is an IN-list over its values.
            # Two columns would need tuple-IN semantics and a very different
            # (and much more expensive) query shape.
            raise DrilldownError(
                f"drilldown binds {len(bind)} column(s); exactly one is supported, "
                f"since the generated predicate is an IN-list over its values"
            )
        return cls(
            query_file=raw["query_file"],
            bind=bind,
            id_column=raw.get("id_column", "request__transaction_id"),
            max_values=int(raw.get("max_values", MAX_VALUES)),
            max_ids=int(raw.get("max_ids", MAX_IDS)),
            execute=bool(raw.get("execute", True)),
            time=raw.get("time"),
            vars=raw.get("vars") or {},
        )

    def time_vars(self, variables: Optional[Dict[str, str]]) -> Dict[str, str]:
        """Derived ${batch_hour} and friends, or nothing if not configured."""
        if not self.time:
            return {}
        param = self.time.get("param")
        if not param:
            raise DrilldownError("drilldown.time needs a 'param' naming the batch parameter")
        value = (variables or {}).get(str(param).lower())
        if value is None:
            raise DrilldownError(
                f"drilldown.time reads '{param}', which this run has no value for. "
                f"Pass --param {param}=<value>."
            )
        return derive_time_vars(
            value,
            fmt=self.time.get("format", BATCH_FORMAT),
            hours_before=int(self.time.get("hours_before", HOURS_BEFORE)),
            hours_after=int(self.time.get("hours_after", HOURS_AFTER)),
        )


# Batch ids in this pipeline are YYYYMMDDHHMMSS: 20260827010000 is the hour
# 2026-08-27 01:00:00. Deriving the window from the run's --param rather than
# hardcoding it is the difference between a drill-down that follows the batch
# under test and one that silently investigates whatever hour someone last
# typed into the case file.
BATCH_FORMAT = "%Y%m%d%H%M%S"

# Matching the window the engineers search by hand: the batch hour itself on
# the migrated side, and one hour before to three after on the source side --
# wide enough to catch a row whose event_date shifted, which is the whole
# question.
HOURS_BEFORE = 1
HOURS_AFTER = 3


def derive_time_vars(
    batch_value: Any,
    fmt: str = BATCH_FORMAT,
    hours_before: int = HOURS_BEFORE,
    hours_after: int = HOURS_AFTER,
) -> Dict[str, str]:
    """Turn a batch id into the timestamps a drill-down window is built from.

    Raises rather than guessing when the id does not parse. A drill-down over
    the wrong window returns rows that look like an answer, and there is
    nothing in the output to say the window was wrong.
    """
    from datetime import datetime, timedelta

    text = str(batch_value).strip()
    try:
        moment = datetime.strptime(text, fmt)
    except ValueError as exc:
        raise DrilldownError(
            f"cannot derive a drill-down time window from batch id {text!r} "
            f"using format {fmt!r}: {exc}. Set drilldown.time.format to match, "
            f"or supply the window explicitly."
        ) from exc

    hour = moment.replace(minute=0, second=0, microsecond=0)
    return {
        "batch_id": text,
        "batch_hour": hour.strftime("%Y-%m-%d %H:%M:%S"),
        "batch_date": hour.strftime("%Y-%m-%d"),
        "batch_hour_start": (hour - timedelta(hours=hours_before)).strftime("%Y-%m-%d %H:%M:%S"),
        "batch_hour_end": (hour + timedelta(hours=hours_after)).strftime("%Y-%m-%d %H:%M:%S"),
    }


def sql_literal(value: Any) -> str:
    """Render a Python value as a SQL literal.

    Quotes are doubled inside strings. Not injection defence -- these values
    came out of the warehouse a moment ago -- but so a value containing an
    apostrophe produces valid SQL rather than a syntax error somewhere the
    reader has to debug.
    """
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def _unwrap(value: Any) -> Any:
    """Canonical key element -> the raw value.

    Key elements are type-tagged tuples: ``('i', 349617594)``. Substituting one
    of those into SQL would produce ``('i', 349617594)`` as a literal.
    """
    if isinstance(value, tuple) and len(value) >= 2 and isinstance(value[0], str):
        return value[1]
    return value


def collect_values(result, column: str, keys: Optional[Sequence[str]], max_values: int):
    """Every distinct value of *column* across the differing rows.

    Returns ``(values, complete, rows_covered)``. When *column* is part of the
    key, values are read from the key tuples of every missing, added and changed
    row, so the list is complete. Otherwise it falls back to the bounded
    ``examples`` list and says so, because that list fills with whichever kind
    of difference the comparison happened to encounter first.
    """
    values, seen = [], set()

    def _add(value):
        if value in seen:
            return
        seen.add(value)
        values.append(value)

    if keys and column in keys:
        position = list(keys).index(column)
        rows = 0
        for group in (result.missing_keys, result.added_keys, result.changed_keys):
            for key in group:
                rows += 1
                _add(_unwrap(key[position]))
        complete = True
    else:
        rows = 0
        for diff in result.examples:
            row = diff.expected_row if diff.kind != "added" else diff.actual_row
            if not row or column not in row:
                continue
            rows += 1
            _add(row[column])
        complete = False

    truncated = len(values) > max_values
    if truncated:
        values = values[:max_values]
    # Sorted so the same run produces the same query text twice, and so a human
    # can scan the list. Mixed types would make sort() raise, hence the guard.
    try:
        values.sort(key=lambda v: (v is None, v))
    except TypeError:
        pass
    return values, complete and not truncated, rows


def build_in_filter(expression: str, values: Sequence[Any]) -> str:
    """An IN-list predicate over *values*.

    Nulls are pulled out into ``is null``: SQL's ``in (null)`` never matches, so
    leaving them in the list would silently drop those rows and the query would
    read as "not found" rather than "not asked for".
    """
    if not values:
        raise DrilldownError("no values to drill down on")
    concrete = [v for v in values if v is not None]
    has_null = len(concrete) != len(values)

    lines = []
    if concrete:
        rendered = ",\n        ".join(sql_literal(v) for v in concrete)
        lines.append(f"{expression} in (\n        {rendered}\n    )")
    if has_null:
        clause = f"{expression} is null"
        lines.append(clause if not concrete else f"or {clause}")
    return "(" + "\n    ".join(lines) + ")" if len(lines) > 1 else lines[0]


def generate(
    cfg: DrilldownConfig,
    result,
    sides: Sequence[dict],
    base_dir: str,
    variables: Optional[Dict[str, str]] = None,
    keys: Optional[Sequence[str]] = None,
) -> DrilldownResult:
    """Render one query per side, covering every differing row at once."""
    column = cfg.bind[0]["column"]
    expression = cfg.bind[0]["expression"]
    values, complete, rows = collect_values(result, column, keys, cfg.max_values)
    if not values:
        raise DrilldownError(
            f"drilldown binds '{column}', which is not a key column and does not "
            f"appear in any example row. Add it to compare.keys, or bind a "
            f"column the compared query selects."
        )

    out = DrilldownResult(
        column=column, values=values, id_column=cfg.id_column,
        complete=complete, rows_covered=rows,
    )
    row_filter = build_in_filter(expression, values)
    # ${batch_hour} and friends, derived from the run's batch parameter rather
    # than typed into the case. This is why the drilldown block is excluded
    # from load-time substitution: these names do not exist until now.
    derived = cfg.time_vars(variables)

    for name, side in zip(("expected", "actual"), sides):
        side_vars = merge_side_vars(side["spec"].get("vars"), variables)
        side_vars.update(derived)
        # The drilldown's own per-side vars, resolved against everything above.
        # Substituted rather than merged raw, so a value may say
        # "... = timestamp '${batch_hour}'" and get the derived hour.
        for key, value in (cfg.vars.get(name) or {}).items():
            side_vars[str(key).lower()] = substitute(
                str(value), side_vars, where=f"drilldown.vars.{name}.{key}"
            )
        side_vars[ROW_FILTER] = row_filter

        spec = dict(side["spec"])
        spec["query_file"] = cfg.query_file
        spec.pop("query", None)
        out.sides.append(
            SideDrilldown(label=side["label"], sql=resolve_query(spec, base_dir, side_vars))
        )
    return out


def execute(
    dd: DrilldownResult,
    cfg: DrilldownConfig,
    sides: Sequence[dict],
    base_dir: str,
) -> None:
    """Run each side's query and collect its transaction ids, then diff them.

    One side failing does not stop the other: a drill-down is an aid to reading
    the result, and half an answer beats none. The failure is recorded against
    that side and shown next to its SQL, rather than raised.
    """
    import time

    from . import progress
    from .sources import load_source

    for side, spec_holder in zip(dd.sides, sides):
        spec = dict(spec_holder["spec"])
        spec.pop("query_file", None)
        spec.pop("vars", None)
        spec["query"] = side.sql
        started = time.time()
        try:
            progress.emit(f"  drill-down: {side.label}")
            table = load_source(spec, base_dir=base_dir)
            if cfg.id_column not in table.column_names:
                raise DrilldownError(
                    f"drill-down query returned no '{cfg.id_column}' column "
                    f"(got: {table.column_names[:8]})"
                )
            ids = table.column(cfg.id_column).to_pylist()
            side.truncated = len(ids) > cfg.max_ids
            side.transaction_ids = ids[: cfg.max_ids]
            side.executed = True
            progress.emit(f"     {len(ids):,} {cfg.id_column} value(s)")
        except Exception as exc:
            side.error = f"{type(exc).__name__}: {exc}"
            progress.emit(f"     failed: {side.error}")
        side.seconds = time.time() - started

    _diff_ids(dd)


def _diff_ids(dd: DrilldownResult) -> None:
    """Which transactions each side has that the other does not.

    Only computed when BOTH sides ran. With one side missing there is nothing
    to subtract, and rendering the other side's ids as "only in X" would be a
    fabrication -- they might be on both.
    """
    if len(dd.sides) != 2 or not all(s.executed for s in dd.sides):
        return
    expected_ids = set(dd.sides[0].transaction_ids)
    actual_ids = set(dd.sides[1].transaction_ids)
    dd.only_expected = sorted(expected_ids - actual_ids, key=repr)
    dd.only_actual = sorted(actual_ids - expected_ids, key=repr)
    dd.in_both = len(expected_ids & actual_ids)
