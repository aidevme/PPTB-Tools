# SBD / Client-Document — Pre-Issue QA Checklist

Run this before a Word deliverable (SBD or Client Document) goes to a client. Every item is
**machine-checkable** by re-opening the produced `.docx` with `python-docx`, so this doubles as the
spec for the structural-QA eval. Generic only — no client content here.

The builder (`scripts/Build-WordDeliverable.py`) prints a **non-blocking integrity-review list** at the
end of a run; this checklist is the human gate that clears it.

## Structural (the document's contract)

- [ ] **Skeleton present** — for an SBD, front matter (Copyright · Trademarks · Disclaimer · Contributors ·
      Revision History · TOC) then body **1 Introduction … 7 Acceptance** (see [sbd-word-structure.md](sbd-word-structure.md)).
- [ ] **Numbering is style-driven** — headings carry no typed numbers; no double numbers ("1. 1. …"); decimal
      hierarchy `1` / `1.1` / `1.1.1` comes from the style / injected list.
- [ ] **Auto-updating TOC field present** (levels 1–3) after the title block.
- [ ] **Contributors** (Name/Role/Company) and **Revision History** (Version/Section/Content Change/Date) tables
      present; **no single stamped author**; `core_properties.author` blank or `HSO` (never the maintainer).
- [ ] **Brand** — one font family (Segoe UI); styles from the base (`Table Grid`, bullets), no manual font/size overrides.

## Integrity (what may not leave the building — SOP §6–§7)

- [ ] **No `[PLACEHOLDER: …]` left** — zero yellow-highlighted runs remain (each is an unfilled gap).
- [ ] **No fabrication-smell** — no "across N HSO engagements", "HSO experience shows", or unsourced incident/$
      claims presented as HSO experience (SOP §7; see the [override-fabrication audit](../../../agent/wiki/digests/hso-override-fabrication-audit.md)).
      State the *recommendation*, never an Override's engagement/incident/$ evidence.
- [ ] **No internal pointers** — no SOP/skill file paths, ADR numbers, `agent/wiki/` references, "HSO Override",
      or "per HSO SOP §x" anywhere a client sees (SOP §7).
- [ ] **No unsupplied names/clients** — no client name or named individual appears that the user did not supply
      for *this* document (SOP §5, §6a); Company defaults to `HSO`.
- [ ] **Scope honored** — only in-scope systems/modules/integrations have §3–§6 sub-sections (SOP §4a); out-of-scope
      items are omitted, not placeholdered.

## Automation hook

`Build-WordDeliverable.py` scans authored content (lead + `blocks`) for the fabrication-smell and
internal-pointer patterns above and prints an `INTEGRITY REVIEW` list — heuristic, not a gate. The
structural items are asserted by re-opening the output `.docx` (the basis for the structural-QA eval).