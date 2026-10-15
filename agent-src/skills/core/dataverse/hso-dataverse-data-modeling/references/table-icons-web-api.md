# Custom-table icons via the Web API (`IconVectorName`)

The Web API specifics behind the `CreateWebResource` / `SetTableIcon` operations and the optional
`-IconVectorName` / icon-source parameters on `CreateTable`. The **methodology** (when to set an icon, the
SVG authoring rules, security) lives in the SOP —
[`data-modeling-best-practices.md` → Table icons](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md).
This file is the operations reference.

## Mechanism

A custom table's icon is an **SVG web resource** (webresourcetype `11`) referenced by
`EntityMetadata.IconVectorName`. This supersedes the legacy raster properties `IconSmallName` (16×16 PNG),
`IconMediumName` (32×32 PNG), and `IconLargeName`. The skill only writes `IconVectorName`.

> **System tables cannot be re-iconed.** Microsoft does not allow changing the icon of system/OOB tables —
> only custom tables (`IsCustomEntity = true`). `SetTableIcon` reads `IsCustomEntity` and refuses on a
> system table rather than firing a PUT that fails opaquely. This means an `extension` slice (HSO columns on
> an OOB table) can never carry a custom icon.

## Microsoft's SVG rules (enforced by `Test-DataverseSvgIcon`)

From [Image web resources](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/image-web-resources)
and [Change custom table icons](https://learn.microsoft.com/en-us/power-apps/maker/model-driven-apps/change-custom-entity-icons):

| Rule | Enforcement |
|------|-------------|
| ≤ **10 KB** (all image web resources) | **hard** — throws |
| Must be a valid `<svg>` with a **`viewBox`** (default size; renders at 16×16) | **hard** — throws |
| **No `<script>`**, no `on*=` event handlers, no external/`data:` `href` | **hard** — throws |
| Prefer `fill="currentColor"` over hard-coded hex (theming / contrast) | **warn** |
| No embedded `<style>`/class blocks (they leak across SVGs); use a `fill`/`style` attribute | **warn** |

> **Why the script refusals are a security control, not cosmetics.** Microsoft Learn: *"Vector Format (SVG)
> web resources are treated like the Script (JScript) web resources, and carry the same security risks as
> JavaScript web resources because SVG files allow JScript embedding."* Dataverse **does not sanitize** the
> SVG — a script-bearing icon is stored and served as-is and executes in the user's security context. Hence
> `<script>` / `on*=` / external `href` are hard refusals.

## Getting an icon

The skill does **not** ship artwork — bring your own SVG (`-IconSvgPath` / `-IconSvgContent`), or reuse an
existing SVG web resource (`-IconVectorName`). For a ready-made glyph, pull one from Microsoft **Fluent UI
System Icons** ([microsoft/fluentui-system-icons](https://github.com/microsoft/fluentui-system-icons), MIT):

1. Pick a glyph and take its **`*_16_regular`** SVG variant (16px renders crisply at the table-icon size).
2. Replace the hard-coded `fill="#212121"` with **`fill="currentColor"`** — Microsoft's own guidance so the
   icon themes with the app and keeps contrast. Leave the geometry unchanged.
3. Pass the file via `-IconSvgPath` (or its markup via `-IconSvgContent`). `Test-DataverseSvgIcon` validates
   it against the rules above before upload.

Makers working interactively can instead use the
[Iconator](https://www.xrmtoolbox.com/plugins/MscrmTools.Iconator/) XrmToolBox plugin (not callable headlessly).

## Payloads

### Create the SVG web resource (`webresourceset`, type 11)

`content` is base64 of the UTF-8 SVG bytes.

```jsonc
POST [Organization URI]/api/data/v9.2/webresourceset
{
  "name": "hso_contract_icon.svg",      // publisher-prefixed unique name
  "displayname": "Contract icon",
  "webresourcetype": 11,                 // 11 = SVG (Vector Format)
  "content": "PHN2ZyB3aWR0aD0..."        // base64(UTF-8 SVG)
}
```

Then publish it (so a table referencing it resolves on the table publish):

```jsonc
POST [Organization URI]/api/data/v9.2/PublishXml
{ "ParameterXml": "<importexportxml><webresources><webresource>{webresourceid}</webresource></webresources></importexportxml>" }
```

The skill is **idempotent**: an existing web resource of the same name is PATCHed (content/displayname/
description) rather than re-POSTed. It refuses to repurpose a same-named non-SVG web resource.

### Point the table at it (`IconVectorName`)

Entity metadata is updated with the GET-modify-PUT pattern (PUT requires `@odata.type` + `MetadataId`):

```jsonc
PUT [Organization URI]/api/data/v9.2/EntityDefinitions(LogicalName='hso_contract')
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "MetadataId": "{table MetadataId}",
  "IconVectorName": "hso_contract_icon.svg"
}
```

Then publish the table (`PublishXml` with `<entities><entity>hso_contract</entity></entities>`). The skill
read-back-verifies `IconVectorName` afterward — a dangling reference (web resource missing/unpublished, or
not an SVG) silently no-ops, so the success banner is not trusted.

## Solution portability

`IconVectorName` referencing a web resource by **name** creates a solution dependency
(the `$webresource:` dependency described in
[Image web resources](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/image-web-resources)).
Create the web resource **in the same unmanaged solution** as the table (pass `-SolutionName` to
`CreateWebResource` / `SetTableIcon`), or the icon reference breaks on export — the same failure mode as the
relationship-parent-table portability trap in
[`relationship-solution-portability.md`](relationship-solution-portability.md).

## App-designer override

An icon chosen in the app designer **overrides** the table-definition icon for that app. `IconVectorName` is
the default shown when the app designer is left on the default icon, so it is the right place to set a
table's standard icon.
