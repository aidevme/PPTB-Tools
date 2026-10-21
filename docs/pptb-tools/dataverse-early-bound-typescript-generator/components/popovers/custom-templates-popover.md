# CustomTemplatesPopover

<!-- cspell:ignore complextype complextypes -->

The **Custom Templates** button on the [PreviewCard](../cards/preview-card.md)'s switch row and the popover it opens:
a tile per kind of generated file whose custom template the project wants. The choices are saved with the project
but don't change the output yet; the popover says so.

Source: [`src/components/popovers/CustomTemplatesPopover.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/popovers/CustomTemplatesPopover.tsx),
styles in `src/styles/CustomTemplatesPopover.styles.ts` (`useCustomTemplatesPopoverStyles`), and each kind's label, icon,
location and info text in `Popovers.const.tsx` (`CUSTOM_TEMPLATE_LABELS`).

## Props (`ICustomTemplatesPopoverProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `selection` | `CustomTemplateSelection` | The project's choices, one per kind. |
| `disabled` | `boolean` | Disables the button (no project open, or work in progress). |
| `onChange` | `(selection: CustomTemplateSelection) => void` | Called with every kind's value when **OK** is clicked; not on **Cancel**. |

`PreviewActionBar` (in `cards/parts/PreviewParts.tsx`) renders it when the Preview card has `onCustomTemplatesChange`,
with `customTemplates` as `selection` (every kind off when unset) and `disabled` while busy or while
`customTemplatesDisabled` is set. `App.tsx` stores the choices in the project's config with
`withProjectCustomTemplates` (`pptbEarlyBoundGenerator.customTemplates`) and doesn't mark the preview stale
(`updateConfig(…, { markStale: false })`); they're saved with the project on the next Generate.

## Button

**Custom Templates** with a `DocumentSettingsRegular` icon and a `CounterBadge` with the number of saved choices
(hidden at 0, labelled "*n* selected").

## Popover

A `Popover` with an arrow and focus trapped inside, on a wider surface with a larger radius and shadow:

- **Header:** an icon, the title ("Custom templates", also the surface's accessible name), and **Select all** and
  **Clear** links, each disabled when it would change nothing.
- **Info bar:** an info `MessageBar`: the choices are saved with the project but don't change the output yet.
- **Tiles**, one per row, for the kinds in `CUSTOM_TEMPLATE_KINDS` (`core/config.ts`):

  | Tile | Icon | Location | dataverse-gen template |
  | --- | --- | --- | --- |
  | Actions | `FlashRegular` | `actions/` | `action.ejs` |
  | Complex Types | `BracesRegular` | `complextypes/` | `complextype.ejs` |
  | Entities | `TableRegular` | `entities/` | `entity.ejs` |
  | Enums | `NumberSymbolRegular` | `enums/` | `enum.ejs` |
  | Functions | `MathFormulaRegular` | `functions/` | `function.ejs` |
  | Metadata | `DatabaseRegular` | `metadata.ts` | `metadata.ejs` |

  Each tile has its icon, a `Checkbox` with an info label (`infoLabel`) naming the files and the template, and the
  location on the right. The checkbox is the control (keyboard and screen readers use it); a click on the rest of
  the tile toggles it too. Checked tiles are highlighted in the brand colour. Enums is separate from the
  **Custom enum template** switch, which its info label says.
- **Footer:** a `Divider`, then "*n* of 6 selected", **OK** and **Cancel**.

## Draft, OK and Cancel

The tiles edit a draft that starts from `selection` each time the popover opens. **OK**, enabled once the draft
differs from `selection`, calls `onChange` and closes the popover. **Cancel**, Escape or a click outside closes it
without saving.
