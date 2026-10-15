"""
HSO Treemap diagram template.

Copy this file into <engagement-repo>/agent/work/deliverables/diagrams/_generators/
and rename to an engagement-agnostic slug. Edit only the `# Data` block.

Default: a 2-level hierarchy — three top-level categories with three subcategories
each. One color per top-level branch (HSO categorical palette, in order). Replace
the data block with the real hierarchy your story needs.

Run: python <this-file>.py
"""
from pathlib import Path
import plotly.graph_objects as go

# ============================================================
# Data
# ============================================================
# Each row: (label, parent, value). Top-level rows have parent="".
data = [
    ("Category Alpha",      "",                 0),   # value computed from children when branchvalues="total"
    ("Category Beta",       "",                 0),
    ("Category Gamma",      "",                 0),

    ("Alpha · Item 1",      "Category Alpha",  40),
    ("Alpha · Item 2",      "Category Alpha",  25),
    ("Alpha · Item 3",      "Category Alpha",  15),

    ("Beta · Item 1",       "Category Beta",   30),
    ("Beta · Item 2",       "Category Beta",   20),
    ("Beta · Item 3",       "Category Beta",   10),

    ("Gamma · Item 1",      "Category Gamma",  20),
    ("Gamma · Item 2",      "Category Gamma",  15),
    ("Gamma · Item 3",      "Category Gamma",   8),
]

TITLE = "Replace with one declarative claim about the breakdown"
SUBTITLE = "Illustrative hierarchy — replace with real values; cite source if real"

# ============================================================
# Palette
# ============================================================
HSO_DARK_BLUE = "#00395F"
HSO_BLUEGREEN = "#079FC3"
HSO_GREEN     = "#00B294"
HSO_SALMON    = "#F1554B"
HSO_MIMOSA    = "#F2B949"
HSO_STEEL     = "#7F9CAF"
HSO_CANVAS    = "#FDFCF7"


def apply_hso_layout(fig, title, subtitle="", width=1400, height=780):
    title_html = f"<b>{title}</b>"
    if subtitle:
        title_html += f"<br><span style='font-size:14px; color:{HSO_STEEL};'>{subtitle}</span>"
    fig.update_layout(
        template="none",
        title=dict(text=title_html, x=0.5, xanchor="center",
                   font=dict(family="Segoe UI, sans-serif", size=20, color=HSO_DARK_BLUE)),
        font=dict(family="Segoe UI, sans-serif", size=13, color=HSO_DARK_BLUE),
        paper_bgcolor=HSO_CANVAS, plot_bgcolor=HSO_CANVAS,
        width=width, height=height,
        margin=dict(l=40, r=40, t=110, b=40),
    )

# ============================================================
# Treemap
# ============================================================
labels   = [d[0] for d in data]
parents  = [d[1] for d in data]
values   = [d[2] for d in data]

# One color per top-level branch (HSO categorical palette, in order).
top_level_colors = {
    "Category Alpha": HSO_BLUEGREEN,
    "Category Beta":  HSO_GREEN,
    "Category Gamma": HSO_SALMON,
}
colors = []
for label, parent, _ in data:
    if parent == "":
        colors.append(top_level_colors.get(label, HSO_STEEL))
    else:
        colors.append(top_level_colors.get(parent, HSO_STEEL))

fig = go.Figure(go.Treemap(
    labels=labels, parents=parents, values=values,
    branchvalues="total",
    marker=dict(colors=colors, line=dict(color=HSO_DARK_BLUE, width=1.5)),
    textfont=dict(family="Segoe UI, sans-serif", size=14, color="#FFFFFF"),
    pathbar=dict(visible=False),
))

apply_hso_layout(fig, TITLE, SUBTITLE)

# ============================================================
# Output
# ============================================================
out = Path(__file__).resolve().with_suffix("")
fig.write_image(str(out.with_suffix(".svg")), format="svg", width=1400, height=780)
fig.write_image(str(out.with_suffix(".png")), format="png", width=2400, height=1340, scale=1)
print(f"SVG: {out.with_suffix('.svg')}")
print(f"PNG: {out.with_suffix('.png')}")
