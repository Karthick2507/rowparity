"""The shipped Hoover / Hoover++ parity case.

Offline only -- no connection is made. These assert the wiring: that the case
loads, that each side resolves to the right query against the right catalog,
and that the batch parameter cannot be skipped.

That last one carries the most weight. The query files are templated by another
system and carry ``${arena.presto.var.process_batch_id}``. Until dotted names
were recognised, that placeholder matched nothing, so it was neither
substituted nor reported unresolved -- the literal text reached Presto inside
quotes as a syntactically valid predicate matching no batch. Both sides
returned zero rows, the multiset diff found nothing missing and nothing added,
and the run reported EQUIVALENT. A green result proving nothing is the worst
outcome available to a verification tool, so it gets tests.
"""
import os
import re

import pytest
import yaml

from rowparity.cases import Case, discover_cases
from rowparity.params import ParamError
from rowparity.sources import resolve_query

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES_DIR = os.path.join(REPO, "scripts", "cases_insight_plus")
CASE_FILE = os.path.join(CASES_DIR, "f_demand_portfolio_hourly.yaml")
BATCH = "20260812010000"
BATCH_PARAM = "arena.presto.var.process_batch_id"
PARAMS = {BATCH_PARAM: BATCH}


def _case(params=PARAMS) -> Case:
    for case in discover_cases(CASES_DIR, params):
        if case.name == "f_demand_portfolio_hourly":
            return case
    raise AssertionError(f"case not found in {CASES_DIR}")


def _sql(case: Case, side: str) -> str:
    spec = case.expected if side == "expected" else case.actual
    return resolve_query(spec, os.path.dirname(case.source_file), case.variables)


@pytest.fixture(scope="module")
def sql_files_present():
    if not os.path.isdir(os.path.join(REPO, "sql", "insight_plus")):
        pytest.skip("sql/insight_plus not present")


class TestWiring:
    def test_case_loads(self, sql_files_present):
        assert _case().name == "f_demand_portfolio_hourly"

    def test_it_is_a_row_case_not_a_schema_check(self, sql_files_present):
        # Column status falls out of the row comparison; a separate zero-row
        # schema pass would be a second execution of a 2000-line aggregate for
        # information the row result already carries.
        case = _case()
        assert isinstance(case, Case)
        assert case.expected["type"] == "trino"
        assert case.actual["type"] == "trino"

    def test_default_engine_not_pushdown(self, sql_files_present):
        # Push-down re-executes the source query about four times per side.
        # For an aggregate this expensive that is the wrong trade, and the
        # Trino push-down path has never been run against a live cluster.
        assert _case().engine is None

    def test_each_side_reads_its_own_catalog(self, sql_files_present):
        case = _case()
        expected, actual = _sql(case, "expected"), _sql(case, "actual")
        assert "mrm_log_flat.default" in expected
        assert "etl.public_test1" not in expected
        assert "etl.public_test1" in actual
        assert "mrm_log_flat.default" not in actual

    def test_both_sides_carry_the_sampling_filter(self, sql_files_present):
        # Hoover++ was originally unsampled, on the understanding that its
        # source was already the bit-59 sample. A live run disproved that:
        # 2,719 rows against 1,113,423, a ratio of 409. Comparing a sampled
        # side against an unsampled one measures the sampling, not the
        # migration.
        case = _case()
        assert _sql(case, "expected").count("--sampling filter") == 3
        assert _sql(case, "actual").count("--sampling filter") == 3


class TestBatchParameter:
    def test_it_substitutes_on_both_sides(self, sql_files_present):
        case = _case()
        for side in ("expected", "actual"):
            sql = _sql(case, side)
            assert f"process_batch_id = '{BATCH}'" in sql, side
            assert BATCH_PARAM not in sql, f"{side} still carries the placeholder"

    def test_omitting_it_raises_rather_than_running(self, sql_files_present):
        # The false-pass guard. Silence here is what produced a green run over
        # zero rows.
        case = _case(params={})
        with pytest.raises(ParamError) as exc:
            _sql(case, "expected")
        assert BATCH_PARAM in str(exc.value)

    def test_the_yaml_ships_no_default_batch(self, sql_files_present):
        # A literal default would name a batch that ages out, and an aged-out
        # batch returns zero rows on both sides -- equivalent, and meaningless.
        with open(CASE_FILE, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
        assert BATCH_PARAM not in (doc.get("vars") or {})
        for case in doc["cases"]:
            assert BATCH_PARAM not in (case.get("vars") or {})


class TestComparisonSettings:
    def test_keyed_on_the_group_by_dimensions(self, sql_files_present):
        # This case ran keyless first. No row-level identifier survives the
        # GROUP BY, so there appeared to be no key -- but the GROUP BY set
        # itself is one, unique by construction after aggregation. Keyless, a
        # live run gave 158 missing + 217 added with no way to tell drifting
        # metrics from genuinely different groups. See
        # TestKeysMatchTheQueryDimensions below.
        assert _case().config().keys is not None
        assert len(_case().config().keys) == 83

    def test_source_ordered_arrays_are_compared_unordered(self, sql_files_present):
        # rowparity treats list as ORDERED. These two reach the output straight
        # from the source, where Presto guarantees no element order, so without
        # this an ordering difference reads as a data difference.
        unordered = set(_case().config().unordered_list_columns)
        assert {"global_advertiser_ids", "global_brand_ids"} <= unordered

    def test_float_tolerance_is_unset(self, sql_files_present):
        # Deliberately exact until a live run shows whether the metrics are
        # DECIMAL. Loosening later is easy; discovering it was loosened for no
        # reason is not.
        assert "float_tolerance" not in _case().compare

    def test_examples_are_bounded(self, sql_files_present):
        # 100k rows of diff would be unreadable and would bloat every report.
        assert _case().config().max_examples == 50


# --------------------------------------------------------------------------- #
# Keys: the GROUP BY dimensions, kept in sync with the query
# --------------------------------------------------------------------------- #
HOOVER_SQL = os.path.join(
    REPO, "sql", "insight_plus", "f_demand_portfolio_hourly_hoover.sql"
)


def _strip_sql_comments(sql: str) -> str:
    # Before splitting, never after: a comment like "-- no use, could be
    # removed" contains a comma, and splitting first tears the SELECT item in
    # half. Commented-out columns (--,ivt_indicator) would also be read as real
    # ones, which added three phantom dimensions the first time this was tried.
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    return "\n".join(re.sub(r"--.*$", "", line) for line in sql.splitlines())


def _outer_select_items(sql: str):
    """The outer SELECT list, split on top-level commas."""
    body = _strip_sql_comments(sql).split("\nfrom (", 1)[0]
    body = body[body.rfind("\nselect") + len("\nselect"):]
    items, depth, current = [], 0, []
    for ch in body:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            items.append("".join(current))
            current = []
        else:
            current.append(ch)
    items.append("".join(current))
    return [i.strip() for i in items if i.strip()]


def _output_name(item: str):
    m = re.search(r"\bas\s+([a-z_][a-z0-9_]*)\s*$", item, re.I | re.S)
    if m:
        return m.group(1)
    m = re.fullmatch(r"(?:[a-z_][a-z0-9_]*\.)?([a-z_][a-z0-9_]*)", item.strip(), re.I)
    return m.group(1) if m else None


def _dimensions_and_metrics():
    """Split the query's output columns into GROUP BY dimensions and sum() metrics."""
    with open(HOOVER_SQL, encoding="utf-8") as fh:
        sql = fh.read()
    dims, metrics, unparsed = [], [], []
    for item in _outer_select_items(sql):
        name = _output_name(item)
        if name is None:
            unparsed.append(item)
            continue
        (metrics if re.search(r"\bsum\s*\(", item, re.I) else dims).append(name)
    return dims, metrics, unparsed


class TestKeysMatchTheQueryDimensions:
    """The keys are the 83 GROUP BY dimensions.

    Not a business key -- nobody would call it one -- but unique by
    construction after the outer aggregation, which is all a key needs to be.

    This case ran keyless first and the output could not be acted on: 158
    missing + 217 added, with no way to tell whether those were the same
    logical rows with drifting metrics or genuinely different groups, and all
    262 columns flagged because one side had 59 extra rows.

    The risk keys introduce is silent rot: add a column to the SELECT, forget
    this list, and "the same row" quietly means something else. Hence these.
    """

    def test_the_parser_accounts_for_every_output_column(self):
        # If this fails, every assertion below is measuring the wrong thing.
        dims, metrics, unparsed = _dimensions_and_metrics()
        assert unparsed == [], f"could not parse: {unparsed[:3]}"
        assert len(dims) + len(metrics) == 262
        assert len(dims) == 83
        assert len(metrics) == 179

    def test_keys_are_exactly_the_dimensions(self, sql_files_present):
        dims, _, _ = _dimensions_and_metrics()
        assert sorted(_case().config().keys) == sorted(dims)

    def test_no_metric_is_used_as_a_key(self, sql_files_present):
        # Keying on a sum() would make the key change whenever the data does,
        # which pairs nothing and turns every drift into missing + added --
        # exactly the keyless behaviour the keys exist to escape.
        _, metrics, _ = _dimensions_and_metrics()
        assert set(_case().config().keys).isdisjoint(metrics)

    def test_keys_are_unique_names(self, sql_files_present):
        keys = _case().config().keys
        assert len(keys) == len(set(keys))

    def test_array_dimensions_that_may_reorder_are_compared_unordered(self, sql_files_present):
        # These are in the key, so their canonical form decides which rows pair
        # up. If Presto returns the elements in a different order on the two
        # sides, an ordered comparison makes the same group look like two.
        cfg = _case().config()
        unordered = set(cfg.unordered_list_columns)
        for column in ("global_advertiser_ids", "global_brand_ids"):
            assert column in cfg.keys
            assert column in unordered

    def test_the_case_is_keyed_not_keyless(self, sql_files_present):
        assert _case().config().keys, "keys were dropped; the report loses attribution"
