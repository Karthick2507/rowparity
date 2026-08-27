"""CODE_FLOW.md must keep describing code that exists.

A walkthrough naming functions goes stale the moment one is renamed, and
nothing about a stale document looks wrong -- it reads exactly as confidently
as a correct one. That is the same failure mode as a green run over zero rows:
a confident answer to a question nobody actually asked.

So every ``module.function()`` reference in the document is resolved against
the package. A rename breaks this test instead of leaving the docs quietly
lying.

Deliberately NOT checked: line numbers. They drift with every edit and pinning
them would make this test fail constantly for no gain, which is why the
document marks them indicative.
"""
import importlib
import os
import re

import pytest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(REPO, "CODE_FLOW.md")

# `module.function()` where module is a rowparity module -- the form the
# document uses for code references.
REFERENCE = re.compile(r"\b([a-z_]+)\.([a-z_][a-z0-9_]*)\(\)")

# Modules the document may reference. Anything else in `x.y()` form is prose or
# third-party (yaml.safe_load, pa.table) and is not our business to verify.
MODULES = {
    "cases", "cli", "compare", "hashing", "params", "param_queries",
    "progress", "report", "sources", "trino_auth", "schema_check",
    "exclusions", "equivalence", "schema_introspect",
}

# Methods documented as `Case.run()` etc. -- class, then attribute.
CLASS_REFERENCE = re.compile(r"\b([A-Z][A-Za-z]+)\.([a-z_][a-z0-9_]*)\(\)")
CLASSES = {
    "Case": ("rowparity.cases", "Case"),
    "SchemaCheckCase": ("rowparity.schema_check", "SchemaCheckCase"),
    "ConceptCheckCase": ("rowparity.concept_check", "ConceptCheckCase"),
}


FENCED_BLOCK = re.compile(r"^```.*?^```", re.M | re.S)


@pytest.fixture(scope="module")
def raw_doc() -> str:
    if not os.path.isfile(DOC):
        pytest.skip("CODE_FLOW.md not present")
    with open(DOC, encoding="utf-8") as fh:
        return fh.read()


@pytest.fixture(scope="module")
def doc(raw_doc) -> str:
    """The document with fenced code blocks removed.

    Code blocks are excerpts of real source, so they contain ordinary attribute
    access -- ``self.compare.items()`` reads as ``compare.items()`` to the
    regex and sent this test looking for a function that was never claimed to
    exist. The prose is where the document makes its claims, so the prose is
    what gets verified.
    """
    return FENCED_BLOCK.sub("", raw_doc)


class TestReferencesResolve:
    def test_every_module_function_exists(self, doc):
        missing = []
        for module, func in set(REFERENCE.findall(doc)):
            if module not in MODULES:
                continue
            mod = importlib.import_module(f"rowparity.{module}")
            if not hasattr(mod, func):
                missing.append(f"{module}.{func}()")
        assert not missing, f"CODE_FLOW.md names functions that do not exist: {sorted(missing)}"

    def test_every_class_method_exists(self, doc):
        missing = []
        for cls_name, attr in set(CLASS_REFERENCE.findall(doc)):
            if cls_name not in CLASSES:
                continue
            module, name = CLASSES[cls_name]
            cls = getattr(importlib.import_module(module), name)
            if not hasattr(cls, attr):
                missing.append(f"{cls_name}.{attr}()")
        assert not missing, f"CODE_FLOW.md names methods that do not exist: {sorted(missing)}"

    def test_it_actually_found_references(self, doc):
        # Guards the two tests above against passing because the regex matched
        # nothing -- the classic way a "check the docs" test becomes a no-op.
        found = {m for m, _ in REFERENCE.findall(doc) if m in MODULES}
        assert len(found) >= 8, f"only matched modules {sorted(found)}; has the doc's style changed?"


class TestDocumentedFactsHoldInCode:
    """Spot-check claims the document makes that a reader would act on."""

    def test_the_entry_point_is_what_the_doc_says(self, raw_doc):
        with open(os.path.join(REPO, "pyproject.toml"), encoding="utf-8") as fh:
            pyproject = fh.read()
        assert 'rowparity = "rowparity.cli:main"' in pyproject
        assert "rowparity.cli:main" in raw_doc

    def test_exit_codes_match_the_cli(self, doc):
        # The doc tabulates 0 / 1 / 2 and CI depends on the distinction.
        from rowparity import cli

        source = open(cli.__file__, encoding="utf-8").read()
        assert "return 2" in source          # load / config failure
        assert "return 1 if failures else 0" in source
        for code in ("| 0 |", "| 1 |", "| 2 |"):
            assert code in doc

    def test_the_five_csv_statuses_are_the_real_ones(self, doc):
        from rowparity import report

        for status in (
            report.STATUS_MATCHED, report.STATUS_TYPE_DIFF, report.STATUS_VALUE_DIFF,
            report.STATUS_EQUIVALENT, report.STATUS_DIFF,
        ):
            assert f"`{status}`" in doc, f"{status!r} missing from the status table"

    def test_the_digest_is_still_blake2b_16_bytes(self, raw_doc):
        from rowparity.hashing import row_digest

        assert len(row_digest((("a", (1,)),))) == 16
        assert "blake2b" in raw_doc

    def test_keyless_still_cannot_report_changed(self, doc):
        # The document tells readers changed_count is 0 by construction without
        # a key. If that ever stops being true the doc misleads.
        import pyarrow as pa

        from rowparity.compare import CompareConfig, compare_tables

        exp = pa.Table.from_pylist([{"v": 1}])
        act = pa.Table.from_pylist([{"v": 2}])
        result = compare_tables(exp, act, CompareConfig())
        assert result.changed_count == 0
        assert result.missing_count == 1 and result.added_count == 1
