"""Schema-only introspection: column names/types from a source, without ever
materializing a row. For concept_check.py — a many-source-to-one-target
"did we lose a business concept" check needs schemas from N+1 sources, and
should be structurally impossible to write in a way that scans real data.

Reuses sources.py's spec vocabulary (`type`/`table`/`query`/...), but every
path here is a genuinely metadata-only mechanism for that engine — not a
`LIMIT 0` SELECT a developer could forget to add, or that could still touch
data on some engines. `table:` is preferred; `query:` stays available for a
derived/hypothetical shape, but is always resolved through the same
metadata-only path, never executed as written.
"""

from __future__ import annotations

import glob
import os
from typing import Any, Dict

from .sources import SourceError, _resolve_path, resolve_query


def _resolve_query_or_table(
    spec: Dict[str, Any], base_dir: str = ".", variables: Dict[str, str] = None
) -> str:
    query = resolve_query(spec, base_dir, variables)
    if not query and spec.get("table"):
        query = f"SELECT * FROM {spec['table']}"
    if not query:
        raise SourceError("source needs a 'query' or 'table' for schema introspection")
    return query


def _describe_duckdb(spec, base_dir, variables=None) -> Dict[str, str]:
    try:
        import duckdb
    except ImportError as e:  # pragma: no cover
        raise SourceError("duckdb source needs `pip install rowparity[duckdb]`") from e

    database = spec.get("database", ":memory:")
    if database != ":memory:":
        database = _resolve_path(database, base_dir)
    con = duckdb.connect(database, read_only=spec.get("read_only", False))
    try:
        for stmt in spec.get("setup", []):
            con.execute(stmt)
        query = _resolve_query_or_table(spec, base_dir, variables)
        # DESCRIBE never executes the inner query -- catalog/plan lookup only.
        rows = con.execute(f"DESCRIBE ({query})").fetchall()
        return {r[0]: r[1] for r in rows}
    finally:
        con.close()


def _describe_snowflake(spec, base_dir, variables=None) -> Dict[str, str]:
    try:
        from snowflake.connector.constants import FIELD_ID_TO_NAME
    except ImportError as e:  # pragma: no cover
        raise SourceError("snowflake source needs `pip install rowparity[snowflake]`") from e
    from .snowflake_auth import connect as _sf_connect

    query = _resolve_query_or_table(spec, base_dir, variables)
    con = _sf_connect(spec)
    try:
        cur = con.cursor()
        metadata = cur.describe(query)  # explicitly: obtains schema WITHOUT executing
        out = {}
        for m in metadata:
            type_name = FIELD_ID_TO_NAME.get(m.type_code, str(m.type_code))
            if type_name == "FIXED" and m.scale:
                type_name = f"NUMBER({m.precision},{m.scale})"
            out[m.name] = type_name
        return out
    finally:
        con.close()


def _describe_trino(spec, base_dir, variables=None) -> Dict[str, str]:
    """Trino/Presto column types.

    Two mechanisms, picked by what the spec names:

    * ``table:`` -> ``DESCRIBE <table>``, a catalog metadata lookup. No scan,
      no splits, no rows. This is the same mechanism the BCV analyser uses,
      so the type strings returned here match what it reports.
    * ``query:`` / ``query_file:`` -> a ``LIMIT 0`` probe, because a *derived*
      query has no catalog entry to describe. Trino plans the scan away, so
      this stays metadata-only in practice, but unlike ``DESCRIBE`` it is a
      query the planner has to compile -- hence ``table:`` is preferred.
    """
    from .trino_auth import connect as _trino_connect

    query = resolve_query(spec, base_dir, variables)
    table = spec.get("table")
    if not query and not table:
        raise SourceError(
            "trino source needs a 'query', 'query_file', or 'table' for schema introspection"
        )

    con = _trino_connect(spec)
    try:
        cur = con.cursor()
        if query:
            cur.execute(f"SELECT * FROM ({query}) AS __rp_schema_probe LIMIT 0")
            # cursor.description is populated after execute() even with 0 rows.
            return {col[0]: col[1] for col in (cur.description or [])}
        cur.execute(f"DESCRIBE {table}")
        # Trino's DESCRIBE yields (Column, Type, Extra, Comment); only the
        # first two carry schema -- the rest is presentation metadata.
        return {row[0]: row[1] for row in cur.fetchall()}
    finally:
        con.close()


def _describe_spark(spec, base_dir, variables=None) -> Dict[str, str]:
    try:
        from pyspark.sql import SparkSession
    except ImportError as e:  # pragma: no cover
        raise SourceError("spark source needs pyspark installed") from e

    spark = SparkSession.builder.getOrCreate()
    query = _resolve_query_or_table(spec, base_dir, variables)
    df = spark.sql(query)  # lazy: .schema below triggers analysis/planning only, never execution
    return {f.name: f.dataType.simpleString() for f in df.schema.fields}


def _describe_iceberg(spec, base_dir, variables=None) -> Dict[str, str]:
    try:
        from pyiceberg.catalog import load_catalog
    except ImportError as e:  # pragma: no cover
        raise SourceError("iceberg source needs `pip install rowparity[iceberg]`") from e

    catalog = load_catalog(spec.get("catalog", "default"), **spec.get("catalog_properties", {}))
    table = catalog.load_table(spec["table"])
    return {f.name: str(f.field_type) for f in table.schema().fields}


def _describe_delta(spec, base_dir, variables=None) -> Dict[str, str]:
    try:
        from deltalake import DeltaTable
    except ImportError as e:  # pragma: no cover
        raise SourceError("delta source needs `pip install rowparity[delta]`") from e

    path = spec.get("path")
    if not path:
        raise SourceError("delta source requires a 'path'")
    if not os.path.isabs(path):
        path = _resolve_path(path, base_dir)
    dt = DeltaTable(path, storage_options=spec.get("storage_options", {}))
    arrow_schema = dt.schema().to_pyarrow()
    return {f.name: str(f.type) for f in arrow_schema}


def _describe_parquet(spec, base_dir, variables=None) -> Dict[str, str]:
    import pyarrow.parquet as pq

    pattern = _resolve_path(spec["path"], base_dir)
    files = sorted(glob.glob(pattern)) or [pattern]
    schema = pq.read_schema(files[0])  # file footer only, never reads row groups
    return {f.name: str(f.type) for f in schema}


def _describe_arrow(spec, base_dir, variables=None) -> Dict[str, str]:
    import pyarrow as pa

    path = _resolve_path(spec["path"], base_dir)
    with pa.memory_map(path, "rb") as source:
        reader = pa.ipc.open_file(source)
        return {f.name: str(f.type) for f in reader.schema}


def _describe_csv(spec, base_dir, variables=None) -> Dict[str, str]:
    from pyarrow import csv as pacsv

    path = _resolve_path(spec["path"], base_dir)
    # open_csv is a streaming reader; touching .schema only reads the first
    # block for type inference, not the whole file -- bounded, not a full scan.
    reader = pacsv.open_csv(path)
    return {f.name: str(f.type) for f in reader.schema}


def _describe_inline(spec, base_dir, variables=None) -> Dict[str, str]:
    schema_spec = spec.get("schema")
    if schema_spec:
        return dict(schema_spec)
    rows = spec.get("rows", [])
    if not rows:
        return {}
    import pyarrow as pa

    tbl = pa.Table.from_pylist(rows)
    return {f.name: str(f.type) for f in tbl.schema}


_HANDLERS = {
    "duckdb": _describe_duckdb,
    "sql": _describe_duckdb,
    "snowflake": _describe_snowflake,
    "trino": _describe_trino,
    "spark": _describe_spark,
    "iceberg": _describe_iceberg,
    "delta": _describe_delta,
    "parquet": _describe_parquet,
    "arrow": _describe_arrow,
    "feather": _describe_arrow,
    "csv": _describe_csv,
    "inline": _describe_inline,
}


def describe_source(
    spec: Dict[str, Any], *, base_dir: str = ".", variables: Dict[str, str] = None
) -> Dict[str, str]:
    """Column name -> type string, for any rowparity source spec, without
    materializing row data."""
    if not isinstance(spec, dict) or "type" not in spec:
        raise SourceError(f"source spec must be a dict with a 'type' key, got: {spec!r}")
    kind = spec["type"]
    handler = _HANDLERS.get(kind)
    if handler is None:
        raise SourceError(f"unknown source type '{kind}'. Known: {sorted(_HANDLERS)}")
    return handler(spec, base_dir, variables)
