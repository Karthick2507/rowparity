"""Schema-only parity check between two sources.

Unlike a normal case (which compares row data) or a concept_check (which
asks "did every business concept survive a remodel"), a schema_check asks
exactly one question: do two tables / views agree on column names and types?
Zero rows are ever fetched — schema_introspect.py's metadata-only paths are
used throughout, same guarantee as concept_check.

YAML format::

    name: orders_schema_matches_view
    schema_check:
      expected:
        type: duckdb
        table: orders_v1
        database: warehouse.duckdb
      actual:
        type: trino
        table: hive.analytics.orders_v2
      ignore_columns: [loaded_at, _updated_at]  # optional
      # Or from a shared per-table CSV (see exclusions.py); unioned with the
      # inline list above when both are present:
      ignore_columns_file: exclude.csv          # optional, relative to this YAML
      ignore_columns_table: orders              # required with the above

    # Works with any source type schema_introspect.py supports:
    # duckdb / sql / snowflake / spark / iceberg / delta / parquet / arrow / csv / inline

Produces a ComparisonResult — report.py, result_sink.py, history.py, and the
HTML report all work unchanged:
  columns_only_in_expected   columns present in expected but missing from actual
  columns_only_in_actual     columns present in actual but missing from expected
  type_mismatches            columns present on both sides with a different type
  equivalent                 True only when all three lists are empty
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from .compare import ComparisonResult
from .exclusions import ExclusionError, merge_ignore_columns
from .schema_introspect import describe_source

_SCHEMA_CHECK_KEYS = {
    "expected", "actual", "ignore_columns",
    "ignore_columns_file", "ignore_columns_table",
}


class SchemaCheckError(RuntimeError):
    pass


def run_schema_check(
    expected_spec: Dict[str, Any],
    actual_spec: Dict[str, Any],
    ignore_columns: Optional[List[str]] = None,
    base_dir: str = ".",
    variables: Optional[Dict[str, str]] = None,
) -> ComparisonResult:
    exp_schema = describe_source(expected_spec, base_dir=base_dir, variables=variables)
    act_schema = describe_source(actual_spec, base_dir=base_dir, variables=variables)

    skip = set(ignore_columns or [])
    exp_cols = {c: t for c, t in exp_schema.items() if c not in skip}
    act_cols = {c: t for c, t in act_schema.items() if c not in skip}

    exp_set, act_set = set(exp_cols), set(act_cols)
    only_exp = sorted(c for c in exp_cols if c not in act_set)
    only_act = sorted(c for c in act_cols if c not in exp_set)
    type_mismatches = [
        (c, exp_cols[c], act_cols[c])
        for c in sorted(exp_set & act_set)
        if exp_cols[c] != act_cols[c]
    ]

    equivalent = not (only_exp or only_act or type_mismatches)
    return ComparisonResult(
        equivalent=equivalent,
        keys=None,
        compared_columns=sorted(exp_set & act_set),
        expected_rows=0,
        actual_rows=0,
        columns_only_in_expected=only_exp,
        columns_only_in_actual=only_act,
        type_mismatches=type_mismatches,
        kind="schema",
        expected_schema=exp_cols,
        actual_schema=act_cols,
    )


@dataclass
class SchemaCheckCase:
    name: str
    expected: Dict[str, Any]
    actual: Dict[str, Any]
    ignore_columns: List[str] = field(default_factory=list)
    description: str = ""
    tags: List[str] = field(default_factory=list)
    source_file: str = ""
    variables: Dict[str, str] = field(default_factory=dict)
    # Resolved in run(), not at build time, so an explicit base_dir override
    # applies to the exclusion file the same way it applies to query_file.
    ignore_columns_file: Optional[str] = None
    ignore_columns_table: Optional[str] = None

    def run(self, base_dir: Optional[str] = None, sink=None, result_sink=None) -> ComparisonResult:
        base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
        try:
            ignore_columns = merge_ignore_columns(
                self.ignore_columns,
                self.ignore_columns_file,
                self.ignore_columns_table,
                base_dir=base_dir,
            )
        except ExclusionError as exc:
            raise ExclusionError(f"case '{self.name}': {exc}") from exc
        result = run_schema_check(
            self.expected, self.actual,
            ignore_columns=ignore_columns,
            base_dir=base_dir,
            variables=self.variables,
        )
        if result_sink:
            result_sink.write(self.name, self.tags, result)
        return result


def build_schema_check_case(
    raw: dict, source_file: str, variables: Optional[Dict[str, str]] = None
) -> SchemaCheckCase:
    sc = raw["schema_check"]
    for required in ("expected", "actual"):
        if required not in sc:
            raise SchemaCheckError(
                f"{source_file}: schema_check is missing required field '{required}'"
            )
    # A typo'd key here used to be silently ignored, which for an exclusion key
    # means "nothing was excluded" -- the failure mode exclusions.py exists to
    # prevent. Reject unknown keys instead.
    unknown = set(sc) - _SCHEMA_CHECK_KEYS
    if unknown:
        raise SchemaCheckError(
            f"{source_file}: schema_check has unknown field(s) {sorted(unknown)}; "
            f"valid fields are {sorted(_SCHEMA_CHECK_KEYS)}"
        )
    return SchemaCheckCase(
        name=raw["name"],
        expected=sc["expected"],
        actual=sc["actual"],
        ignore_columns=sc.get("ignore_columns", []) or [],
        description=raw.get("description", ""),
        tags=raw.get("tags", []) or [],
        source_file=source_file,
        variables=variables or {},
        ignore_columns_file=sc.get("ignore_columns_file"),
        ignore_columns_table=sc.get("ignore_columns_table"),
    )
