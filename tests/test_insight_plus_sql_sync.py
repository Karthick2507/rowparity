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

**The only difference allowed is the catalog the fact tables are read from.**

That was not always true. Hoover++ originally carried no sampling filter, on
the understanding that its source was already the bit-59 sample. A live run
disproved it: Hoover produced 2,719 rows and Hoover++ 1,113,423 -- a ratio of
409, which is a sampling difference, not a migration defect. The filter now
applies to both sides, and Hoover++ is generated from Hoover by swapping the
catalog, so nothing else can drift.

Everything else -- projections, joins, CASE ladders, WHERE predicates, GROUP BY
ordinals, the sampling filter itself -- must match byte for byte once the
catalog is normalised away.
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
    """Strip the one intended difference, plus trailing whitespace.

    The sampling filter is deliberately NOT stripped any more: it applies to
    both sides now, so it has to match like everything else. Stripping it would
    let one side lose it silently -- which is precisely the bug that cost a
    77-minute run.
    """
    out = []
    for line in text.splitlines():
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


class TestBothSidesSampleIdentically:
    """The population guard.

    Comparing a sampled side against an unsampled one is not a comparison at
    all: every sum is over a different number of rows. That is not a tolerance
    problem, and no rowparity setting rescues it -- the run simply measures the
    sampling ratio. It cost 77 minutes to learn once.
    """

    @pytest.mark.parametrize("which", [0, 1], ids=["hoover", "hoover++"])
    def test_every_union_branch_is_sampled(self, sources, which):
        count = sources[which].count(SAMPLING_MARKER)
        assert count == EXPECTED_SAMPLING_LINES, (
            f"expected {EXPECTED_SAMPLING_LINES} sampling filters (one per UNION "
            f"ALL branch), found {count}. A branch without the filter contributes "
            f"unsampled rows and skews the whole aggregate -- and because the "
            f"other branches are still sampled, the total looks plausible."
        )

    def test_the_sampling_filter_tests_bit_59_on_both_sides(self, sources):
        for text in sources:
            for line in text.splitlines():
                if SAMPLING_MARKER in line:
                    assert "request__bit_flags" in line
                    assert re.search(
                        r"bitwise_left_shift\(\s*BIGINT\s*'1'\s*,\s*59\s*\)", line
                    ), f"not the expected bit-59 test: {line.strip()}"

    def test_a_side_losing_its_filter_would_fail(self, sources):
        # The specific regression: silently reverting Hoover++ to unsampled.
        hoover, plus = sources
        tampered = "\n".join(
            ln for ln in plus.splitlines() if SAMPLING_MARKER not in ln
        )
        assert _normalise(hoover) != _normalise(tampered)

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
