"""Case parameterisation: ${name} resolution, precedence, and failure modes.

Covers params.py in isolation plus its two integration points -- the case
loader (spec dicts) and resolve_query (query_file contents), which are
substituted at different times and so have to be tested separately.
"""

import pytest

from rowparity.cases import discover_cases, load_cases_from_file
from rowparity.cli import main as cli_main
from rowparity.params import (
    ENV_PREFIX,
    ParamError,
    parse_cli_params,
    resolve_variables,
    substitute,
    substitute_spec,
)
from rowparity.sources import resolve_query


class TestParseCliParams:
    def test_parses_name_value(self):
        assert parse_cli_params(["batch_id=2026", "x=y"]) == {"batch_id": "2026", "x": "y"}

    def test_value_may_contain_equals(self):
        assert parse_cli_params(["q=a=b"]) == {"q": "a=b"}

    def test_none_is_empty(self):
        assert parse_cli_params(None) == {}

    def test_missing_equals_raises(self):
        with pytest.raises(ParamError, match="NAME=VALUE"):
            parse_cli_params(["batch_id"])

    def test_empty_name_raises(self):
        with pytest.raises(ParamError, match="empty name"):
            parse_cli_params(["=value"])


class TestPrecedence:
    def test_case_vars_beat_file_vars(self):
        v = resolve_variables({"a": "file"}, {"a": "case"}, None, {})
        assert v["a"] == "case"

    def test_env_beats_yaml(self):
        v = resolve_variables({"a": "file"}, {"a": "case"}, None, {f"{ENV_PREFIX}A": "env"})
        assert v["a"] == "env"

    def test_cli_beats_everything(self):
        v = resolve_variables({"a": "file"}, {"a": "case"}, {"a": "cli"}, {f"{ENV_PREFIX}A": "env"})
        assert v["a"] == "cli"

    def test_env_only_name_resolves(self):
        # A name that appears nowhere in the YAML is still usable.
        v = resolve_variables({}, {}, None, {f"{ENV_PREFIX}BATCH_ID": "202608"})
        assert v["batch_id"] == "202608"

    def test_unrelated_env_vars_ignored(self):
        v = resolve_variables({}, {}, None, {"PATH": "/bin", "TRINO_HOST": "h"})
        assert v == {}

    def test_non_string_yaml_values_stringify(self):
        v = resolve_variables({"n": 1000, "b": True, "z": None}, {}, None, {})
        assert v == {"n": "1000", "b": "True", "z": ""}


class TestSubstitute:
    def test_replaces_placeholder(self):
        assert substitute("id = '${batch_id}'", {"batch_id": "42"}) == "id = '42'"

    def test_repeated_placeholder(self):
        assert substitute("${a}-${a}", {"a": "x"}) == "x-x"

    def test_name_matching_is_case_insensitive(self):
        # ${BATCH_ID} has to resolve, or the env-var form would silently miss.
        assert substitute("${BATCH_ID}", {"batch_id": "9"}) == "9"

    def test_text_without_placeholders_is_untouched(self):
        sql = "SELECT a FROM t WHERE b = 'x'"
        assert substitute(sql, {}) == sql

    def test_non_placeholder_dollar_passes_through(self):
        # Not identifier-shaped, so not a placeholder.
        for text in ("cost $5", "${ bad }", "$notbraced", "${1abc}"):
            assert substitute(text, {}) == text

    def test_unresolved_raises_and_names_the_variable(self):
        with pytest.raises(ParamError) as exc:
            substitute("WHERE id = '${batch_id}'", {"other": "1"}, where="q.sql")
        msg = str(exc.value)
        assert "batch_id" in msg
        assert "q.sql" in msg
        assert f"{ENV_PREFIX}BATCH_ID" in msg  # tells you how to fix it

    def test_all_missing_names_reported_at_once(self):
        with pytest.raises(ParamError) as exc:
            substitute("${a} ${b}", {})
        assert "'a'" in str(exc.value) and "'b'" in str(exc.value)


class TestSubstituteSpec:
    def test_recurses_dicts_lists_and_leaves_scalars(self):
        spec = {
            "type": "trino",
            "table": "${cat}.default.request",
            "keys": ["${k}", "fixed"],
            "n": 5,
            "flag": True,
            "nested": {"query": "SELECT ${col}"},
        }
        out = substitute_spec(spec, {"cat": "mrm", "k": "id", "col": "x"})
        assert out["table"] == "mrm.default.request"
        assert out["keys"] == ["id", "fixed"]
        assert out["nested"]["query"] == "SELECT x"
        assert out["n"] == 5 and out["flag"] is True


class TestCaseLoaderIntegration:
    def _write(self, tmp_path, text):
        f = tmp_path / "case.yaml"
        f.write_text(text, encoding="utf-8")
        return str(f)

    def test_single_case_vars_substitute_into_specs(self, tmp_path):
        path = self._write(
            tmp_path,
            """
name: c
vars:
  cat: mrm_log_flat
schema_check:
  expected: {type: trino, table: "${cat}.default.request"}
  actual: {type: trino, table: etl.public_test1.request}
""",
        )
        case = load_cases_from_file(path)[0]
        assert case.expected["table"] == "mrm_log_flat.default.request"
        # vars: must not survive as a case attribute/spec key
        assert "vars" not in case.expected

    def test_file_level_vars_apply_to_every_case(self, tmp_path):
        path = self._write(
            tmp_path,
            """
vars:
  cat: mrm_log_flat
cases:
  - name: a
    schema_check:
      expected: {type: trino, table: "${cat}.default.request"}
      actual: {type: trino, table: etl.x.request}
  - name: b
    schema_check:
      expected: {type: trino, table: "${cat}.default.slot"}
      actual: {type: trino, table: etl.x.slot}
""",
        )
        cases = {c.name: c for c in load_cases_from_file(path)}
        assert cases["a"].expected["table"] == "mrm_log_flat.default.request"
        assert cases["b"].expected["table"] == "mrm_log_flat.default.slot"

    def test_cli_param_overrides_yaml(self, tmp_path):
        path = self._write(
            tmp_path,
            """
name: c
vars:
  cat: from_yaml
schema_check:
  expected: {type: trino, table: "${cat}.t"}
  actual: {type: trino, table: etl.t}
""",
        )
        case = discover_cases(path, {"cat": "from_cli"})[0]
        assert case.expected["table"] == "from_cli.t"

    def test_unresolved_placeholder_fails_at_load(self, tmp_path):
        path = self._write(
            tmp_path,
            """
name: c
schema_check:
  expected: {type: trino, table: "${nope}.t"}
  actual: {type: trino, table: etl.t}
""",
        )
        with pytest.raises(ParamError, match="nope"):
            load_cases_from_file(path)

    def test_variables_are_carried_onto_the_case(self, tmp_path):
        path = self._write(
            tmp_path,
            """
name: c
vars:
  batch_id: "20260812"
expected: {type: inline, rows: [{a: 1}]}
actual: {type: inline, rows: [{a: 1}]}
""",
        )
        case = load_cases_from_file(path)[0]
        assert case.variables["batch_id"] == "20260812"

    def test_existing_cases_without_vars_are_unaffected(self):
        # The whole backward-compatibility claim, checked against the shipped
        # example suite rather than a synthetic file.
        cases = discover_cases("examples/cases")
        assert len(cases) > 0
        for case in cases:
            assert getattr(case, "variables", {}) == {}


class TestQueryFileSubstitution:
    def test_placeholders_inside_a_sql_file_are_substituted(self, tmp_path):
        (tmp_path / "q.sql").write_text(
            "SELECT * FROM t WHERE batch_id = '${batch_id}'", encoding="utf-8"
        )
        sql = resolve_query({"query_file": "q.sql"}, str(tmp_path), {"batch_id": "20260812"})
        assert sql == "SELECT * FROM t WHERE batch_id = '20260812'"

    def test_unresolved_in_a_sql_file_raises_with_the_path(self, tmp_path):
        (tmp_path / "q.sql").write_text("SELECT ${missing}", encoding="utf-8")
        with pytest.raises(ParamError) as exc:
            resolve_query({"query_file": "q.sql"}, str(tmp_path), {})
        assert "q.sql" in str(exc.value)

    def test_no_variables_means_no_substitution_attempted(self, tmp_path):
        # Back-compat: callers that pass nothing keep the old behaviour, even
        # if the SQL happens to contain something placeholder-shaped.
        (tmp_path / "q.sql").write_text("SELECT ${untouched}", encoding="utf-8")
        assert resolve_query({"query_file": "q.sql"}, str(tmp_path)) == "SELECT ${untouched}"

    def test_inline_query_wins_over_file(self, tmp_path):
        (tmp_path / "q.sql").write_text("SELECT from_file", encoding="utf-8")
        spec = {"query": "SELECT inline", "query_file": "q.sql"}
        assert resolve_query(spec, str(tmp_path), {}) == "SELECT inline"


class TestCliErrors:
    """Case loading happens before the CLI's per-case error handling, so these
    failures have to be caught explicitly or they surface as tracebacks."""

    def _write(self, tmp_path, text):
        f = tmp_path / "c.yaml"
        f.write_text(text, encoding="utf-8")
        return str(f)

    UNRESOLVED = """
name: unresolved
expected: {type: inline, rows: [{a: 1}]}
actual: {type: duckdb, query: "SELECT * FROM t WHERE b='${batch_id}'"}
"""

    def test_unresolved_placeholder_is_a_clean_message_not_a_traceback(self, tmp_path, capsys):
        rc = cli_main(["run", self._write(tmp_path, self.UNRESOLVED)])
        assert rc == 2
        err = capsys.readouterr().err
        assert "unresolved parameter(s) ['batch_id']" in err
        assert "Traceback" not in err
        # The message must say how to fix it, all three ways.
        assert "vars:" in err
        assert "ROWPARITY_VAR_BATCH_ID" in err
        assert "--param batch_id=" in err

    def test_malformed_param_is_a_clean_message(self, tmp_path, capsys):
        rc = cli_main(["run", self._write(tmp_path, self.UNRESOLVED), "--param", "batch_id"])
        assert rc == 2
        assert "expects NAME=VALUE" in capsys.readouterr().err

    def test_list_reports_the_same_way(self, tmp_path, capsys):
        rc = cli_main(["list", self._write(tmp_path, self.UNRESOLVED)])
        assert rc == 2
        assert "unresolved parameter(s)" in capsys.readouterr().err

    def test_supplying_the_param_gets_past_loading(self, tmp_path, capsys):
        # Reaches execution (and fails there on a table that does not exist),
        # which proves the placeholder resolved rather than blocking the load.
        rc = cli_main(
            ["run", self._write(tmp_path, self.UNRESOLVED), "--param", "batch_id=20260812"]
        )
        out = capsys.readouterr().out
        assert "unresolved parameter" not in out
        assert rc == 1  # the case errored, but on SQL, not on parameters
