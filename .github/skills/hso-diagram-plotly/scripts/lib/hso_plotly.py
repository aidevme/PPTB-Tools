"""
HSO Plotly helper — palette constants and layout helper.

Mirror of the canonical HSO palette per HSO Brand Manual v3.0.
See ../../references/hso-plotly-styles.md for usage rules.

Usage:
    from hso_plotly import (
        HSO_DARK_BLUE, HSO_BLUEGREEN, HSO_GREEN, HSO_SALMON,
        HSO_MIMOSA, HSO_STEEL, HSO_LIGHT_GREY, HSO_WEB_GREY,
        HSO_CANVAS, HSO_TEXT,
        link_color, apply_hso_layout, write_outputs,
    )

Templates inline a copy of the constants + helpers for portability — downstream
users copy a template script into their engagement repo and run it without
needing this lib on the import path.
"""
from pathlib import Path

# --- Palette (HSO Brand Manual v3.0) ---
HSO_DARK_BLUE = "#00395F"
HSO_BLUEGREEN = "#079FC3"
HSO_GREEN     = "#00B294"
HSO_SALMON    = "#F1554B"
HSO_MIMOSA    = "#F2B949"
HSO_STEEL     = "#7F9CAF"
HSO_LIGHT_GREY = "#E3E3E3"
HSO_WEB_GREY  = "#ECEFF3"
HSO_CANVAS    = "#FDFCF7"
HSO_TEXT      = "#505050"

CATEGORICAL = [HSO_BLUEGREEN, HSO_GREEN, HSO_SALMON, HSO_MIMOSA, HSO_STEEL]


def link_color(hex_str: str, alpha: float) -> str:
    """Convert '#RRGGBB' + alpha into 'rgba(r, g, b, a)' for Sankey link colors."""
    h = hex_str.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"Expected 6-char hex (e.g. '#079FC3'), got {hex_str!r}")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


def apply_hso_layout(fig, title: str, subtitle: str = "",
                     width: int = 1400, height: int = 780,
                     rev_stamp: str = "") -> None:
    """Apply HSO branding to a Plotly figure: title, fonts, backgrounds, margins.

    Sets template='none' so Plotly's default styling does not compete with
    the HSO overrides. Title is bold dark-blue; subtitle is steel-grey on the
    same line via inline HTML.
    """
    title_html = f"<b>{title}</b>"
    if subtitle:
        title_html += (
            f"<br><span style='font-size:14px; color:{HSO_STEEL};'>"
            f"{subtitle}</span>"
        )

    fig.update_layout(
        template="none",
        title=dict(
            text=title_html,
            x=0.5, xanchor="center",
            font=dict(family="Segoe UI, sans-serif", size=20, color=HSO_DARK_BLUE),
        ),
        font=dict(family="Segoe UI, sans-serif", size=13, color=HSO_DARK_BLUE),
        paper_bgcolor=HSO_CANVAS,
        plot_bgcolor=HSO_CANVAS,
        width=width,
        height=height,
        margin=dict(l=40, r=40, t=110, b=40),
    )

    if rev_stamp:
        fig.add_annotation(
            text=rev_stamp,
            xref="paper", yref="paper",
            x=1.0, y=-0.04,
            xanchor="right", yanchor="top",
            showarrow=False,
            font=dict(family="Segoe UI, sans-serif", size=11,
                      color=HSO_STEEL, style="italic"),
        )


def write_outputs(fig, out_path_no_ext, *, width: int = 1400, height: int = 780,
                  png_scale: int = 1) -> tuple:
    """Write SVG and PNG side by side. Returns (svg_path, png_path)."""
    out = Path(out_path_no_ext)
    svg_path = out.with_suffix(".svg")
    png_path = out.with_suffix(".png")
    fig.write_image(str(svg_path), format="svg", width=width, height=height)
    fig.write_image(str(png_path), format="png",
                    width=width * (2 if png_scale >= 2 else 1),
                    height=height * (2 if png_scale >= 2 else 1),
                    scale=1)
    return svg_path, png_path
