# PCF manifest `<property>` element reference

Reference notes on the `<property>` element of a Power Apps component framework (PCF)
`ControlManifest.Input.xml`, condensed from the
[official manifest schema reference](https://learn.microsoft.com/en-us/power-apps/developer/component-framework/manifest-schema-reference/property).
A `<property>` node defines one specific, configurable piece of data a component expects from
Microsoft Dataverse (model-driven apps) or from the app author (canvas apps) — this is the element
that `customcontrol.manifest` XML is built from, and that PCF2BPF's own
[`PcfService.ts`](../../tools/pcf2bpf/src/services/pcfservice/PcfService.ts) parses (see
[Relevance to PCF2BPF](#relevance-to-pcf2bpf) below).

**Available for:** Model-driven and canvas apps.

**Parent element:** [`<control>`](https://learn.microsoft.com/en-us/power-apps/developer/component-framework/manifest-schema-reference/control) — defines the component's namespace, version, and display information; `<property>` nodes are its direct children.

## Attributes

| Name | Description | Type | Required | Available for |
| --- | --- | --- | --- | --- |
| `default-value` | The default configuration value provided to the component. In model-driven apps, only allowed on `input` properties, since `bound` parameters expect an associated column. | string | Optional | Model-driven apps |
| `description-key` | Localized string key shown in customization screens as the property's description. | string | Optional | Model-driven and canvas apps |
| `display-name-key` | Localized string key shown in customization screens as the property's name. | string | **Yes** | Model-driven apps |
| `name` | Name of the property. | string | **Yes** | Model-driven and canvas apps |
| `of-type` | The property's data type — see [Using `of-type`](#using-of-type). | see below | Optional | Model-driven and canvas apps |
| `of-type-group` | Name of a `<type-group>` defined elsewhere in the manifest, as an alternative to a single `of-type` value. | string | Optional | Model-driven apps |
| `pfx-default-value` | Default value as a Power Fx expression instead of a static value — see [Using `pfx-default-value`](#using-pfx-default-value). | see below | Optional | Canvas apps |
| `required` | Whether the property is required. | boolean | Optional | Model-driven apps |
| `usage` | Whether the property represents a column the component can change (`bound`), a read-only input (`input`), or an output-only value (`output`). | `bound` \| `input` \| `output` | **Yes** | Model-driven apps |

## Remarks

### Using `of-type`

`of-type` must be one of the following values:

| Value | Description |
| --- | --- |
| `Currency` | Monetary values between -922,337,203,685,477 and 922,337,203,685,477. |
| `DateAndTime.DateAndTime` | Date and time. |
| `DateAndTime.DateOnly` | Date only. |
| `Decimal` | Up to 10 decimal points of precision, values between -100,000,000,000 and 100,000,000,000. |
| `Enum` | Enumerated data type. |
| `FP` | Up to 5 decimal points of precision (floating point), values between -100,000,000,000 and 100,000,000,000. |
| `Lookup.Simple` | A single reference to a specific table. All custom lookups are this type. Model-driven apps only. |
| `Multiple` | Up to 1,048,576 text characters. |
| `MultiSelectOptionSet` | A choices column allowing one, multiple, or all of a set of values to be selected. |
| `Object` | Object data type. Can only be used with `output` properties. |
| `OptionSet` | A set of options (number value + label); the control lets users select exactly one. |
| `SingleLine.Email` | Text formatted/validated as an email address; rendered as a clickable link by Unified Interface controls. |
| `SingleLine.Phone` | Text formatted/validated as a phone number; rendered as a clickable link by Unified Interface controls. |
| `SingleLine.Text` | Plain text. |
| `SingleLine.TextArea` | Multiple lines of text, up to 4,000 characters (use `Multiple` for larger amounts). |
| `SingleLine.Ticker` | Text formatted/validated as a stock ticker symbol; rendered as a clickable link by Unified Interface controls. |
| `SingleLine.URL` | A hyperlink; Unified Interface controls auto-prepend `https://` if no protocol is given. Only HTTP, HTTPS, FTP, FTPS, OneNote, and TEL protocols are expected. |
| `TwoOptions` | A boolean column (0/1) with a label pair for each state (e.g. "Yes"/"No", "On"/"Off"). |
| `Whole.None` | A plain number. |

> **Warning** — if `ControlManifest.Input.xml` contains at least one `<data-set>`, then any
> `Lookup.Simple` properties must also be wrapped in the
> [`<data-set>`](https://learn.microsoft.com/en-us/power-apps/developer/component-framework/manifest-schema-reference/data-set) element.

#### `of-type` values that aren't currently supported

| Value | Description |
| --- | --- |
| `Lookup.Customer` | A single reference to either an `account` or `contact` record (Opportunity/Case/Quote/Order/Invoice tables). |
| `Lookup.Owner` | A single reference to either a `team` or `user` record, on any team/user-owned table. |
| `Lookup.PartyList` | Multiple references to multiple tables — used by Email's **To**/**Cc** columns and in Phone/Appointment tables. |
| `Lookup.Regarding` | A single reference to multiple tables, used by the "regarding" column on activities. |
| `Status Reason` | System column with options detailing the `Status` column; each option maps to one `Status` option. |
| `Status` | System column with options generally corresponding to active/inactive state. |
| `Whole.Duration` | A duration column (stored as minutes) with a picklist of suggested values; users can also type a custom number of minutes. |
| `Whole.Language` | A language picklist (provisioned org languages), stored as an LCID. |
| `Whole.TimeZone` | A time zone picklist (e.g. "(GMT-08:00) Pacific Time (US & Canada)"), stored as a numeric `TimeZoneCode`. |

> **Note** — File columns aren't supported at this time.

### Using `pfx-default-value`

Canvas apps only. Lets a property's default value be evaluated as a Power Fx expression instead of
a static string — e.g. to responsively size the control, access connectors, provide sample data,
reference theme properties, or wire up custom events.

- Any valid Power Fx expression can be used, but it must be valid at import time.
- Wrap the value in single quotes if it contains inner quotes or other special characters, e.g.
  `pfx-default-value='"Test"'`.
- Reference other controls (including screens) and their properties as
  `%ControlName.ID%.ControlProperty`, e.g. `pfx-default-value='SubmitForm(%MyFormName.ID%)'`.
- Reference enums (e.g. `DisplayType`, `ScreenTransition`) as `%EnumName.RESERVED%.EnumValue`, e.g.
  `pfx-default-value='Back(%ScreenTransition.RESERVED%.Cover)'`.
- If both are present, `pfx-default-value` takes precedence over `default-value`.

## Example

```xml
<property name="myFirstProperty" display-name-key="myFirstProperty_Display_Key"
  description-key="myFirstProperty_Desc_Key" of-type="SingleLine.Text" usage="bound" required="true" />
```

## Relevance to PCF2BPF

`tools/pcf2bpf/src/services/pcfservice/PcfService.ts`'s `parsePcfManifestParameters` parses
`control > property` elements out of a `customcontrol.manifest` XML string, reading these attributes:

- `name` — the parameter's key (read/write its saved value) **and** its displayed label in
  `FormFactorsCard`'s parameter editor (`param.name + (param.required ? " *" : "")`).
- `display-name-key` (falling back to `name` if absent) is parsed onto `PcfParameter.displayNameKey`,
  but nothing in the UI currently reads that field — `FormFactorsCard` labels each parameter with
  the raw `name` instead, not the localized display name.
- `of-type` / `of-type-group` — parsed onto the parameter but not used for validation anywhere.
- `required` — shown as a `*` suffix on the parameter's field label.
- `usage` — parameters with `usage === "bound"` are filtered out both in `FormFactorsCard` (so
  they're never shown in the editor) and in `services/formxml.ts`'s `setCustomControl` (so a bound
  parameter can't be written even if one somehow made it into `parameterValues`), since bound
  parameters are wired to a field by the form designer rather than a static value (see "Not
  implemented" in the tool's root `README.md` — binding a parameter to another field isn't
  supported by this port).

`default-value` and `pfx-default-value` aren't read at all — PCF2BPF's parameter editor always
starts from the *existing* assignment's saved values (or blank), not the manifest's declared
default, and canvas-app-only attributes like `pfx-default-value` don't apply to this tool's
model-driven-only scope. `description-key` also isn't surfaced anywhere in the UI today.
