"""Read a biz_service batch (a conf.yml plus the .sql files it owns) and
derive a rowparity case for each SQL file.

A "biz_service" batch does not have the shape ``analyse.py`` was built for --
no ``${facts}``-templated UNION ALL over one already-agreed key set. Instead
the BI system's own ``conf.yml`` already states, once per batch, which output
columns are dimensions and which are metrics; every ``.sql`` file in that
batch folder is queried against that ONE shared classification and becomes
its own, separate rowparity case (never merged with its siblings).

Everything this module needs is either read straight from ``conf.yml`` or
found in the SQL text by pattern -- deliberately, for the same reason
``analyse.py`` avoids a SQL parser dependency: these files come from one
templating system and share one shape, and the day that stops being true this
is the module to replace.

Two placeholder conventions arrive pre-existing in every batch's SQL, not
invented here:

* ``${DATA_FILTER_<SUFFIX>}`` -- a batch-window predicate. Its exact name
  varies per file (``${DATA_FILTER_REQUEST}``, ``${DATA_FILTER_ACK}``, ...),
  so it is found by pattern. ``conf.yml``'s own ``batch_id_filter`` map gives
  either a custom expression (keyed by the file's own basename) or nothing,
  in which case the standard ``process_batch_id`` predicate is used.
* ``${PROCESS_BATCH_ID}`` -- the BI system's own batch-id placeholder,
  appearing inside a custom ``batch_id_filter`` expression. Translated to
  rowparity's own ``${arena.presto.var.process_batch_id}`` so both systems'
  conventions can coexist in the one generated file.

A file is SKIPPED, not generated, when either signal PRISM would need is
absent: no ``mrm_log_flat.default`` reference (there is nothing to point
``${facts}`` at) or no ``${DATA_FILTER_*}`` token (there is no place to
anchor the batch predicate and the sampling filter that must sit beside it).
Generating a case anyway, silently missing one of those, would produce a
query that runs and returns plausible numbers on both sides while comparing
an unbounded window -- the exact failure mode these placeholders exist to
prevent. Skipping is conservative on purpose; it is reported, not silent.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set

import datetime

import yaml

from .analyse import AnalysisError, classify_arrays, output_name, strip_comments

# The BI system's own facts catalog+schema, matching analyse.py's default for
# the expected (Hoover) side. The literal PRISM looks for and replaces with
# ${facts}.
FACTS_CATALOG = "mrm_log_flat.default"

DATA_FILTER_TOKEN = re.compile(r"\$\{DATA_FILTER_[A-Z_]+\}")
PROCESS_BATCH_ID_TOKEN = "${PROCESS_BATCH_ID}"
ROWPARITY_BATCH_PARAM = "${arena.presto.var.process_batch_id}"
DEFAULT_BATCH_FILTER = f"process_batch_id = '{ROWPARITY_BATCH_PARAM}'"

SAMPLING_MARKER = "--sampling filter"
DEFAULT_SAMPLING_FILTER = (
    "bitwise_and(coalesce(request__bit_flags, BIGINT '0'),"
    "bitwise_left_shift(BIGINT '1', 59)) > 0"
)

CONF_FILENAMES = ("conf.yml", "conf.yaml")


class BizServiceError(RuntimeError):
    pass


@dataclass
class BatchConf:
    """What one batch's conf.yml states, trimmed to what rowparity needs."""

    path: str
    dimensions: List[str] = field(default_factory=list)     # type suffix stripped
    metrics: List[str] = field(default_factory=list)        # type suffix stripped
    metrics_set: Set[str] = field(default_factory=set)
    batch_id_filter: Dict[str, Optional[str]] = field(default_factory=dict)


@dataclass
class FileResult:
    """One .sql file's outcome: either a generated case, or a skip with why."""

    name: str                       # file basename, no extension -- the case name
    sql_path: str
    batch_name: str
    skipped: bool = False
    skip_reason: Optional[str] = None
    keys: List[str] = field(default_factory=list)
    metrics: List[str] = field(default_factory=list)
    unparsed: List[str] = field(default_factory=list)
    unordered_arrays: List[str] = field(default_factory=list)
    constructed_arrays: List[str] = field(default_factory=list)
    data_filter_tokens: List[str] = field(default_factory=list)
    resolved_batch_filter: Optional[str] = None
    transformed_sql: Optional[str] = None
    issues: List[str] = field(default_factory=list)

    @property
    def output_columns(self) -> int:
        return len(self.keys) + len(self.metrics)


def _strip_type_suffix(name: str) -> str:
    """``ack_ad_revenue:double`` -> ``ack_ad_revenue``. Untyped names pass through."""
    return name.split(":", 1)[0].strip()


def find_conf_file(folder: str) -> Optional[str]:
    for fname in CONF_FILENAMES:
        candidate = os.path.join(folder, fname)
        if os.path.isfile(candidate):
            return candidate
    return None


def load_conf(conf_path: str) -> BatchConf:
    with open(conf_path, encoding="utf-8") as fh:
        raw = yaml.safe_load(fh) or {}
    if not isinstance(raw, dict):
        raise BizServiceError(f"{conf_path}: top level must be a mapping")

    dims = [_strip_type_suffix(d) for d in (raw.get("dimensions") or [])]
    metrics = [_strip_type_suffix(m) for m in (raw.get("metrics") or [])]
    batch_id_filter = {
        str(k): (v if v else None) for k, v in (raw.get("batch_id_filter") or {}).items()
    }
    return BatchConf(
        path=conf_path,
        dimensions=dims,
        metrics=metrics,
        metrics_set=set(metrics),
        batch_id_filter=batch_id_filter,
    )


# --------------------------------------------------------------------------- #
# A SELECT-list parser for FLAT biz_service queries.
#
# analyse.py's outer_select_items() assumes the insight_plus shape -- an outer
# aggregate over a subquery reached via "\nfrom (". biz_service queries are
# flat (``select ... from <table> ... group by``), optionally with CTEs ahead
# of the final select. This finds the LAST "select" at paren depth 0 (so a
# CTE's own internal select, always inside parens, is never mistaken for the
# output list) and reads up to the next depth-0 "from".
# --------------------------------------------------------------------------- #
def _depth_at(text: str, pos: int) -> int:
    return text.count("(", 0, pos) - text.count(")", 0, pos)


def outer_select_items_flat(sql: str) -> List[str]:
    text = strip_comments(sql)
    selects = [m.start() for m in re.finditer(r"\bselect\b", text, re.I)
               if _depth_at(text, m.start()) == 0]
    if not selects:
        raise AnalysisError("no depth-0 'select' found -- not a flat query PRISM can read")
    start = selects[-1] + len("select")

    from_pos = None
    for m in re.finditer(r"\bfrom\b", text[start:], re.I):
        pos = start + m.start()
        if _depth_at(text, pos) == 0:
            from_pos = pos
            break
    if from_pos is None:
        raise AnalysisError("no depth-0 'from' after the final select -- malformed query")

    body = text[start:from_pos]
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


def classify_columns(sql: str, conf: BatchConf):
    """(keys, metrics, unparsed), classified against conf.yml's metrics list.

    Not aggregate-function detection -- biz_service's own conf.yml already
    made this call for the whole batch, and it is the one classification the
    BI system and rowparity must agree on. A column not in ``metrics:`` is a
    key, whether or not conf.yml's ``dimensions:`` happens to name it too
    (``timestamp`` in ab_test_request.sql is such a column).
    """
    items = outer_select_items_flat(sql)
    keys, metrics, unparsed = [], [], []
    for item in items:
        name = output_name(item)
        if name is None:
            unparsed.append(item.strip()[:80])
            continue
        (metrics if name in conf.metrics_set else keys).append(name)
    return sorted(set(keys)), sorted(set(metrics)), unparsed


# --------------------------------------------------------------------------- #
# SQL transformation
# --------------------------------------------------------------------------- #
def has_facts_reference(sql: str) -> bool:
    return FACTS_CATALOG in sql


def substitute_facts(sql: str) -> str:
    return sql.replace(FACTS_CATALOG + ".", "${facts}.")


def resolve_batch_filter(conf: BatchConf, file_stem: str) -> str:
    custom = conf.batch_id_filter.get(file_stem)
    if not custom:
        return DEFAULT_BATCH_FILTER
    return custom.replace(PROCESS_BATCH_ID_TOKEN, ROWPARITY_BATCH_PARAM)


def insert_batch_and_sampling_filter(sql: str, resolved_filter: str) -> str:
    """Replace every ``${DATA_FILTER_*}`` token with the resolved batch
    predicate, and add ``${sampling_filter}`` right beside it.

    Same anchor point on purpose: the DATA_FILTER token is already inside the
    WHERE clause that reads the fact table, on both the flat-query and the
    CTE shapes alike, so inserting at that exact position is syntactically
    safe without knowing anything else about the query's structure.
    """
    def _replace(match: "re.Match[str]") -> str:
        return f"{resolved_filter}\n    and ${{sampling_filter}} {SAMPLING_MARKER}"

    return DATA_FILTER_TOKEN.sub(_replace, sql)


def transform_sql(sql: str, conf: BatchConf, file_stem: str) -> str:
    sql = substitute_facts(sql)
    resolved = resolve_batch_filter(conf, file_stem)
    return insert_batch_and_sampling_filter(sql, resolved)


# --------------------------------------------------------------------------- #
# Per-file analysis
# --------------------------------------------------------------------------- #
def analyse_file(sql_path: str, conf: BatchConf, batch_name: str) -> FileResult:
    name = os.path.splitext(os.path.basename(sql_path))[0]
    with open(sql_path, encoding="utf-8") as fh:
        sql = fh.read()

    result = FileResult(name=name, sql_path=sql_path, batch_name=batch_name)

    if not has_facts_reference(sql):
        result.skipped = True
        result.skip_reason = (
            f"no '{FACTS_CATALOG}' reference -- nothing for ${{facts}} to point at"
        )
        return result

    tokens = sorted(set(DATA_FILTER_TOKEN.findall(sql)))
    result.data_filter_tokens = tokens
    if not tokens:
        result.skipped = True
        result.skip_reason = (
            "no ${DATA_FILTER_*} token -- no anchor for the batch predicate "
            "and sampling filter"
        )
        return result

    keys, metrics, unparsed = classify_columns(sql, conf)
    result.keys, result.metrics, result.unparsed = keys, metrics, unparsed
    result.unordered_arrays, result.constructed_arrays = classify_arrays(sql, keys)
    result.resolved_batch_filter = resolve_batch_filter(conf, name)
    result.transformed_sql = transform_sql(sql, conf, name)

    if unparsed:
        result.issues.append(
            f"{len(unparsed)} SELECT item(s) could not be named: {unparsed[:2]}"
        )
    if not keys:
        result.issues.append("no key columns found -- the generated case would be keyless")
    if not metrics:
        result.issues.append(
            "no output column matched conf.yml's metrics: list -- every column became a key"
        )
    if name not in conf.batch_id_filter:
        result.issues.append(
            f"{name!r} not listed in conf.yml's batch_id_filter -- used the default "
            f"process_batch_id predicate"
        )
    return result


def analyse_batch(folder: str) -> Optional[tuple]:
    """(BatchConf, [FileResult, ...]) for one batch folder, or None if it has no conf.yml."""
    conf_path = find_conf_file(folder)
    if conf_path is None:
        return None
    conf = load_conf(conf_path)
    sql_files = sorted(
        f for f in os.listdir(folder)
        if f.endswith(".sql") and os.path.isfile(os.path.join(folder, f))
    )
    batch_name = os.path.basename(os.path.normpath(folder))
    results = [analyse_file(os.path.join(folder, f), conf, batch_name) for f in sql_files]
    return conf, results


# --------------------------------------------------------------------------- #
# Rendering: one merged case YAML, transformed SQL copies, one test file.
#
# All three live under prism/output -- PRISM never writes into the repo's
# real tree, same rule as the insight_plus pipeline. Unlike that pipeline,
# THIS one has to be additive: batches arrive incrementally over many
# separate `generate` runs, so a run must update the cases it just derived
# and leave every other batch's cases in the file untouched.
# --------------------------------------------------------------------------- #
SQL_DIR = os.path.join("sql", "biz_service")
CASE_FILE = os.path.join("scripts", "cases_biz_service.yaml")
TEST_FILE = os.path.join("tests", "test_biz_service_sql_sync.py")

DEFAULT_EXPECTED_FACTS = "mrm_log_flat.default"
DEFAULT_ACTUAL_FACTS = "etl.public_test1"
DEFAULT_EXPECTED_LABEL = "Hoover"
DEFAULT_ACTUAL_LABEL = "Hoover++"


def render_case_dict(
    result: FileResult,
    *,
    expected_facts: str = DEFAULT_EXPECTED_FACTS,
    actual_facts: str = DEFAULT_ACTUAL_FACTS,
    expected_label: str = DEFAULT_EXPECTED_LABEL,
    actual_label: str = DEFAULT_ACTUAL_LABEL,
    sampling_filter: str = DEFAULT_SAMPLING_FILTER,
) -> dict:
    """One case, as a plain dict -- ready to drop into the merged YAML's
    ``cases:`` list. Dumped with PyYAML rather than hand-formatted text,
    unlike generate.py's insight_plus renderer: at 400+ cases in one file,
    a per-case comment banner would dwarf the content, and a dict-based
    merge is what makes re-running PRISM on one batch safe for every other
    batch already in the file.
    """
    rel_sql = os.path.relpath(
        os.path.join(SQL_DIR, result.batch_name, f"{result.name}.sql"),
        os.path.dirname(CASE_FILE),
    ).replace(os.sep, "/")

    compare: dict = {
        "keys": result.keys,
        "max_examples": 50,
        "near_miss": True,
    }
    if result.unordered_arrays:
        compare["unordered_list_columns"] = result.unordered_arrays

    return {
        "name": result.name,
        "expected_label": expected_label,
        "actual_label": actual_label,
        "description": (
            f"The {result.name} biz_service query (batch {result.batch_name}) must "
            f"produce identical rows whether built from the {expected_label} layout "
            f"or the {actual_label} layout. Both sides are queries; neither is "
            f"materialised."
        ),
        "vars": {"sampling_filter": sampling_filter},
        "expected": {
            "type": "trino",
            "query_file": rel_sql,
            "vars": {"facts": expected_facts},
        },
        "actual": {
            "type": "trino",
            "query_file": rel_sql,
            "vars": {"facts": actual_facts},
        },
        "compare": compare,
        "tags": ["biz_service", "prism", result.batch_name],
    }


def _yaml_banner() -> str:
    stamp = datetime.date.today().isoformat()
    return (
        f"# Generated by PRISM (biz_service pipeline) -- last touched {stamp}.\n"
        f"#\n"
        f"# One case per SQL file, keyed by file name, across every batch dropped\n"
        f"# under prism/input/. Re-running `python -m prism generate` on one batch\n"
        f"# folder only touches that batch's own cases here -- every other batch's\n"
        f"# cases already in this file are preserved as-is.\n"
        f"#\n"
        f"# EDIT THIS FILE if you need to. Re-generating a batch overwrites only the\n"
        f"# cases derived from it.\n"
    )


def merge_cases_yaml(existing_text: Optional[str], new_cases: Dict[str, dict]) -> str:
    """The full ``cases_biz_service.yaml`` text after folding ``new_cases`` in.

    Existing cases keep their position; a case with a name PRISM just
    re-derived is replaced in place, and brand-new names are appended in
    sorted order at the end -- so a diff of this file shows exactly what one
    `generate` run changed, not a full reshuffle.
    """
    ordered: Dict[str, dict] = {}
    if existing_text:
        doc = yaml.safe_load(existing_text) or {}
        for raw in doc.get("cases") or []:
            if isinstance(raw, dict) and raw.get("name"):
                ordered[raw["name"]] = raw

    for name in sorted(new_cases):
        ordered[name] = new_cases[name]

    body = yaml.safe_dump(
        {"cases": list(ordered.values())},
        sort_keys=False,
        default_flow_style=False,
        width=100,
        allow_unicode=True,
    )
    return _yaml_banner() + "\n" + body


TEST_FILE_CONTENTS = '''"""Every check scripts/cases_biz_service.yaml and its SQL need, in one file.

Mirrors tests/test_insight_plus_sql_sync.py's shape and reasons, adapted for
the biz_service pipeline: one case per batch SQL file, keys classified from
that batch's own conf.yml rather than an aggregate-function scan, no
drilldown block (biz_service cases do not generate one).

Discovers every case in scripts/cases_biz_service.yaml and parametrizes over
the result, so a new batch is covered the moment `python -m prism generate`
folds its cases into that file -- nothing here to edit when a batch is added.

Offline only -- no connection is made, ever.
"""

from __future__ import annotations

import os
import re

import pytest

from rowparity.cases import Case, discover_cases
from rowparity.params import _PLACEHOLDER, ParamError, merge_side_vars
from rowparity.sources import resolve_query

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES_FILE = os.path.join(REPO, "scripts", "cases_biz_service.yaml")

# A syntactically valid batch id, used only to prove substitution WORKS. No
# query here is ever executed against it.
BATCH = "20260812010000"


def _discover(params):
    if not os.path.isfile(CASES_FILE):
        return []
    return discover_cases(CASES_FILE, params, resolve_queries=False)


try:
    _UNPARAMETRISED_CASES = _discover({})
    _DISCOVERY_ERROR = None
except Exception as exc:  # noqa: BLE001 -- reported as a test failure, not swallowed
    _UNPARAMETRISED_CASES = []
    _DISCOVERY_ERROR = exc

CASE_NAMES = [c.name for c in _UNPARAMETRISED_CASES]


def test_the_case_file_loads_at_all():
    """If this fails, every other test in this file was SKIPPED, not run."""
    if _DISCOVERY_ERROR is not None:
        pytest.fail(str(_DISCOVERY_ERROR), pytrace=False)


def _find(name: str, params: dict) -> Case:
    for case in discover_cases(CASES_FILE, params, resolve_queries=False):
        if case.name == name:
            return case
    raise AssertionError(f"case {name!r} not found in {CASES_FILE}")


def _sql_path(case: Case, side: str) -> str:
    spec = case.expected if side == "expected" else case.actual
    qf = spec.get("query_file")
    assert qf, f"{case.name} [{side}]: no query_file -- inline queries aren't covered here"
    base_dir = os.path.dirname(case.source_file)
    return qf if os.path.isabs(qf) else os.path.join(base_dir, qf)


def _raw_sql(case: Case, side: str = "expected") -> str:
    with open(_sql_path(case, side), encoding="utf-8") as fh:
        return fh.read()


def _sql(case: Case, side: str) -> str:
    """One side's SQL, resolved exactly as load_source would."""
    spec = case.expected if side == "expected" else case.actual
    variables = merge_side_vars(spec.get("vars"), case.variables)
    return resolve_query(spec, os.path.dirname(case.source_file), variables)


@pytest.mark.parametrize("name", CASE_NAMES)
class TestWiring:
    def test_case_loads(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        assert case.expected.get("query_file")
        assert case.actual.get("query_file")

    def test_keys_are_non_empty(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        assert case.compare.get("keys"), f"{name}: no compare.keys -- case would be keyless"

    def test_facts_differ_between_sides(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        expected_facts = (case.expected.get("vars") or {}).get("facts")
        actual_facts = (case.actual.get("vars") or {}).get("facts")
        assert expected_facts and actual_facts and expected_facts != actual_facts, (
            f"{name}: expected/actual read the SAME facts catalog -- the run would "
            f"compare a table with itself and always pass"
        )

    def test_both_sides_resolve_with_a_batch_id(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        for side in ("expected", "actual"):
            sql = _sql(case, side)
            assert not _PLACEHOLDER.search(sql), (
                f"{name} [{side}]: unresolved placeholder(s) remain after substitution"
            )

    def test_missing_batch_id_raises(self, name):
        case = _find(name, {})
        with pytest.raises(ParamError):
            _sql(case, "expected")


@pytest.mark.parametrize("name", CASE_NAMES)
class TestTheRawTemplate:
    """Scans the SQL TEXT directly -- the one thing case-shape checks can't see."""

    def test_no_hardcoded_facts_catalog_remains(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        raw = _raw_sql(case, "expected")
        assert "mrm_log_flat.default." not in raw, (
            f"{name}: a hardcoded facts reference survived generation -- both sides "
            f"would read the SAME table regardless of ${{facts}}"
        )

    def test_sampling_filter_is_present(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        raw = _raw_sql(case, "expected")
        assert "${sampling_filter}" in raw and "--sampling filter" in raw, (
            f"{name}: no sampling filter marker -- an unsampled read skews the "
            f"aggregate while the totals still look plausible"
        )

    def test_no_data_filter_token_remains(self, name):
        case = _find(name, {"arena.presto.var.process_batch_id": BATCH})
        raw = _raw_sql(case, "expected")
        assert not re.search(r"\\$\\{DATA_FILTER_[A-Z_]+\\}", raw), (
            f"{name}: an unresolved ${{DATA_FILTER_*}} token survived generation"
        )
'''

