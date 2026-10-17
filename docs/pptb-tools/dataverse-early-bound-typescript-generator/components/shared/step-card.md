# StepCard

The frame shared by the four workflow cards ([ProjectCard](../cards/project-card.md),
[SelectionCard](../cards/selection-card.md), [OptionsCard](../cards/options-card.md) and
[PreviewCard](../cards/preview-card.md)). It gives every step the same header and highlights the step to work on
next.

Source: [`src/components/shared/StepCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/StepCard.tsx)

## Props (`IStepCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `step` | `StepState` | The step's number, title, completion, whether it's active, and status. |
| `description` | `string \| ReactElement` | Explanation under the title. A string is shown as small text. |
| `children` | `ReactNode` | The card's content. |

## Behavior

- **Header:** a step indicator, the step title, the description, and a status badge on the right
  (for example "Ready", "12 selected" or "Out of date").
- **Step indicator** (`StepIndicator`, also used by [WorkflowProgress](./workflow-progress.md)): a circle
  showing the step number. It turns brand-colored while it's the active step, and green with a check mark
  once the step is done.
- **Active step:** the first step that isn't done gets a brand-colored accent on its left edge and a
  slightly stronger shadow.
- **Accessibility:** the card is labelled "Step *n*: *title*, *state*". Its `id`
  (`workflow-step-<key>`) is what the progress bar scrolls to.

## Step states

`computeWorkflowSteps` (`src/components/shared/workflowSteps.ts`) works out each step from the app state:

| Step | Done when | Status |
| --- | --- | --- |
| Project | A project folder is open | Ready / Not selected |
| Select | Anything is selected | *n* selected / Nothing selected |
| Options | A project folder is open (its options then exist, with defaults if never changed) | Ready / Needs a project |
| Preview and generate | An up-to-date preview has nothing left to write | Up to date / *n* to write / Out of date / Not run |

The first step that isn't done is the active one.
