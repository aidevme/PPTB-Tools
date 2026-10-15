"""
HSO Waterfall diagram template.

Copy this file into <engagement-repo>/agent/work/deliverables/diagrams/_generators/
and rename to an engagement-agnostic slug. Edit only the `# Data` block.

Default: starting balance -> three positive drivers + two negative drivers ->
ending balance. Increases render in HSO green, decreases in HSO salmon, totals
in HSO dark blue.

Run: python <this-file>.py
"""
from pathlib import Path
import plotly.graph_objects as go

# ============================================================
# Data
# ============================================================
# Each step: (label, measure, value).
#   measure = "absolute" for an anchor (start / end totals)
#   measure = "relative" for a contribution (positive or negative)
#   measure = "total" for a computed total bar
steps = [
    ("Starting balance", "absolute",  10000),
    ("Driver A (+)",     "relative",   2500),
    ("Driver B (+)",     "relative",   1500),
    ("Driver C (-)",     "relative",  -1200),
    ("Driver D (+)",     "relative",    800),
    ("Driver E (-)",     "relative",   -600),
    ("Ending balance",   "total",         0),    # value ignored when measure="total"
]

TITLE = "Replace with one declarative claim about the bridge"
SUBTITLE = "Illustrative variance bridge — replace with real values; cite source if real"

# ============================================================
# Palette
# ============================================================
HSO_DARK_BLUE = "#00395F"
HSO_GREEN     = "#00B294"
HSO_SALMON    = "#F1554B"
HSO_STEEL     = "#7F9CAF"
HSO_LIGHT_GREY = "#E3E3E3"
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
# Waterfall
# ============================================================
labels   = [s[0] for s in steps]
measures = [s[1] for s in steps]
values   = [s[2] for s in steps]

fig = go.Figure(go.Waterfall(
    name="",
    orientation="v",
    measure=measures,
    x=labels,
    y=values,
    textposition="outside",
    text=[f"{v:+,.0f}" if m == "relative" else f"{v:,.0f}"
          for m, v in zip(measures, values)],
    connector=dict(line=dict(color=HSO_STEEL, dash="dot", width=1)),
    increasing=dict(marker=dict(color=HSO_GREEN, line=dict(color=HSO_DARK_BLUE, width=1))),
    decreasing=dict(marker=dict(color=HSO_SALMON, line=dict(color=HSO_DARK_BLUE, width=1))),
    totals=dict(marker=dict(color=HSO_DARK_BLUE, line=dict(color=HSO_DARK_BLUE, width=1))),
))

fig.update_yaxes(showgrid=True, gridcolor=HSO_LIGHT_GREY, zeroline=False,
                 tickformat=",.0f")
fig.update_xaxes(showgrid=False)

apply_hso_layout(fig, TITLE, SUBTITLE)

# ============================================================
# Output
# ============================================================
out = Path(__file__).resolve().with_suffix("")
fig.write_image(str(out.with_suffix(".svg")), format="svg", width=1400, height=780)
fig.write_image(str(out.with_suffix(".png")), format="png", width=2400, height=1340, scale=1)
print(f"SVG: {out.with_suffix('.svg')}")
print(f"PNG: {out.with_suffix('.png')}")
