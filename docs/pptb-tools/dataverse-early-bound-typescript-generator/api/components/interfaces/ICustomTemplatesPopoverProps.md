# Interface: ICustomTemplatesPopoverProps

Defined in: components/popovers/CustomTemplatesPopover.tsx:30

Props for [CustomTemplatesPopover](../functions/CustomTemplatesPopover.md).

## Properties

### disabled

> **disabled**: `boolean`

Defined in: components/popovers/CustomTemplatesPopover.tsx:34

Disables the button (work in progress, or no project open).

***

### onChange

> **onChange**: (`selection`) => `void`

Defined in: components/popovers/CustomTemplatesPopover.tsx:36

Called with every kind's value when OK is clicked; not called on Cancel.

#### Parameters

##### selection

[`CustomTemplateSelection`](../../core/type-aliases/CustomTemplateSelection.md)

#### Returns

`void`

***

### selection

> **selection**: [`CustomTemplateSelection`](../../core/type-aliases/CustomTemplateSelection.md)

Defined in: components/popovers/CustomTemplatesPopover.tsx:32

The project's choices, one checkbox per kind.
