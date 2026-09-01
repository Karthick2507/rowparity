"""Read a parity SQL template and derive everything the generated files need.

PRISM's premise is that a rowparity case is not *authored* so much as it is
*implied* by the query it compares. The 83 keys are the query's GROUP BY
dimensions. The breakdown column is the one dimension that is a hardcoded
literal, different in every UNION branch. The unordered arrays are the ones
that come out of a source column rather than being constructed inline. None of
that is a judgement call; all of it is in the text.

So this module extracts a ``QueryProfile`` and ``generate.py`` renders it. The
split matters: analysis is where the risk lives (a mis-parsed SELECT list makes
every generated file wrong), so it is separable, inspectable, and testable
against a query whose correct answers are already known.

**Deliberately no SQL parser dependency.** sqlglot or sqlparse would be more
general and would also be a new runtime dependency, a new failure mode on
dialect edge cases, and a much larger thing to reason about than the six regexes
below. The queries this reads are machine-generated from one templating system
and share one shape. If that stops being true, this is the module to replace,
and the ``issues`` list is how it tells you it has stopped being true.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set

from .rules import coverage, derive_row_summary

# A placeholder, matching rowparity's own pattern exactly -- including the dot,
# because query files arrive pre-templated with namespaced names.
PLACEHOLDER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_.]*)\}")

# The marker comment that says "this branch is sampled". Counting it is how the
# generated test proves no UNION branch was left unfiltered.
SAMPLING_MARKER = "--sampling filter"

# Reference data both sides share. Templating these would let a dimension
# difference masquerade as a migration defect, so PRISM asserts they stay
# literal rather than rewriting them.
SHARED_CATALOG = "db.default"


class AnalysisError(RuntimeError):
    pass


@dataclass
class QueryProfile:
    """Everything the four generated files need, derived from one .sql file."""

    name: str                                   # f_supply_portfolio_hourly
    sql_path: str
    dimensions: List[str] = field(default_factory=list)
    metrics: List[str] = field(default_factory=list)
    branches: int = 1                           # UNION ALL branches
    placeholders: Set[str] = field(default_factory=set)
    fact_refs: int = 0                          # ${facts}. occurrences
    fact_tables: List[str] = field(default_factory=list)   # ad, ack, ...
    sampling_markers: int = 0
    batch_param: Optional[str] = None
    batch_refs: int = 0
    breakdown_by: Optional[str] = None
    breakdown_values: List[str] = field(default_factory=list)
    unordered_arrays: List[str] = field(default_factory=list)
    constructed_arrays: List[str] = field(default_factory=list)
    shared_catalogs: List[str] = field(default_factory=list)
    row_summary: List[Dict] = field(default_factory=list)
    row_summary_coverage: float = 0.0
    # Everything PRISM could not decide, or decided against the odds. A
    # generator that silently guesses is worse than one that says what it
    # guessed -- the whole point of these files is that they fail loudly.
    issues: List[str] = field(default_factory=list)

    @property
    def output_columns(self) -> int:
        return len(self.dimensions) + len(self.metrics)


# --------------------------------------------------------------------------- #
# SELECT-list parsing
# --------------------------------------------------------------------------- #
def strip_comments(sql: str) -> str:
    """Remove comments BEFORE splitting, never after.

    A comment like ``-- no use, could be removed`` contains a comma, and
    splitting first tears the SELECT item in half. Commented-out columns
    (``--,ivt_indicator``) would also be read as real ones.
    """
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    return "\n".join(re.sub(r"--.*$", "", line) for line in sql.splitlines())


def outer_select_items(sql: str) -> List[str]:
    """The outer SELECT list, split on top-level commas only."""
    body = strip_comments(sql).split("\nfrom (", 1)[0]
    marker = body.rfind("\nselect")
    if marker == -1:
        raise AnalysisError(
            "no outer 'select' found before the first 'from (' -- this does not "
            "look like an aggregate over a subquery, which is the shape PRISM reads"
        )
    body = body[marker + len("\nselect"):]
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


def output_name(item: str) -> Optional[str]:
    """The column name this SELECT item produces, or None if unparsable."""
    m = re.search(r"\bas\s+([a-z_][a-z0-9_]*)\s*$", item, re.I | re.S)
    if m:
        return m.group(1)
    m = re.fullmatch(r"(?:[a-z_][a-z0-9_]*\.)?([a-z_][a-z0-9_]*)", item.strip(), re.I)
    return m.group(1) if m else None


def split_dimensions_and_metrics(sql: str):
    """(dimensions, metrics, unparsed). A sum() is a metric; everything else a key."""
    dims, metrics, unparsed = [], [], []
    for item in outer_select_items(sql):
        name = output_name(item)
        if name is None:
            unparsed.append(item.strip()[:80])
            continue
        (metrics if re.search(r"\bsum\s*\(", item, re.I) else dims).append(name)
    return dims, metrics, unparsed


# --------------------------------------------------------------------------- #
# Individual signals
# --------------------------------------------------------------------------- #
def count_branches(sql: str) -> int:
    """UNION ALL keywords + 1. Comments stripped first so a mention is not a branch."""
    return len(re.findall(r"\bunion\s+all\b", strip_comments(sql), re.I)) + 1


def find_fact_tables(sql: str) -> List[str]:
    """The tables read through ${facts}: ad, ack, ..."""
    return sorted(set(re.findall(r"\$\{facts\}\.([a-z_][a-z0-9_]*)", sql, re.I)))


def find_batch_param(placeholders: Set[str]) -> Optional[str]:
    """The placeholder that names a batch or partition, if there is one.

    Matched by name rather than position because it arrives namespaced from
    another templating system and the namespace is not ours to predict.
    """
    for name in sorted(placeholders):
        if re.search(r"(batch|partition)_?id$", name, re.I):
            return name
    return None


def find_breakdown_column(sql: str, dimensions: List[str], branches: int):
    """The dimension that is a hardcoded literal, different in every branch.

    That is exactly the property a breakdown column needs: it partitions the
    output by which UNION branch produced the row, and because it is also a
    dimension its value is available for missing, added and changed rows alike.

    Requires one distinct literal per branch. Two branches sharing a literal
    means the column does not partition the output and would report a merged
    group as if it were one branch.
    """
    if branches < 2:
        return None, []
    best = None
    for dim in dimensions:
        literals = set(re.findall(r"'([^']*)'\s+as\s+" + re.escape(dim) + r"\b", sql, re.I))
        if len(literals) == branches:
            if best is not None:
                # Two candidates is not an error, but picking silently would be.
                return best[0], best[1]
            best = (dim, sorted(literals))
    return best if best else (None, [])


def classify_arrays(sql: str, dimensions: List[str]):
    """(unordered, constructed) array dimensions.

    The distinction is where the array comes from, and it is visible in the
    text:

        array[coalesce(slot__time_position_class, 'Unknown')]   CONSTRUCTED
        coalesce(advertisement__global_advertiser_ids, array[]) PASSED THROUGH

    A constructed single-element array cannot vary in order, so comparing it as
    a sequence is correct. One that reaches the output from a source column can
    arrive in any order the engine likes, and rowparity treats lists as ORDERED
    by default -- so without ``unordered_list_columns`` a pure ordering
    difference reads as a data difference.
    """
    unordered, constructed = [], []
    for dim in dimensions:
        m = re.search(r"^\s*,?\s*(.+?)\s+as\s+" + re.escape(dim) + r"\s*$", sql, re.I | re.M)
        if m is None:
            m = re.search(r"^\s*,\s*(array\[.+?\])\s*$", sql, re.I | re.M)
            if m is None:
                continue
        expr = m.group(1).strip()
        if not re.search(r"\barray\b", expr, re.I):
            continue
        if re.match(r"^array\s*\[", expr, re.I):
            constructed.append(dim)
        else:
            unordered.append(dim)
    return unordered, constructed


def find_shared_catalogs(sql: str) -> List[str]:
    """Literal catalogs still in the template. ``db.default`` is expected."""
    found = set(re.findall(r"\b(?:from|join)\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)\.", sql, re.I))
    return sorted(found)


# --------------------------------------------------------------------------- #
# The entry point
# --------------------------------------------------------------------------- #
def analyse(sql_path: str) -> QueryProfile:
    """Read one parity SQL template and derive its profile."""
    if not os.path.isfile(sql_path):
        raise AnalysisError(f"no such SQL file: {sql_path}")
    with open(sql_path, encoding="utf-8") as fh:
        sql = fh.read()

    name = os.path.splitext(os.path.basename(sql_path))[0]
    dims, metrics, unparsed = split_dimensions_and_metrics(sql)
    branches = count_branches(sql)
    placeholders = set(PLACEHOLDER.findall(sql))
    batch_param = find_batch_param(placeholders)
    breakdown, breakdown_values = find_breakdown_column(sql, dims, branches)
    unordered, constructed = classify_arrays(sql, dims)

    p = QueryProfile(
        name=name,
        sql_path=sql_path,
        dimensions=sorted(dims),
        metrics=sorted(metrics),
        branches=branches,
        placeholders=placeholders,
        fact_refs=sql.count("${facts}."),
        fact_tables=find_fact_tables(sql),
        sampling_markers=sql.count(SAMPLING_MARKER),
        batch_param=batch_param,
        batch_refs=sql.count("${" + batch_param + "}") if batch_param else 0,
        breakdown_by=breakdown,
        breakdown_values=breakdown_values,
        unordered_arrays=sorted(unordered),
        constructed_arrays=sorted(constructed),
        shared_catalogs=find_shared_catalogs(sql),
        row_summary=derive_row_summary(sorted(dims)),
    )

    p.row_summary_coverage = coverage(p.dimensions, p.row_summary)

    # ---- everything PRISM wants a human to look at --------------------------
    if unparsed:
        p.issues.append(
            f"{len(unparsed)} SELECT item(s) could not be named, so the "
            f"dimension/metric split is incomplete: {unparsed[:2]}"
        )
    if not dims:
        p.issues.append("no dimensions found -- the generated case would be keyless")
    if not metrics:
        p.issues.append("no sum() metrics found -- is this really an aggregate?")
    if "facts" not in placeholders:
        p.issues.append(
            "no ${facts} placeholder: both sides would read the same tables and "
            "the run would report EQUIVALENT regardless of the data"
        )
    if p.fact_refs and p.fact_refs < branches:
        p.issues.append(
            f"{p.fact_refs} ${{facts}} reference(s) but {branches} UNION branch(es) -- "
            f"a branch may still read a hardcoded catalog"
        )
    if "sampling_filter" in placeholders and p.sampling_markers != branches:
        p.issues.append(
            f"{p.sampling_markers} '{SAMPLING_MARKER}' marker(s) for {branches} branch(es) -- "
            f"an unsampled branch skews the aggregate while the total still looks plausible"
        )
    if batch_param and p.batch_refs != branches:
        p.issues.append(
            f"{p.batch_refs} batch predicate(s) for {branches} branch(es) -- "
            f"a branch pinned to a different window reads a different population on BOTH sides"
        )
    if not batch_param:
        p.issues.append(
            "no batch/partition placeholder found; the generated case will have "
            "no required parameter and can run over an unbounded window"
        )
    if branches > 1 and not breakdown:
        p.issues.append(
            f"{branches} UNION branches but no dimension is a distinct literal per "
            f"branch, so no breakdown_by was set -- differences will be one "
            f"undifferentiated pile"
        )
    for cat in p.shared_catalogs:
        if cat != SHARED_CATALOG:
            p.issues.append(
                f"literal catalog '{cat}' in the template; if it is a FACT table it "
                f"must go through ${{facts}}, if it is shared reference data it is fine"
            )
    if p.row_summary:
        p.issues.append(
            f"row_summary came from column-name rules (prism/rules.py), not from the "
            f"query -- it is a presentation choice. {len(p.row_summary)} group(s) "
            f"covering {p.row_summary_coverage:.0%} of dimensions; review them."
        )
    return p
