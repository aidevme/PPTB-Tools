# PCF control definition formats: `customcontrol.manifest` and `customcontrol.clientjson`

A registered PCF (Power Apps Component Framework) control is stored on Dataverse as a
`customcontrol` record. That record carries the *same* control definition in two different formats,
both read by this repo's `services/`:

- **`manifest`** — the control author's source XML (`ControlManifest.Input.xml`), the format
  Microsoft documents publicly. See [manifest.xml](manifest.xml) for a captured sample and
  [pcf-property-element.md](pcf-property-element.md) for the full `<property>` element reference.
- **`clientjson`** — a platform-generated JSON mirror of the manifest, produced when the control is
  registered/deployed. It isn't part of Microsoft's public schema docs; everything below about its
  shape is reverse-engineered from the captured sample at [clientjson.json](clientjson.json), not a
  documented contract, so treat field meanings (especially the numeric `Type`/`Usage` codes) as
  best-effort.

Both samples describe the same control (`MsdynmktControls.EmailEditor.FormControls.ThicknessControl`,
a virtual control with one bound `SingleLine.Text` property), which is why the two sections below
line up field-for-field.

## `manifest` (XML)

```xml
<manifest>
    <control namespace="MsdynmktControls.EmailEditor.FormControls" constructor="ThicknessControl"
        version="1.60115.104" display-name-key="Thickness Control" control-type="virtual">
        <modes></modes>
        <property name="value" display-name-key="CC_ThicknessControlValue"
            description-key="CC_ThicknessControlValue_desc" of-type="SingleLine.Text" usage="bound"
            required="true" hidden="false" />
        <resources>
            <code path="ThicknessControl.js" order="2" />
            <resx path="locale/ThicknessControl.1033.resx" version="1.0.2" />
            <platform-library name="Fluent" version="9.46.2" />
        </resources>
    </control>
</manifest>
```

### `<control>` attributes

| Attribute | Description |
| --- | --- |
| `namespace` | The control's namespace (publisher/product grouping). |
| `constructor` | The control's class/constructor name. |
| `version` | The control's own version number (independent of the manifest schema version). |
| `display-name-key` | Localized string key for the control's display name in customization UI. |
| `control-type` | `"virtual"` for a React-rendered control, omitted/absent for a standard (HTML) control. |

### `<modes>`

Declares which app modes (e.g. Configuration) the control supports; empty here since this control
supports the default set.

### `<property>`

One entry per configurable parameter. Fully documented in
[pcf-property-element.md](pcf-property-element.md) — this manifest uses `name`, `display-name-key`,
`description-key`, `of-type`, `usage`, `required`, and `hidden`.

### `<resources>`

| Element | Description |
| --- | --- |
| `<code path="..." order="N">` | A JS file loaded for the control, in `order` sequence. |
| `<resx path="..." version="...">` | A localization resource file. |
| `<platform-library name="..." version="...">` | A platform-provided library (e.g. Fluent UI) the control depends on, resolved by name/version rather than bundled. |

## `clientjson` (JSON)

```json
{
    "CustomControlId": "fb6c9816-4e20-44ed-88a2-00cd551ea9e3",
    "Name": "MsdynmktControls.EmailEditor.FormControls.ThicknessControl",
    "ConstructorName": "ThicknessControl",
    "ControlMode": "Unknown",
    "DisplayName": "Thickness Control",
    "Namespace": "MsdynmktControls.EmailEditor.FormControls",
    "IsVirtual": true,
    "Properties": {
        "Resources": [
            { "Name": "fluent_9_4_0", "LoadOrder": 0, "LibraryName": "fluent_9_4_0", "Type": 0 },
            { "Name": "MsdynmktControls.EmailEditor.FormControls.ThicknessControl_ThicknessControl.js", "LoadOrder": 2, "Type": 4 },
            { "Name": "locale/ThicknessControl.1033.resx", "LoadOrder": 0, "Type": 5 }
        ],
        "DataSets": [],
        "Properties": [
            { "Name": "value", "Type": "SingleLine.Text", "Hidden": false, "Required": true, "Usage": 0 }
        ],
        "FeatureUsage": [],
        "PlatformAction": [],
        "Events": [],
        "Actions": []
    },
    "VersionNumber": 0,
    "OverallVersionNumber": 0,
    "FullName": "MsdynmktControls.EmailEditor.FormControls.ThicknessControl",
    "Children": [],
    "ControlManifestVersion": "1.60115.104"
}
```

### Top-level fields

| Field | Description |
| --- | --- |
| `CustomControlId` | The `customcontrol` record's GUID. |
| `Name` / `FullName` | The control's fully-qualified name (`Namespace.Constructor`). |
| `ConstructorName` | Same as manifest's `constructor`. |
| `ControlMode` | Observed as `"Unknown"` in this sample; not otherwise verified. |
| `DisplayName` | The control's *resolved* display name — unlike the manifest's `display-name-key` (a lookup key), this is already the localized string. |
| `Namespace` | Same as manifest's `namespace`. |
| `IsVirtual` | `true`/`false` — same concept as manifest's `control-type="virtual"`. |
| `VersionNumber` / `OverallVersionNumber` | Observed as `0` in this sample; not otherwise verified. |
| `Children` | Empty here; presumably nested/composed controls when populated. |
| `ControlManifestVersion` | The manifest schema version the control was built against — same as manifest's `<control version="...">`. |
| `Properties` | Object holding the control's parameters and asset lists, detailed below. |

### `Properties` object

| Field | Description |
| --- | --- |
| `Resources[]` | Assets the control loads — see [Resource `Type` codes](#resource-type-codes-inferred) below. |
| `DataSets[]` | Empty here; would list `<data-set>` definitions for a dataset-bound control. |
| `Properties[]` | One entry per manifest `<property>` — see below. |
| `FeatureUsage[]` / `PlatformAction[]` / `Events[]` / `Actions[]` | All empty in this sample; not otherwise verified. |

#### `Properties.Properties[]` (parameter entries)

| Field | Manifest equivalent | Description |
| --- | --- | --- |
| `Name` | `name` | Parameter name. |
| `Type` | `of-type` | Same value space as the manifest's `of-type` (e.g. `"SingleLine.Text"`). |
| `Hidden` | *(no manifest attribute in this sample)* | Whether the parameter is hidden from customization UI. |
| `Required` | `required` | Boolean, matching the manifest attribute directly (not the XML string `"true"`/`"false"`). |
| `Usage` | `usage` | Numeric code — see [Usage codes](#usage-codes-inferred) below. |

#### Usage codes (inferred)

| Code | Manifest `usage` |
| --- | --- |
| `0` | `bound` |
| `1` | `input` |
| `2` | `output` |

(Matches [`PcfService.ts`](../../tools/pcf2bpf/src/services/pcfservice/PcfService.ts)'s `USAGE_BY_CODE`
map — inferred from behavior, not an official spec.)

#### Resource `Type` codes (inferred)

Inferred from this single sample's three entries — treat as illustrative, not exhaustive:

| Code | Observed resource | Guess |
| --- | --- | --- |
| `0` | `{ "Name": "fluent_9_4_0", "LibraryName": "fluent_9_4_0" }` | Platform library (manifest's `<platform-library>`) — has a `LibraryName`, unlike the other entries. |
| `4` | `..._ThicknessControl.js` | Code/script resource (manifest's `<code>`). |
| `5` | `locale/ThicknessControl.1033.resx` | Localization resource (manifest's `<resx>`). |

No `LoadOrder` value in this sample corresponds to a manifest `order` other than the code resource's
`"LoadOrder": 2` matching `<code order="2">` — the platform-library and resx entries both show
`"LoadOrder": 0` despite the manifest not declaring an explicit order for them.

## How the two formats correspond

| Manifest XML | `clientjson` JSON |
| --- | --- |
| `control/@namespace` | `Namespace` |
| `control/@constructor` | `ConstructorName` |
| `control/@version` | `ControlManifestVersion` |
| `control/@display-name-key` | `DisplayName` (resolved, not a key) |
| `control/@control-type="virtual"` | `IsVirtual: true` |
| `property/@name` | `Properties.Properties[].Name` |
| `property/@of-type` | `Properties.Properties[].Type` |
| `property/@required="true"/"false"` (string) | `Properties.Properties[].Required` (boolean) |
| `property/@usage="bound"/"input"/"output"` | `Properties.Properties[].Usage` (`0`/`1`/`2`) |
| `resources/code/@path`, `@order` | `Properties.Resources[]` entry, `Type: 4`, `LoadOrder` |
| `resources/resx/@path` | `Properties.Resources[]` entry, `Type: 5` |
| `resources/platform-library/@name`, `@version` | `Properties.Resources[]` entry, `Type: 0`, `LibraryName` |

Fields with no manifest counterpart in this sample (`CustomControlId`, `ControlMode`, `VersionNumber`,
`OverallVersionNumber`, `Hidden`) are either Dataverse-record metadata (the ID) or not present as
manifest attributes on this particular control.

## Relevance to PCF2BPF

[`tools/pcf2bpf/src/services/pcfservice/PcfService.ts`](../../tools/pcf2bpf/src/services/pcfservice/PcfService.ts)
holds all manifest/clientjson parsing plus `loadPcfControls()`, which reads a `customcontrol`
record's `manifest` and `clientjson` attributes and combines them into one `PcfControl`:

- **Parameters** always come from `PcfService.ts`'s `parsePcfManifestParameters(manifest)` — parsing
  the XML's `<property>` elements (see [pcf-property-element.md](pcf-property-element.md)).
- **`isVirtual` and `version`** come from `PcfService.ts`'s `parsePcfClientJsonInfo(clientjson)`,
  reading `IsVirtual` and `ControlManifestVersion`.
- `PcfService.ts` also exports `parsePcfClientJsonParameters`, which parses `Properties.Properties[]`
  into the same `PcfParameter[]` shape as the manifest parser — but nothing in this repo currently
  calls it. Parameters are always sourced from the XML manifest, never from `clientjson`, despite both
  containing equivalent data.
- `compatibleDataTypes` (used to filter which controls are offered for a given Dataverse attribute
  type, via `getCompatiblePcfControls` in
  [`dataverseservice/DataverseService.ts`](../../tools/pcf2bpf/src/services/dataverseservice/DataverseService.ts))
  comes from neither format directly — it's read from the `customcontrol` record's own
  `compatibledatatypes` attribute, a separate comma-separated field.
