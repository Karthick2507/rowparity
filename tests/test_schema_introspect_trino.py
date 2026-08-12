"""schema_introspect._describe_trino coverage, without a live cluster.

Uses the same fake-cursor approach as test_trino_pushdown.py: a stand-in
connection records the SQL it is handed and replays canned answers, which is
enough to pin down the two things that actually matter here —

  1. WHICH mechanism is chosen (DESCRIBE for `table:`, LIMIT 0 probe for a
     derived `query:`), since that is the module's metadata-only contract.
  2. HOW the answer is shaped into {column: type}.

What it deliberately cannot verify is whether a real Presto/Trino gateway
returns the type strings we expect — that needs the live check in
scripts/trino_connectivity_check.py.
"""

import pytest

from rowparity import schema_introspect as si
from rowparity.sources import SourceError


class _FakeCursor:
    def __init__(self, describe_rows=None, description=None):
        self._describe_rows = describe_rows or []
        self.description = description
        self.executed = []

    def execute(self, sql):
        self.executed.append(sql)
        return self

    def fetchall(self):
        return self._describe_rows


class _FakeConnection:
    def __init__(self, cursor):
        self._cursor = cursor
        self.closed = False

    def cursor(self):
        return self._cursor

    def close(self):
        self.closed = True


@pytest.fixture
def patch_connect(monkeypatch):
    """Swap trino_auth.connect for a fake, returning the cursor for assertions."""

    def _install(describe_rows=None, description=None):
        cursor = _FakeCursor(describe_rows=describe_rows, description=description)
        conn = _FakeConnection(cursor)
        monkeypatch.setattr("rowparity.trino_auth.connect", lambda spec: conn)
        return cursor, conn

    return _install


# ---------------------------------------------------------------------------
# table: -> DESCRIBE (the preferred, genuinely metadata-only path)
# ---------------------------------------------------------------------------


class TestDescribeViaTable:
    def test_uses_describe_not_a_select(self, patch_connect):
        cursor, _ = patch_connect(
            describe_rows=[
                # Trino's DESCRIBE shape: (Column, Type, Extra, Comment)
                ("request__transaction_id", "varchar", "", ""),
                ("request__bit_flags", "bigint", "", ""),
            ]
        )
        out = si.describe_source({"type": "trino", "table": "mrm_log_flat.default.request"})

        assert out == {
            "request__transaction_id": "varchar",
            "request__bit_flags": "bigint",
        }
        assert cursor.executed == ["DESCRIBE mrm_log_flat.default.request"]
        # The contract: no SELECT is ever issued for a table: spec.
        assert not any("SELECT" in sql.upper() for sql in cursor.executed)

    def test_drops_extra_and_comment_columns(self, patch_connect):
        # Only the first two DESCRIBE columns carry schema; the rest is
        # presentation metadata and must not leak into the type map.
        patch_connect(describe_rows=[("col_a", "double", "partition key", "a note")])
        out = si.describe_source({"type": "trino", "table": "etl.public_test1.request"})
        assert out == {"col_a": "double"}

    def test_nested_types_pass_through_verbatim(self, patch_connect):
        patch_connect(
            describe_rows=[
                ("tags", "array(varchar)", "", ""),
                ("ctx", "row(a bigint, b varchar)", "", ""),
                ("m", "map(varchar, double)", "", ""),
            ]
        )
        out = si.describe_source({"type": "trino", "table": "t"})
        assert out["tags"] == "array(varchar)"
        assert out["ctx"] == "row(a bigint, b varchar)"
        assert out["m"] == "map(varchar, double)"

    def test_connection_is_closed(self, patch_connect):
        _, conn = patch_connect(describe_rows=[("c", "bigint", "", "")])
        si.describe_source({"type": "trino", "table": "t"})
        assert conn.closed is True


# ---------------------------------------------------------------------------
# query: / query_file: -> LIMIT 0 probe (no catalog entry to DESCRIBE)
# ---------------------------------------------------------------------------


class TestDescribeViaQuery:
    def test_derived_query_uses_limit_zero_probe(self, patch_connect):
        cursor, _ = patch_connect(description=[("day", "date"), ("revenue", "double")])
        out = si.describe_source(
            {
                "type": "trino",
                "query": "SELECT day, revenue FROM hive.analytics.daily",
            }
        )

        assert out == {"day": "date", "revenue": "double"}
        assert len(cursor.executed) == 1
        sql = cursor.executed[0]
        assert sql.endswith("LIMIT 0")
        assert "SELECT day, revenue FROM hive.analytics.daily" in sql

    def test_query_wins_over_table(self, patch_connect):
        # Matches _resolve_query_or_table precedence elsewhere in the module.
        cursor, _ = patch_connect(description=[("x", "bigint")])
        si.describe_source({"type": "trino", "query": "SELECT x FROM t", "table": "ignored"})
        assert "LIMIT 0" in cursor.executed[0]
        assert "DESCRIBE" not in cursor.executed[0]

    def test_query_file_is_resolved(self, patch_connect, tmp_path):
        sql_file = tmp_path / "probe.sql"
        sql_file.write_text("SELECT a FROM hive.s.t", encoding="utf-8")
        cursor, _ = patch_connect(description=[("a", "varchar")])

        out = si.describe_source(
            {"type": "trino", "query_file": "probe.sql"}, base_dir=str(tmp_path)
        )
        assert out == {"a": "varchar"}
        assert "SELECT a FROM hive.s.t" in cursor.executed[0]

    def test_empty_description_yields_empty_map(self, patch_connect):
        patch_connect(description=None)
        assert si.describe_source({"type": "trino", "query": "SELECT 1 WHERE false"}) == {}


# ---------------------------------------------------------------------------
# Registration + errors
# ---------------------------------------------------------------------------


class TestRegistration:
    def test_trino_is_a_known_source_type(self):
        # Before this change a `type: trino` schema_check raised
        # "unknown source type 'trino'" — FEATURES.md documented it as working.
        assert "trino" in si._HANDLERS
        assert si._HANDLERS["trino"] is si._describe_trino

    def test_missing_query_and_table_raises(self, patch_connect):
        patch_connect()
        with pytest.raises(SourceError, match="needs a 'query', 'query_file', or 'table'"):
            si.describe_source({"type": "trino"})
