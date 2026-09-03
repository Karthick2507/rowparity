import argparse
import os
import sys
import traceback

from rowparity.schema_introspect import describe_source

# Mirrors the sampling predicate the Phase 3 cases use. Constant-folded here
# (no table) so this probes function availability without scanning anything.
SAMPLING_PROBE_SQL = (
    "SELECT abs(from_big_endian_64(xxhash64(to_utf8(CAST('probe-key' AS VARCHAR))))) % 1000"
)


def _spec(table: str) -> dict:
    return {"type": "trino", "table": table}


def _hr(title: str) -> None:
    print()
    print(f"--- {title} " + "-" * max(0, 60 - len(title)))


def step_connect() -> "tuple[bool, object]":
    _hr("1. Connection")
    host = os.environ.get("TRINO_HOST")
    if not host:
        print("FAILED: TRINO_HOST is not set", file=sys.stderr)
        return False, None
    print(f"  host:   {host}")
    print(f"  port:   {os.environ.get('TRINO_PORT', '8080 (default)')}")
    print(f"  user:   {os.environ.get('TRINO_USER', '(OS user)')}")
    print(f"  scheme: {os.environ.get('TRINO_HTTP_SCHEME', 'http (default)')}")
    auth = (
        "JWT/Bearer"
        if os.environ.get("TRINO_JWT_TOKEN")
        else ("Basic" if os.environ.get("TRINO_PASSWORD") else "none")
    )
    print(f"  auth:   {auth}")
    if "://" in host:
        print(
            "WARNING: TRINO_HOST contains a scheme. Use a bare hostname and set "
            "TRINO_HTTP_SCHEME=https instead.",
            file=sys.stderr,
        )

    try:
        from rowparity.trino_auth import connect

        con = connect({})
        cur = con.cursor()
        cur.execute("SELECT 1")
        cur.fetchall()
        print("  Connected OK")
        return True, con
    except Exception as exc:
        print(f"FAILED to connect: {type(exc).__name__}: {exc}", file=sys.stderr)
        traceback.print_exc()
        return False, None


def step_describe(label: str, table: str) -> "dict | None":
    _hr(f"2. DESCRIBE {label}: {table}")
    try:
        cols = describe_source(_spec(table))
    except Exception as exc:
        print(f"FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        traceback.print_exc()
        return None

    print(f"  columns: {len(cols)}")
    print("  first 10 (name -> type as this engine reports it):")
    for name, type_str in list(cols.items())[:10]:
        print(f"    {name}  ->  {type_str}")
    nested = {n: t for n, t in cols.items() if t.startswith(("array(", "row(", "map("))}
    print(f"  nested-typed columns: {len(nested)}")
    for name, type_str in list(nested.items())[:3]:
        print(f"    {name}  ->  {type_str[:110]}")
    return cols


def step_compare(src_cols: dict, bcv_cols: dict) -> None:
    """Preview of exactly what a Phase 1 schema_check case will report."""
    _hr("3. Schema comparison preview (what schema_check will report)")
    src_set, bcv_set = set(src_cols), set(bcv_cols)
    common = src_set & bcv_set
    matched = [c for c in common if src_cols[c] == bcv_cols[c]]
    type_diff = [c for c in common if src_cols[c] != bcv_cols[c]]
    only_src = sorted(src_set - bcv_set)
    only_bcv = sorted(bcv_set - src_set)

    print(f"  MATCHED             : {len(matched)}   -> compared_columns")
    print(f"  MATCHED - TYPE DIFF : {len(type_diff)}   -> type_mismatches")
    print(f"  DIFF (SRC only)     : {len(only_src)}   -> columns_only_in_expected")
    print(f"  DIFF (BCV only)     : {len(only_bcv)}   -> columns_only_in_actual")

    for c in type_diff[:10]:
        print(f"    TYPE DIFF  {c}: src={src_cols[c]!r}  bcv={bcv_cols[c]!r}")
    if len(type_diff) > 10:
        print(f"    ... and {len(type_diff) - 10} more")
    for c in only_src[:5]:
        print(f"    SRC only   {c}  ({src_cols[c]})")
    if len(only_src) > 5:
        print(f"    ... and {len(only_src) - 5} more")


def step_key(src_cols: dict, bcv_cols: dict, keys: "list[str]") -> None:
    _hr("4. Join key check")
    for key in keys:
        in_src, in_bcv = key in src_cols, key in bcv_cols
        if in_src and in_bcv:
            same = src_cols[key] == bcv_cols[key]
            status = "OK" if same else "TYPE DIFFERS"
            print(f"  {status}: {key}  src={src_cols[key]!r}  bcv={bcv_cols[key]!r}")
            if not same:
                print(
                    "    -> keyed compare still works, but check the values align", file=sys.stderr
                )
        else:
            where = "SRC" if not in_src else "BCV"
            print(f"  MISSING from {where}: {key}  -- keyed compare cannot work", file=sys.stderr)


def step_sampling(con) -> None:
    _hr("5. Deterministic sampling expression")
    print(f"  {SAMPLING_PROBE_SQL}")
    try:
        cur = con.cursor()
        cur.execute(SAMPLING_PROBE_SQL)
        value = cur.fetchall()[0][0]
        print(f"  OK -- evaluates to {value} (stable for a given key)")
    except Exception as exc:
        print(f"FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        print(
            "  -> this engine lacks one of xxhash64 / to_utf8 / from_big_endian_64.",
            file=sys.stderr,
        )
        print(
            "  -> report this back; the sampling predicate needs a different form.", file=sys.stderr
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--src", default="mrm_log_flat.default.request", help="fully-qualified SRC table"
    )
    parser.add_argument(
        "--bcv", default="etl.public_test1.request", help="fully-qualified BCV table"
    )
    parser.add_argument("--key", action="append", default=None, help="join key column (repeatable)")
    args = parser.parse_args()
    keys = args.key or ["request__transaction_id"]

    ok, con = step_connect()
    if not ok:
        print("\nConnection failed -- skipping remaining steps.", file=sys.stderr)
        return 1

    try:
        src_cols = step_describe("SRC", args.src)
        bcv_cols = step_describe("BCV", args.bcv)
        if src_cols and bcv_cols:
            step_compare(src_cols, bcv_cols)
            step_key(src_cols, bcv_cols, keys)
        else:
            print("\nSkipping comparison -- a DESCRIBE failed above.", file=sys.stderr)
        step_sampling(con)
    finally:
        try:
            con.close()
        except Exception:
            pass

    print()
    print("Done. Send this whole output back to continue with Phase 1.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
