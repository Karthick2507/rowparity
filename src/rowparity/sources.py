"""Pluggable data sources. Every source returns a ``pyarrow.Table``.

The comparison core never knows or cares where data came from — that is the whole
point. The same YAML case can read ``expected`` from an inline literal and
``actual`` from Snowflake, or read both from a local DuckDB run in CI. Swapping
engines (Snowflake <-> Spark/Iceberg <-> dbt-duckdb) means changing the source
block, never the assertions.

Heavy drivers (snowflake, pyiceberg) are imported lazily so the core has no hard
dependency on them; you only need the driver for the sources you actually use.

A source is described by a dict with a ``type`` key. Supported types:

    inline    rows literal in the YAML (great for expected fixtures)
    csv       path to a .csv
    parquet   path/glob to .parquet file(s)
    arrow     path to a .arrow / .feather file
    duckdb    a SQL query against a DuckDB database (file or :memory: over parquet/iceberg)
    sql       alias for duckdb
    snowflake a SQL query against Snowflake (key-pair auth only, see snowflake_auth.py)
    trino     a SQL query against Trino (see trino_auth.py for auth/connection options)
    iceberg   an Iceberg table via pyiceberg (optionally row-filtered)

See ``examples/cases`` for real usage.
"""
from __future__ import annotations

import glob
import os
from typing import Any, Dict, List

import pyarrow as pa


class SourceError(RuntimeError):
    pass


def load_source(
    spec: Dict[str, Any], *, base_dir: str = ".", variables: Dict[str, str] = None
) -> pa.Table:
    """Materialise a source spec into an Arrow table.

    ``variables`` carries resolved ``${name}`` values for ``query_file:``
    contents. Spec dicts themselves are already substituted by the case
    loader, so this only matters for SQL read from disk at run time.
    """
    if not isinstance(spec, dict) or "type" not in spec:
        raise SourceError(f"source spec must be a dict with a 'type' key, got: {spec!r}")
    kind = spec["type"]
    handler = _HANDLERS.get(kind)
    if handler is None:
        raise SourceError(f"unknown source type '{kind}'. Known: {sorted(_HANDLERS)}")
    return handler(spec, base_dir, variables)


def _resolve_path(path: str, base_dir: str) -> str:
    return path if os.path.isabs(path) else os.path.join(base_dir, path)


def resolve_query(
    spec: Dict[str, Any], base_dir: str, variables: Dict[str, str] = None
) -> "str | None":
    """Return SQL from ``query:`` or, if absent, by reading ``query_file:``.

    ``query_file`` is resolved relative to ``base_dir`` (the YAML case file's
    directory), so sibling SQL files can be referenced with a plain filename::

        actual:
          type: trino
          query_file: sqls/actual_revenue.sql

    ``${name}`` placeholders inside the file are substituted from
    ``variables``; an unresolved one raises rather than reaching the engine.
    """
    if spec.get("query"):
        return spec["query"]
    qf = spec.get("query_file")
    if qf:
        path = _resolve_path(qf, base_dir)
        with open(path, "r", encoding="utf-8") as fh:
            sql = fh.read().strip()
        if variables is not None:
            from .params import substitute

            sql = substitute(sql, variables, where=path)
        return sql
    return None


# --------------------------------------------------------------------------- #
# Local / literal sources
# --------------------------------------------------------------------------- #
def _inline(spec, base_dir, variables=None) -> pa.Table:
    rows: List[dict] = spec.get("rows", [])
    if not isinstance(rows, list):
        raise SourceError("inline source requires a 'rows' list")
    schema = _schema_from_spec(spec.get("schema"))
    if not rows:
        return pa.table({}, schema=schema) if schema else pa.table({})
    if schema is not None:
        return pa.Table.from_pylist(rows, schema=schema)
    return pa.Table.from_pylist(rows)


def _schema_from_spec(schema_spec) -> pa.Schema | None:
    """Optional explicit typing for inline fixtures, e.g. {col: 'int64', amt: 'decimal128(10,2)'}."""
    if not schema_spec:
        return None
    fields = []
    for name, type_str in schema_spec.items():
        fields.append(pa.field(name, _parse_type(type_str)))
    return pa.schema(fields)


def _parse_type(type_str: str) -> pa.DataType:
    # A small, explicit type mini-parser for common cases used in fixtures.
    t = type_str.strip()
    simple = {
        "int": pa.int64(), "int32": pa.int32(), "int64": pa.int64(),
        "float": pa.float64(), "double": pa.float64(), "float32": pa.float32(),
        "str": pa.string(), "string": pa.string(), "bool": pa.bool_(),
        "date": pa.date32(), "timestamp": pa.timestamp("us"),
        "timestamptz": pa.timestamp("us", tz="UTC"),
    }
    if t in simple:
        return simple[t]
    if t.startswith("decimal"):
        inside = t[t.index("(") + 1 : t.index(")")]
        p, s = (int(x) for x in inside.split(","))
        return pa.decimal128(p, s)
    if t.startswith("list<") and t.endswith(">"):
        return pa.list_(_parse_type(t[5:-1]))
    raise SourceError(f"cannot parse type '{type_str}' (extend _parse_type if you need it)")


def _csv(spec, base_dir, variables=None) -> pa.Table:
    from pyarrow import csv as pacsv

    path = _resolve_path(spec["path"], base_dir)
    return pacsv.read_csv(path)


def _parquet(spec, base_dir, variables=None) -> pa.Table:
    import pyarrow.parquet as pq

    pattern = _resolve_path(spec["path"], base_dir)
    files = sorted(glob.glob(pattern)) or [pattern]
    if len(files) == 1:
        return pq.read_table(files[0])
    return pa.concat_tables([pq.read_table(f) for f in files], promote_options="default")


def _arrow(spec, base_dir, variables=None) -> pa.Table:
    import pyarrow.feather as feather

    return feather.read_table(_resolve_path(spec["path"], base_dir))


# --------------------------------------------------------------------------- #
# Query sources
# --------------------------------------------------------------------------- #
def _duckdb(spec, base_dir, variables=None) -> pa.Table:
    try:
        import duckdb
    except ImportError as e:  # pragma: no cover
        raise SourceError("duckdb source needs `pip install rowparity[duckdb]`") from e

    database = spec.get("database", ":memory:")
    if database != ":memory:":
        database = _resolve_path(database, base_dir)
    con = duckdb.connect(database, read_only=spec.get("read_only", False))
    try:
        for stmt in spec.get("setup", []):          # e.g. INSTALL/LOAD iceberg, CREATE VIEW
            con.execute(stmt)
        query = resolve_query(spec, base_dir, variables)
        if not query and spec.get("table"):
            query = f"SELECT * FROM {spec['table']}"
        if not query:
            raise SourceError("duckdb source needs a 'query' or 'table'")
        out = con.execute(query).arrow()
        # Depending on the duckdb version, .arrow() yields a Table or a streaming reader.
        if isinstance(out, pa.RecordBatchReader):
            out = out.read_all()
        return out
    finally:
        con.close()


def _snowflake(spec, base_dir, variables=None) -> pa.Table:
    from .snowflake_auth import connect as _sf_connect

    query = resolve_query(spec, base_dir, variables)
    if not query and spec.get("table"):
        query = f"SELECT * FROM {spec['table']}"
    if not query:
        raise SourceError("snowflake source needs a 'query' or 'table'")

    con = _sf_connect(spec)
    try:
        cur = con.cursor()
        cur.execute(query)
        batches = cur.fetch_arrow_all()          # -> pa.Table (or None if empty)
        if batches is None:
            return pa.table({})
        return batches
    finally:
        con.close()


def _iceberg(spec, base_dir, variables=None) -> pa.Table:
    try:
        from pyiceberg.catalog import load_catalog
    except ImportError as e:  # pragma: no cover
        raise SourceError("iceberg source needs `pip install rowparity[iceberg]`") from e

    catalog = load_catalog(spec.get("catalog", "default"), **spec.get("catalog_properties", {}))
    table = catalog.load_table(spec["table"])
    scan = table.scan(row_filter=spec.get("row_filter", "true"),
                      selected_fields=tuple(spec["columns"]) if spec.get("columns") else ("*",))
    return scan.to_arrow()


def _delta(spec, base_dir, variables=None) -> pa.Table:
    """Delta Lake table via delta-rs (no Spark/JVM required).

    Reads Delta tables from local paths, S3, GCS, or ADLS directly into Arrow.
    Unity Catalog tables are Delta tables under the hood and work the same way.

    Install: pip install rowparity[delta]
    """
    try:
        from deltalake import DeltaTable
    except ImportError as e:  # pragma: no cover
        raise SourceError("delta source needs `pip install rowparity[delta]`") from e

    path = spec.get("path")
    if not path:
        raise SourceError("delta source requires a 'path'")
    if not os.path.isabs(path):
        path = _resolve_path(path, base_dir)

    # storage_options passes cloud credentials: {"AWS_REGION": "us-east-1"} etc.
    dt = DeltaTable(path, storage_options=spec.get("storage_options", {}))

    # version: read a specific Delta snapshot (time-travel)
    if spec.get("version") is not None:
        dt.load_version(spec["version"])
    elif spec.get("timestamp"):
        dt.load_with_datetime(spec["timestamp"])

    return dt.to_pyarrow(
        columns=spec.get("columns"),          # optional column projection
        filters=spec.get("filters"),          # partition/row filters: [("col",">=","val")]
    )


def _trino(spec, base_dir, variables=None) -> pa.Table:
    from .trino_auth import connect as _trino_connect

    query = resolve_query(spec, base_dir, variables)
    if not query and spec.get("table"):
        query = f"SELECT * FROM {spec['table']}"
    if not query:
        raise SourceError("trino source needs a 'query' or 'table'")

    con = _trino_connect(spec)
    try:
        cur = con.cursor()
        cur.execute(query)
        rows = cur.fetchall()
        if not rows:
            col_names = [d[0] for d in (cur.description or [])]
            return pa.table({col: [] for col in col_names})
        col_names = [d[0] for d in cur.description]
        return pa.Table.from_pylist([dict(zip(col_names, row)) for row in rows])
    finally:
        con.close()


def _spark(spec, base_dir, variables=None) -> pa.Table:
    """Spark DataFrame or SQL query, collected to Arrow via PySpark's Arrow bridge.

    Requires a live SparkSession (getOrCreate). Enables Arrow-optimized transfer
    automatically. Suitable for small-to-medium result sets; for large tables use
    the Fingerprint Sink with Spark SQL pushdown instead.

    Install: pip install rowparity[spark]  (or manage pyspark in your own environment)
    """
    try:
        from pyspark.sql import SparkSession
    except ImportError as e:  # pragma: no cover
        raise SourceError("spark source needs pyspark installed") from e

    spark = SparkSession.builder.getOrCreate()

    # Enable Arrow-optimized toPandas() transfer; ignore if conf is read-only.
    try:
        spark.conf.set("spark.sql.execution.arrow.pyspark.enabled", "true")
    except Exception:  # pragma: no cover
        pass

    query = spec.get("query")
    if not query and spec.get("table"):
        query = f"SELECT * FROM {spec['table']}"
    if not query:
        raise SourceError("spark source needs a 'query' or 'table'")

    df = spark.sql(query)
    # Column projection pushed into Spark before collection.
    if spec.get("columns"):
        df = df.select(*spec["columns"])

    return pa.Table.from_pandas(df.toPandas(), preserve_index=False)


_HANDLERS = {
    "inline": _inline,
    "csv": _csv,
    "parquet": _parquet,
    "arrow": _arrow,
    "feather": _arrow,
    "duckdb": _duckdb,
    "sql": _duckdb,
    "snowflake": _snowflake,
    "trino": _trino,
    "iceberg": _iceberg,
    "delta": _delta,
    "spark": _spark,
}
