"""Per-table column exclusion lists loaded from a CSV.

A migration accumulates columns that are deliberately not compared -- storage
metadata (``__path__``, ``__offset__``, ``__file_size__``, ``__footer_size__``),
gaps the team has explicitly accepted. Those live naturally in one shared file
rather than duplicated across every case: the same four metadata columns apply
to six tables, and an inline list per case would be twenty-four lines that drift
apart.

Format (BCV Analyzer's ``exclude.csv``, adopted unchanged so an existing file
works as-is)::

    table,column
    request,__path__
    slot,__path__
    request,__offset__

Each row says "for this table, skip this column". Rows for other tables are
ignored, which is what makes one file serve a whole suite.

Wired into YAML as two keys, valid in both a ``compare:`` block and a
``schema_check:`` block::

    ignore_columns_file: exclude.csv     # relative to the case YAML
    ignore_columns_table: request
    ignore_columns: [extra_one_off]      # optional, unioned with the file

The result is unioned with any inline ``ignore_columns``, so a case can carry
both a shared list and its own additions.

Two deliberate divergences from BCV Analyzer's loader, both in the direction of
failing loudly -- rowparity treats a silently-skipped exclusion as worse than a
stopped run, the same reasoning as an unresolved ``${parameter}``:

* **A missing file raises.** BCV returned an empty set, which turns a typo'd
  path into "nothing was excluded" -- discovered later, as a comparison failure
  on columns you believed were out of scope.
* **A table the file knows nothing about raises**, and the error names the
  tables it does know. Same reasoning: ``ignore_columns_table: requests`` would
  otherwise exclude nothing at all, silently. If a table genuinely has no
  exclusions, omit the two keys for that case rather than pointing at the file.

What does *not* raise: an entry naming a column that no longer exists, or never
existed on that table. BCV's own file lists the same four metadata columns for
all six tables and they are not all present on every one, so treating a
non-matching entry as an error would reject a legitimate shared file. An
exclusion is a statement about intent, not an assertion about the schema.
"""
from __future__ import annotations

import csv
import os
from typing import List, Set

REQUIRED_HEADERS = ("table", "column")


class ExclusionError(RuntimeError):
    pass


def load_exclusions(path: str, table: str, base_dir: str = ".") -> List[str]:
    """Return the column names to skip for *table*, sorted.

    *path* is resolved relative to *base_dir* (the directory of the case YAML),
    matching how ``query_file:`` resolves.
    """
    if not table:
        raise ExclusionError(
            f"ignore_columns_file: {path!r} needs ignore_columns_table to say which "
            f"table's rows to use. The file is keyed by table, so without it every "
            f"row would apply to every case."
        )

    resolved = path if os.path.isabs(path) else os.path.join(base_dir, path)
    if not os.path.isfile(resolved):
        raise ExclusionError(
            f"ignore_columns_file not found: {resolved!r} (from {path!r}, resolved "
            f"relative to {base_dir!r}). Paths are relative to the case YAML, the "
            f"same as query_file."
        )

    # utf-8-sig, not utf-8: a CSV round-tripped through Excel carries a BOM,
    # which makes the first header read as "﻿table" and match nothing --
    # exactly the silent no-op this module exists to prevent.
    with open(resolved, encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        fieldnames = [(name or "").strip().lower() for name in (reader.fieldnames or [])]
        missing = [h for h in REQUIRED_HEADERS if h not in fieldnames]
        if missing:
            raise ExclusionError(
                f"{resolved}: exclusion CSV is missing required header(s) {missing}. "
                f"Expected a header row of 'table,column'; found {fieldnames or 'nothing'}."
            )

        wanted = table.strip().lower()
        columns: Set[str] = set()
        seen_tables: Set[str] = set()
        for row in reader:
            # Headers are matched case-insensitively above, so read by the
            # normalised name rather than whatever casing the file used.
            normalised = {(k or "").strip().lower(): v for k, v in row.items()}
            row_table = (normalised.get("table") or "").strip()
            column = (normalised.get("column") or "").strip()
            if not row_table or not column:
                continue
            seen_tables.add(row_table)
            if row_table.lower() == wanted:
                columns.add(column)

    if not seen_tables:
        raise ExclusionError(
            f"{resolved}: no usable rows. Every row needs both a table and a column."
        )

    if not columns:
        raise ExclusionError(
            f"{resolved}: no exclusions for table {table!r}. The file covers "
            f"{sorted(seen_tables)}. Fix ignore_columns_table if that is a typo; if "
            f"{table!r} genuinely has no exclusions, drop ignore_columns_file and "
            f"ignore_columns_table from this case instead of pointing at the file."
        )

    return sorted(columns)


def merge_ignore_columns(
    inline: List[str] | None,
    file_path: str | None,
    table: str | None,
    base_dir: str = ".",
) -> List[str]:
    """Union an inline ``ignore_columns`` list with a CSV exclusion file.

    Returns the inline list unchanged when no file is configured, so cases that
    do not use exclusion files are unaffected.
    """
    merged = list(inline or [])
    if not file_path:
        if table:
            raise ExclusionError(
                f"ignore_columns_table: {table!r} was set without ignore_columns_file. "
                f"It selects rows from an exclusion CSV and does nothing on its own."
            )
        return merged

    from_file = load_exclusions(file_path, table or "", base_dir=base_dir)
    for column in from_file:
        if column not in merged:
            merged.append(column)
    return merged
