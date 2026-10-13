# WorkflowProgress

A progress bar across the top of the page showing the four workflow steps, so the cards below read as a
guided flow.

Source: [`src/components/shared/WorkflowProgress.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/WorkflowProgress.tsx)

## Props (`IWorkflowProgressProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `steps` | `StepState[]` | The four steps from `computeWorkflowSteps`; see [StepCard](./step-card.md#step-states). |

## Behavior

- Each step shows the same indicator as its card (number, brand-colored while active, a green check once
  done), its title and its status.
- The line after a step turns green once that step is done.
- **Clicking a step** scrolls to its card. The scroll is instant instead of smooth when the user has asked
  their system for reduced motion.
- **Accessibility:** it's a `nav` labelled "Workflow progress" containing an ordered list. The active step
  has `aria-current="step"`, and each button is labelled with the step's number, title and status.
- On narrow windows the bar scrolls sideways instead of wrapping.
- Styles are in `src/styles/WorkflowProgress.styles.ts`.
