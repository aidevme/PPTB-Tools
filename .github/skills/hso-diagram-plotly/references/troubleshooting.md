# Plotly Diagram Troubleshooting

Common issues when running this skill on Windows / cross-platform. Most are kaleido-related (Plotly's static image exporter).

## kaleido fails to import or hangs on first SVG export

Plotly 6.x ships with kaleido as the default image exporter. If `fig.write_image(...)` hangs or errors:

```bash
python -m pip install --upgrade kaleido
```

If still failing on Windows, check that the kaleido subprocess can find a Chromium build:

```bash
python -c "import plotly.io as pio; pio.kaleido.scope.default_format = 'svg'; print(pio.kaleido.scope)"
```

If kaleido reports a missing chromium, reinstall: `python -m pip install --force-reinstall kaleido`.

## kaleido ≥ 1.x — Chromium download required

Plotly 6 + kaleido 1.x downloads a Chromium build on first invocation. On a corporate-firewalled machine this can fail silently. Options:

1. Run once on an unrestricted network so the Chromium download completes (`~/.kaleido/`).
2. Set `PLOTLY_KALEIDO_CHROMIUM_DOWNLOAD=true` and ensure outbound HTTPS works.
3. Pin to kaleido 0.2.x (no Chromium dependency, but legacy):
   ```bash
   python -m pip install "kaleido==0.2.1"
   ```

The skill's [`requirements.txt`](../scripts/requirements.txt) targets the modern stack but documents the legacy fallback in a comment.

## Fonts substituted in the rendered SVG

Plotly renders text in SVG by default — fonts are referenced, not embedded. If a viewer doesn't have `Segoe UI` (Linux, some Mac configs), it falls back to a sans-serif and the diagram looks slightly off.

The helper sets `font.family = "Segoe UI, sans-serif"` so the fallback chain is sane. To force consistent rendering across platforms:

1. Embed the rendered SVG into a markdown / reveal.js context that ALSO loads a webfont with the same name.
2. Or render PNG only (PNGs are pre-rasterized and don't depend on viewer fonts).

For client-shipped artifacts, prefer PNG when font fidelity matters.

## Sankey bands cross unexpectedly

Plotly's default `arrangement="snap"` re-orders nodes by source/target connectivity. For diagrams where the column order matters (left = sources, right = destinations), bands cross.

Fix: always set `arrangement="fixed"` and supply explicit `x` and `y` arrays for every node.

```python
node=dict(
    x=[0.01, 0.01, 0.01, 0.99, 0.99, 0.99, 0.99],
    y=[0.12, 0.45, 0.78, 0.50, 0.08, 0.28, 0.58],
    ...
)
```

x / y values are in figure-relative space — `0.0` is the left/top edge, `1.0` is the right/bottom edge. Use `0.01` and `0.99` instead of `0.0` and `1.0` to leave a hairline of padding.

## Treemap labels overflow rectangles

If a leaf rectangle is small relative to the canvas, its label clips. Options:

1. Increase the diagram width (often the cleanest fix — clipping usually means too much data on too small a canvas).
2. Use a shorter label.
3. Set `textinfo="label"` (omit values from the rectangle, show on hover only — useful for SVG-only embeds).

## Waterfall connectors invisible

Plotly's waterfall connector defaults to a faint line. The HSO recipe sets it to `hso-steel` dotted at width 1 — visible but not loud. If connectors aren't showing:

```python
connector=dict(line=dict(color=HSO_STEEL, dash="dot", width=1))
```

Confirm the trace has it; check that `connector.visible` isn't `False` somewhere downstream.

## SVG file is large

Plotly emits verbose SVG with embedded MathJax, etc. For final delivery, optimize with `svgo`:

```bash
npx svgo path/to/diagram.svg --multipass
```

Typically cuts file size 30–60% with no visible change. Only run on the COMMITTED svg, not on the regenerated source — re-run will overwrite it.

## "kaleido scope already initialized" warning

Harmless — Python re-imports the scope between runs. Safe to ignore.

## Different output between local and CI

Plotly version, kaleido version, and the embedded Chromium build can all drift. Pin all three in [`requirements.txt`](../scripts/requirements.txt) and rebuild the CI image when bumping. If a CI render diverges from local: install the exact pinned versions locally and re-render — match against committed SVG.
