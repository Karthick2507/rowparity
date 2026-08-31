"""Attributing differences to a group, and describing how columns moved.

Two features that answer the two questions a bare "9 rows changed" leaves open.

**Which branch?** The Hoover query is a 3-way UNION ALL, and every output row
carries the literal its branch stamped on it (``slot_user_drop_off`` --
'Included' / 'Removed' / 'Not Applicable'). ``breakdown_by`` splits every
missing, added and changed row by that column, so 149 missing rows stop being
one undifferentiated pile.

**How did it move?** A change signature said *which* columns differ together
and how often, never in which direction or by how much. One example cannot
distinguish "every row loses exactly one" from "the deltas are all over the
place" -- and those are different bugs. The delta profile reports the direction
tally and, when every row moved by the same amount, says so.

Both are computed over *every* row rather than over the bounded ``examples``
list. A breakdown derived from 50 of 366 differing rows would describe a sample
while looking like the whole picture, which is the trap this exists to avoid.
"""
import textwrap

import pyarrow as pa
import pytest

from rowparity.cases import discover_cases
from rowparity.compare import CompareConfig, compare_tables
from rowparity.report import render_console, to_dict
from rowparity.run_report import build_payload


def _tbl(rows):
    return pa.Table.from_pylist(rows)


def _run(expected, actual, **cfg):
    cfg.setdefault("keys", ["branch", "k"])
    return compare_tables(_tbl(expected), _tbl(actual), CompareConfig(**cfg))


# One "Removed" branch losing exactly one ad per row -- the shape of the real
# finding, reduced to something a test can assert on.
LOSES_ONE_EXP = [
    {"branch": "Removed", "k": i, "filled_ads": 11, "duration": 330} for i in range(6)
]
LOSES_ONE_ACT = [
    {"branch": "Removed", "k": i, "filled_ads": 10, "duration": 300} for i in range(6)
]
STABLE_EXP = [
    {"branch": "Included", "k": 100 + i, "filled_ads": 5, "duration": 150} for i in range(3)
]


class TestBreakdownCounts:
    def test_changed_rows_land_in_their_group(self):
        r = _run(LOSES_ONE_EXP + STABLE_EXP, LOSES_ONE_ACT + STABLE_EXP,
                 breakdown_by=["branch"])
        assert r.breakdown["Removed"].changed == 6
        assert r.breakdown["Included"].changed == 0

    def test_missing_rows_land_in_their_group(self):
        exp = STABLE_EXP + [{"branch": "Removed", "k": 1, "filled_ads": 1, "duration": 1}]
        r = _run(exp, STABLE_EXP, breakdown_by=["branch"])
        assert r.breakdown["Removed"].missing == 1
        assert r.breakdown["Included"].missing == 0

    def test_added_rows_land_in_their_group(self):
        act = STABLE_EXP + [{"branch": "Removed", "k": 1, "filled_ads": 1, "duration": 1}]
        r = _run(STABLE_EXP, act, breakdown_by=["branch"])
        assert r.breakdown["Removed"].added == 1

    def test_each_group_carries_both_side_totals(self):
        # Needed for the share: an absolute count cannot say whether 58
        # differences out of 892 rows is worse than 71 out of 1,204.
        r = _run(LOSES_ONE_EXP + STABLE_EXP, LOSES_ONE_ACT + STABLE_EXP,
                 breakdown_by=["branch"])
        assert r.breakdown["Removed"].expected_rows == 6
        assert r.breakdown["Removed"].actual_rows == 6
        assert r.breakdown["Included"].expected_rows == 3

    def test_the_group_totals_reconcile_with_the_case_totals(self):
        # A breakdown that does not add up is worse than none: it looks precise
        # and quietly loses rows.
        exp = LOSES_ONE_EXP + STABLE_EXP + [{"branch": "NA", "k": 9, "filled_ads": 1, "duration": 1}]
        act = LOSES_ONE_ACT + STABLE_EXP + [{"branch": "NA", "k": 8, "filled_ads": 1, "duration": 1}]
        r = _run(exp, act, breakdown_by=["branch"])
        assert sum(g.missing for g in r.breakdown.values()) == r.missing_count
        assert sum(g.added for g in r.breakdown.values()) == r.added_count
        assert sum(g.changed for g in r.breakdown.values()) == r.changed_count
        assert sum(g.expected_rows for g in r.breakdown.values()) == r.expected_rows
        assert sum(g.actual_rows for g in r.breakdown.values()) == r.actual_rows

    def test_it_counts_every_row_not_just_the_examples(self):
        # The whole point. With max_examples=2, a breakdown built from the
        # examples list would report 2 and look authoritative.
        exp = [{"branch": "Removed", "k": i, "v": 1} for i in range(50)]
        act = [{"branch": "Removed", "k": i, "v": 2} for i in range(50)]
        r = compare_tables(_tbl(exp), _tbl(act),
                           CompareConfig(keys=["branch", "k"], breakdown_by=["branch"],
                                         max_examples=2))
        assert len(r.examples) == 2
        assert r.breakdown["Removed"].changed == 50

    def test_no_breakdown_configured_leaves_it_empty(self):
        r = _run(LOSES_ONE_EXP, LOSES_ONE_ACT)
        assert r.breakdown == {}
        assert r.breakdown_columns == []


class TestDifferingShare:
    def test_it_is_relative_to_the_larger_side(self):
        r = _run(LOSES_ONE_EXP + STABLE_EXP, LOSES_ONE_ACT + STABLE_EXP,
                 breakdown_by=["branch"])
        assert r.breakdown["Removed"].differing_share == 1.0
        assert r.breakdown["Included"].differing_share == 0.0

    def test_a_small_badly_broken_group_outranks_a_large_slightly_off_one(self):
        # The reason to sort by share rather than count. The big group has more
        # absolute differences and is in far better shape.
        big_exp = [{"branch": "big", "k": i, "v": 1} for i in range(1000)]
        big_act = [{"branch": "big", "k": i, "v": 2 if i < 50 else 1} for i in range(1000)]
        small_exp = [{"branch": "small", "k": i, "v": 1} for i in range(10)]
        small_act = [{"branch": "small", "k": i, "v": 2} for i in range(10)]
        r = _run(big_exp + small_exp, big_act + small_act, breakdown_by=["branch"])
        assert r.breakdown["big"].differences > r.breakdown["small"].differences
        assert r.breakdown["small"].differing_share > r.breakdown["big"].differing_share
        ranked = sorted(r.breakdown.values(), key=lambda g: -g.differing_share)
        assert ranked[0].value == "small"

    def test_an_empty_group_does_not_divide_by_zero(self):
        from rowparity.compare import BreakdownGroup

        assert BreakdownGroup(value="x").differing_share == 0.0


class TestGroupLabels:
    def test_the_label_is_the_raw_value_not_the_canonical_tuple(self):
        # Keys hold canonicalised values -- ('s', 'Removed') -- which group
        # correctly and read terribly on a page.
        r = _run(LOSES_ONE_EXP, LOSES_ONE_ACT, breakdown_by=["branch"])
        labels = [g.value for g in r.breakdown.values()]
        assert labels == ["Removed"]

    def test_two_columns_group_as_a_composite(self):
        exp = [{"branch": "a", "sub": "x", "k": 1, "v": 1},
               {"branch": "a", "sub": "y", "k": 2, "v": 1}]
        act = [{"branch": "a", "sub": "x", "k": 1, "v": 2},
               {"branch": "a", "sub": "y", "k": 2, "v": 1}]
        r = compare_tables(_tbl(exp), _tbl(act),
                           CompareConfig(keys=["branch", "sub", "k"],
                                         breakdown_by=["branch", "sub"]))
        assert r.breakdown[("a", "x")].changed == 1
        assert r.breakdown[("a", "y")].changed == 0


class TestDeltaProfile:
    def _sig(self, expected=LOSES_ONE_EXP, actual=LOSES_ONE_ACT, **cfg):
        r = _run(expected, actual, **cfg)
        return r, r.signatures_by_count()[0]

    def test_a_uniform_loss_reports_a_constant_delta(self):
        # The headline case: not "6 rows changed" but "every row lost exactly
        # one ad", which is a diagnosis rather than a starting point.
        _, sig = self._sig()
        assert sig.deltas["filled_ads"].constant_delta == -1
        assert sig.deltas["duration"].constant_delta == -30

    def test_a_varying_delta_is_not_called_constant(self):
        exp = [{"branch": "b", "k": i, "v": 10} for i in range(4)]
        act = [{"branch": "b", "k": i, "v": 10 - i} for i in range(1, 4)]
        _, sig = self._sig(exp, act + [{"branch": "b", "k": 0, "v": 3}])
        assert sig.deltas["v"].constant_delta is None
        assert sig.deltas["v"].min_delta != sig.deltas["v"].max_delta

    def test_direction_is_reported(self):
        _, sig = self._sig()
        assert sig.deltas["filled_ads"].direction == "lower"
        assert sig.deltas["filled_ads"].lower == 6
        assert sig.deltas["filled_ads"].higher == 0

    def test_a_mixed_direction_says_mixed(self):
        exp = [{"branch": "b", "k": 0, "v": 5}, {"branch": "b", "k": 1, "v": 5}]
        act = [{"branch": "b", "k": 0, "v": 6}, {"branch": "b", "k": 1, "v": 4}]
        _, sig = self._sig(exp, act)
        assert sig.deltas["v"].direction == "mixed"

    def test_nulls_are_counted_apart_from_movement(self):
        # "became null" is a different failure from "got smaller"; folding them
        # together would invent a delta out of an absent value.
        exp = [{"branch": "b", "k": 0, "v": 5}]
        act = [{"branch": "b", "k": 0, "v": None}]
        _, sig = self._sig(exp, act)
        d = sig.deltas["v"]
        assert d.became_null == 1
        assert d.numeric == 0
        assert d.constant_delta is None

    def test_booleans_do_not_get_a_delta(self):
        # bool is an int in Python; reporting a flag "moved by -1" is worse
        # than saying nothing about it.
        exp = [{"branch": "b", "k": 0, "flag": True}]
        act = [{"branch": "b", "k": 0, "flag": False}]
        _, sig = self._sig(exp, act)
        assert sig.deltas["flag"].numeric == 0

    def test_strings_get_the_dominant_value_pair(self):
        exp = [{"branch": "b", "k": i, "s": "OLD"} for i in range(3)]
        act = [{"branch": "b", "k": i, "s": "NEW"} for i in range(3)]
        _, sig = self._sig(exp, act)
        assert sig.deltas["s"].top_pair == ("OLD", "NEW")
        assert sig.deltas["s"].top_pair_count == 3

    def test_float_deltas_quantise_to_the_tolerance_grid(self):
        # Without quantising, the last bits differ on every row and no float
        # column would ever report a constant delta -- losing the most useful
        # signal precisely where sums over doubles make it most likely.
        exp = [{"branch": "b", "k": i, "v": 1.0} for i in range(3)]
        act = [{"branch": "b", "k": 0, "v": 2.0000000001},
               {"branch": "b", "k": 1, "v": 1.9999999999},
               {"branch": "b", "k": 2, "v": 2.0}]
        _, sig = self._sig(exp, act, float_tolerance=1e-6)
        assert sig.deltas["v"].constant_delta == pytest.approx(1.0)

    def test_the_profile_covers_every_row_not_just_the_example(self):
        exp = [{"branch": "b", "k": i, "v": 100} for i in range(40)]
        act = [{"branch": "b", "k": i, "v": 99} for i in range(40)]
        r = compare_tables(_tbl(exp), _tbl(act),
                           CompareConfig(keys=["branch", "k"], max_examples=3))
        sig = r.signatures_by_count()[0]
        assert sig.deltas["v"].rows == 40


class TestExampleSelection:
    def test_the_most_extreme_row_is_kept(self):
        # An arbitrary first row is a fine illustration and a poor lead.
        exp = [{"branch": "b", "k": i, "v": 100} for i in range(3)]
        act = [{"branch": "b", "k": 0, "v": 99},
               {"branch": "b", "k": 1, "v": 1},      # the interesting one
               {"branch": "b", "k": 2, "v": 98}]
        r = _run(exp, act)
        sig = r.signatures_by_count()[0]
        assert sig.example.columns[0].actual == 1


class TestSignatureExtras:
    def test_share_of_changed_rows(self):
        exp = [{"branch": "b", "k": i, "v": 1, "w": 1} for i in range(4)]
        act = [{"branch": "b", "k": 0, "v": 2, "w": 1},
               {"branch": "b", "k": 1, "v": 2, "w": 1},
               {"branch": "b", "k": 2, "v": 2, "w": 1},
               {"branch": "b", "k": 3, "v": 1, "w": 2}]
        r = _run(exp, act)
        top = r.signatures_by_count()[0]
        assert top.count == 3
        assert top.share_of(r.changed_count) == pytest.approx(0.75)

    def test_a_signature_splits_by_the_breakdown_column(self):
        exp = ([{"branch": "Removed", "k": i, "v": 1} for i in range(3)] +
               [{"branch": "Included", "k": i, "v": 1} for i in range(2)])
        act = ([{"branch": "Removed", "k": i, "v": 2} for i in range(3)] +
               [{"branch": "Included", "k": i, "v": 2} for i in range(2)])
        r = _run(exp, act, breakdown_by=["branch"])
        sig = r.signatures_by_count()[0]
        assert sig.breakdown == {"Removed": 3, "Included": 2}

    def test_share_of_zero_changed_does_not_divide_by_zero(self):
        from rowparity.compare import ChangeSignature

        assert ChangeSignature(columns=("a",)).share_of(0) == 0.0


# --------------------------------------------------------------------------- #
# Validation: reject a breakdown that cannot be computed, before fetching
# --------------------------------------------------------------------------- #

CASE = """
cases:
  - name: bd
    expected: {{type: inline, rows: [{{branch: a, k: 1, v: 1}}]}}
    actual:   {{type: inline, rows: [{{branch: a, k: 1, v: 2}}]}}
    {engine}
    compare:
      {keys}
      breakdown_by: {column}
"""


def _case(tmp_path, column="branch", keys="keys: [branch, k]", engine=""):
    (tmp_path / "c.yaml").write_text(
        textwrap.dedent(CASE.format(column=column, keys=keys, engine=engine))
    )
    return discover_cases(str(tmp_path))[0]


class TestValidation:
    def test_a_non_key_column_is_refused(self):
        # For a key the value is in the key tuple, free for every row. For a
        # non-key column a missing row has no handle at all without retaining
        # every source row -- real memory, for something adding the column to
        # keys solves.
        import pathlib
        import tempfile

        with tempfile.TemporaryDirectory() as d:
            case = _case(pathlib.Path(d), column="v")
            with pytest.raises(ValueError, match="not in compare.keys"):
                case.run()

    def test_a_keyless_case_is_refused(self, tmp_path):
        case = _case(tmp_path, keys="max_examples: 5")
        with pytest.raises(ValueError, match="needs compare.keys"):
            case.run()

    def test_a_pushdown_engine_is_refused(self, tmp_path):
        # Push-down counts in SQL and never sees a row, so it would accept the
        # option and silently produce nothing.
        case = _case(tmp_path, engine="engine: duckdb")
        with pytest.raises(ValueError, match="not supported with engine"):
            case.run()

    def test_the_refusal_happens_before_any_fetch(self, tmp_path):
        case = _case(tmp_path, column="v")
        case.expected = {"type": "parquet", "path": "/nonexistent/nope.parquet"}
        with pytest.raises(ValueError, match="not in compare.keys"):
            case.run()

    def test_a_bare_string_is_accepted_as_one_column(self, tmp_path):
        case = _case(tmp_path)
        assert case.config().breakdown_by == ["branch"]

    def test_a_valid_breakdown_runs(self, tmp_path):
        case = _case(tmp_path)
        result = case.run()
        assert result.breakdown["a"].changed == 1


# --------------------------------------------------------------------------- #
# It reaches the reports
# --------------------------------------------------------------------------- #


class TestReporting:
    def _result(self):
        return _run(LOSES_ONE_EXP + STABLE_EXP, LOSES_ONE_ACT + STABLE_EXP,
                    breakdown_by=["branch"])

    def test_console_names_the_worst_group_first(self):
        text = render_console(self._result(), "c")
        assert "row differences by branch" in text
        assert text.index("Removed") < text.index("Included")

    def test_console_says_constant(self):
        assert "(constant)" in render_console(self._result(), "c")

    def test_console_stays_ascii(self):
        text = render_console(self._result(), "c")
        assert all(ord(ch) < 128 for ch in text)

    def test_json_carries_the_groups(self):
        d = to_dict(self._result(), "c")
        assert d["breakdown_columns"] == ["branch"]
        assert {g["value"] for g in d["breakdown"]} == {"Removed", "Included"}

    def test_json_carries_the_constant_delta(self):
        d = to_dict(self._result(), "c")
        deltas = {x["column"]: x for x in d["change_signatures"][0]["deltas"]}
        assert deltas["filled_ads"]["constant_delta"] == -1

    def test_html_payload_carries_the_breakdown(self):
        payload = build_payload([("c", self._result())], [])
        case = payload["cases"][0]
        assert case["breakdown"]["columns"] == ["branch"]
        assert case["breakdown"]["groups"][0]["value"] == "Removed"

    def test_html_payload_marks_dimensions_and_metrics(self):
        payload = build_payload([("c", self._result())], [])
        kinds = {c["column"]: c["kind"] for c in payload["cases"][0]["columns"]}
        assert kinds["branch"] == "dimension"
        assert kinds["k"] == "dimension"
        assert kinds["filled_ads"] == "metric"

    def test_html_payload_renders_the_delta_amount(self):
        payload = build_payload([("c", self._result())], [])
        sig = payload["cases"][0]["change_signatures"][0]
        amounts = {d["column"]: d for d in sig["deltas"]}
        assert amounts["filled_ads"]["amount"] == "-1"
        assert amounts["filled_ads"]["constant"] is True

    def test_a_near_constant_float_delta_is_marked_approximate(self):
        # Float deltas without a tolerance almost never come out exactly equal,
        # so the min and max format identically while differing in the last
        # bits. Rendering that as "+0.07 to +0.07" reads as a broken report.
        exp = [{"branch": "b", "k": i, "v": 1.0} for i in range(3)]
        act = [{"branch": "b", "k": 0, "v": 1.07},
               {"branch": "b", "k": 1, "v": 1.0700000001},
               {"branch": "b", "k": 2, "v": 1.0699999999}]
        payload = build_payload([("c", _run(exp, act))], [])
        d = payload["cases"][0]["change_signatures"][0]["deltas"][0]
        assert d["amount"] == "+0.07"
        assert d["approx"] is True
        # Approximate is NOT constant: the report must not claim an exactness
        # it does not have.
        assert d["constant"] is False

    def test_a_genuinely_constant_delta_is_not_marked_approximate(self):
        payload = build_payload([("c", _run(LOSES_ONE_EXP, LOSES_ONE_ACT))], [])
        d = {x["column"]: x for x in payload["cases"][0]["change_signatures"][0]["deltas"]}
        assert d["filled_ads"]["constant"] is True
        assert d["filled_ads"].get("approx") is not True

    def test_console_marks_an_approximate_delta_with_a_tilde(self):
        exp = [{"branch": "b", "k": i, "v": 1.0} for i in range(2)]
        act = [{"branch": "b", "k": 0, "v": 1.07}, {"branch": "b", "k": 1, "v": 1.0700000001}]
        text = render_console(_run(exp, act), "c")
        assert "~+0.07" in text
        assert "(constant)" not in text

    def test_a_case_without_a_breakdown_carries_none(self):
        payload = build_payload([("c", _run(LOSES_ONE_EXP, LOSES_ONE_ACT))], [])
        assert payload["cases"][0]["breakdown"] is None
