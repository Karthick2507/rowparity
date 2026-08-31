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

from . import params, progress
from .compare import (
    CompareConfig,
    ComparisonResult,
    EmptyComparisonError,
    IdenticalSourcesError,
    compare_tables,
)
from .concept_check import ConceptCheckCase, build_concept_check_case
from .exclusions import ExclusionError, merge_ignore_columns
from .schema_check import SchemaCheckCase, build_schema_check_case
from .sources import load_source, resolve_query

_COMPARE_KEYS = {
    "keys", "select", "ignore_columns", "float_tolerance", "coerce_numeric_to_float",
    "trim_strings", "case_insensitive", "unordered_list_columns", "strict_columns",
    "max_examples", "vectorized", "null_equivalence", "allow_empty",
    "allow_identical_sources", "breakdown_by", "near_miss",
    "ignore_columns_file", "ignore_columns_table",
}

# Consumed while building CompareConfig and then dropped -- they resolve into
# ignore_columns rather than being options of their own, so CompareConfig (and
# every engine reading it) stays unaware that a file was involved.
_EXCLUSION_KEYS = ("ignore_columns_file", "ignore_columns_table")


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
    # Human names for the two sides, used by reports only.
    expected_label: str = "expected"
    actual_label: str = "actual"
    # Labelled groups of columns used to digest a diff row in the report.
    row_summary: List[Dict[str, Any]] = field(default_factory=list)
    # Optional drilldown: block -- generates per-row investigation SQL.
    drilldown: Optional[Dict[str, Any]] = None

    def config(self, base_dir: Optional[str] = None) -> CompareConfig:
        unknown = set(self.compare) - _COMPARE_KEYS
        if unknown:
            raise ValueError(f"case '{self.name}': unknown compare option(s): {sorted(unknown)}")

        options = {k: v for k, v in self.compare.items() if k not in _EXCLUSION_KEYS}
        # A single column name is the common case; normalise so everything
        # downstream sees a list and never has to ask which it got.
        if isinstance(options.get("breakdown_by"), str):
            options["breakdown_by"] = [options["breakdown_by"]]
        exclusion_file = self.compare.get("ignore_columns_file")
        exclusion_table = self.compare.get("ignore_columns_table")
        if exclusion_file or exclusion_table:
            base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
            try:
                options["ignore_columns"] = merge_ignore_columns(
                    self.compare.get("ignore_columns"),
                    exclusion_file,
                    exclusion_table,
                    base_dir=base_dir,
                )
            except ExclusionError as exc:
                raise ExclusionError(f"case '{self.name}': {exc}") from exc
        return CompareConfig(**options)

    def run(self, base_dir: Optional[str] = None, sink=None, result_sink=None) -> ComparisonResult:
        base_dir = base_dir or (os.path.dirname(self.source_file) or ".")
        cfg = self.config(base_dir)

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

        self._check_breakdown(cfg)

        progress.emit(f"Case '{self.name}'")

        self._guard_identical_sides(base_dir, cfg)

        if self.engine in ("duckdb", "snowflake", "trino"):
            # Push-down does its work inside the warehouse, so there is no
            # per-side load to time separately -- only the whole operation.
            runner = {
                "duckdb": self._run_duckdb_pushdown,
                "snowflake": self._run_snowflake_pushdown,
                "trino": self._run_trino_pushdown,
            }[self.engine]
            with progress.step(f"{self.engine} push-down") as st:
                result = runner(base_dir, cfg)
            result.compare_seconds = st.elapsed
        else:
            with progress.step(f"expected  ({self.expected.get('type', '?')})") as st:
                expected_tbl = load_source(
                    self.expected, base_dir=base_dir, variables=self.variables
                )
                st.result(progress.describe_table(expected_tbl))
            expected_seconds = st.elapsed

            with progress.step(f"actual    ({self.actual.get('type', '?')})") as st:
                actual_tbl = load_source(
                    self.actual, base_dir=base_dir, variables=self.variables
                )
                st.result(progress.describe_table(actual_tbl))
            actual_seconds = st.elapsed

            with progress.step("comparing") as st:
                result = compare_tables(expected_tbl, actual_tbl, cfg)
                st.result(f"{len(result.compared_columns)} columns compared")
            result.expected_load_seconds = expected_seconds
            result.actual_load_seconds = actual_seconds
            result.compare_seconds = st.elapsed

            if sink:
                sink.write(self.name, "expected", expected_tbl, result.compared_columns, cfg)
                sink.write(self.name, "actual", actual_tbl, result.compared_columns, cfg)

        result.expected_label = self.expected_label
        result.actual_label = self.actual_label
        result.row_summary = self.row_summary
        self._generate_drilldowns(result, base_dir)

        self._guard_empty(result, cfg)

        if result_sink:
            result_sink.write(self.name, self.tags, result)
        return result

    def _generate_drilldowns(self, result: ComparisonResult, base_dir: str) -> None:
        """Render per-row investigation SQL, if the case asks for it.

        Failures here are reported and swallowed. A drill-down is an aid to
        reading the result, not part of it -- losing a whole parity run because
        a helper query template has a typo would be the wrong trade entirely.
        """
        if not self.drilldown or result.equivalent:
            return
        from . import drilldown as dd

        sides = [
            {"label": self.expected_label, "spec": self.expected},
            {"label": self.actual_label, "spec": self.actual},
        ]
        try:
            cfg = dd.DrilldownConfig.from_yaml(self.drilldown)
            generated = dd.generate(
                cfg, result, sides, base_dir, self.variables, keys=result.keys
            )
        except Exception as exc:
            progress.emit(f"  drill-down SQL not generated: {type(exc).__name__}: {exc}")
            return

        result.drilldown = generated
        if cfg.execute:
            # Executing cannot raise past here: each side records its own
            # failure. A drill-down is an aid to reading the parity result, so
            # losing the whole run to it would be entirely the wrong trade.
            with progress.step("drill-down") as st:
                dd.execute(generated, cfg, sides, base_dir)
            st.result(
                f"{len(generated.only_expected)} / {len(generated.only_actual)} "
                f"{cfg.id_column} on one side only"
            )

    def _check_breakdown(self, cfg: CompareConfig) -> None:
        """Reject a breakdown that cannot be computed, before anything is fetched.

        Two restrictions, both structural rather than incidental:

        *Keys only.* A key is the only thing guaranteed identical on both sides
        of a paired row. Break down by a non-key column and a *changed* row has
        two group values, one per side, so it belongs to no single group --
        whichever side the code read would be an arbitrary choice presented as
        a fact. Adding the column to `keys` fixes it and is usually what the
        author meant anyway.

        *Default engine only.* Push-down engines count in SQL and never see a
        row, so they would accept the option and silently produce nothing. Same
        reasoning as null_equivalence above: refuse rather than quietly differ.
        """
        if not cfg.breakdown_by:
            return
        if self.engine in ("duckdb", "snowflake", "trino"):
            raise ValueError(
                f"case '{self.name}': breakdown_by is not supported with engine: "
                f"{self.engine}. It is attributed per row by the default engine; "
                f"push-down engines aggregate in-warehouse and never see one. "
                f"Drop the engine: key for this case."
            )
        if not cfg.keys:
            raise ValueError(
                f"case '{self.name}': breakdown_by needs compare.keys. Without a "
                f"key nothing pairs the two sides, so every difference is a "
                f"missing row plus an added row and there is no per-row "
                f"attribution to break down."
            )
        unknown = [c for c in cfg.breakdown_by if c not in cfg.keys]
        if unknown:
            raise ValueError(
                f"case '{self.name}': breakdown_by names {unknown}, which "
                f"{'are' if len(unknown) > 1 else 'is'} not in compare.keys. A "
                f"breakdown column has to be part of the key: only a key is "
                f"guaranteed the same on both sides of a changed row, so a "
                f"non-key column would put that row in two groups at once. "
                f"Add it to keys, or break down by a column already there."
            )

    def _guard_identical_sides(self, base_dir: str, cfg: CompareConfig) -> None:
        """Refuse to run one shared query file that resolves the same both sides.

        One SQL file parameterised per side removes the risk that two copies of
        a query drift apart. It introduces the mirror image: both sides
        resolving to the *same* catalog, because a ``vars:`` block was
        copy-pasted and half-edited. Nothing about that looks wrong -- the run
        succeeds, every row matches, and it reports EQUIVALENT with exit 0
        after however long the warehouse took. It is the ``_guard_empty``
        failure again in a new costume: a confident pass that verified nothing.

        **Scoped to the shared-``query_file`` case on purpose.** Two sides
        naming the same parquet path, or carrying two identical ``inline:``
        blocks, are hand-written fixtures whose author can see both sides at
        once; refusing those would reject a lot of legitimate cases to catch a
        mistake nobody makes. Pointing both sides at one file, on the other
        hand, has exactly one purpose -- to parameterise them differently -- so
        a run where that produced no difference is a bug every time.
        """
        if cfg.allow_identical_sources:
            return
        shared = self.expected.get("query_file")
        if not shared or shared != self.actual.get("query_file"):
            return
        try:
            expected_sql = resolve_query(
                self.expected, base_dir, params.merge_side_vars(self.expected.get("vars"), self.variables)
            )
            actual_sql = resolve_query(
                self.actual, base_dir, params.merge_side_vars(self.actual.get("vars"), self.variables)
            )
        except Exception:
            # Not this guard's job to report. Let the real load raise it, in
            # the step where the operator is already looking for the error.
            return
        if expected_sql != actual_sql:
            return
        raise IdenticalSourcesError(
            f"case '{self.name}': '{self.expected_label}' and '{self.actual_label}' "
            f"both read {shared} and resolve it to exactly the same query, so this "
            f"would compare a source with itself and report EQUIVALENT no matter "
            f"what the data holds. The usual cause is a copy-pasted per-side "
            f"'vars:' block where one value was never changed -- check that the "
            f"two sides name different places. Set compare.allow_identical_sources: "
            f"true if comparing a source with itself is genuinely the intent."
        )

    def _guard_empty(self, result: ComparisonResult, cfg: CompareConfig) -> None:
        """Refuse to call a comparison over zero rows equivalent.

        Two empty tables are trivially equivalent, so a run that fetched nothing
        reports EQUIVALENT and exits 0 -- identical in every visible way to a
        real pass. A live run did exactly this: eight minutes of warehouse time,
        both sides empty because the batch had aged out of staging, and a green
        "1/1 equivalent" at the end. A verification tool that reports success
        for having verified nothing is worse than one that crashes.

        Only row comparisons are guarded. schema_check and concept_check
        legitimately report zero rows -- fetching none is the entire point of
        them -- and they carry a different `kind`.
        """
        if cfg.allow_empty or result.kind != "rows":
            return
        if result.expected_rows or result.actual_rows:
            return
        raise EmptyComparisonError(
            f"case '{self.name}': both sides returned 0 rows, so nothing was "
            f"compared. This would otherwise report EQUIVALENT and exit 0, which "
            f"is indistinguishable from a real pass. Usual causes: the batch or "
            f"partition no longer exists, a ${{parameter}} names something that "
            f"was never there, or a filter matched nothing on both sides. Check "
            f"the queries return rows before trusting a comparison of them. Set "
            f"compare.allow_empty: true if an empty result is genuinely expected "
            f"for this case."
        )

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
        expected_label=raw.get("expected_label", "expected"),
        actual_label=raw.get("actual_label", "actual"),
        row_summary=raw.get("row_summary", []) or [],
        drilldown=raw.get("drilldown"),
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
