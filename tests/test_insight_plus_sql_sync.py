"""One SQL file, parameterised per side -- and what still has to be checked.

There were two copies of this query, ~2,000 lines each, differing in three
lines. A test diffed them after normalising the catalog away, because at 185 KB
"identical apart from the catalog" is a promise you cannot verify by eye. That
test is gone, along with the file it was guarding: the query now reads
``from ${facts}.ad`` and each side supplies ``facts``. A file cannot drift from
itself, so the entire class of "someone edited one copy" is unrepresentable
rather than merely tested for.

That was never the only hazard, though, and collapsing to one file changes the
shape of the remaining ones rather than removing them:

* **The population guard.** Comparing a sampled side against an unsampled one
  is not a comparison -- every sum is over a different number of rows. This
  cost a 77-minute run to learn (2,719 rows vs 1,113,423, a ratio of 409). The
  filter is now a single case-level var used by both sides, so "one side
  sampled" is also unrepresentable; what these tests check is that it stayed
  that way, i.e. that nobody moved it into a per-side ``vars:`` block.
* **The substitution must reproduce the original queries exactly.** The
  template was mechanically derived from the old Hoover file, and both renders
  were verified byte-for-byte against the two originals before they were
  deleted. The renders are pinned here so a future edit to the template cannot
  quietly change what runs.
* **The dimension catalog is shared.** ``d_network`` and ``d_ad_unit`` live in
  ``db.default`` for both sides. Templating them would let a dimension
  difference masquerade as a migration defect, so they stay literal -- and that
  is now guaranteed by there being one file, not asserted by a test.
"""
import os
import re

import pytest
import yaml

from rowparity.params import _PLACEHOLDER, substitute

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL = os.path.join(ROOT, "sql", "insight_plus", "f_demand_portfolio_hourly.sql")
CASE = os.path.join(ROOT, "scripts", "cases_insight_plus", "f_demand_portfolio_hourly.yaml")

HOOVER = "mrm_log_flat.default"
HOOVER_PLUS = "etl.public_test1"

SAMPLING_MARKER = "--sampling filter"
EXPECTED_SAMPLING_LINES = 3  # one per UNION ALL branch
EXPECTED_FACT_REFS = 3       # ad, ack, ack

BATCH_PLACEHOLDER = "${arena.presto.var.process_batch_id}"
EXPECTED_BATCH_REFS = 3      # one predicate per UNION ALL branch


@pytest.fixture(scope="module")
def sql():
    if not os.path.isfile(SQL):
        pytest.skip(f"{SQL} not present")
    with open(SQL, encoding="utf-8") as fh:
        return fh.read()


@pytest.fixture(scope="module")
def case():
    with open(CASE, encoding="utf-8") as fh:
        return yaml.safe_load(fh)["cases"][0]


@pytest.fixture(scope="module")
def variables(case):
    """Exactly what a run resolves, minus the batch id, which has no default."""
    base = dict(case["vars"])
    base["arena.presto.var.process_batch_id"] = "20260812010000"
    return base


def _render(sql_text, variables, facts):
    return substitute(sql_text, {**variables, "facts": facts})


class TestTheTemplate:
    def test_it_has_exactly_the_placeholders_we_expect(self, sql):
        # A new placeholder that nothing supplies fails the run at
        # substitution time, which is loud but late -- after the operator has
        # exported credentials and started waiting. Catch it here instead.
        assert set(_PLACEHOLDER.findall(sql)) == {
            "facts",
            "sampling_filter",
            "arena.presto.var.process_batch_id",
        }

    def test_every_fact_table_goes_through_the_placeholder(self, sql):
        assert sql.count("${facts}.") == EXPECTED_FACT_REFS

    def test_every_batch_predicate_goes_through_the_placeholder(self, sql):
        """Count, not presence -- presence is blind to a partially broken file.

        The placeholder assertion above uses a *set*, so hardcoding the batch in
        one of the three branches leaves the other two and the set is unchanged.
        The substitution test in test_insight_plus_case.py is blind to it for a
        worse reason: it renders with BATCH = "20260812010000" and asserts that
        string appears, so a branch hardcoded to any plausible batch id
        satisfies it -- the literal someone would paste in IS the literal the
        test looks for.

        One branch pinned to a stale batch returns rows for a different hour
        than the other two, on both sides. The totals stay plausible, the run
        does not error, and the drift reads as a migration defect.
        """
        assert sql.count(BATCH_PLACEHOLDER) == EXPECTED_BATCH_REFS

    def test_no_batch_id_is_hardcoded(self, sql):
        # Belt and braces for the count above: catches a batch predicate added
        # with a literal rather than one converted to a literal.
        literals = re.findall(r"process_batch_id\s*=\s*'(\d{8,14})'", sql)
        assert literals == [], f"hardcoded batch id(s) in the template: {literals}"

    def test_no_catalog_is_hardcoded_any_more(self, sql):
        # A fact table left pointing at a literal catalog would read the same
        # data on both sides and silently agree.
        assert HOOVER not in sql
        assert HOOVER_PLUS not in sql

    def test_the_dimension_catalog_stays_literal(self, sql):
        # Shared reference data. If it were per-side, a dimension difference
        # would be reported as a migration defect.
        for name in ("d_network", "d_ad_unit"):
            refs = re.findall(rf"from\s+(\S+)\.{name}\b|join\s+(\S+)\.{name}\b", sql)
            catalogs = {c for pair in refs for c in pair if c}
            assert catalogs == {"db.default"}, f"{name} read from {catalogs or 'nowhere'}"


class TestRenderingBothSides:
    def test_each_side_reads_only_its_own_catalog(self, sql, variables):
        hoover = _render(sql, variables, HOOVER)
        plus = _render(sql, variables, HOOVER_PLUS)
        assert HOOVER in hoover and HOOVER_PLUS not in hoover
        assert HOOVER_PLUS in plus and HOOVER not in plus

    def test_the_two_renders_differ_only_in_the_catalog(self, sql, variables):
        # The property the old two-file sync test existed to establish, now
        # cheap to state directly.
        hoover = _render(sql, variables, HOOVER).replace(HOOVER, "@FACTS@")
        plus = _render(sql, variables, HOOVER_PLUS).replace(HOOVER_PLUS, "@FACTS@")
        assert hoover == plus

    def test_a_render_leaves_no_placeholder_behind(self, sql, variables):
        # An unsubstituted ${...} reaching Presto inside quotes is a valid
        # string matching no batch: both sides return nothing and the run
        # reports EQUIVALENT. params.substitute raises instead, but only for
        # names it recognises -- so assert the rendered text is clean.
        assert not _PLACEHOLDER.search(_render(sql, variables, HOOVER))


class TestBothSidesSampleIdentically:
    """The population guard, in its new shape.

    The filter is one case-level var used by both sides, so the two cannot
    differ. These tests check that structure holds -- that it was not moved
    into a per-side block, and that it still tests the bit it claims to.
    """

    def test_the_filter_is_case_level_not_per_side(self, case):
        assert "sampling_filter" in case["vars"]
        for side in ("expected", "actual"):
            assert "sampling_filter" not in (case[side].get("vars") or {}), (
                f"{side} overrides the sampling filter. A per-side filter means "
                f"the two sides sample differently, and the run then measures "
                f"the sampling ratio rather than the migration."
            )

    def test_every_union_branch_is_sampled(self, sql):
        count = sql.count(SAMPLING_MARKER)
        assert count == EXPECTED_SAMPLING_LINES, (
            f"expected {EXPECTED_SAMPLING_LINES} sampling filters (one per UNION "
            f"ALL branch), found {count}. A branch without the filter contributes "
            f"unsampled rows and skews the whole aggregate -- and because the "
            f"other branches are still sampled, the total still looks plausible."
        )

    def test_the_default_filter_tests_bit_59(self, variables):
        predicate = variables["sampling_filter"]
        assert "request__bit_flags" in predicate
        assert re.search(
            r"bitwise_left_shift\(\s*BIGINT\s*'1'\s*,\s*59\s*\)", predicate
        ), f"not the expected bit-59 test: {predicate}"

    def test_the_filter_reaches_every_branch_when_rendered(self, sql, variables):
        rendered = _render(sql, variables, HOOVER)
        assert rendered.count(variables["sampling_filter"]) == EXPECTED_SAMPLING_LINES


class TestTheRenderMatchesWhatUsedToRun:
    """Pins the exact text of the queries the two-file version executed.

    Both renders were verified byte-for-byte against the deleted originals when
    the template was derived. These fragments are the parts a careless edit
    would most plausibly break -- the fact-table reads and the sampled
    predicate -- kept so the pinning survives the files themselves.
    """

    @pytest.mark.parametrize(
        "facts,tables",
        [(HOOVER, ("ad", "ack")), (HOOVER_PLUS, ("ad", "ack"))],
        ids=["hoover", "hoover++"],
    )
    def test_the_fact_reads_render_as_they_did(self, sql, variables, facts, tables):
        rendered = _render(sql, variables, facts)
        for table in tables:
            assert f"from {facts}.{table}" in rendered

    def test_the_sampled_predicate_renders_verbatim(self, sql, variables):
        expected = (
            "and bitwise_and(coalesce(request__bit_flags, BIGINT '0'),"
            "bitwise_left_shift(BIGINT '1', 59)) > 0 --sampling filter"
        )
        assert expected in _render(sql, variables, HOOVER)
