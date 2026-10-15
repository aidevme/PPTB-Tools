---
title: "Reference architecture diagram - canonical examples"
type: reference
status: active
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [diagrams, examples]
sources: []
created: 2026-04-27
updated: 2026-04-27
---

# Reference Architecture Diagram - Canonical Examples

The canonical reference implementations of this skill live in the originating engagement repo (project tier), NOT in this shared skill folder. The two validated layouts are:

- **LTR (left-to-right, personas on the left, platform center, externals right)** - in the originating project at `agent/work/deliverables/diagrams/reference_architecture.svg` plus its rendered `reference_architecture.png`.
- **TTB (top-to-bottom, audiences on top, AWS left / platform center / externals right)** - in the originating project at `agent/work/deliverables/diagrams/reference_architecture_v2.svg` plus its rendered `reference_architecture_v2.png`.

These are NOT generic templates. They contain client-specific persona names, brand counts, component lists, and integration partners. Copy-and-edit will leak engagement-specific data into a new diagram.

## How to use them as references

When starting a new engagement's reference architecture:

1. Open the canonical SVG with the closest layout match (LTR or TTB) in the originating engagement repo.
2. Use it as a SHAPE reference - proportions, spacing, ribbon styling, card heights, arrow angles.
3. Do NOT copy the file contents into the new engagement.
4. Start from `templates/ttb-skeleton.svg` or `templates/ltr-skeleton.svg` in this shared skill instead.
5. Inline the `templates/defs-block.svg` defs verbatim, then fill the zones using:
   - `references/visual-grammar.md` for class roles and colors,
   - `references/layout-ttb.md` or `layout-ltr.md` for coordinates,
   - `references/icon-catalog.md` for glyph and vendor icon picks.

## Why no shared example SVGs

Two reasons:

1. Every working SVG includes specific persona names, specific component lists, and specific integration partners. None of those should ship in a shared skill.
2. Stripping a working SVG down to a generic example produces a diagram that is no longer faithful to the layouts that actually shipped (because the proportions tune themselves around the specific content). A skeleton with placeholder comments (which IS shipped, in `templates/`) is a more honest starting point.

If a future engagement adds a third validated layout, the canonical implementation lives in that engagement's `agent/work/deliverables/diagrams/` and a pointer is added here.
