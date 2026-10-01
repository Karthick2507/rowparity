"""Publish one test's run: files for people, Parquet for Presto.

Layout under DEST (``s3://bucket/prefix`` or a local directory)::

    runs/<test>/<run_date>_<run_id>/result.json      every run, kept until S3 lifecycle expires it
    runs/<test>/<run_date>_<run_id>/columns.csv
    runs/<test>/<run_date>_<run_id>/view.sql
    runs/<test>/<run_date>_<run_id>/report.html
    latest/<test>/...                                 the same files for the newest run
    _tables/diffs/case_name=<test>/run_date=<d>/run_id=<id>/part-0.parquet
    _tables/run_summary/case_name=<test>/run_date=<d>/run_id=<id>/part-0.parquet

Everything that expires sits under a shared top-level prefix (``runs/``,
``_tables/``, ``_runs/``) because S3 lifecycle rules match literal prefixes:
one rule per prefix covers every test, while ``latest/`` is never expired.

The run directory is written before ``latest/``, so a failed upload never leaves
``latest/`` describing a run that was not recorded. Partitions are keyed by
run_id as well as date: a rerun adds a run, it never replaces one.
"""
from __future__ import annotations

import csv
import io
import json
from datetime import date, datetime, time, timezone
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple

import pyarrow as pa
import pyarrow.fs as pafs
import pyarrow.parquet as pq

from . import presto_sql
from .compare import ComparisonResult
from .findings import classify_diff_rows
from .report import CSV_FIELDS, to_column_rows
from .result_json import safe_name

DIFFS_SCHEMA = pa.schema([
    ("diff_kind", pa.string()),
    ("finding_id", pa.int32()),
    ("pair_id", pa.int64()),
    ("key_values", pa.map_(pa.string(), pa.string())),
    ("changed_columns", pa.list_(pa.string())),
    ("expected_values", pa.map_(pa.string(), pa.string())),
    ("actual_values", pa.map_(pa.string(), pa.string())),
])

SUMMARY_SCHEMA = pa.schema([
    ("run_ts", pa.timestamp("us")),
    ("status", pa.string()),
    ("passed", pa.bool_()),
    ("expected_rows", pa.int64()),
    ("actual_rows", pa.int64()),
    ("missing", pa.int64()),
    ("added", pa.int64()),
    ("changed", pa.int64()),
    ("total_differences", pa.int64()),
    ("diff_ratio", pa.float64()),
    ("max_diff_ratio", pa.float64()),
    ("keys", pa.list_(pa.string())),
    ("keys_inferred", pa.bool_()),
    ("finding_count", pa.int32()),
    ("top_finding", pa.string()),
    ("diff_rows_stored", pa.int64()),
    ("diff_rows_complete", pa.bool_()),
    ("expected_sql_sha256", pa.string()),
    ("actual_sql_sha256", pa.string()),
    ("error", pa.string()),
    ("result_uri", pa.string()),
    ("diffs_query", pa.string()),
])


class PublishError(RuntimeError):
    pass


def _filesystem(dest: str) -> Tuple[pafs.FileSystem, str]:
    import os

    if "://" not in dest:
        return pafs.LocalFileSystem(), os.path.abspath(dest)
    fs, path = pafs.FileSystem.from_uri(dest)
    return fs, path.rstrip("/")


def _uri(dest: str, relative: str) -> str:
    return dest.rstrip("/") + "/" + relative


def value_text(value: Any) -> Optional[str]:
    """A value as the string Presto's try_cast / json_parse will read back."""
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            return value.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f UTC")
        return value.strftime("%Y-%m-%d %H:%M:%S.%f")
    if isinstance(value, (date, time)):
        return value.isoformat()
    if isinstance(value, (list, tuple, dict)):
        return json.dumps(value, default=str, sort_keys=True)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, Decimal):
        return format(value, "f")
    return str(value)


def _values(row: Optional[dict]) -> Optional[List[Tuple[str, Optional[str]]]]:
    if row is None:
        return None
    return [(k, value_text(v)) for k, v in row.items()]


def diffs_table(result: ComparisonResult) -> pa.Table:
    keys = list(result.keys or [])
    columns: Dict[str, list] = {name: [] for name in DIFFS_SCHEMA.names}
    for diff, (kind, finding_id, pair_id) in zip(result.diff_rows, classify_diff_rows(result)):
        row = diff.expected_row if diff.expected_row is not None else diff.actual_row
        columns["diff_kind"].append(kind)
        columns["finding_id"].append(finding_id)
        columns["pair_id"].append(pair_id)
        columns["key_values"].append(
            [(k, value_text(row.get(k))) for k in keys] if keys and row is not None else None
        )
        columns["changed_columns"].append(
            sorted(c.column for c in diff.columns) if diff.kind == "changed" else []
        )
        columns["expected_values"].append(_values(diff.expected_row))
        columns["actual_values"].append(_values(diff.actual_row))
    return pa.table(columns, schema=DIFFS_SCHEMA)


def _summary_table(record: dict, result_uri: str, diffs_query: Optional[str]) -> pa.Table:
    findings = record.get("findings") or []
    definition = (record.get("definition") or {}).get("sources") or {}
    diffs = record.get("diffs") or {}
    run = record.get("run") or {}
    run_ts = run.get("generated_at")
    row = {
        "run_ts": datetime.strptime(run_ts, "%Y-%m-%dT%H:%M:%SZ") if run_ts else None,
        "status": record.get("status"),
        "passed": record.get("passed"),
        "expected_rows": record.get("expected_rows"),
        "actual_rows": record.get("actual_rows"),
        "missing": record.get("missing"),
        "added": record.get("added"),
        "changed": record.get("changed"),
        "total_differences": record.get("total_differences"),
        "diff_ratio": record.get("diff_ratio"),
        "max_diff_ratio": record.get("max_diff_ratio"),
        "keys": record.get("keys"),
        "keys_inferred": record.get("keys_inferred"),
        "finding_count": len(findings),
        "top_finding": findings[0]["title"] if findings else None,
        "diff_rows_stored": diffs.get("stored_rows"),
        "diff_rows_complete": diffs.get("complete"),
        "expected_sql_sha256": (definition.get("expected") or {}).get("sql_sha256"),
        "actual_sql_sha256": (definition.get("actual") or {}).get("sql_sha256"),
        "error": record.get("error"),
        "result_uri": result_uri,
        "diffs_query": diffs_query,
    }
    return pa.Table.from_pylist([row], schema=SUMMARY_SCHEMA)


def _write_bytes(fs: pafs.FileSystem, path: str, data: bytes) -> None:
    parent = path.rsplit("/", 1)[0]
    try:
        fs.create_dir(parent, recursive=True)
    except (OSError, NotImplementedError):
        pass  # object stores have no directories
    with fs.open_output_stream(path) as out:
        out.write(data)


def _parquet_bytes(table: pa.Table) -> bytes:
    sink = pa.BufferOutputStream()
    pq.write_table(table, sink)
    return sink.getvalue().to_pybytes()


def _columns_csv(result: ComparisonResult, name: str) -> bytes:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=CSV_FIELDS)
    writer.writeheader()
    writer.writerows(to_column_rows(result, name))
    return buf.getvalue().encode("utf-8")


def attach_diffs(record: dict, result: ComparisonResult, run_id: str) -> None:
    """Add where this run's rows can be queried to its record, before it is written."""
    name = safe_name(record["case"])  # the case_name partition value
    stored = len(result.diff_rows)
    record["keys_inferred"] = result.keys_inferred
    record["diffs"] = {
        "table": f"{presto_sql.tables_schema()}.diffs",
        "view": f"{presto_sql.views_schema()}.{presto_sql.view_name(name)}",
        "query": presto_sql.diffs_query(name, run_id) if result.total_differences else None,
        "stored_rows": stored,
        "complete": stored == result.total_differences and not result.diff_rows_truncated,
        "view_sql": presto_sql.diffs_view_sql(
            name, result.keys, result.compared_columns,
            result.expected_schema, result.actual_schema,
            result.expected_label, result.actual_label,
        ),
    }


def publish(
    dest: str,
    record: dict,
    result: Optional[ComparisonResult],
    run_id: str,
    run_date: str,
) -> Dict[str, str]:
    """Write one test's run. Raises PublishError if anything cannot be written."""
    name = safe_name(record["case"])
    fs, root = _filesystem(dest)
    run_rel = f"runs/{name}/{run_date}_{run_id}"
    partition = f"case_name={name}/run_date={run_date}/run_id={run_id}"

    from .html_report import render_test

    files: Dict[str, bytes] = {
        "result.json": json.dumps(record, indent=2, default=str).encode("utf-8"),
        "report.html": render_test(json.loads(json.dumps(record, default=str))).encode("utf-8"),
    }
    diffs_query = None
    if result is not None:
        files["columns.csv"] = _columns_csv(result, record["case"])
        view_sql = (record.get("diffs") or {}).get("view_sql")
        if view_sql:
            files["view.sql"] = (view_sql + ";\n").encode("utf-8")
        diffs_query = (record.get("diffs") or {}).get("query")

    try:
        for filename, data in files.items():
            _write_bytes(fs, f"{root}/{run_rel}/{filename}", data)
        if result is not None and result.diff_rows:
            _write_bytes(
                fs, f"{root}/_tables/diffs/{partition}/part-0.parquet",
                _parquet_bytes(diffs_table(result)),
            )
        result_uri = _uri(dest, f"{run_rel}/result.json")
        _write_bytes(
            fs, f"{root}/_tables/run_summary/{partition}/part-0.parquet",
            _parquet_bytes(_summary_table(record, result_uri, diffs_query)),
        )
        latest = f"{root}/latest/{name}"
        try:
            fs.delete_dir_contents(latest, missing_dir_ok=True)
        except (OSError, NotImplementedError):
            pass
        for filename, data in files.items():
            _write_bytes(fs, f"{latest}/{filename}", data)
    except (OSError, pa.ArrowException) as exc:
        raise PublishError(f"could not publish {record['case']} to {dest}: {exc}") from exc

    return {"run": _uri(dest, run_rel), "latest": _uri(dest, f"latest/{name}"), "result": result_uri}
