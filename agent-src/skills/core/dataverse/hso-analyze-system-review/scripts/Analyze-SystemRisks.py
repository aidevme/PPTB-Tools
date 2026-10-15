#!/usr/bin/env python
"""
Build the System Review *Risk Register* (risks.json) from harvested metadata + (optional) source code.

GENERIC — no client content. Consolidates the heuristics behind the code/config review skills
(formscript, plugin-code-review, workflow->flow, form hygiene, security) into one register that
feeds Build-TechnicalPack.py (Risks sheet) and the client summary.

Usage:
  python Analyze-SystemRisks.py <metadata_dir> <out_risks.json> [--code <repo_dir>] [--client-prefix contoso]

Severities: High (fix), Medium (should), Low (nice), Info (note).
"""
import sys, os, json, re
from collections import Counter

def load(d, n):
    p = os.path.join(d, n)
    return json.load(open(p, encoding="utf-8-sig")) if os.path.exists(p) else None

def as_list(x): return x if isinstance(x, list) else ([] if x is None else [x])

def main():
    if len(sys.argv) < 3:
        print("usage: Analyze-SystemRisks.py <metadata_dir> <out_risks.json> [--code <repo>] [--client-prefix p]"); sys.exit(2)
    md, out = sys.argv[1], sys.argv[2]
    code = None; cp = None
    args = sys.argv[3:]
    for i, a in enumerate(args):
        if a == "--code" and i + 1 < len(args): code = args[i + 1]
        if a == "--client-prefix" and i + 1 < len(args): cp = args[i + 1]

    forms = load(md, "forms.json") or []
    attrs = load(md, "attributes.json") or []
    wf = load(md, "workflows.json") or []
    sec = load(md, "security_org.json") or {}
    wr = load(md, "webresources.json") or []

    R = []
    def add(area, item, sev, finding, rec):
        R.append({"Id": f"R{len(R)+1:03d}", "Area": area, "Item": item, "Severity": sev, "Finding": finding, "Recommendation": rec})

    # ---- Workflows ----
    classic = [w for w in wf if w.get("Category") == 0]
    active_classic = [w for w in classic if w.get("StateCode") == 1]
    bg = [w for w in active_classic if w.get("Mode") == 0]
    rt = [w for w in active_classic if w.get("Mode") == 1]
    dialogs = [w for w in wf if w.get("Category") == 1]
    if bg: add("Workflows", "Background classic workflows", "Medium",
               f"{len(bg)} active background classic workflows.", "Migrate to Power Automate cloud flows (modern, supportable, observable).")
    if rt: add("Workflows", "Real-time classic workflows", "Medium",
               f"{len(rt)} active real-time classic workflows.", "Review each: convert to flow (if async ok), business rule, or plugin.")
    if dialogs: add("Workflows", "Deprecated Dialogs", "High",
                    f"{len(dialogs)} Dialog(s) present (end-of-life technology).", "Retire/replace dialogs.")

    # ---- Forms ----
    main_active = [f for f in forms if f.get("Type") == 2 and f.get("ActivationState") == 1]
    big = [f for f in main_active if (f.get("FieldCount") or 0) >= 150]
    for f in sorted(big, key=lambda x: -(x.get("FieldCount") or 0))[:10]:
        add("Forms", f"Oversized form: {f.get('Entity')} / {f.get('Name')}", "Medium",
            f"{f.get('FieldCount')} fields on one main form.", "Rationalise tabs/sections; move rarely-used fields to a collapsed area or remove.")
    from collections import defaultdict
    dup = defaultdict(list)
    for f in main_active: dup[f.get("Entity")].append(f)
    dups = {e: fs for e, fs in dup.items() if len(fs) > 1}
    if dups:
        add("Forms", "Duplicate active main forms", "Low",
            f"{len(dups)} tables have >1 active main form.", "Designate one primary form per table; deactivate redundant ones; scope by security role.")

    # ---- Fields (unused searchable custom; UI-only reference) ----
    ref = set()
    for f in forms:
        for t in as_list(f.get("DataFields")): ref.add(str(t).lower())
        for t in as_list(f.get("RefTokens")): ref.add(str(t).lower())
    views = load(md, "views.json") or []
    for v in views:
        for t in as_list(v.get("RefTokens")): ref.add(str(t).lower())
    cand = [a for a in attrs if a.get("IsCustom") and a.get("SearchableAF") and not a.get("AttributeOf")]
    unused = [a for a in cand if a.get("LogicalName", "").lower() not in ref]
    client_unused = [a for a in unused if cp and a.get("LogicalName", "").startswith(cp + "_")]
    if unused:
        add("Fields", "Searchable fields not on forms/views", "Low",
            f"{len(unused)} searchable custom fields are on no form or view"
            + (f" ({len(client_unused)} client-owned)" if cp else "") + ".",
            "Review against rollup/calc/report dependencies, then deactivate/remove to simplify search.")

    # ---- Security ----
    if isinstance(sec, dict):
        if sec.get("BusinessUnits") == 1:
            add("Security", "Flat business-unit model", "Info",
                "Single (root) business unit — security is purely role-based, no BU data partitioning.",
                "Confirm this matches the access model; BU isolation unavailable if needed later.")
        fsp = sec.get("FieldSecurityProfiles") or []
        if not any(p for p in fsp if cp and (cp.lower() in str(p).lower())):
            add("Security", "No client field-security profiles", "Medium",
                "Field-security profiles are all OOTB/ISV; none client-authored.",
                "Confirm sensitive fields (financials, comp, revenue split) are protected via field-level security.")

    rolesum = load(md, "security_roles_summary.json")
    if rolesum:
        over = [r for r in rolesum if (r.get("OrgLevelWriteDelete") or 0) >= 20]
        if over:
            add("Security", "Broad org-level privileges in client roles", "Medium",
                f"{len(over)} client role(s) grant organization-level Write/Delete on 20+ tables (e.g. " +
                ", ".join(f"{r['Role']}={r['OrgLevelWriteDelete']}" for r in sorted(over, key=lambda x:-(x.get('OrgLevelWriteDelete') or 0))[:3]) + ").",
                "Review against least-privilege; scope Write/Delete to BU/owner depth where organization-wide access isn't required.")

    chk = load(md, "checker_summary.json")   # optional: [{rule,severity,count,recommendation}]
    for c in (chk or []):
        add("Solution Checker", c.get("rule","(rule)"), c.get("severity","Medium"),
            f"{c.get('count','?')} occurrence(s) flagged by Microsoft Solution Checker.",
            c.get("recommendation","Review per Solution Checker guidance."))

    # ---- JavaScript (optional code scan) ----
    if code and os.path.isdir(code):
        js = []
        for root, _, files in os.walk(code):
            if any(s in root for s in ("\\node_modules", "/node_modules", "\\bin", "\\obj", "\\.git")): continue
            for fn in files:
                if fn.lower().endswith(".js"): js.append(os.path.join(root, fn))
        pat = {
            "Xrm.Page (deprecated)": re.compile(r"Xrm\.Page"),
            "synchronous XHR": re.compile(r"async:\s*false|XMLHttpRequest"),
            "alert() UX": re.compile(r"\balert\s*\("),
            "DOM manipulation": re.compile(r"document\.getElement|\.innerHTML"),
            "eval()": re.compile(r"\beval\s*\("),
            "hardcoded org URL": re.compile(r"https://[a-z0-9-]+\.(?:crm\d*\.)?dynamics\.com", re.I),
        }
        agg = Counter(); files_hit = Counter()
        for p in js:
            try: txt = open(p, encoding="utf-8", errors="ignore").read()
            except Exception: continue
            for label, rx in pat.items():
                n = len(rx.findall(txt))
                if n: agg[label] += n; files_hit[label] += 1
        sevmap = {"Xrm.Page (deprecated)": "Medium", "synchronous XHR": "High", "alert() UX": "Low",
                  "DOM manipulation": "Medium", "eval()": "High", "hardcoded org URL": "Medium"}
        for label, n in agg.items():
            add("JavaScript", label, sevmap.get(label, "Medium"),
                f"{n} occurrence(s) across {files_hit[label]} file(s) (scanned {len(js)} JS files).",
                "Replace per HSO form-script standards (executionContext.getFormContext, async Xrm.WebApi, Xrm.Navigation notifications, no hardcoded URLs).")
        # plugins / C#
        cs = []
        for root, _, files in os.walk(code):
            if any(s in root for s in ("\\bin", "\\obj", "\\.git", "\\packages")): continue
            for fn in files:
                if fn.lower().endswith(".cs"): cs.append(os.path.join(root, fn))
        colset = 0; console = 0
        for p in cs:
            try: txt = open(p, encoding="utf-8", errors="ignore").read()
            except Exception: continue
            colset += len(re.findall(r"ColumnSet\(true\)", txt)); console += len(re.findall(r"Console\.Write", txt))
        if colset: add("Plugins", "ColumnSet(true)", "Medium", f"{colset} ColumnSet(true) retrievals (fetch all columns).", "Select only needed columns.")
        if console: add("Plugins", "Console.Write in plugins", "Low", f"{console} Console.Write call(s).", "Remove; use ITracingService.")
        tf = set(t.strip() for t in re.findall(r"<TargetFramework(?:Version)?[^>]*>([^<]+)", "\n".join(open(p, encoding="utf-8", errors="ignore").read() for p in [q for r2,_,fs in os.walk(code) for q in [os.path.join(r2,x) for x in fs] if q.lower().endswith(".csproj")][:50])) if t.strip())
        if len(tf) > 1:
            add("Plugins", "Mixed plugin target frameworks", "Medium", f"Frameworks: {', '.join(sorted(tf))}.", "Standardise; Dataverse plugin sandbox baseline is net462/4.6.2.")
    else:
        add("JavaScript", "Code review not run", "Info", "No source repo provided (--code).", "Clone the client source repo and re-run for JS/plugin risk.")

    json.dump(R, open(out, "w", encoding="utf-8"), indent=2)
    bysev = Counter(r["Severity"] for r in R)
    print("SAVED:", out, "| risks:", len(R), "|", dict(bysev))


if __name__ == "__main__":
    main()
