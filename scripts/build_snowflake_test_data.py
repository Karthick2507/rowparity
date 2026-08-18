#!/usr/bin/env python3
"""Builds tiny golden/actual table pairs in Snowflake for validating
snowflake_pushdown.py against a real warehouse -- separate from
examples/build_tpch_data.py (DuckDB, runs in CI) since this needs a live
Snowflake account and shouldn't be part of the regular test suite.

Two pairs, deliberately small (XSMALL warehouse, a handful of rows each):
  SCALAR_GOLDEN / SCALAR_ACTUAL   -- exercises the static-schema scalar path
  NESTED_GOLDEN / NESTED_ACTUAL   -- exercises the TYPEOF()/FLATTEN nested path
                                     (ARRAY, OBJECT, and ARRAY<OBJECT>)
Both pairs have exactly one deliberate, known diff so the case YAMLs have a
concrete expected result to check against.

Usage:
    set -a; source .env.snowflake; set +a
    python scripts/build_snowflake_test_data.py
"""
from rowparity.snowflake_auth import connect


def main() -> None:
    con = connect({})
    try:
        cur = con.cursor()

        # ---- scalar pair -----------------------------------------------------
        cur.execute("""
            CREATE OR REPLACE TABLE SCALAR_GOLDEN (
                id NUMBER, name VARCHAR, amount NUMBER(10,2), score FLOAT, active BOOLEAN,
                created_date DATE, created_at TIMESTAMP_NTZ, updated_at TIMESTAMP_TZ
            )
        """)
        cur.execute("""
            INSERT INTO SCALAR_GOLDEN VALUES
                (1, 'Alice', 100.50, 3.14, TRUE, '2024-01-01', '2024-01-01 10:00:00', '2024-01-01 10:00:00 +00:00'),
                (2, 'Bob',   200.00, 2.71, FALSE, '2024-01-02', '2024-01-02 11:00:00', '2024-01-02 11:00:00 +00:00'),
                (3, 'Carol', 300.25, 1.41, TRUE, '2024-01-03', '2024-01-03 12:00:00', '2024-01-03 12:00:00 +00:00')
        """)
        cur.execute("CREATE OR REPLACE TABLE SCALAR_ACTUAL AS SELECT * FROM SCALAR_GOLDEN")
        cur.execute("UPDATE SCALAR_ACTUAL SET amount = 999.99 WHERE id = 2")  # one deliberate diff

        # ---- nested pair -------------------------------------------------------
        cur.execute("CREATE OR REPLACE TABLE NESTED_GOLDEN (id NUMBER, tags ARRAY, attrs OBJECT, line_items ARRAY)")
        cur.execute("""
            INSERT INTO NESTED_GOLDEN
            SELECT 1,
                   ARRAY_CONSTRUCT('a', 'b', 'c'),
                   OBJECT_CONSTRUCT('color', 'red', 'size', 'm'),
                   ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('sku', 'X1', 'qty', 2), OBJECT_CONSTRUCT('sku', 'X2', 'qty', 1))
            UNION ALL
            SELECT 2,
                   ARRAY_CONSTRUCT(1, 2, 3),
                   OBJECT_CONSTRUCT('color', 'blue', 'size', 'l'),
                   ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('sku', 'Y1', 'qty', 5))
        """)
        cur.execute("CREATE OR REPLACE TABLE NESTED_ACTUAL AS SELECT * FROM NESTED_GOLDEN")
        cur.execute(
            "UPDATE NESTED_ACTUAL SET attrs = OBJECT_CONSTRUCT('color', 'blue', 'size', 'xl') WHERE id = 2"
        )  # one deliberate diff, inside the nested OBJECT

        print("Built SCALAR_GOLDEN/SCALAR_ACTUAL and NESTED_GOLDEN/NESTED_ACTUAL "
              "in the configured database/schema. Each pair has exactly 1 row changed (id=2).")
    finally:
        con.close()


if __name__ == "__main__":
    main()
