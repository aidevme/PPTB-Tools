# Cards

Standalone card components used in `App.tsx`'s "PCFs Configuration" tab. Each is presentational,
receiving its data and callbacks as props from `App.tsx`, and shares its outer frame/eyebrow heading via
`GenericCard` rather than declaring its own.

## FieldPropertiesCard

Read-only summary card for the currently selected field: its label/logical name, resolved attribute type,
owning entity, and whether it's required on its BPF stage — plus a colored badge matching the field's stage
color (passed in as `stageColor` and applied via a `--stage-color` CSS custom property, the same pattern
`XmlFormatter` uses for its theme colors).

| Prop | Type | Description |
| --- | --- | --- |
| `field` | `FieldInfo` | The selected field. |
| `attribute` | `AttributeInfo \| undefined` | Resolved entity metadata for the field; `undefined` renders "Unknown" as the type. |
| `entityDisplayName` | `string` | Display name of the field's owning entity. |
| `stageName` | `string` | Name of the BPF stage the field belongs to. |
| `stageColor` | `string` | CSS color, applied via `--stage-color` to the stage badge. |

## FormFactorsCard

The main editing surface: pick a form factor (Web/Phone/Tablet), see which of the three already have a PCF
control assigned (a green checkmark badge vs. a plain "+"), choose a PCF control compatible with the
field's data type, fill in its non-bound manifest parameters, and apply or remove the assignment.

| Prop | Type | Description |
| --- | --- | --- |
| `field` | `FieldInfo \| null` | Selected field; `null` renders a "Select a field…" placeholder instead of the editor. |
| `entityDisplayName` | `string` | Shown in the "Form Factors for {field} ({entity})" heading. |
| `doc` | `XMLDocument \| null` | The live form XML document, used to check which form factors already have an assignment. |
| `docVersion` | `number` | Bump counter from `App.tsx`; `doc` is mutated in place, so this is what actually drives recomputation (see the root `CLAUDE.md`'s state-management note). |
| `formFactor` | `FormFactor` | Currently selected form factor. |
| `onFormFactorChange` | `(formFactor: FormFactor) => void` | Called when the user clicks a different form factor. |
| `attribute` | `AttributeInfo \| undefined` | Resolved metadata for `field`; `undefined` shows a "could not resolve metadata" message. |
| `compatibleControls` | `PcfControl[]` | PCF controls compatible with the field's attribute type. Empty renders a "no compatible control" message. |
| `existing` | `PcfAssignment \| null` | The field's current PCF assignment on `formFactor`, if any — seeds the selected control and parameter values. |
| `onApply` | `(pcf: PcfControl, values: Record<string, string>) => void` | Called on "Add Control / Apply Changes". |
| `onRemove` | `() => void` | Called on "Remove Control"; disabled when `existing` is `null`. |

Local state (`selectedPcfId`, `paramValues`) resets whenever the selected field, form factor, or that
combination's existing assignment changes — see the `useEffect` with the `field?.controlId, formFactor,
existing?.name` dependency array — so switching fields or form factors doesn't leak one field's in-progress
parameter edits into another's editor.

Only parameters with `usage !== "bound"` are shown, since bound parameters are wired to a field by the form
designer rather than a static value (see "Not implemented" in the tool's root `README.md` — binding a
parameter to another field isn't supported by this port).

The title is composed JSX (a bold field/entity name inside "Form Factors for ..."), which is why
`GenericCard`'s `title` prop accepts `ReactNode` rather than a plain `string`. `useFormFactorsCardStyles`
supplies a `content` wrapper reproducing the original panel's `display: flex; flexDirection: column; gap:
12px` root (since `GenericCard`'s own children are plain block flow) plus the tab/assigned-icon styling;
everything else inside still uses inline `style` objects rather than `makeStyles` classes. Match the
surrounding inline-style pattern for internal layout tweaks; only add to the styles hook for things that
should visually match the frame itself.
