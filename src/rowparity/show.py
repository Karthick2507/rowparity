"""``rowparity show``: read a published test run back, without rerunning anything.

    rowparity show clicks_by_device                  latest run, as the console showed it
    rowparity show clicks_by_device --run-id ID      one specific run
    rowparity show clicks_by_device --runs           every kept run of the test
    rowparity show clicks_by_device --html out.html  the report page, to open locally

Reads from --publish DEST or $ROWPARITY_PUBLISH_URI, S3 or a local directory.
"""
from __future__ import annotations

import json
from typing import Any, Dict, List

import pyarrow.fs as pafs

from .publish import _filesystem, _uri
from .result_json import safe_name


class ShowError(RuntimeError):
    pass


def _read_json(fs: pafs.FileSystem, path: str) -> Dict[str, Any]:
    try:
        with fs.open_input_stream(path) as fh:
            return json.loads(fh.read().decode("utf-8"))
    except FileNotFoundError as exc:
        raise ShowError(f"no result at {path}") from exc
    except (OSError, ValueError) as exc:
        raise ShowError(f"could not read {path}: {exc}") from exc


def list_runs(dest: str, test: str) -> List[Dict[str, Any]]:
    """Kept runs of one test, newest first."""
    fs, root = _filesystem(dest)
    base = f"{root}/runs/{safe_name(test)}"
    infos = fs.get_file_info(pafs.FileSelector(base, allow_not_found=True))
    runs = []
    for info in infos:
        if info.type != pafs.FileType.Directory:
            continue
        folder = info.path.rstrip("/").rsplit("/", 1)[-1]
        run_date, _, run_id = folder.partition("_")
        record = _read_json(fs, f"{info.path}/result.json")
        runs.append({
            "run_date": run_date,
            "run_id": run_id,
            "generated_at": (record.get("run") or {}).get("generated_at") or "",
            "status": record.get("status"),
            "total_differences": record.get("total_differences"),
            "location": _uri(dest, f"runs/{safe_name(test)}/{folder}"),
        })
    return sorted(runs, key=lambda r: (r["generated_at"], r["run_id"]), reverse=True)


def load_record(dest: str, test: str, run_id: str = None) -> Dict[str, Any]:
    fs, root = _filesystem(dest)
    name = safe_name(test)
    if not run_id:
        return _read_json(fs, f"{root}/latest/{name}/result.json")
    for run in list_runs(dest, test):
        if run["run_id"] == run_id:
            return _read_json(fs, f"{root}/runs/{name}/{run['run_date']}_{run_id}/result.json")
    raise ShowError(f"no kept run {run_id} for {test} under {dest}")


def render_runs(test: str, runs: List[Dict[str, Any]]) -> str:
    if not runs:
        return f"{test}: no kept runs"
    lines = [f"{test}: {len(runs)} kept run(s), newest first"]
    for run in runs:
        diffs = run["total_differences"]
        size = "" if diffs is None else f"{int(diffs):,} differ"
        lines.append(
            f"  {run['run_date']}  {run['run_id']:<40}  {(run['status'] or '').replace('_', ' '):<16}  {size}"
        )
    return "\n".join(lines)
