"""The two Hoover SQL files must stay identical apart from the two intended
differences.

The comparison is only meaningful if both sides run the *same* aggregate. If
someone edits one file and not the other, the run still succeeds and still
reports differences -- but those differences are the SQL, not the data, and
nothing in the output says so. That is a wrong answer wearing the costume of a
right one.

Both files are ~2000 lines with a positional GROUP BY (``group by 1,2,...,77,
189,190,259,...``). Inserting a single column shifts every ordinal after it and
changes what the query means, while still parsing and running cleanly. No
reviewer catches that by eye.

The only differences allowed:

1. the catalog/schema the fact tables are read from
2. the bit-59 sampling filter, present on Hoover and absent on Hoover++

Everything else -- projections, joins, CASE ladders, WHERE predicates, GROUP BY
ordinals -- must match byte for byte once (1) and (2) are normalised away.
"""
import os
import re

import pytest

SQL_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sql", "insight_plus"
)
HOOVER = os.path.join(SQL_DIR, "f_demand_portfolio_hourly_hoover.sql")
HOOVER_PLUS = os.path.join(SQL_DIR, "f_demand_portfolio_hourly_hoover++.sql")

# The fact-table locations, and the shared dimension catalog. d_network and
# d_ad_unit both live in db.default on BOTH sides -- one of them briefly did
# not, which would have made a dimension difference look like a migration
# defect. Normalising them to the same token means a future divergence there
# fails this test rather than passing silently.
_CATALOGS = (
    ("mrm_log_flat.default", "@FACTS@"),
    ("etl.public_test1", "@FACTS@"),
    ("db.default", "@DIMS@"),
)

SAMPLING_MARKER = "--sampling filter"
EXPECTED_SAMPLING_LINES = 3  # one per UNION ALL branch


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def _normalise(text: str) -> str:
    """Strip the two intended differences, plus trailing whitespace."""
    out = []
    for line in text.splitlines():
        if SAMPLING_MARKER in line:
            continue
        for literal, token in _CATALOGS:
            line = line.replace(literal, token)
        out.append(line.rstrip())
    return "\n".join(out)


@pytest.fixture(scope="module")
def sources():
    for path in (HOOVER, HOOVER_PLUS):
        if not os.path.isfile(path):
            pytest.skip(f"{path} not present")
    return _read(HOOVER), _read(HOOVER_PLUS)


class TestTheTwoFilesAreOneQuery:
    def test_identical_once_catalog_and_sampling_are_normalised(self, sources):
        hoover, plus = sources
        a, b = _normalise(hoover), _normalise(plus)
        if a != b:
            import difflib

            diff = "\n".join(
                difflib.unified_diff(
                    a.splitlines(), b.splitlines(),
                    fromfile="hoover (normalised)", tofile="hoover++ (normalised)",
                    lineterm="", n=2,
                )
            )
            raise AssertionError(
                "The two queries have diverged beyond catalog and sampling.\n"
                "Whatever this diff shows would be reported as a DATA difference "
                "by the parity run.\n\n" + diff
            )

    def test_group_by_ordinals_match_exactly(self, sources):
        # Called out separately because it is the highest-consequence, least
        # visible way these files can drift: the ordinals still parse after a
        # column is inserted, they just mean something else.
        hoover, plus = sources
        a = [ln.strip() for ln in hoover.splitlines() if ln.strip().startswith("group by")]
        b = [ln.strip() for ln in plus.splitlines() if ln.strip().startswith("group by")]
        assert a == b, "GROUP BY ordinal lists differ between the two files"
        assert a, "no GROUP BY found -- has the query shape changed?"


class TestTheIntendedDifferencesAreStillThere:
    """Guard the other direction: normalising must not hide a real problem.

    If the sampling filter were dropped from Hoover, or Hoover++ started
    reading the Hoover tables, the test above would still pass -- the files
    would simply be identical. These assert the differences that are supposed
    to exist.
    """

    def test_hoover_samples_every_union_branch(self, sources):
        hoover, _ = sources
        count = hoover.count(SAMPLING_MARKER)
        assert count == EXPECTED_SAMPLING_LINES, (
            f"expected {EXPECTED_SAMPLING_LINES} sampling filters in Hoover "
            f"(one per UNION ALL branch), found {count}. A branch without the "
            f"filter contributes unsampled rows and skews the whole aggregate."
        )

    def test_hoover_plus_samples_nothing(self, sources):
        _, plus = sources
        assert SAMPLING_MARKER not in plus, (
            "Hoover++ carries a sampling filter. Its source data is already the "
            "bit-59 sample, so filtering again would sample the sample."
        )

    def test_the_sampling_filter_tests_bit_59(self, sources):
        hoover, _ = sources
        for line in hoover.splitlines():
            if SAMPLING_MARKER in line:
                assert "request__bit_flags" in line
                assert re.search(r"bitwise_left_shift\(\s*BIGINT\s*'1'\s*,\s*59\s*\)", line), (
                    f"sampling filter is not the expected bit-59 test: {line.strip()}"
                )

    def test_each_side_reads_only_its_own_catalog(self, sources):
        hoover, plus = sources
        assert "mrm_log_flat.default" in hoover
        assert "etl.public_test1" not in hoover
        assert "etl.public_test1" in plus
        assert "mrm_log_flat.default" not in plus

    def test_both_sides_share_the_dimension_catalog(self, sources):
        # d_network and d_ad_unit are shared reference data. If one side ever
        # points somewhere else, a dimension difference shows up as a data
        # difference and gets investigated as a migration defect.
        hoover, plus = sources
        for name in ("d_network", "d_ad_unit"):
            for label, text in (("hoover", hoover), ("hoover++", plus)):
                refs = re.findall(rf"from\s+(\S+)\.{name}\b|join\s+(\S+)\.{name}\b", text)
                catalogs = {c for pair in refs for c in pair if c}
                assert catalogs == {"db.default"}, (
                    f"{label}: {name} read from {catalogs or 'nowhere'}, expected "
                    f"{{'db.default'}}"
                )


class TestNormalisationIsNotVacuous:
    """The normaliser must not be so aggressive it would hide a real edit."""

    def test_a_changed_projection_would_fail(self, sources):
        hoover, plus = sources
        tampered = plus.replace("as placed_ads", "as placed_ads_RENAMED", 1)
        assert tampered != plus, "fixture assumption broken: marker not found"
        assert _normalise(hoover) != _normalise(tampered)

    def test_a_shifted_group_by_would_fail(self, sources):
        hoover, plus = sources
        tampered = plus.replace("group by 1,2,3", "group by 1,2,4", 1)
        assert tampered != plus, "fixture assumption broken: marker not found"
        assert _normalise(hoover) != _normalise(tampered)

    def test_an_extra_where_predicate_would_fail(self, sources):
        hoover, plus = sources
        tampered = plus.replace(
            "    and bitwise_and(slot__flags, 64) = 0",
            "    and bitwise_and(slot__flags, 64) = 0\n    and network_id > 0",
            1,
        )
        assert tampered != plus, "fixture assumption broken: marker not found"
        assert _normalise(hoover) != _normalise(tampered)
