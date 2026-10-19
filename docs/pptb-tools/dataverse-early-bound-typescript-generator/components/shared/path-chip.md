# PathChip

A path shortened in the middle, with the full path in a tooltip and a copy button. The
[ProjectCard](../cards/project-card.md) uses it for the open project's folder and the
[PreviewCard](../cards/preview-card.md) for the output folder.

Source: [`src/components/shared/PathChip.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx)

## Props (`IPathChipProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `path` | `string` | The full path. |
| `label` | `string` | What the path is, for example "Project folder path". It's passed to `onCopy`, and the copy button's tooltip is "Copy" and the label with a lowercase first letter. |
| `onCopy` | `(path: string, label: string) => void` | Called with the full path and the label when the copy button is clicked. |
| `maxLength` | `number` (optional) | Longest text shown before `shortenPath` shortens the middle; defaults to 48. The PreviewCard passes 64. |
| `appearance` | `'plain' \| 'filled'` (optional) | `plain` (default) is monospace text that truncates with an ellipsis; `filled` adds a neutral background. The PreviewCard uses `filled`. |

## Behavior

- The component renders a fragment (the path and the button), so the parent row sets the layout and spacing.
- Paths are shortened by `shortenPath` in `components/shared/format.ts`.

Styles: `usePathChipStyles` in `src/styles/PathChip.styles.ts`.
