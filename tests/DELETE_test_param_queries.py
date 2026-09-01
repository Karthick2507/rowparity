"""Query-backed parameters: ``param_queries:``.

Exercised against DuckDB rather than a fake, so the whole path runs for real:
YAML -> query -> scalar -> ${name} substitution -> comparison. The Trino cases
that motivated this differ only in the driver.
"""

import duckdb
import pytest

from rowparity.cases import discover_cases, load_cases_from_file
from rowparity.param_queries import resolve_param_queries
from rowparity.params import ParamError


@pytest.fixture
def db(tmp_path):
    """A warehouse with two batches; batch 'b2' is the newest."""
    path = str(tmp_path / "w.duckdb")
    con = duckdb.connect(path)
    con.execute("CREATE TABLE t (batch VARCHAR, id INTEGER, v VARCHAR)")
    con.execute("INSERT INTO t VALUES ('b1',1,'x'),('b1',2,'y'),('b2',1,'x'),('b2',2,'CHANGED')")
    con.close()
    return path


def _spec(db, sql):
    return {"type": "duckdb", "database": db, "query": sql}


class TestScalarContract:
    def test_resolves_a_single_value(self, db):
        out = resolve_param_queries({"batch_id": _spec(db, "SELECT max(batch) FROM t")}, {}, ".")
        assert out == {"batch_id": "b2"}

    def test_skips_names_already_resolved(self, db):
        # --param must short-circuit the query, not run it and discard it.
        out = resolve_param_queries(
            {"batch_id": _spec(db, "SELECT 1/0")}, {"batch_id": "pinned"}, "."
        )
        assert out == {}

    def test_no_rows_is_an_error_not_an_empty_string(self, db):
        # Substituting "" would filter on a partition that cannot exist and
        # report EQUIVALENT over two empty results.
        with pytest.raises(ParamError, match="returned no rows"):
            resolve_param_queries(
                {"batch_id": _spec(db, "SELECT batch FROM t WHERE false")}, {}, "."
            )

    def test_null_is_an_error(self, db):
        with pytest.raises(ParamError, match="returned NULL"):
            resolve_param_queries({"batch_id": _spec(db, "SELECT NULL")}, {}, ".")

    def test_multiple_rows_is_an_error(self, db):
        with pytest.raises(ParamError, match="must return exactly one"):
            resolve_param_queries({"batch_id": _spec(db, "SELECT DISTINCT batch FROM t")}, {}, ".")

    def test_multiple_columns_is_an_error(self, db):
        with pytest.raises(ParamError, match="exactly one column"):
            resolve_param_queries(
                {"batch_id": _spec(db, "SELECT max(batch), count(*) FROM t")}, {}, "."
            )

    def test_a_non_spec_is_rejected(self):
        with pytest.raises(ParamError, match="must be a source spec"):
            resolve_param_queries({"batch_id": "SELECT 1"}, {}, ".")

    def test_the_query_itself_can_use_resolved_parameters(self, db):
        out = resolve_param_queries(
            {"batch_id": _spec(db, "SELECT max(batch) FROM t WHERE batch = '${want}'")},
            {"want": "b1"},
            ".",
        )
        assert out == {"batch_id": "b1"}


class TestEndToEnd:
    def _case_file(self, tmp_path, db, body):
        f = tmp_path / "c.yaml"
        f.write_text(body.replace("DB", db), encoding="utf-8")
        return str(f)

    YAML = """
vars:
  which: b2
param_queries:
  batch_id:
    type: duckdb
    database: DB
    query: "SELECT max(batch) FROM t WHERE batch <= '${which}'"
cases:
  - name: a
    expected: {type: duckdb, database: DB, query: "SELECT id, v FROM t WHERE batch = 'b1'"}
    actual:   {type: duckdb, database: DB, query: "SELECT id, v FROM t WHERE batch = '${batch_id}'"}
    compare: {keys: [id]}
  - name: b
    expected: {type: duckdb, database: DB, query: "SELECT id FROM t WHERE batch = '${batch_id}'"}
    actual:   {type: duckdb, database: DB, query: "SELECT id FROM t WHERE batch = '${batch_id}'"}
    compare: {keys: [id]}
"""

    def test_the_resolved_value_reaches_the_comparison(self, tmp_path, db):
        path = self._case_file(tmp_path, db, self.YAML)
        cases = {c.name: c for c in load_cases_from_file(path)}
        assert cases["a"].variables["batch_id"] == "b2"
        # b1 vs b2 differ in one row's value -> the substitution really took.
        result = cases["a"].run()
        assert result.changed_count == 1

    def test_every_case_in_the_file_sees_the_same_value(self, tmp_path, db):
        # Resolving per case would let a new batch land between them and
        # silently compare two different populations.
        cases = load_cases_from_file(self._case_file(tmp_path, db, self.YAML))
        assert {c.variables["batch_id"] for c in cases} == {"b2"}

    def test_cli_param_overrides_the_query(self, tmp_path, db):
        path = self._case_file(tmp_path, db, self.YAML)
        cases = {c.name: c for c in discover_cases(path, {"batch_id": "b1"})}
        assert cases["a"].variables["batch_id"] == "b1"
        # b1 vs b1 -> equivalent, proving the override reached the SQL.
        assert cases["a"].run().equivalent is True

    def test_env_var_overrides_the_query(self, tmp_path, db, monkeypatch):
        monkeypatch.setenv("ROWPARITY_VAR_BATCH_ID", "b1")
        cases = {c.name: c for c in load_cases_from_file(self._case_file(tmp_path, db, self.YAML))}
        assert cases["a"].variables["batch_id"] == "b1"

    def test_resolve_queries_false_skips_the_query_without_failing(self, tmp_path, db, monkeypatch):
        # `rowparity list` must never touch a warehouse, but it must still be
        # able to list. A declared-but-unresolved name is left as its own
        # literal placeholder rather than raising or inventing a value.
        import duckdb as _duckdb

        def _boom(*args, **kwargs):
            raise AssertionError("listing resolved a param query")

        monkeypatch.setattr(_duckdb, "connect", _boom)

        path = self._case_file(tmp_path, db, self.YAML)
        cases = {c.name: c for c in discover_cases(path, None, resolve_queries=False)}
        assert set(cases) == {"a", "b"}
        # Visibly unresolved, not a fabricated value.
        assert "${batch_id}" in cases["a"].actual["query"]

    def test_a_file_without_param_queries_is_untouched(self, tmp_path, db):
        path = self._case_file(
            tmp_path,
            db,
            """
name: plain
expected: {type: duckdb, database: DB, query: "SELECT id FROM t WHERE batch = 'b1'"}
actual:   {type: duckdb, database: DB, query: "SELECT id FROM t WHERE batch = 'b1'"}
compare: {keys: [id]}
""",
        )
        case = load_cases_from_file(path)[0]
        assert case.variables == {}
        assert case.run().equivalent is True
