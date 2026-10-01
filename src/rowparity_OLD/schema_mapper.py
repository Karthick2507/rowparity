"""Column coverage mapping: usage columns (Looker, scheduled reports) against a
source table schema.

Given:
  - a list of columns a downstream consumer uses (from a Looker model, a
    scheduled report, a BI tool, etc.)
  - one source table (any type schema_introspect.py supports)
  - an optional schema CSV (column_name, type, description) in the repo

Produces a CoverageResult:
  - mapped       : usage columns that exist in the source table (case-insensitive)
  - unmapped     : usage columns not found in the source table
  - unreferenced : source columns not referenced by any usage column

YAML format::

    name: looker_orders_coverage
    coverage_check:
      usage_columns:               # inline list  (mutually exclusive with usage_file)
        - order_id
        - revenue
        - customer_name
      # OR:
      usage_file: columns/looker_order_fields.txt   # one column per line

      source:                      # any source type schema_introspect supports
        type: snowflake
        table: PROD.ANALYTICS.FACT_ORDERS

      schema_file: schemas/fact_orders.csv   # optional CSV: column_name,type,description
"""
from __future__ import annotations

import csv
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


class CoverageError(RuntimeError):
    pass


@dataclass
class MappedColumn:
    usage_name: str       # name as supplied in the usage list
    source_name: str      # actual column name from the source (original casing)
    source_type: str      # type string from schema_introspect / schema_file
    description: str = "" # from schema_file if provided


@dataclass
class CoverageResult:
    name: str
    source_label: str                           # table/query label for display
    total_source_columns: int
    mapped: List[MappedColumn] = field(default_factory=list)
    unmapped_usage: List[str] = field(default_factory=list)   # usage cols absent from source
    unreferenced_source: List[str] = field(default_factory=list)  # source cols not used

    @property
    def equivalent(self) -> bool:
        """True only when every usage column is mapped."""
        return len(self.unmapped_usage) == 0


def _load_usage_columns(spec: Dict[str, Any], base_dir: str) -> List[str]:
    if spec.get("usage_columns"):
        cols = spec["usage_columns"]
        if not isinstance(cols, list):
            raise CoverageError("'usage_columns' must be a list")
        return [str(c).strip() for c in cols if str(c).strip()]
    if spec.get("usage_file"):
        path = spec["usage_file"]
        if not os.path.isabs(path):
            path = os.path.join(base_dir, path)
        with open(path, encoding="utf-8") as fh:
            return [line.strip() for line in fh if line.strip() and not line.startswith("#")]
    raise CoverageError("coverage_check needs 'usage_columns' (list) or 'usage_file' (path)")


def _load_schema_file(path: str, base_dir: str) -> Dict[str, Dict[str, str]]:
    """Returns {lower(column_name): {column_name, type, description}}."""
    if not os.path.isabs(path):
        path = os.path.join(base_dir, path)
    result: Dict[str, Dict[str, str]] = {}
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        required = {"column_name"}
        if not reader.fieldnames or not required.issubset(
            {f.lower().strip() for f in reader.fieldnames}
        ):
            raise CoverageError(
                f"schema_file '{path}' must have at least a 'column_name' header column"
            )
        # normalise header names to lowercase for lookup
        for row in reader:
            norm = {k.lower().strip(): v.strip() for k, v in row.items()}
            col = norm.get("column_name", "").strip()
            if col:
                result[col.lower()] = {
                    "column_name": col,
                    "type": norm.get("type", ""),
                    "description": norm.get("description", ""),
                }
    return result


def _source_label(source_spec: Dict[str, Any]) -> str:
    return (
        source_spec.get("table")
        or source_spec.get("query", "")[:60]
        or source_spec.get("path", "")
        or source_spec.get("type", "?")
    )


def run_coverage_check(
    usage_columns: List[str],
    source_spec: Dict[str, Any],
    schema_override: Optional[Dict[str, Dict[str, str]]] = None,
    base_dir: str = ".",
) -> CoverageResult:
    """Core logic — no YAML parsing here, just pure data."""
    from .schema_introspect import describe_source

    source_schema: Dict[str, str] = describe_source(source_spec, base_dir=base_dir)
    # Build a lowercase→original-casing index for case-insensitive matching
    source_index: Dict[str, str] = {col.lower(): col for col in source_schema}

    label = _source_label(source_spec)
    mapped: List[MappedColumn] = []
    unmapped: List[str] = []
    referenced_source: set = set()

    for usage_col in usage_columns:
        source_col = source_index.get(usage_col.lower())
        if source_col is None:
            unmapped.append(usage_col)
            continue
        referenced_source.add(source_col)
        col_type = source_schema[source_col]
        description = ""
        if schema_override:
            override = schema_override.get(source_col.lower(), {})
            if override.get("type"):
                col_type = override["type"]
            description = override.get("description", "")
        mapped.append(MappedColumn(
            usage_name=usage_col,
            source_name=source_col,
            source_type=col_type,
            description=description,
        ))

    unreferenced = [col for col in source_schema if col not in referenced_source]

    return CoverageResult(
        name="",  # filled in by the caller
        source_label=label,
        total_source_columns=len(source_schema),
        mapped=mapped,
        unmapped_usage=unmapped,
        unreferenced_source=unreferenced,
    )


@dataclass
class CoverageCase:
    name: str
    usage_columns: List[str]
    source: Dict[str, Any]
    schema_override: Optional[Dict[str, Dict[str, str]]]
    description: str = ""
    tags: List[str] = field(default_factory=list)
    source_file: str = ""

    def run(self, base_dir: Optional[str] = None, **_) -> CoverageResult:
        base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
        result = run_coverage_check(
            self.usage_columns, self.source, self.schema_override, base_dir
        )
        result.name = self.name
        return result


def build_coverage_case(raw: dict, source_file: str) -> CoverageCase:
    cc = raw.get("coverage_check", {})
    for required in ("source",):
        if required not in cc:
            raise CoverageError(
                f"{source_file}: coverage_check is missing required field '{required}'"
            )
    base_dir = os.path.dirname(source_file) or "."
    usage_columns = _load_usage_columns(cc, base_dir)
    schema_override = None
    if cc.get("schema_file"):
        schema_override = _load_schema_file(cc["schema_file"], base_dir)
    return CoverageCase(
        name=raw.get("name", "coverage"),
        usage_columns=usage_columns,
        source=cc["source"],
        schema_override=schema_override,
        description=raw.get("description", ""),
        tags=raw.get("tags", []) or [],
        source_file=source_file,
    )


def load_coverage_cases(path: str) -> List[CoverageCase]:
    """Load coverage_check cases from a file or directory (*.yaml / *.yml)."""
    import glob

    import yaml

    if os.path.isdir(path):
        files = sorted(
            f
            for ext in ("*.yml", "*.yaml")
            for f in glob.glob(os.path.join(path, "**", ext), recursive=True)
        )
    else:
        files = [path]

    cases: List[CoverageCase] = []
    for fpath in files:
        with open(fpath, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or {}
        if not isinstance(doc, dict):
            continue
        if "coverage_check" not in doc:
            continue
        cases.append(build_coverage_case(doc, fpath))
    return cases
