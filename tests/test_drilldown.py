"""Generated (not executed) investigation SQL for one differing row.

A parity run names the aggregate rows that disagree. It cannot name the
underlying transactions, because the compared query is a GROUP BY that collapses
every per-request identifier. Recovering them takes a second query against the
raw table, and today an engineer writes it by hand: copy a value out of the
report, paste it into a 40-line WHERE clause, run it once per side.

This generates both queries with the row's values already substituted. It
deliberately stops there -- see the module docstring for why running them is a
separate step.

The tests below are mostly about the ways generated SQL can be wrong *and still
run*: a null compared with ``=``, an apostrophe that ends a literal early, a
placeholder left unresolved. Each of those returns a clean empty result rather
than an error, which reads as "nothing found" and is the worst possible failure
for a debugging aid.
"""
import textwrap

import pytest

from rowparity.cases import discover_cases
from rowparity.compare import RowDiff
from rowparity.drilldown import (
    DrilldownConfig,
    DrilldownError,
    build_row_filter,
    generate,
    sql_literal,
)


class TestSqlLiteral:
    def test_integers_are_bare(self):
        assert sql_literal(3320114) == "3320114"

    def test_negative_sentinels_survive(self):
        # -1 is the "not applicable" sentinel throughout this data, and it is
        # a value like any other -- not a null, not a missing filter.
        assert sql_literal(-1) == "-1"

    def test_strings_are_quoted(self):
        assert sql_literal("Included") == "'Included'"

    def test_an_apostrophe_is_doubled(self):
        # Not injection defence -- these values came from the warehouse a
        # moment ago. It is so the generated SQL parses instead of failing
        # somewhere the reader has to debug.
        assert sql_literal("O'Brien") == "'O''Brien'"

    def test_booleans_are_sql_booleans(self):
        assert sql_literal(True) == "true"
        assert sql_literal(False) == "false"

    def test_null_is_null_not_the_string(self):
        assert sql_literal(None) == "null"


BIND = [{"column": "creative_id",
         "expression": "if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1)"}]


class TestRowFilter:
    def test_it_uses_the_expression_not_the_alias(self):
        # creative_id in the parity output is an if(...) over the source
        # columns. Filtering on the alias would not compile against the raw
        # table at all.
        sql = build_row_filter({"creative_id": 3320114}, BIND)
        assert sql.startswith("if(network_is_ad_owner")
        assert sql.endswith("= 3320114")

    def test_a_null_uses_is_null(self):
        # "= null" is never true in SQL, so the query would return nothing and
        # look like a clean "this row does not exist over there" -- the exact
        # wrong answer for a tool whose job is finding missing rows.
        assert build_row_filter({"creative_id": None}, BIND).endswith("is null")

    def test_a_minus_one_sentinel_is_an_equality_not_a_null(self):
        assert build_row_filter({"creative_id": -1}, BIND).endswith("= -1")

    def test_several_binds_are_anded(self):
        bind = [{"column": "a", "expression": "a"}, {"column": "b", "expression": "b"}]
        sql = build_row_filter({"a": 1, "b": 2}, bind)
        assert "a = 1" in sql and "b = 2" in sql and "and" in sql

    def test_binding_a_column_the_query_lacks_is_refused(self):
        # Silently skipping it would widen the filter and return unrelated
        # transactions, presented as this row's.
        with pytest.raises(DrilldownError, match="not a column"):
            build_row_filter({"other": 1}, BIND)


class TestConfig:
    def test_a_mapping_keeps_the_expression(self):
        cfg = DrilldownConfig.from_yaml(
            {"query_file": "q.sql", "bind": {"creative_id": "if(x, y, -1)"}}
        )
        assert cfg.bind == [{"column": "creative_id", "expression": "if(x, y, -1)"}]

    def test_a_bare_list_binds_columns_to_themselves(self):
        cfg = DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["creative_id"]})
        assert cfg.bind == [{"column": "creative_id", "expression": "creative_id"}]

    def test_a_bare_string_is_one_column(self):
        cfg = DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": "creative_id"})
        assert len(cfg.bind) == 1

    def test_no_block_means_no_drilldown(self):
        assert DrilldownConfig.from_yaml(None) is None

    def test_a_missing_query_file_is_refused(self):
        with pytest.raises(DrilldownError, match="query_file"):
            DrilldownConfig.from_yaml({"bind": ["creative_id"]})

    def test_an_empty_bind_is_refused(self):
        # Without a bind the query is not about this row at all.
        with pytest.raises(DrilldownError, match="bind"):
            DrilldownConfig.from_yaml({"query_file": "q.sql"})

    def test_a_typo_is_refused_rather_than_ignored(self):
        with pytest.raises(DrilldownError, match="unknown"):
            DrilldownConfig.from_yaml({"query_file": "q.sql", "bind": ["a"], "max_row": 5})


# --------------------------------------------------------------------------- #
# Generation, with the two sides resolving differently
# --------------------------------------------------------------------------- #

DRILL_SQL = """\
select request__transaction_id
from ${facts}.ack
where ${time_filter}
  and ${row_filter}
"""


class _Result:
    def __init__(self, examples):
        self.examples = examples
        self.expected_label, self.actual_label = "Hoover", "Hoover++"


def _sides():
    return [
        {"label": "Hoover", "spec": {"type": "trino", "vars": {
            "facts": "mrm_log_flat.default", "time_filter": "event_date >= timestamp '2026-08-27 00:00:00'"}}},
        {"label": "Hoover++", "spec": {"type": "trino", "vars": {
            "facts": "etl.public_test1", "time_filter": "process_batch_id = '20260827010000'"}}},
    ]


@pytest.fixture
def sql_dir(tmp_path):
    (tmp_path / "drill.sql").write_text(DRILL_SQL)
    return tmp_path


def _generate(sql_dir, rows, max_rows=10):
    cfg = DrilldownConfig(query_file="drill.sql", bind=BIND, max_rows=max_rows)
    return generate(cfg, _Result(rows), _sides(), str(sql_dir))


def _diff(kind="missing", creative_id=3320114):
    row = {"creative_id": creative_id}
    return RowDiff(
        kind=kind,
        key=(("i", creative_id),),
        expected_row=row if kind != "added" else None,
        actual_row=row if kind == "added" else None,
    )


class TestGeneration:
    def test_one_query_per_side(self, sql_dir):
        out = _generate(sql_dir, [_diff()])
        assert [q.side for q in out[0].queries] == ["Hoover", "Hoover++"]

    def test_each_side_reads_its_own_catalog(self, sql_dir):
        hoover, plus = _generate(sql_dir, [_diff()])[0].queries
        assert "mrm_log_flat.default.ack" in hoover.sql
        assert "etl.public_test1.ack" in plus.sql

    def test_the_time_windows_are_asymmetric(self, sql_dir):
        # Deliberate: the migrated side is pinned to the batch under test while
        # the source side is searched wider, because "the event_date shifted"
        # is the hypothesis. Pinning both would assume the answer and return
        # nothing on the very rows being investigated.
        hoover, plus = _generate(sql_dir, [_diff()])[0].queries
        assert "timestamp '2026-08-27 00:00:00'" in hoover.sql
        assert "process_batch_id = '20260827010000'" in plus.sql
        assert hoover.sql != plus.sql

    def test_the_row_value_is_substituted_into_both(self, sql_dir):
        for q in _generate(sql_dir, [_diff(creative_id=99)])[0].queries:
            assert "= 99" in q.sql

    def test_no_placeholder_survives(self, sql_dir):
        # An unresolved ${...} reaching Presto inside quotes is a valid string
        # matching nothing: the query runs, returns zero rows, and reads as
        # "not found".
        for q in _generate(sql_dir, [_diff()])[0].queries:
            assert "${" not in q.sql

    def test_an_added_row_reads_the_actual_side(self, sql_dir):
        # A row that exists only in Hoover++ has no expected_row to read from.
        out = _generate(sql_dir, [_diff(kind="added", creative_id=555)])
        assert "= 555" in out[0].queries[0].sql

    def test_max_rows_bounds_the_output(self, sql_dir):
        out = _generate(sql_dir, [_diff(creative_id=i) for i in range(50)], max_rows=3)
        assert len(out) == 3

    def test_the_filter_is_reported_alongside(self, sql_dir):
        # So a reader can see what was pinned without reading 40 lines of SQL.
        assert "3320114" in _generate(sql_dir, [_diff()])[0].filter_sql


class TestFailureIsNotFatal:
    def test_a_broken_drilldown_does_not_sink_the_run(self, tmp_path):
        # A drill-down is an aid to reading the result, not part of it. Losing
        # a 14-minute parity run because a helper template has a typo would be
        # entirely the wrong trade.
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
        assert result.drilldowns == []


class TestTheRealCaseIsWired:
    def test_it_binds_only_creative_id(self):
        import os

        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cases_dir = os.path.join(repo, "scripts", "cases_insight_plus")
        if not os.path.isdir(cases_dir):
            pytest.skip("scripts/cases_insight_plus not present")
        case = discover_cases(cases_dir, {"arena.presto.var.process_batch_id": "1"})[0]
        cfg = DrilldownConfig.from_yaml(case.drilldown)
        assert [b["column"] for b in cfg.bind] == ["creative_id"]
        # The source expression, not the output alias -- the alias does not
        # exist on the raw ack table.
        assert "advertisement__creative_id" in cfg.bind[0]["expression"]

    def test_the_drilldown_sql_has_the_three_placeholders(self):
        import os
        import re

        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(repo, "sql", "insight_plus",
                            "f_demand_portfolio_hourly_drilldown.sql")
        if not os.path.isfile(path):
            pytest.skip("drilldown sql not present")
        with open(path, encoding="utf-8") as fh:
            sql = fh.read()
        # Exactly three, each used once. A placeholder written out inside a
        # comment is still a substitution site -- documenting one that way
        # silently rewrites the comment, which happened once already.
        found = re.findall(r"\$\{(\w+)\}", sql)
        assert sorted(found) == ["facts", "row_filter", "time_filter"]

    def test_the_drilldown_keeps_the_branch_predicates(self):
        import os

        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(repo, "sql", "insight_plus",
                            "f_demand_portfolio_hourly_drilldown.sql")
        if not os.path.isfile(path):
            pytest.skip("drilldown sql not present")
        with open(path, encoding="utf-8") as fh:
            sql = fh.read()
        # If these drift from the parity query, the drill-down looks at a
        # different population than the row it is meant to explain.
        for predicate in (
            "bitwise_and(slot__flags, 64) = 0",
            "coalesce(nw.nw_role, '') in ('CRO', 'R')",
            "supply_source != 4",
            "ack__ack_entity_type",
        ):
            assert predicate in sql, predicate

    def test_the_sampling_filter_is_absent_on_purpose(self):
        import os

        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(repo, "sql", "insight_plus",
                            "f_demand_portfolio_hourly_drilldown.sql")
        if not os.path.isfile(path):
            pytest.skip("drilldown sql not present")
        with open(path, encoding="utf-8") as fh:
            sql = fh.read()
        # This query hunts specific transactions behind an already-identified
        # row. Excluding 511 of every 512 would usually return nothing and read
        # as "the row does not exist".
        assert "bitwise_left_shift(BIGINT '1', 59)" not in sql
