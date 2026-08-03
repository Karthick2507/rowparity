"""Concept check: N old tables collapsed into one wide table, "drift" means
a business concept has no home anymore -- not exact structural schema
equality. Covers schema_introspect.py (metadata-only, never touches row
data) and concept_check.py's core algorithm, plus the YAML/CLI path.
"""
import duckdb
import pyarrow as pa
import pytest

from rowparity.cases import discover_cases, load_cases_from_file
from rowparity.concept_check import ConceptCheckError, run_concept_check
from rowparity.schema_introspect import describe_source


@pytest.fixture
def star_db(tmp_path):
    """orders/customers/products -> gold_orders_wide, with a deliberately lost
    concept (customers.region), an unaccounted new column (loyalty_tier), and
    two columns that legitimately renamed (cust_id/id -> customer_id)."""
    db_path = str(tmp_path / "star.duckdb")
    con = duckdb.connect(db_path)
    con.execute("CREATE TABLE orders (order_id BIGINT, cust_id BIGINT, amount DECIMAL(18,2), status VARCHAR)")
    con.execute("CREATE TABLE customers (id BIGINT, email VARCHAR, region VARCHAR)")
    con.execute("CREATE TABLE products (sku VARCHAR, category VARCHAR)")
    con.execute("""
        CREATE TABLE gold_orders_wide (
            order_id BIGINT, customer_id BIGINT, amount DECIMAL(18,2), status VARCHAR,
            customer_email VARCHAR, sku VARCHAR, category VARCHAR, loyalty_tier VARCHAR
        )
    """)
    con.close()
    return db_path


def _sources(db_path):
    return {
        "orders": {"type": "duckdb", "database": db_path, "table": "orders"},
        "customers": {"type": "duckdb", "database": db_path, "table": "customers"},
        "products": {"type": "duckdb", "database": db_path, "table": "products"},
    }


def _full_map():
    return [
        {"from": {"source": "orders", "column": "cust_id"}, "to": "customer_id"},
        {"from": {"source": "customers", "column": "id"}, "to": "customer_id"},
        {"from": {"source": "customers", "column": "email"}, "to": "customer_email"},
    ]


# --------------------------------------------------------------------------- #
# schema_introspect.py: metadata-only, never touches row data
# --------------------------------------------------------------------------- #

def test_describe_duckdb_table(star_db):
    schema = describe_source({"type": "duckdb", "database": star_db, "table": "orders"})
    assert schema == {"order_id": "BIGINT", "cust_id": "BIGINT", "amount": "DECIMAL(18,2)", "status": "VARCHAR"}


def test_describe_duckdb_query(star_db):
    schema = describe_source({"type": "duckdb", "database": star_db, "query": "SELECT order_id FROM orders"})
    assert schema == {"order_id": "BIGINT"}


def test_describe_never_scans_row_data(tmp_path):
    # a table with real, populated rows -- describe_source must not need to read them
    db_path = str(tmp_path / "big.duckdb")
    con = duckdb.connect(db_path)
    con.execute("CREATE TABLE t AS SELECT range AS id FROM range(1000000)")
    con.close()
    # if this touched the actual column data it would still be fast at 1M rows,
    # so the real assertion is behavioral: works identically on a 0-row table too
    schema_with_data = describe_source({"type": "duckdb", "database": db_path, "table": "t"})

    con = duckdb.connect(db_path)
    con.execute("DELETE FROM t")
    con.close()
    schema_empty = describe_source({"type": "duckdb", "database": db_path, "table": "t"})
    assert schema_with_data == schema_empty == {"id": "BIGINT"}


def test_describe_parquet_footer_only(tmp_path):
    import pyarrow.parquet as pq
    path = str(tmp_path / "p.parquet")
    pq.write_table(pa.table({"sku": ["a", "b"], "price": [1.5, 2.5]}), path)
    schema = describe_source({"type": "parquet", "path": path})
    assert schema == {"sku": "string", "price": "double"}


def test_describe_inline_explicit_schema():
    schema = describe_source({"type": "inline", "schema": {"id": "int64", "name": "string"}, "rows": []})
    assert schema == {"id": "int64", "name": "string"}


def test_describe_inline_inferred():
    schema = describe_source({"type": "inline", "rows": [{"id": 1, "amt": 1.5}]})
    assert schema == {"id": "int64", "amt": "double"}


def test_describe_unknown_type_raises():
    from rowparity.sources import SourceError
    with pytest.raises(SourceError):
        describe_source({"type": "not_a_real_type"})


# --------------------------------------------------------------------------- #
# concept_check.py: the core algorithm
# --------------------------------------------------------------------------- #

def test_lost_concept_and_unaccounted_column_detected(star_db):
    target = {"type": "duckdb", "database": star_db, "table": "gold_orders_wide"}
    r = run_concept_check(_sources(star_db), target, _full_map())

    assert not r.equivalent
    assert r.columns_only_in_expected == ["customers.region"]  # lost: no mapping, no same-name match
    assert r.columns_only_in_actual == ["loyalty_tier"]  # unaccounted: not the target of anything
    assert r.type_mismatches == []


def test_implicit_same_name_match_needs_no_mapping(star_db):
    # order_id, amount, status, sku, category all kept their names -- zero
    # concept_map entries needed for any of them to be considered covered.
    target = {"type": "duckdb", "database": star_db, "table": "gold_orders_wide"}
    r = run_concept_check(_sources(star_db), target, concept_map=[])
    lost = set(r.columns_only_in_expected)
    # only the columns that actually got renamed should be flagged without a map
    assert lost == {"orders.cust_id", "customers.id", "customers.email", "customers.region"}
    assert "orders.order_id" not in lost
    assert "orders.amount" not in lost
    assert "products.sku" not in lost


def test_fully_mapped_and_accounted_is_equivalent(star_db):
    # add back a mapping for the region concept and account for loyalty_tier
    target = {"type": "duckdb", "database": star_db, "table": "gold_orders_wide"}
    full_map = _full_map() + [{"from": {"source": "customers", "column": "region"}, "to": "loyalty_tier"}]
    r = run_concept_check(_sources(star_db), target, full_map)
    assert r.equivalent
    assert r.columns_only_in_expected == []
    assert r.columns_only_in_actual == []


def test_strict_unmapped_target_isolated(tmp_path):
    # a minimal scenario with nothing lost, only one unaccounted target column,
    # to cleanly isolate strict_unmapped_target's effect from "lost concept".
    db_path = str(tmp_path / "t.duckdb")
    con = duckdb.connect(db_path)
    con.execute("CREATE TABLE src (id BIGINT)")
    con.execute("CREATE TABLE wide (id BIGINT, extra_new_col VARCHAR)")
    con.close()
    sources = {"src": {"type": "duckdb", "database": db_path, "table": "src"}}
    target = {"type": "duckdb", "database": db_path, "table": "wide"}

    r_lenient = run_concept_check(sources, target, strict_unmapped_target=False)
    assert r_lenient.equivalent  # nothing lost -> passes despite the new column
    assert r_lenient.columns_only_in_actual == ["extra_new_col"]

    r_strict = run_concept_check(sources, target, strict_unmapped_target=True)
    assert not r_strict.equivalent  # same data, but strict mode now fails on it
    assert r_strict.columns_only_in_actual == ["extra_new_col"]


def test_type_mismatch_on_matched_concept_detected(tmp_path):
    db_path = str(tmp_path / "t.duckdb")
    con = duckdb.connect(db_path)
    con.execute("CREATE TABLE src (amount DECIMAL(18,2))")
    con.execute("CREATE TABLE wide (amount DOUBLE)")  # same name, different type
    con.close()
    r = run_concept_check(
        {"src": {"type": "duckdb", "database": db_path, "table": "src"}},
        {"type": "duckdb", "database": db_path, "table": "wide"},
        concept_map=[],
    )
    assert not r.equivalent
    assert r.type_mismatches == [("src.amount -> amount", "DECIMAL(18,2)", "DOUBLE")]


def test_stale_concept_map_entry_raises(star_db):
    target = {"type": "duckdb", "database": star_db, "table": "gold_orders_wide"}
    bad_map = _full_map() + [{"from": {"source": "orders", "column": "does_not_exist"}, "to": "customer_id"}]
    with pytest.raises(ConceptCheckError, match="orders.does_not_exist"):
        run_concept_check(_sources(star_db), target, bad_map)


def test_no_sources_raises():
    with pytest.raises(ConceptCheckError):
        run_concept_check({}, {"type": "inline", "rows": []})


# --------------------------------------------------------------------------- #
# YAML / CLI path
# --------------------------------------------------------------------------- #

def test_concept_check_case_from_yaml(star_db, tmp_path):
    case_yaml = tmp_path / "case.yaml"
    case_yaml.write_text(f"""
name: gold_orders_wide_concept_check
tags: [gold, remodel]
concept_check:
  sources:
    orders:    {{type: duckdb, database: "{star_db}", table: orders}}
    customers: {{type: duckdb, database: "{star_db}", table: customers}}
    products:  {{type: duckdb, database: "{star_db}", table: products}}
  target:
    type: duckdb
    database: "{star_db}"
    table: gold_orders_wide
  concept_map:
    - from: {{source: orders, column: cust_id}}
      to: customer_id
    - from: {{source: customers, column: id}}
      to: customer_id
    - from: {{source: customers, column: email}}
      to: customer_email
""")
    cases = load_cases_from_file(str(case_yaml))
    assert len(cases) == 1
    case = cases[0]
    assert case.name == "gold_orders_wide_concept_check"
    assert case.tags == ["gold", "remodel"]

    result = case.run()
    assert not result.equivalent
    assert result.columns_only_in_expected == ["customers.region"]


def test_discover_cases_mixes_regular_and_concept_check(star_db, tmp_path):
    (tmp_path / "regular.yaml").write_text("""
name: a_regular_case
expected: {type: inline, rows: [{id: 1}]}
actual: {type: inline, rows: [{id: 1}]}
""")
    (tmp_path / "concept.yaml").write_text(f"""
name: a_concept_check
concept_check:
  sources:
    orders: {{type: duckdb, database: "{star_db}", table: orders}}
  target: {{type: duckdb, database: "{star_db}", table: gold_orders_wide}}
""")
    cases = discover_cases(str(tmp_path))
    names = sorted(c.name for c in cases)
    assert names == ["a_concept_check", "a_regular_case"]
    for c in cases:
        result = c.run()
        assert result is not None  # both run through the same interface without special-casing