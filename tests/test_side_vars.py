"""Per-side ``vars:`` -- one query file, two sides, different places to read.

The Hoover comparison ran the same 2,000-line aggregate against two layouts
that differ only in which catalog the fact tables live in. Expressing that as
two SQL files meant 185 KB of duplication per query and a test whose whole job
was to diff them; at 137 queries that is 274 files nobody can review. A side's
own ``vars:`` block collapses it to one file.

The interesting part is not the substitution -- that machinery already existed
for ``${batch_id}``. It is the precedence: a side var beats ``--param``, which
is backwards from every other variable in the system, and the tests below pin
that inversion along with the reason for it.
"""
import os
import textwrap

import pytest

from rowparity.cases import discover_cases
from rowparity.compare import IdenticalSourcesError
from rowparity.params import ParamError, merge_side_vars, resolve_variables
from rowparity.sources import load_source


class TestMergeSideVars:
    def test_a_side_var_lands_in_the_mapping(self):
        assert merge_side_vars({"facts": "a"}, {})["facts"] == "a"

    def test_case_variables_survive_alongside_it(self):
        merged = merge_side_vars({"facts": "a"}, {"batch": "1"})
        assert merged == {"facts": "a", "batch": "1"}

    def test_the_side_wins_over_the_case(self):
        merged = merge_side_vars({"facts": "mine"}, {"facts": "shared"})
        assert merged["facts"] == "mine"

    def test_names_are_lower_cased_like_everywhere_else(self):
        assert merge_side_vars({"FACTS": "a"}, {})["facts"] == "a"

    def test_values_are_stringified(self):
        # YAML yields ints happily; placeholders substitute as text.
        assert merge_side_vars({"n": 59}, {}) == {"n": "59"}

    def test_no_side_vars_is_a_passthrough_copy(self):
        base = {"a": "1"}
        assert merge_side_vars(None, base) == base
        assert merge_side_vars(None, base) is not base, "must not alias the caller's dict"

    def test_it_does_not_mutate_the_case_variables(self):
        # Both sides merge off the same dict. Mutating it would mean whichever
        # side loaded first silently redefined the other.
        base = {"facts": "shared"}
        merge_side_vars({"facts": "mine"}, base)
        assert base == {"facts": "shared"}


class TestPrecedenceInversion:
    """A side var outranks --param, unlike every other variable.

    Deliberate: a side var is half of what makes the two sides different, not a
    run-time knob. A --param reaching both sides would point them at the same
    place and produce a confident EQUIVALENT for comparing a table with itself.
    """

    def test_a_cli_param_does_not_override_a_side_var(self):
        variables = resolve_variables(cli_params={"facts": "from_cli"}, env={})
        assert merge_side_vars({"facts": "from_side"}, variables)["facts"] == "from_side"

    def test_an_env_var_does_not_override_a_side_var(self):
        variables = resolve_variables(env={"ROWPARITY_VAR_FACTS": "from_env"})
        assert merge_side_vars({"facts": "from_side"}, variables)["facts"] == "from_side"

    def test_a_templated_side_var_stays_cli_controllable(self):
        # The escape hatch. A side that wants to be overridable says so by
        # templating its value; the case loader resolves ${...} in the spec
        # before the side var is ever consulted, so the CLI reaches it.
        variables = resolve_variables(cli_params={"old_catalog": "staging"}, env={})
        # substitute_spec has already turned "${old_catalog}" into "staging" by
        # the time the spec reaches a load, so the side var holds the resolved text.
        assert merge_side_vars({"facts": variables["old_catalog"]}, variables)["facts"] == "staging"

    def test_a_param_still_reaches_a_name_no_side_claims(self):
        # The common case must keep working: the batch id is shared by both
        # sides and comes from --param.
        variables = resolve_variables(cli_params={"batch": "20260812"}, env={})
        assert merge_side_vars({"facts": "a"}, variables)["batch"] == "20260812"


class TestLoadSourceAppliesThem:
    def test_the_side_var_reaches_the_query_file(self, tmp_path):
        (tmp_path / "q.sql").write_text("SELECT '${facts}' AS catalog")
        spec = {
            "type": "duckdb",
            "database": ":memory:",
            "query_file": "q.sql",
            "vars": {"facts": "mrm_log_flat.default"},
        }
        table = load_source(spec, base_dir=str(tmp_path))
        assert table.column("catalog").to_pylist() == ["mrm_log_flat.default"]

    def test_a_spec_without_vars_still_gets_none_not_an_empty_dict(self, tmp_path):
        # resolve_query reads `variables is not None` as "substitution is in
        # play". Handing it {} instead of None would start rejecting ${...} in
        # files that previously passed through untouched.
        sql = tmp_path / "q.sql"
        sql.write_text("SELECT 1 AS a -- ${not_a_param}")
        spec = {"type": "duckdb", "database": ":memory:", "query_file": "q.sql"}
        table = load_source(spec, base_dir=str(tmp_path))
        assert table.num_rows == 1

    def test_two_sides_of_one_file_produce_different_queries(self, tmp_path):
        sql = tmp_path / "q.sql"
        sql.write_text("SELECT ${n} AS n")
        common = {"type": "duckdb", "database": ":memory:", "query_file": "q.sql"}
        a = load_source({**common, "vars": {"n": "1"}}, base_dir=str(tmp_path))
        b = load_source({**common, "vars": {"n": "2"}}, base_dir=str(tmp_path))
        assert a.column("n").to_pylist() == [1]
        assert b.column("n").to_pylist() == [2]


# --------------------------------------------------------------------------- #
# The guard: one shared file that resolves the same on both sides
# --------------------------------------------------------------------------- #

CASE_TEMPLATE = """
cases:
  - name: shared_file
    expected:
      type: duckdb
      database: ":memory:"
      query_file: q.sql
      vars: {{facts: {expected_facts}}}
    actual:
      type: duckdb
      database: ":memory:"
      query_file: q.sql
      vars: {{facts: {actual_facts}}}
    compare: {{{compare}}}
"""


def _write_case(tmp_path, expected_facts, actual_facts, compare=""):
    (tmp_path / "q.sql").write_text("SELECT ${facts} AS n")
    (tmp_path / "case.yaml").write_text(
        textwrap.dedent(
            CASE_TEMPLATE.format(
                expected_facts=expected_facts, actual_facts=actual_facts, compare=compare
            )
        )
    )
    cases = discover_cases(str(tmp_path))
    assert len(cases) == 1
    return cases[0]


class TestIdenticalSidesGuard:
    def test_the_same_value_on_both_sides_raises(self, tmp_path):
        case = _write_case(tmp_path, "1", "1")
        with pytest.raises(IdenticalSourcesError):
            case.run()

    def test_different_values_run_normally(self, tmp_path):
        case = _write_case(tmp_path, "1", "2")
        result = case.run()
        assert result.expected_rows == 1 and result.actual_rows == 1

    def test_the_message_names_the_file_and_the_likely_cause(self, tmp_path):
        case = _write_case(tmp_path, "1", "1")
        with pytest.raises(IdenticalSourcesError) as exc:
            case.run()
        message = str(exc.value)
        assert "q.sql" in message
        assert "vars:" in message
        assert "EQUIVALENT" in message, "must say what the silent failure looks like"

    def test_it_raises_before_fetching_anything(self, tmp_path):
        # The whole point is to fail in the first second rather than after the
        # warehouse has spent an hour producing an answer that proves nothing.
        case = _write_case(tmp_path, "1", "1")
        case.expected["database"] = "/nonexistent/path.duckdb"
        with pytest.raises(IdenticalSourcesError):
            case.run()

    def test_it_can_be_opted_out_of(self, tmp_path):
        case = _write_case(tmp_path, "1", "1", compare="allow_identical_sources: true")
        result = case.run()
        assert result.equivalent

    def test_two_different_files_are_not_its_business(self, tmp_path):
        # Only a *shared* file is guarded. Two separate files are two separate
        # queries whose author can see both at once.
        (tmp_path / "a.sql").write_text("SELECT 1 AS n")
        (tmp_path / "b.sql").write_text("SELECT 1 AS n")
        (tmp_path / "case.yaml").write_text(
            textwrap.dedent(
                """
                cases:
                  - name: two_files
                    expected: {type: duckdb, database: ":memory:", query_file: a.sql}
                    actual:   {type: duckdb, database: ":memory:", query_file: b.sql}
                """
            )
        )
        case = discover_cases(str(tmp_path))[0]
        assert case.run().equivalent

    def test_identical_inline_sides_are_not_its_business(self, tmp_path):
        # A hand-written fixture comparing a literal with itself is a normal
        # thing to write when testing plumbing rather than data.
        (tmp_path / "case.yaml").write_text(
            textwrap.dedent(
                """
                cases:
                  - name: inline_both
                    expected: {type: inline, rows: [{id: 1}]}
                    actual:   {type: inline, rows: [{id: 1}]}
                """
            )
        )
        case = discover_cases(str(tmp_path))[0]
        assert case.run().equivalent

    def test_an_unresolvable_var_is_left_to_the_real_load(self, tmp_path):
        # The guard must not turn a missing-parameter error into a confusing
        # one of its own; the operator needs the message that names the param.
        (tmp_path / "q.sql").write_text("SELECT ${nope} AS n")
        (tmp_path / "case.yaml").write_text(
            textwrap.dedent(
                """
                cases:
                  - name: unresolved
                    expected: {type: duckdb, database: ":memory:", query_file: q.sql}
                    actual:   {type: duckdb, database: ":memory:", query_file: q.sql}
                """
            )
        )
        case = discover_cases(str(tmp_path))[0]
        with pytest.raises(ParamError, match="nope"):
            case.run()


class TestTheRealCaseIsWiredThisWay:
    """The insight_plus case is the reason all of the above exists."""

    def test_it_uses_one_file_with_per_side_catalogs(self):
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cases_dir = os.path.join(repo, "scripts", "cases_insight_plus")
        if not os.path.isdir(cases_dir):
            pytest.skip("scripts/cases_insight_plus not present")
        case = discover_cases(cases_dir, {"arena.presto.var.process_batch_id": "1"})[0]
        assert case.expected["query_file"] == case.actual["query_file"]
        assert case.expected["vars"]["facts"] != case.actual["vars"]["facts"]
