"""The Trino source pulls rows in batches, not all at once.

``fetchall()`` built the whole result as Python tuples and then a second full
copy as dicts before Arrow saw anything. At 262 columns that is roughly 3-5 KB
of interpreter overhead per row, so a few hundred thousand rows was tens of
gigabytes -- the process dies rather than finishing, and it dies after however
many minutes the warehouse query took.

Batching introduces its own hazard, which is most of what these tests are
about: types are inferred per batch, so a column that is entirely NULL in one
batch infers as Arrow ``null`` while a later batch infers ``int64``. Without
promotion on the concat, batching would have turned a memory problem into a
correctness one.

Driven by a fake cursor. There is no cluster here, and the behaviour under test
is the fetch loop rather than anything Trino does.
"""
import pyarrow as pa
import pytest

from rowparity import sources
from rowparity.sources import _trino_batch_rows, load_source


class FakeCursor:
    """Records how it was asked for rows, so the fetch pattern is observable."""

    def __init__(self, columns, rows):
        self._columns = columns
        self._rows = list(rows)
        self._pos = 0
        self.description = [(c, "varchar", None, None, None, None, None) for c in columns]
        self.executed = None
        self.fetch_sizes = []

    def execute(self, sql):
        self.executed = sql

    def fetchmany(self, size):
        self.fetch_sizes.append(size)
        chunk = self._rows[self._pos : self._pos + size]
        self._pos += len(chunk)
        return chunk

    def fetchall(self):  # pragma: no cover - must never be reached
        raise AssertionError("fetchall() defeats the point: it materialises everything")


class FakeConnection:
    def __init__(self, cursor):
        self._cursor = cursor
        self.closed = False

    def cursor(self):
        return self._cursor

    def close(self):
        self.closed = True


@pytest.fixture
def fake_trino(monkeypatch):
    """Install a fake connection and hand back a factory for the cursor."""
    holder = {}

    def _install(columns, rows):
        cursor = FakeCursor(columns, rows)
        connection = FakeConnection(cursor)
        holder["cursor"] = cursor
        holder["connection"] = connection
        import rowparity.trino_auth as trino_auth

        monkeypatch.setattr(trino_auth, "connect", lambda spec: connection)
        return cursor

    holder["install"] = _install
    return holder


def _load(fake, columns, rows, **spec):
    cursor = fake["install"](columns, rows)
    spec = {"type": "trino", "query": "SELECT 1", **spec}
    table = load_source(spec, base_dir=".")
    return table, cursor


class TestBatchSizing:
    def test_wide_results_get_smaller_batches(self):
        # A cell budget, not a row count: a 262-column row is two orders of
        # magnitude heavier than a 1-column row.
        assert _trino_batch_rows(262) < _trino_batch_rows(10)

    def test_narrow_results_are_capped(self):
        assert _trino_batch_rows(1) == sources._TRINO_MAX_BATCH_ROWS

    def test_very_wide_results_still_get_a_usable_floor(self):
        # 5,000 columns would compute a batch of 400 rows; the floor keeps the
        # loop from degenerating into one round trip per handful of rows.
        assert _trino_batch_rows(5000) == sources._TRINO_MIN_BATCH_ROWS

    def test_zero_columns_does_not_divide_by_zero(self):
        assert _trino_batch_rows(0) == sources._TRINO_MAX_BATCH_ROWS

    def test_the_budget_is_respected_for_a_realistic_width(self):
        n = 262
        assert _trino_batch_rows(n) * n <= sources._TRINO_TARGET_CELLS


class TestItActuallyBatches:
    def test_fetchall_is_never_called(self, fake_trino):
        # FakeCursor.fetchall raises; reaching it fails the test loudly.
        table, _ = _load(fake_trino, ["a"], [(i,) for i in range(50)])
        assert table.num_rows == 50

    def test_a_large_result_takes_several_fetches(self, fake_trino):
        rows = [(i, "x") for i in range(2500)]
        table, cursor = _load(fake_trino, ["a", "b"], rows, fetch_batch_rows=500)
        assert table.num_rows == 2500
        # 5 full batches, then one empty fetch that ends the loop.
        assert cursor.fetch_sizes == [500] * 6

    def test_an_explicit_batch_size_is_honoured(self, fake_trino):
        _, cursor = _load(fake_trino, ["a"], [(i,) for i in range(10)], fetch_batch_rows=3)
        assert cursor.fetch_sizes[0] == 3

    def test_the_default_batch_size_comes_from_the_column_count(self, fake_trino):
        _, cursor = _load(fake_trino, ["a", "b", "c"], [(1, 2, 3)])
        assert cursor.fetch_sizes[0] == _trino_batch_rows(3)

    def test_the_connection_is_closed(self, fake_trino):
        _load(fake_trino, ["a"], [(1,)])
        assert fake_trino["connection"].closed


class TestResultsAreUnchanged:
    def test_values_and_order_survive_batching(self, fake_trino):
        rows = [(i, f"row{i}") for i in range(1000)]
        table, _ = _load(fake_trino, ["n", "s"], rows, fetch_batch_rows=64)
        assert table.column("n").to_pylist() == list(range(1000))
        assert table.column("s").to_pylist()[-1] == "row999"

    def test_column_names_are_preserved(self, fake_trino):
        table, _ = _load(fake_trino, ["alpha", "beta"], [(1, 2)])
        assert table.column_names == ["alpha", "beta"]

    def test_a_single_batch_result_is_returned_directly(self, fake_trino):
        table, _ = _load(fake_trino, ["a"], [(1,), (2,)])
        assert table.num_rows == 2
        # One chunk: nothing was concatenated, so nothing needed promoting.
        assert table.column("a").num_chunks == 1


class TestEmptyResults:
    def test_no_rows_still_carries_the_columns(self, fake_trino):
        # Losing the schema turns "zero rows" into "no such columns", and the
        # comparison then reports every column as missing on one side.
        table, _ = _load(fake_trino, ["a", "b", "c"], [])
        assert table.num_rows == 0
        assert table.column_names == ["a", "b", "c"]

    def test_no_rows_makes_exactly_one_fetch(self, fake_trino):
        _, cursor = _load(fake_trino, ["a"], [])
        assert len(cursor.fetch_sizes) == 1


class TestTypeUnificationAcrossBatches:
    """The hazard batching introduces.

    Types are inferred per batch. A column that is all-NULL in the first batch
    infers as Arrow `null`; the same column with integers in a later batch
    infers as int64. Concatenating those without promotion raises -- so batching
    without this would trade a memory bug for a correctness bug.
    """

    def test_a_column_null_in_the_first_batch_then_populated(self, fake_trino):
        rows = [(None,)] * 4 + [(7,)] * 4
        table, _ = _load(fake_trino, ["v"], rows, fetch_batch_rows=4)
        assert table.num_rows == 8
        assert pa.types.is_integer(table.schema.field("v").type)
        assert table.column("v").to_pylist() == [None] * 4 + [7] * 4

    def test_a_column_populated_first_then_null(self, fake_trino):
        rows = [(7,)] * 4 + [(None,)] * 4
        table, _ = _load(fake_trino, ["v"], rows, fetch_batch_rows=4)
        assert pa.types.is_integer(table.schema.field("v").type)
        assert table.column("v").to_pylist() == [7] * 4 + [None] * 4

    def test_mixed_null_batches_in_the_middle(self, fake_trino):
        rows = [(1,)] * 2 + [(None,)] * 2 + [(3,)] * 2
        table, _ = _load(fake_trino, ["v"], rows, fetch_batch_rows=2)
        assert table.column("v").to_pylist() == [1, 1, None, None, 3, 3]

    def test_a_column_null_in_every_batch_stays_null_typed(self, fake_trino):
        # Documents the limitation rather than claiming it is fixed: with no
        # value anywhere there is nothing to infer from, and only an explicit
        # schema from cursor.description could resolve it.
        table, _ = _load(fake_trino, ["v"], [(None,)] * 8, fetch_batch_rows=4)
        assert pa.types.is_null(table.schema.field("v").type)

    def test_strings_and_numbers_in_separate_batches_do_not_silently_merge(self, fake_trino):
        # Permissive promotion unifies null with a real type; it must not
        # quietly reconcile two genuinely incompatible types, which would hide
        # a real schema difference.
        #
        # Matched narrowly on purpose: pytest.raises(Exception) would also pass
        # if this test raised for its own reasons -- a typo in the fixture, a
        # bad column name -- and would then be asserting nothing.
        rows = [("text",)] * 2 + [(5,)] * 2
        with pytest.raises(pa.lib.ArrowTypeError, match="incompatible types"):
            _load(fake_trino, ["v"], rows, fetch_batch_rows=2)
