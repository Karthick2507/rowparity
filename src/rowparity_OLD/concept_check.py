"""Concept check: does a table remodel (N old tables collapsed into one wide
table — the star-schema-to-wide-table pattern) still account for every old
business concept, without requiring exact structural schema equality.

Unlike compare.py's strict_columns (exact name-for-name schema equality
between exactly two tables), a remodel legitimately renames/relocates
columns on purpose. "Drift" here means something narrower and more useful:
a business concept that used to live somewhere in the old N tables has no
home anywhere in the new wide table.

For every (source_table, column) across the N old sources:
  1. If a concept_map entry names it explicitly -> look up that target
     column in the wide table.
  2. Otherwise -> fall back to an implicit same-name lookup in the wide
     table (covers the common case: most columns keep their name).
  3. Found (either way) -> covered. Not found -> a LOST concept (drift).

Wide-table columns not reached by any explicit or implicit match are
reported as unaccounted-for, separately, since a new column appearing is a
different (and usually much less alarming) situation than one disappearing:
warn-only by default, opt into failing via strict_unmapped_target.

Produces a ComparisonResult, the same shape compare.py produces, so
report.py / result_sink.py / history.py / the HTML report all work
unchanged — only how "expected" gets built is new here.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .compare import ComparisonResult
from .schema_introspect import describe_source


class ConceptCheckError(RuntimeError):
    pass


def _resolve_concept_map(concept_map: List[dict]) -> Dict[tuple, str]:
    """{(source_name, column): target_column} from the (optional) declared map."""
    resolved = {}
    for entry in concept_map or []:
        src = entry.get("from") or {}
        source_name, column = src.get("source"), src.get("column")
        target_column = entry.get("to")
        if not source_name or not column or not target_column:
            raise ConceptCheckError(
                f"concept_map entry needs from.source, from.column, and to: {entry!r}"
            )
        resolved[(source_name, column)] = target_column
    return resolved


def run_concept_check(
    sources: Dict[str, dict],
    target: dict,
    concept_map: Optional[List[dict]] = None,
    strict_unmapped_target: bool = False,
    base_dir: str = ".",
) -> ComparisonResult:
    if not sources:
        raise ConceptCheckError("concept_check needs at least one entry under 'sources'")

    explicit_map = _resolve_concept_map(concept_map)
    declared_targets = set(explicit_map)  # for detecting unused map entries, see below

    source_schemas = {name: describe_source(spec, base_dir=base_dir) for name, spec in sources.items()}
    target_schema = describe_source(target, base_dir=base_dir)

    lost_concepts: List[str] = []
    type_mismatches: List[tuple] = []
    covered_target_cols = set()
    total_concepts = 0

    for source_name, schema in source_schemas.items():
        for column, dtype in schema.items():
            total_concepts += 1
            target_column = explicit_map.get((source_name, column), column)
            declared_targets.discard((source_name, column))
            qualified = f"{source_name}.{column}"

            if target_column not in target_schema:
                lost_concepts.append(qualified)
                continue

            covered_target_cols.add(target_column)
            target_type = target_schema[target_column]
            if dtype != target_type:
                type_mismatches.append((f"{qualified} -> {target_column}", dtype, target_type))

    if declared_targets:
        # a concept_map entry that named a (source, column) pair that doesn't
        # actually exist in that source's real schema -- almost always a typo
        # or a stale map after the source itself changed; fail loudly rather
        # than silently ignoring it.
        stale = ", ".join(f"{s}.{c}" for s, c in sorted(declared_targets))
        raise ConceptCheckError(f"concept_map references column(s) not found in their source: {stale}")

    unaccounted = sorted(c for c in target_schema if c not in covered_target_cols)

    equivalent = not lost_concepts and not type_mismatches
    if strict_unmapped_target and unaccounted:
        equivalent = False

    return ComparisonResult(
        equivalent=equivalent,
        keys=None,
        compared_columns=sorted(covered_target_cols),
        expected_rows=total_concepts,
        actual_rows=len(target_schema),
        columns_only_in_expected=sorted(lost_concepts),
        columns_only_in_actual=unaccounted,
        type_mismatches=type_mismatches,
    )


@dataclass
class ConceptCheckCase:
    """Duck-type compatible with cases.Case: .name/.tags/.source_file/.run(...)
    so it drops into discover_cases()/cli.py/runner.py unchanged."""
    name: str
    sources: Dict[str, dict]
    target: dict
    concept_map: List[dict] = field(default_factory=list)
    strict_unmapped_target: bool = False
    description: str = ""
    tags: List[str] = field(default_factory=list)
    source_file: str = ""

    def run(self, base_dir: Optional[str] = None, sink=None, result_sink=None) -> ComparisonResult:
        base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
        result = run_concept_check(
            self.sources, self.target, self.concept_map, self.strict_unmapped_target, base_dir=base_dir,
        )
        # no raw data sink -- there's no materialized table to write, same as
        # duckdb push-down cases skip it too.
        if result_sink:
            result_sink.write(self.name, self.tags, result)
        return result


def build_concept_check_case(raw: dict, source_file: str) -> ConceptCheckCase:
    cc = raw["concept_check"]
    for required in ("sources", "target"):
        if required not in cc:
            raise ConceptCheckError(f"{source_file}: concept_check is missing required field '{required}'")
    return ConceptCheckCase(
        name=raw["name"],
        sources=cc["sources"],
        target=cc["target"],
        concept_map=cc.get("concept_map", []) or [],
        strict_unmapped_target=cc.get("strict_unmapped_target", False),
        description=raw.get("description", ""),
        tags=raw.get("tags", []) or [],
        source_file=source_file,
    )