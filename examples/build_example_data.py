"""Build a self-contained example warehouse so the sample cases run with no cloud.

Scenario 1 (`daily_revenue`) is built by a REAL dbt project (examples/dbt_project,
using the dbt-duckdb adapter, `pip install -e ".[dbt]"`) -- not simulated. dbt
seeds raw_orders.csv and runs models/daily_revenue.sql (a genuine SUM/COUNT
aggregation) to build the table `rowparity run` actually compares against.
Scenarios 2/3 (the BCV migration demo) remain a lightweight DuckDB stand-in
below since they were never dbt-specific. In production these same cases
would point their ``actual`` source at Snowflake / Iceberg instead of this
DuckDB file — the assertions do not change either way.

Run once:  python examples/build_example_data.py
"""
import os
import subprocess

import duckdb

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
os.makedirs(DATA, exist_ok=True)
DB = os.path.join(DATA, "warehouse.duckdb")
DBT_PROJECT = os.path.join(HERE, "dbt_project")

if os.path.exists(DB):
    os.remove(DB)

# --------------------------------------------------------------------------- #
# Scenario 1: a REAL dbt model, and its "expected" golden snapshot. `dbt build`
# seeds + runs + tests directly against DB -- ROWPARITY_DBT_DB_PATH is how
# examples/dbt_project/profiles.yml locates it (an absolute path, so this
# doesn't depend on dbt's cwd-relative-path resolution).
# --------------------------------------------------------------------------- #
subprocess.run(
    ["dbt", "build", "--project-dir", DBT_PROJECT, "--profiles-dir", DBT_PROJECT],
    check=True, env=dict(os.environ, ROWPARITY_DBT_DB_PATH=DB),
)

con = duckdb.connect(DB)

# Golden snapshot the QA team blessed (note: revenue stored with tiny fp noise
# to prove the float tolerance in the case actually matters).
con.execute("""
COPY (
    SELECT day, region, revenue + 0.0000001 AS revenue, orders
    FROM daily_revenue
) TO '%s' (FORMAT PARQUET);
""" % os.path.join(DATA, "daily_revenue_expected.parquet"))

# --------------------------------------------------------------------------- #
# Scenario 2: complex nested data + a backward-compatible view.
#
# orders_v1 is the ORIGINAL user-facing shape:
#   items:      LIST<STRUCT<sku, qty>>   (ordered line items)
#   attributes: MAP<STRING,STRING>       (unordered)
#
# DE migrated to a normalised v2 (exploded line items + a header table).
# They ship a backward-compatible VIEW `orders_v1_compat` that reconstructs the
# exact v1 shape so downstream users don't have to change anything.
# --------------------------------------------------------------------------- #
con.execute("""
CREATE TABLE orders_v1 AS
SELECT * FROM (VALUES
    (1, 'alice',
        [{'sku':'A','qty':2}, {'sku':'B','qty':1}],
        MAP(['color','size'], ['red','L']),
        CAST(31.98 AS DECIMAL(10,2))),
    (2, 'bob',
        [{'sku':'C','qty':5}],
        MAP(['color'], ['blue']),
        CAST(50.00 AS DECIMAL(10,2))),
    (3, 'carol',
        [{'sku':'D','qty':1}, {'sku':'E','qty':3}, {'sku':'F','qty':2}],
        MAP(['color','size'], ['green','M']),
        CAST(72.25 AS DECIMAL(10,2)))
) AS t(order_id, customer, items, attributes, total);
""")

# Golden snapshot of v1 (this is the "expected" the QA team compares BCV against).
con.execute(
    "COPY orders_v1 TO '%s' (FORMAT PARQUET);" % os.path.join(DATA, "orders_v1_expected.parquet")
)

# Normalised v2: header + exploded line items, intentionally stored in SHUFFLED
# row order and shuffled line order to prove order-independence of the check.
con.execute("""
CREATE TABLE orders_v2_header AS
SELECT * FROM (VALUES
    (2, 'bob',   'blue', NULL,  CAST(50.00 AS DECIMAL(10,2))),
    (3, 'carol', 'green','M',   CAST(72.25 AS DECIMAL(10,2))),
    (1, 'alice', 'red',  'L',   CAST(31.98 AS DECIMAL(10,2)))
) AS t(order_id, customer, color, size, total);
""")
con.execute("""
CREATE TABLE orders_v2_lines AS
SELECT * FROM (VALUES
    (3, 2, 'E', 3),      -- rows deliberately out of (order_id, line_no) order
    (1, 1, 'A', 2),
    (3, 1, 'D', 1),
    (2, 1, 'C', 5),
    (1, 2, 'B', 1),
    (3, 3, 'F', 2)
) AS t(order_id, line_no, sku, qty);
""")

# The backward-compatible view: reassemble v1 exactly.
#   - items rebuilt as an ORDERED list<struct> using line_no (preserves order)
#   - attributes rebuilt as a MAP, only for non-null keys
con.execute("""
CREATE VIEW orders_v1_compat AS
WITH lines AS (
    SELECT order_id,
           list(struct_pack(sku := sku, qty := qty) ORDER BY line_no) AS items
    FROM orders_v2_lines
    GROUP BY order_id
),
attrs AS (
    SELECT order_id,
           map(
             list(k) FILTER (WHERE v IS NOT NULL),
             list(v) FILTER (WHERE v IS NOT NULL)
           ) AS attributes
    FROM (
        SELECT order_id, 'color' AS k, color AS v FROM orders_v2_header
        UNION ALL
        SELECT order_id, 'size'  AS k, size  AS v FROM orders_v2_header
    ) GROUP BY order_id
)
SELECT h.order_id, h.customer, l.items, a.attributes, h.total
FROM orders_v2_header h
JOIN lines l USING (order_id)
JOIN attrs a USING (order_id);
""")

# A deliberately BROKEN compat view: it forgets ORDER BY line_no, so the items
# list can come back in the wrong order — the kind of regression QA must catch.
con.execute("""
CREATE VIEW orders_v1_compat_broken AS
WITH lines AS (
    SELECT order_id,
           list(struct_pack(sku := sku, qty := qty)) AS items  -- NO order by line_no
    FROM orders_v2_lines
    GROUP BY order_id
),
attrs AS (
    SELECT order_id,
           map(list(k) FILTER (WHERE v IS NOT NULL),
               list(v) FILTER (WHERE v IS NOT NULL)) AS attributes
    FROM (
        SELECT order_id, 'color' AS k, color AS v FROM orders_v2_header
        UNION ALL
        SELECT order_id, 'size'  AS k, size  AS v FROM orders_v2_header
    ) GROUP BY order_id
)
SELECT h.order_id, h.customer, l.items, a.attributes,
       h.total - 1.00 AS total          -- also drops a dollar, to show a scalar diff
FROM orders_v2_header h
JOIN lines l USING (order_id)
JOIN attrs a USING (order_id);
""")

con.close()
print(f"Built {DB} and parquet snapshots in {DATA}")
