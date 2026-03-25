#!/usr/bin/env python3
"""
build_workbook.py
-----------------
Reads testJSON.json and produces roles_workbook.xlsx with:
  Sheet 1 ("Roles")           — full JSON data as a formatted table
  Sheet 2 ("User Assignments")— data-entry sheet with columns:
                                  email | roleID (dropdown → name) |
                                  roleID_value (VLOOKUP → numeric id) |
                                  agencyid | holdcoid

Usage:
    python build_workbook.py [--json path/to/file.json] [--out path/to/output.xlsx]
"""

import json
import argparse
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.utils import get_column_letter

# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------
HEADER_FONT      = Font(name="Arial", bold=True, color="FFFFFF", size=11)
HEADER_FILL      = PatternFill("solid", start_color="2F5496")   # dark blue
ALT_FILL         = PatternFill("solid", start_color="DCE6F1")   # light blue
DATA_FONT        = Font(name="Arial", size=10)
BOLD_FONT        = Font(name="Arial", bold=True, size=10)
CENTER           = Alignment(horizontal="center", vertical="center")
LEFT             = Alignment(horizontal="left",   vertical="center")

THIN = Side(style="thin", color="B0B0B0")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)


def style_header(cell, text):
    cell.value     = text
    cell.font      = HEADER_FONT
    cell.fill      = HEADER_FILL
    cell.alignment = CENTER
    cell.border    = BORDER


def style_data(cell, value, align=LEFT, alt_row=False):
    cell.value     = value
    cell.font      = DATA_FONT
    cell.fill      = ALT_FILL if alt_row else PatternFill()
    cell.alignment = align
    cell.border    = BORDER


# ---------------------------------------------------------------------------
# Sheet 1 — Roles reference table
# ---------------------------------------------------------------------------
def build_sheet1(wb, data):
    ws = wb.active
    ws.title = "Roles"
    ws.sheet_view.showGridLines = False

    columns = [
        ("id",          8,  CENTER),
        ("name",        42, LEFT),
        ("type",        10, CENTER),
        ("createdDate", 14, CENTER),
    ]

    # Header row
    ws.row_dimensions[1].height = 20
    for col_idx, (header, width, _) in enumerate(columns, start=1):
        style_header(ws.cell(row=1, column=col_idx), header)
        ws.column_dimensions[get_column_letter(col_idx)].width = width

    # Data rows
    for row_idx, record in enumerate(data, start=2):
        alt = (row_idx % 2 == 0)
        ws.row_dimensions[row_idx].height = 16
        values = [record["id"], record["name"], record["type"], record["createdDate"]]
        for col_idx, (val, (_, _, align)) in enumerate(zip(values, columns), start=1):
            style_data(ws.cell(row=row_idx, column=col_idx), val, align=align, alt_row=alt)

    # Freeze header row
    ws.freeze_panes = "A2"

    return ws


# ---------------------------------------------------------------------------
# Sheet 2 — User Assignments (data-entry)
# ---------------------------------------------------------------------------
def build_sheet2(wb, data, roles_sheet_name="Roles"):
    ws = wb.create_sheet("User Assignments")
    ws.sheet_view.showGridLines = False

    n_roles   = len(data)
    max_rows  = 1000   # validation range depth
    name_col  = "B"    # name column in Roles sheet
    id_col    = "A"    # id column in Roles sheet
    name_range = f"'{roles_sheet_name}'!${name_col}$2:${name_col}${n_roles + 1}"

    # Column layout:
    #  A=email | B=roleID (dropdown of names) | C=roleID_value (VLOOKUP→id) |
    #  D=agencyid | E=holdcoid
    columns = [
        ("email",           30),
        ("roleID",          42),   # dropdown — shows name, human-friendly
        ("roleID_value",    14),   # VLOOKUP resolves to numeric id (auto)
        ("agencyid",        14),
        ("holdcoid",        14),
    ]

    ws.row_dimensions[1].height = 20
    for col_idx, (header, width) in enumerate(columns, start=1):
        style_header(ws.cell(row=1, column=col_idx), header)
        ws.column_dimensions[get_column_letter(col_idx)].width = width

    # roleID_value column note in header
    note_cell = ws.cell(row=1, column=3)
    note_cell.value = "roleID_value (auto)"

    # Data validation — dropdown on column B (roleID)
    dv = DataValidation(
        type="list",
        formula1=f"={name_range}",
        allow_blank=True,
        showDropDown=False,   # False = show the dropdown arrow
    )
    dv.error      = "Please select a valid role from the list."
    dv.errorTitle = "Invalid Role"
    dv.prompt     = "Pick a role name from the list."
    dv.promptTitle = "Role"
    dv.sqref      = f"B2:B{max_rows}"
    ws.add_data_validation(dv)

    # VLOOKUP formulas — column C auto-resolves the numeric id from column B
    # =IFERROR(VLOOKUP(B2, Roles!$B$2:$A$N, -1, 0), "")  — note: VLOOKUP needs
    # id left of name, so we use INDEX/MATCH instead.
    for row in range(2, max_rows + 1):
        formula = (
            f'=IFERROR(INDEX(\'{roles_sheet_name}\'!${id_col}$2:${id_col}${n_roles+1},'
            f'MATCH(B{row},\'{roles_sheet_name}\'!${name_col}$2:${name_col}${n_roles+1},0)),"")'
        )
        cell = ws.cell(row=row, column=3, value=formula)
        cell.font      = Font(name="Arial", size=10, color="008000")  # green = cross-sheet formula
        cell.alignment = CENTER
        cell.border    = BORDER

    # Style placeholder rows lightly
    for row in range(2, 51):   # pre-style first 50 rows for UX
        alt = (row % 2 == 0)
        for col in [1, 2, 4, 5]:
            c = ws.cell(row=row, column=col)
            c.font      = DATA_FONT
            c.fill      = ALT_FILL if alt else PatternFill()
            c.alignment = LEFT
            c.border    = BORDER

    # Freeze header
    ws.freeze_panes = "A2"

    return ws


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Build Excel workbook from JSON roles data.")
    parser.add_argument("--json", default="testJSON.json",        help="Input JSON file path")
    parser.add_argument("--out",  default="roles_workbook.xlsx",  help="Output Excel file path")
    args = parser.parse_args()

    json_path = Path(args.json)
    out_path  = Path(args.out)

    if not json_path.exists():
        raise FileNotFoundError(f"JSON file not found: {json_path}")

    with open(json_path, "r") as f:
        data = json.load(f)

    print(f"Loaded {len(data)} roles from {json_path}")

    wb = Workbook()
    build_sheet1(wb, data)
    build_sheet2(wb, data)

    wb.save(out_path)
    print(f"Workbook saved → {out_path}")


if __name__ == "__main__":
    main()
