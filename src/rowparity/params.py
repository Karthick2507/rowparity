"""Case parameterisation: ``${name}`` placeholders in a case.

A case file is otherwise fully static, which is a problem for anything that
changes per run -- a batch id, a partition date, a catalog name while a
migration is in flight. This resolves ``${name}`` placeholders from three
sources, in increasing precedence:

    vars: block in the case YAML   <   ROWPARITY_VAR_<NAME> env var   <   --param NAME=VALUE

so a case file carries a sensible default, CI can override it per run
without editing YAML, and a one-off local run can override that again.

Two deliberate choices:

* **Names are case-insensitive.** ``${batch_id}`` and ``${BATCH_ID}`` resolve
  to the same value, because the env-var form has to be upper-cased and
  silently failing to match that would be a nasty footgun.
* **An unresolved placeholder is a hard error, never a passthrough.** The
  alternative is querying a table literally named ``${batch_id}``, which
  fails later, further away, and more confusingly -- or worse, silently
  matches nothing and reports a clean pass.

A case with no ``${...}`` in it is unaffected, so this is invisible to every
existing case.
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, Iterable, Mapping, Optional

# Only identifier-shaped names are placeholders. Anything else containing a
# '$' -- a shell snippet in a comment, a regex -- passes through untouched.
#
# Dots are allowed inside the name because real query files arrive already
# templated by another system, and those names are namespaced:
# ``${arena.presto.var.process_batch_id}``. Refusing to recognise them was
# worse than it sounds -- the name did not match, so it was neither substituted
# nor reported unresolved, and the literal text reached Presto inside quotes as
# a valid string that matches no batch. Both sides then return zero rows and the
# run reports EQUIVALENT: a clean pass proving nothing. Recognising the name
# turns that into either a substitution or a loud error.
_PLACEHOLDER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_.]*)\}")

ENV_PREFIX = "ROWPARITY_VAR_"


class ParamError(RuntimeError):
    pass


def parse_cli_params(items: Optional[Iterable[str]]) -> Dict[str, str]:
    """Turn ``--param NAME=VALUE`` arguments into a dict."""
    out: Dict[str, str] = {}
    for item in items or []:
        if "=" not in item:
            raise ParamError(f"--param expects NAME=VALUE, got {item!r}")
        name, value = item.split("=", 1)
        name = name.strip()
        if not name:
            raise ParamError(f"--param has an empty name: {item!r}")
        out[name] = value
    return out


def _stringify(source: Optional[Mapping[str, Any]]) -> Dict[str, str]:
    # YAML happily yields ints/bools/None; placeholders substitute as text.
    return {str(k).lower(): ("" if v is None else str(v)) for k, v in (source or {}).items()}


def resolve_variables(
    file_vars: Optional[Mapping[str, Any]] = None,
    case_vars: Optional[Mapping[str, Any]] = None,
    cli_params: Optional[Mapping[str, Any]] = None,
    env: Optional[Mapping[str, str]] = None,
) -> Dict[str, str]:
    """Merge the three sources into one lower-cased name -> value mapping."""
    env = os.environ if env is None else env

    merged: Dict[str, str] = {}
    merged.update(_stringify(file_vars))
    merged.update(_stringify(case_vars))
    for key, value in env.items():
        if key.startswith(ENV_PREFIX) and len(key) > len(ENV_PREFIX):
            merged[key[len(ENV_PREFIX) :].lower()] = value
    merged.update(_stringify(cli_params))
    return merged


def merge_side_vars(
    side_vars: Optional[Mapping[str, Any]], variables: Optional[Mapping[str, str]]
) -> Dict[str, str]:
    """Overlay one source spec's own ``vars:`` block on the case variables.

    This is what lets a single SQL file serve both sides of a comparison::

        expected: { type: trino, query_file: q.sql, vars: { facts: old_catalog } }
        actual:   { type: trino, query_file: q.sql, vars: { facts: new_catalog } }

    Before this, "same query, different catalog" meant two near-identical
    copies of a 2,000-line file kept in step by a test. That works for one
    query and does not survive a hundred: the files drift, the run still
    succeeds, and it reports SQL differences as data differences.

    **A side var outranks --param and the environment**, which inverts the
    precedence everywhere else in this module. That is deliberate. A side var
    is not a knob, it is half of what makes the two sides different; letting
    ``--param facts=x`` reach both sides would point them at the same catalog
    and produce a confident EQUIVALENT for comparing a table with itself. A
    case that *wants* a side overridable can say so by templating the value
    (``vars: {facts: "${old_catalog}"}``), which resolves normally and stays
    fully controllable from the CLI.
    """
    merged = dict(variables or {})
    merged.update(_stringify(side_vars))
    return merged


def substitute(text: str, variables: Mapping[str, str], *, where: str = "") -> str:
    """Replace every ``${name}`` in *text*; raise if any cannot be resolved."""
    missing: list = []

    def _replace(match: "re.Match") -> str:
        name = match.group(1)
        key = name.lower()
        if key in variables:
            return variables[key]
        if name not in missing:
            missing.append(name)
        return match.group(0)

    out = _PLACEHOLDER.sub(_replace, text)
    if missing:
        known = sorted(variables) or ["(none)"]
        location = f" in {where}" if where else ""
        raise ParamError(
            f"unresolved parameter(s) {missing}{location}. Define them in the case's "
            f"vars: block, set {ENV_PREFIX}{missing[0].upper()}, or pass "
            f"--param {missing[0]}=<value>. Known: {known}"
        )
    return out


def substitute_spec(value: Any, variables: Mapping[str, str], *, where: str = "") -> Any:
    """Recursively substitute placeholders in every string inside a structure."""
    if isinstance(value, str):
        return substitute(value, variables, where=where)
    if isinstance(value, dict):
        return {k: substitute_spec(v, variables, where=where) for k, v in value.items()}
    if isinstance(value, list):
        return [substitute_spec(v, variables, where=where) for v in value]
    return value


def has_placeholder(value: str) -> bool:
    return bool(_PLACEHOLDER.search(value))
