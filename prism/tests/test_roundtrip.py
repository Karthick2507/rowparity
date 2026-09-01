"""Does PRISM reproduce a case a human already wrote?

This is the test that matters. ``f_demand_portfolio_hourly.yaml`` was derived by
hand from its query and then verified against a live cluster, so it is not a
fixture someone invented to make a test pass -- it is a known-correct answer that
predates PRISM.

Every semantic field is asserted equal. ``row_summary`` is asserted *different*,
because it is the one output PRISM derives from column-name rules rather than
from the query: pretending it matched would be the test lying about where the
uncertainty lives.

Offline. No warehouse, no cluster, milliseconds.
"""

import os

import pytest

yaml = pytest.importorskip("yaml")

from prism.analyse import analyse  # noqa: E402
from prism.generate import render_case_yaml  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SQL = os.path.join(REPO, "sql", "insight_plus", "f_demand_portfolio_hourly.sql")
HAND_WRITTEN = os.path.join(
    REPO, "scripts", "cases_insight_plus", "f_demand_portfolio_hourly.yaml"
)


@pytest.fixture(scope="module")
def pair():
    for path in (SQL, HAND_WRITTEN):
        if not os.path.isfile(path):
            pytest.skip(f"{path} not present")
    with open(HAND_WRITTEN, encoding="utf-8") as fh:
        hand = yaml.safe_load(fh)["cases"][0]
    generated = yaml.safe_load(render_case_yaml(analyse(SQL)))["cases"][0]
    return hand, generated


class TestTheComparisonSemantics:
    """Everything that decides what "equal" means. All of it is derived, so all
    of it must match -- a difference here is a PRISM bug, not a style choice."""

    def test_the_keys_are_the_same_83_dimensions(self, pair):
        hand, gen = pair
        assert sorted(gen["compare"]["keys"]) == sorted(hand["compare"]["keys"])

    def test_the_breakdown_column_is_the_same(self, pair):
        hand, gen = pair
        assert gen["compare"]["breakdown_by"] == hand["compare"]["breakdown_by"]

    def test_the_same_arrays_are_compared_unordered(self, pair):
        hand, gen = pair
        assert (sorted(gen["compare"].get("unordered_list_columns") or [])
                == sorted(hand["compare"].get("unordered_list_columns") or []))

    def test_near_miss_and_max_examples_carry_over(self, pair):
        hand, gen = pair
        assert gen["compare"]["near_miss"] == hand["compare"]["near_miss"]
        assert gen["compare"]["max_examples"] == hand["compare"]["max_examples"]


class TestTheWiring:
    def test_both_sides_share_one_query_file(self, pair):
        _, gen = pair
        assert gen["expected"]["query_file"] == gen["actual"]["query_file"]

    def test_each_side_names_the_right_catalog(self, pair):
        hand, gen = pair
        for side in ("expected", "actual"):
            assert gen[side]["vars"]["facts"] == hand[side]["vars"]["facts"]
            assert gen[side]["type"] == hand[side]["type"]

    def test_the_sampling_filter_is_case_level(self, pair):
        hand, gen = pair
        assert gen["vars"]["sampling_filter"] == hand["vars"]["sampling_filter"]
        for side in ("expected", "actual"):
            assert "sampling_filter" not in (gen[side].get("vars") or {})

    def test_no_default_batch_is_shipped(self, pair):
        # A default names a batch that ages out, and an aged-out batch returns
        # zero rows on both sides -- equivalent, and meaningless.
        _, gen = pair
        assert "arena.presto.var.process_batch_id" not in (gen.get("vars") or {})


class TestTheDrilldownBlock:
    def test_bind_kinds_and_time_all_carry_over(self, pair):
        hand, gen = pair
        for field in ("bind", "kinds", "time"):
            assert gen["drilldown"][field] == hand["drilldown"][field], field

    def test_the_time_window_is_asymmetric(self, pair):
        # The migrated side pinned to the batch hour, the source side searched
        # wider -- "the event_date shifted" is the hypothesis under test, and
        # pinning both sides assumes the answer.
        _, gen = pair
        expected = gen["drilldown"]["vars"]["expected"]["time_filter"]
        actual = gen["drilldown"]["vars"]["actual"]["time_filter"]
        assert expected != actual
        assert "batch_hour_start" in expected and "batch_hour_end" in expected
        assert "${batch_hour}" in actual


class TestWhereTheUncertaintyLives:
    """row_summary is the ONE output PRISM guesses at, and the test says so.

    If a model ever replaces prism/rules.py, this is the test that changes --
    and it changing is the signal that the guess got better, not that something
    broke.
    """

    def test_row_summary_is_produced_but_is_not_expected_to_match(self, pair):
        hand, gen = pair
        assert gen["row_summary"], "PRISM produced no row_summary at all"
        hand_labels = [g["label"] for g in hand["row_summary"]]
        gen_labels = [g["label"] for g in gen["row_summary"]]
        # Overlapping, not identical: rules find the obvious groups and one the
        # human chose not to make.
        assert set(gen_labels) & set(hand_labels), "no overlap at all — rules broke"
        assert gen_labels != hand_labels, (
            "rules now reproduce the hand-written grouping exactly. That is good "
            "news, not a failure — update this test to assert equality."
        )

    def test_every_summarised_column_is_a_real_dimension(self, pair):
        # Whatever the grouping decides, it may not invent columns.
        _, gen = pair
        keys = set(gen["compare"]["keys"])
        for group in gen["row_summary"]:
            for column in group["columns"]:
                assert column in keys, f"{column} is not a dimension"

    def test_no_column_is_claimed_by_two_groups(self, pair):
        _, gen = pair
        seen = set()
        for group in gen["row_summary"]:
            for column in group["columns"]:
                assert column not in seen, f"{column} appears twice"
                seen.add(column)


class TestTheInlinedParserDoesNotDrift:
    """The generated test carries its OWN copy of the SELECT-list parser.

    That is deliberate -- importing PRISM would make a repo's test suite depend
    on a code generator at run time -- but a copy can drift from the original,
    and when it does the generated test disagrees with the YAML PRISM generated
    beside it. That already happened once: analyse.py learned to recognise
    aggregates beyond sum() and the inlined copy did not, so the case listed 83
    keys while its own test computed a different set.

    This executes the inlined copy and compares it against the real one.
    """

    def test_the_copy_classifies_identically(self):
        import re as _re
        import types

        from prism.analyse import split_dimensions_and_metrics
        from prism.generate import render_case_test

        if not os.path.isfile(SQL):
            pytest.skip(f"{SQL} not present")

        source = render_case_test(analyse(SQL))
        # Pull just the parser out of the generated module and run it.
        module = types.ModuleType("generated_parser")
        module.__dict__["re"] = _re
        start = source.index("def _strip_sql_comments")
        end = source.index("class TestKeysMatchTheQueryDimensions")
        exec(compile(source[start:end], "<generated>", "exec"), module.__dict__)  # noqa: S102

        with open(SQL, encoding="utf-8") as fh:
            sql = fh.read()
        theirs_dims, theirs_metrics = [], []
        for item in module._outer_select_items(sql):
            name = module._output_name(item)
            if name is None:
                continue
            (theirs_metrics if module._is_metric(item) else theirs_dims).append(name)

        ours_dims, ours_metrics, _ = split_dimensions_and_metrics(sql)
        assert theirs_dims == ours_dims, "the inlined parser has drifted on dimensions"
        assert theirs_metrics == ours_metrics, "the inlined parser has drifted on metrics"

    def test_the_copy_knows_the_same_aggregates(self):
        from prism.analyse import AGGREGATE_FUNCTIONS
        from prism.generate import render_case_test

        if not os.path.isfile(SQL):
            pytest.skip(f"{SQL} not present")
        source = render_case_test(analyse(SQL))
        for func in AGGREGATE_FUNCTIONS:
            assert f"'{func}'" in source, f"{func} missing from the inlined aggregate set"
