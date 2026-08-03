"""Result sink: persists ComparisonResult summaries and diff examples to a store.

Two tables are written per run:

  <prefix>_run_summary  — one row per case: counts, equivalence, metadata
  <prefix>_run_diffs    — one row per diff example: the actual changed/missing/added rows

Supported backends: DuckDB (local/CI), Snowflake (production), Iceberg (Lakehouse).

Use cases beyond QA:
  - Historical trend: which cases fail most often, and since when?
  - Consecutive failure alerting: case X has failed N runs in a row
  - Row-level audit trail: exactly which rows changed and what the values were
  - SLA monitoring: expected_rows within bounds over time
  - Cross-team observability: publish diff results to a shared warehouse schema
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import List, Optional

import pyarrow as pa

from .compare import ComparisonResult

# ── Shared table schemas ──────────────────────────────────────────────────────

SUMMARY_SCHEMA = pa.schema([
    pa.field("run_id",                  pa.string()),
    pa.field("run_ts",                  pa.timestamp("us", tz="UTC")),
    pa.field("case_name",               pa.string()),
    pa.field("tags",                    pa.string()),    # JSON array
    pa.field("equivalent",              pa.bool_()),
    pa.field("expected_rows",           pa.int64()),
    pa.field("actual_rows",             pa.int64()),
    pa.field("missing_count",           pa.int64()),
    pa.field("added_count",             pa.int64()),
    pa.field("changed_count",           pa.int64()),
    pa.field("compared_columns",        pa.string()),   # JSON array
    pa.field("keys",                    pa.string()),   # JSON array or null
    pa.field("type_mismatches",         pa.string()),   # JSON array of {column,expected,actual}
    pa.field("columns_only_in_expected", pa.string()),  # JSON array — schema drift, left-only
    pa.field("columns_only_in_actual",   pa.string()),  # JSON array — schema drift, right-only
])

DIFFS_SCHEMA = pa.schema([
    pa.field("run_id",       pa.string()),
    pa.field("case_name",    pa.string()),
    pa.field("diff_kind",    pa.string()),    # 'missing' | 'added' | 'changed'
    pa.field("key_json",     pa.string()),   # human-readable key values; null for keyless
    pa.field("expected_row", pa.string()),   # full row as JSON; null for 'added'
    pa.field("actual_row",   pa.string()),   # full row as JSON; null for 'missing'
    pa.field("column_diffs", pa.string()),   # JSON [{column,expected,actual}]; 'changed' only
])


# ── Serialization helpers ─────────────────────────────────────────────────────

def _key_to_json(key) -> Optional[str]:
    if key is None:
        return None
    # Each element is a canonical tuple like ('i', 5) or ('t', 'US'); take the payload.
    parts = [str(el[1]) if isinstance(el, tuple) and len(el) >= 2 else str(el) for el in key]
    return json.dumps(parts)


def _row_to_json(row: Optional[dict]) -> Optional[str]:
    if row is None:
        return None
    return json.dumps(row, default=str)


def _build_summary_batch(run_id: str, run_ts: datetime,
                          case_name: str, tags: List[str],
                          result: ComparisonResult) -> pa.Table:
    row = {
        "run_id":           run_id,
        "run_ts":           run_ts,
        "case_name":        case_name,
        "tags":             json.dumps(tags),
        "equivalent":       result.equivalent,
        "expected_rows":    result.expected_rows,
        "actual_rows":      result.actual_rows,
        "missing_count":    result.missing_count,
        "added_count":      result.added_count,
        "changed_count":    result.changed_count,
        "compared_columns": json.dumps(result.compared_columns),
        "keys":             json.dumps(result.keys) if result.keys else None,
        "type_mismatches":  json.dumps([
            {"column": c, "expected": e, "actual": a}
            for c, e, a in result.type_mismatches
        ]),
        "columns_only_in_expected": json.dumps(result.columns_only_in_expected),
        "columns_only_in_actual":   json.dumps(result.columns_only_in_actual),
    }
    return pa.Table.from_pylist([row], schema=SUMMARY_SCHEMA)


def _build_diffs_batch(run_id: str, case_name: str,
                        result: ComparisonResult) -> Optional[pa.Table]:
    rows = []
    for diff in result.examples:
        rows.append({
            "run_id":       run_id,
            "case_name":    case_name,
            "diff_kind":    diff.kind,
            "key_json":     _key_to_json(diff.key),
            "expected_row": _row_to_json(diff.expected_row),
            "actual_row":   _row_to_json(diff.actual_row),
            "column_diffs": json.dumps([
                {"column": c.column, "expected": str(c.expected), "actual": str(c.actual)}
                for c in diff.columns
            ]) if diff.columns else None,
        })
    if not rows:
        return None
    return pa.Table.from_pylist(rows, schema=DIFFS_SCHEMA)


# ── Base class ────────────────────────────────────────────────────────────────

class ResultSink:
    """Persists ComparisonResult data to a backend store.

    Call write() once per case after case.run() returns.
    Call close() after all cases complete (flushes connections).
    """

    def __init__(self, run_id: str, table_prefix: str = "rowparity"):
        self.run_id = run_id
        self.summary_table = f"{table_prefix}_run_summary"
        self.diffs_table   = f"{table_prefix}_run_diffs"

    def write(self, case_name: str, tags: List[str], result: ComparisonResult,
              run_ts: Optional[datetime] = None) -> None:
        summary = _build_summary_batch(self.run_id, run_ts or datetime.now(tz=timezone.utc), case_name, tags, result)
        diffs   = _build_diffs_batch(self.run_id, case_name, result)
        self._write_batches(summary, diffs)

    def _write_batches(self, summary: pa.Table, diffs: Optional[pa.Table]) -> None:
        raise NotImplementedError

    def close(self) -> None:
        pass


# ── DuckDB backend ────────────────────────────────────────────────────────────

class DuckDBResultSink(ResultSink):
    """Writes to a local DuckDB file. Zero extra dependencies beyond duckdb.

    Ideal for CI and local development. The .duckdb file can be queried
    directly with DuckDB CLI or via Python for trend analysis.
    """

    def __init__(self, path: str, run_id: str, table_prefix: str = "rowparity"):
        super().__init__(run_id, table_prefix)
        try:
            import duckdb as _duckdb  # noqa: F401
        except ImportError as e:
            raise RuntimeError("DuckDB result sink needs `pip install rowparity[duckdb]`") from e
        parent = os.path.dirname(os.path.abspath(path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        import duckdb as _ddb
        self._con = _ddb.connect(path)
        self._bootstrap()

    def _bootstrap(self):
        self._con.execute(f"""
            CREATE TABLE IF NOT EXISTS {self.summary_table} (
                run_id VARCHAR, run_ts TIMESTAMPTZ, case_name VARCHAR, tags VARCHAR,
                equivalent BOOLEAN, expected_rows BIGINT, actual_rows BIGINT,
                missing_count BIGINT, added_count BIGINT, changed_count BIGINT,
                compared_columns VARCHAR, keys VARCHAR, type_mismatches VARCHAR,
                columns_only_in_expected VARCHAR, columns_only_in_actual VARCHAR
            )
        """)
        # ALTER ... ADD COLUMN IF NOT EXISTS: a .duckdb file from before these two
        # columns existed still opens and gets migrated forward, instead of the
        # INSERT below failing on a column-count mismatch.
        for col in ("columns_only_in_expected", "columns_only_in_actual"):
            self._con.execute(f"ALTER TABLE {self.summary_table} ADD COLUMN IF NOT EXISTS {col} VARCHAR")
        self._con.execute(f"""
            CREATE TABLE IF NOT EXISTS {self.diffs_table} (
                run_id VARCHAR, case_name VARCHAR, diff_kind VARCHAR,
                key_json VARCHAR, expected_row VARCHAR,
                actual_row VARCHAR, column_diffs VARCHAR
            )
        """)

    def _write_batches(self, summary: pa.Table, diffs: Optional[pa.Table]):
        self._con.register("_s", summary)
        self._con.execute(f"INSERT INTO {self.summary_table} SELECT * FROM _s")
        if diffs is not None and diffs.num_rows > 0:
            self._con.register("_d", diffs)
            self._con.execute(f"INSERT INTO {self.diffs_table} SELECT * FROM _d")

    def close(self):
        self._con.close()


# ── Snowflake backend ─────────────────────────────────────────────────────────

class SnowflakeResultSink(ResultSink):
    """Writes to Snowflake tables (auto-created if absent).

    Credentials are read from SNOWFLAKE_* environment variables or passed
    explicitly in the connection dict.
    """

    def __init__(self, schema: str, run_id: str,
                 table_prefix: str = "rowparity", connection: dict = None):
        super().__init__(run_id, table_prefix)
        from .snowflake_auth import connect as _sf_connect

        conn = dict(connection or {})
        if schema and "." in schema:
            db, sch = schema.split(".", 1)
            conn.setdefault("database", db)
            conn.setdefault("schema", sch)

        self._con = _sf_connect({"connection": conn})
        self._bootstrap()

    def _bootstrap(self):
        cur = self._con.cursor()
        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS {self.summary_table} (
                run_id VARCHAR, run_ts TIMESTAMP_TZ, case_name VARCHAR, tags VARCHAR,
                equivalent BOOLEAN, expected_rows NUMBER, actual_rows NUMBER,
                missing_count NUMBER, added_count NUMBER, changed_count NUMBER,
                compared_columns VARCHAR, keys VARCHAR, type_mismatches VARCHAR,
                columns_only_in_expected VARCHAR, columns_only_in_actual VARCHAR
            )
        """)
        for col in ("columns_only_in_expected", "columns_only_in_actual"):
            cur.execute(f"ALTER TABLE {self.summary_table} ADD COLUMN IF NOT EXISTS {col} VARCHAR")
        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS {self.diffs_table} (
                run_id VARCHAR, case_name VARCHAR, diff_kind VARCHAR,
                key_json VARCHAR, expected_row VARCHAR,
                actual_row VARCHAR, column_diffs VARCHAR
            )
        """)
        cur.close()

    def _write_batches(self, summary: pa.Table, diffs: Optional[pa.Table]):
        from snowflake.connector.pandas_tools import write_pandas
        write_pandas(self._con, summary.to_pandas(),
                     self.summary_table.upper(), auto_create_table=False)
        if diffs is not None and diffs.num_rows > 0:
            write_pandas(self._con, diffs.to_pandas(),
                         self.diffs_table.upper(), auto_create_table=False)

    def close(self):
        self._con.close()


# ── Iceberg backend ───────────────────────────────────────────────────────────

class IcebergResultSink(ResultSink):
    """Writes to Iceberg tables via pyiceberg (auto-created if absent).

    Works with any Iceberg catalog: Glue, REST, Hive, Unity Catalog.
    Tables are partitioned by case_name for fast per-case queries.
    """

    def __init__(self, namespace: str, run_id: str, catalog_name: str = "default",
                 catalog_properties: dict = None, table_prefix: str = "rowparity"):
        super().__init__(run_id, table_prefix)
        try:
            from pyiceberg.catalog import load_catalog
        except ImportError as e:
            raise RuntimeError("Iceberg result sink needs `pip install rowparity[iceberg]`") from e

        from pyiceberg.catalog import load_catalog
        self._catalog  = load_catalog(catalog_name, **(catalog_properties or {}))
        self._namespace = namespace
        self._summary_tbl = self._get_or_create(self.summary_table, SUMMARY_SCHEMA)
        self._diffs_tbl   = self._get_or_create(self.diffs_table,   DIFFS_SCHEMA)

    def _get_or_create(self, name: str, schema: pa.Schema):
        from pyiceberg.exceptions import NoSuchTableError
        identifier = (self._namespace, name)
        try:
            return self._catalog.load_table(identifier)
        except NoSuchTableError:
            return self._catalog.create_table(identifier, schema=schema)

    def _write_batches(self, summary: pa.Table, diffs: Optional[pa.Table]):
        self._summary_tbl.append(summary)
        if diffs is not None and diffs.num_rows > 0:
            self._diffs_tbl.append(diffs)


# ── Factory ───────────────────────────────────────────────────────────────────

def make_result_sink(spec: str, run_id: str, table_prefix: str = "rowparity") -> ResultSink:
    """Parse a result-sink spec string into a ResultSink instance.

    Formats:
        duckdb:<path>           e.g.  duckdb:./reports/results.duckdb
        snowflake:<DB.SCHEMA>   e.g.  snowflake:MY_DB.QA_SCHEMA
        iceberg:<namespace>     e.g.  iceberg:qa_results
    """
    if ":" not in spec:
        raise ValueError(
            f"--result-sink must be <backend>:<target>, got: {spec!r}\n"
            f"Examples: duckdb:./results.duckdb  snowflake:MY_DB.QA  iceberg:qa_results"
        )
    backend, target = spec.split(":", 1)
    backend = backend.lower().strip()
    if backend == "duckdb":
        return DuckDBResultSink(target, run_id, table_prefix)
    if backend == "snowflake":
        return SnowflakeResultSink(target, run_id, table_prefix)
    if backend == "iceberg":
        return IcebergResultSink(target, run_id, table_prefix)
    raise ValueError(
        f"unknown result-sink backend '{backend}'. Known: duckdb, snowflake, iceberg"
    )
