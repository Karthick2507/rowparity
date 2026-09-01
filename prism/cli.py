"""``prism`` — generate a rowparity case from the query it compares.

Three subcommands:

    prism inspect  <file.sql>          what PRISM read, and what it could not decide
    prism generate <file.sql>          write the four files (refuses to clobber)
    prism verify   <file.sql>          regenerate in memory and diff against what is on disk

``verify`` is the one that keeps PRISM honest. Run it against a case a human has
already written and the diff tells you where PRISM's derivation disagrees with a
person's judgement -- which is either a bug in PRISM or a decision worth writing
down. It is also how the regression test works.
"""

from __future__ import annotations

import argparse
import difflib
import os
import sys

from .analyse import AnalysisError, analyse
from .generate import planned_outputs, render_all


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


def _print_issues(p) -> int:
    if not p.issues:
        print("\n  no issues.")
        return 0
    print(f"\n  {len(p.issues)} thing(s) PRISM wants you to look at:")
    for issue in p.issues:
        print(f"    - {issue}")
    return 0


def _inspect(args) -> int:
    p = analyse(args.sql)
    _print_profile(p)
    return _print_issues(p)


def _generate(args) -> int:
    p = analyse(args.sql)
    _print_profile(p)
    _print_issues(p)

    rendered = render_all(
        p,
        expected_facts=args.expected_facts,
        actual_facts=args.actual_facts,
        expected_label=args.expected_label,
        actual_label=args.actual_label,
    )
    paths = planned_outputs(p, args.root)
    only = set(args.only) if args.only else set(rendered)

    print()
    written, skipped = 0, 0
    for kind, path in paths.items():
        if kind not in only:
            continue
        exists = os.path.exists(path)
        if exists and not args.force:
            # Never clobber. A generated file that someone has since edited is
            # the normal case, not the exception -- PRISM writes a first draft
            # and then gets out of the way.
            print(f"  SKIP   {path}  (exists; --force to overwrite)")
            skipped += 1
            continue
        if args.dry_run:
            print(f"  WOULD  {path}  ({len(rendered[kind].splitlines())} lines)")
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(rendered[kind])
        print(f"  WROTE  {path}  ({len(rendered[kind].splitlines())} lines)")
        written += 1

    if args.dry_run:
        print("\n  dry run: nothing written.")
        return 0
    print(f"\n  {written} written, {skipped} skipped.")
    if written:
        print("\n  Next:")
        print(f"    rowparity list {os.path.join(args.root, 'scripts', 'cases_insight_plus')}")
        print(f"    rowparity list {os.path.join(args.root, 'scripts', 'cases_insight_plus')} "
              f"--check --param {p.batch_param}=<batch>")
        print(f"    pytest tests/test_{p.name}_case.py tests/test_{p.name}_sql_sync.py -q")
    return 0


def _verify(args) -> int:
    """Regenerate in memory, diff against disk, exit 1 on any difference."""
    p = analyse(args.sql)
    rendered = render_all(
        p,
        expected_facts=args.expected_facts,
        actual_facts=args.actual_facts,
        expected_label=args.expected_label,
        actual_label=args.actual_label,
    )
    paths = planned_outputs(p, args.root)
    only = set(args.only) if args.only else set(rendered)

    differing = 0
    for kind, path in paths.items():
        if kind not in only:
            continue
        if not os.path.exists(path):
            print(f"  MISSING  {path}")
            differing += 1
            continue
        with open(path, encoding="utf-8") as fh:
            on_disk = fh.read()
        if on_disk == rendered[kind]:
            print(f"  SAME     {path}")
            continue
        differing += 1
        print(f"  DIFFERS  {path}")
        if args.show_diff:
            diff = difflib.unified_diff(
                on_disk.splitlines(), rendered[kind].splitlines(),
                fromfile=f"{path} (on disk)", tofile="PRISM would generate",
                lineterm="", n=1,
            )
            for line in list(diff)[: args.diff_lines]:
                print(f"      {line}")
    return 1 if differing else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        prog="prism",
        description="Generate a rowparity case from the query it compares.",
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(sp):
        sp.add_argument("sql", help="path to the parity SQL template")
        sp.add_argument("--root", default=".", help="repo root (default: .)")
        sp.add_argument("--expected-facts", default="mrm_log_flat.default")
        sp.add_argument("--actual-facts", default="etl.public_test1")
        sp.add_argument("--expected-label", default="Hoover")
        sp.add_argument("--actual-label", default="Hoover++")
        sp.add_argument("--only", nargs="*",
                        choices=["case", "sql_sync_test", "case_test", "drilldown"],
                        help="restrict to these outputs")

    ins = sub.add_parser("inspect", help="show what PRISM read; write nothing")
    ins.add_argument("sql")
    ins.set_defaults(func=_inspect)

    gen = sub.add_parser("generate", help="write the four files")
    common(gen)
    gen.add_argument("--force", action="store_true", help="overwrite existing files")
    gen.add_argument("--dry-run", action="store_true", help="say what would be written")
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
