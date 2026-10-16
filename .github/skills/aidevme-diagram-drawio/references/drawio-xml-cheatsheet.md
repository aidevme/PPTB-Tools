# Draw.io XML Cheatsheet

Minimal reference for authoring `.drawio` files by hand. Paired with `hso-drawio-styles.md` for the HSO palette.

## File skeleton (uncompressed)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" modified="2026-04-15T00:00:00.000Z" agent="hso-diagram-drawio" version="24.0.0">
  <diagram id="main" name="Page-1">
    <mxGraphModel dx="1600" dy="900" grid="1" gridSize="20" guides="1" tooltips="1"
                  connect="1" arrows="1" fold="1" page="1" pageScale="1"
                  pageWidth="1600" pageHeight="900" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <!-- content cells below -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

Cell id `0` and `1` are required roots. All content cells use `parent="1"`.

## Vertex (box / shape)

```xml
<mxCell id="v1" value="Label text" style="HSO_STYLE_STRING" vertex="1" parent="1">
  <mxGeometry x="40" y="40" width="200" height="60" as="geometry" />
</mxCell>
```

## Edge (arrow / connector)

```xml
<mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;..." edge="1" parent="1" source="v1" target="v2">
  <mxGeometry relative="1" as="geometry" />
</mxCell>
```

Omit `source` or `target` to leave an edge dangling (anchored by geometry instead).

## Edge with label

```xml
<mxCell id="e1" value="uses" style="..." edge="1" parent="1" source="v1" target="v2">
  <mxGeometry relative="1" as="geometry">
    <Array as="points">
      <mxPoint x="300" y="200" />
    </Array>
  </mxGeometry>
</mxCell>
```

`<Array as="points">` adds waypoints for orthogonal routing.

## Container (group) with children

A container holds children; useful for layer panels, swim lanes.

```xml
<mxCell id="layer1" value="Presentation Layer" style="BACKDROP_STYLE;container=1;collapsible=0;"
        vertex="1" parent="1">
  <mxGeometry x="40" y="40" width="600" height="200" as="geometry" />
</mxCell>

<mxCell id="child1" value="Model-driven App" style="PRIMARY_COMPONENT_STYLE" vertex="1" parent="layer1">
  <mxGeometry x="20" y="40" width="160" height="60" as="geometry" />
</mxCell>
```

**Note:** child `x`/`y` are relative to the parent container's origin.

## Multi-row entity (ERD pattern)

Pattern: one parent "entity" cell holding a header row + one row per field. All rows are children of the entity container.

```xml
<mxCell id="ent_account" value="" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#00395F;container=1;collapsible=0;"
        vertex="1" parent="1">
  <mxGeometry x="80" y="80" width="220" height="160" as="geometry" />
</mxCell>

<!-- header row -->
<mxCell id="ent_account_hdr" value="hso_account" style="ENTITY_HEADER_STYLE"
        vertex="1" parent="ent_account">
  <mxGeometry y="0" width="220" height="30" as="geometry" />
</mxCell>

<!-- field rows -->
<mxCell id="ent_account_f1" value="[PK] hso_accountid" style="FIELD_ROW_STYLE"
        vertex="1" parent="ent_account">
  <mxGeometry y="30" width="220" height="26" as="geometry" />
</mxCell>
<mxCell id="ent_account_f2" value="hso_name" style="FIELD_ROW_STYLE"
        vertex="1" parent="ent_account">
  <mxGeometry y="56" width="220" height="26" as="geometry" />
</mxCell>
```

## ID conventions

- Use human-readable IDs: `ent_account`, `layer_data`, `edge_app_to_api`.
- Prefix by type: `ent_` (entity), `cmp_` (component), `act_` (actor), `edge_`.
- Never reuse ID `0` or `1`.
- Keep IDs stable across edits to minimize diff noise.

## Common pitfalls

1. **Missing `parent="1"`** — cell won't render.
2. **Self-closing `<mxCell/>` without `<mxGeometry>`** — invisible.
3. **Compressed XML** — drawio desktop saves compressed by default. Force uncompressed by using `File → Edit Diagram` or the `-u` CLI export flag. Our render script outputs SVG (the source `.drawio` must be hand-authored uncompressed).
4. **Wrong page size** — set `pageWidth` / `pageHeight` to match your content bounds + padding.
5. **Forgetting quotes in attribute values** — XML requires double quotes.
