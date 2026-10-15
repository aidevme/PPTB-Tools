# PPTX Technical Implementation (Solution Blueprint)

python-pptx execution detail for the **Solution Blueprint Presentation** type. Apply the *standards* from
[HSO Client Deliverable Standards](../../../agent/wiki/sop/client-deliverables/hso-client-deliverable-standards.md)
§2–3 (brand, deck layout) — this file is the *how*.

## Built-in HSO brand (fallback when no template configured)

```python
NAVY="00395F"; TEAL="079FC3"; DKGRAY="333333"; MDGRAY="737373"; LTGRAY="F2F2F2"; WHITE="FFFFFF"; NEARBLK="171717"
FONT="Segoe UI"
```

## Build on the HSO master template — not Blank layouts

**The #1 PPTX formatting defect is building on `Blank` layouts with manual textboxes** instead of the branded
HSO master. A deck whose slides are all layout `Blank` has lost the HSO cover, dividers, and content layouts —
it only *looks* on-brand because fonts/colors were hand-set. Always start from:

1. **The bundled HSO deck** (zero-config default): `assets/HSO_PPT_Lite_2026.potx` — 13 branded layouts,
   Segoe UI. Ships with the skill; no per-machine setup.
2. **A supplied sample / the Full deck** (`CLAUDE.local.md` → Branding Resources → `Local PPT Sample Path` or
   `Local PPT Template Path`), used as a **format donor only** (SOP §6a): duplicate its branded slides/layouts,
   then **replace every text/table with this project's content or `[PLACEHOLDER: …]`**. Never leave the sample's
   client text, names, or logos-as-content. Use the **Full** deck (11.5 MB, per-machine) only when
   corporate/credentials/industry layouts are needed.
3. Only if none is available: the built-in brand as a *fallback*, and say so in the run summary — the output
   will be brand-approximate, not template-faithful.

Verify after building: no content slide should report layout `Blank`; titles/dividers should map to the named
HSO layouts. If they read `Blank`, you built textboxes on empty slides — rebuild from the template.

## Resolve layouts by NAME, not index

Layout **indices differ across templates and versions** (Lite vs Full; the cover is layout 1 in Lite but 12 in
the 2026 Full). **Look layouts up by `cSld` name**, never by a hard-coded index:

```python
def layout(prs, name):
    for m in prs.slide_masters:
        for lay in m.slide_layouts:
            if lay.name == name:
                return lay
    raise KeyError(name)
```

**Lite 2026 (bundled default) — name map:**

| Slide type | Layout name (Lite) |
|-----------|--------------------|
| Cover | `MAIN Template A` |
| Content (title only) | `1_CONTENT Main Header Only` |
| Two-column | `CONTENT Main 2 Column with Headings` |
| Section divider | `CONTENT Section Header BLUE` (or Green / Salmon / Caramel) |
| Closing | `CONTENT Closing Slide` |

**Full 2026 (per-machine)** carries the same content/section names plus `MAIN Template E` (cover) and the
About-HSO / credentials / industry layouts. Because it resolves by name, the same code targets either deck.

```python
# 1_CONTENT Main Header Only — content box (both decks)
CX, CY, CW, CH = 0.61, 0.90, 12.11, 6.25   # inches
```

## Per-project workspace (optional)

For a large one-off deck you may still stage scripts in `agent/work/deliverables/pptx-workspace/`
(`rearrange.py` to duplicate template slides → `working.pptx` → `fill_content.py` to populate) — but resolve
layouts by name and start from the bundled/Full template, not a `Blank`-layout deck.

## fit_font — dynamic body sizing (never hard-code body sizes)

```python
import math
def fit_font(items, box_w_in, box_h_in, prefer=20, min_size=11):
    avg_len = max((len(i) for i in items), default=40); n = len(items)
    for size in range(prefer, min_size - 1, -1):
        chars_per_line = (box_w_in * 72) / (size * 0.52)
        lines_per_item = max(1, math.ceil(avg_len / chars_per_line))
        if n * (lines_per_item * size * 1.3 + 6) <= box_h_in * 72:
            return size
    return min_size
```

## Bullets / tables / two-column

```python
def bullets(slide, items, x, y, w, h, size=None):
    size = size or fit_font(items, w, h)
    tf = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)).text_frame
    tf.word_wrap = True
    # per item: add paragraph at `size`; bold prefix pattern "Bold: rest" -> bold the "Bold: " run
```

- **Tables:** header row fixed 0.42" height; data rows split the remainder; cell size via `fit_font` on the
  widest column. Navy header row, alternating white/light-gray data rows.
- **Two-column:** the OBJECT placeholders (idx 2, 4) MUST be removed before adding text boxes or they overlap:

```python
def two_col(slide, left_head, left_items, right_head, right_items, size=None):
    set_ph(slide, 1, left_head,  size=14, bold=True, color=NAVY)
    set_ph(slide, 3, right_head, size=14, bold=True, color=NAVY)
    for ph_idx, items, default_x in [(2, left_items, 0.63), (4, right_items, 6.82)]:
        s = ph(slide, ph_idx)
        if s:
            x, y, h, w = s.left.inches, s.top.inches, s.height.inches, s.width.inches
            s._element.getparent().remove(s._element)
        else:
            x, y, h, w = default_x, 1.70, 5.00, 5.91
        bullets(slide, items, x, y, w, h, size=size or fit_font(items, w, h))
```

**Rules:** 4px teal accent bar under every content title; no body on dividers; ≤6 bullets/slide; tables ≤8 cols;
use only the reviewed content — never fabricate.
