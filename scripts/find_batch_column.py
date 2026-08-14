"""Find which column carries the batch id, on each side.

The BCV value-parity cases filter both tables to one batch. SRC and BCV do not
necessarily name that column the same way -- verified live that SRC uses
`process_batch_id` while the BCV layout has no `batch_id` at all, despite the
BCV analyser's README describing exactly that split. Guessing costs a whole
run against a warehouse over VPN, so ask instead.

Schema-only: uses the same DESCRIBE path the schema_check cases use. No rows
are read from either table.

Usage:
    python scripts/find_batch_column.py
    python scripts/find_batch_column.py --table slot

Then run with whatever it reports:
    rowparity run examples/cases_bcv --param bcv_batch_column=<name>
"""

import argparse
import sys

from rowparity.schema_introspect import describe_source

# Substrings that plausibly name a batch/partition column.
HINTS = ("batch", "partition", "process_ts", "process_time", "load_", "dt", "hour")


def _candidates(columns: dict) -> list:
    hits = []
    for name, type_str in columns.items():
        lowered = name.lower()
        if any(h in lowered for h in HINTS):
            hits.append((name, type_str))
    return sorted(hits)


def _report(label: str, table: str) -> "dict | None":
    print(f"\n--- {label}: {table} " + "-" * 20)
    try:
        columns = describe_source({"type": "trino", "table": table})
    except Exception as exc:
        print(f"  FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return None

    hits = _candidates(columns)
    if not hits:
        print(f"  no batch-like column among {len(columns)} columns.")
        print(f"  hints tried: {HINTS}")
        return columns

    print(f"  {len(hits)} candidate(s) out of {len(columns)} columns:")
    for name, type_str in hits:
        print(f"    {name}  ({type_str})")
    return columns


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--table", default="request", help="request | slot | ad | ...")
    parser.add_argument("--src-catalog", default="mrm_log_flat")
    parser.add_argument("--src-schema", default="default")
    parser.add_argument("--bcv-catalog", default="etl")
    parser.add_argument("--bcv-schema", default="public_test1")
    args = parser.parse_args()

    src = f"{args.src_catalog}.{args.src_schema}.{args.table}"
    bcv = f"{args.bcv_catalog}.{args.bcv_schema}.{args.table}"

    src_cols = _report("SRC", src)
    bcv_cols = _report("BCV", bcv)

    if src_cols and bcv_cols:
        shared = sorted(n for n, _ in _candidates(src_cols) if n in bcv_cols)
        print("\n--- Shared by both sides " + "-" * 20)
        if shared:
            print("  These exist on BOTH, so one name can serve for both parameters:")
            for name in shared:
                print(f"    {name}")
            print("\n  rowparity run examples/cases_bcv \\")
            print(f"      --param src_batch_column={shared[0]} \\")
            print(f"      --param bcv_batch_column={shared[0]}")
        else:
            print("  None in common -- the two sides name it differently, so set")
            print("  src_batch_column and bcv_batch_column separately.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
