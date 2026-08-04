"""schemaparity CLI — column coverage mapping.

Usage::

    schemaparity coverage <path>              # run all coverage_check cases
    schemaparity coverage <path> --json out.json
    schemaparity coverage <path> --csv  out.csv
    schemaparity list <path>                  # list discovered cases
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from typing import List, Tuple

from .schema_mapper import CoverageCase, CoverageResult, load_coverage_cases


# ---------------------------------------------------------------------------
# Console rendering
# ---------------------------------------------------------------------------

def _render_console(result: CoverageResult, case_name: str) -> str:
    n_usage = len(result.mapped) + len(result.unmapped_usage)
    status = "FULL COVERAGE" if result.equivalent else "GAPS FOUND"
    lines = [
        f"Coverage '{case_name}': [{status}]  source={result.source_label}"
        f"  usage={n_usage}  mapped={len(result.mapped)}  unmapped={len(result.unmapped_usage)}",
    ]

    if result.mapped:
        lines.append(f"\n  MAPPED ({len(result.mapped)}/{n_usage})")
        for m in result.mapped:
            desc = f'  "{m.description}"' if m.description else ""
            lines.append(f"    {m.usage_name:<30} \u2192  {m.source_name:<30} {m.source_type}{desc}")

    if result.unmapped_usage:
        lines.append(f"\n  UNMAPPED ({len(result.unmapped_usage)}) \u2014 not found in source table")
        for col in result.unmapped_usage:
            lines.append(f"    {col}")

    if result.unreferenced_source:
        lines.append(
            f"\n  SOURCE columns not referenced ({len(result.unreferenced_source)}"
            f" of {result.total_source_columns})"
        )
        for col in result.unreferenced_source:
            lines.append(f"    {col}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# JSON serialisation
# ---------------------------------------------------------------------------

def _to_json_record(case_name: str, result: CoverageResult) -> dict:
    return {
        "case": case_name,
        "source": result.source_label,
        "total_source_columns": result.total_source_columns,
        "equivalent": result.equivalent,
        "mapped_count": len(result.mapped),
        "unmapped_count": len(result.unmapped_usage),
        "mapped": [
            {
                "usage_name": m.usage_name,
                "source_name": m.source_name,
                "source_type": m.source_type,
                "description": m.description,
            }
            for m in result.mapped
        ],
        "unmapped_usage": result.unmapped_usage,
        "unreferenced_source": result.unreferenced_source,
    }


# ---------------------------------------------------------------------------
# CSV output — one row per usage column (mapped or not)
# ---------------------------------------------------------------------------

def _write_csv(path: str, pairs: List[Tuple[str, CoverageResult]]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["case", "usage_column", "mapped", "source_column", "source_type", "description"])
        for case_name, result in pairs:
            for m in result.mapped:
                writer.writerow([case_name, m.usage_name, True, m.source_name, m.source_type, m.description])
            for col in result.unmapped_usage:
                writer.writerow([case_name, col, False, "", "", ""])


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _cmd_coverage(args) -> int:
    cases = load_coverage_cases(args.path)
    if not cases:
        print(f"No coverage_check cases found at {args.path}", file=sys.stderr)
        return 2

    pairs: List[Tuple[str, CoverageResult]] = []
    failures = 0

    for case in cases:
        try:
            result = case.run()
        except Exception as exc:
            print(f"Case '{case.name}': ERROR — {type(exc).__name__}: {exc}\n")
            failures += 1
            continue
        pairs.append((case.name, result))
        print(_render_console(result, case.name))
        print()
        if not result.equivalent:
            failures += 1

    n = len(pairs)
    passing = sum(1 for _, r in pairs if r.equivalent)
    print(f"Summary: {passing}/{n} full coverage, {failures} with gaps")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump([_to_json_record(name, r) for name, r in pairs], fh, indent=2)
        print(f"JSON written to {args.json}")

    if args.csv:
        _write_csv(args.csv, pairs)
        print(f"CSV written to {args.csv}")

    return 1 if failures else 0


def _cmd_list(args) -> int:
    cases = load_coverage_cases(args.path)
    if not cases:
        print(f"No coverage_check cases found at {args.path}", file=sys.stderr)
        return 2
    for case in cases:
        tags = f"  [{', '.join(case.tags)}]" if case.tags else ""
        src = case.source.get("table") or case.source.get("type", "?")
        print(f"{case.name}{tags}  source={src}  usage_columns={len(case.usage_columns)}"
              f"  ({case.source_file})")
        if case.description:
            print(f"  {case.description}")
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main(argv=None) -> None:
    parser = argparse.ArgumentParser(
        prog="schemaparity",
        description="Column coverage mapping — usage columns against a source table schema.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_cov = sub.add_parser("coverage", help="Run coverage_check cases")
    p_cov.add_argument("path", help="A .yaml file or directory of coverage_check cases")
    p_cov.add_argument("--json", metavar="FILE", help="Write JSON output to FILE")
    p_cov.add_argument("--csv", metavar="FILE", help="Write CSV output to FILE")
    p_cov.set_defaults(func=_cmd_coverage)

    p_list = sub.add_parser("list", help="List discovered coverage_check cases")
    p_list.add_argument("path", help="A .yaml file or directory")
    p_list.set_defaults(func=_cmd_list)

    args = parser.parse_args(argv)
    sys.exit(args.func(args))
