# Diagram Integration Patterns (Plotly SVG / PNG)

Embedding guidance mirrors the drawio and excalidraw skills. Plotly outputs both SVG (for markdown / reveal.js) and PNG (for PPTX) — the same source `.py` is the regeneration root.

## Markdown embed

```markdown
![Diagram caption](diagrams/<slug>.svg)
```

With caption:
```markdown
<figure>
  <img src="diagrams/<slug>.svg"
       alt="<descriptive alt text>"
       style="max-width:1100px;width:100%;" />
  <figcaption><em>Figure N — <one-line description of what the diagram teaches>.</em></figcaption>
</figure>
```

## Reveal.js slide

```html
<section>
  <h2>Slide title</h2>
  <img src="diagrams/<slug>.svg"
       alt="<descriptive alt text>"
       style="max-height:75vh;max-width:90%;" />
  <aside class="notes">
    Speaker notes that walk the audience through the diagram. Reference the visual hierarchy
    (e.g., the alpha-paired primary vs. secondary bands) and call out what the geometry teaches.
  </aside>
</section>
```

## PPTX embed

Use the PNG, not the SVG — PowerPoint's SVG support is inconsistent across versions and degrades to raster anyway.

```python
slide.shapes.add_picture(
    "diagrams/<slug>.png",
    Inches(1), Inches(1),
    width=Inches(11),
)
```

## Use-case framing

Plotly archetypes signal "data-driven analysis." Frame them in contexts where that signal helps:

- **OK:** "value distribution", "cost waterfall", "variance bridge", "conversion funnel"
- **NOT OK:** "process flow" (use drawio), "system architecture" (use reference-architecture or drawio), "workshop sketch" (use excalidraw)

If the diagram is the ONE distinctive visual that teaches the slide's point — that's the right context. If it's filler — the slide doesn't need it.

## Regenerating from updated data

Plotly's strength is regenerability. When inputs change:

1. Edit the `# Data` block at the top of the `.py` source.
2. Re-run the script. SVG + PNG regenerate next to the source.
3. Commit all three (`.py`, `.svg`, `.png`).
4. The embedding markdown / slide picks up the new image without changes.

Don't hand-edit the rendered SVG. It will be silently overwritten on the next run, and the change won't survive.
