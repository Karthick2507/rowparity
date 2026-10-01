"""A suite: many SQL pairs, one shared config, no per-query YAML.

Writing a case file per query does not survive hundreds of queries, and almost
everything in those files would be the same: which table each side reads, the
compare policy, the labels. A suite states that once and turns every SQL file
under ``sql_dir`` into a case::

    rowparity.yaml
    sql/
      daily_impressions.sql            one file; ${schema} filled per side
      revenue_by_deal/
        expected.sql                   the two sides need different SQL
        actual.sql
        case.yaml                      optional per-query overrides
      clicks_by_device.yaml            optional overrides for a single-file query

``rowparity.yaml``::

    suite:
      expected_label: Hoover
      actual_label: Hoover++
      expected: {type: trino, vars: {schema: mrm_log_flat.default}}
      actual:   {type: trino, vars: {schema: etl.public_test1}}
      compare:
        float_tolerance: 0.0001
        max_diff_ratio: 0.0001
    vars: {}                           # suite-wide ${placeholders}

Case names are the path under ``sql_dir`` without the extension, with ``/``
written as ``.`` (``insight_plus/f_demand.sql`` -> ``insight_plus.f_demand``).
Overrides are shallow-merged, with ``compare`` merged key by key. Relative paths
inside an override (a drilldown ``query_file``, say) resolve from the suite
file's directory, the same base every generated case uses.
"""
from __future__ import annotations

import os
import zlib
from typing import Any, Dict, List, Optional

import yaml

PAIR_FILES = ("expected.sql", "actual.sql")
OVERRIDE_FILE = "case.yaml"

# Keys a suite passes to every case, and keys an override may set.
_SHARED_KEYS = (
    "expected_label", "actual_label", "compare", "tags", "engine", "row_summary",
)
_OVERRIDE_KEYS = set(_SHARED_KEYS) | {
    "description", "enabled", "group", "drilldown", "vars", "expected", "actual",
}


def is_suite_doc(doc: Any) -> bool:
    return isinstance(doc, dict) and isinstance(doc.get("suite"), dict)


def group_of(name: str, groups: int) -> int:
    """A stable group in ``[0, groups)`` for spreading cases across days.

    crc32 rather than hash(): Python salts str hashes per process, and a case
    must land in the same group on every run and every machine.
    """
    return zlib.crc32(name.encode("utf-8")) % groups


def sql_dir_of(path: str, doc: dict) -> str:
    base = os.path.dirname(os.path.abspath(path))
    return os.path.normpath(os.path.join(base, doc["suite"].get("sql_dir", "sql")))


def _load_override(path: str) -> Dict[str, Any]:
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        doc = yaml.safe_load(fh) or {}
    if not isinstance(doc, dict):
        raise ValueError(f"{path}: override must be a mapping")
    unknown = set(doc) - _OVERRIDE_KEYS
    if unknown:
        raise ValueError(
            f"{path}: unknown override key(s) {sorted(unknown)}; allowed: {sorted(_OVERRIDE_KEYS)}"
        )
    return doc


def _side(shared: Dict[str, Any], override: Optional[Dict[str, Any]], query_file: str) -> dict:
    spec = dict(shared or {})
    if override:
        vars_ = {**(spec.get("vars") or {}), **(override.get("vars") or {})}
        spec.update(override)
        if vars_:
            spec["vars"] = vars_
    spec["query_file"] = query_file
    return spec


def _raw_case(
    name: str,
    suite: Dict[str, Any],
    suite_dir: str,
    expected_sql: str,
    actual_sql: str,
    override: Dict[str, Any],
    override_path: str,
) -> Dict[str, Any]:
    for side in ("expected", "actual"):
        if not isinstance(suite.get(side), dict) or "type" not in suite[side]:
            raise ValueError(f"suite: '{side}' needs at least a 'type'")

    raw: Dict[str, Any] = {"name": name}
    for key in _SHARED_KEYS:
        if key in suite:
            raw[key] = suite[key]
    raw["expected"] = _side(
        suite["expected"], override.get("expected"), os.path.relpath(expected_sql, suite_dir)
    )
    raw["actual"] = _side(
        suite["actual"], override.get("actual"), os.path.relpath(actual_sql, suite_dir)
    )

    for key, value in override.items():
        if key in ("expected", "actual"):
            continue
        if key == "compare":
            raw["compare"] = {**(raw.get("compare") or {}), **(value or {})}
        elif key == "tags":
            raw["tags"] = list(raw.get("tags") or []) + list(value or [])
        else:
            raw[key] = value
    raw["_override_file"] = override_path if override else ""
    return raw


def discover_raw_cases(path: str, doc: dict) -> List[Dict[str, Any]]:
    """Raw case dicts for every query under the suite's sql_dir, sorted by name."""
    suite = doc["suite"]
    suite_dir = os.path.dirname(os.path.abspath(path))
    sql_dir = sql_dir_of(path, doc)
    if not os.path.isdir(sql_dir):
        raise ValueError(f"{path}: sql_dir {sql_dir} does not exist")

    raws: List[Dict[str, Any]] = []
    for root, dirs, files in os.walk(sql_dir):
        dirs.sort()
        rel = os.path.relpath(root, sql_dir)
        present = [f for f in PAIR_FILES if f in files]

        if present:
            if len(present) == 1:
                missing = next(f for f in PAIR_FILES if f not in files)
                raise ValueError(f"{root}: has {present[0]} but no {missing}")
            if rel == ".":
                raise ValueError(
                    f"{root}: expected.sql/actual.sql must be in a folder named after the query"
                )
            others = sorted(f for f in files if f.endswith(".sql") and f not in PAIR_FILES)
            if others or dirs:
                raise ValueError(
                    f"{root}: a pair folder holds only expected.sql, actual.sql and case.yaml; "
                    f"found {others + sorted(dirs)}"
                )
            override_path = os.path.join(root, OVERRIDE_FILE)
            raws.append(
                _raw_case(
                    rel.replace(os.sep, "."),
                    suite,
                    suite_dir,
                    os.path.join(root, "expected.sql"),
                    os.path.join(root, "actual.sql"),
                    _load_override(override_path),
                    override_path,
                )
            )
            dirs[:] = []
            continue

        for filename in sorted(files):
            if not filename.endswith(".sql"):
                continue
            stem = filename[: -len(".sql")]
            name = stem if rel == "." else f"{rel.replace(os.sep, '.')}.{stem}"
            sql_path = os.path.join(root, filename)
            override_path = os.path.join(root, f"{stem}.yaml")
            raws.append(
                _raw_case(
                    name, suite, suite_dir, sql_path, sql_path,
                    _load_override(override_path), override_path,
                )
            )

    names = [r["name"] for r in raws]
    dupes = sorted({n for n in names if names.count(n) > 1})
    if dupes:
        raise ValueError(f"{path}: more than one query is named {dupes}")
    return sorted(raws, key=lambda r: r["name"])
