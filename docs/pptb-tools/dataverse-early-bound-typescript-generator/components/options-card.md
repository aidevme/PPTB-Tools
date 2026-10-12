# OptionsCard

Step 3 of the workflow: the output folder and which files to generate. The options mirror the
dataverse-gen `init` prompts and are saved to `.dataverse-gen.json`, so the dataverse-gen CLI uses the same
settings.

Source: [`src/components/OptionsCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/OptionsCard.tsx)

## Props (`OptionsCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `config` | `DataverseGenConfig` | The current project config. |
| `disabled` | `boolean` | Disables every input. |
| `onChange` | `(update: Partial<DataverseGenConfig>) => void` | Merges a change into the config. |

## Options

| Control | Config key | Default |
| --- | --- | --- |
| Output folder (relative to the project) | `output.outputRoot` | `./src/dataverse-gen` |
| Early-bound entity interfaces (dataverse-ify) | `generateEntityTypes` | On |
| Form context helpers (Xrm.FormContext) | `generateFormContext` | Off |
| index.ts barrel file | `generateIndex` | On |

Attribute constants, choice enums and the metadata cache (`metadata.ts`) are always generated for the
selected tables.
