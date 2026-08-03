"""Command-line entry point: ``rowparity run <path>``.

Runs every case found at a file or directory, prints a readable result for each,
optionally writes JSON + Markdown reports, and exits non-zero if any case differs
— which is exactly what a CI stage needs.
"""
from __future__ import annotations

import argparse
import sys
import uuid
from typing import List, Tuple

from .cases import discover_cases
from .compare import ComparisonResult
from .report import render_console, write_reports
from .report_html import render_report_from_sink
from .result_sink import make_result_sink


def _run(args) -> int:
    cases = discover_cases(args.path)
    if not cases:
        print(f"No cases found at {args.path}", file=sys.stderr)
        return 2

    run_id = str(uuid.uuid4())

    result_sink = None
    if args.result_sink:
        try:
            result_sink = make_result_sink(args.result_sink, run_id,
                                           table_prefix=args.result_sink_prefix)
            print(f"Result sink: {args.result_sink}  run_id={run_id}")
        except Exception as exc:
            print(f"WARNING: could not initialise result sink: {exc}", file=sys.stderr)

    results: List[Tuple[str, ComparisonResult]] = []
    only = set(args.select) if args.select else None
    failures = 0
    xfail_confirmed = 0
    xfail_unexpected_pass = 0
    for case in cases:
        if only and case.name not in only:
            continue
        is_xfail = "xfail" in case.tags
        try:
            result = case.run(result_sink=result_sink)
        except Exception as exc:  # a source/config error should fail the case, not crash the run
            print(f"Case '{case.name}': ERROR - {type(exc).__name__}: {exc}\n")
            failures += 1
            continue
        results.append((case.name, result))
        print(render_console(result, case.name))
        if is_xfail:
            if result.equivalent:
                print("  [XFAIL-UNEXPECTED-PASS] case is tagged xfail but tables were equivalent")
                xfail_unexpected_pass += 1
                failures += 1
            else:
                print("  [XFAIL] expected failure confirmed")
                xfail_confirmed += 1
        elif not result.equivalent:
            failures += 1
        print()

    if result_sink:
        result_sink.close()

    if args.json or args.md:
        write_reports(results, json_path=args.json, md_path=args.md)

    total = len(results)
    n_xfail = xfail_confirmed + xfail_unexpected_pass
    passed = sum(1 for _, r in results if r.equivalent) - xfail_unexpected_pass
    summary = f"Summary: {passed}/{total - n_xfail} equivalent"
    if xfail_confirmed:
        summary += f", {xfail_confirmed} xfail"
    if xfail_unexpected_pass:
        summary += f", {xfail_unexpected_pass} xfail-unexpected-pass"
    if failures:
        summary += f", {failures} failing"
    print(summary)
    return 1 if failures else 0


def _report(args) -> int:
    try:
        html = render_report_from_sink(args.result_sink, table_prefix=args.result_sink_prefix, days=args.days)
    except Exception as exc:
        print(f"ERROR: could not render report: {exc}", file=sys.stderr)
        return 2
    with open(args.html, "w", encoding="utf-8") as fh:
        fh.write(html)
    print(f"Wrote {args.html} ({args.days}-day window from {args.result_sink})")
    return 0


def _list(args) -> int:
    for case in discover_cases(args.path):
        tags = f" [{', '.join(case.tags)}]" if case.tags else ""
        print(f"{case.name}{tags}  ({case.source_file})")
        if case.description:
            print(f"    {case.description}")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="rowparity", description="Fingerprint-based data comparison for CI.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    run_p = sub.add_parser("run", help="run cases and exit non-zero on any difference")
    run_p.add_argument("path", help="a case file or a directory of *.yml/*.yaml cases")
    run_p.add_argument("--select", nargs="*", help="only run these case names")
    run_p.add_argument("--json", help="write a JSON summary here")
    run_p.add_argument("--md", help="write a Markdown report here")
    run_p.add_argument(
        "--result-sink", dest="result_sink", metavar="BACKEND:TARGET",
        help="persist diff results to a store, e.g. duckdb:./results.duckdb  "
             "snowflake:MY_DB.QA_SCHEMA  iceberg:qa_results",
    )
    run_p.add_argument(
        "--result-sink-prefix", dest="result_sink_prefix", default="rowparity",
        metavar="PREFIX",
        help="table name prefix for result sink tables (default: rowparity → "
             "rowparity_run_summary, rowparity_run_diffs)",
    )
    run_p.set_defaults(func=_run)

    list_p = sub.add_parser("list", help="list discovered cases")
    list_p.add_argument("path")
    list_p.set_defaults(func=_list)

    report_p = sub.add_parser(
        "report", help="render a historical HTML report from a result sink's run history"
    )
    report_p.add_argument(
        "--result-sink", dest="result_sink", required=True, metavar="BACKEND:TARGET",
        help="where run history was persisted by `rowparity run --result-sink ...`, "
             "e.g. duckdb:./results.duckdb  snowflake:MY_DB.QA_SCHEMA",
    )
    report_p.add_argument(
        "--result-sink-prefix", dest="result_sink_prefix", default="rowparity",
        metavar="PREFIX", help="must match the prefix used when writing (default: rowparity)",
    )
    report_p.add_argument("--days", type=int, default=21, metavar="N", help="history window (default: 21)")
    report_p.add_argument("--html", required=True, metavar="FILE", help="write the HTML report here")
    report_p.set_defaults(func=_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
