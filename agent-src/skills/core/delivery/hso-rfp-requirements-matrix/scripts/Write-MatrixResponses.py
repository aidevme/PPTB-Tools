#!/usr/bin/env python
"""
Write-MatrixResponses.py — fill vendor-response cells into a client matrix in place.

Takes the ORIGINAL workbook plus a responses file, and writes the drafted values
into the mapped response/product/cost/comment columns — preserving the client's
formatting, formulas, and layout. Never touches the requirement, number, or
priority cells. Output is a new *_DRAFT.xlsx (the original is never overwritten).

Responses JSON shape:
{
  "<sheet name>": [
    {"row": 6, "cells": {"12": "Y", "16": "Configurator", "17": "Standard CPQ covers this."}},
    ...
  ]
}
  - "row" is 1-based (as emitted by Read-MatrixWorkbook.py).
  - "cells" maps a 0-based COLUMN INDEX (as a string) -> value to write.
    Use the column indices from the confirmed profile (columns / response_columns).

Usage:
    python Write-MatrixResponses.py "<original.xlsx>" responses.json [--out "<path>"] [--suffix _DRAFT]

Exit codes: 0 ok; 2 bad input; 3 nothing written (all targets out of range / empty).
"""
import sys, os, json, argparse

try:
    import openpyxl
    from openpyxl.utils import get_column_letter
except ImportError:
    sys.stderr.write("openpyxl not installed. Run: python -m pip install -r requirements.txt\n")
    sys.exit(2)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("workbook")
    ap.add_argument("responses")
    ap.add_argument("--out", dest="out")
    ap.add_argument("--suffix", default="_DRAFT")
    ap.add_argument("--overwrite-nonblank", action="store_true",
                    help="Allow writing over cells that already contain a value (default: skip & warn).")
    args = ap.parse_args()

    if not os.path.isfile(args.workbook):
        sys.stderr.write(f"Workbook not found: {args.workbook}\n"); sys.exit(2)
    if not os.path.isfile(args.responses):
        sys.stderr.write(f"Responses file not found: {args.responses}\n"); sys.exit(2)

    with open(args.responses, "r", encoding="utf-8") as fh:
        responses = json.load(fh)

    # Keep formatting/formulas: do NOT use read_only or data_only here.
    wb = openpyxl.load_workbook(args.workbook)
    written, skipped, missing_sheets = 0, 0, []

    for sheet_name, entries in responses.items():
        if sheet_name not in wb.sheetnames:
            missing_sheets.append(sheet_name)
            continue
        ws = wb[sheet_name]
        for entry in entries:
            row = int(entry["row"])
            for col_str, value in entry.get("cells", {}).items():
                col = int(col_str) + 1  # 0-based profile index -> 1-based openpyxl
                cell = ws.cell(row=row, column=col)
                existing = cell.value
                if existing not in (None, "") and not args.overwrite_nonblank:
                    sys.stderr.write(
                        f"  ! skip {sheet_name}!{get_column_letter(col)}{row} "
                        f"(already has '{existing}', use --overwrite-nonblank to replace)\n")
                    skipped += 1
                    continue
                cell.value = value
                written += 1

    if missing_sheets:
        sys.stderr.write(f"  ! sheets not found in workbook (skipped): {missing_sheets}\n")
    if written == 0:
        sys.stderr.write("Nothing written — check row/column indices against the profile.\n")
        sys.exit(3)

    if args.out:
        out_path = args.out
    else:
        base, ext = os.path.splitext(args.workbook)
        out_path = f"{base}{args.suffix}{ext}"
    wb.save(out_path)
    print(f"Wrote {written} cells ({skipped} skipped). Draft saved: {out_path}")
    print("REMINDER: draft only — a consultant must review every verdict, product, "
          "and comment before this goes to the client.")

if __name__ == "__main__":
    main()
