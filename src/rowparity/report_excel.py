from __future__ import annotations

from typing import List, Optional, Tuple

from .compare import ComparisonResult


def _build_schema_diff_cols(
    result: ComparisonResult,
) -> Optional[List[Tuple[str, str, str, str, str]]]:
    has_schema_signals = bool(
        result.exp_cols
        or result.act_cols
        or result.columns_only_in_expected
        or result.columns_only_in_actual
        or result.type_mismatches
    )
    if not has_schema_signals:
        return None

    only_exp = set(result.columns_only_in_expected) | (set(result.exp_cols) - set(result.act_cols))
    only_act = set(result.columns_only_in_actual) | (set(result.act_cols) - set(result.exp_cols))

    mismatch_map = {c: (e, a) for c, e, a in result.type_mismatches}
    for c in set(result.exp_cols) & set(result.act_cols):
        if c not in mismatch_map and result.exp_cols[c] != result.act_cols[c]:
            mismatch_map[c] = (result.exp_cols[c], result.act_cols[c])

    all_keys = sorted(
        set(result.exp_cols) | set(result.act_cols) | only_exp | only_act | set(mismatch_map)
    )

    cols: List[Tuple[str, str, str, str, str]] = []
    for key_label in all_keys:
        exp_type = result.exp_cols.get(key_label, "")
        act_type = result.act_cols.get(key_label, "")

        if key_label in only_exp and key_label not in only_act:
            cols.append(("Missing", key_label, exp_type, "", ""))
        elif key_label in only_act and key_label not in only_exp:
            cols.append(("Added", "", "", key_label, act_type))
        elif key_label in mismatch_map:
            et, at = mismatch_map[key_label]
            cols.append(("Type mismatch", key_label, et, key_label, at))
        else:
            cols.append(("Matched", key_label, exp_type, key_label, act_type))

    return cols


def write_excel_report(results: List[Tuple[str, ComparisonResult]], xlsx_path: str) -> None:
    try:
        from openpyxl import Workbook  # lazy — optional dependency
        from openpyxl.styles import Font, PatternFill
    except ImportError as exc:
        raise ImportError(
            "openpyxl is required for Excel report output. "
            "Install it with:  pip install openpyxl"
        ) from exc

    STATUS_COLORS = {
        "Missing": "FFFFC7CE",  # light red
        "Added": "FFC6EFCE",  # light green
        "Type mismatch": "FFFFEB9C",  # light yellow
        "Matched": "FFFFFFFF",  # white
    }

    workbook = Workbook()

    # summary sheet
    summary = workbook.active
    summary.title = "summary"
    summary.append(
        [
            "Case",
            "Equivalent",
            "Expected_columns",
            "Actual_columns",
            "Missing (Only in Expected)",
            "Added (Only in Actual)",
        ]
    )
    for case_name, result in results:
        summary.append(
            [
                case_name,
                result.equivalent,
                result.expected_rows,
                result.actual_rows,
                result.missing_count,
                result.added_count,
            ]
        )

    schema_cols_by_case = [(name, _build_schema_diff_cols(result)) for name, result in results]
    has_schema_data = any(cols for _, cols in schema_cols_by_case)

    if has_schema_data:
        for case_name, diff_cols in schema_cols_by_case:
            schema_sheet = workbook.create_sheet(case_name)
            headers = ["STATUS", "EXPECTED", "EXPECTED_TYPE", "ACTUAL", "ACTUAL_TYPE"]
            schema_sheet.append(headers)

            # Bold header row
            for cell in schema_sheet[1]:
                cell.font = Font(bold=True)

            for status, exp_col, exp_type, act_col, act_type in diff_cols:
                row_data = [status, exp_col, exp_type, act_col, act_type]
                schema_sheet.append(row_data)

                # Colour the STATUS cell
                status_col_idx = 1
                cell = schema_sheet.cell(row=schema_sheet.max_row, column=status_col_idx)
                hex_color = STATUS_COLORS.get(status, "FFFFFFFF")
                cell.fill = PatternFill(
                    start_color=hex_color, end_color=hex_color, fill_type="solid"
                )

    workbook.save(xlsx_path)
