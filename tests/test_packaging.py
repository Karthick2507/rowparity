"""Packaging invariants.

A missing dependency declaration is invisible until the transitive path that
was quietly supplying it goes away -- at which point `pip install` reports
success and every entry point dies at import. That is exactly what happened
with numpy: it arrived via pyarrow until pyarrow stopped declaring any
dependencies at all.
"""

import importlib.metadata
import re
from pathlib import Path

import pytest

PYPROJECT = Path(__file__).resolve().parent.parent / "pyproject.toml"

# Modules imported unconditionally at package import time. Each must be a
# declared runtime dependency, not something inherited from another package.
UNCONDITIONAL_THIRD_PARTY_IMPORTS = {
    "pyarrow": "pyarrow",
    "numpy": "numpy",  # hashing.py, module level
    "yaml": "PyYAML",
}


def _declared_core_requirements() -> list:
    """Runtime requirements, excluding the optional extras."""
    return [r for r in (importlib.metadata.requires("rowparity") or []) if "extra ==" not in r]


@pytest.mark.parametrize("module,distribution", sorted(UNCONDITIONAL_THIRD_PARTY_IMPORTS.items()))
def test_unconditional_import_is_a_declared_dependency(module, distribution):
    declared = _declared_core_requirements()
    names = {re.split(r"[<>=!~\[; ]", r, maxsplit=1)[0].lower() for r in declared}
    assert distribution.lower() in names, (
        f"{module!r} is imported unconditionally but {distribution!r} is not a "
        f"declared runtime dependency. Declared: {sorted(names)}"
    )


def test_numpy_is_pinned_in_pyproject_not_merely_installed():
    # importlib.metadata reads installed metadata, which can lag an edit; read
    # the source of truth too so an accidental removal is caught either way.
    text = PYPROJECT.read_text(encoding="utf-8")
    core = text.split("[project.optional-dependencies]")[0]
    assert re.search(r'^\s*"numpy', core, re.MULTILINE), (
        "numpy vanished from [project] dependencies. hashing.py imports it at "
        "module level; without it a fresh install breaks on first import."
    )


def test_the_package_actually_imports():
    # The end the user experiences: a bare import of the CLI entry point.
    from rowparity.cli import main

    assert callable(main)
