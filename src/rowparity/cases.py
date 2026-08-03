"""YAML test-case format, loader, and executor.

A case is declarative on purpose: a QA engineer describes *what* the expected and
actual data are and *how* to compare them, never *how* to fetch or hash. One YAML
file may contain a single case or a list under ``cases:``. A top-level
``defaults:`` block is shallow-merged into every case (handy for shared
connection settings or a common ``compare`` policy).

Minimal example::

    name: orders_row_parity
    expected:
      type: duckdb
      query: SELECT * FROM read_parquet('expected/orders.parquet')
    actual:
      type: duckdb
      query: SELECT * FROM main.orders          # the dbt-built model
    compare:
      keys: [order_id]
      float_tolerance: 1e-9
"""
from __future__ import annotations

import glob
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Union

import yaml

from .compare import CompareConfig, ComparisonResult, compare_tables
from .concept_check import ConceptCheckCase, build_concept_check_case
from .schema_check import SchemaCheckCase, build_schema_check_case
from .sources import load_source

_COMPARE_KEYS = {
    "keys", "select", "ignore_columns", "float_tolerance", "coerce_numeric_to_float",
    "trim_strings", "case_insensitive", "unordered_list_columns", "strict_columns",
    "max_examples", "vectorized",
}


_ENGINES = {None, "python", "duckdb", "snowflake", "trino"}


@dataclass
class Case:
    name: str
    expected: Dict[str, Any]
    actual: Dict[str, Any]
    compare: Dict[str, Any] = field(default_factory=dict)
    description: str = ""
    tags: List[str] = field(default_factory=list)
    source_file: str = ""
    engine: Optional[str] = None

    def config(self) -> CompareConfig:
        unknown = set(self.compare) - _COMPARE_KEYS
        if unknown:
            raise ValueError(f"case '{self.name}': unknown compare option(s): {sorted(unknown)}")
        return CompareConfig(**self.compare)

    def run(self, base_dir: Optional[str] = None, sink=None, result_sink=None) -> ComparisonResult:
        base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
        cfg = self.config()

        if self.engine == "duckdb":
            result = self._run_duckdb_pushdown(base_dir, cfg)
        elif self.engine == "snowflake":
            result = self._run_snowflake_pushdown(base_dir, cfg)
        elif self.engine == "trino":
            result = self._run_trino_pushdown(base_dir, cfg)
        else:
            expected_tbl = load_source(self.expected, base_dir=base_dir)
            actual_tbl = load_source(self.actual, base_dir=base_dir)
            result = compare_tables(expected_tbl, actual_tbl, cfg)
            if sink:
                sink.write(self.name, "expected", expected_tbl, result.compared_columns, cfg)
                sink.write(self.name, "actual", actual_tbl, result.compared_columns, cfg)

        if result_sink:
            result_sink.write(self.name, self.tags, result)
        return result

    def _run_duckdb_pushdown(self, base_dir: str, cfg: CompareConfig) -> ComparisonResult:
        from . import duckdb_pushdown as pd

        con = pd.open_pushdown_connection([self.expected, self.actual], base_dir)
        try:
            expected_sql = pd.resolve_pushdown_sql(con, self.expected, base_dir)
            actual_sql = pd.resolve_pushdown_sql(con, self.actual, base_dir)
            if cfg.keys:
                return pd.duckdb_keyed_compare(con, expected_sql, actual_sql, cfg)
            return pd.duckdb_keyless_compare(con, expected_sql, actual_sql, cfg)
        finally:
            con.close()

    def _run_snowflake_pushdown(self, base_dir: str, cfg: CompareConfig) -> ComparisonResult:
        from . import snowflake_pushdown as spd

        con = spd.open_pushdown_connection([self.expected, self.actual])
        try:
            expected_sql = spd.resolve_pushdown_sql(self.expected, base_dir)
            actual_sql = spd.resolve_pushdown_sql(self.actual, base_dir)
            if cfg.keys:
                return spd.snowflake_keyed_compare(con, expected_sql, actual_sql, cfg)
            return spd.snowflake_keyless_compare(con, expected_sql, actual_sql, cfg)
        finally:
            con.close()

    def _run_trino_pushdown(self, base_dir: str, cfg: CompareConfig) -> ComparisonResult:
        from . import trino_pushdown as tpd

        con = tpd.open_pushdown_connection([self.expected, self.actual])
        try:
            expected_sql = tpd.resolve_pushdown_sql(self.expected, base_dir)
            actual_sql = tpd.resolve_pushdown_sql(self.actual, base_dir)
            if cfg.keys:
                return tpd.trino_keyed_compare(con, expected_sql, actual_sql, cfg)
            return tpd.trino_keyless_compare(con, expected_sql, actual_sql, cfg)
        finally:
            con.close()


def _merge_defaults(case: dict, defaults: dict) -> dict:
    out = dict(defaults or {})
    for k, v in case.items():
        if k == "compare" and isinstance(v, dict) and isinstance(out.get("compare"), dict):
            merged = dict(out["compare"])
            merged.update(v)
            out["compare"] = merged
        else:
            out[k] = v
    return out


def _build_case(raw: dict, source_file: str) -> Union[Case, ConceptCheckCase, SchemaCheckCase]:
    if "name" not in raw:
        raise ValueError(f"{source_file}: case is missing required field 'name': {raw!r}")

    if "schema_check" in raw:
        return build_schema_check_case(raw, source_file)

    if "concept_check" in raw:
        return build_concept_check_case(raw, source_file)

    for required in ("expected", "actual"):
        if required not in raw:
            raise ValueError(f"{source_file}: case is missing required field '{required}': {raw!r}")
    engine = raw.get("engine")
    if engine not in _ENGINES:
        raise ValueError(f"{source_file}: case '{raw['name']}' has unknown engine {engine!r} (known: {sorted(e for e in _ENGINES if e)})")
    return Case(
        name=raw["name"],
        expected=raw["expected"],
        actual=raw["actual"],
        compare=raw.get("compare", {}) or {},
        description=raw.get("description", ""),
        tags=raw.get("tags", []) or [],
        source_file=source_file,
        engine=engine,
    )


def load_cases_from_file(path: str) -> List[Union[Case, ConceptCheckCase]]:
    with open(path, "r", encoding="utf-8") as fh:
        doc = yaml.safe_load(fh) or {}
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: top level must be a mapping")
    defaults = doc.get("defaults", {}) or {}
    if "cases" in doc:
        raw_cases = doc["cases"]
    else:
        raw_cases = [doc]
    cases = []
    for raw in raw_cases:
        merged = _merge_defaults(raw, defaults)
        merged.pop("defaults", None)
        cases.append(_build_case(merged, path))
    return cases


def discover_cases(path: str) -> List[Union[Case, ConceptCheckCase]]:
    """Load cases from a single file or, if ``path`` is a directory, every *.yml/*.yaml under it."""
    if os.path.isdir(path):
        files: List[str] = []
        for ext in ("*.yml", "*.yaml"):
            files.extend(glob.glob(os.path.join(path, "**", ext), recursive=True))
        cases: List[Union[Case, ConceptCheckCase]] = []
        for f in sorted(files):
            cases.extend(load_cases_from_file(f))
        return cases
    return load_cases_from_file(path)
