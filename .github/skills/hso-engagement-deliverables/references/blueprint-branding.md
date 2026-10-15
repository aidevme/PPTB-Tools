# Solution Blueprint — Branding & Formatting Rules

Strict formatting rules for all Solution Blueprint presentations. Apply exactly as specified — no exceptions without user approval.

## Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| HSO Navy | `#00395F` | Cover/divider backgrounds · Slide titles · Table headers |
| HSO Teal | `#079FC3` | 4px accent bar under content titles · Hyperlinks · Callout highlights |
| Dark Gray | `#333333` | Body text · Table body text |
| Medium Gray | `#737373` | Footnotes · Secondary labels · Metadata |
| Light Gray | `#F2F2F2` | Alternate table rows · Subtle backgrounds |
| White | `#FFFFFF` | Slide backgrounds · Text on dark slides |
| Near-Black | `#171717` | Cover and section dividers — alternate to navy for dark-background slides |

```python
# python-pptx color reference
NAVY    = RGBColor(0x00, 0x39, 0x5F)   # HSO Navy
TEAL    = RGBColor(0x07, 0x9F, 0xC3)   # HSO Teal
DKGRAY  = RGBColor(0x33, 0x33, 0x33)   # Body text
MDGRAY  = RGBColor(0x73, 0x73, 0x73)   # Footnotes
LTGRAY  = RGBColor(0xF2, 0xF2, 0xF2)   # Alt table rows
WHITE   = RGBColor(0xFF, 0xFF, 0xFF)   # Backgrounds
NEARBLK = RGBColor(0x17, 0x17, 0x17)   # Dark backgrounds (alternate to NAVY)
```

## Typography

All text uses **Segoe UI** — no other fonts.

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Cover title | 40pt | Bold | White `#FFFFFF` |
| Cover subtitle / date | 18pt | Regular | White `#FFFFFF` |
| Section divider title | 36pt | Bold | White `#FFFFFF` |
| Slide title (content slides) | 24pt | Semibold | Navy `#00395F` |
| Subtitle / section label | 16pt | Semibold | Navy `#00395F` |
| Body bullets | 12pt | Regular | Dark gray `#333333` |
| Table header text | 11pt | Semibold | White `#FFFFFF` |
| Table body text | 11pt | Regular | Dark gray `#333333` |
| Footnote / annotation | 10pt | Regular | Medium gray `#737373` |

**Font size rule:** Body content uses only 16 / 12 / 10pt. Never mix sizes within a single slide's content area.

## Slide Dimensions

**13.33" × 7.50"** (widescreen 16:9) — standard for all slides.

```python
from pptx.util import Inches
prs.slide_width  = Inches(13.33)
prs.slide_height = Inches(7.50)
```

## Slide Layouts

### Cover Slide
- Background: Full-bleed navy `#00395F`
- Title: 40pt Bold White, horizontally centered
- Subtitle / phase: 18pt Regular White, below title
- Date and presenter: 18pt Regular White (80% opacity effect via color lightening)
- No accent bar
- HSO logo if template includes it

### Section Divider Slide
- Background: Full-bleed navy `#00395F`
- Title: 36pt Bold White, vertically and horizontally centered
- Thin teal `#079FC3` line (2pt) immediately below the title text
- **No body text** — title only

```python
# Section divider background
background = slide.background
fill = background.fill
fill.solid()
fill.fore_color.rgb = NAVY

# Teal accent line under title
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
line = slide.shapes.add_shape(
    MSO_SHAPE_TYPE.RECTANGLE,
    Inches(1.0), Inches(4.2),    # x, y (adjust to be just below title)
    Inches(11.33), Pt(2)          # width, height
)
line.fill.solid()
line.fill.fore_color.rgb = TEAL
line.line.fill.background()
```

### Content Slide — Text
- Background: White
- Title: 24pt Semibold Navy, left-aligned
- Teal accent bar: 4px height, full width below title
- Body: 12pt Regular Dark gray, bulleted list
- Max 6 bullet points

### Content Slide — Table
- Background: White
- Title: 24pt Semibold Navy + 4px teal bar
- Table: Navy `#00395F` header row (white text), alternating white / light gray `#F2F2F2` data rows
- Max 8 columns

### Content Slide — Two Column
- Background: White
- Title: 24pt Semibold Navy + 4px teal bar
- Two equal-width columns below title

## Universal Rules

1. **Every content slide** has a **4px teal `#079FC3` accent bar** immediately below the slide title
2. **Section dividers** contain no body text — title only
3. **Maximum 6 bullet points** per content slide — split into two slides if more needed
4. **Tables**: navy header row, alternating white / light gray data rows, max 8 columns
5. **No more than 3 distinct font sizes** on any single slide
6. **No text boxes** used as decorative elements — structure content as bullets or tables
7. **Consistent left margin**: content left edge at 0.5" from slide left

## python-pptx Helper Reference

### Add Title + Teal Accent Bar

```python
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor

def add_content_title(slide, title_text):
    # Title text box
    txBox = slide.shapes.add_textbox(
        Inches(0.5), Inches(0.4),   # x, y
        Inches(12.33), Inches(0.7)  # width, height
    )
    tf = txBox.text_frame
    tf.text = title_text
    p = tf.paragraphs[0]
    p.runs[0].font.name = "Segoe UI"
    p.runs[0].font.size = Pt(24)
    p.runs[0].font.bold = True
    p.runs[0].font.color.rgb = RGBColor(0x00, 0x39, 0x5F)

    # Teal accent bar (4px = ~50,800 EMU)
    bar = slide.shapes.add_shape(
        1,  # MSO_SHAPE_TYPE.RECTANGLE
        Inches(0.5), Inches(1.15),
        Inches(12.33), Emu(57600)   # ~4px at 96dpi
    )
    bar.fill.solid()
    bar.fill.fore_color.rgb = RGBColor(0x07, 0x9F, 0xC3)
    bar.line.fill.background()
    return bar
```

### Add Bulleted Body Text

```python
def add_body_text(slide, bullets, left=0.5, top=1.3, width=12.33, height=5.5):
    txBox = slide.shapes.add_textbox(
        Inches(left), Inches(top),
        Inches(width), Inches(height)
    )
    tf = txBox.text_frame
    tf.word_wrap = True
    for i, bullet in enumerate(bullets):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = bullet
        p.runs[0].font.name = "Segoe UI"
        p.runs[0].font.size = Pt(12)
        p.runs[0].font.color.rgb = RGBColor(0x33, 0x33, 0x33)
        p.level = 0
```

### Add Navy Table

```python
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

def add_navy_table(slide, headers, rows, left=0.5, top=1.3):
    cols = len(headers)
    table = slide.shapes.add_table(
        len(rows) + 1, cols,
        Inches(left), Inches(top),
        Inches(12.33), Inches(0.4 * (len(rows) + 1))
    ).table

    # Header row
    for j, h in enumerate(headers):
        cell = table.cell(0, j)
        cell.text = h
        cell.fill.solid()
        cell.fill.fore_color.rgb = RGBColor(0x00, 0x39, 0x5F)
        run = cell.text_frame.paragraphs[0].runs[0]
        run.font.name = "Segoe UI"
        run.font.size = Pt(11)
        run.font.bold = True
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    # Data rows (alternating white / light gray)
    for i, row in enumerate(rows):
        bg = RGBColor(0xFF, 0xFF, 0xFF) if i % 2 == 0 else RGBColor(0xF2, 0xF2, 0xF2)
        for j, val in enumerate(row):
            cell = table.cell(i + 1, j)
            cell.text = str(val)
            cell.fill.solid()
            cell.fill.fore_color.rgb = bg
            run = cell.text_frame.paragraphs[0].runs[0]
            run.font.name = "Segoe UI"
            run.font.size = Pt(11)
            run.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
```
