"""result.json: the one complete record of a case run.

Every other view of a run -- the console findings, the per-column CSV, and
later the HTML report and ``rowparity show`` -- can be rendered from this file
without the ComparisonResult or another trip to the warehouse. That is what
lets a scheduled run publish it and a data engineer read it days later.

Layout written by ``write_case_outputs``::

    <out_dir>/<case>/result.json
    <out_dir>/<case>/columns.csv

Bump ``SCHEMA_VERSION`` on any change a reader would have to branch on.
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from . import __version__
from .compare import ComparisonResult
from .findings import summary_dict
from .report import CSV_FIELDS, to_column_rows
from .run_report import case_to_dict

SCHEMA_VERSION = 1


def safe_name(name: str) -> str:
    """Case names are author-supplied and end up as paths."""
    return re.sub(r"[^A-Za-z0-9._-]", "_", name) or "case"


# The SQL a side ran is kept in the record so a report can show exactly what
# Presto received, bindings and all. A few shapes are enormous; past this size
# only the fingerprint and the path are kept.
MAX_SQL_BYTES = 256 * 1024


def _resolved_sql(case, spec: Dict[str, Any]) -> Optional[str]:
    """The SQL a side would run, with every ${placeholder} filled in."""
    if not isinstance(spec, dict) or not (spec.get("query") or spec.get("query_file")):
        return None
    from .params import merge_side_vars
    from .sources import resolve_query

    base_dir = os.path.dirname(getattr(case, "source_file", "") or "") or "."
    try:
        return resolve_query(spec, base_dir, merge_side_vars(spec.get("vars"), case.variables))
    except Exception:
        return None


def case_meta(case) -> Dict[str, Any]:
    """What was run: the case definition, not its outcome."""
    sources = {}
    for side in ("expected", "actual"):
        spec = getattr(case, side, None)
        if not isinstance(spec, dict):
            continue
        sql = _resolved_sql(case, spec)
        sql_bytes = len(sql.encode("utf-8")) if sql else 0
        sources[side] = {
            "label": getattr(case, f"{side}_label", side),
            "type": spec.get("type"),
            "table": spec.get("table"),
            "query_file": spec.get("query_file"),
            "sql_sha256": hashlib.sha256(sql.encode("utf-8")).hexdigest() if sql else None,
            "sql_bytes": sql_bytes,
            "sql": sql if sql and sql_bytes <= MAX_SQL_BYTES else None,
        }
    return {
        "source_file": getattr(case, "source_file", ""),
        "description": getattr(case, "description", ""),
        "tags": list(getattr(case, "tags", []) or []),
        "engine": getattr(case, "engine", None),
        "variables": dict(getattr(case, "variables", {}) or {}),
        "sources": sources,
    }


def run_meta(
    run_id: str, params: Optional[Dict[str, Any]] = None, run_date: Optional[str] = None
) -> Dict[str, Any]:
    now = datetime.now(tz=timezone.utc)
    return {
        "run_id": run_id,
        "run_date": run_date or now.strftime("%Y-%m-%d"),
        "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rowparity_version": __version__,
        "params": dict(params or {}),
        # Set by Jenkins; Airflow tasks can export the same names.
        "git_commit": os.environ.get("GIT_COMMIT"),
        "build_url": os.environ.get("BUILD_URL"),
    }


def build_result(
    name: str,
    result: ComparisonResult,
    *,
    case=None,
    run: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """The complete, JSON-ready record of one case run."""
    detail = case_to_dict(name, result)
    summary = summary_dict(name, result)
    return {
        "schema_version": SCHEMA_VERSION,
        **detail,
        **summary,  # status (incl. WITHIN_TOLERANCE), ratios, findings, notes
        "passed": result.passed,
        "run": run or {},
        "definition": case_meta(case) if case is not None else {},
    }


def build_error(
    name: str, exc: BaseException, *, case=None, run: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """A run that produced no verdict still overwrites the previous one.

    Otherwise the last published result would keep showing yesterday's
    differences as if they were today's.
    """
    return {
        "schema_version": SCHEMA_VERSION,
        "case": name,
        "status": "ERROR",
        "passed": False,
        "error_type": type(exc).__name__,
        "error": str(exc),
        "run": run or {},
        "definition": case_meta(case) if case is not None else {},
    }


def write_case_outputs(
    out_dir: str, record: Dict[str, Any], result: Optional[ComparisonResult] = None
) -> List[str]:
    """Write result.json (and columns.csv when there is a result) for one case."""
    case_dir = os.path.join(out_dir, safe_name(record["case"]))
    os.makedirs(case_dir, exist_ok=True)
    written = []

    path = os.path.join(case_dir, "result.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(record, fh, indent=2, default=str)
    written.append(path)

    if result is not None:
        path = os.path.join(case_dir, "columns.csv")
        with open(path, "w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(to_column_rows(result, record["case"]))
        written.append(path)
    return written


def load_result(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as fh:
        record = json.load(fh)
    version = record.get("schema_version")
    if version != SCHEMA_VERSION:
        raise ValueError(
            f"{path}: result.json schema_version {version!r} is not supported by this "
            f"rowparity (expects {SCHEMA_VERSION}); upgrade rowparity to read it."
        )
    return record
