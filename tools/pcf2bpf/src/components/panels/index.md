# Panels

Presentational panel components for PCF2BPF's two tabs. Each panel receives its data and callbacks as
props from `App.tsx` — none of them talk to `window.toolboxAPI`/`window.dataverseAPI` or hold
Dataverse-facing state directly.

## Where each panel is used

`App.tsx` renders one of these two panels per tab: `PcfConfigurationPanel` for "PCFs Configuration",
`FormXmlPanel` for "Xml Details". All state and Dataverse calls still live in `App.tsx` — both panels
are purely presentational, receiving everything as props/callbacks.

## PcfConfigurationPanel

The "PCFs Configuration" tab's layout, assembling the cards imported directly from their own files under
`../cards/` (there is no `cards/index.ts` barrel):

- **Left column** — `ScopeCard`, `BpfSelectorCard`, an error `MessageBar` (if loading the
  form failed), the stage/field list (`StagesFieldsCard`, or a loading message while the form loads),
  and the "Update and Publish" button.
- **Right area** — a top row with `FieldPropertiesCard` (only rendered once a field is selected) beside
  `CopyFormFactorCard` (also only once a field is selected), followed below by `FormFactorsCard` spanning
  their combined width so its parameter table isn't squeezed into a narrower column.

Its own `usePcfConfigurationPanelStyles` holds the column layout (`configRow`/`leftColumn`/`rightArea`/
`topRow`/`fieldPropertiesColumn`/`copyColumn`) and the "Update and Publish" button's `fullWidth`; the card
frame/eyebrow styling is each card's own concern via `GenericCard`.

The props interface mirrors what `App.tsx` already tracks — no new state or memoization was introduced
by this extraction, existing `useMemo`/`useCallback` values (`attribute`, `compatibleControls`,
`selectedStageIndex`, `existingAssignment`, `handle*` callbacks) are just passed straight through.

## FormXmlPanel

Side-by-side Before/After `XmlFormatter` panes for the BPF's form XML, with a search box that highlights
matching text in both panes and a "Show differences" checkbox that turns on GitHub-style diff highlighting
(green for lines added in After, red for lines removed from Before) — see `XmlFormatter`'s own
[index.md](../formatters/index.md) for how the diff/highlight machinery works.

| Prop | Type | Description |
| --- | --- | --- |
| `beforeXml` | `string` | The form's XML as originally loaded, before any edits this session. |
| `afterXml` | `string` | The form's XML reflecting current (possibly unsaved) edits. |

Both panes always pretty-print (`prettyPrint` is hard-coded on) and use the `"light"` `XmlFormatter` theme,
independent of PPTB's own light/dark app theme.
