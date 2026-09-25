"""``prism`` — generate rowparity cases from the queries they compare.

Three subcommands, all **folder-only**:

    prism inspect  <folder>          what PRISM read, and what it could not decide
    prism generate <folder>          write the case file(s) (never clobbers SQL)
    prism verify   <folder>          regenerate in memory and diff against what is on disk

``<folder>`` is routed per subfolder, not by a single fixed shape:

* A subfolder holding a ``conf.yml``/``conf.yaml`` is a **biz_service batch** --
  every ``.sql`` file beside that conf becomes its own case, classified into
  keys/metrics from the conf's own ``dimensions:``/``metrics:`` lists. One
  merged ``cases_biz_service.yaml`` covers every batch generated this way.
* A ``.sql`` file directly in the folder, with no conf.yml beside it, is read
  by the original single-query pipeline (``prism/analyse.py``) -- one case
  per file, an aggregate-over-UNION-ALL query with its keys derived from the
  GROUP BY. Pass a folder such as ``sql/insight_plus`` to batch-run this over
  every case already there.

``verify`` is the one that keeps PRISM honest. Run it against cases a human
has already written and the diff tells you where PRISM's derivation disagrees
with a person's judgement -- which is either a bug in PRISM or a decision
worth writing down. It is also how the regression test works.

A file that fails to analyse does not stop the run: it is reported and
skipped, and every other file in the folder is still processed. The exit
code reflects whether anything failed.
"""

from __future__ import annotations

import argparse
import difflib
import os
import shutil
import sys
from typing import List, Tuple

from . import biz_service as bs
from .analyse import AnalysisError, analyse
from .generate import (
    SQL_DIR,
    default_output_root,
    planned_outputs,
    render_all,
    repo_root,
)

Target = Tuple[str, str]  # ("insight_plus", sql_path) | ("biz_service", batch_dir)


def _discover_targets(folder: str) -> List[Target]:
    """Every target under ``folder``, routed by conf.yml presence.

    ``folder`` itself is checked first (so pointing straight at a batch
    folder such as ``prism/input/ab_test`` works), then its immediate
    children -- a batch subfolder for each one holding a conf.yml, a
    single-query target for each ``.sql`` file that is not inside one.
    """
    if not os.path.isdir(folder):
        raise AnalysisError(f"no such folder: {folder}")

    if bs.find_conf_file(folder):
        return [("biz_service", folder)]

    targets: List[Target] = []
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        if os.path.isdir(path) and bs.find_conf_file(path):
            targets.append(("biz_service", path))
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        # *_drilldown.sql is PRISM's own generated output, never a parity
        # query in its own right -- analysing it as one would derive a
        # nonsensical second case (and that case's own "_drilldown_drilldown.sql").
        if os.path.isfile(path) and name.endswith(".sql") and not name.endswith("_drilldown.sql"):
            targets.append(("insight_plus", path))
    return targets


# --------------------------------------------------------------------------- #
# insight_plus: one case per .sql file (unchanged logic, just looped)
# --------------------------------------------------------------------------- #
def _print_profile(p) -> None:
    print(f"PRISM read {p.sql_path}\n")
    print(f"  name                {p.name}")
    print(f"  output columns      {p.output_columns}  "
          f"({len(p.dimensions)} dimensions + {len(p.metrics)} metrics)")
    print(f"  UNION branches      {p.branches}")
    print(f"  placeholders        {sorted(p.placeholders)}")
    print(f"  ${{facts}} references  {p.fact_refs}  -> {p.fact_tables}")
    print(f"  sampling markers    {p.sampling_markers}")
    print(f"  batch parameter     {p.batch_param}  ({p.batch_refs} predicate(s))")
    print(f"  breakdown_by        {p.breakdown_by}  {p.breakdown_values}")
    print(f"  unordered arrays    {p.unordered_arrays}")
    print(f"  constructed arrays  {p.constructed_arrays}   (left ordered)")
    print(f"  shared catalogs     {p.shared_catalogs}")
    if p.row_summary:
        print("  row_summary")
        for g in p.row_summary:
            print(f"      {g['label']:14} {', '.join(g['columns'])}")


def _print_issues(p) -> bool:
    if not p.issues:
        print("\n  no issues.")
        return True
    print(f"\n  {len(p.issues)} thing(s) PRISM wants you to look at:")
    for issue in p.issues:
        print(f"    - {issue}")
    return True


def _inspect_one_insight_plus(sql_path: str) -> bool:
    try:
        p = analyse(sql_path)
    except AnalysisError as exc:
        print(f"ERROR  {sql_path}: {exc}", file=sys.stderr)
        return False
    _print_profile(p)
    _print_issues(p)
    return True


def _generate_one_insight_plus(args, sql_path: str) -> bool:
    try:
        p = analyse(sql_path)
    except AnalysisError as exc:
        print(f"ERROR  {sql_path}: {exc}", file=sys.stderr)
        return False
    _print_profile(p)
    _print_issues(p)

    rendered = render_all(
        p,
        expected_facts=args.expected_facts,
        actual_facts=args.actual_facts,
        expected_label=args.expected_label,
        actual_label=args.actual_label,
    )
    root = args.root or default_output_root()
    paths = planned_outputs(p, root)
    only = set(args.only) if args.only else set(rendered)

    print()
    written = 0
    for kind, path in paths.items():
        if kind not in only:
            continue
        exists = os.path.exists(path)
        if exists and not args.force:
            print(f"  SKIP   {path}  (exists; --force to overwrite)")
            continue
        if args.dry_run:
            print(f"  WOULD  {path}  ({len(rendered[kind].splitlines())} lines)")
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(rendered[kind])
        print(f"  WROTE  {path}  ({len(rendered[kind].splitlines())} lines)")
        written += 1

    if not args.dry_run and written and not args.no_copy_source:
        dest = os.path.join(root, SQL_DIR, os.path.basename(sql_path))
        if os.path.abspath(dest) != os.path.abspath(sql_path):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copyfile(sql_path, dest)
            print(f"  COPIED {dest}  (so the preview is runnable)")
    print()
    return True


# --------------------------------------------------------------------------- #
# biz_service: every .sql file in a conf.yml-owned folder becomes its own case
# --------------------------------------------------------------------------- #
def _print_batch_result(r: "bs.FileResult") -> None:
    if r.skipped:
        print(f"  SKIP   {r.sql_path}  ({r.skip_reason})")
        return
    print(f"  {r.name}  ({r.output_columns} columns: {len(r.keys)} keys + "
          f"{len(r.metrics)} metrics)")
    if r.issues:
        for issue in r.issues:
            print(f"    - {issue}")


def _inspect_one_batch(batch_dir: str) -> bool:
    try:
        conf, results = bs.analyse_batch(batch_dir)
    except (bs.BizServiceError, AnalysisError) as exc:
        print(f"ERROR  {batch_dir}: {exc}", file=sys.stderr)
        return False
    print(f"PRISM read batch {batch_dir}  ({conf.path})")
    print(f"  {len(conf.dimensions)} conf dimension(s), {len(conf.metrics)} conf metric(s)")
    ok = True
    for r in results:
        _print_batch_result(r)
        if not r.skipped and (r.unparsed or not r.keys):
            ok = False
    print()
    return ok


def _generate_one_batch(args, batch_dir: str) -> bool:
    try:
        conf, results = bs.analyse_batch(batch_dir)
    except (bs.BizServiceError, AnalysisError) as exc:
        print(f"ERROR  {batch_dir}: {exc}", file=sys.stderr)
        return False

    print(f"PRISM read batch {batch_dir}  ({conf.path})")
    ok = True
    new_cases = {}
    root = args.root or default_output_root()

    for r in results:
        _print_batch_result(r)
        if r.skipped:
            continue
        if r.unparsed or not r.keys:
            ok = False
            continue

        sql_dest = os.path.join(root, bs.SQL_DIR, r.batch_name, f"{r.name}.sql")
        if args.dry_run:
            print(f"  WOULD  {sql_dest}")
        else:
            if os.path.exists(sql_dest) and not args.force:
                print(f"  SKIP   {sql_dest}  (exists; --force to overwrite)")
            else:
                os.makedirs(os.path.dirname(sql_dest), exist_ok=True)
                with open(sql_dest, "w", encoding="utf-8") as fh:
                    fh.write(r.transformed_sql)
                print(f"  WROTE  {sql_dest}")

        new_cases[r.name] = bs.render_case_dict(
            r,
            expected_facts=args.expected_facts,
            actual_facts=args.actual_facts,
            expected_label=args.expected_label,
            actual_label=args.actual_label,
        )

    if new_cases and not args.dry_run:
        case_file = os.path.join(root, bs.CASE_FILE)
        existing = None
        if os.path.exists(case_file):
            with open(case_file, encoding="utf-8") as fh:
                existing = fh.read()
        merged = bs.merge_cases_yaml(existing, new_cases)
        os.makedirs(os.path.dirname(case_file), exist_ok=True)
        with open(case_file, "w", encoding="utf-8") as fh:
            fh.write(merged)
        print(f"  MERGED {case_file}  ({len(new_cases)} case(s) from this batch)")

        test_file = os.path.join(root, bs.TEST_FILE)
        os.makedirs(os.path.dirname(test_file), exist_ok=True)
        with open(test_file, "w", encoding="utf-8") as fh:
            fh.write(bs.TEST_FILE_CONTENTS)
        print(f"  WROTE  {test_file}")
    elif new_cases:
        print(f"  WOULD MERGE {len(new_cases)} case(s) into "
              f"{os.path.join(root, bs.CASE_FILE)}")

    print()
    return ok


def _verify_one_batch(args, batch_dir: str) -> bool:
    """Regenerate a batch's transformed SQL in memory and diff against disk."""
    try:
        conf, results = bs.analyse_batch(batch_dir)
    except (bs.BizServiceError, AnalysisError) as exc:
        print(f"ERROR  {batch_dir}: {exc}", file=sys.stderr)
        return False

    root = args.root or repo_root()
    same = True
    for r in results:
        if r.skipped:
            print(f"  SKIP     {r.sql_path}  ({r.skip_reason})")
            continue
        path = os.path.join(root, bs.SQL_DIR, r.batch_name, f"{r.name}.sql")
        if not os.path.exists(path):
            print(f"  MISSING  {path}")
            same = False
            continue
        with open(path, encoding="utf-8") as fh:
            on_disk = fh.read()
        if on_disk == r.transformed_sql:
            print(f"  SAME     {path}")
            continue
        same = False
        print(f"  DIFFERS  {path}")
        if args.show_diff:
            diff = difflib.unified_diff(
                on_disk.splitlines(), r.transformed_sql.splitlines(),
                fromfile=f"{path} (on disk)", tofile="PRISM would generate",
                lineterm="", n=1,
            )
            for line in list(diff)[: args.diff_lines]:
                print(f"      {line}")
    return same


# --------------------------------------------------------------------------- #
# Dispatch -- skip-and-continue, one summary at the end
# --------------------------------------------------------------------------- #
def _run(args, *, one_insight_plus, one_batch) -> int:
    try:
        targets = _discover_targets(args.folder)
    except AnalysisError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if not targets:
        print(f"no .sql files or conf.yml batches found under {args.folder}", file=sys.stderr)
        return 2

    results = []
    for kind, target in targets:
        fn = one_insight_plus if kind == "insight_plus" else one_batch
        ok = fn(args, target)
        results.append((kind, target, ok))

    failed = [(k, t) for k, t, ok in results if not ok]
    print(f"{len(results)} target(s): {len(results) - len(failed)} OK, {len(failed)} failed.")
    if failed:
        print("Failed:")
        for kind, target in failed:
            print(f"  - [{kind}] {target}")
    return 1 if failed else 0


def _inspect(args) -> int:
    return _run(
        args,
        one_insight_plus=lambda a, t: _inspect_one_insight_plus(t),
        one_batch=lambda a, t: _inspect_one_batch(t),
    )


def _generate(args) -> int:
    return _run(args, one_insight_plus=_generate_one_insight_plus, one_batch=_generate_one_batch)


def _verify(args) -> int:
    def _verify_insight_plus(args, sql_path: str) -> bool:
        try:
            p = analyse(sql_path)
        except AnalysisError as exc:
            print(f"ERROR  {sql_path}: {exc}", file=sys.stderr)
            return False
        rendered = render_all(
            p,
            expected_facts=args.expected_facts,
            actual_facts=args.actual_facts,
            expected_label=args.expected_label,
            actual_label=args.actual_label,
        )
        root = args.root or repo_root()
        paths = planned_outputs(p, root)
        only = set(args.only) if args.only else set(rendered)

        same = True
        for kind, path in paths.items():
            if kind not in only:
                continue
            if not os.path.exists(path):
                print(f"  MISSING  {path}")
                same = False
                continue
            with open(path, encoding="utf-8") as fh:
                on_disk = fh.read()
            if on_disk == rendered[kind]:
                print(f"  SAME     {path}")
                continue
            same = False
            print(f"  DIFFERS  {path}")
            if args.show_diff:
                diff = difflib.unified_diff(
                    on_disk.splitlines(), rendered[kind].splitlines(),
                    fromfile=f"{path} (on disk)", tofile="PRISM would generate",
                    lineterm="", n=1,
                )
                for line in list(diff)[: args.diff_lines]:
                    print(f"      {line}")
        return same

    return _run(args, one_insight_plus=_verify_insight_plus, one_batch=_verify_one_batch)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        prog="prism",
        description="Generate rowparity cases from the queries they compare.",
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(sp):
        sp.add_argument(
            "folder",
            help="a folder to scan: subfolders holding a conf.yml are biz_service "
                 "batches, .sql files directly in it are read by the single-query "
                 "pipeline (e.g. sql/insight_plus, or prism/input for everything)",
        )
        sp.add_argument(
            "--root", default=None,
            help="where to write / what to diff against. generate defaults to "
                 "prism/output; verify defaults to the repo root.",
        )
        sp.add_argument("--expected-facts", default="mrm_log_flat.default")
        sp.add_argument("--actual-facts", default="etl.public_test1")
        sp.add_argument("--expected-label", default="Hoover")
        sp.add_argument("--actual-label", default="Hoover++")
        sp.add_argument("--only", nargs="*",
                        choices=["case", "drilldown"],
                        help="restrict to these outputs (insight_plus targets only)")

    ins = sub.add_parser("inspect", help="show what PRISM read; write nothing")
    ins.add_argument("folder")
    ins.set_defaults(func=_inspect)

    gen = sub.add_parser("generate", help="write the case file(s)")
    common(gen)
    gen.add_argument("--force", action="store_true", help="overwrite existing SQL copies")
    gen.add_argument("--dry-run", action="store_true", help="say what would be written")
    gen.add_argument(
        "--no-copy-source", action="store_true",
        help="insight_plus targets only: do not copy the parity .sql into the "
             "output tree (the copy is what makes the preview runnable)",
    )
    gen.set_defaults(func=_generate)

    ver = sub.add_parser("verify", help="diff what PRISM would generate against disk")
    common(ver)
    ver.add_argument("--show-diff", action="store_true")
    ver.add_argument("--diff-lines", type=int, default=40)
    ver.set_defaults(func=_verify)

    args = ap.parse_args(argv)
    try:
        return args.func(args)
    except AnalysisError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
