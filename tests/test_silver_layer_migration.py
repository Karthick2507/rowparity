"""Regression tests for an incremental silver-layer overhaul: a baseline view
reshapes the OLD silver layer into the NEW silver layer's schema so gold
consumers can start adapting before the real overhaul is ready. Two distinct
regressions matter before the eventual cutover (baseline -> real new silver
layer), and — per the discussion this was designed from — neither needs new
rowparity features, only the right test shape:

1. SCHEMA regression — the baseline view's columns/types must keep matching
   the contract the real new silver layer will eventually expose, or gold
   consumers built against the baseline break the moment the source swaps.
   Needs no real data at all: compare_tables() on two EMPTY, correctly-typed
   tables with strict_columns=True is a pure "does the contract hold" check.

2. LOGIC regression — as the real new silver layer gets built out, its
   in-progress output should already agree with the baseline for whatever it
   currently implements. This is the "harder, but important" one — solved
   not with new machinery but by *scoping*: select/ignore_columns to only
   the columns the new pipeline has actually ported, filter to only the
   entities it currently covers, and read change_signatures as a running
   list of what's still diverging. Comparing everything unscoped is also
   shown below, deliberately, to make the point: unscoped just reports
   "not built yet" as noise indistinguishable from a real bug; scoping is
   what turns the same comparison into a real regression signal.
"""
from datetime import date
from decimal import Decimal

import pyarrow as pa
import pyarrow.compute as pc

from rowparity import CompareConfig, compare_tables

# The schema the fully-overhauled silver layer commits to exposing. This is
# the frozen contract gold-layer consumers are already coding against via the
# baseline view.
CONTRACT_SCHEMA = pa.schema([
    pa.field("order_id", pa.int64()),
    pa.field("customer_id", pa.int64()),
    pa.field("order_date", pa.date32()),
    pa.field("channel", pa.string()),
    pa.field("revenue", pa.decimal128(18, 2)),
    pa.field("discount_amount", pa.decimal128(18, 2)),
    pa.field("is_returned", pa.bool_()),
])


def _empty(schema: pa.Schema) -> pa.Table:
    return pa.Table.from_arrays([pa.array([], type=f.type) for f in schema], schema=schema)


# --------------------------------------------------------------------------- #
# 1. Schema regression — baseline view vs. the frozen future contract
# --------------------------------------------------------------------------- #

def test_baseline_view_matches_target_schema_contract():
    """The baseline (interim adapter) view's schema, as it is today, must
    already match the contract the real new silver layer will expose. No
    rows needed — this is purely "does the shape hold." """
    baseline_schema = CONTRACT_SCHEMA  # today, the adapter view conforms exactly
    r = compare_tables(_empty(CONTRACT_SCHEMA), _empty(baseline_schema), CompareConfig(strict_columns=True))
    assert r.equivalent, r.type_mismatches


def test_schema_contract_catches_a_retyped_column():
    """A real failure mode: someone building the adapter used DOUBLE for
    revenue instead of the contracted DECIMAL(18,2) — structurally invisible
    in a quick eyeball, but it'll break gold-layer code doing exact decimal
    math the moment the source swaps. strict_columns must catch it now,
    not after the cutover."""
    drifted = pa.schema([
        f if f.name != "revenue" else pa.field("revenue", pa.float64())
        for f in CONTRACT_SCHEMA
    ])
    r = compare_tables(_empty(CONTRACT_SCHEMA), _empty(drifted), CompareConfig(strict_columns=True))
    assert not r.equivalent
    assert r.type_mismatches == [("revenue", "decimal128(18, 2)", "double")]


def test_schema_contract_catches_a_missing_column():
    """The adapter hasn't back-filled `channel` yet — fine as a known gap
    during the build-out, but it must show up explicitly, not silently pass."""
    partial = pa.schema([f for f in CONTRACT_SCHEMA if f.name != "channel"])
    r = compare_tables(_empty(CONTRACT_SCHEMA), _empty(partial), CompareConfig(strict_columns=True))
    assert not r.equivalent
    assert r.columns_only_in_expected == ["channel"]


# --------------------------------------------------------------------------- #
# 2. Logic regression — baseline values vs. the new pipeline's in-progress output
# --------------------------------------------------------------------------- #

def _baseline_orders() -> pa.Table:
    """The interim adapter's output: 10 orders, fully populated, matching
    CONTRACT_SCHEMA. Treated as ground truth for whatever the new pipeline
    has gotten to so far."""
    return pa.table({
        "order_id": list(range(1, 11)),
        "customer_id": [100, 100, 101, 101, 102, 102, 103, 103, 104, 104],
        "order_date": pa.array(
            [date(2026, 7, d) for d in range(1, 11)], type=pa.date32()
        ),
        "channel": ["web", "app", "web", "web", "app", "app", "web", "app", "web", "app"],
        "revenue": pa.array(
            [Decimal(v) for v in ["120.00", "85.50", "310.25", "44.00", "199.99",
                                   "60.00", "150.00", "20.00", "500.00", "75.25"]],
            type=pa.decimal128(18, 2),
        ),
        "discount_amount": pa.array(
            [Decimal(v) for v in ["0.00", "5.00", "10.00", "0.00", "20.00",
                                   "0.00", "15.00", "0.00", "50.00", "0.00"]],
            type=pa.decimal128(18, 2),
        ),
        "is_returned": [False, False, False, True, False, False, False, False, True, False],
    }, schema=CONTRACT_SCHEMA)


def _new_silver_partial() -> pa.Table:
    """The real overhaul's current, incomplete output:
      - only orders 1-7 processed so far (8-10 not built yet: a known gap)
      - `channel` not back-filled yet (a known gap)
      - order_id=3's discount_amount is WRONG: applied twice (a real bug,
        not a known gap — this is what the logic regression must catch)
    Same schema shape otherwise, no `channel` column.
    """
    schema = pa.schema([f for f in CONTRACT_SCHEMA if f.name != "channel"])
    return pa.table({
        "order_id": [1, 2, 3, 4, 5, 6, 7],
        "customer_id": [100, 100, 101, 101, 102, 102, 103],
        "order_date": pa.array([date(2026, 7, d) for d in range(1, 8)], type=pa.date32()),
        "revenue": pa.array(
            [Decimal(v) for v in ["120.00", "85.50", "310.25", "44.00", "199.99", "60.00", "150.00"]],
            type=pa.decimal128(18, 2),
        ),
        "discount_amount": pa.array(
            [Decimal(v) for v in ["0.00", "5.00", "20.00", "0.00", "20.00", "0.00", "15.00"]],  # order 3: 20.00 not 10.00 -- bug
            type=pa.decimal128(18, 2),
        ),
        "is_returned": [False, False, False, True, False, False, False],
    }, schema=schema)


def test_logic_regression_unscoped_drowns_the_real_bug_in_known_gaps():
    """Comparing everything, unscoped, is what "just diff the two tables"
    naively looks like — and it correctly reports missing rows / missing
    columns for known gaps, but that's exactly the problem: those known
    gaps and the one real bug all show up as the same kind of "different,"
    with nothing to tell them apart at a glance."""
    baseline = _baseline_orders()
    partial = _new_silver_partial()

    r = compare_tables(baseline, partial, CompareConfig(keys=["order_id"]))
    assert not r.equivalent
    assert r.columns_only_in_expected == ["channel"]  # known gap, column-level
    assert r.missing_count == 3   # orders 8,9,10 -- known gap, not-yet-built
    assert r.changed_count == 1   # order 3's discount bug -- the actual regression
    # nothing in the result distinguishes "known gap" from "real bug" without
    # the reader already knowing which columns/entities are supposed to be ready


def test_logic_regression_scoped_to_ready_columns_and_entities_isolates_the_bug():
    """Scope to exactly what the new pipeline claims is ready: the columns
    it has ported (select, excluding channel) and the entities it has
    processed (filter both sides to order_id <= 7). What's left is a clean
    apples-to-apples check of ported logic -- and it should surface only
    the one real bug, nothing else."""
    baseline = _baseline_orders().filter(pc.field("order_id") <= 7)
    partial = _new_silver_partial()

    cfg = CompareConfig(
        keys=["order_id"],
        select=["order_id", "customer_id", "order_date", "revenue", "discount_amount", "is_returned"],
    )
    r = compare_tables(baseline, partial, cfg)

    assert not r.equivalent
    assert r.missing_count == 0
    assert r.added_count == 0
    assert r.changed_count == 1
    bad = r.examples[0]
    assert bad.key == (("i", 3),)
    assert {c.column for c in bad.columns} == {"discount_amount"}
    assert (bad.columns[0].expected, bad.columns[0].actual) == (Decimal("10.00"), Decimal("20.00"))


def test_logic_regression_confirms_the_rest_of_ported_logic_is_correct():
    """The flip side, worth asserting explicitly: once scoped, the other 6
    already-ported orders show zero drift -- the baseline and the new
    pipeline agree wherever the new pipeline claims to be done, aside from
    the one known bug."""
    baseline = _baseline_orders().filter(pc.field("order_id") <= 7)
    partial = _new_silver_partial()
    cfg = CompareConfig(
        keys=["order_id"],
        select=["order_id", "customer_id", "order_date", "revenue", "discount_amount", "is_returned"],
    )
    r = compare_tables(baseline, partial, cfg)
    assert r.changed_count == 1  # only the known bug, out of 7 compared orders
