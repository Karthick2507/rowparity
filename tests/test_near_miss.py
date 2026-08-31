"""Finding the key column that turned one row into two.

A keyed comparison pairs rows on the whole key, so a single drifting key column
destroys the pairing: the row is reported as missing AND added, and nothing in
the output connects the two halves. 149 missing against 208 added looks like
catastrophic data loss and is actually one column that moved.

The tell is the balance. Genuine loss is lopsided; a broken key produces two
similar numbers, because every unpaired row on one side has a twin on the other.

This costs no warehouse time -- it re-pairs key tuples the comparison already
built -- which is the whole reason it is worth doing before anything that has
to query.
"""
import pyarrow as pa
import pytest

from rowparity import near_miss
from rowparity.compare import CompareConfig, compare_tables
from rowparity.report import render_console
from rowparity.run_report import build_payload

KEYS = ["event_date", "network_id", "site_id"]


def _run(expected, actual, **cfg):
    cfg.setdefault("keys", KEYS)
    cfg.setdefault("near_miss", True)
    return compare_tables(
        pa.Table.from_pylist(expected), pa.Table.from_pylist(actual), CompareConfig(**cfg)
    )


def _shifted(n, hour_from="01", hour_to="00"):
    """n rows whose event hour moved -- the real defect, in miniature."""
    exp = [{"event_date": f"2026-08-27T{hour_from}:00", "network_id": 516429,
            "site_id": 1000 + i, "v": 5} for i in range(n)]
    act = [{"event_date": f"2026-08-27T{hour_to}:00", "network_id": 516429,
            "site_id": 1000 + i, "v": 5} for i in range(n)]
    return exp, act


class TestItFindsTheDriftingColumn:
    def test_a_shifted_column_is_identified(self):
        exp, act = _shifted(8)
        r = _run(exp, act)
        assert r.near_miss.best.column == "event_date"
        assert r.near_miss.best.pairs == 8

    def test_the_rows_are_still_reported_as_missing_and_added(self):
        # The analysis explains the differences; it must not quietly absolve
        # them. The keys genuinely do not match, and the verdict stays.
        exp, act = _shifted(8)
        r = _run(exp, act)
        assert r.missing_count == 8 and r.added_count == 8
        assert not r.equivalent

    def test_the_shift_itself_is_reported(self):
        # "event_date is the culprit" is half an answer; which way it moved is
        # the half that tells you where to look.
        exp, act = _shifted(3)
        pair = _run(exp, act).near_miss.best.examples[0]
        assert pair.expected_value == "2026-08-27T01:00"
        assert pair.actual_value == "2026-08-27T00:00"

    def test_the_share_is_of_missing_rows(self):
        exp, act = _shifted(8)
        exp = exp + [{"event_date": "2026-08-27T01:00", "network_id": 9, "site_id": 1, "v": 1}]
        r = _run(exp, act)
        assert r.missing_count == 9
        assert r.near_miss.best.pairs == 8
        assert r.near_miss.best.share_of(r.missing_count) == pytest.approx(8 / 9)

    def test_the_worst_column_sorts_first(self):
        exp, act = _shifted(6)
        # One row differs in site_id instead, so two columns produce pairs.
        exp.append({"event_date": "2026-08-27T05:00", "network_id": 1, "site_id": 7, "v": 1})
        act.append({"event_date": "2026-08-27T05:00", "network_id": 1, "site_id": 8, "v": 1})
        r = _run(exp, act)
        assert [c.column for c in r.near_miss.columns][0] == "event_date"
        assert {c.column for c in r.near_miss.columns} == {"event_date", "site_id"}


class TestWhatItRefusesToClaim:
    def test_ambiguous_matches_are_counted_not_paired(self):
        # Two added rows agree on the other columns, so which one the missing
        # row "is" cannot be decided. Picking one would be a guess dressed up
        # as a finding.
        exp = [{"event_date": "01", "network_id": 1, "site_id": 1, "v": 1}]
        act = [{"event_date": "02", "network_id": 1, "site_id": 1, "v": 1},
               {"event_date": "03", "network_id": 1, "site_id": 1, "v": 1}]
        r = _run(exp, act)
        col = next(c for c in r.near_miss.columns if c.column == "event_date")
        assert col.pairs == 0
        assert col.ambiguous_groups == 1

    def test_two_columns_drifting_together_are_not_found(self):
        # A documented limit, not an oversight: only one column is dropped at a
        # time. Reporting nothing is correct; reporting a partial match would
        # send someone after the wrong column.
        exp = [{"event_date": "01", "network_id": 1, "site_id": 1, "v": 1}]
        act = [{"event_date": "02", "network_id": 2, "site_id": 1, "v": 1}]
        assert _run(exp, act).near_miss.columns == []

    def test_unrelated_rows_produce_no_pairs(self):
        exp = [{"event_date": "01", "network_id": 1, "site_id": 1, "v": 1}]
        act = [{"event_date": "09", "network_id": 9, "site_id": 9, "v": 9}]
        assert _run(exp, act).near_miss.columns == []

    def test_a_single_column_key_is_refused(self):
        # Dropping the only key column pairs everything with everything, which
        # is true and completely uninformative.
        exp = [{"k": 1, "v": 1}]
        act = [{"k": 2, "v": 1}]
        r = compare_tables(pa.Table.from_pylist(exp), pa.Table.from_pylist(act),
                           CompareConfig(keys=["k"], near_miss=True))
        assert r.near_miss.columns == []


class TestWhenItRuns:
    def test_it_is_off_by_default(self):
        exp, act = _shifted(4)
        r = compare_tables(pa.Table.from_pylist(exp), pa.Table.from_pylist(act),
                           CompareConfig(keys=KEYS))
        assert r.near_miss is None

    def test_it_needs_both_missing_and_added(self):
        # Nothing to pair with: rows only absent from one side cannot have
        # drifted, they are simply not there.
        exp, _ = _shifted(4)
        r = _run(exp, exp[:2])          # actual is a strict subset
        assert r.missing_count == 2 and r.added_count == 0
        assert r.near_miss is None

    def test_a_keyless_case_does_not_attempt_it(self):
        exp, act = _shifted(4)
        r = compare_tables(pa.Table.from_pylist(exp), pa.Table.from_pylist(act),
                           CompareConfig(near_miss=True))
        assert r.near_miss is None

    def test_the_unpaired_keys_are_retained_regardless(self):
        # They cost one pointer each -- the tuples already exist as index keys
        # -- so they are kept whether or not the analysis runs.
        exp, act = _shifted(4)
        r = compare_tables(pa.Table.from_pylist(exp), pa.Table.from_pylist(act),
                           CompareConfig(keys=KEYS))
        assert len(r.missing_keys) == 4 and len(r.added_keys) == 4


class TestScale:
    def test_it_caps_and_says_so(self):
        exp, act = _shifted(50)
        r = compare_tables(pa.Table.from_pylist(exp), pa.Table.from_pylist(act),
                           CompareConfig(keys=KEYS, near_miss=True))
        capped = near_miss.analyse(r.missing_keys, r.added_keys, KEYS, max_rows=10)
        assert capped.truncated
        # Silently truncating would present a subset as the whole picture.
        assert capped.best.pairs <= 10

    def test_capping_does_not_destroy_the_pairing_it_looks_for(self):
        # Both key lists come from unordered sets. Truncating BOTH would keep
        # ten missing rows and ten unrelated added rows, find nothing, and
        # report "no near misses" -- a confident wrong answer. Only the missing
        # side is capped, so every examined row can still find its partner.
        exp, act = _shifted(50)
        r = compare_tables(pa.Table.from_pylist(exp), pa.Table.from_pylist(act),
                           CompareConfig(keys=KEYS, near_miss=True))
        capped = near_miss.analyse(r.missing_keys, r.added_keys, KEYS, max_rows=10)
        assert capped.best is not None, "capping destroyed the pairing"
        assert capped.best.column == "event_date"
        assert capped.best.pairs == 10


class TestValueRendering:
    def test_canonical_tuples_are_unwrapped(self):
        # Key elements are type-tagged: ('i', 5), ('t', 'x'). Reported raw they
        # are unreadable and the tag is noise to anyone not debugging hashing.
        assert near_miss._unwrap(("i", 5)) == 5
        assert near_miss._unwrap(("t", "midroll")) == "midroll"

    def test_list_elements_are_unwrapped_too(self):
        assert near_miss._unwrap(("L", (("i", 34007),))) == [34007]

    def test_a_plain_value_passes_through(self):
        assert near_miss._unwrap(7) == 7


class TestReporting:
    def test_console_leads_with_the_finding(self):
        exp, act = _shifted(8)
        text = render_console(_run(exp, act), "c")
        assert "near misses" in text
        assert "event_date" in text
        assert "are not missing" in text

    def test_console_stays_ascii(self):
        exp, act = _shifted(8)
        assert all(ord(ch) < 128 for ch in render_console(_run(exp, act), "c"))

    def test_the_html_payload_carries_it(self):
        exp, act = _shifted(8)
        payload = build_payload([("c", _run(exp, act))], [])
        nm = payload["cases"][0]["near_miss"]
        assert nm["columns"][0]["column"] == "event_date"
        assert nm["columns"][0]["pairs"] == 8
        assert nm["missing_rows"] == 8

    def test_a_case_with_no_near_misses_carries_none(self):
        exp = [{"event_date": "01", "network_id": 1, "site_id": 1, "v": 1}]
        act = [{"event_date": "09", "network_id": 9, "site_id": 9, "v": 9}]
        payload = build_payload([("c", _run(exp, act))], [])
        assert payload["cases"][0]["near_miss"] is None
