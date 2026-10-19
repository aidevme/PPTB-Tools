# OptionsCard

Step 3 of the workflow: the output folder and which files to generate. The options mirror the
dataverse-gen `init` prompts and are saved to `.dataverse-gen.json`, so the dataverse-gen CLI uses the same
settings.

Source: [`src/components/cards/OptionsCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx)

## Props (`IOptionsCardProps`)

`OptionsCardProps` remains as a deprecated alias of `IOptionsCardProps`.

| Prop | Type | Description |
| --- | --- | --- |
| `step` | `StepState` | This step's state for the [StepCard](../shared/step-card.md) header. |
| `config` | `DataverseGenConfig` | The current project config. |
| `disabled` | `boolean` | Disables every input. |
| `onChange` | `(update: Partial<DataverseGenConfig>) => void` | Merges a change into the config. |
| `customEnumTemplate` | `boolean` | Whether the project uses the custom enum template: its `pptbEarlyBoundGenerator.customEnumTemplate`, or the Settings default. |
| `onCustomEnumTemplateChange` | `(checked: boolean) => void` | Called by the **Custom enum template** switch. |

## Options

| Control | Config key | Default |
| --- | --- | --- |
| Output folder (relative to the project) | `output.outputRoot` | `./src/dataverse-gen` |
| Early-bound entity interfaces (dataverse-ify) | `generateEntityTypes` | On |
| Form context helpers (Xrm.FormContext) | `generateFormContext` | Off |
| index.ts barrel file | `generateIndex` | On |
| Custom enum template | `pptbEarlyBoundGenerator.customEnumTemplate` | **Settings** → **Options** default (off) |

The **Custom enum template** switch doesn't call `onChange`: `App.tsx` passes the same
`useCustomEnumTemplateConfirmation` handler as the Preview card, which asks first when turning it on would replace an
edited `enum.ejs`, then saves the value with `withProjectCustomEnumTemplate` and marks the preview stale. Its info
label is `CUSTOM_ENUM_TEMPLATE_INFO` from `settingsInfo.tsx`.

Attribute constants, choice enums and the metadata cache (`metadata.ts`) are always generated for the
selected tables.

## Info labels

Each control's label is a Fluent UI `InfoLabel`: an info button next to the text opens a short explanation of
what the option produces and which `.dataverse-gen.json` key it's saved as. The `InfoLabel` renders in the
control's label slot, so the label stays associated with its input, and clicking the text still toggles the
switch.
