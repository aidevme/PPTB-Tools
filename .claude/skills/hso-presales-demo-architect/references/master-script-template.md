# Demo Master Script — the choreographed present-from document

The **Master Script** is the third demo artifact (alongside the Outline and the Clickpath). It is the
**single document the presenter drives the live demo from** — the run-of-show (timing, tab map, cuts) and the
word-for-word clickpath, **interleaved as SAY + CLICK choreography**.

It exists because, in a real run, the presenter cannot hold an outline *and* a deep clickpath open at once. The
Outline stays an internal/exec briefing; the Clickpath becomes the **deep reference** (Q&A prep, recovery moves,
full record/URL table, build-status notes); the Master Script is what's on the second monitor at go-time.

## When to produce one

Produce a Master Script (in addition to the Outline + Clickpath) when **any** of these hold:
- The demo is **presented live to a client/exec audience** (not just an internal walkthrough).
- There is a **hard time ceiling** (e.g. a 1:45 slot) that forces cut/restore decisions on the fly.
- The flow spans **multiple acts, personas, or browser tabs/apps** that must be pre-loaded and switched in order.
- More than one variant draft already exists (`_MR`, `_CONSOLIDATED_DRAFT`, etc.) — consolidate them **into** the
  Master Script rather than leaving parallel near-duplicates that drift (see demo-data-fidelity.md §5).

For a short, single-thread internal demo the Outline + Clickpath are enough — don't force a Master Script.

## File

`clients/<ClientName>/PROJ-<project>/04_solutioning/Demo_Master_Script.md` — root tier, present-facing.
The Clickpath remains the deep reference and the Master Script links to it by name in its header.

## Required structure

### 1. Header block
- One-line statement of what this doc is ("single present-from document … interleaved SAY + CLICK").
- Hard ceiling and target (e.g. "scripted to a hard 1:45 ceiling, targets ~1:40").
- **Presenter · Environment · Author · Updated** line.
- **Deep reference** pointer: the `Presenter_Clickpath.md` (Q&A, recovery, record table, build notes).

### 2. "How to read this script" legend
A token table. Recommended tokens (extend as needed):

| Token | Meaning |
| --- | --- |
| **SAY:** | Say this, verbatim. |
| **CLICK:** | Click this exact target. Path = `Tab ▸ Record/Screen ▸ element`. |
| **TYPE:** | Type / paste this. |
| **DO:** | Non-click action (switch tab, scroll, wait, fill form). |
| **AND** | Do both at once — talk *while* clicking. |
| **THEN** | Sequential — finish the first, then the second. |
| ⭐ **LIVE** | Present live, never canned — the "prove it's real" beats. |
| 🔒 KEEP | Do not cut. |
| ✂️ CUT | Cut for this run — show collapsed with a one-line bridge. |
| ⚙ Setup | Must be done **before** the room arrives. |

### 3. Tab / app pre-load map
List the tabs or apps to open **left→right before go-time**, lettered, each with what it shows and (if
applicable) which persona/login it's signed in as. Call out the **minimum** set needed for the time-boxed run.
This is the operationalization of the **primary app** captured at Step 2 (demo-data-fidelity.md §6) — every
`CLICK:` path resolves against these tabs.

### 4. Timing table (with cut + restore order)
A per-act table: `Act | Min | Cumulative | Cut for this run`. Below it:
- **Restore order** — the exact order to add beats back if running ahead, with the per-beat cost.
- **Fixed/never-cut callouts** — partner-owned segments (e.g. a vendor's 15-min slot), ⭐ LIVE beats, and any
  beat tied to a specific person in the room.

### 5. "Decisions this script reflects"
A short bullet list reconciling the script to the **resolved decision log** and the latest build state, so the
present-from doc and the build can't silently diverge. Name the canonical numbers (counts, $ figures, persona
names) once here; they must match the Outline and Clickpath verbatim.

### 6. Acts — interleaved choreography
Each act is `# ACT N — NAME · <min> · <medium>`, then numbered beats `### §N.n — Beat name · <min> · <markers>`.
Within a beat, steps are numbered and use the legend tokens. End each act with a **Punchline** SAY line.
- ✂️ CUT beats are shown **collapsed** with a `> **Bridge (say in place of this beat):**` line and a parenthetical
  `(Restore: …)` so the cut content isn't lost.
- ⚙ Setup notes ride **inside** the beat they gate (`> ⚙ Setup: …`), not in a separate appendix.
- Record references are **live deep-links** to the records in the primary app; the full record/URL table lives in
  the Clickpath's "Record Quick Reference," and the Master Script points there rather than duplicating it.

### 7. Footer
One line: end-of-script marker pointing back to the Clickpath for Q&A prep, recovery moves, the record/URL table,
and build-status notes.

## References and SOPs to cite in the Master Script

Where a beat depends on a build mechanic with a known procedure, cite the SOP **in the gating `⚙ Setup` note** so
whoever runs the demo can re-do it — don't bury it in a separate doc:
- **SLA / countdown timers** that must be ticking at demo start → cite the re-anchor procedure
  (`hso-dataverse-ui-config` → SLA KPI timers) and **state the demo date/time assumption** (demo-data-fidelity.md
  §2, §8). Re-anchor if the slot moves.
- **Pricing/commodity refresh, BPF stage advance, approval flows** → name the pre-session setup step explicitly
  ("bump the COMEX rate before the session so the refresh visibly moves numbers").
- **Portal changes** → "clear the portal cache after any change."
- **Demo-owned records** → confirm the demo-use stamp (demo-data-fidelity.md §8) is set so a parallel build can't
  overwrite the seeded record.

## Relationship to the other two artifacts

| Artifact | Audience | Role |
| --- | --- | --- |
| `DemoOutline.md` | Internal / exec | 1–2 page briefing — what the demo covers and why |
| `Demo_Master_Script.md` | Presenter (live) | Present-from choreography — SAY + CLICK, timing, cuts, tabs |
| `Presenter_Clickpath.md` | Presenter (prep) | Deep reference — Q&A, recovery moves, record/URL table, build notes |

All three describe the **same demo**: part names, timings, persona names, and headline numbers must match across
all three. When you reconcile, grep for stale tokens across **all three** (demo-data-fidelity.md §5).
