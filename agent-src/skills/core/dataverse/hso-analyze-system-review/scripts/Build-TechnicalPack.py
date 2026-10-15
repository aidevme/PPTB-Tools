#!/usr/bin/env python
"""
Build the HSO System Review *Technical Pack* (Excel) from harvested metadata JSON.

GENERIC — no client content. Reads the JSON written by Harvest-DataverseMetadata.ps1 and emits a
multi-sheet, HSO-branded .xlsx inventory (Tables, Fields, Forms, Views, Web Resources/JS, Workflows,
Flows, Business Rules, Actions, Plugins, Apps, Dashboards, Charts, Solutions, Security, Risks).

Usage:  python Build-TechnicalPack.py <metadata_dir> <out.xlsx> [risks.json]
"""
import sys, json, os
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

NAVY = "00395F"; WHITE = "FFFFFF"; LT = "F2F2F2"
HEAD_FILL = PatternFill("solid", fgColor=NAVY)
HEAD_FONT = Font(name="Segoe UI", bold=True, color=WHITE, size=11)
CELL_FONT = Font(name="Segoe UI", size=10)
THIN = Side(style="thin", color="D9D9D9"); BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

FORM_TYPE = {2: "Main", 6: "Quick Create", 7: "Quick View", 11: "Card", 8: "Dialog", 0: "Dashboard", 5: "Mobile"}
ACT = {0: "Inactive", 1: "Active"}
WF_CAT = {0: "Classic Workflow", 1: "Dialog", 2: "Business Rule", 3: "Action", 4: "BPF", 5: "Cloud Flow"}
WF_MODE = {0: "Background", 1: "Real-time"}
WF_SCOPE = {1: "User", 2: "Business Unit", 3: "Parent-Child BU", 4: "Organization"}
WF_STATE = {0: "Draft", 1: "Activated", 2: "Suspended"}
QTYPE = {0: "Public", 1: "Advanced Find", 2: "Associated", 4: "Quick Find", 8: "Lookup", 64: "Offline"}


def load(d, name):
    p = os.path.join(d, name)
    if not os.path.exists(p): return None
    with open(p, encoding="utf-8-sig") as f:
        return json.load(f)


def as_list(x):
    if x is None: return []
    return x if isinstance(x, list) else [x]


def sheet(wb, title, headers, rows):
    ws = wb.create_sheet(title[:31])
    ws.append(headers)
    for c in ws[1]:
        c.fill = HEAD_FILL; c.font = HEAD_FONT; c.alignment = Alignment(vertical="center"); c.border = BORDER
    for r in rows:
        ws.append([("" if v is None else v) for v in r])
    # style + width
    for col in range(1, len(headers) + 1):
        width = len(str(headers[col - 1])) + 2
        for r in range(2, ws.max_row + 1):
            cell = ws.cell(r, col); cell.font = CELL_FONT; cell.border = BORDER
            cell.alignment = Alignment(vertical="top", wrap_text=True)
            width = max(width, min(60, len(str(cell.value)) + 2))
        ws.column_dimensions[ws.cell(1, col).column_letter].width = width
    # zebra striping
    for r in range(2, ws.max_row + 1):
        if r % 2 == 0:
            for col in range(1, len(headers) + 1):
                ws.cell(r, col).fill = PatternFill("solid", fgColor=LT)
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = f"A1:{ws.cell(1, len(headers)).column_letter}{ws.max_row}"
    return ws


def main():
    if len(sys.argv) < 3:
        print("usage: python Build-TechnicalPack.py <metadata_dir> <out.xlsx> [risks.json]"); sys.exit(2)
    d, out = sys.argv[1], sys.argv[2]
    risks_path = sys.argv[3] if len(sys.argv) > 3 else None
    wb = Workbook(); wb.remove(wb.active)

    ent = load(d, "entities.json") or []
    attrs = load(d, "attributes.json") or []
    forms = load(d, "forms.json") or []
    views = load(d, "views.json") or []
    wf = load(d, "workflows.json") or []
    wr = load(d, "webresources.json") or []
    apps = load(d, "apps.json") or []
    dash = load(d, "dashboards.json") or []
    charts = load(d, "charts.json") or []
    cat = load(d, "solution_catalog.json") or []
    sec = load(d, "security_org.json") or {}
    plugins = load(d, "pluginsteps.json") or []

    classic = [w for w in wf if w.get("Category") == 0]
    flows = [w for w in wf if w.get("Category") == 5]
    rules = [w for w in wf if w.get("Category") == 2]
    actions = [w for w in wf if w.get("Category") == 3]

    # --- Summary ---
    summ = [
        ["Tables (in scope)", len(ent)],
        ["Fields", len(attrs)],
        ["  - custom", sum(1 for a in attrs if a.get("IsCustom"))],
        ["  - searchable custom", sum(1 for a in attrs if a.get("IsCustom") and a.get("SearchableAF"))],
        ["Forms", len(forms)],
        ["  - active main", sum(1 for f in forms if f.get("Type") == 2 and f.get("ActivationState") == 1)],
        ["Views", len(views)],
        ["Web resources (unmanaged)", len(wr)],
        ["  - JScript", sum(1 for w in wr if w.get("Type") == "JScript")],
        ["Classic workflows", len(classic)],
        ["Cloud flows", len(flows)],
        ["Business rules", len(rules)],
        ["Actions", len(actions)],
        ["Plugin steps", len(plugins)],
        ["Apps", len(apps)],
        ["Dashboards", len(dash)],
        ["Charts", len(charts)],
        ["Solutions (visible)", len(cat)],
    ]
    sheet(wb, "Summary", ["Metric", "Count"], summ)

    sheet(wb, "Tables", ["Logical", "Display", "Custom", "Managed", "Ownership", "Source"],
          [[e.get("LogicalName"), e.get("DisplayName"), e.get("IsCustomEntity"), e.get("IsManaged"),
            e.get("OwnershipType"), e.get("Solutions", e.get("Source"))] for e in sorted(ent, key=lambda x: x.get("LogicalName", ""))])

    sheet(wb, "Fields", ["Entity", "Logical", "Display", "Type", "Custom", "Managed", "Searchable(AF)", "OnForm-valid", "RelevanceSearch", "AttributeOf"],
          [[a.get("Entity"), a.get("LogicalName"), a.get("DisplayName"), a.get("Type"), a.get("IsCustom"),
            a.get("IsManaged"), a.get("SearchableAF"), a.get("ValidForForm"), a.get("RelevanceSearch"), a.get("AttributeOf")]
           for a in sorted(attrs, key=lambda x: (x.get("Entity", ""), x.get("LogicalName", "")))])

    sheet(wb, "Forms", ["Entity", "Name", "Type", "State", "Managed", "Default", "InApp", "Fields", "JS Libraries", "Events", "Handlers"],
          [[f.get("Entity"), f.get("Name"), FORM_TYPE.get(f.get("Type"), f.get("Type")), ACT.get(f.get("ActivationState")),
            f.get("IsManaged"), f.get("IsDefault"), f.get("InApp"), f.get("FieldCount"),
            "; ".join(as_list(f.get("Libraries"))), "; ".join(as_list(f.get("Events"))), len(as_list(f.get("Functions")))]
           for f in sorted(forms, key=lambda x: (x.get("Entity", ""), str(x.get("Type"))))])

    sheet(wb, "Views", ["Entity", "Name", "QueryType", "Default", "Managed"],
          [[v.get("Entity"), v.get("Name"), QTYPE.get(v.get("QueryType"), v.get("QueryType")), v.get("IsDefault"), v.get("IsManaged")]
           for v in sorted(views, key=lambda x: (x.get("Entity", ""), x.get("Name", "")))])

    sheet(wb, "WebResources-JS", ["Name", "Display", "Type", "Managed", "Wired to a form"],
          [[w.get("Name"), w.get("DisplayName"), w.get("Type"), w.get("IsManaged"), w.get("WiredToForm")]
           for w in sorted(wr, key=lambda x: (x.get("Type", ""), x.get("Name", "")))])

    sheet(wb, "Classic Workflows", ["Name", "Entity", "Mode", "Scope", "State", "OnDemand", "TrigCreate", "TrigDelete", "TrigUpdateAttrs"],
          [[w.get("Name"), w.get("PrimaryEntity"), WF_MODE.get(w.get("Mode")), WF_SCOPE.get(w.get("Scope")),
            WF_STATE.get(w.get("StateCode")), w.get("OnDemand"), w.get("TriggerCreate"), w.get("TriggerDelete"), w.get("TriggerUpdateAttrs")]
           for w in sorted(classic, key=lambda x: x.get("Name", ""))])

    sheet(wb, "Cloud Flows", ["Name", "Entity", "State"],
          [[w.get("Name"), w.get("PrimaryEntity"), WF_STATE.get(w.get("StateCode"))] for w in sorted(flows, key=lambda x: x.get("Name", ""))])

    sheet(wb, "Business Rules", ["Name", "Entity", "State"],
          [[w.get("Name"), w.get("PrimaryEntity"), WF_STATE.get(w.get("StateCode"))] for w in sorted(rules, key=lambda x: x.get("Name", ""))])

    sheet(wb, "Actions", ["Name", "Entity", "State"],
          [[w.get("Name"), w.get("PrimaryEntity"), WF_STATE.get(w.get("StateCode"))] for w in sorted(actions, key=lambda x: x.get("Name", ""))])

    if plugins:
        sheet(wb, "Plugins", ["Assembly", "Type", "Step", "Message", "Stage", "Mode", "State", "FilterAttrs"],
              [[p.get("Assembly"), p.get("Type"), p.get("Step"), p.get("Message"), p.get("Stage"),
                p.get("Mode"), p.get("State"), p.get("FilterAttrs")] for p in plugins])

    sheet(wb, "Apps", ["Name", "Unique", "Managed", "Description"],
          [[a.get("Name"), a.get("Unique"), a.get("IsManaged"), a.get("Description")] for a in sorted(apps, key=lambda x: x.get("Name", ""))])

    sheet(wb, "Dashboards", ["Name", "Entity", "Managed"],
          [[x.get("Name"), x.get("Entity"), x.get("IsManaged")] for x in sorted(dash, key=lambda x: str(x.get("Name", "")))])
    sheet(wb, "Charts", ["Name", "Entity", "Managed"],
          [[x.get("Name"), x.get("Entity"), x.get("IsManaged")] for x in sorted(charts, key=lambda x: str(x.get("Name", "")))])

    sheet(wb, "Solutions", ["Unique", "Friendly", "Version", "Managed", "Publisher", "Prefix"],
          [[c.get("Unique"), c.get("Friendly"), c.get("Version"), c.get("Managed"), c.get("Publisher"), c.get("Prefix")] for c in cat])

    if isinstance(sec, dict) and sec:
        srows = []
        for k, v in sec.items():
            srows.append([k, v if not isinstance(v, (list, dict)) else json.dumps(v, ensure_ascii=False)])
        sheet(wb, "Security-Org", ["Property", "Value"], srows)

    secroles = load(d, "security_roles.json")
    if secroles:
        sheet(wb, "Security Roles", ["Role", "Entity", "Access", "Depth"],
              [[r.get("Role"), r.get("Entity"), r.get("Access"), r.get("Depth")] for r in secroles])

    rels = load(d, "relationships.json")
    if rels:
        sheet(wb, "Relationships", ["Schema", "Referenced (1)", "Referencing (N)", "Lookup Attribute", "Custom"],
              [[r.get("Schema"), r.get("Referenced"), r.get("Referencing"), r.get("ReferencingAttribute"), r.get("IsCustom")]
               for r in rels])

    # Risks (from Phase 2 risk register if provided, else placeholder)
    risk_rows = []
    if risks_path and os.path.exists(risks_path):
        for r in (json.load(open(risks_path, encoding="utf-8-sig")) or []):
            risk_rows.append([r.get("Id"), r.get("Area"), r.get("Item"), r.get("Severity"), r.get("Finding"), r.get("Recommendation")])
    sheet(wb, "Risks", ["Id", "Area", "Item", "Severity", "Finding", "Recommendation"], risk_rows)

    wb.save(out)
    print("SAVED:", out, "| sheets:", len(wb.sheetnames))


if __name__ == "__main__":
    main()
