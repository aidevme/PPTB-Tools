# SelectionCard

Step 2 of the workflow: choose the tables, actions and functions to generate. The selection is stored
directly in the config, so it's saved to `.dataverse-gen.json`.

Source: [`src/components/cards/SelectionCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx)

## Props (`SelectionCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `step` | `StepState` | This step's state for the [StepCard](../shared/step-card.md) header. |
| `entities` | `EntitySummary[]` | Tables in the connected environment. |
| `operations` | `OperationSummary[] \| null` | Actions and functions; `null` until the `$metadata` document has been loaded. |
| `solutions` | `SolutionSummary[]` | Solutions offered in the solution filter. |
| `solutionEntityIds` | `Set<string> \| null` | Table `MetadataId`s in the chosen solution; `null` when no solution filter is active. |
| `solutionComponentIds` | `Set<string> \| null` | Custom API and custom process action ids in the chosen solution; `null` when not filtering. |
| `selectedSolutionId` | `string \| null` | The solution chosen in the filter. |
| `loadingEntities` | `boolean` | Shows a spinner on the Tables tab. |
| `loadingOperations` | `boolean` | Shows a spinner on the Actions and Functions tabs. |
| `loadingSolution` | `boolean` | Shows a spinner while the solution's components load. |
| `selected` | `Record<SelectionKind, string[]>` | Selected names per tab. |
| `missing` | `Record<SelectionKind, string[]>` | Names in the config that the connected environment doesn't have. |
| `disabled` | `boolean` | Disables the checkboxes and Clear button. |
| `needsProject` | `boolean` (optional) | No project open: instead of the tables it says to create or open a project (step 1), hides the row count, and disables the tabs, search box, solution filter, **Custom only** and **Selected only** switches, and **Clear**. `App.tsx` only lists tables, solutions and the `$metadata` operations once a project is open. |
| `rowLimit` | `number` (optional) | Most rows listed at once. Defaults to 500. `App.tsx` passes the `general.selectionRowLimit` setting. |
| `onToggle` | `(kind, name, checked) => void` | Selects or deselects one item. |
| `onClear` | `(kind: SelectionKind) => void` | Clears the current tab's selection. |
| `onSolutionChange` | `(solutionId: string \| null) => void` | Changes the solution filter. |
| `onEnsureOperations` | `() => void` | Called when the Actions or Functions tab opens, so the `$metadata` document is only fetched when needed. |

`SelectionKind` is `'entities' | 'actions' | 'functions'`, one per tab.

## Behavior

- **Tabs:** Tables, Actions and Functions, each with an icon and a tooltip describing what it lists.
- **Filters:** a search box, a solution dropdown, **Selected only**, and on the Actions and Functions tabs
  **Custom only** (custom APIs and custom process actions).
- **Sorting:** actions and functions list custom APIs first, then sort by name ignoring case.
- **Row limit:** the list shows at most `rowLimit` rows (500 by default); the footer says "Showing the first
  *N* of *M* matches" and asks you to refine the search when there are more.
- **Tables:** each tab lists its items in a Fluent UI `Table` with a checkbox column. Clicking a row, its
  checkbox, or pressing Space or Enter on it toggles the selection; selected rows are highlighted. Column
  headers are semibold and stay visible while the list scrolls.
  - **Tables tab:** Display Name, Logical Name, Schema Name, Description, and Type: a **Standard**,
    **Activity**, **Virtual** or **Elastic** badge. The type comes from the table metadata's `TableType`
    (Standard, Virtual, Elastic) and `IsActivity`, since activity tables report `TableType: Standard`
    (`toTableType` in `services/metadataProvider.ts`). Long descriptions are cut to one line, with the full text in a Fluent UI `Tooltip` on
    hover; tables without one show a dash.
  - **Actions and Functions tabs:** Name (display name above the unique name when they differ), Binding
    (Bound to a table, or Unbound), Parameters, and Type (**Custom API**, **Private custom API** or **Custom
    action** badges, or Built-in). Custom APIs missing from `$metadata` show **From definition** under
    Parameters: their types are built from the custom API definition.
- **Missing items:** names that are in the config but not in the environment are listed above the list.
  They stay in the config and are skipped when generating.

## Where the code lives

- `components/cards/SelectionCard.tsx`: the card: tabs, filters, solution filter, row limit and missing items.
- `components/cards/selectionRows.tsx`: `buildEntityRows` and `buildOperationRows`, pure functions that filter the
  entities or operations, order them, and build the cells and sort values of each row; also `operationType`.
- `components/tables/SelectionTable.tsx`: the table (a checkbox per row, sortable columns) and the `SelectionRow`
  type.
- `components/tables/selectionColumns.tsx`: the column definitions per tab (`ENTITY_COLUMNS`, `ACTION_COLUMNS`,
  `FUNCTION_COLUMNS`) with their header tooltips, and the badge colour per table type (`TABLE_TYPE_COLORS`).
- `components/shared/sorting.ts`: `sortSelectionRows`, which sorts the rows by the chosen column, listing rows
  without a value last.
- `components/tables/SortableHeaderCell.tsx`, `nextSort` in `components/shared/sorting.ts` and
  `components/tables/tableRows.ts`: the header cell, sort toggling and Enter/Space row handling shared by the
  sortable tables (Select card, Preview card, Load Existing Project dialog), styled by `useSortableTableStyles`.
