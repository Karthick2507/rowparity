"""Every check scripts/cases_insight_plus/*.yaml and its SQL need, in one file.

This is the ONLY test file for the insight_plus case directory. It replaces two
things that used to be separate: a hand-written (or PRISM-generated) wiring
test per case, and a hand-written (or PRISM-generated) sql-sync test per case.
Both were the same shape for every case, differing only in constants a human
had retyped from the Case object or counted out of that case's own SQL text.
Neither kind of file exists anymore -- PRISM writes a case YAML and a
drilldown SQL skeleton, nothing else, and this file discovers every case
under CASES_DIR and parametrizes over the result, deriving everything it
checks from the Case object and its own SQL, never from a constant written
for one case.

Two different KINDS of check live here on purpose:

* Case-shape checks (TestWiring, TestBatchParameter's first three, TestKeys...)
  ask the Case object: does it load, do the keys match the parsed dimensions,
  does an omitted batch raise. These are identical in shape for every case.
* Raw-template checks (TestBatchParameter's last two, TestTheRawTemplate) scan
  the SQL TEXT directly, per UNION branch where it matters. A query with N
  branches can have some branches correctly templated and one silently
  reverted to a hardcoded literal -- the run still returns plausible numbers
  on both sides, nothing errors, and the drift reads as a migration defect
  instead of a stale test fixture. Whole-document checks (does the batch
  value appear ANYWHERE, is the catalog different ANYWHERE) cannot see that;
  only a per-branch check can. Proven empirically, not just asserted: with one
  of a 7-branch query's batch predicates hardcoded to a stale literal, the
  case-shape checks all still passed -- 16 passed, 2 skipped, no failures --
  while the raw-template checks caught it immediately.

Every expected value below is DERIVED, never typed in as a per-case literal:
the placeholder set a case may use comes from its own vars: block plus facts
and its own batch parameter, not a list someone transcribed; the "no branch
was skipped" checks come from splitting the SQL on UNION ALL, not a count
written once at generation time. That is what makes one file correct for
every case in the directory, present and future, with nothing to edit when a
case is added.

Drop a new case's .sql/.yaml pair in beside f_demand_portfolio_hourly's (by
hand, or via `python -m prism generate` -- see prism/README.md) and it is
covered the moment pytest collects this file.

Offline only -- no connection is made, ever.
"""

from __future__ import annotations

import os
import re

import pytest
import yaml

from rowparity.cases import Case, discover_cases
from rowparity.params import _PLACEHOLDER, ParamError, merge_side_vars
from rowparity.sources import resolve_query

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES_DIR = os.path.join(REPO, "scripts", "cases_insight_plus")

# A syntactically valid batch id, used only to prove substitution WORKS. Its
# value is arbitrary -- no query is ever executed against it -- so one value
# serves every case; only the PARAMETER'S NAME differs between cases, and
# that is derived per case below, never hardcoded.
BATCH = "20260812010000"


def _discover(params):
    if not os.path.isdir(CASES_DIR):
        return []
    return discover_cases(CASES_DIR, params, resolve_queries=False)


# Collected once, at import time, so pytest can parametrize on it. This is
# wrapped, not left to raise: a raw exception here is a pytest COLLECTION
# error, and pytest's default behaviour on a collection error is to abort the
# entire session -- every unrelated test file, not just this one. One broken
# case YAML would then take down every other test file in tests/ too.
#
# So a discovery failure is stored, CASE_NAMES becomes empty (parametrizing
# over nothing produces zero test items, not an error), and the one test below
# turns the stored exception into an ordinary, clearly-named test failure
# instead.
try:
    _UNPARAMETRISED_CASES = _discover({})
    _DISCOVERY_ERROR = None
except Exception as exc:  # noqa: BLE001 -- reported as a test failure, not swallowed
    _UNPARAMETRISED_CASES = []
    _DISCOVERY_ERROR = exc

CASE_NAMES = [c.name for c in _UNPARAMETRISED_CASES]


def test_the_case_directory_loads_at_all():
    """If this fails, every other test in this file was SKIPPED, not run.

    pytest cannot parametrize over cases it could not discover, so a broken
    case YAML anywhere in CASES_DIR empties CASE_NAMES for the whole module.
    Fix the error named below, then this file's usual test count comes back
    on the next collection -- there is nothing to fix in this test itself.
    """
    if _DISCOVERY_ERROR is not None:
        pytest.fail(str(_DISCOVERY_ERROR), pytrace=False)


def _find(name: str, params: dict) -> Case:
    for case in discover_cases(CASES_DIR, params, resolve_queries=False):
        if case.name == name:
            return case
    raise AssertionError(f"case {name!r} not found in {CASES_DIR}")


def _sql_path(case: Case, side: str) -> str:
    spec = case.expected if side == "expected" else case.actual
    qf = spec.get("query_file")
    assert qf, f"{case.name} [{side}]: no query_file -- inline queries aren't covered here"
    base_dir = os.path.dirname(case.source_file)
    return qf if os.path.isabs(qf) else os.path.join(base_dir, qf)


def _raw_sql(case: Case, side: str = "expected") -> str:
    with open(_sql_path(case, side), encoding="utf-8") as fh:
        return fh.read()


def _batch_param(case: Case) -> "str | None":
    """The name of this case's batch/partition parameter, or None if it has one.

    Preferred source: drilldown.time.param, which names it explicitly for
    exactly this purpose. A case without a drilldown block (or without one
    naming a param) falls back to scanning its own SQL for a placeholder
    shaped like a batch id -- the same heuristic prism/analyse.py uses when
    first deriving a case, duplicated here rather than imported so this file
    never depends on prism at test-collection time (prism is a generator, not
    a runtime dependency of anything it produces).
    """
    if case.drilldown:
        param = (case.drilldown.get("time") or {}).get("param")
        if param:
            return param
    sql = _raw_sql(case, "expected")
    placeholders = set(re.findall(r"\$\{([A-Za-z_][A-Za-z0-9_.]*)\}", sql))
    for name in sorted(placeholders):
        if re.search(r"(batch|partition)_?id$", name, re.I):
            return name
    return None


def _sql(case: Case, side: str) -> str:
    """One side's SQL, resolved exactly as load_source would."""
    spec = case.expected if side == "expected" else case.actual
    variables = merge_side_vars(spec.get("vars"), case.variables)
    return resolve_query(spec, os.path.dirname(case.source_file), variables)


# --------------------------------------------------------------------------- #
# The SELECT-list parser, INLINED on purpose -- a repo test suite must never
# import prism at run time (prism is a generator, not a dependency of what it
# generates). It is exercised here against every case's real SQL, which makes
# it a better drift guard than testing it in isolation:
# prism/tests/test_roundtrip.py checks this exact copy against prism.analyse's
# own, on the real Hoover query, so the two cannot silently diverge without a
# red test naming exactly that.
# --------------------------------------------------------------------------- #
def _strip_sql_comments(sql: str) -> str:
    # Before splitting, never after: a comment like "-- no use, could be
    # removed" contains a comma, and splitting first tears the SELECT item in
    # half. Commented-out columns would also be read as real ones.
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    return "\n".join(re.sub(r"--.*$", "", line) for line in sql.splitlines())


def _outer_select_items(sql: str):
    """The outer SELECT list, split on top-level commas only."""
    body = _strip_sql_comments(sql).split("\nfrom (", 1)[0]
    body = body[body.rfind("\nselect") + len("\nselect") :]
    items, depth, current = [], 0, []
    for ch in body:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            items.append("".join(current))
            current = []
        else:
            current.append(ch)
    items.append("".join(current))
    return [i.strip() for i in items if i.strip()]


def _output_name(item: str):
    m = re.search(r"\bas\s+([a-z_][a-z0-9_]*)\s*$", item, re.I | re.S)
    if m:
        return m.group(1)
    m = re.fullmatch(r"(?:[a-z_][a-z0-9_]*\.)?([a-z_][a-z0-9_]*)", item.strip(), re.I)
    return m.group(1) if m else None


# Presto/Trino aggregates. An output column whose OUTERMOST call is one of
# these is a measure; anything else is a dimension, and every dimension is a
# key. Keep this in step with prism/analyse.py's AGGREGATE_FUNCTIONS -- the
# drift guard in prism/tests/test_roundtrip.py is what notices if they part
# ways.
_AGGREGATES = {
    "any_value", "approx_distinct", "approx_percentile", "approx_set", "arbitrary",
    "array_agg", "avg", "bitwise_and_agg", "bitwise_or_agg", "bool_and",
    "bool_or", "checksum", "corr", "count", "count_if",
    "covar_pop", "covar_samp", "every", "geometric_mean", "histogram",
    "listagg", "map_agg", "map_union", "max", "max_by",
    "mean", "min", "min_by", "multimap_agg", "numeric_histogram",
    "set_agg", "set_union", "stddev", "stddev_pop", "stddev_samp",
    "sum", "var_pop", "var_samp", "variance",
}


def _outermost_function(item: str):
    """The OUTERMOST call, not "an aggregate appears somewhere".

    The difference is load-bearing: reduce(set_agg(x), ...) as stage yields
    one scalar per group and IS a dimension. Searching the whole expression
    for an aggregate would demote it and silently drop a real key.
    """
    expr = re.sub(r"\s+as\s+[a-z_][a-z0-9_]*\s*$", "", item.strip(), flags=re.I | re.S)
    m = re.match(r"^([a-z_][a-z0-9_]*)\s*\(", expr, re.I)
    return m.group(1).lower() if m else None


def _is_metric(item: str) -> bool:
    return _outermost_function(item) in _AGGREGATES


def _dimensions_and_metrics(sql: str):
    """(dimensions, metrics, unparsed). Every dimension name becomes a key."""
    dims, metrics, unparsed = [], [], []
    for item in _outer_select_items(sql):
        name = _output_name(item)
        if name is None:
            unparsed.append(item.strip()[:80])
            continue
        (metrics if _is_metric(item) else dims).append(name)
    return dims, metrics, unparsed


def _unordered_arrays(sql: str, dimensions):
    """Dimensions that reach the output from a source column, not array[...].

        array[coalesce(x, 'Unknown')]              constructed -> ORDERED
        coalesce(source__col, array[])              passthrough -> UNORDERED

    A constructed single-element array cannot vary in order; one that reaches
    the output from a source column can, in whatever order the engine likes.
    """
    out = []
    for dim in dimensions:
        m = re.search(r"^\s*,?\s*(.+?)\s+as\s+" + re.escape(dim) + r"\s*$", sql, re.I | re.M)
        if m is None:
            continue
        expr = m.group(1).strip()
        if not re.search(r"\barray\b", expr, re.I):
            continue
        if not re.match(r"^array\s*\[", expr, re.I):
            out.append(dim)
    return out


def _branches(sql: str):
    """Raw SQL split into its UNION ALL branch segments, comments stripped.

    Used for PER-BRANCH checks -- a whole-document "does X appear somewhere"
    check cannot tell one correctly-templated branch from six, which is
    exactly the gap a partially-reverted template hides in.
    """
    return re.split(r"\bunion\s+all\b", _strip_sql_comments(sql), flags=re.I)


def _branch_count(sql: str) -> int:
    return len(_branches(sql))


# --------------------------------------------------------------------------- #
# Fixtures. `raw` proves listing needs no --param; `case` is loaded WITH a
# batch value for anything that has to render SQL.
# --------------------------------------------------------------------------- #
@pytest.fixture(scope="module", params=CASE_NAMES, ids=CASE_NAMES)
def case_name(request):
    return request.param


@pytest.fixture
def raw(case_name):
    """The case loaded with NO --param -- proves `rowparity list` needs none."""
    return _find(case_name, {})


@pytest.fixture
def batch_param(raw):
    return _batch_param(raw)


@pytest.fixture
def case(case_name, batch_param):
    """The case loaded WITH a batch value, for anything that renders SQL."""
    params = {batch_param: BATCH} if batch_param else {}
    return _find(case_name, params)


@pytest.fixture
def dims_metrics(case):
    dims, metrics, unparsed = _dimensions_and_metrics(_raw_sql(case))
    assert unparsed == [], f"{case.name}: could not parse {unparsed[:3]}"
    return dims, metrics


@pytest.fixture
def known_placeholder_names(raw, batch_param):
    """Every placeholder name THIS case is entitled to use, derived not typed.

    facts is always side-level and always allowed -- every case compares two
    catalogs. batch_param, if this case has one, is allowed. Anything else
    raw.variables declares (e.g. sampling_filter) is allowed. A name outside
    this set reaching the rendered SQL is one nothing supplies -- loud, but
    late: after credentials are exported and someone is waiting.
    """
    names = set(raw.variables or {}) | {"facts"}
    if batch_param:
        names.add(batch_param)
    return names


pytestmark = pytest.mark.skipif(
    not CASE_NAMES and _DISCOVERY_ERROR is None,
    reason=f"no cases found under {CASES_DIR}",
)
# NOT "not CASE_NAMES" alone -- that would also skip
# test_the_case_directory_loads_at_all above whenever discovery failed,
# which is exactly the one test that must run then. A genuinely empty
# CASES_DIR (no error, just nothing to discover) still skips everything,
# since there is nothing for the parametrized tests to check either way.


class TestWiring:
    def test_case_loads(self, raw, case_name):
        assert raw.name == case_name

    def test_it_is_a_row_case(self, case):
        assert isinstance(case, Case)

    def test_default_engine_when_breakdown_or_near_miss_is_set(self, case):
        # breakdown_by and near_miss are attributed per row by the default
        # engine; a push-down engine aggregates in-warehouse and never sees
        # one, so rowparity's own guard raises the moment such a case runs.
        # Catch the same mistake here, offline, before anything is queried.
        compare = case.compare or {}
        if compare.get("breakdown_by") or compare.get("near_miss"):
            assert case.engine is None, (
                f"{case.name}: engine={case.engine!r} but breakdown_by/near_miss "
                f"is set -- these are computed per row by the default engine only"
            )

    def test_the_two_sides_share_one_query_file(self, case):
        # The scale-out pattern this whole directory exists for: one SQL file
        # parameterised per side cannot drift from itself the way two copies
        # of the same query eventually do.
        assert case.expected.get("query_file")
        assert case.expected["query_file"] == case.actual["query_file"]

    def test_the_sides_differ_only_in_the_fact_catalog(self, case):
        expected_facts = case.expected.get("vars", {}).get("facts")
        actual_facts = case.actual.get("vars", {}).get("facts")
        assert expected_facts and actual_facts, f"{case.name}: facts var missing"
        assert expected_facts != actual_facts, (
            f"{case.name}: both sides read {expected_facts!r} -- "
            f"see IdenticalSourcesError in cases.py"
        )

    def test_side_vars_carry_no_placeholder(self, case):
        # A spec value substitutes when the case LOADS, so a ${...} surviving
        # here could never resolve -- `rowparity list` would fail even with
        # a valid --param, since spec dicts don't see query_file's variables.
        for spec in (case.expected, case.actual):
            for name, value in (spec.get("vars") or {}).items():
                assert "${" not in str(value), f"{spec} {name} still carries a placeholder"

    def test_listing_needs_no_param(self, raw, case_name):
        # Re-asserted per case, not just assumed from collection: a case
        # whose spec dicts need a run-time value would break `rowparity list`
        # for the WHOLE directory, not just fail its own test.
        assert raw.name == case_name

    def test_each_side_reads_its_own_catalog(self, case):
        expected_facts = case.expected["vars"]["facts"]
        actual_facts = case.actual["vars"]["facts"]
        expected_sql, actual_sql = _sql(case, "expected"), _sql(case, "actual")
        assert expected_facts in expected_sql and actual_facts not in expected_sql
        assert actual_facts in actual_sql and expected_facts not in actual_sql

    def test_both_sides_sample_identically(self, case):
        # Only meaningful when the case declares a sampling filter at all;
        # a case with no sampling concept has nothing to check here.
        if "sampling_filter" not in (case.variables or {}):
            pytest.skip(f"{case.name} has no sampling_filter var")
        expected_sql, actual_sql = _sql(case, "expected"), _sql(case, "actual")
        marker = "--sampling filter"
        branches = _branch_count(_raw_sql(case))
        found_expected, found_actual = expected_sql.count(marker), actual_sql.count(marker)
        assert found_expected == found_actual == branches, (
            f"{case.name}: {branches} UNION branch(es) but {found_expected}/{found_actual} "
            f"sampling marker(s) on expected/actual. Comparing a sampled side against an "
            f"unsampled one measures the sampling ratio, not the migration."
        )


class TestBatchParameter:
    def test_it_substitutes_on_both_sides(self, case, batch_param):
        if not batch_param:
            pytest.skip(f"{case.name}: no batch/partition parameter detected")
        placeholder = "${" + batch_param + "}"
        for side in ("expected", "actual"):
            sql = _sql(case, side)
            assert BATCH in sql, f"{case.name} [{side}]"
            # The PLACEHOLDER form, not the bare name -- a .sql header comment
            # legitimately lists parameter names in prose, and writing them
            # bare there is correct (${...} INSIDE a comment is a real
            # substitution site). What must not survive is an unsubstituted one.
            assert placeholder not in sql, f"{case.name} [{side}] still carries the placeholder"

    def test_omitting_it_raises_rather_than_running(self, raw, batch_param):
        if not batch_param:
            pytest.skip(f"{raw.name}: no batch/partition parameter detected")
        # The false-pass guard. Silence here is what produces a green run
        # over zero rows.
        with pytest.raises(ParamError) as exc:
            _sql(raw, "expected")
        assert batch_param in str(exc.value)

    def test_the_yaml_ships_no_default_batch(self, raw, batch_param):
        if not batch_param:
            pytest.skip(f"{raw.name}: no batch/partition parameter detected")
        # A literal default would name a batch that ages out, and an aged-out
        # batch returns zero rows on both sides -- equivalent, and meaningless.
        with open(raw.source_file, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
        assert batch_param not in (doc.get("vars") or {})
        for entry in doc.get("cases", [doc]):
            if entry.get("name") == raw.name:
                assert batch_param not in (entry.get("vars") or {})

    def test_every_union_branch_references_it(self, raw, batch_param):
        # A whole-document "does the batch value appear anywhere" check
        # cannot tell one correctly-templated branch from seven -- it takes
        # a per-branch check to catch a single branch left pinned to a
        # literal while its siblings still substitute.
        if not batch_param:
            pytest.skip(f"{raw.name}: no batch/partition parameter detected")
        sql = _raw_sql(raw)
        placeholder = "${" + batch_param + "}"
        missing = [i for i, b in enumerate(_branches(sql)) if placeholder not in b]
        assert not missing, (
            f"{raw.name}: UNION branch(es) {missing} do not reference {placeholder} -- "
            f"a branch pinned to a stale batch reads a different window than the "
            f"others ON BOTH SIDES, so totals stay plausible and nothing errors."
        )

    def test_it_is_never_a_hardcoded_literal(self, raw, batch_param):
        # What a half-reverted placeholder degrades into: the bare column
        # name compared against a literal digit string instead of the
        # placeholder. Derived from batch_param's own name, not typed in.
        if not batch_param:
            pytest.skip(f"{raw.name}: no batch/partition parameter detected")
        sql = _raw_sql(raw)
        column = batch_param.rsplit(".", 1)[-1]
        literals = re.findall(rf"{re.escape(column)}\s*=\s*'(\d{{8,14}})'", sql)
        assert literals == [], f"{raw.name}: hardcoded batch id(s) {literals}"


class TestKeysMatchTheQueryDimensions:
    """The keys are the SQL's GROUP BY dimensions -- for every case equally.

    Not a business key -- nobody would call it one -- but unique by
    construction after the outer aggregation, which is all a key needs to be.

    The risk keys introduce is silent rot: add a column to a case's SELECT,
    forget to update its keys, and "the same row" quietly means something
    else. These are what would have caught it, whichever case it happened in.
    """

    def test_the_parser_accounts_for_every_output_column(self, case, dims_metrics):
        # If this fails, every assertion below is measuring the wrong thing.
        # The "unparsed == []" half of that guarantee lives in the fixture
        # itself, which raises before this test body ever runs.
        dims, metrics = dims_metrics
        assert dims, f"{case.name}: no dimensions parsed -- would be a keyless case"
        assert metrics, f"{case.name}: no metrics parsed -- is this really an aggregate?"

    def test_keys_are_exactly_the_dimensions(self, case, dims_metrics):
        dims, _ = dims_metrics
        assert sorted(case.config().keys) == sorted(dims)

    def test_no_metric_is_used_as_a_key(self, case, dims_metrics):
        # Keying on a metric makes the key change whenever the data does,
        # which pairs nothing and turns every drift into missing + added --
        # exactly the keyless behaviour the keys exist to escape.
        _, metrics = dims_metrics
        assert set(case.config().keys).isdisjoint(metrics)

    def test_keys_are_unique_names(self, case):
        keys = case.config().keys
        assert len(keys) == len(set(keys))

    def test_the_case_is_keyed_not_keyless(self, case):
        assert case.config().keys, f"{case.name}: keys were dropped; the report loses attribution"

    def test_source_ordered_arrays_are_compared_unordered(self, case, dims_metrics):
        # These are in the key, so their canonical form decides which rows
        # pair up. A different element order on the two sides makes one
        # group look like two unless it is declared unordered.
        dims, _ = dims_metrics
        expected = set(_unordered_arrays(_raw_sql(case), dims))
        if not expected:
            pytest.skip(f"{case.name}: no source-order arrays in this query")
        cfg = case.config()
        declared = set(cfg.unordered_list_columns)
        for column in expected:
            assert column in cfg.keys, f"{case.name}: {column} not a key"
            assert column in declared, (
                f"{case.name}: {column} reaches the output from a source column "
                f"but is not in unordered_list_columns"
            )


class TestTheRawTemplate:
    """What used to live in one generated test_<name>_sql_sync.py per case.

    Every check here used to compare against a hardcoded per-case constant
    (EXPECTED_FACT_REFS = 6, and so on) that PRISM typed into the file at
    generation time -- which is exactly the duplication this file exists to
    remove. Each is rewritten here to derive its own expectation: the
    placeholder set from the case's own vars:, the catalog strings from the
    case's own vars.facts, so the same test works for a 3-branch query and a
    7-branch one without a number transcribed for either.
    """

    def test_every_placeholder_is_one_this_case_declares(self, raw, known_placeholder_names):
        sql = _raw_sql(raw)
        found = set(_PLACEHOLDER.findall(sql))
        unexpected = found - known_placeholder_names
        assert not unexpected, (
            f"{raw.name}: undeclared placeholder(s) {unexpected} -- nothing "
            f"supplies these, so substitution fails at run time"
        )

    def test_neither_catalog_is_hardcoded_in_the_template(self, case):
        # ${facts} is how a catalog reaches this query. Either catalog
        # string appearing literally means some reference reverted to a
        # hardcoded copy instead -- that branch reads the same catalog on
        # both sides forever, and a comparison of a table with itself
        # always passes.
        sql = _raw_sql(case)
        expected_facts = case.expected["vars"]["facts"]
        actual_facts = case.actual["vars"]["facts"]
        assert expected_facts not in sql, f"{case.name}: {expected_facts!r} hardcoded outside ${{facts}}"
        assert actual_facts not in sql, f"{case.name}: {actual_facts!r} hardcoded outside ${{facts}}"

    def test_the_two_sides_render_identically_except_for_the_catalog(self, case):
        # A stronger claim than "each side has its own catalog": swapping
        # ${facts}'s value is the ONLY difference a render produces. Catches
        # a stray extra ${facts}-guarded branch or conditional that a
        # presence/absence check alone would miss.
        expected_facts = case.expected["vars"]["facts"]
        actual_facts = case.actual["vars"]["facts"]
        a = _sql(case, "expected").replace(expected_facts, "@FACTS@")
        b = _sql(case, "actual").replace(actual_facts, "@FACTS@")
        assert a == b, f"{case.name}: the two sides differ in more than the catalog"

    def test_a_render_leaves_no_placeholder_behind(self, case):
        for side in ("expected", "actual"):
            assert not _PLACEHOLDER.search(_sql(case, side)), (
                f"{case.name} [{side}]: an unsubstituted placeholder reaches the "
                f"engine inside quotes as a syntactically valid predicate matching "
                f"no batch -- both sides return zero rows and the diff reports "
                f"EQUIVALENT, the worst outcome available to a verification tool"
            )
