"""
Excel Analyzer - Extracts comprehensive structural information from Excel files.
Outputs structured JSON that can be used to generate documentation for Dataverse specs.

Usage:
    python analyze_excel.py <excel_file> [--output <output_file>] [--format json|markdown]

Supports: .xlsx, .xltx, .xlsm, .xltm (the OOXML formats openpyxl can read).

NOT supported, by design of the underlying library: .xls (legacy BIFF), .xlsb (binary),
.csv, .ods. These are rejected up front with a message naming the alternative rather than
being allowed to fail as a traceback deep inside openpyxl.
"""
import argparse
import json
import sys
import os
import re
import zipfile
from pathlib import Path
from collections import defaultdict

try:
    from openpyxl import load_workbook
    from openpyxl.utils import get_column_letter
except ImportError:
    print("ERROR: openpyxl is required. Install with: pip install openpyxl", file=sys.stderr)
    sys.exit(1)

# Formats openpyxl can actually open.
SUPPORTED_EXTENSIONS = {".xlsx", ".xltx", ".xlsm", ".xltm"}

# Formats we know we cannot handle, mapped to the advice that actually unblocks the caller.
# Read-ExcelContent.ps1 (hso-wiki-ingest-discovery-artifact) drives Excel via COM and opens
# anything Excel opens -- but it yields cell VALUES only, not structure.
UNSUPPORTED_EXTENSIONS = {
    ".xls": "Legacy BIFF format. openpyxl cannot read it at all. Re-save as .xlsx, or use "
            "hso-wiki-ingest-discovery-artifact's Read-ExcelContent.ps1 (Excel COM) if you only need cell values.",
    ".xlsb": "Binary workbook format. openpyxl cannot read it. Re-save as .xlsx.",
    ".csv": "Not a workbook -- no sheets, formulas, or validations to extract. Read it directly.",
    ".ods": "OpenDocument format. openpyxl cannot read it. Re-save as .xlsx.",
}

# Scan caps. Defaults preserve the original behaviour; all three are overridable from the CLI
# so a large workbook can be analyzed in full rather than silently truncated.
DEFAULT_MAX_ROWS = 1000
DEFAULT_MAX_COLS = 200
DEFAULT_MAX_FORMULAS = 500


class WorkbookLoadError(Exception):
    """The workbook could not be opened. Carries a caller-facing explanation, not a traceback."""


def has_vba_project(filepath):
    """True only when the file really contains a VBA project.

    Do NOT use openpyxl's `wb.vba_archive` for this. When a workbook is loaded with
    keep_vba=True -- which this script always does -- openpyxl populates vba_archive with a
    ZipFile for EVERY workbook, macro-bearing or not, so truth-testing it reports macros on
    100% of files. The only reliable marker is the xl/vbaProject.bin part inside the package.
    """
    try:
        with zipfile.ZipFile(filepath) as zf:
            return any(n.lower() == "xl/vbaproject.bin" for n in zf.namelist())
    except Exception:
        return False


def _explain_load_failure(filepath, exc):
    """Translate an openpyxl load failure into advice the caller can act on."""
    ext = Path(filepath).suffix.lower()
    detail = str(exc).strip() or exc.__class__.__name__

    if "encrypted" in detail.lower() or "password" in detail.lower():
        return (f"'{os.path.basename(filepath)}' appears to be password-protected or encrypted. "
                f"openpyxl cannot open it. Remove the protection in Excel and re-save, then retry.\n"
                f"  Underlying error: {detail}")

    if ext in SUPPORTED_EXTENSIONS:
        return (f"'{os.path.basename(filepath)}' has a supported extension ({ext}) but could not be opened. "
                f"It may be corrupt, truncated, or actually a different format saved under the wrong "
                f"extension (a .xls renamed to .xlsx is the usual cause -- open it in Excel and 'Save As' "
                f"a real .xlsx).\n"
                f"  Underlying error: {detail}")

    return (f"'{os.path.basename(filepath)}' could not be opened.\n"
            f"  Underlying error: {detail}")


def validate_input_format(filepath):
    """Reject formats we know openpyxl cannot read, with actionable advice.

    Returns a warning string for unrecognised-but-attempted extensions, or None.
    Raises WorkbookLoadError for extensions known to be unreadable -- failing here beats
    failing several hundred lines into a traceback with no advice attached.
    """
    ext = Path(filepath).suffix.lower()

    if ext in UNSUPPORTED_EXTENSIONS:
        raise WorkbookLoadError(
            f"Unsupported format '{ext}': {UNSUPPORTED_EXTENSIONS[ext]}\n"
            f"  Supported: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )

    if ext not in SUPPORTED_EXTENSIONS:
        return (f"[WARN] '{ext or '(no extension)'}' is not a recognised Excel extension "
                f"({', '.join(sorted(SUPPORTED_EXTENSIONS))}). Attempting to open it anyway.")

    return None


def analyze_workbook(filepath, max_rows=DEFAULT_MAX_ROWS, max_cols=DEFAULT_MAX_COLS,
                     max_formulas=DEFAULT_MAX_FORMULAS):
    """Main analysis function. Returns a comprehensive dict of workbook structure."""
    result = {
        "file": os.path.basename(filepath),
        "file_type": Path(filepath).suffix,
        "file_size_kb": round(os.path.getsize(filepath) / 1024, 1),
        "scan_limits": {"max_rows": max_rows, "max_columns": max_cols, "max_formulas_per_sheet": max_formulas},
        "truncated": False,          # set True if ANY sheet hit a cap -- see per-sheet detail
        "sheets": [],
        "named_ranges": [],
        "excel_tables": [],
        "formulas": {"total_count": 0, "by_sheet": {}},
        "data_validations": [],
        "conditional_formatting": [],
        "merged_cells": [],
        "comments": [],
        "cross_sheet_references": [],
        "pivot_tables": [],
        "charts": [],
        "external_links": [],
        "formatting_patterns": {},
        "vba_macros": None,
    }

    # Load twice: once for formulas, once for cached values. Roughly doubles peak memory,
    # which is the documented trade-off for being able to report formula AND result.
    # Failures here are the common real-world ones (encrypted, corrupt, mislabelled
    # extension), so translate them instead of surfacing an openpyxl traceback.
    try:
        wb = load_workbook(filepath, data_only=False, keep_vba=True)
        wb_data = load_workbook(filepath, data_only=True)
    except Exception as exc:
        raise WorkbookLoadError(_explain_load_failure(filepath, exc)) from exc

    result["sheet_count"] = len(wb.sheetnames)

    # Named ranges / defined names (compatible with openpyxl 3.1+)
    defined_names = wb.defined_names
    for name_key in defined_names:
        dn = defined_names[name_key]
        destinations = []
        is_broken = False
        broken_reason = None
        try:
            for sheet_title, cell_range in dn.destinations:
                destinations.append({"sheet": sheet_title, "range": cell_range})
        except Exception:
            is_broken = True
            broken_reason = "destination could not be parsed"
        attr_text = getattr(dn, 'attr_text', None) or getattr(dn, 'value', str(dn))

        # A name is also broken when it survives parsing but points nowhere real. openpyxl happily
        # yields ('NoSuchSheet', '$A$1') for a name whose sheet was deleted, so parsing alone
        # under-reports: check the reference text for #REF! and confirm each sheet still exists.
        if not is_broken and attr_text and "#REF!" in str(attr_text):
            is_broken = True
            broken_reason = "reference contains #REF!"
        if not is_broken:
            missing = [d["sheet"] for d in destinations if d["sheet"] and d["sheet"] not in wb.sheetnames]
            if missing:
                is_broken = True
                broken_reason = f"references missing sheet(s): {', '.join(sorted(set(missing)))}"
        local_id = getattr(dn, 'localSheetId', None)
        result["named_ranges"].append({
            "name": dn.name if hasattr(dn, 'name') else name_key,
            "value": attr_text,
            "destinations": destinations,
            "is_broken": is_broken,
            "broken_reason": broken_reason,
            "scope": "Workbook" if local_id is None else f"Sheet[{local_id}]",
        })

    # Analyze each sheet
    for sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
        ws_data = wb_data[sheet_name]
        sheet_info = analyze_sheet(ws, ws_data, sheet_name, max_rows, max_cols, max_formulas)
        result["sheets"].append(sheet_info)
        if sheet_info["truncation"]["truncated"]:
            result["truncated"] = True

        # Pivot tables and charts are structural design signals (a pivot is an aggregation the
        # replacement app must reproduce; a chart names the measures that matter). Both live on
        # private openpyxl attributes, so every access is defensive.
        for pivot in getattr(ws, "_pivots", None) or []:
            try:
                cache = getattr(pivot, "cache", None)
                result["pivot_tables"].append({
                    "sheet": sheet_name,
                    "name": getattr(pivot, "name", None),
                    "location": str(getattr(pivot, "location", "") or ""),
                    "cache_fields": [getattr(f, "name", None) for f in (getattr(cache, "cacheFields", None) or [])],
                    "source": str(getattr(getattr(cache, "cacheSource", None), "worksheetSource", "") or ""),
                })
            except Exception as exc:
                result["pivot_tables"].append({"sheet": sheet_name, "name": "(unreadable)", "error": str(exc)})

        for chart in getattr(ws, "_charts", None) or []:
            try:
                title = None
                if getattr(chart, "title", None) is not None:
                    title = _extract_chart_title(chart.title)
                result["charts"].append({
                    "sheet": sheet_name,
                    "type": chart.__class__.__name__,
                    "title": title,
                    "anchor": str(getattr(chart, "anchor", "") or ""),
                })
            except Exception as exc:
                result["charts"].append({"sheet": sheet_name, "type": "(unreadable)", "error": str(exc)})

        # Accumulate formula counts
        if sheet_info["formulas"]:
            result["formulas"]["by_sheet"][sheet_name] = len(sheet_info["formulas"])
            result["formulas"]["total_count"] += len(sheet_info["formulas"])

        # Accumulate cross-sheet references
        for f in sheet_info["formulas"]:
            refs = extract_cross_sheet_refs(f["formula"], sheet_name)
            if refs:
                result["cross_sheet_references"].extend(refs)

        # Accumulate data validations
        if sheet_info["data_validations"]:
            for dv in sheet_info["data_validations"]:
                dv["sheet"] = sheet_name
                result["data_validations"].append(dv)

        # Accumulate conditional formatting
        if sheet_info["conditional_formatting"]:
            for cf in sheet_info["conditional_formatting"]:
                cf["sheet"] = sheet_name
                result["conditional_formatting"].append(cf)

        # Accumulate merged cells
        if sheet_info["merged_cells"]:
            for mc in sheet_info["merged_cells"]:
                result["merged_cells"].append({"sheet": sheet_name, "range": mc})

        # Accumulate comments
        if sheet_info["comments"]:
            for c in sheet_info["comments"]:
                c["sheet"] = sheet_name
                result["comments"].append(c)

    # Excel tables (openpyxl 3.1+: .values() returns Table objects, .items() returns (name, range_str))
    for sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
        if hasattr(ws, 'tables') and ws.tables:
            for table in ws.tables.values():
                if isinstance(table, str):
                    continue  # Skip if API returned string
                try:
                    result["excel_tables"].append({
                        "name": table.name,
                        "sheet": sheet_name,
                        "range": table.ref,
                        "display_name": table.displayName,
                        "header_row": table.headerRowCount,
                        "total_row": table.totalsRowCount,
                        "columns": [col.name for col in table.tableColumns] if table.tableColumns else [],
                    })
                except Exception:
                    result["excel_tables"].append({
                        "name": str(table),
                        "sheet": sheet_name,
                        "range": "unknown",
                        "display_name": str(table),
                        "columns": [],
                    })

    # External workbook links. A formula pointing at another file is a hard dependency the
    # replacement design has to resolve -- usually it means a second source system exists.
    for link in getattr(wb, "_external_links", None) or []:
        try:
            target = getattr(getattr(link, "file_link", None), "Target", None)
            result["external_links"].append({
                "target": target or str(link),
                "target_mode": getattr(getattr(link, "file_link", None), "TargetMode", None),
            })
        except Exception as exc:
            result["external_links"].append({"target": "(unreadable)", "error": str(exc)})

    # VBA macros -- gated on the real package marker, not wb.vba_archive (see has_vba_project).
    if has_vba_project(filepath):
        result["vba_macros"] = extract_vba_info(filepath)

    wb.close()
    wb_data.close()
    return result


def _extract_chart_title(title):
    """Pull plain text out of an openpyxl chart title object, which is deeply nested."""
    try:
        if isinstance(title, str):
            return title
        rich = getattr(getattr(title, "tx", None), "rich", None)
        if rich is None:
            return None
        parts = []
        for para in getattr(rich, "p", None) or []:
            for run in getattr(para, "r", None) or []:
                text = getattr(run, "t", None)
                if text:
                    parts.append(text)
        return " ".join(parts) or None
    except Exception:
        return None


def analyze_sheet(ws, ws_data, sheet_name, max_rows=DEFAULT_MAX_ROWS, max_cols=DEFAULT_MAX_COLS,
                  max_formulas=DEFAULT_MAX_FORMULAS):
    """Analyze a single worksheet."""
    info = {
        "name": sheet_name,
        "state": ws.sheet_state,
        "dimensions": ws.dimensions,
        "max_row": ws.max_row,
        "max_column": ws.max_column,
        # Populated by the cell scan below. Never let a cap pass silently: a truncated sheet
        # that reads as complete is worse than no analysis, because it looks authoritative.
        "truncation": {
            "truncated": False,
            "rows_scanned": 0, "rows_total": ws.max_row or 0,
            "cols_scanned": 0, "cols_total": ws.max_column or 0,
            "formulas_captured": 0, "formula_cap_hit": False,
        },
        "formulas": [],
        "data_validations": [],
        "conditional_formatting": [],
        "merged_cells": [],
        "comments": [],
        "data_sample": {},
        "headers": [],
        "input_cells": [],
        "column_widths": {},
        "protected": ws.protection.sheet if ws.protection else False,
    }

    # Merged cells
    for mc in ws.merged_cells.ranges:
        info["merged_cells"].append(str(mc))

    # Data validations
    if ws.data_validations and ws.data_validations.dataValidation:
        for dv in ws.data_validations.dataValidation:
            cells = str(dv.sqref) if dv.sqref else ""
            info["data_validations"].append({
                "cells": cells,
                "type": dv.type,
                "formula1": str(dv.formula1) if dv.formula1 else None,
                "formula2": str(dv.formula2) if dv.formula2 else None,
                "allow_blank": dv.allow_blank,
                "prompt": dv.promptTitle,
                "error": dv.errorTitle,
            })

    # Conditional formatting
    for cf_rule in ws.conditional_formatting:
        ranges_str = str(cf_rule)
        for rule in cf_rule.rules:
            info["conditional_formatting"].append({
                "range": ranges_str,
                "type": rule.type,
                "operator": getattr(rule, 'operator', None),
                "formula": [str(f) for f in rule.formula] if rule.formula else None,
                "priority": rule.priority,
            })

    # Scan cells for formulas, data, comments, and formatting.
    #
    # The formula cap bounds FORMULA COLLECTION ONLY. It used to `break` the whole scan, which
    # also stopped comment and input-cell collection -- so a formula-heavy sheet silently lost
    # its input-cell inventory, i.e. the form surface, which is one of the main design signals
    # this skill exists to surface. Those three collections are independent; keep them that way.
    formula_count = 0
    formula_cap_hit = False
    max_scan_rows = min(ws.max_row or 0, max_rows)
    max_scan_cols = min(ws.max_column or 0, max_cols)

    info["truncation"]["rows_scanned"] = max_scan_rows
    info["truncation"]["cols_scanned"] = max_scan_cols

    for row in ws.iter_rows(min_row=1, max_row=max_scan_rows, max_col=max_scan_cols):
        for cell in row:
            if cell.value is None:
                continue

            cell_ref = f"{get_column_letter(cell.column)}{cell.row}"

            # Formulas
            if isinstance(cell.value, str) and cell.value.startswith('='):
                if formula_count < max_formulas:
                    # Get cached value from data_only workbook
                    try:
                        cached_val = ws_data[cell_ref].value
                    except Exception:
                        cached_val = None
                    info["formulas"].append({
                        "cell": cell_ref,
                        "formula": cell.value,
                        "cached_value": str(cached_val) if cached_val is not None else None,
                    })
                else:
                    formula_cap_hit = True
                formula_count += 1

            # Comments
            if cell.comment:
                info["comments"].append({
                    "cell": cell_ref,
                    "text": cell.comment.text,
                    "author": cell.comment.author,
                })

            # Identify input cells (unlocked cells with fill)
            if cell.protection and not cell.protection.locked:
                info["input_cells"].append({
                    "cell": cell_ref,
                    "value": str(cell.value) if cell.value else None,
                    "number_format": cell.number_format,
                })

    info["truncation"]["formulas_captured"] = len(info["formulas"])
    info["truncation"]["formula_cap_hit"] = formula_cap_hit
    info["truncation"]["formulas_total_seen"] = formula_count
    info["truncation"]["truncated"] = bool(
        formula_cap_hit
        or max_scan_rows < (ws.max_row or 0)
        or max_scan_cols < (ws.max_column or 0)
    )

    # Extract headers (first few rows with values)
    headers = []
    for row in ws.iter_rows(min_row=1, max_row=min(5, ws.max_row or 1), max_col=max_scan_cols):
        row_data = []
        for cell in row:
            if cell.value is not None:
                row_data.append({"cell": f"{get_column_letter(cell.column)}{cell.row}", "value": str(cell.value)})
        if row_data:
            headers.append(row_data)
    info["headers"] = headers

    # Data sample (first 20 data rows after headers)
    data_rows = []
    start_row = min(6, (ws.max_row or 1))
    for row in ws.iter_rows(min_row=start_row, max_row=min(start_row + 20, ws.max_row or start_row), max_col=max_scan_cols):
        row_data = {}
        for cell in row:
            if cell.value is not None:
                col_letter = get_column_letter(cell.column)
                val = cell.value
                if isinstance(val, str) and val.startswith('='):
                    # Show formula + cached value
                    try:
                        cached = ws_data[f"{col_letter}{cell.row}"].value
                        row_data[col_letter] = f"[FORMULA] {val} => {cached}"
                    except Exception:
                        row_data[col_letter] = f"[FORMULA] {val}"
                else:
                    row_data[col_letter] = str(val)
        if row_data:
            data_rows.append({"row": row[0].row, "data": row_data})
    info["data_sample"] = data_rows

    # Column widths
    for col_dim in ws.column_dimensions.values():
        if col_dim.width and col_dim.width != 8.0:  # Skip default width
            info["column_widths"][col_dim.index] = col_dim.width

    return info


def extract_cross_sheet_refs(formula, source_sheet):
    """Extract cross-sheet references from a formula."""
    refs = []
    # Match patterns like 'Sheet Name'!A1 or SheetName!A1:B2
    pattern = r"'([^']+)'!([A-Z]+\d+(?::[A-Z]+\d+)?)|([A-Za-z_]\w+)!([A-Z]+\d+(?::[A-Z]+\d+)?)"
    for match in re.finditer(pattern, formula):
        target_sheet = match.group(1) or match.group(3)
        cell_range = match.group(2) or match.group(4)
        if target_sheet and target_sheet != source_sheet:
            refs.append({
                "from_sheet": source_sheet,
                "to_sheet": target_sheet,
                "cell_range": cell_range,
                "formula": formula,
            })
    return refs


def extract_vba_info(filepath):
    """Extract VBA macro information."""
    vba_info = {"has_macros": False, "modules": []}
    try:
        import oletools.olevba as olevba
        vba_parser = olevba.VBA_Parser(filepath)
        if vba_parser.detect_vba_macros():
            vba_info["has_macros"] = True
            for (filename, stream_path, vba_filename, vba_code) in vba_parser.extract_macros():
                # Skip empty/attribute-only modules
                code_lines = [l for l in vba_code.split('\n') if l.strip() and not l.strip().startswith('Attribute')]
                if code_lines:
                    vba_info["modules"].append({
                        "filename": vba_filename,
                        "stream": stream_path,
                        "code": vba_code,
                        "line_count": len(code_lines),
                    })
        vba_parser.close()
    except ImportError:
        # oletools not available -- we can still say a VBA project exists, just not read its code.
        if has_vba_project(filepath):
            vba_info["has_macros"] = True
            vba_info["modules"].append({
                "filename": "(oletools not installed - cannot extract code)",
                "note": "Install oletools for VBA extraction: pip install oletools",
            })
    except Exception as e:
        vba_info["error"] = str(e)
    return vba_info


def generate_markdown(analysis):
    """Convert analysis dict to structured markdown."""
    lines = []
    a = analysis

    lines.append(f"# {a['file']} - Excel Analysis Report")
    lines.append("")
    lines.append(f"**File:** {a['file']}")
    lines.append(f"**Type:** {a['file_type']}")
    lines.append(f"**Size:** {a['file_size_kb']} KB")
    lines.append(f"**Sheets:** {a['sheet_count']} ({sum(1 for s in a['sheets'] if s['state'] == 'visible')} visible, {sum(1 for s in a['sheets'] if s['state'] != 'visible')} hidden)")
    lines.append(f"**Total Formulas:** {a['formulas']['total_count']}")
    lines.append(f"**Excel Tables:** {len(a['excel_tables'])}")
    lines.append(f"**Named Ranges:** {len(a['named_ranges'])} ({sum(1 for nr in a['named_ranges'] if nr['is_broken'])} broken)")
    if a['vba_macros'] and a['vba_macros'].get('has_macros'):
        lines.append(f"**VBA Macros:** Yes ({len(a['vba_macros']['modules'])} modules)")
    else:
        lines.append("**VBA Macros:** None")
    lines.append(f"**Pivot Tables:** {len(a.get('pivot_tables', []))}")
    lines.append(f"**Charts:** {len(a.get('charts', []))}")
    lines.append(f"**External Links:** {len(a.get('external_links', []))}")
    lines.append("")

    # Truncation banner. This has to be impossible to miss -- a partially-scanned workbook that
    # reads as complete would send the design conversation off incomplete evidence.
    if a.get('truncated'):
        limits = a.get('scan_limits', {})
        lines.append("> ## INCOMPLETE ANALYSIS")
        lines.append(">")
        lines.append("> One or more sheets exceeded a scan cap, so this report does **not** describe the whole workbook.")
        lines.append(f"> Caps in effect: {limits.get('max_rows')} rows, {limits.get('max_columns')} columns, "
                     f"{limits.get('max_formulas_per_sheet')} formulas per sheet.")
        lines.append(">")
        lines.append("> | Sheet | Rows scanned | Columns scanned | Formulas captured |")
        lines.append("> |---|---|---|---|")
        for s in a['sheets']:
            t = s.get('truncation', {})
            if not t.get('truncated'):
                continue
            rows = f"{t.get('rows_scanned')} of {t.get('rows_total')}"
            cols = f"{t.get('cols_scanned')} of {t.get('cols_total')}"
            forms = f"{t.get('formulas_captured')} of {t.get('formulas_total_seen')}"
            lines.append(f"> | {s['name']} | {rows} | {cols} | {forms} |")
        lines.append(">")
        lines.append("> Re-run with `--max-rows` / `--max-cols` / `--max-formulas` raised to capture the rest.")
        lines.append("")

    lines.append("---")
    lines.append("")

    # Sheet Overview
    lines.append("## Sheet Overview")
    lines.append("")
    lines.append("| # | Sheet | State | Dimensions | Formulas | Scan | Purpose |")
    lines.append("|---|-------|-------|-----------|----------|------|---------|")
    for i, s in enumerate(a['sheets'], 1):
        fc = a['formulas']['by_sheet'].get(s['name'], 0)
        purpose = _infer_sheet_purpose(s)
        scan = "PARTIAL" if s.get('truncation', {}).get('truncated') else "complete"
        lines.append(f"| {i} | {s['name']} | {s['state']} | {s['dimensions']} | {fc} | {scan} | {purpose} |")
    lines.append("")

    # Formulas by Sheet
    lines.append("## Formulas")
    lines.append("")
    for sheet in a['sheets']:
        if not sheet['formulas']:
            continue
        lines.append(f"### {sheet['name']} ({len(sheet['formulas'])} formulas)")
        lines.append("")
        # Show up to 50 formulas per sheet
        shown = sheet['formulas'][:50]
        lines.append("| Cell | Formula | Cached Value |")
        lines.append("|------|---------|-------------|")
        for f in shown:
            formula_escaped = f['formula'].replace('|', '\\|')
            cached = f['cached_value'] or ''
            lines.append(f"| {f['cell']} | `{formula_escaped}` | {cached} |")
        if len(sheet['formulas']) > 50:
            lines.append(f"| ... | *{len(sheet['formulas']) - 50} more formulas* | |")
        lines.append("")

    # Excel Tables
    if a['excel_tables']:
        lines.append("## Excel Tables")
        lines.append("")
        lines.append("| Table | Sheet | Range | Columns |")
        lines.append("|-------|-------|-------|---------|")
        for t in a['excel_tables']:
            cols = ", ".join(t['columns'][:10])
            if len(t['columns']) > 10:
                cols += f" ... (+{len(t['columns']) - 10} more)"
            lines.append(f"| {t['name']} | {t['sheet']} | {t['range']} | {cols} |")
        lines.append("")

    # Named Ranges
    if a['named_ranges']:
        lines.append("## Named Ranges")
        lines.append("")
        valid = [nr for nr in a['named_ranges'] if not nr['is_broken']]
        broken = [nr for nr in a['named_ranges'] if nr['is_broken']]
        if valid:
            lines.append("### Valid Named Ranges")
            lines.append("")
            lines.append("| Name | Value | Scope |")
            lines.append("|------|-------|-------|")
            for nr in valid:
                lines.append(f"| {nr['name']} | `{nr['value']}` | {nr['scope']} |")
            lines.append("")
        if broken:
            lines.append(f"### Broken Named Ranges ({len(broken)} total)")
            lines.append("")
            # Show first 20, summarize rest
            for nr in broken[:20]:
                lines.append(f"- `{nr['name']}` → `{nr['value']}`")
            if len(broken) > 20:
                lines.append(f"- *... and {len(broken) - 20} more broken references*")
            lines.append("")

    # Data Validations
    if a['data_validations']:
        lines.append("## Data Validations")
        lines.append("")
        lines.append("| Sheet | Cells | Type | Source/Formula |")
        lines.append("|-------|-------|------|----------------|")
        for dv in a['data_validations']:
            source = dv['formula1'] or ''
            source_escaped = source.replace('|', '\\|')
            lines.append(f"| {dv['sheet']} | {dv['cells']} | {dv['type']} | `{source_escaped}` |")
        lines.append("")

    # Conditional Formatting
    if a['conditional_formatting']:
        lines.append("## Conditional Formatting")
        lines.append("")
        lines.append("| Sheet | Range | Type | Condition |")
        lines.append("|-------|-------|------|-----------|")
        for cf in a['conditional_formatting']:
            cond = ""
            if cf['formula']:
                cond = ", ".join(cf['formula'])
            elif cf['operator']:
                cond = cf['operator']
            lines.append(f"| {cf['sheet']} | {cf['range']} | {cf['type']} | `{cond}` |")
        lines.append("")

    # Cross-Sheet References
    if a['cross_sheet_references']:
        lines.append("## Cross-Sheet References")
        lines.append("")
        # Deduplicate by from→to sheet pairs
        pairs = defaultdict(list)
        for ref in a['cross_sheet_references']:
            key = f"{ref['from_sheet']} → {ref['to_sheet']}"
            pairs[key].append(ref['cell_range'])
        lines.append("| From | To | Referenced Ranges |")
        lines.append("|------|----|-------------------|")
        for pair, ranges in pairs.items():
            unique_ranges = list(set(ranges))[:10]
            ranges_str = ", ".join(unique_ranges)
            if len(set(ranges)) > 10:
                ranges_str += f" (+{len(set(ranges)) - 10} more)"
            from_s, to_s = pair.split(" → ")
            lines.append(f"| {from_s} | {to_s} | {ranges_str} |")
        lines.append("")

    # Pivot Tables -- each one is an aggregation the replacement app has to reproduce.
    if a.get('pivot_tables'):
        lines.append("## Pivot Tables")
        lines.append("")
        lines.append("| Sheet | Name | Location | Source | Cache Fields |")
        lines.append("|-------|------|----------|--------|--------------|")
        for p in a['pivot_tables']:
            fields = [f for f in (p.get('cache_fields') or []) if f]
            fields_str = ", ".join(fields[:12]) + (f" (+{len(fields) - 12} more)" if len(fields) > 12 else "")
            lines.append(f"| {p.get('sheet','')} | {p.get('name') or '(unnamed)'} | {p.get('location','')} | "
                         f"{p.get('source','')} | {fields_str} |")
        lines.append("")

    # Charts -- the titles and types name the measures the business actually watches.
    if a.get('charts'):
        lines.append("## Charts")
        lines.append("")
        lines.append("| Sheet | Type | Title |")
        lines.append("|-------|------|-------|")
        for c in a['charts']:
            lines.append(f"| {c.get('sheet','')} | {c.get('type','')} | {c.get('title') or '(untitled)'} |")
        lines.append("")

    # External Links -- a hard dependency on another file, usually a second source system.
    if a.get('external_links'):
        lines.append("## External Workbook Links")
        lines.append("")
        lines.append("Formulas in this workbook depend on other files. Each is a data source the "
                     "replacement design must account for.")
        lines.append("")
        for link in a['external_links']:
            lines.append(f"- `{link.get('target','')}`")
        lines.append("")

    # Comments
    if a['comments']:
        lines.append("## Cell Comments")
        lines.append("")
        for c in a['comments']:
            text = c['text'].replace('\n', ' ').strip()[:200]
            lines.append(f"- **{c['sheet']}!{c['cell']}** ({c['author']}): {text}")
        lines.append("")

    # Merged Cells
    if a['merged_cells']:
        lines.append("## Merged Cells")
        lines.append("")
        by_sheet = defaultdict(list)
        for mc in a['merged_cells']:
            by_sheet[mc['sheet']].append(mc['range'])
        for sheet, ranges in by_sheet.items():
            lines.append(f"- **{sheet}**: {', '.join(ranges[:20])}")
            if len(ranges) > 20:
                lines.append(f"  - *... and {len(ranges) - 20} more*")
        lines.append("")

    # Input Cells (unlocked)
    input_sheets = [(s['name'], s['input_cells']) for s in a['sheets'] if s['input_cells']]
    if input_sheets:
        lines.append("## Input Cells (Unlocked)")
        lines.append("")
        for sheet_name, cells in input_sheets:
            lines.append(f"### {sheet_name}")
            lines.append("")
            lines.append("| Cell | Current Value | Number Format |")
            lines.append("|------|--------------|---------------|")
            for c in cells[:50]:
                lines.append(f"| {c['cell']} | {c['value'] or ''} | {c['number_format']} |")
            if len(cells) > 50:
                lines.append(f"| ... | *{len(cells) - 50} more* | |")
            lines.append("")

    # VBA Macros
    if a['vba_macros'] and a['vba_macros'].get('has_macros'):
        lines.append("## VBA Macros")
        lines.append("")
        for mod in a['vba_macros']['modules']:
            lines.append(f"### {mod['filename']}")
            if 'code' in mod:
                lines.append("")
                lines.append("```vba")
                lines.append(mod['code'])
                lines.append("```")
            elif 'note' in mod:
                lines.append(f"*{mod['note']}*")
            lines.append("")

    # Data Samples
    lines.append("## Data Samples (First Rows)")
    lines.append("")
    for sheet in a['sheets']:
        if not sheet['data_sample'] and not sheet['headers']:
            continue
        lines.append(f"### {sheet['name']}")
        lines.append("")
        if sheet['headers']:
            lines.append("**Headers:**")
            for h_row in sheet['headers']:
                vals = [f"{h['cell']}={h['value']}" for h in h_row]
                lines.append(f"- {', '.join(vals)}")
            lines.append("")
        if sheet['data_sample']:
            lines.append("**Sample rows:**")
            for dr in sheet['data_sample'][:10]:
                items = [f"{k}={v}" for k, v in dr['data'].items()]
                lines.append(f"- Row {dr['row']}: {', '.join(items[:8])}")
                if len(items) > 8:
                    lines.append(f"  - {', '.join(items[8:16])}")
            lines.append("")

    return "\n".join(lines)


def _infer_sheet_purpose(sheet_info):
    """Infer sheet purpose from its name and content."""
    name = sheet_info['name'].lower()
    if 'color' in name:
        return "Brand color reference"
    if 'lookup' in name or 'look up' in name:
        return "Dropdown/reference data"
    if 'rate' in name:
        return "Rate schedule"
    if 'input' in name:
        return "Input parameters"
    if 'wbs' in name:
        return "Work breakdown structure"
    if 'par_' in name:
        return "Parametric estimation data"
    if 'resource' in name and 'plan' in name:
        return "Resource allocation plan"
    if 'cost' in name:
        return "Cost calculations"
    if 'change' in name or 'log' in name:
        return "Change log / version history"
    if 'timeline' in name:
        return "Project timeline"
    if 'report' in name:
        return "Reports and analysis"
    if 'assumption' in name:
        return "Estimation assumptions"
    if 'client' in name:
        return "Client-facing data view"
    if sheet_info['state'] != 'visible':
        return "Hidden reference data"
    # Check formula count for hint
    if len(sheet_info['formulas']) > 20:
        return "Calculation sheet"
    return ""


def main():
    parser = argparse.ArgumentParser(description="Analyze Excel file structure for Dataverse spec documentation")
    parser.add_argument("file", help="Path to Excel file (.xlsx, .xltx, .xlsm, .xltm)")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")
    parser.add_argument("--format", "-f", choices=["json", "markdown"], default="markdown",
                        help="Output format (default: markdown)")
    parser.add_argument("--max-rows", type=int, default=DEFAULT_MAX_ROWS,
                        help=f"Rows scanned per sheet (default: {DEFAULT_MAX_ROWS}). Raise for large sheets; "
                             f"any truncation is reported in the output either way.")
    parser.add_argument("--max-cols", type=int, default=DEFAULT_MAX_COLS,
                        help=f"Columns scanned per sheet (default: {DEFAULT_MAX_COLS}).")
    parser.add_argument("--max-formulas", type=int, default=DEFAULT_MAX_FORMULAS,
                        help=f"Formulas captured per sheet (default: {DEFAULT_MAX_FORMULAS}). Comments and "
                             f"input cells are collected in full regardless of this cap.")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"ERROR: File not found: {args.file}", file=sys.stderr)
        sys.exit(1)

    try:
        warning = validate_input_format(args.file)
        if warning:
            print(warning, file=sys.stderr)
        analysis = analyze_workbook(args.file, max_rows=args.max_rows, max_cols=args.max_cols,
                                    max_formulas=args.max_formulas)
    except WorkbookLoadError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)

    if args.format == "json":
        output = json.dumps(analysis, indent=2, default=str)
    else:
        output = generate_markdown(analysis)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"Analysis written to: {args.output}", file=sys.stderr)
    else:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        print(output)


if __name__ == "__main__":
    main()
