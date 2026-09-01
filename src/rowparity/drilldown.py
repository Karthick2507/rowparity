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

The queries are **generated, not executed**. Running them was tried and taken
back out: against the real cluster the two scans took long enough to dominate
the parity run they were supposed to annotate, and a drill-down is an aid to
reading a result rather than part of producing one. Paying minutes on every run
for something an engineer reads occasionally is the wrong trade.

So the report hands over two ready-to-run queries with every value already
substituted, and whoever is investigating runs them when they want the answer.
The tedious, error-prone part -- pasting values into a 40-line WHERE by hand --
is what was actually worth automating.

The values come from **every** differing row, not from the bounded ``examples``
list -- possible because the bound column is part of the key, so its value sits
in the key tuple of every unpaired row. That matters here: at realistic
proportions the examples list fills entirely with ``missing`` rows before an
``added`` or ``changed`` row is ever reached, so drawing from it would silently
cover one third of the problem.

**Which differing rows, though.** ``kinds:`` selects that, and defaults to
``[missing]``. Merging all three was the first shape and read badly: with an
83-column key one ``creative_id`` spans many aggregate rows, so a union of
missing + added + changed collapses into a long list that looks like the whole
column and says nothing about why any given id is in it. Missing rows are also
the ones an engineer is chasing -- "this did not arrive" -- while ``added`` is
usually the same row under a shifted ``event_date`` and ``changed`` is metric
drift, a different investigation with a different query.

The kinds left out are still counted and reported, so a narrowed filter is
visible in the output rather than something you have to know about.
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

# The three ways a keyed comparison can disagree. Order is the order they are
# reported in, not a precedence.
KINDS = ("missing", "added", "changed")

# Rows present on the expected side and absent from the actual one -- "this did
# not arrive", which is the question a drill-down is usually opened to answer.
DEFAULT_KINDS = ("missing",)


class DrilldownError(RuntimeError):
    pass


@dataclass
class SideDrilldown:
    """One side's ready-to-run query."""
    label: str
    sql: str


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
    # Which kinds of difference the IN-list was built from.
    kinds: List[str] = field(default_factory=lambda: list(DEFAULT_KINDS))
    # Distinct values each kind contributes, INCLUDING the kinds left out of
    # the filter. A narrowed drill-down should say what it narrowed away --
    # otherwise "no rows found" and "never asked" look identical in the report.
    kind_values: Dict[str, int] = field(default_factory=dict)
    kind_rows: Dict[str, int] = field(default_factory=dict)


@dataclass
class DrilldownConfig:
    query_file: str
    bind: List[Dict[str, str]]
    id_column: str = "request__transaction_id"
    max_values: int = MAX_VALUES
    # Which kinds of differing row contribute values to the IN-list. See the
    # module docstring for why this defaults to missing alone.
    kinds: List[str] = field(default_factory=lambda: list(DEFAULT_KINDS))
    # {param, format, hours_before, hours_after} -- how to turn the run's batch
    # parameter into ${batch_hour} and friends.
    time: Optional[Dict[str, Any]] = None
    # {expected: {...}, actual: {...}} -- per-side values for the drill-down
    # SQL's placeholders. Kept here rather than in the sides' own vars: because
    # these may reference the derived time variables, which do not exist until
    # generation time.
    vars: Dict[str, Dict[str, str]] = field(default_factory=dict)

    @classmethod
    def from_yaml(cls, raw: Optional[dict]) -> "Optional[DrilldownConfig]":
        if not raw:
            return None
        known = {"query_file", "bind", "id_column", "max_values", "kinds", "time", "vars"}
        unknown = set(raw) - known
        if unknown:
            raise DrilldownError(f"unknown drilldown option(s): {sorted(unknown)}")
        if "query_file" not in raw:
            raise DrilldownError("drilldown needs a 'query_file'")

        kinds = raw.get("kinds", list(DEFAULT_KINDS))
        if isinstance(kinds, str):
            kinds = [kinds]
        kinds = [str(k).strip().lower() for k in kinds]
        bad = [k for k in kinds if k not in KINDS]
        if bad:
            raise DrilldownError(
                f"drilldown kinds {bad} are not comparison outcomes; "
                f"expected any of {list(KINDS)}"
            )
        if not kinds:
            raise DrilldownError(
                "drilldown kinds is empty, which would leave the IN-list with "
                "nothing to filter on. Name at least one of " + str(list(KINDS))
            )
        # Deduplicated, in KINDS order, so the report reads the same however
        # the case file happened to list them.
        kinds = [k for k in KINDS if k in kinds]

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
            kinds=kinds,
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


def collect_values_by_kind(result, column: str, keys: Optional[Sequence[str]]):
    """Distinct values of *column*, per kind of difference.

    Returns ``({kind: [values]}, {kind: row_count}, complete)``. When *column*
    is part of the key, values are read from the key tuples of every unpaired
    and changed row, so each kind's list is complete. Otherwise it falls back to
    the bounded ``examples`` list and says so, because that list fills with
    whichever kind of difference the comparison happened to encounter first.

    Kept per kind rather than merged so the caller can filter on one of them and
    still report what the others held.
    """
    per_kind: Dict[str, List[Any]] = {k: [] for k in KINDS}
    per_rows: Dict[str, int] = {k: 0 for k in KINDS}
    seen: Dict[str, set] = {k: set() for k in KINDS}

    def _add(kind: str, value: Any) -> None:
        if value in seen[kind]:
            return
        seen[kind].add(value)
        per_kind[kind].append(value)

    if keys and column in keys:
        position = list(keys).index(column)
        groups = zip(KINDS, (result.missing_keys, result.added_keys, result.changed_keys))
        for kind, group in groups:
            for key in group:
                per_rows[kind] += 1
                _add(kind, _unwrap(key[position]))
        complete = True
    else:
        for diff in result.examples:
            kind = diff.kind if diff.kind in per_kind else "changed"
            row = diff.actual_row if diff.kind == "added" else diff.expected_row
            if not row or column not in row:
                continue
            per_rows[kind] += 1
            _add(kind, row[column])
        complete = False

    return per_kind, per_rows, complete


def _sorted_values(values: Sequence[Any], max_values: int):
    """Deduplicated, ordered, bounded. Returns ``(values, truncated)``."""
    out, seen = [], set()
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        out.append(value)
    truncated = len(out) > max_values
    if truncated:
        out = out[:max_values]
    # Sorted so the same run produces the same query text twice, and so a human
    # can scan the list. Mixed types would make sort() raise, hence the guard.
    try:
        out.sort(key=lambda v: (v is None, v))
    except TypeError:
        pass
    return out, truncated


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
    per_kind, per_rows, complete = collect_values_by_kind(result, column, keys)

    if not any(per_kind.values()):
        raise DrilldownError(
            f"drilldown binds '{column}', which is not a key column and does not "
            f"appear in any example row. Add it to compare.keys, or bind a "
            f"column the compared query selects."
        )

    selected = [v for kind in cfg.kinds for v in per_kind[kind]]
    if not selected:
        # The comparison found differences, just none of the selected kind.
        # Naming what it does hold is the difference between a dead end and a
        # one-word edit to the case file.
        held = ", ".join(f"{k}: {len(per_kind[k])}" for k in KINDS if per_kind[k]) or "none"
        raise DrilldownError(
            f"drilldown kinds {cfg.kinds} matched no differing rows for "
            f"'{column}' ({held}). Widen drilldown.kinds, or drop the block for "
            f"this run."
        )

    values, truncated = _sorted_values(selected, cfg.max_values)
    rows = sum(per_rows[k] for k in cfg.kinds)

    out = DrilldownResult(
        column=column, values=values, id_column=cfg.id_column,
        complete=complete and not truncated, rows_covered=rows,
        kinds=list(cfg.kinds),
        kind_values={k: len(per_kind[k]) for k in KINDS},
        kind_rows=dict(per_rows),
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
