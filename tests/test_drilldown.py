"""Two queries that name the transactions behind every differing row.

Row parity says which aggregate rows disagree; it cannot say which underlying
transactions caused it, because the compared query is a GROUP BY that collapses
per-request identifiers. This runs the query that recovers them -- **once per
side**, with every differing row's creative_id in a single IN-list -- and diffs
the two id sets.

The per-row shape was the obvious first design and the wrong one: twenty
near-identical queries are twenty results to reconcile by hand and twenty scans
of the same partition, when one scan answers all of them.

Most of what is tested here is the ways generated SQL can be wrong *and still
run*: a null inside an IN-list, an apostrophe that ends a literal early, a
placeholder left unresolved. Each returns a clean empty result rather than an
error, which reads as "nothing found" -- the worst possible failure for a
debugging aid.
"""
import textwrap

import pyarrow as pa
import pytest

from rowparity.cases import discover_cases
from rowparity.compare import CompareConfig, compare_tables
from rowparity.drilldown import (
    DrilldownConfig,
    DrilldownError,
    build_in_filter,
    collect_values,
    derive_time_vars,
    generate,
    sql_literal,
)
from rowparity.run_report import build_payload

EXPR = "if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1)"
BIND = [{"column": "creative_id", "expression": EXPR}]
KEYS = ["creative_id", "site_id"]


class TestSqlLiteral:
    def test_integers_are_bare(self):
        assert sql_literal(349617594) == "349617594"

    def test_the_minus_one_sentinel_survives(self):
        assert sql_literal(-1) == "-1"

    def test_strings_are_quoted(self):
        assert sql_literal("Included") == "'Included'"

    def test_an_apostrophe_is_doubled(self):
        # So the SQL parses. These values came from the warehouse a moment ago,
        # so this is not injection defence -- it is not handing the reader a
        # syntax error to debug.
        assert sql_literal("O'Brien") == "'O''Brien'"

    def test_booleans_are_sql_booleans(self):
        assert sql_literal(True) == "true"

    def test_null_is_null_not_the_string(self):
        assert sql_literal(None) == "null"


class TestInFilter:
    def test_it_is_one_in_list_not_many_equalities(self):
        # The whole point of the redesign.
        sql = build_in_filter(EXPR, [1, 2, 3])
        assert sql.count(EXPR) == 1
        assert "in (" in sql
        assert "1" in sql and "2" in sql and "3" in sql

    def test_nulls_are_pulled_out_of_the_list(self):
        # "in (null)" never matches in SQL, so leaving a null in the list would
        # silently drop those rows -- the query returns "not found" for
        # something that was never actually asked about.
        sql = build_in_filter(EXPR, [1, None])
        assert "is null" in sql
        assert "in (\n        1\n    )" in sql

    def test_an_all_null_list_is_only_an_is_null(self):
        sql = build_in_filter(EXPR, [None])
        assert sql == f"{EXPR} is null"
        assert "in (" not in sql

    def test_an_empty_list_is_refused(self):
        # A predicate over nothing would match everything or nothing depending
        # on how it was built; neither is a drill-down.
        with pytest.raises(DrilldownError, match="no values"):
            build_in_filter(EXPR, [])


SCHEMA = pa.schema([("creative_id", pa.int64()), ("site_id", pa.int64()), ("v", pa.int64())])


def _result(missing=(), added=(), changed=()):
    exp = [{"creative_id": c, "site_id": 1, "v": 1} for c in list(missing) + list(changed)]
    act = [{"creative_id": c, "site_id": 1, "v": 1} for c in added]
    act += [{"creative_id": c, "site_id": 1, "v": 2} for c in changed]
    # An explicit schema so a side with no rows still has columns: a
    # schemaless empty table would fail as "key column missing", which is a
    # fixture artefact rather than anything about drill-downs.
    return compare_tables(
        pa.Table.from_pylist(exp, schema=SCHEMA),
        pa.Table.from_pylist(act, schema=SCHEMA),
        CompareConfig(keys=KEYS, max_examples=2),
    )


class TestCollectingValues:
    def test_it_covers_every_differing_row_not_just_the_examples(self):
        # max_examples is 2, so an examples-based collector would find two.
        # At realistic proportions the examples list fills entirely with
        # `missing` rows before an added or changed row is reached, so drawing
        # from it would silently cover one third of the problem.
        r = _result(missing=range(30))
        values, complete, rows = collect_values(r, "creative_id", KEYS, 1000)
        assert len(r.examples) == 2
        assert len(values) == 30 and complete and rows == 30

    def test_all_three_kinds_contribute(self):
        r = _result(missing=[1], added=[2], changed=[3])
        values, _, _ = collect_values(r, "creative_id", KEYS, 1000)
        assert values == [1, 2, 3]

    def test_duplicates_collapse(self):
        # Many differing rows share a creative; the IN-list wants each once.
        r = _result(missing=[7, 7, 7, 8])
        values, _, _ = collect_values(r, "creative_id", KEYS, 1000)
        assert values == [7, 8]

    def test_values_are_sorted_for_a_stable_query(self):
        r = _result(missing=[9, 1, 5])
        values, _, _ = collect_values(r, "creative_id", KEYS, 1000)
        assert values == [1, 5, 9]

    def test_a_non_key_column_falls_back_to_examples_and_says_so(self):
        r = _result(missing=range(30))
        values, complete, _ = collect_values(r, "v", KEYS, 1000)
        assert not complete, "must not claim completeness it does not have"
        assert len(values) <= 2

    def test_a_cap_marks_the_result_incomplete(self):
        r = _result(missing=range(30))
        values, complete, _ = collect_values(r, "creative_id", KEYS, 5)
        assert len(values) == 5 and not complete


class TestDerivingTheTimeWindow:
    """The window follows the run's --param, never a date typed into the case.

    A hardcoded date goes stale the moment someone drills a different batch,
    and nothing in the output says the window was wrong -- the query returns
    rows from some other hour and they look exactly like an answer.
    """

    def test_the_batch_id_becomes_its_hour(self):
        assert derive_time_vars("20260827010000")["batch_hour"] == "2026-08-27 01:00:00"

    def test_the_window_brackets_that_hour(self):
        v = derive_time_vars("20260827010000")
        assert v["batch_hour_start"] == "2026-08-27 00:00:00"   # 1 hour before
        assert v["batch_hour_end"] == "2026-08-27 04:00:00"     # 3 hours after

    def test_the_window_is_configurable(self):
        v = derive_time_vars("20260827010000", hours_before=2, hours_after=2)
        assert v["batch_hour_start"] == "2026-08-26 23:00:00"
        assert v["batch_hour_end"] == "2026-08-27 03:00:00"

    def test_midnight_rolls_the_date_back(self):
        # Clamping to 00:00 on the same day would silently narrow the window
        # exactly where a shifted event_date is most likely to have landed.
        assert derive_time_vars("20260101000000")["batch_hour_start"] == "2025-12-31 23:00:00"

    def test_minutes_and_seconds_are_truncated_to_the_hour(self):
        assert derive_time_vars("20260827013745")["batch_hour"] == "2026-08-27 01:00:00"

    def test_the_date_is_available_on_its_own(self):
        assert derive_time_vars("20260827010000")["batch_date"] == "2026-08-27"

    def test_an_unparseable_batch_id_is_refused(self):
        # Not defaulted to "now" or skipped: a drill-down over the wrong window
        # returns rows that look like an answer.
        with pytest.raises(DrilldownError, match="cannot derive"):
            derive_time_vars("not-a-batch")

    def test_a_missing_param_is_refused_by_name(self):
        cfg = DrilldownConfig.from_yaml({
            "query_file": "q.sql", "bind": ["c"],
            "time": {"param": "arena.presto.var.process_batch_id"},
        })
        with pytest.raises(DrilldownError, match="process_batch_id"):
            cfg.time_vars({})

    def test_no_time_block_derives_nothing(self):
        cfg = DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["c"]})
        assert cfg.time_vars({"anything": "1"}) == {}


class TestConfig:
    def test_a_mapping_keeps_the_expression(self):
        cfg = DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": {"creative_id": EXPR}})
        assert cfg.bind == [{"column": "creative_id", "expression": EXPR}]

    def test_it_executes_by_default(self):
        # Two narrow queries are cheap next to the parity run, and the ids are
        # the actual deliverable.
        assert DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["c"]}).execute

    def test_execution_can_be_turned_off(self):
        cfg = DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["c"], "execute": False})
        assert not cfg.execute

    def test_two_bind_columns_are_refused(self):
        # The predicate is an IN-list over one column's values; two would need
        # tuple-IN semantics and a very different query shape.
        with pytest.raises(DrilldownError, match="exactly one"):
            DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["a", "b"]})

    def test_a_typo_is_refused_rather_than_ignored(self):
        with pytest.raises(DrilldownError, match="unknown"):
            DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["a"], "max_row": 5})


# --------------------------------------------------------------------------- #
# Generation and execution, end to end against DuckDB
# --------------------------------------------------------------------------- #

DRILL_SQL = """\
select * from (values (101, 'a'), (202, 'b'), (303, 'c'))
    as t(request__transaction_id, side)
where ${time_filter} and ${row_filter}
"""


def _sides(a_pred="side <> 'c'", b_pred="side <> 'a'"):
    return [
        {"label": "Hoover", "spec": {"type": "duckdb", "database": ":memory:",
                                     "vars": {"time_filter": a_pred}}},
        {"label": "Hoover++", "spec": {"type": "duckdb", "database": ":memory:",
                                       "vars": {"time_filter": b_pred}}},
    ]


@pytest.fixture
def sql_dir(tmp_path):
    # request__transaction_id doubles as the bound column here so one tiny
    # fixture exercises both the IN-list and the fetch.
    (tmp_path / "drill.sql").write_text(DRILL_SQL)
    return tmp_path


def _generate(sql_dir, values, sides=None, **kw):
    cfg = DrilldownConfig(
        query_file="drill.sql",
        bind=[{"column": "creative_id", "expression": "request__transaction_id"}],
        **kw,
    )
    return cfg, generate(cfg, _result(missing=values), sides or _sides(), str(sql_dir), keys=KEYS)


class TestGeneration:
    def test_one_query_per_side_total(self, sql_dir):
        _, dd = _generate(sql_dir, [101, 202, 303])
        assert len(dd.sides) == 2
        assert [s.label for s in dd.sides] == ["Hoover", "Hoover++"]

    def test_every_value_lands_in_one_in_list(self, sql_dir):
        _, dd = _generate(sql_dir, [101, 202, 303])
        for side in dd.sides:
            assert side.sql.count("in (") == 1
            for value in ("101", "202", "303"):
                assert value in side.sql

    def test_the_sides_differ_only_where_they_should(self, sql_dir):
        _, dd = _generate(sql_dir, [101])
        a, b = dd.sides
        assert a.sql != b.sql
        assert "side <> 'c'" in a.sql and "side <> 'a'" in b.sql

    def test_no_placeholder_survives(self, sql_dir):
        # An unresolved ${...} reaching the engine inside quotes is a valid
        # string matching nothing: the query runs and reads as "not found".
        _, dd = _generate(sql_dir, [101])
        for side in dd.sides:
            assert "${" not in side.sql


class TestPerSideVarsAndDerivedTime:
    def test_the_sides_get_different_windows_from_one_param(self, tmp_path):
        (tmp_path / "drill.sql").write_text(
            "select request__transaction_id from t where ${time_filter} and ${row_filter}")
        cfg = DrilldownConfig.from_yaml({
            "query_file": "drill.sql",
            "bind": {"creative_id": "creative_id"},
            "time": {"param": "batch"},
            "vars": {
                "expected": {"time_filter": "ts >= timestamp '${batch_hour_start}'"},
                "actual": {"time_filter": "ts = timestamp '${batch_hour}'"},
            },
        })
        sides = [{"label": "Hoover", "spec": {"type": "duckdb"}},
                 {"label": "Hoover++", "spec": {"type": "duckdb"}}]
        dd = generate(cfg, _result(missing=[1]), sides, str(tmp_path),
                      {"batch": "20260827010000"}, keys=KEYS)
        # Asymmetric on purpose: pinning both sides to the same hour would
        # assume the answer to "did the event_date shift?".
        assert "ts >= timestamp '2026-08-27 00:00:00'" in dd.sides[0].sql
        assert "ts = timestamp '2026-08-27 01:00:00'" in dd.sides[1].sql

    def test_nothing_is_hardcoded_in_the_generated_sql(self, tmp_path):
        # Change the param, the window must move with it.
        (tmp_path / "drill.sql").write_text(
            "select request__transaction_id from t where ${time_filter} and ${row_filter}")
        cfg = DrilldownConfig.from_yaml({
            "query_file": "drill.sql", "bind": {"creative_id": "creative_id"},
            "time": {"param": "batch"},
            "vars": {
                "expected": {"time_filter": "ts >= timestamp '${batch_hour_start}'"},
                "actual": {"time_filter": "ts = timestamp '${batch_hour}'"},
            },
        })
        sides = [{"label": "A", "spec": {"type": "duckdb"}},
                 {"label": "B", "spec": {"type": "duckdb"}}]
        first = generate(cfg, _result(missing=[1]), sides, str(tmp_path),
                         {"batch": "20260827010000"}, keys=KEYS).sides[1].sql
        second = generate(cfg, _result(missing=[1]), sides, str(tmp_path),
                          {"batch": "20260812130000"}, keys=KEYS).sides[1].sql
        assert "2026-08-27 01:00:00" in first
        assert "2026-08-12 13:00:00" in second


class TestExecution:
    def test_it_fetches_the_transaction_ids(self, sql_dir):
        from rowparity.drilldown import execute

        sides = _sides()
        cfg, dd = _generate(sql_dir, [101, 202, 303], sides)
        execute(dd, cfg, sides, str(sql_dir))
        assert [s.executed for s in dd.sides] == [True, True]
        assert dd.sides[0].transaction_ids == [101, 202]      # side <> 'c'
        assert dd.sides[1].transaction_ids == [202, 303]      # side <> 'a'

    def test_the_id_sets_are_diffed(self, sql_dir):
        from rowparity.drilldown import execute

        sides = _sides()
        cfg, dd = _generate(sql_dir, [101, 202, 303], sides)
        execute(dd, cfg, sides, str(sql_dir))
        # This is the answer the whole feature exists to produce.
        assert dd.only_expected == [101]
        assert dd.only_actual == [303]
        assert dd.in_both == 1

    def test_one_side_failing_does_not_lose_the_other(self, sql_dir):
        from rowparity.drilldown import execute

        sides = _sides()
        cfg, dd = _generate(sql_dir, [101], sides)
        dd.sides[0].sql = "SELECT * FROM no_such_table"
        execute(dd, cfg, sides, str(sql_dir))
        assert dd.sides[0].error and not dd.sides[0].executed
        assert dd.sides[1].executed, "the good side must survive"

    def test_a_failed_side_suppresses_the_diff(self, sql_dir):
        from rowparity.drilldown import execute

        # With one side missing there is nothing to subtract. Rendering the
        # other side's ids as "only in X" would be a fabrication -- they might
        # be on both.
        sides = _sides()
        cfg, dd = _generate(sql_dir, [101], sides)
        dd.sides[0].sql = "SELECT * FROM no_such_table"
        execute(dd, cfg, sides, str(sql_dir))
        assert dd.only_expected == [] and dd.only_actual == [] and dd.in_both == 0

    def test_a_missing_id_column_is_an_error_not_an_empty_list(self, sql_dir):
        from rowparity.drilldown import execute

        sides = _sides()
        cfg, dd = _generate(sql_dir, [101], sides)
        for s in dd.sides:
            s.sql = "SELECT 1 AS something_else"
        execute(dd, cfg, sides, str(sql_dir))
        # Reporting zero ids here would say "no transactions found" about a
        # query that never looked for any.
        assert all("request__transaction_id" in s.error for s in dd.sides)


class TestItReachesTheReport:
    def _payload(self, sql_dir):
        from rowparity.drilldown import execute

        sides = _sides()
        cfg, dd = _generate(sql_dir, [101, 202, 303], sides)
        execute(dd, cfg, sides, str(sql_dir))
        result = _result(missing=[101, 202, 303])
        result.drilldown = dd
        result.expected_label, result.actual_label = "Hoover", "Hoover++"
        return build_payload([("c", result)], [])["cases"][0]["drilldown"]

    def test_the_sql_and_the_ids_are_both_carried(self, sql_dir):
        dd = self._payload(sql_dir)
        assert len(dd["sides"]) == 2
        for side in dd["sides"]:
            assert side["sql"] and side["ids"]

    def test_the_diff_is_carried(self, sql_dir):
        dd = self._payload(sql_dir)
        assert dd["only_expected"] == ["101"]
        assert dd["only_actual"] == ["303"]
        assert dd["in_both"] == 1

    def test_completeness_is_reported(self, sql_dir):
        dd = self._payload(sql_dir)
        assert dd["complete"] is True
        assert dd["rows_covered"] == 3

    def test_a_case_without_a_drilldown_carries_none(self):
        payload = build_payload([("c", _result(missing=[1]))], [])
        assert payload["cases"][0]["drilldown"] is None


class TestFailureIsNotFatal:
    def test_a_broken_drilldown_does_not_sink_the_run(self, tmp_path):
        (tmp_path / "q.sql").write_text("SELECT ${facts} AS n")
        (tmp_path / "case.yaml").write_text(
            textwrap.dedent(
                """
                cases:
                  - name: c
                    expected: {type: duckdb, database: ":memory:", query_file: q.sql,
                               vars: {facts: 1}}
                    actual:   {type: duckdb, database: ":memory:", query_file: q.sql,
                               vars: {facts: 2}}
                    compare: {keys: [n]}
                    drilldown:
                      query_file: does_not_exist.sql
                      bind: [n]
                """
            )
        )
        case = discover_cases(str(tmp_path))[0]
        result = case.run()
        assert result.missing_count == 1 and result.added_count == 1
        assert result.drilldown is None


class TestTheRealCaseIsWired:
    def _case(self):
        import os

        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cases_dir = os.path.join(repo, "scripts", "cases_insight_plus")
        if not os.path.isdir(cases_dir):
            pytest.skip("scripts/cases_insight_plus not present")
        return discover_cases(cases_dir, {"arena.presto.var.process_batch_id": "1"})[0]

    def _sql(self):
        import os

        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(repo, "sql", "insight_plus",
                            "f_demand_portfolio_hourly_drilldown.sql")
        if not os.path.isfile(path):
            pytest.skip("drilldown sql not present")
        with open(path, encoding="utf-8") as fh:
            return fh.read()

    def test_it_binds_only_creative_id(self):
        cfg = DrilldownConfig.from_yaml(self._case().drilldown)
        assert [b["column"] for b in cfg.bind] == ["creative_id"]
        # The source expression, not the output alias -- the alias does not
        # exist on the raw ack table.
        assert "advertisement__creative_id" in cfg.bind[0]["expression"]

    def test_creative_id_is_a_key_so_every_row_is_covered(self):
        # If it were not a key, values would come from the bounded example
        # list, which fills with `missing` rows and never reaches the others.
        assert "creative_id" in self._case().config().keys

    def test_the_time_window_is_derived_from_the_run_parameter(self):
        cfg = DrilldownConfig.from_yaml(self._case().drilldown)
        assert cfg.time and cfg.time["param"] == "arena.presto.var.process_batch_id"
        derived = cfg.time_vars({"arena.presto.var.process_batch_id": "20260827010000"})
        assert derived["batch_hour"] == "2026-08-27 01:00:00"

    def test_no_date_is_hardcoded_anywhere_in_the_case(self):
        # The whole point. A literal date here would silently drill whatever
        # hour was last typed in, regardless of the batch under test.
        import re

        import yaml as _yaml

        with open(self._case().source_file, encoding="utf-8") as fh:
            doc = _yaml.safe_load(fh)
        block = _yaml.safe_dump(doc["cases"][0]["drilldown"])
        assert not re.search(r"20\d\d-\d\d-\d\d \d\d:", block), \
            "a literal timestamp in the drilldown block"
        for side in ("expected", "actual"):
            for value in (doc["cases"][0][side].get("vars") or {}).values():
                assert "timestamp '" not in str(value)

    def test_it_fetches_request_transaction_id(self):
        assert DrilldownConfig.from_yaml(self._case().drilldown).id_column \
            == "request__transaction_id"

    def test_the_sql_has_the_three_placeholders(self):
        import re

        # A ${...} written inside a comment is still a substitution site --
        # documenting one that way silently rewrote the comment, once.
        assert sorted(re.findall(r"\$\{(\w+)\}", self._sql())) == [
            "facts", "row_filter", "time_filter"
        ]

    def test_the_sql_selects_the_id_column_first(self):
        assert "request__transaction_id" in self._sql().split("from")[0]

    def test_the_branch_predicates_are_kept(self):
        sql = self._sql()
        # Drift here means the drill-down looks at a different population than
        # the row it is supposed to explain.
        for predicate in (
            "bitwise_and(slot__flags, 64) = 0",
            "coalesce(nw.nw_role, '') in ('CRO', 'R')",
            "supply_source != 4",
            "ack__ack_entity_type",
        ):
            assert predicate in sql, predicate

    def test_the_sampling_filter_is_absent_on_purpose(self):
        # This hunts specific transactions behind an already-identified row.
        # Excluding 511 of every 512 would usually return nothing and read as
        # "the row does not exist".
        assert "bitwise_left_shift(BIGINT '1', 59)" not in self._sql()
