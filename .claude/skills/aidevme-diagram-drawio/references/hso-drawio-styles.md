# HSO Draw.io Style Reference

Canonical HSO palette and copy-paste `style=` fragments for draw.io `mxCell` elements. All diagrams produced by `hso-diagram-drawio` MUST use these values and nothing else.

## Palette (source: HSO Brand Manual v3.0 — aligned with `hso-revealjs-presentation`)

| Name | Hex | Role |
|---|---|---|
| `hso-dark-blue` | `#00395F` | Primary. Headers, primary entities, title bars. |
| `hso-bluegreen` | `#079FC3` | Default accent. Most decks/diagrams. |
| `hso-green` | `#00B294` | Success / opportunity emphasis. |
| `hso-salmon` | `#F1554B` | Warning / risk / attention. |
| `hso-mimosa` | `#F2B949` | Caution / contrast. |
| `hso-steel` | `#7F9CAF` | Secondary strokes, muted emphasis. |
| `hso-tagline` | `#4A4A4A` | Muted dark text. |
| `hso-text` | `#505050` | Body text. |
| `hso-light-grey` | `#E3E3E3` | Dividers, subtle fills. |
| `hso-web-grey` | `#ECEFF3` | Backdrop panels, swim lane bands. |
| `white` | `#FFFFFF` | Entity body, text on dark fills. |

Each diagram picks **ONE** dominant accent (default `hso-bluegreen`) and uses it consistently. Do NOT introduce colors outside this palette.

## Drawio style fragments

### Title bar (top-left of every diagram)
```
rounded=0;whiteSpace=wrap;html=1;fillColor=#00395F;strokeColor=#00395F;fontColor=#FFFFFF;fontSize=16;fontStyle=1;fontFamily=Segoe UI;align=left;spacingLeft=12;
```

### Entity header (ERD — table name band)
```
rounded=0;whiteSpace=wrap;html=1;fillColor=#00395F;strokeColor=#00395F;fontColor=#FFFFFF;fontSize=12;fontStyle=1;fontFamily=Segoe UI;align=left;spacingLeft=8;
```

### Entity body (ERD — field list)
```
rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#00395F;fontColor=#505050;fontSize=11;fontFamily=Segoe UI;align=left;verticalAlign=top;spacingLeft=8;spacingTop=6;
```

### Field row (ERD — inside entity)
```
text;html=1;strokeColor=none;fillColor=none;fontColor=#505050;fontSize=11;fontFamily=Segoe UI;align=left;verticalAlign=middle;spacingLeft=8;
```

### Primary key marker (append to field row)
Prefix the field label with `🔑` or `[PK]`. Avoid emojis in client-facing diagrams — use `[PK]` / `[FK]` instead.

### Component box — primary accent
```
rounded=1;whiteSpace=wrap;html=1;fillColor=#079FC3;strokeColor=#079FC3;fontColor=#FFFFFF;fontSize=12;fontStyle=1;fontFamily=Segoe UI;arcSize=6;
```

### Component box — neutral / outlined
```
rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#00395F;fontColor=#00395F;fontSize=12;fontStyle=1;fontFamily=Segoe UI;arcSize=6;
```

### Component box — muted backdrop (group / layer container)
```
rounded=0;whiteSpace=wrap;html=1;fillColor=#ECEFF3;strokeColor=#7F9CAF;fontColor=#00395F;fontSize=13;fontStyle=1;fontFamily=Segoe UI;verticalAlign=top;align=left;spacingLeft=10;spacingTop=6;dashed=0;
```

### External actor (system context)
```
shape=umlActor;html=1;strokeColor=#00395F;fillColor=#FFFFFF;fontColor=#00395F;fontSize=11;fontFamily=Segoe UI;
```

### Lifeline (sequence diagram)
```
shape=umlLifeline;perimeter=lifelinePerimeter;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#00395F;fontColor=#00395F;fontSize=12;fontStyle=1;fontFamily=Segoe UI;
```

### Note / callout
```
shape=note;whiteSpace=wrap;html=1;fillColor=#F2B949;strokeColor=#F2B949;fontColor=#00395F;fontSize=11;fontFamily=Segoe UI;size=14;
```

### Success pill
```
rounded=1;whiteSpace=wrap;html=1;fillColor=#00B294;strokeColor=#00B294;fontColor=#FFFFFF;fontSize=11;fontStyle=1;fontFamily=Segoe UI;arcSize=40;
```

### Risk / warning pill
```
rounded=1;whiteSpace=wrap;html=1;fillColor=#F1554B;strokeColor=#F1554B;fontColor=#FFFFFF;fontSize=11;fontStyle=1;fontFamily=Segoe UI;arcSize=40;
```

## Edge styles

### Orthogonal (architecture, ERD)
```
edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;jettySize=auto;orthogonalLoop=1;strokeColor=#00395F;fontColor=#00395F;fontFamily=Segoe UI;fontSize=10;endArrow=classic;endFill=1;
```

### Straight (sequence messages)
```
html=1;strokeColor=#00395F;fontColor=#00395F;fontFamily=Segoe UI;fontSize=10;endArrow=classic;endFill=1;
```

### Dashed (async / deferred)
```
edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#7F9CAF;fontColor=#505050;dashed=1;endArrow=open;
```

### ERD cardinality (1-to-many)
Append to edge style: `startArrow=ERone;startFill=0;endArrow=ERmany;endFill=0;`

### ERD cardinality (many-to-many)
Append: `startArrow=ERmany;startFill=0;endArrow=ERmany;endFill=0;`

## Typography

- **Family:** `Segoe UI` to match HSO PPT and reveal.js decks. Fall back to system default if unavailable.
- **Sizes:** Title 16 · Entity header 12 · Body 11 · Edge labels 10.
- **Weight:** Titles and headers `fontStyle=1` (bold). Body text regular.

## Coordinates & layout

- Grid spacing: **20px**. All positions on multiples of 20.
- Entity width: **200px** default. Architecture components **160–220px**.
- Row height: **26px** per field in ERD. **40px** per component in architecture.
- Layer panels: **20px** padding from children inside `#ECEFF3` backdrops.
