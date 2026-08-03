"""Build TPC-H example data for all rowparity feature demonstrations.

Uses DuckDB's built-in TPC-H extension — no file download or cloud account needed.
Scale factor 0.01 gives ~15 000 orders and ~60 000 line items; runs in seconds.

Run once:  python examples/build_tpch_data.py
"""
import os

import duckdb

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
os.makedirs(DATA, exist_ok=True)
DB = os.path.join(DATA, "tpch.duckdb")

if os.path.exists(DB):
    os.remove(DB)

con = duckdb.connect(DB)
con.execute("INSTALL tpch; LOAD tpch; CALL dbgen(sf=0.01)")

# ── Case A: keyed regression ──────────────────────────────────────────────────
# Golden snapshot of orders with tiny float noise on o_totalprice.
# float_tolerance=0.001 in the YAML covers the 0.0001 noise → case passes.
# o_comment is excluded here and via ignore_columns in the YAML.
con.execute(f"""
COPY (
    SELECT o_orderkey, o_custkey, o_orderstatus,
           o_totalprice + 0.0001 AS o_totalprice,
           o_orderdate, o_orderpriority
    FROM orders
) TO '{DATA}/orders_golden.parquet' (FORMAT PARQUET)
""")

# ── Case B: column subset / pricing audit ─────────────────────────────────────
# Golden stores only the pricing columns of lineitem plus a derived net_price.
con.execute(f"""
COPY (
    SELECT l_orderkey, l_linenumber,
           l_extendedprice, l_discount, l_tax,
           CAST(l_extendedprice * (1 - l_discount) AS DECIMAL(15,2)) AS net_price
    FROM lineitem
) TO '{DATA}/lineitem_pricing_golden.parquet' (FORMAT PARQUET)
""")

# ── Case C: string normalization ──────────────────────────────────────────────
# Simulates a legacy system that exports names in UPPERCASE and pads addresses.
# trim_strings + case_insensitive in the YAML make the comparison pass.
con.execute(f"""
COPY (
    SELECT c_custkey,
           upper(c_name)              AS c_name,
           '  ' || c_address || '  '  AS c_address,
           c_mktsegment
    FROM customer
) TO '{DATA}/customers_legacy.parquet' (FORMAT PARQUET)
""")

# ── Case D: backward-compatible view with nested list<struct> ─────────────────
# Golden: orders with line_items as list<struct>, each list ordered by l_linenumber.
con.execute(f"""
COPY (
    SELECT o.o_orderkey,
           o.o_orderstatus,
           o.o_totalprice,
           list(struct_pack(
               l_linenumber := l.l_linenumber,
               l_partkey    := l.l_partkey,
               l_quantity   := l.l_quantity,
               l_extprice   := l.l_extendedprice
           ) ORDER BY l.l_linenumber) AS line_items
    FROM orders o
    JOIN lineitem l ON o.o_orderkey = l.l_orderkey
    GROUP BY o.o_orderkey, o.o_orderstatus, o.o_totalprice
) TO '{DATA}/orders_nested_golden.parquet' (FORMAT PARQUET)
""")

# ── Case D / D2: views in the DuckDB warehouse ───────────────────────────────
# Good BCV: reassembles line items in the correct order (matches golden).
con.execute("""
CREATE VIEW orders_nested_compat AS
SELECT o.o_orderkey,
       o.o_orderstatus,
       o.o_totalprice,
       list(struct_pack(
           l_linenumber := l.l_linenumber,
           l_partkey    := l.l_partkey,
           l_quantity   := l.l_quantity,
           l_extprice   := l.l_extendedprice
       ) ORDER BY l.l_linenumber) AS line_items
FROM orders o
JOIN lineitem l ON o.o_orderkey = l.l_orderkey
GROUP BY o.o_orderkey, o.o_orderstatus, o.o_totalprice
""")

# Broken BCV: lineitem stored in reversed l_linenumber order; no ORDER BY in the
# aggregate → lists come back in wrong order, exactly what QA must catch.
con.execute("""
CREATE TABLE lineitem_shuffled AS
SELECT * FROM lineitem ORDER BY l_orderkey, l_linenumber DESC
""")

con.execute("""
CREATE VIEW orders_nested_broken AS
SELECT o.o_orderkey,
       o.o_orderstatus,
       o.o_totalprice,
       list(struct_pack(
           l_linenumber := l.l_linenumber,
           l_partkey    := l.l_partkey,
           l_quantity   := l.l_quantity,
           l_extprice   := l.l_extendedprice
       )) AS line_items
FROM orders o
JOIN lineitem_shuffled l ON o.o_orderkey = l.l_orderkey
GROUP BY o.o_orderkey, o.o_orderstatus, o.o_totalprice
""")

# ── Case E: schema drift ──────────────────────────────────────────────────────
# Golden has 6 columns. The actual query returns all 9 (3 extra columns added
# upstream). strict_columns: true in the YAML catches this immediately.
con.execute(f"""
COPY (
    SELECT o_orderkey, o_custkey, o_orderstatus,
           o_totalprice, o_orderdate, o_orderpriority
    FROM orders
) TO '{DATA}/orders_schema_golden.parquet' (FORMAT PARQUET)
""")

# ── Case G: unordered list columns ───────────────────────────────────────────
# Golden: each customer's order priorities sorted ASC.
# Actual (in the DB): sorted DESC — different order, same multiset.
# unordered_list_columns: [priorities] makes the case pass.
con.execute(f"""
COPY (
    SELECT c.c_custkey, c.c_name,
           list(o.o_orderpriority ORDER BY o.o_orderpriority ASC) AS priorities
    FROM customer c
    JOIN orders o ON c.c_custkey = o.o_custkey
    GROUP BY c.c_custkey, c.c_name
) TO '{DATA}/customer_priorities_golden.parquet' (FORMAT PARQUET)
""")

con.execute("""
CREATE VIEW customer_priorities_actual AS
SELECT c.c_custkey, c.c_name,
       list(o.o_orderpriority ORDER BY o.o_orderpriority DESC) AS priorities
FROM customer c
JOIN orders o ON c.c_custkey = o.o_custkey
GROUP BY c.c_custkey, c.c_name
""")

con.close()
print(f"TPC-H data written to {DATA}/tpch.duckdb and parquet snapshots")
