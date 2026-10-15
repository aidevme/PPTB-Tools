# HSO Excalidraw Style Reference

Canonical HSO palette and copy-paste JSON fragments for `.excalidraw` elements. Mirrors the drawio palette so diagrams look like one family.

## Palette (source: HSO Brand Manual v3.0)

| Name | Hex | Role |
|---|---|---|
| `hso-dark-blue` | `#00395F` | **Default stroke for everything.** Also primary fill for "anchor" elements. |
| `hso-bluegreen` | `#079FC3` | Default accent fill. |
| `hso-green` | `#00B294` | Success / opportunity / AI components. |
| `hso-salmon` | `#F1554B` | Warning / risk / attention. |
| `hso-mimosa` | `#F2B949` | Caution / external systems. |
| `hso-steel` | `#7F9CAF` | Muted / secondary strokes, dashed connectors. |
| `hso-light-grey` | `#E3E3E3` | Subtle fills, background clusters. |
| `hso-web-grey` | `#ECEFF3` | Backdrop panels, grouping areas. |
| `white` | `#FFFFFF` | Neutral element body. |
| `hso-canvas` | `#FDFCF7` | `appState.viewBackgroundColor` for conceptual-ERD diagrams (warm off-white that matches HSO slide masters). Also useful as a label-mask fill behind text that crosses an arrow. |
| `hso-text` | `#505050` | Body text (rarely used — most text is `#00395F`). |

**Default stroke is ALWAYS `#00395F`.** Vary `backgroundColor` for emphasis, not `strokeColor`.

## Element recipes

### Primary accent box (hachure — the signature look)
```json
{
  "type": "rectangle",
  "strokeColor": "#00395F",
  "backgroundColor": "#079FC3",
  "fillStyle": "hachure",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100
}
```

### Neutral outlined box
```json
{
  "type": "rectangle",
  "strokeColor": "#00395F",
  "backgroundColor": "#FFFFFF",
  "fillStyle": "hachure",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100
}
```

### Backdrop / grouping panel (cross-hatch, subtle)
```json
{
  "type": "rectangle",
  "strokeColor": "#7F9CAF",
  "backgroundColor": "#ECEFF3",
  "fillStyle": "cross-hatch",
  "strokeWidth": 1,
  "strokeStyle": "dashed",
  "roughness": 1,
  "opacity": 60
}
```

### AI / success ellipse
```json
{
  "type": "ellipse",
  "strokeColor": "#00B294",
  "backgroundColor": "#00B294",
  "fillStyle": "hachure",
  "strokeWidth": 2,
  "roughness": 1,
  "opacity": 60
}
```

### Risk / attention callout
```json
{
  "type": "rectangle",
  "strokeColor": "#F1554B",
  "backgroundColor": "#F1554B",
  "fillStyle": "hachure",
  "strokeWidth": 2,
  "roughness": 1,
  "opacity": 40
}
```

### External system (mimosa)
```json
{
  "type": "rectangle",
  "strokeColor": "#00395F",
  "backgroundColor": "#F2B949",
  "fillStyle": "hachure",
  "strokeWidth": 2,
  "roughness": 1,
  "opacity": 100
}
```

### Text label
```json
{
  "type": "text",
  "strokeColor": "#00395F",
  "backgroundColor": "transparent",
  "fontSize": 16,
  "fontFamily": 3,
  "textAlign": "center",
  "verticalAlign": "middle",
  "roughness": 1
}
```

`fontFamily` values Excalidraw accepts: `1` = Virgil (classic sketchy), `2` = Helvetica, `3` = Cascadia, `4` = Segoe UI Emoji. Use **3** for most diagrams to keep readability; use **1** when maximum sketchiness is desired.

### Solid arrow (bound to two elements)
```json
{
  "type": "arrow",
  "strokeColor": "#00395F",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "startArrowhead": null,
  "endArrowhead": "arrow",
  "startBinding": { "elementId": "A", "focus": 0, "gap": 5 },
  "endBinding": { "elementId": "B", "focus": 0, "gap": 5 },
  "points": [[0, 0], [200, 0]]
}
```

### Dashed arrow (async / external)
```json
{
  "type": "arrow",
  "strokeColor": "#7F9CAF",
  "strokeWidth": 2,
  "strokeStyle": "dashed",
  "roughness": 1,
  "endArrowhead": "arrow"
}
```

## Required element fields

Every element needs: `id` (unique string), `type`, `x`, `y`, `width`, `height`, `angle` (usually 0), `strokeColor`, `backgroundColor`, `fillStyle`, `strokeWidth`, `strokeStyle`, `roughness`, `opacity`, `seed` (any integer for deterministic rendering), `version`, `versionNonce`, `isDeleted: false`, `groupIds: []`, `boundElements: []`, `updated` (any integer, e.g. 1).

For text elements, also include: `text`, `fontSize`, `fontFamily`, `textAlign`, `verticalAlign`, `baseline`.

For arrows, also include: `startArrowhead`, `endArrowhead`, `points` (array of [x,y] offsets from element origin), `startBinding` / `endBinding` (optional), `lastCommittedPoint: null`.

## Conceptual-ERD recipes (solid fills, client-facing)

Use these for conceptual ERD diagrams in client decks (per [`conceptual-erd-style.md`](conceptual-erd-style.md)). The `solid` fill replaces hachure here — hachure reads as "unfinished" in a presales deck.

### Anchor box (one per diagram — the most-emphasized entity)
```json
{
  "type": "rectangle",
  "width": 300, "height": 110,
  "strokeColor": "#00395F",
  "backgroundColor": "#00395F",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100
}
```
Text inside: `strokeColor: "#FFFFFF"`, `fontFamily: 1`, `fontSize: 16`, first line ALL CAPS.

### Accent box (at most one or two — secondary focal point)
```json
{
  "type": "rectangle",
  "width": 300, "height": 110,
  "strokeColor": "#00395F",
  "backgroundColor": "#079FC3",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "roughness": 1,
  "opacity": 100
}
```
Text inside: `strokeColor: "#FFFFFF"`.

### Supporting box (most boxes in the diagram)
```json
{
  "type": "rectangle",
  "width": 300, "height": 110,
  "strokeColor": "#00395F",
  "backgroundColor": "#FFFFFF",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "roughness": 1,
  "opacity": 100
}
```
Text inside: `strokeColor: "#00395F"`.

### Conceptual-ERD canvas
```json
"appState": { "viewBackgroundColor": "#FDFCF7", "gridSize": 20 }
```

### L-shape arrow (different row AND different column — DO NOT add bindings)
```json
{
  "type": "arrow",
  "strokeColor": "#00395F",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "endArrowhead": "arrow",
  "points": [[0,0],[0,40],[280,40],[280,80]]
}
```
Bindings on L-shapes cause Excalidraw to auto-reroute the path; explicit `points` without bindings keep the L intact.

### Arrow label (above horizontal arrow segment, transparent background)
```json
{
  "type": "text",
  "strokeColor": "#00395F",
  "backgroundColor": "transparent",
  "fontSize": 13,
  "fontFamily": 1,
  "textAlign": "center"
}
```
For labels beside a vertical arrow that crosses other elements, use `"backgroundColor": "#FDFCF7"` to mask cross-traffic.

## Roughness guidance

- `0` = mechanical/CAD — defeats the purpose. Don't use.
- `1` = tidy hand-drawn. **Use this for all HSO diagrams.**
- `2` = scribbly/cartoon. Too chaotic for HSO branding.
