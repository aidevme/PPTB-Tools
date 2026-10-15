# Conceptual ERD Style — Excalidraw for Client-Facing Diagrams

A subset of the Excalidraw skill optimized for **conceptual ERD diagrams** that appear in client-facing slide decks (presales demos, technical demo decks, architecture overviews). These are NOT workshop sketches — they're polished single-screen explainers of a Dataverse data model.

Use this reference when the goal is "explain a 6–8 entity slice of the data model on one slide" rather than "capture a brainstorm."

Output style emerged after producing four conceptual diagrams (`property_ops`, `billing_royalty`, `franchisee`, `homewatch`) for a Field Service presales engagement. See [examples/franchisee_conceptual.svg](../examples/franchisee_conceptual.svg) and [examples/billing_royalty_conceptual.svg](../examples/billing_royalty_conceptual.svg) for reference renders.

---

## Process — ASCII-first, JSON-second

**Rule: sketch the layout as ASCII text before writing any JSON.** Iterating on ASCII takes seconds; iterating on JSON + re-render takes minutes. Get alignment with the user on:

- Which boxes appear (cap at 7–8 — beyond that, split the diagram)
- Row / column arrangement
- Which relationships are shown, with verb labels
- Which arrows are solid vs dashed
- Which arrows are primary (straight) vs secondary (L-shape)

Only after the ASCII is approved, write the JSON. This rule emerged after three failed JSON revisions in a row on the first conceptual ERD.

Example ASCII sketch:

```
[ Subscription Plan ]                                    [ Royalty Scheme ]
        | defines (dashed)                                       | defines (dashed)
        v                                                        v
[ Customer Subscription ] -emits-> [ Invoice ] -fires-> [ Billing Event ] -contributes-> [ Royalty Calc ]
                                                              |
                                                              | charged by
                                                              v
                                                       [ Payment Transaction ]
```

---

## Visual Grammar

### Boxes — uniform sizing, color for emphasis

| Rule | Reason |
|---|---|
| All boxes same dimensions (300 × 110) | Uneven sizes read as "unfinished." Use color for emphasis, not size. |
| 2px stroke, color `#00395F` (navy) | HSO canonical default stroke. |
| Fill: `solid` — **never** `hachure` for client-facing diagrams | Hachure reads as "sketchy/unfinished" in a deck. (Hachure is fine for workshop-mode diagrams; not here.) |
| **Anchor box**: navy fill (`#00395F`) + white text | The single most-emphasized entity per diagram (e.g., `Customer Subscription`, `Franchisee`). One per diagram. |
| **Accent box**: bluegreen fill (`#079FC3`) + white text | Secondary focal point (e.g., `Billing Event`, `Bookable Resource`). At most one or two. |
| All other boxes: white fill (`#FFFFFF`) + navy text | Supporting entities. |
| First line of box text: **ALL CAPS** | Table name stands out. Matches anchor format. |
| Lines 2–3: mixed case, same `fontSize` | Short descriptive tagline + differentiator. |
| Body `fontSize: 16`, `fontFamily: 1` (Virgil) | Tested to fit 3 lines cleanly in 110 px height. |

### Grid — uniform column centers

- For 4 columns in a 1500-px canvas: `x = 180, 560, 940, 1320` (center-to-center 380, gap 80). Easy to extend to 3 or 5 columns by adjusting the step.
- For 3 columns in a 1100-px canvas: `x = 180, 560, 940`.
- Top row `y = 40`. Row spacing 280 (= 110 box + 170 for labels and L-shape routing).
- **Compute `box_x` from column center**: `box_x = col_center - box_width/2`. Avoid eyeballing.

### Arrows — orthogonal only

Three allowed shapes:

1. **Straight horizontal** — `points: [[0,0],[dx,0]]`. Same-row relationships.
2. **Straight vertical** — `points: [[0,0],[0,dy]]`. Same-column relationships.
3. **L-shape** (3 segments) — `points: [[0,0],[0,dy1],[dx,dy1],[dx,dy2]]`. Different row AND different column.

**Never use diagonal arrows.** Readers parse orthogonal routing as "intentional"; diagonals as "messy."

For L-shapes, use explicit `points` and **omit `startBinding` / `endBinding`** — bindings cause Excalidraw to auto-reroute and may undo the carefully chosen path. Straight arrows can keep their bindings.

**Solid arrows** (stroke `#00395F`): primary lifecycle, ownership, or physical attachment (`Homeowner → Property`, `Quote → Agreement`, `Invoice → Billing Event`).

**Dashed arrows** (stroke `#7F9CAF`): reference relationships — lookups, "also-referenced-on" (`Customer Asset → Agreement`, `Subscription Plan → Customer Subscription`). Visually subordinate.

### Arrow labels

- **Position above the horizontal segment**, not on it. `label_y = arrow_y - 22 to -24`. Background `transparent` — no masking needed since label sits in a clear zone above the line.
- `fontSize: 13` (smaller than body 16). Creates hierarchy.
- **Short verbs**. "fires" beats "fires off" when it has to fit an 80-px gap. Keep labels under ~12 chars.
- **Vertical arrow exception**: label sits BESIDE (right of) the arrow, not above. Use a solid `#FDFCF7` background to mask any cross-traffic.
- Two L-shapes can share a y-range if their x-ranges don't overlap (which they naturally won't if they go in opposite directions).

---

## What to Avoid

| Anti-pattern | Why it hurts |
|---|---|
| `fillStyle: "hachure"` on entity boxes | Reads as "sketchy/unfinished" in a deck. Use `solid` for conceptual ERDs. |
| Diagonal arrows | Always use L-shape instead. |
| Mixing box sizes for emphasis | Emphasis comes from color. Varying sizes makes the diagram feel unfinished. |
| Slide title or eyebrow text baked into the diagram | The slide provides those; baking them in double-labels and fights with reveal.js scaling. |
| Decorative banners (stripes, legend strips) | Clutter. Talking points belong in slide body or notes. |
| Labels centered on arrow with masking background (horizontal case) | Obscures arrowheads; reader loses directional cue. Position above instead. |
| More than 7–8 boxes | Loses the conceptual-diagram advantage. Split into multiple diagrams. |
| `roughness: 0` | Defeats the Excalidraw aesthetic — looks like half-broken CAD. Keep `roughness: 1`. |
| Binding L-shape arrows to start/end boxes | Excalidraw auto-reroutes and erases the L-path. Drop bindings for L-shapes; use explicit `points`. |

---

## Render Workflow (SVG → PNG for Slides)

1. **Author the `.excalidraw` JSON** — see the templates in `templates/` or copy the structure from `examples/franchisee_conceptual.excalidraw`.

2. **Render to SVG**:
   ```bash
   node .claude/skills/hso-diagram-excalidraw/scripts/render-excalidraw.mjs \
     <path>/<name>.excalidraw
   ```

3. **Convert to PNG at 2400-px width** for slide embedding:
   ```bash
   NODE_PATH="$(npm root -g)" node -e "
     const fs = require('fs'), sharp = require('sharp');
     const svg = fs.readFileSync('<path>/<name>.svg');
     sharp(svg, { density: 300 }).resize({ width: 2400 }).png()
       .toFile('<path>/<name>.png')
       .then(r => console.log('PNG:', r.width + 'x' + r.height));
   "
   ```

4. **Always open the PNG and inspect visually.** JSON coordinates can be correct and the result still be wrong (labels overlapping arrowheads, arrows hitting the wrong edge, etc.).

The Virgil-font-face warning from the renderer is cosmetic — the SVG still writes correctly.

---

## HSO Palette — Conceptual ERD Subset

| Role | Hex | Used for |
|---|---|---|
| Primary stroke | `#00395F` | All box outlines, primary arrows, anchor box fill |
| Accent fill | `#079FC3` | Secondary focal box |
| White | `#FFFFFF` | Supporting box fills, text on navy/bluegreen |
| Muted stroke | `#7F9CAF` | Dashed reference arrows |
| Canvas | `#FDFCF7` | `viewBackgroundColor` in `appState`; also label-mask fill |
| Text on dark fill | `#FFFFFF` | Anchor / accent box text |
| Text on white fill | `#00395F` | Supporting box text |

---

## Relationship Vocabulary

Use short, active verbs. Past-participle (`covered by`, `installed on`) for passive relationships; present-tense (`generates`, `templates`) for active ones. Cap at ~12 chars to fit an 80-px gap.

| Verb | Meaning | Example |
|---|---|---|
| `resident at` | Contact ↔ Account (person at place) | Homeowner → Property |
| `installed on` | Asset ↔ Property (physical attachment) | Customer Asset → Property |
| `for property` | Quote/Order ↔ Property (contextual ref) | Quote → Property |
| `covered by` | Transactional record ↔ Agreement | Customer Asset → Agreement |
| `serviced on` | Asset ↔ Work Order | Customer Asset → Work Order |
| `materializes` | Quote → Subscription (contract creation) | Quote → Customer Subscription |
| `generates` | Agreement → Work Order (spawns) | Subscription → Work Order |
| `templates` | Incident Type → Work Order (pre-fills) | Incident Type → Work Order |
| `emits` | Subscription → Invoice | Customer Subscription → Invoice |
| `fires` | Invoice → Billing Event | Invoice → Billing Event |
| `contributes` | Billing Event → Royalty | Billing Event → Royalty Calc |
| `charged by` | Billing Event → Payment | Billing Event → Payment Transaction |
| `defines` | Plan → Instance | Subscription Plan → Customer Subscription |
| `contains` | Parent → Child (org hierarchy) | Business Unit → System User |

---

## Cost Reference

First conceptual diagram took ~1 hour of iteration (3 visual revisions, 2 layout, 1 text). Subsequent diagrams in the same set take 15–20 minutes each when ASCII-first and this guide are followed.
