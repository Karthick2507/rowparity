"""Sanity check before running any real snowflake_pushdown.py case: confirms
key-pair auth actually connects, and that the configured warehouse/database/
schema are usable. Doesn't touch snowflake_pushdown.py at all -- this only
validates snowflake_auth.py's connection path.

Usage:
    set -a; source .env.snowflake; set +a
    python scripts/snowflake_connectivity_check.py
"""

import sys

from rowparity.snowflake_auth import connect


def main() -> int:
    print("Connecting via key-pair auth...")
    try:
        con = connect({})
    except Exception as exc:
        print(f"FAILED to connect: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    try:
        cur = con.cursor()
        row = cur.execute(
            "SELECT CURRENT_VERSION(), CURRENT_ACCOUNT(), CURRENT_USER(), "
            "CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE(), CURRENT_SCHEMA()"
        ).fetchone()
        version, account, user, role, warehouse, database, schema = row
        print(f"Connected OK -- Snowflake {version}")
        print(f"  account:   {account}")
        print(f"  user:      {user}")
        print(f"  role:      {role}")
        print(f"  warehouse: {warehouse}")
        print(f"  database:  {database}")
        print(f"  schema:    {schema}")
        if warehouse is None:
            print("WARNING: no warehouse resolved -- set SNOWFLAKE_WAREHOUSE", file=sys.stderr)
        if database is None:
            print("WARNING: no database resolved -- set SNOWFLAKE_DATABASE", file=sys.stderr)
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
