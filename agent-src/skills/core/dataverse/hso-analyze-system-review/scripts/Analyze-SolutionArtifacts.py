#!/usr/bin/env python
"""
Offline best-practice scan of exported solution artifacts (.zip) — an auth-free complement to the
live Microsoft Solution Checker (`pac solution check`, which needs a fresh interactive pac sign-in).

Unzips each solution, scans the deployed JavaScript web resources for deprecated/risky patterns, and
notes plugin assemblies / classic workflows present. Emits checker_summary.json
[{rule,severity,count,recommendation}] consumed by Analyze-SystemRisks.py (Solution Checker area).

GENERIC — no client content. Usage:
  python Analyze-SolutionArtifacts.py <zips_dir_or_glob> <out_metadata_dir>
"""
import sys, os, re, glob, json, zipfile, io
from collections import Counter

PATTERNS = {
    "Xrm.Page (deprecated) in deployed JS": (re.compile(r"Xrm\.Page"), "Medium",
        "Migrate to executionContext.getFormContext() per HSO form-script standards."),
    "Synchronous XHR in deployed JS": (re.compile(r"async:\s*false|new\s+XMLHttpRequest"), "High",
        "Replace with async Xrm.WebApi; synchronous requests block the UI thread and are deprecated."),
    "alert()/confirm() UX in deployed JS": (re.compile(r"\b(?:alert|confirm)\s*\("), "Low",
        "Use Xrm.Navigation.openAlertDialog/openConfirmDialog."),
    "Direct DOM access in deployed JS": (re.compile(r"document\.getElement|\.innerHTML|\$\("), "Medium",
        "Avoid DOM/jQuery against the form; use the Client API (unsupported and fragile across updates)."),
    "eval() in deployed JS": (re.compile(r"\beval\s*\("), "High",
        "Remove eval(); security and maintainability risk."),
    "Hardcoded org URL in deployed JS": (re.compile(r"https://[a-z0-9-]+\.(?:crm\d*\.)?dynamics\.com", re.I), "Medium",
        "Resolve URLs at runtime (getClientUrl); remove environment-specific URLs."),
}

SKIP_NAME = re.compile(r"(bundle\.js$|\.min\.js$|/lib/|/libs?/|/libraries/|jquery|/node_modules/|/controls/)", re.I)

def is_minified(txt):
    """Heuristic: bundled/minified files (PCF, vendor libs) — skip to avoid framework false positives."""
    if not txt: return False
    lines = txt.split("\n")
    maxlen = max((len(l) for l in lines), default=0)
    return maxlen > 2000 or (len(txt) > 50000 and (len(lines) / len(txt)) < 0.005)

def main():
    if len(sys.argv) < 3:
        print("usage: Analyze-SolutionArtifacts.py <zips_dir_or_glob> <out_metadata_dir>"); sys.exit(2)
    src, out = sys.argv[1], sys.argv[2]
    zips = glob.glob(os.path.join(src, "*.zip")) if os.path.isdir(src) else glob.glob(src)
    if not zips:
        print("no .zip solutions found at", src); sys.exit(1)

    agg = Counter(); files_hit = Counter()
    js_count = 0; sol_count = 0; assemblies = 0; sols = []; skipped = 0
    for z in zips:
        sol_count += 1; sols.append(os.path.basename(z))
        try:
            zf = zipfile.ZipFile(z)
        except Exception as e:
            print("skip", z, e); continue
        for n in zf.namelist():
            low = n.lower()
            if low.endswith(".dll"): assemblies += 1
            if not low.endswith(".js"): continue
            if SKIP_NAME.search(n.replace("\\", "/")): skipped += 1; continue
            try:
                txt = zf.read(n).decode("utf-8", errors="ignore")
            except Exception:
                continue
            if is_minified(txt): skipped += 1; continue
            js_count += 1
            for label, (rx, _sev, _rec) in PATTERNS.items():
                c = len(rx.findall(txt))
                if c: agg[label] += c; files_hit[label] += 1

    summary = []
    for label, (rx, sev, rec) in PATTERNS.items():
        if agg[label]:
            summary.append({"rule": label, "severity": sev, "count": agg[label],
                            "recommendation": rec, "files": files_hit[label]})
    os.makedirs(out, exist_ok=True)
    json.dump(summary, open(os.path.join(out, "checker_summary.json"), "w", encoding="utf-8"), indent=2)
    print(f"SOLUTION_SCAN_DONE: {sol_count} solution(s), {js_count} hand-written JS scanned, {skipped} bundled/minified skipped, {assemblies} assemblies")
    print("rules flagged:", {s["rule"]: s["count"] for s in summary} or "none")
    print("OUT:", os.path.join(out, "checker_summary.json"))

if __name__ == "__main__":
    main()
