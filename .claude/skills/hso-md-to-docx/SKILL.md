---
name: hso-md-to-docx
layer: atomic
scope: core
description: |
  Convert a Markdown file to a Word .docx, rendering Mermaid diagrams to embedded PNGs.
  Use when:
  (1) User asks to convert markdown to Word, export a .md as .docx, or "make this a Word doc"
  (2) A markdown deliverable needs to go to a client who expects Word
  (3) A document contains Mermaid diagrams that must survive the conversion as images
  (4) Documentation is being exported for review by someone outside the repo
  Does NOT produce HSO-branded client deliverables on the corporate template — use
  `hso-engagement-deliverables` for anything client-facing that must carry HSO branding.
  Does NOT generate PDFs, edit existing .docx files, or convert other formats.
---

# Markdown to Word (.docx)

Converts a `.md` file to `.docx` via Pandoc, extracting each Mermaid block, rendering it to PNG
with mermaid-cli, and embedding the image in place of the code.

## Scope — read before using this for client work

This produces a **plain** Word document: Pandoc's default styling, no HSO template, no branding.
That is the right output for an internal review copy, a working draft, or a document someone
outside the repo needs to comment on.

**Authority for client deliverable standards — read before any document leaves the building:**
[`hso-client-deliverable-standards.md`](../../../agent/wiki/sop/client-deliverables/hso-client-deliverable-standards.md).
Its §4 (Word document standards), §5 (version and document control), §6 (universal rules), and
especially **§7 (what may not leave the building)** govern any document that reaches a client,
regardless of which tool produced it. A `.docx` this skill generates is not exempt because it was
converted rather than authored. The summary here is a pointer — read the SOP before sharing output.

**Authority for producing branded client deliverables — read before building one:**
[`hso-engagement-deliverables`](../hso-engagement-deliverables/SKILL.md) is the single HSO
client-deliverable skill and governs branded PPTX and Word output on the corporate template. This
skill is for what it does not cover: fast, unbranded conversion of a markdown file that already
exists.

| Task | Primary authority |
|---|---|
| Standards any client-bound document must meet | [`hso-client-deliverable-standards.md`](../../../agent/wiki/sop/client-deliverables/hso-client-deliverable-standards.md) |
| Branded Word / PPTX deliverable on the HSO template | [`hso-engagement-deliverables`](../hso-engagement-deliverables/SKILL.md) |
| Quick unbranded `.docx` from an existing `.md` | this skill |
| Publishing deliverables out to a client repo | [`hso-client-publish`](../hso-client-publish/SKILL.md) |

## Prerequisites

| Tool | Required | Install |
|---|---|---|
| **Pandoc** | Always | `winget install --id JohnMacFarlane.Pandoc --accept-source-agreements --accept-package-agreements` |
| **Node.js** | Only for documents containing Mermaid | https://nodejs.org/ |
| **mermaid-cli** (`mmdc`) | Only for documents containing Mermaid | `npm install -g @mermaid-js/mermaid-cli` |

The script refreshes `PATH` from the machine and user environment on start, so a tool installed in
another shell moments earlier is picked up without reopening the terminal.

## Usage

```powershell
& "<skill-dir>/scripts/Convert-MdToDocx.ps1" -SourceFile "<path.md>" -OutputDocx "<path.docx>"
```

| Parameter | Description |
|---|---|
| `-SourceFile` | Source `.md`. Must exist. |
| `-OutputDocx` | Destination `.docx`. Its folder must exist. |
| `-KeepBuildDir` | Keep the temporary `_docx_build/` folder instead of removing it. |

## What it does

1. Validates the source exists, the output folder exists, and the destination is **not locked** —
   all before any rendering work.
2. Creates `_docx_build/diagrams/` beside the source.
3. Walks the markdown, matching both ` ```mermaid ` and `::: mermaid` fences.
4. Writes each block to a `.mmd` file and renders it to PNG via `mmdc` at 1600px, scale 2, white
   background.
5. Replaces each block with an image reference; a block that **fails** to render is left in the
   document as a fenced code block rather than dropped.
6. Converts to `.docx` with Pandoc, using `--resource-path` so the relative image paths resolve.
7. Removes the build folder — unless a diagram failed or `-KeepBuildDir` was passed, so the failing
   `.mmd` input survives for inspection.

## Failure behaviour

The script fails loudly and specifically. Each of these was verified:

| Condition | Result |
|---|---|
| Source file missing | Throws before any work |
| Output folder missing | Throws before any work |
| Output `.docx` open in Word | Throws immediately, naming the lock — not after minutes of rendering |
| Document has Mermaid but `mmdc` absent | Throws when the first diagram is reached, naming the install command |
| A single diagram fails to render | Warns, keeps that block as code, continues, keeps the build folder, reports which failed |
| Pandoc exits non-zero | Throws, keeps the build folder for diagnosis |
| Mermaid fence never closed | Throws, naming the diagram number |

## Notes

- **No auth, no network** beyond what `mmdc` does locally. Nothing to configure.
- **Encoding.** Temporary `.mmd` and `.md` files are written as UTF-8 **without** BOM via an explicit
  `UTF8Encoding($false)`. `Set-Content -Encoding UTF8` cannot be used here: it emits a BOM under
  Windows PowerShell 5.1 but not under 7 ([ADR 0058](../../../agent/wiki/decisions/0058-powershell-7-run-host-and-behavioral-parity.md)
  — syntax parity is not behavioural parity), and a BOM on a `.mmd` file makes `mmdc` fail to parse
  the first directive.
- **SVG diagrams** exported from draw.io should be converted to PNG first — Word and Azure DevOps
  strip `<foreignObject>` from SVG.
- The `:::` fence style is an Azure DevOps convention; the script accepts both it and standard
  triple-backtick fences.

## Changelog

See **[CHANGELOG.md](CHANGELOG.md)** (per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md)).
