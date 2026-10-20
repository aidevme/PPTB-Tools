# Function: CustomTemplatesPopover()

> **CustomTemplatesPopover**(`__namedParameters`): `Element`

Defined in: components/popovers/CustomTemplatesPopover.tsx:52

The Custom Templates button and its popover. The button has a count badge of the saved choices: opens a popover with a tile per kind of
generated file (Actions, Complex Types, Entities, Enums, Functions, Metadata), one per row. Each tile has an icon,
a checkbox with an info label naming its files and dataverse-gen template, and the output location on the right; a click
anywhere on the tile toggles it, and checked tiles are highlighted.

## Parameters

### \_\_namedParameters

[`ICustomTemplatesPopoverProps`](../interfaces/ICustomTemplatesPopoverProps.md)

## Returns

`Element`

## Remarks

The header has Select all and Clear, and an info bar says the choices are saved but not used yet. The tiles edit a
draft that starts from `selection` each time the popover opens: OK (with "n of 6 selected" beside it) saves it and
closes the popover; Cancel, Escape or a click outside closes it without saving.
