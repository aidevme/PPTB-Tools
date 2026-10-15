"""
HSO Sankey diagram template.

Copy this file into <engagement-repo>/agent/work/deliverables/diagrams/_generators/
and rename it to a generic engagement-agnostic slug (e.g., revenue_flow_sankey.py).
Edit only the `# Data` block; everything below is the layout helper.

Default behavior: 3 sources -> 1 anchor + 3 destinations, illustrative balanced
magnitudes so the structure reads clearly. Replace the data block with real or
illustrative inputs that match your story.

Run: python <this-file>.py   ->   writes <name>.svg + <name>.png next to itself.
"""
from pathlib import Path
import plotly.graph_objects as go

# ============================================================
# Data
# ============================================================
# Three sources, each split into a "primary" portion (to the central anchor) and
# a "retained" portion (to its own destination). Illustrative — replace with the
# real values your story requires.

source_a_total = 100.0
source_b_total = 100.0
source_c_total = 100.0

primary_pct_a = 0.40   # portion of source A flowing to the central anchor
primary_pct_b = 0.30
primary_pct_c = 0.20

a_primary, a_secondary = source_a_total * primary_pct_a, source_a_total * (1 - primary_pct_a)
b_primary, b_secondary = source_b_total * primary_pct_b, source_b_total * (1 - primary_pct_b)
c_primary, c_secondary = source_c_total * primary_pct_c, source_c_total * (1 - primary_pct_c)
anchor_total = a_primary + b_primary + c_primary

TITLE = "Replace with one declarative claim about the flow"
SUBTITLE = "Illustrative data — replace with real values or keep as illustrative; cite source if real"

# ============================================================
# Palette (HSO Brand Manual v3.0 — see references/hso-plotly-styles.md)
# ============================================================
HSO_DARK_BLUE = "#00395F"
HSO_BLUEGREEN = "#079FC3"
HSO_GREEN     = "#00B294"
HSO_SALMON    = "#F1554B"
HSO_MIMOSA    = "#F2B949"
HSO_STEEL     = "#7F9CAF"
HSO_CANVAS    = "#FDFCF7"


def link_color(hex_str: str, alpha: float) -> str:
    h = hex_str.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


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
# Sankey nodes + links
# ============================================================
# Node order — left column, anchor, right column.
labels = [
    f"Source A<br>{source_a_total:,.0f}",
    f"Source B<br>{source_b_total:,.0f}",
    f"Source C<br>{source_c_total:,.0f}",
    f"Central anchor<br>{anchor_total:,.0f} aggregated",
    f"Destination A<br>{a_secondary:,.0f}",
    f"Destination B<br>{b_secondary:,.0f}",
    f"Destination C<br>{c_secondary:,.0f}",
]
node_colors = [HSO_SALMON, HSO_BLUEGREEN, HSO_GREEN, HSO_DARK_BLUE,
               HSO_STEEL, HSO_STEEL, HSO_STEEL]

# Explicit positions to prevent band crossings.
node_x = [0.01, 0.01, 0.01, 0.99, 0.99, 0.99, 0.99]
node_y = [0.12, 0.45, 0.78, 0.50, 0.08, 0.30, 0.62]

# Index map: 0=A, 1=B, 2=C, 3=anchor, 4=destA, 5=destB, 6=destC
source = [0, 0,  1, 1,  2, 2]
target = [3, 4,  3, 5,  3, 6]
values = [a_primary, a_secondary,
          b_primary, b_secondary,
          c_primary, c_secondary]

# 0.75 alpha for the primary flow into the anchor; 0.35 for the secondary band.
link_colors = [
    link_color(HSO_SALMON, 0.75), link_color(HSO_SALMON, 0.35),
    link_color(HSO_BLUEGREEN, 0.75), link_color(HSO_BLUEGREEN, 0.35),
    link_color(HSO_GREEN, 0.75), link_color(HSO_GREEN, 0.35),
]

fig = go.Figure(data=[go.Sankey(
    arrangement="fixed",
    node=dict(
        pad=30, thickness=26,
        line=dict(color=HSO_DARK_BLUE, width=1.5),
        label=labels, color=node_colors,
        x=node_x, y=node_y,
    ),
    link=dict(source=source, target=target, value=values, color=link_colors),
)])

apply_hso_layout(fig, TITLE, SUBTITLE)

# ============================================================
# Output
# ============================================================
out = Path(__file__).resolve().with_suffix("")
svg_path = out.with_suffix(".svg")
png_path = out.with_suffix(".png")
fig.write_image(str(svg_path), format="svg", width=1400, height=780)
fig.write_image(str(png_path), format="png", width=2400, height=1340, scale=1)

print(f"SVG: {svg_path}")
print(f"PNG: {png_path}")
