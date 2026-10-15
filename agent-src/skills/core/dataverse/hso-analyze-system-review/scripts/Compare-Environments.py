#!/usr/bin/env python
"""
Compare two harvested-metadata folders (e.g. Dev vs QA vs Prod) and report drift.

GENERIC. Both folders must be harvested at the SAME scope (e.g. both -AppName MyApp) for a fair diff.
Outputs a markdown drift report + CSVs (tables/fields/forms/workflows/solutions).

Usage:  python Compare-Environments.py <dirA> <dirB> <out_dir> [labelA] [labelB]
"""
import sys, os, json, csv

def load(d, n):
    p = os.path.join(d, n)
    return json.load(open(p, encoding="utf-8-sig")) if os.path.exists(p) else []

def main():
    if len(sys.argv) < 4:
        print("usage: Compare-Environments.py <dirA> <dirB> <out_dir> [labelA] [labelB]"); sys.exit(2)
    dA, dB, out = sys.argv[1], sys.argv[2], sys.argv[3]
    A = sys.argv[4] if len(sys.argv) > 4 else "A"
    B = sys.argv[5] if len(sys.argv) > 5 else "B"
    os.makedirs(out, exist_ok=True)

    entA = {e["LogicalName"]: e for e in load(dA, "entities.json")}
    entB = {e["LogicalName"]: e for e in load(dB, "entities.json")}
    atA, atB = load(dA, "attributes.json"), load(dB, "attributes.json")
    def fieldset(at):
        m = {}
        for a in at: m.setdefault(a["Entity"], set()).add(a["LogicalName"])
        return m
    fA, fB = fieldset(atA), fieldset(atB)
    def mainforms(d):
        m = {}
        for f in load(d, "forms.json"):
            if f.get("Type") == 2 and f.get("ActivationState") == 1:
                m.setdefault(f["Entity"], set()).add(f.get("Name"))
        return m
    mfA, mfB = mainforms(dA), mainforms(dB)
    def wfset(d): return {w.get("Name"): w for w in load(d, "workflows.json")}
    wA, wB = wfset(dA), wfset(dB)
    def sols(d): return {s.get("Unique"): s.get("Version") for s in load(d, "solution_catalog.json")}
    sA, sB = sols(dA), sols(dB)

    rows_tbl = []
    onlyA = sorted(set(entA) - set(entB)); onlyB = sorted(set(entB) - set(entA))
    for t in onlyA: rows_tbl.append([t, f"only in {A}", "", ""])
    for t in onlyB: rows_tbl.append([t, f"only in {B}", "", ""])
    rows_fld = []
    for t in sorted(set(entA) & set(entB)):
        da = fA.get(t, set()) - fB.get(t, set()); db = fB.get(t, set()) - fA.get(t, set())
        if da or db:
            rows_tbl.append([t, "field delta", f"+{len(da)} in {A}", f"+{len(db)} in {B}"])
            for x in sorted(da): rows_fld.append([t, x, f"only in {A}"])
            for x in sorted(db): rows_fld.append([t, x, f"only in {B}"])
    rows_form = []
    for t in sorted(set(mfA) | set(mfB)):
        fa, fb = mfA.get(t, set()), mfB.get(t, set())
        for x in sorted(fa - fb): rows_form.append([t, x, f"active main only in {A}"])
        for x in sorted(fb - fa): rows_form.append([t, x, f"active main only in {B}"])
    rows_wf = []
    for n in sorted(set(wA) | set(wB)):
        if n not in wB: rows_wf.append([n, wA[n].get("PrimaryEntity"), f"only in {A}"])
        elif n not in wA: rows_wf.append([n, wB[n].get("PrimaryEntity"), f"only in {B}"])
        elif wA[n].get("StateCode") != wB[n].get("StateCode"):
            rows_wf.append([n, wA[n].get("PrimaryEntity"), f"state {A}={wA[n].get('StateCode')} {B}={wB[n].get('StateCode')}"])
    rows_sol = []
    for u in sorted(set(sA) | set(sB)):
        if sA.get(u) != sB.get(u): rows_sol.append([u, sA.get(u, "-"), sB.get(u, "-")])

    def writecsv(name, header, rows):
        with open(os.path.join(out, name), "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f); w.writerow(header); w.writerows(rows)
    writecsv("drift_tables.csv", ["Table", "Drift", A, B], rows_tbl)
    writecsv("drift_fields.csv", ["Table", "Field", "Drift"], rows_fld)
    writecsv("drift_forms.csv", ["Table", "Form", "Drift"], rows_form)
    writecsv("drift_workflows.csv", ["Name", "Entity", "Drift"], rows_wf)
    writecsv("drift_solutions.csv", ["Solution", A, B], rows_sol)

    md = [f"# Environment drift — {A} vs {B}", "",
          f"- Tables only in {A}: {len(onlyA)} · only in {B}: {len(onlyB)}",
          f"- Tables with field deltas: {len([r for r in rows_tbl if r[1]=='field delta'])}",
          f"- Field-level deltas: {len(rows_fld)}",
          f"- Active-main-form deltas: {len(rows_form)}",
          f"- Workflow/flow deltas: {len(rows_wf)}",
          f"- Solution version differences: {len(rows_sol)}", "",
          "## Solution version differences", "", f"| Solution | {A} | {B} |", "|---|---|---|"]
    for r in rows_sol: md.append(f"| {r[0]} | {r[1]} | {r[2]} |")
    open(os.path.join(out, "drift_report.md"), "w", encoding="utf-8").write("\n".join(md))
    print("DRIFT:", f"tables only-{A}={len(onlyA)} only-{B}={len(onlyB)};",
          f"field-deltas={len(rows_fld)}; form-deltas={len(rows_form)}; wf-deltas={len(rows_wf)}; sol-version-diffs={len(rows_sol)}")
    print("OUT:", out)

if __name__ == "__main__":
    main()
