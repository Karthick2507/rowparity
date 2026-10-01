"""Command-line entry point: ``rowparity run <path>``.

Runs every case found at a file or directory, prints a readable result for each,
optionally writes JSON + Markdown reports, and exits non-zero if any case differs
— which is exactly what a CI stage needs.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import uuid
from typing import List, Optional, Tuple

import yaml

from . import progress, result_json
from .cases import discover_cases
from .compare import ComparisonResult
from .findings import render_case, summary_dict
from .params import ParamError, merge_side_vars, parse_cli_params
from .report import render_console, write_csv_reports, write_reports
from .report_html import render_report_from_sink
from .result_sink import make_result_sink
from .run_report import write_run_report
from .sources import SourceError, resolve_query
from .suite import group_of

# Everything case loading can fail with. A malformed YAML raises ValueError out
# of cases._build_case, an unreadable one OSError, a syntactically broken one
# yaml.YAMLError -- none of which are ParamError, so all three used to escape
# both entry points as a bare traceback and exit 1 (Python's default for an
# uncaught exception) instead of the documented 2. Exit 2 is the contract CI
# depends on: "the tool could not run" must stay distinct from "the data
# disagrees", and a loading failure is squarely the former.
_LOAD_ERRORS = (ParamError, ValueError, SourceError, yaml.YAMLError, OSError)


def _load_cases(path, cli_params, *, resolve_queries=True):
    """Discover cases, or print a clean error and return the exit code.

    Returns ``(cases, None)`` or ``(None, exit_code)``.
    """
    try:
        return discover_cases(path, cli_params, resolve_queries=resolve_queries), None
    except _LOAD_ERRORS as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return None, 2


def _parse_group(spec: Optional[str]) -> Optional[Tuple[int, int]]:
    """``--group 3/7`` -> (3, 7): run the cases whose group is 3 of 7."""
    if not spec:
        return None
    match = re.fullmatch(r"\s*(\d+)\s*/\s*(\d+)\s*", spec)
    if not match or int(match.group(2)) < 1 or int(match.group(1)) >= int(match.group(2)):
        raise ParamError(f"--group must be I/N with 0 <= I < N, e.g. 3/7; got {spec!r}")
    return int(match.group(1)), int(match.group(2))


def _select_cases(cases, args):
    """Apply --select, --group and enabled. Returns (cases, exit_code or None).

    Naming a case with --select runs it even if it is disabled or in another
    group: that is how one case gets re-run or debugged by hand.
    """
    try:
        group = _parse_group(getattr(args, "group", None))
        if args.select:
            names = {c.name for c in cases}
            unknown = [n for n in args.select if n not in names]
            if unknown:
                raise ParamError(f"--select names unknown case(s): {unknown}")
            wanted = set(args.select)
            return [c for c in cases if c.name in wanted], None
        include_disabled = getattr(args, "include_disabled", False)
        selected = []
        for case in cases:
            if not getattr(case, "enabled", True) and not include_disabled:
                continue
            if group is not None:
                index, groups = group
                in_group = (
                    case.group_in(groups) if hasattr(case, "group_in") else group_of(case.name, groups)
                )
                if in_group != index:
                    continue
            selected.append(case)
        return selected, None
    except (ParamError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return None, 2


def _run(args) -> int:
    progress.configure(
        enabled=not getattr(args, "quiet", False),
        heartbeat_seconds=getattr(args, "heartbeat", None),
    )

    try:
        cli_params = parse_cli_params(getattr(args, "param", None))
    except ParamError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    cases, failed = _load_cases(args.path, cli_params)
    if failed is not None:
        return failed
    if not cases:
        print(f"No cases found at {args.path}", file=sys.stderr)
        return 2

    cases, failed = _select_cases(cases, args)
    if failed is not None:
        return failed
    if not cases:
        print("No cases selected (check --group, or enabled: false in case overrides)")
        return 0

    run_id = getattr(args, "run_id", None) or str(uuid.uuid4())
    publish_to = getattr(args, "publish", None) or os.environ.get("ROWPARITY_PUBLISH_URI")
    run_date = getattr(args, "run_date", None)
    if run_date and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", run_date):
        print(f"ERROR: --run-date must be YYYY-MM-DD, got {run_date!r}", file=sys.stderr)
        return 2
    if not re.fullmatch(r"[A-Za-z0-9._:-]+", run_id):
        print(f"ERROR: --run-id may only use letters, digits and . _ : -; got {run_id!r}", file=sys.stderr)
        return 2

    result_sink = None
    if args.result_sink:
        try:
            result_sink = make_result_sink(args.result_sink, run_id,
                                           table_prefix=args.result_sink_prefix)
            print(f"Result sink: {args.result_sink}  run_id={run_id}")
        except Exception as exc:
            print(f"WARNING: could not initialise result sink: {exc}", file=sys.stderr)

    results: List[Tuple[str, ComparisonResult]] = []
    errors: List[Tuple[str, BaseException]] = []
    out_dir = getattr(args, "out", None)
    verbose = getattr(args, "verbose", False)
    run = result_json.run_meta(run_id, cli_params, run_date) if (out_dir or publish_to) else None
    records: List[Tuple[dict, "ComparisonResult | None"]] = []
    failures = 0
    errored = 0
    write_failed = False

    def _publish(record, result) -> bool:
        from .publish import PublishError, publish

        try:
            where = publish(publish_to, record, result, run_id, run["run_date"])
        except PublishError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return False
        print(f"  Published: {where['run']}/")
        return True

    xfail_confirmed = 0
    xfail_unexpected_pass = 0
    for case in cases:
        is_xfail = "xfail" in case.tags
        try:
            result = case.run(result_sink=result_sink)
        except Exception as exc:  # a source/config error should fail the case, not crash the run
            print(f"Case '{case.name}': ERROR - {type(exc).__name__}: {exc}")
            errors.append((case.name, exc))
            if out_dir or publish_to:
                record = result_json.build_error(case.name, exc, case=case, run=run)
                records.append((record, None))
                if publish_to and not _publish(record, None):
                    write_failed = True
            print()
            failures += 1
            errored += 1
            continue
        results.append((case.name, result))
        summary = summary_dict(case.name, result)
        if out_dir or publish_to:
            record = result_json.build_result(case.name, result, case=case, run=run)
            if publish_to and result.kind == "rows":
                from .publish import attach_diffs

                attach_diffs(record, result, run_id)
                summary["diffs"] = record["diffs"]
            summary["run"] = run
            records.append((record, result))
        if result.kind == "rows":
            print(render_case(summary))
            if verbose and result.total_differences:
                print()
                print(render_console(result, case.name))
        else:
            print(render_console(result, case.name))
        if is_xfail:
            if result.passed:
                print("  [XFAIL-UNEXPECTED-PASS] case is tagged xfail but tables were equivalent")
                xfail_unexpected_pass += 1
                failures += 1
            else:
                print("  [XFAIL] expected failure confirmed")
                xfail_confirmed += 1
        elif not result.passed:
            failures += 1
        if publish_to and not _publish(records[-1][0], result):
            write_failed = True
        print()

    if result_sink:
        result_sink.close()

    if out_dir:
        try:
            for record, result in records:
                result_json.write_case_outputs(out_dir, record, result)
            print(f"Wrote result.json for {len(records)} case(s) to {out_dir}/")
        except OSError as exc:
            # Unlike --html, this is the deliverable of a scheduled run: a run
            # that could not record its result must not look green.
            print(f"ERROR: could not write results to {out_dir}: {exc}", file=sys.stderr)
            write_failed = True

    if args.json or args.md or args.xlsx:
        write_reports(results, json_path=args.json, md_path=args.md, xlsx_path=args.xlsx)
    if getattr(args, "csv", None):
        paths = write_csv_reports(results, args.csv)
        print(f"Wrote {len(paths)} per-column CSV report(s) to {args.csv}/")
    if getattr(args, "html", None):
        try:
            write_run_report(args.html, results, errors, run_id=run_id)
            print(f"Wrote HTML report to {args.html}")
        except Exception as exc:
            # A report is an artifact of the run, not the run. Losing it
            # must not change the verdict the comparison already reached.
            print(f"WARNING: could not write HTML report: {exc}", file=sys.stderr)

    total = len(results)
    n_xfail = xfail_confirmed + xfail_unexpected_pass
    passed = sum(1 for _, r in results if r.passed) - xfail_unexpected_pass
    within = sum(1 for _, r in results if r.status == "WITHIN_TOLERANCE")
    summary_line = f"Summary: {passed}/{total - n_xfail} passed"
    if within:
        summary_line += f" ({within} within tolerance)"
    if xfail_confirmed:
        summary_line += f", {xfail_confirmed} xfail"
    if xfail_unexpected_pass:
        summary_line += f", {xfail_unexpected_pass} xfail-unexpected-pass"
    if failures:
        summary_line += f", {failures} failing"
    print(summary_line)
    if write_failed:
        return 2
    if errored:
        return 3  # a pair produced no verdict: worth retrying, unlike a difference
    return 1 if failures else 0



def _summarize(args) -> int:
    from .summarize import SummarizeError, summarize

    dest = args.publish or os.environ.get("ROWPARITY_PUBLISH_URI")
    if not dest:
        print("ERROR: summarize needs --publish DEST or $ROWPARITY_PUBLISH_URI", file=sys.stderr)
        return 2
    expected = None
    if args.expect:
        try:
            with (sys.stdin if args.expect == "-" else open(args.expect, encoding="utf-8")) as fh:
                text = fh.read()
        except OSError as exc:
            print(f"ERROR: could not read --expect {args.expect}: {exc}", file=sys.stderr)
            return 2
        text = text.strip()
        if text.startswith("["):  # `rowparity list --format json`
            expected = [row["name"] for row in json.loads(text)]
        else:  # `rowparity list --format names`
            expected = [line.strip() for line in text.splitlines() if line.strip()]
    try:
        _, text, code = summarize(
            dest, args.run_id, run_date=args.run_date, expected=expected, presto=args.presto
        )
    except SummarizeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(text)
    return code


def _compare_runs(args) -> int:
    from .compare_runs import CompareRunsError, run, to_csv

    dest = args.publish or os.environ.get("ROWPARITY_PUBLISH_URI")
    if not dest:
        print("ERROR: compare-runs needs --publish DEST or $ROWPARITY_PUBLISH_URI", file=sys.stderr)
        return 2
    cases = None
    if args.cases:
        try:
            with (sys.stdin if args.cases == "-" else open(args.cases, encoding="utf-8")) as fh:
                cases = [ln.strip() for ln in fh if ln.strip() and not ln.lstrip().startswith("#")]
        except OSError as exc:
            print(f"ERROR: could not read --cases {args.cases}: {exc}", file=sys.stderr)
            return 2
    try:
        runs, text, uri = run(dest, last=args.last, cases=cases, cases_file=args.cases,
                              publish_html=args.publish_html)
    except CompareRunsError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(text)
    if args.csv:
        try:
            with open(args.csv, "w", encoding="utf-8", newline="") as fh:
                fh.write(to_csv(runs))
        except OSError as exc:
            print(f"ERROR: could not write --csv {args.csv}: {exc}", file=sys.stderr)
            return 2
        print(f"\n  CSV:  {args.csv}")
    if uri:
        print(f"  Page: {uri}")
    return 0


def _show(args) -> int:
    from .findings import render_case
    from .html_report import render_test
    from .show import ShowError, list_runs, load_record, render_runs

    dest = args.publish or os.environ.get("ROWPARITY_PUBLISH_URI")
    if not dest:
        print("ERROR: show needs --publish DEST or $ROWPARITY_PUBLISH_URI", file=sys.stderr)
        return 2
    try:
        if args.runs:
            print(render_runs(args.test, list_runs(dest, args.test)))
            return 0
        record = load_record(dest, args.test, args.run_id)
    except ShowError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(record, indent=2, default=str))
    else:
        print(render_case(record, max_findings=10_000))
    if args.html:
        with open(args.html, "w", encoding="utf-8") as fh:
            fh.write(render_test(record))
        print(f"\nWrote {args.html}")
    return 0


def _param(args) -> int:
    """Resolve one param_queries value and print it, for a scheduler to pin."""
    import yaml as _yaml

    from .param_queries import resolve_param_queries

    try:
        cli_params = parse_cli_params(getattr(args, "param", None))
        with open(args.path, encoding="utf-8") as fh:
            doc = _yaml.safe_load(fh) or {}
        queries = doc.get("param_queries") or {}
        if args.name not in queries:
            print(
                f"ERROR: {args.path} has no param_queries entry named {args.name!r}"
                f" (has: {sorted(queries) or 'none'})",
                file=sys.stderr,
            )
            return 2
        values = resolve_param_queries(
            {args.name: queries[args.name]},
            {**(doc.get("vars") or {}), **cli_params},
            base_dir=os.path.dirname(args.path) or ".",
        )
    except _LOAD_ERRORS as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(values[args.name.lower()])
    return 0


def _ddl(args) -> int:
    from . import presto_sql

    dest = args.publish or os.environ.get("ROWPARITY_PUBLISH_URI") or "s3://<bucket>/<prefix>"
    views = presto_sql.views_schema()
    print(f"-- One-time setup for rowparity results under {dest}")
    print(f"CREATE SCHEMA IF NOT EXISTS {presto_sql.tables_schema()};")
    print(f"CREATE SCHEMA IF NOT EXISTS {views};")
    for statement in presto_sql.table_ddl(dest):
        print(statement + ";")
    return 0


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


def _check_query_files(cases) -> int:
    problems = 0
    for case in cases:
        for label, spec in (("expected", getattr(case, "expected", None)),
                            ("actual", getattr(case, "actual", None))):
            if not isinstance(spec, dict) or not spec.get("query_file"):
                continue
            base_dir = os.path.dirname(case.source_file) or "."
            variables = merge_side_vars(spec.get("vars"), getattr(case, "variables", {}))
            try:
                resolve_query(spec, base_dir, variables)
            except _LOAD_ERRORS as exc:
                problems += 1
                print(f"  {case.name} [{label}]: {exc}", file=sys.stderr)
    if problems:
        print(
            f"ERROR: {problems} query file(s) will not resolve. Pass the missing "
            f"--param, or add the name to the case's vars: block.",
            file=sys.stderr,
        )
        return 2
    return 0


def _where_defined(case) -> str:
    """The SQL a suite query comes from; the YAML file for an ordinary case."""
    expected = getattr(case, "expected", None) or {}
    actual = getattr(case, "actual", None) or {}
    query_file = expected.get("query_file")
    if query_file and query_file == actual.get("query_file"):
        return query_file
    if query_file and actual.get("query_file"):
        return os.path.dirname(query_file) + os.sep
    return case.source_file


def _list(args) -> int:
    try:
        cli_params = parse_cli_params(getattr(args, "param", None))
    except ParamError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    # resolve_queries=False: listing cases must never hit a warehouse.
    cases, failed = _load_cases(args.path, cli_params, resolve_queries=False)
    if failed is not None:
        return failed
    cases, failed = _select_cases(cases, args)
    if failed is not None:
        return failed
    fmt = getattr(args, "format", "text")
    if fmt == "names":
        # One name per line: pipe into `xargs -I{} rowparity run ... --select {}`.
        for case in cases:
            print(case.name)
    elif fmt == "json":
        print(json.dumps([
            {
                "name": case.name,
                "enabled": getattr(case, "enabled", True),
                "group": getattr(case, "group", None),
                "tags": list(case.tags),
                "description": case.description,
                "source_file": case.source_file,
                "sql": _where_defined(case),
            }
            for case in cases
        ], indent=2))
    else:
        for case in cases:
            tags = f" [{', '.join(case.tags)}]" if case.tags else ""
            disabled = " (disabled)" if not getattr(case, "enabled", True) else ""
            print(f"{case.name}{tags}{disabled}  ({_where_defined(case)})")
            if case.description:
                print(f"    {case.description}")
    if getattr(args, "check", False):
        return _check_query_files(cases)
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="rowparity", description="Fingerprint-based data comparison for CI.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    run_p = sub.add_parser("run", help="run cases and exit non-zero on any difference")
    run_p.add_argument("path", help="a case file or a directory of *.yml/*.yaml cases")
    run_p.add_argument(
        "--select", nargs="*",
        help="only run these case names (runs them even if disabled or in another group)",
    )
    run_p.add_argument(
        "--group", metavar="I/N",
        help="only run cases in group I of N, e.g. 3/7 for one day of a weekly rotation. "
             "A case's group comes from its name unless its overrides pin `group:`.",
    )
    run_p.add_argument(
        "--param", action="append", metavar="NAME=VALUE",
        help="set a ${name} placeholder, overriding the case's vars: block and "
             "ROWPARITY_VAR_NAME. Repeatable.",
    )
    run_p.add_argument(
        "--out", metavar="DIR",
        help="write <DIR>/<case>/result.json (the complete record of the run: "
             "verdict, findings, examples, drill-down SQL, run metadata) and "
             "columns.csv. Exits 2 if they cannot be written.",
    )
    run_p.add_argument(
        "--publish", metavar="DEST",
        help="publish each test's run to DEST (s3://bucket/prefix or a local directory): "
             "<test>/runs/<date>_<run_id>/, <test>/latest/, and Parquet for the Presto tables "
             "under _tables/. Defaults to $ROWPARITY_PUBLISH_URI. Exits 2 if anything cannot "
             "be written.",
    )
    run_p.add_argument(
        "--run-id", metavar="ID",
        help="identify this run (default: a new UUID). Pass the scheduler's run id so every "
             "task of one scheduled run shares it.",
    )
    run_p.add_argument(
        "--run-date", metavar="YYYY-MM-DD",
        help="the run_date partition to publish under (default: today, UTC)",
    )
    run_p.add_argument(
        "--verbose", action="store_true",
        help="after the findings, also print the full diff: breakdown table, "
             "every change signature and the example rows.",
    )
    run_p.add_argument("--json", help="write a JSON summary here")
    run_p.add_argument("--md", help="write a Markdown report here")
    run_p.add_argument("--xlsx", help="write an Excel report here")
    run_p.add_argument(
        "--html", metavar="FILE",
        help="write a self-contained HTML report for THIS run here. Unlike "
             "`rowparity report --html`, which renders pass-rate history from "
             "a result sink, this shows one run: per-case verdict, timings, "
             "row parity, a filterable per-column table, change signatures, "
             "and any case that failed to run at all.",
    )
    run_p.add_argument(
        "--quiet", action="store_true",
        help="suppress the live per-step progress on stderr. Results still go "
             "to stdout; only the 'running query ...' / heartbeat lines go away.",
    )
    run_p.add_argument(
        "--heartbeat", type=float, default=None, metavar="SECONDS",
        help="how often to print 'still running' while a step is in flight "
             "(default 30). 0 disables the heartbeat but keeps step lines.",
    )
    run_p.add_argument(
        "--csv", metavar="DIR",
        help="write one <case>.csv per case here: a row per column with its "
             "status and type on each side. This is the readable form when "
             "schema drift runs to hundreds of columns.",
    )
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
    list_p.add_argument("--select", nargs="*", help="only list these case names")
    list_p.add_argument("--group", metavar="I/N", help="only list cases in group I of N")
    list_p.add_argument(
        "--format", choices=("text", "names", "json"), default="text",
        help="names: one per line, for scripts and xargs; json: for schedulers such as Airflow",
    )
    list_p.add_argument(
        "--include-disabled", action="store_true",
        help="also list cases whose overrides set enabled: false",
    )
    list_p.add_argument(
        "--param", action="append", metavar="NAME=VALUE",
        help="set a ${name} placeholder (same as `run --param`)",
    )
    list_p.add_argument(
        "--check", action="store_true",
        help="also resolve each side's query_file and report any ${name} that "
             "will not resolve. Listing alone proves only that the YAML parses; "
             "SQL files are read at run time, so a bad placeholder in one lists "
             "cleanly and fails only once the run starts. Reads local files "
             "only -- no connection is opened. Exits 2 on any problem. Pass the "
             "same --param you would pass to `run`.",
    )
    list_p.set_defaults(func=_list)

    sum_p = sub.add_parser(
        "summarize",
        help="after all tests of a run have published: totals, common causes across tests, "
             "and (with --presto) partition sync and view refresh",
    )
    sum_p.add_argument("--run-id", required=True, help="the --run-id every test was published with")
    sum_p.add_argument("--run-date", metavar="YYYY-MM-DD", help="only read this run_date partition")
    sum_p.add_argument(
        "--publish", metavar="DEST", help="where the tests published (default $ROWPARITY_PUBLISH_URI)"
    )
    sum_p.add_argument(
        "--expect", metavar="FILE",
        help="the tests that were meant to run: output of `rowparity list --format names|json`, "
             "or - for stdin. Tests without a published result are reported as NO RESULT.",
    )
    sum_p.add_argument(
        "--presto", action="store_true",
        help="sync partitions of the shared tables and create/refresh each test's view "
             "(TRINO_* credentials; schemas from ROWPARITY_TABLES_SCHEMA / ROWPARITY_VIEWS_SCHEMA)",
    )
    sum_p.set_defaults(func=_summarize)

    cmp_p = sub.add_parser(
        "compare-runs",
        help="the last N runs side by side: rows compared, rows on each side, rows mismatching",
    )
    cmp_p.add_argument("--last", type=int, default=7, metavar="N", help="how many runs (default: 7)")
    cmp_p.add_argument(
        "--cases", metavar="FILE",
        help="only these tests: one name per line, e.g. a suites/<suite>.txt list, or - for stdin",
    )
    cmp_p.add_argument("--csv", metavar="FILE", help="also write the totals here, one row per run")
    cmp_p.add_argument(
        "--publish-html", action="store_true",
        help="also write the page to <DEST>/_compare/<name>.html (overwritten each time)",
    )
    cmp_p.add_argument(
        "--publish", metavar="DEST", help="where the tests published (default $ROWPARITY_PUBLISH_URI)"
    )
    cmp_p.set_defaults(func=_compare_runs)

    show_p = sub.add_parser("show", help="read a published test run back: findings, runs, HTML")
    show_p.add_argument("test", help="the test's name, as `rowparity list` prints it")
    show_p.add_argument("--run-id", help="a specific kept run (default: the latest)")
    show_p.add_argument("--runs", action="store_true", help="list the test's kept runs instead")
    show_p.add_argument("--html", metavar="FILE", help="also write the report page here")
    show_p.add_argument("--json", action="store_true", help="print result.json instead of findings")
    show_p.add_argument(
        "--publish", metavar="DEST", help="where results are published (default $ROWPARITY_PUBLISH_URI)"
    )
    show_p.set_defaults(func=_show)

    param_p = sub.add_parser(
        "param",
        help="resolve one param_queries value and print it, so a scheduler can pin the "
             "same value for every task of a run (rowparity run --param name=<value>)",
    )
    param_p.add_argument("path", help="the suite or case file declaring param_queries")
    param_p.add_argument("name", help="which parameter to resolve, e.g. batch_id")
    param_p.add_argument("--param", action="append", metavar="NAME=VALUE",
                         help="values the resolving query itself needs")
    param_p.set_defaults(func=_param)

    ddl_p = sub.add_parser("ddl", help="print the one-time CREATE SCHEMA / CREATE TABLE statements")
    ddl_p.add_argument("--publish", metavar="DEST", help="the published location the tables read")
    ddl_p.set_defaults(func=_ddl)

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
    try:
        return args.func(args)
    except BrokenPipeError:
        # `rowparity list --format names | head` closes the pipe early. That is
        # normal use, not an error, and Python's own shutdown flush would print
        # a second traceback unless stdout is pointed somewhere harmless.
        try:
            sys.stdout.close()
        except BrokenPipeError:
            pass
        os.dup2(os.open(os.devnull, os.O_WRONLY), 1)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
