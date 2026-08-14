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

from . import params
from .compare import CompareConfig, ComparisonResult, compare_tables
from .concept_check import ConceptCheckCase, build_concept_check_case
from .schema_check import SchemaCheckCase, build_schema_check_case
from .sources import load_source

_COMPARE_KEYS = {
    "keys", "select", "ignore_columns", "float_tolerance", "coerce_numeric_to_float",
    "trim_strings", "case_insensitive", "unordered_list_columns", "strict_columns",
    "max_examples", "vectorized", "null_equivalence",
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
    # Resolved ${name} values. Spec dicts are already substituted by the time
    # a Case exists; these are kept for query_file contents, which are only
    # read at run time.
    variables: Dict[str, str] = field(default_factory=dict)

    def config(self) -> CompareConfig:
        unknown = set(self.compare) - _COMPARE_KEYS
        if unknown:
            raise ValueError(f"case '{self.name}': unknown compare option(s): {sorted(unknown)}")
        return CompareConfig(**self.compare)

    def run(self, base_dir: Optional[str] = None, sink=None, result_sink=None) -> ComparisonResult:
        base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
        cfg = self.config()

        # Equivalence classification happens in compare.py's per-row diff pass,
        # which push-down engines do not run -- they would accept the option and
        # silently classify nothing. Refuse instead of quietly differing.
        if cfg.null_equivalence and self.engine in ("duckdb", "snowflake", "trino"):
            raise ValueError(
                f"case '{self.name}': null_equivalence is not supported with "
                f"engine: {self.engine}. It is computed per changed row by the "
                f"default engine; push-down engines fingerprint in-warehouse and "
                f"never see individual values. Drop the engine: key for this case."
            )

        if self.engine == "duckdb":
            result = self._run_duckdb_pushdown(base_dir, cfg)
        elif self.engine == "snowflake":
            result = self._run_snowflake_pushdown(base_dir, cfg)
        elif self.engine == "trino":
            result = self._run_trino_pushdown(base_dir, cfg)
        else:
            expected_tbl = load_source(self.expected, base_dir=base_dir, variables=self.variables)
            actual_tbl = load_source(self.actual, base_dir=base_dir, variables=self.variables)
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


def _build_case(
    raw: dict,
    source_file: str,
    file_vars: Optional[Dict[str, Any]] = None,
    cli_params: Optional[Dict[str, Any]] = None,
    query_vars: Optional[Dict[str, str]] = None,
    deferred_names: frozenset = frozenset(),
) -> Union[Case, ConceptCheckCase, SchemaCheckCase]:
    if "name" not in raw:
        raise ValueError(f"{source_file}: case is missing required field 'name': {raw!r}")

    # Resolve ${name} placeholders once, over the whole raw case, before any
    # shape dispatch -- so every case type gets it for free and no spec dict
    # can reach an engine still holding an unsubstituted placeholder.
    raw = dict(raw)
    case_vars = raw.pop("vars", None) or {}
    raw.pop("param_queries", None)  # resolved once per file, see load_cases_from_file
    variables = params.resolve_variables(file_vars, case_vars, cli_params)
    # Query-resolved values sit below --param/env (which short-circuit the
    # query entirely) but above a vars: default.
    for name, value in (query_vars or {}).items():
        variables.setdefault(name, value)
    raw = params.substitute_spec(raw, variables, where=f"case '{raw['name']}' ({source_file})")
    # Names whose query was skipped stood in for themselves just now, so that
    # listing works. They must NOT survive onto the case: query_file contents
    # are substituted at run time, and a literal "${batch_id}" reaching an
    # engine is precisely the failure this design exists to prevent. Dropping
    # them restores the clear "unresolved parameter" error instead.
    for name in deferred_names:
        variables.pop(name, None)

    if "schema_check" in raw:
        return build_schema_check_case(raw, source_file, variables=variables)

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
        variables=variables,
    )


def load_cases_from_file(
    path: str,
    params_: Optional[Dict[str, Any]] = None,
    resolve_queries: bool = True,
) -> List[Union[Case, ConceptCheckCase]]:
    with open(path, "r", encoding="utf-8") as fh:
        doc = yaml.safe_load(fh) or {}
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: top level must be a mapping")
    defaults = doc.get("defaults", {}) or {}
    # A file-level vars: block sits beside cases: and applies to all of them.
    # For a single-case document it is part of the case itself, and _build_case
    # picks it up there instead.
    multi = "cases" in doc
    file_vars = (doc.get("vars", {}) or {}) if multi else {}
    # param_queries: sits at document level either way -- beside cases:, or as
    # a key of the single case, which is the document.
    param_queries = doc.get("param_queries", {}) or {}
    raw_cases = doc["cases"] if multi else [doc]

    # Resolve query-backed parameters ONCE per file, not per case. Two cases
    # that both key off the latest batch must see the same batch: resolving
    # per case would let a batch landing mid-run compare two different
    # populations, which is exactly the kind of difference that looks like a
    # data defect.
    query_vars: Dict[str, str] = {}
    deferred: frozenset = frozenset()
    if param_queries and resolve_queries:
        from .param_queries import resolve_param_queries

        seed = params.resolve_variables(file_vars, {}, params_)
        query_vars = resolve_param_queries(
            param_queries, seed, base_dir=os.path.dirname(path) or "."
        )
    elif param_queries:
        # Resolution is off (rowparity list), but these names are legitimately
        # declared -- failing with "unresolved parameter" would be wrong and
        # would stop listing cases at all. Substitute each to its own literal
        # placeholder: a single pass, so the text is unchanged and visibly
        # still-unresolved rather than a fabricated value.
        query_vars = {str(name).lower(): "${" + str(name) + "}" for name in param_queries}
        deferred = frozenset(query_vars)

    cases = []
    for raw in raw_cases:
        merged = _merge_defaults(raw, defaults)
        merged.pop("defaults", None)
        cases.append(
            _build_case(
                merged,
                path,
                file_vars=file_vars,
                cli_params=params_,
                query_vars=query_vars,
                deferred_names=deferred,
            )
        )
    return cases


def discover_cases(
    path: str,
    params_: Optional[Dict[str, Any]] = None,
    resolve_queries: bool = True,
) -> List[Union[Case, ConceptCheckCase]]:
    """Load cases from a single file or, if ``path`` is a directory, every *.yml/*.yaml under it.

    ``params_`` carries ``--param NAME=VALUE`` overrides; they take precedence
    over both a case's ``vars:`` block and ``ROWPARITY_VAR_*`` environment
    variables.

    ``resolve_queries`` runs any ``param_queries:`` block. ``rowparity list``
    turns it off so that merely listing cases never touches a warehouse.
    """
    if os.path.isdir(path):
        files: List[str] = []
        for ext in ("*.yml", "*.yaml"):
            files.extend(glob.glob(os.path.join(path, "**", ext), recursive=True))
        cases: List[Union[Case, ConceptCheckCase]] = []
        for f in sorted(files):
            cases.extend(load_cases_from_file(f, params_, resolve_queries))
        return cases
    return load_cases_from_file(path, params_, resolve_queries)
