"""PRISM's analyser, checked against a query whose right answers are known.

``sql/insight_plus/f_demand_portfolio_hourly.sql`` has a hand-written case beside
it that a human derived and then verified against a live cluster. That makes it
the only fixture worth having: every number below was established by a person
reading the query, so a PRISM that reproduces them is a PRISM that read the query
the same way.

Everything here is offline and takes milliseconds. No warehouse, no rowparity.
"""

import os

import pytest

from prism.analyse import (
    AGGREGATE_FUNCTIONS,
    analyse,
    classify_arrays,
    count_branches,
    find_breakdown_column,
    is_metric,
    outermost_function,
    output_name,
    split_dimensions_and_metrics,
    strip_comments,
)

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SQL = os.path.join(REPO, "sql", "insight_plus", "f_demand_portfolio_hourly.sql")

# Established by hand, before PRISM existed. See tests/test_insight_plus_case.py.
KNOWN_DIMENSIONS = 83
KNOWN_METRICS = 179
KNOWN_BRANCHES = 3
KNOWN_BREAKDOWN = "slot_user_drop_off"
KNOWN_BREAKDOWN_VALUES = ["Included", "Not Applicable", "Removed"]
KNOWN_UNORDERED = ["global_advertiser_ids", "global_brand_ids"]
KNOWN_CONSTRUCTED = ["slot_ad_unit_ids", "time_position_classes"]
KNOWN_PLACEHOLDERS = {"facts", "sampling_filter", "arena.presto.var.process_batch_id"}


@pytest.fixture(scope="module")
def sql():
    if not os.path.isfile(SQL):
        pytest.skip(f"{SQL} not present")
    with open(SQL, encoding="utf-8") as fh:
        return fh.read()


@pytest.fixture(scope="module")
def profile():
    if not os.path.isfile(SQL):
        pytest.skip(f"{SQL} not present")
    return analyse(SQL)


class TestTheSelectListParser:
    """The riskiest part of PRISM: get this wrong and all four files are wrong."""

    def test_it_accounts_for_every_output_column(self, sql):
        dims, metrics, unparsed = split_dimensions_and_metrics(sql)
        assert unparsed == [], f"could not name: {unparsed[:3]}"
        assert len(dims) == KNOWN_DIMENSIONS
        assert len(metrics) == KNOWN_METRICS

    def test_comments_are_stripped_before_splitting(self):
        # A comment containing a comma tears a SELECT item in half if you split
        # first, and a commented-out column reads as a real one.
        sql = "\nselect\n  a,  -- keep this, or not\n  --, ivt_indicator\n  b\nfrom (x)"
        assert "ivt_indicator" not in strip_comments(sql)
        dims, _, unparsed = split_dimensions_and_metrics(sql)
        assert dims == ["a", "b"]
        assert unparsed == []

    def test_a_function_call_with_commas_stays_one_item(self):
        sql = "\nselect\n  coalesce(x, y, -1) as z,\n  w\nfrom (t)"
        dims, _, _ = split_dimensions_and_metrics(sql)
        assert dims == ["z", "w"]

    @pytest.mark.parametrize("item,expected", [
        ("coalesce(a, -1) as user_country_id", "user_country_id"),
        ("t.network_id", "network_id"),
        ("network_id", "network_id"),
        ("sum(x) AS revenue", "revenue"),
        ("case when a then b end", None),          # no alias -> unnameable
    ])
    def test_output_name(self, item, expected):
        assert output_name(item) == expected

    def test_a_sum_is_a_metric_and_everything_else_a_key(self):
        sql = "\nselect\n  day,\n  sum(x) as total,\n  SUM(y) as other\nfrom (t)"
        dims, metrics, _ = split_dimensions_and_metrics(sql)
        assert dims == ["day"]
        assert metrics == ["total", "other"]


class TestKeysAreDimensionsNeverMetrics:
    """The rule the whole thing rests on: a key must be a dimension.

    A metric in `compare.keys` changes whenever the data does, so nothing pairs
    and every difference becomes missing + added -- the keyless behaviour keys
    exist to escape, arrived at silently.
    """

    @pytest.mark.parametrize("func", [
        "sum", "count", "count_if", "min", "max", "avg", "approx_distinct",
        "array_agg", "arbitrary", "any_value", "stddev", "histogram", "listagg",
    ])
    def test_every_aggregate_produces_a_metric_not_a_key(self, func):
        sql = f"\nselect\n  day,\n  {func}(x) as measure\nfrom (t)"
        dims, metrics, _ = split_dimensions_and_metrics(sql)
        assert dims == ["day"], f"{func}() leaked into the keys"
        assert metrics == ["measure"]

    def test_the_shapes_that_used_to_leak_into_keys(self):
        # Before the fix only sum() was recognised, so all five of these landed
        # in compare.keys.
        sql = ("\nselect\n  day,\n"
               "  sum(revenue) as revenue,\n"
               "  count(*) as impressions,\n"
               "  max(bid) as top_bid,\n"
               "  approx_distinct(user_id) as reach,\n"
               "  count(distinct ad_id) as ads\nfrom (t)")
        dims, metrics, _ = split_dimensions_and_metrics(sql)
        assert dims == ["day"]
        assert len(metrics) == 5

    def test_an_aggregate_NESTED_in_a_dimension_stays_a_dimension(self):
        # The real query's process_stage. set_agg is an aggregate, but it is an
        # implementation detail inside a reduce() that yields one scalar per
        # group -- and the hand-written case has it in keys. "Contains an
        # aggregate" would demote it and drop a real key.
        sql = ("\nselect\n  reduce(set_agg(stage), 0, (a, v) -> a + v, v -> v) "
               "as process_stage,\n  sum(x) as t\nfrom (t)")
        dims, metrics, _ = split_dimensions_and_metrics(sql)
        assert dims == ["process_stage"]
        assert metrics == ["t"]

    def test_position_is_not_used_to_classify(self):
        # "Everything after the first aggregate is a metric" is tempting and
        # wrong: the real query has 13 genuine dimensions after its first sum(),
        # event_date and partition_key among them.
        sql = ("\nselect\n  a,\n  sum(x) as t,\n  event_date,\n"
               "  sum(y) as u,\n  partition_key\nfrom (t)")
        dims, metrics, _ = split_dimensions_and_metrics(sql)
        assert dims == ["a", "event_date", "partition_key"]
        assert metrics == ["t", "u"]

    def test_a_scalar_function_column_is_a_dimension(self):
        sql = "\nselect\n  coalesce(x, -1) as network_id,\n  sum(y) as t\nfrom (t)"
        dims, _, _ = split_dimensions_and_metrics(sql)
        assert dims == ["network_id"]

    @pytest.mark.parametrize("item,expected", [
        ("sum(f.metric01) as m", "sum"),
        ("coalesce(a, -1) as network_id", "coalesce"),
        ("reduce(set_agg(x), 0, (a,v) -> a+v, v -> v) as stage", "reduce"),
        ("network_id", None),
        ("t.network_id", None),
    ])
    def test_outermost_function(self, item, expected):
        assert outermost_function(item) == expected

    def test_is_metric_reads_the_outermost_call_only(self):
        assert is_metric("sum(f.targeted_listings) as m")
        assert not is_metric("reduce(set_agg(x), 0, (a,v) -> a+v, v -> v) as stage")
        assert not is_metric("network_id")

    def test_the_aggregate_list_covers_the_common_presto_set(self):
        for func in ("sum", "count", "min", "max", "avg", "approx_distinct",
                     "array_agg", "arbitrary", "count_if"):
            assert func in AGGREGATE_FUNCTIONS


class TestBranchCounting:
    def test_the_real_query(self, sql):
        assert count_branches(sql) == KNOWN_BRANCHES

    def test_a_union_named_in_a_comment_is_not_a_branch(self):
        # Comments are stripped first, so prose about unions does not inflate
        # the count -- which would then demand a sampling marker that has no
        # branch to sit in.
        assert count_branches("-- this is a union all of three things\nselect 1") == 1


class TestBreakdownDetection:
    def test_it_finds_the_column_that_partitions_the_union(self, profile):
        assert profile.breakdown_by == KNOWN_BREAKDOWN
        assert profile.breakdown_values == KNOWN_BREAKDOWN_VALUES

    def test_it_requires_one_distinct_literal_per_branch(self):
        # Two branches sharing a literal means the column does not partition the
        # output, and reporting a merged group as one branch would be wrong.
        sql = "select 'A' as kind union all select 'A' as kind union all select 'B' as kind"
        col, vals = find_breakdown_column(sql, ["kind"], branches=3)
        assert col is None and vals == []

    def test_a_single_branch_query_gets_no_breakdown(self):
        col, vals = find_breakdown_column("select 'A' as kind", ["kind"], branches=1)
        assert col is None


class TestArrayClassification:
    """The one classification that looked like it needed a model and did not.

        array[coalesce(col, 'Unknown')]        constructed inline -> ORDERED
        coalesce(source__col, array[])         passed through     -> UNORDERED

    A constructed single-element array cannot vary in order. One that reaches
    the output from a source column can arrive in any order the engine likes.
    """

    def test_the_real_query_matches_what_a_human_chose(self, profile):
        assert profile.unordered_arrays == KNOWN_UNORDERED
        assert profile.constructed_arrays == KNOWN_CONSTRUCTED

    def test_a_constructed_array_is_left_ordered(self):
        sql = "\n, array[coalesce(x, 'Unknown')] as tags\n"
        unordered, constructed = classify_arrays(sql, ["tags"])
        assert constructed == ["tags"] and unordered == []

    def test_a_source_array_is_marked_unordered(self):
        sql = "\n, coalesce(src__tag_ids, array[]) as tag_ids\n"
        unordered, constructed = classify_arrays(sql, ["tag_ids"])
        assert unordered == ["tag_ids"] and constructed == []

    def test_a_non_array_column_is_neither(self):
        sql = "\n, coalesce(x, -1) as network_id\n"
        unordered, constructed = classify_arrays(sql, ["network_id"])
        assert unordered == [] and constructed == []


class TestTheWholeProfile:
    def test_it_reproduces_every_hand_derived_number(self, profile):
        assert len(profile.dimensions) == KNOWN_DIMENSIONS
        assert len(profile.metrics) == KNOWN_METRICS
        assert profile.output_columns == KNOWN_DIMENSIONS + KNOWN_METRICS
        assert profile.branches == KNOWN_BRANCHES
        assert profile.placeholders == KNOWN_PLACEHOLDERS
        assert profile.batch_param == "arena.presto.var.process_batch_id"

    def test_the_three_counts_the_generated_tests_depend_on(self, profile):
        # One per UNION branch, each. A count that is short by one is a branch
        # reading a hardcoded catalog, an unsampled branch, or a branch pinned
        # to a different window -- on BOTH sides, so the totals stay plausible.
        assert profile.fact_refs == KNOWN_BRANCHES
        assert profile.sampling_markers == KNOWN_BRANCHES
        assert profile.batch_refs == KNOWN_BRANCHES

    def test_no_metric_reached_the_dimensions(self, profile):
        # Every dimension becomes a key, so this is the invariant that matters.
        assert set(profile.dimensions).isdisjoint(profile.metrics)
        assert profile.aggregates_seen == ["sum"]

    def test_the_shared_dimension_catalog_is_recognised(self, profile):
        assert profile.shared_catalogs == ["db.default"]

    def test_the_only_issues_are_the_two_known_ones(self, profile):
        # Both are advisory, and both are expected on this query:
        #   - row_summary is a presentation choice, so PRISM always says so
        #   - process_stage is reduce(set_agg(...)), a dimension with an
        #     aggregate nested inside, which is worth a look and not an error
        # Any THIRD issue means the analyser regressed.
        assert len(profile.issues) == 2, profile.issues
        assert any("row_summary" in i for i in profile.issues)
        assert any("process_stage" in i for i in profile.issues)


class TestItSaysWhatItCouldNotDecide:
    """The issues list is a deliverable. A generator that silently guesses is
    worse than one that says what it guessed."""

    def _issues(self, sql, tmp_path):
        p = tmp_path / "q.sql"
        p.write_text(sql, encoding="utf-8")
        return analyse(str(p)).issues

    def test_a_missing_facts_placeholder_is_flagged(self, tmp_path):
        sql = "\nselect a, sum(b) as t\nfrom (select 1) x\n"
        assert any("${facts}" in i for i in self._issues(sql, tmp_path))

    def test_a_branch_without_a_sampling_marker_is_flagged(self, tmp_path):
        sql = ("\nselect a, sum(b) as t\nfrom (\n"
               "select 1 from ${facts}.x where ${sampling_filter} --sampling filter\n"
               "union all select 2 from ${facts}.y\n) z\n")
        assert any("sampling" in i for i in self._issues(sql, tmp_path))

    def test_a_query_with_no_batch_parameter_is_flagged(self, tmp_path):
        sql = "\nselect a, sum(b) as t\nfrom ${facts}.x\n"
        assert any("batch" in i for i in self._issues(sql, tmp_path))

    def test_unions_with_nothing_to_partition_them_are_flagged(self, tmp_path):
        sql = ("\nselect a, sum(b) as t\nfrom (\n"
               "select 1 from ${facts}.x union all select 2 from ${facts}.y\n) z\n")
        assert any("breakdown_by" in i for i in self._issues(sql, tmp_path))
