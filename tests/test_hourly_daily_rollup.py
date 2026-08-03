"""Hourly-vs-daily rollup validation — the "testing ETL within the same/across
engines" use case: prove a stored daily aggregate equals what you'd get by
re-aggregating the hourly data on the fly, not just eyeballing that it "looks
right."

Modeled on a real setup where hourly lands in one engine (e.g. Spark) and
daily lands in another (e.g. Snowflake): here both sides are built via DuckDB
so the whole thing runs standalone, but the pattern is identical to a real
YAML case — swap `type: duckdb` for `type: spark` / `type: snowflake` and
nothing else changes. rowparity doesn't do the rollup itself; the rollup is
just the SQL on the "expected" side, same as any other source query.

expected = SUM(hourly) computed fresh, grouped to daily grain
actual   = the (possibly stale/buggy) stored daily table
"""
import duckdb
import pyarrow as pa
import pytest

from rowparity import CompareConfig, compare_tables

DAYS = ["2026-07-01", "2026-07-02", "2026-07-03"]
REGIONS = ["US", "EU"]


def _hourly_table(con, corrupt=None):
    """Deterministic synthetic hourly data: 3 days x 2 regions x 24 hours.

    corrupt: optional (day, region, hour) -> "drop" | "duplicate", to simulate
    a missing or double-counted hour landing in the hourly source itself.
    """
    con.execute("""
        CREATE OR REPLACE TABLE hourly AS
        SELECT
            (d.day::date + INTERVAL (hr.hour) HOUR) AS hour_ts,
            r.region,
            round(100 + hr.hour * 3.37 + day(d.day::date) * 17
                  + (CASE WHEN r.region = 'EU' THEN 50 ELSE 0 END), 2) AS revenue,
            (10 + hr.hour % 5) AS orders
        FROM (SELECT unnest(?) AS day) d
        CROSS JOIN (SELECT unnest(?) AS region) r
        CROSS JOIN (SELECT * FROM generate_series(0, 23) AS t(hour)) hr
    """, [DAYS, REGIONS])

    if corrupt:
        day, region, hour = corrupt[:3]
        action = corrupt[3]
        if action == "drop":
            con.execute(
                "DELETE FROM hourly WHERE hour_ts = ?::date + INTERVAL (?) HOUR AND region = ?",
                [day, hour, region],
            )
        elif action == "duplicate":
            con.execute(
                """INSERT INTO hourly
                   SELECT * FROM hourly
                   WHERE hour_ts = ?::date + INTERVAL (?) HOUR AND region = ?""",
                [day, hour, region],
            )


def _rollup_hourly_to_daily(con) -> "duckdb.DuckDBPyRelation":
    return con.sql("""
        SELECT hour_ts::date AS day, region,
               SUM(revenue) AS revenue, SUM(orders)::bigint AS orders
        FROM hourly
        GROUP BY 1, 2
    """)


def _rollup_arrow(con) -> pa.Table:
    """Materialize the on-the-fly hourly->daily rollup as a real pa.Table
    (DuckDB's .arrow() can hand back a streaming RecordBatchReader)."""
    out = _rollup_hourly_to_daily(con).arrow()
    return out.read_all() if isinstance(out, pa.RecordBatchReader) else out


@pytest.fixture
def con():
    c = duckdb.connect(":memory:")
    yield c
    c.close()


def test_daily_rollup_matches_hourly_aggregate(con):
    """The common case: the stored daily table was built correctly from hourly."""
    _hourly_table(con)
    expected = _rollup_arrow(con)  # computed fresh from hourly
    actual = _rollup_arrow(con)  # stand-in for the stored daily table, built correctly

    r = compare_tables(expected, actual, CompareConfig(keys=["day", "region"], float_tolerance=0.01))
    assert r.equivalent, r.summary()
    assert r.expected_rows == len(DAYS) * len(REGIONS)


def test_daily_rollup_tolerates_cross_engine_numeric_noise(con):
    """SUM() over a rounded expression comes back DECIMAL here (confirmed:
    decimal128(38,2)) — exactly what SUM(revenue) typically returns from
    Snowflake/Spark too. Decimal comparison is EXACT by default (no
    float_tolerance leniency, matching hashing.py's documented behavior), so
    tiny cross-engine summation noise needs coerce_numeric_to_float as well
    as float_tolerance — this proves that combination actually absorbs it
    without masking the genuine discrepancies the tests below inject."""
    _hourly_table(con)
    expected = _rollup_arrow(con)
    daily = _rollup_arrow(con)
    assert pa.types.is_decimal(daily.schema.field("revenue").type)  # the scenario this test is actually about

    # simulate summation-order noise on the stored side, well under 1 cent
    import pyarrow.compute as pc
    noisy_revenue = pc.add(daily.column("revenue"), 0.0003)
    actual = daily.set_column(daily.schema.get_field_index("revenue"), "revenue", noisy_revenue)

    cfg_exact = CompareConfig(keys=["day", "region"], float_tolerance=0.01)
    r_exact = compare_tables(expected, actual, cfg_exact)
    assert not r_exact.equivalent, "sanity check: decimal noise IS visible without coerce_numeric_to_float"

    cfg_coerced = CompareConfig(keys=["day", "region"], float_tolerance=0.01, coerce_numeric_to_float=True)
    r_coerced = compare_tables(expected, actual, cfg_coerced)
    assert r_coerced.equivalent, r_coerced.summary()


def test_daily_rollup_catches_a_dropped_hour(con):
    """A real failure mode: one hour never made it into the stored daily
    aggregate (e.g. a late-arriving Spark partition), so daily undercounts
    for exactly that (day, region) — everything else must still match."""
    _hourly_table(con)
    expected = _rollup_arrow(con)  # fresh rollup: all 24 hours

    _hourly_table(con, corrupt=("2026-07-02", "US", 14, "drop"))  # simulate the stored daily's source was short one hour
    actual = _rollup_arrow(con)

    r = compare_tables(expected, actual, CompareConfig(keys=["day", "region"], float_tolerance=0.01))
    assert not r.equivalent
    assert r.changed_count == 1
    bad = r.examples[0]
    assert bad.key == (("D", "2026-07-02"), ("t", "US"))
    changed_cols = {c.column for c in bad.columns}
    assert changed_cols == {"revenue", "orders"}


def test_daily_rollup_catches_a_double_counted_hour(con):
    """The opposite failure mode: an hour got processed twice into the daily
    aggregate (e.g. a re-run ETL job without idempotent dedup)."""
    _hourly_table(con)
    expected = _rollup_arrow(con)

    _hourly_table(con, corrupt=("2026-07-03", "EU", 9, "duplicate"))
    actual = _rollup_arrow(con)

    r = compare_tables(expected, actual, CompareConfig(keys=["day", "region"], float_tolerance=0.01))
    assert not r.equivalent
    assert r.changed_count == 1
    assert r.examples[0].key == (("D", "2026-07-03"), ("t", "EU"))


def test_daily_rollup_keyless_multiset_also_catches_drift(con):
    """Same check, keyless — useful when the daily table has no clean composite
    key you're willing to declare (the tool's own recommendation for that case)."""
    _hourly_table(con)
    expected = _rollup_arrow(con)

    _hourly_table(con, corrupt=("2026-07-01", "US", 3, "drop"))
    actual = _rollup_arrow(con)

    r = compare_tables(expected, actual, CompareConfig(float_tolerance=0.01))
    assert not r.equivalent
    assert r.missing_count == 1  # the correct (day, region, revenue, orders) row is gone
    assert r.added_count == 1    # replaced by a row with the wrong revenue/orders
