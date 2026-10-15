#!/usr/bin/env python
"""
Read-MatrixWorkbook.py — profile + extract an RFP requirements worksheet.

Profiles any client requirements matrix (.xlsx/.xlsm): detects, per sheet, the
header row and the ROLE of each column (requirement text, id/number, priority,
one-or-more vendor-response columns, cost, required-product, comment), then
emits the requirement rows with section-header rows flagged.

The role detection is heuristic and is meant to be *confirmed by the consultant*
before any write-back (see SKILL.md "Profile" step) — never trust it silently.

Usage:
    python Read-MatrixWorkbook.py "<workbook.xlsx>" [--json out.json] [--max-preview 8]

Output:
    - Human-readable profile to stdout (sheets, detected column map, row counts).
    - If --json given, a machine-readable profile {sheets:[{name, header_row,
      columns:{role:col_index}, response_columns:[...], rows:[{row, number,
      text, priority, responses:{header:value}, is_section}]}]}.

Exit codes: 0 ok; 2 file not found / unreadable.
"""
import sys, os, json, argparse

try:
    import openpyxl
except ImportError:
    sys.stderr.write("openpyxl not installed. Run: python -m pip install -r requirements.txt\n")
    sys.exit(2)

# --- Role detection keywords (lowercased substring match against header text) ---
ROLE_KEYWORDS = {
    "number":      ["number", "req #", "req#", "req num", "req. num", "id", "seq", "item #"],
    "requirement": ["application requirement", "requirement description", "requirement",
                    "sub-function", "subtopic", "attribute", "specification", "capability"],
    "priority":    ["priority", "client score", "weight", "importance", "criticality"],
    "cost":        ["cost", "price"],
    "product":     ["required product", "product(s)", "module", "solution component", "primary product"],
    "comment":     ["comment", "notes", "additional detail", "internal comments", "vendor comment"],
}
# Response/verdict columns are recognised by these header cues OR by being a
# blank-but-present column to the right of the requirement under a known banner.
RESPONSE_KEYWORDS = [
    "d365 availability", "availability", "standard", "modify", "modification", "custom",
    "cannot", "3rd party", "third party", "future", "vendor score", "fit",
    "basic configuration", "complex configuration", "embedded", "pre-integrated",
    "point solution", "new extension", "not supported", "response", "meets requirement",
]

def _norm(v):
    return "" if v is None else str(v).replace("\n", " ").strip()

def _lower(v):
    return _norm(v).lower()

def detect_header_row(rows, scan=15):
    """Pick the row (within the first `scan`) that best looks like a header."""
    best_idx, best_score = None, 0
    for i, row in enumerate(rows[:scan]):
        cells = [_lower(c) for c in row]
        score = 0
        for c in cells:
            if not c:
                continue
            if any(k in c for k in ROLE_KEYWORDS["requirement"]): score += 3
            if any(k in c for k in ROLE_KEYWORDS["priority"]):    score += 2
            if any(k in c for k in RESPONSE_KEYWORDS):            score += 2
            if any(k in c for k in ROLE_KEYWORDS["comment"]):     score += 1
            if any(k in c for k in ROLE_KEYWORDS["number"]):      score += 1
        if score > best_score:
            best_idx, best_score = i, score
    return best_idx

def map_columns(header_cells):
    """Map column index -> role. Response columns collected separately (can be many)."""
    colmap, response_cols = {}, []
    taken = set()
    # First pass: strong single-role columns
    for idx, raw in enumerate(header_cells):
        h = _lower(raw)
        if not h:
            continue
        for role in ("number", "requirement", "priority", "cost", "product", "comment"):
            if role in colmap:
                continue
            if any(k in h for k in ROLE_KEYWORDS[role]):
                colmap[role] = idx
                taken.add(idx)
                break
    # Second pass: response/verdict columns (everything matching response cues, not already taken)
    for idx, raw in enumerate(header_cells):
        if idx in taken:
            continue
        h = _lower(raw)
        if h and any(k in h for k in RESPONSE_KEYWORDS):
            response_cols.append({"col": idx, "header": _norm(raw)})
            taken.add(idx)
    return colmap, response_cols

def profile_sheet(ws):
    rows = [list(r) for r in ws.iter_rows(values_only=True)]
    hdr = detect_header_row(rows)
    out = {"name": ws.title, "header_row": hdr, "columns": {}, "response_columns": [],
           "rows": [], "warnings": []}
    if hdr is None:
        out["warnings"].append("No header row detected in first 15 rows.")
        return out
    header_cells = rows[hdr]
    colmap, response_cols = map_columns(header_cells)
    out["columns"] = colmap
    out["response_columns"] = response_cols
    if "requirement" not in colmap:
        out["warnings"].append("No requirement-text column detected — confirm mapping manually.")
    req_col = colmap.get("requirement")
    num_col = colmap.get("number")
    pri_col = colmap.get("priority")
    resp_idx = [c["col"] for c in response_cols]
    for r_i in range(hdr + 1, len(rows)):
        row = rows[r_i]
        def cell(ci):
            return _norm(row[ci]) if ci is not None and ci < len(row) else ""
        text = cell(req_col)
        number = cell(num_col)
        priority = cell(pri_col)
        responses = {response_cols[k]["header"]: cell(ci) for k, ci in enumerate(resp_idx)}
        # skip fully empty rows
        if not text and not number and not priority and not any(responses.values()):
            continue
        # section header heuristic: has text, but no priority and no response values
        is_section = bool(text) and not priority and not any(responses.values())
        out["rows"].append({
            "row": r_i + 1,  # 1-based for openpyxl write-back
            "number": number,
            "text": text,
            "priority": priority,
            "responses": responses,
            "is_section": is_section,
        })
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("workbook")
    ap.add_argument("--json", dest="json_out")
    ap.add_argument("--max-preview", type=int, default=8)
    args = ap.parse_args()

    if not os.path.isfile(args.workbook):
        sys.stderr.write(f"File not found: {args.workbook}\n")
        sys.exit(2)

    wb = openpyxl.load_workbook(args.workbook, data_only=True, read_only=True)
    profile = {"workbook": os.path.basename(args.workbook), "sheets": []}
    for ws in wb.worksheets:
        profile["sheets"].append(profile_sheet(ws))
    wb.close()

    # Human-readable summary
    print(f"WORKBOOK: {profile['workbook']}")
    for s in profile["sheets"]:
        scored = [r for r in s["rows"] if not r["is_section"]]
        sect = [r for r in s["rows"] if r["is_section"]]
        print("\n" + "=" * 78)
        print(f"SHEET: {s['name']}  | header row: {s['header_row']}")
        print(f"  columns: {s['columns']}")
        print(f"  response columns: {[c['header'] for c in s['response_columns']]}")
        print(f"  scored reqs: {len(scored)} | section headers: {len(sect)}")
        for w in s["warnings"]:
            print(f"  ! WARNING: {w}")
        for r in scored[:args.max_preview]:
            print(f"    R{r['row']} [{r['priority']}] {r['text'][:80]}  -> {r['responses']}")
        if len(scored) > args.max_preview:
            print(f"    ... (+{len(scored) - args.max_preview} more)")

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(profile, fh, indent=2, ensure_ascii=False)
        print(f"\nProfile JSON written: {args.json_out}")

if __name__ == "__main__":
    main()
