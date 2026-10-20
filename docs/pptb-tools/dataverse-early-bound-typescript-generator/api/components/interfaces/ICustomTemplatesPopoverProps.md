# Interface: ICustomTemplatesPopoverProps

Defined in: [components/popovers/CustomTemplatesPopover.tsx:30](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/popovers/CustomTemplatesPopover.tsx#L30)

Props for [CustomTemplatesPopover](../functions/CustomTemplatesPopover.md).

## Properties

### disabled

> **disabled**: `boolean`

Defined in: [components/popovers/CustomTemplatesPopover.tsx:34](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/popovers/CustomTemplatesPopover.tsx#L34)

Disables the button (work in progress, or no project open).

***

### onChange

> **onChange**: (`selection`) => `void`

Defined in: [components/popovers/CustomTemplatesPopover.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/popovers/CustomTemplatesPopover.tsx#L36)

Called with every kind's value when OK is clicked; not called on Cancel.

#### Parameters

##### selection

[`CustomTemplateSelection`](../../core/type-aliases/CustomTemplateSelection.md)

#### Returns

`void`

***

### selection

> **selection**: [`CustomTemplateSelection`](../../core/type-aliases/CustomTemplateSelection.md)

Defined in: [components/popovers/CustomTemplatesPopover.tsx:32](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/popovers/CustomTemplatesPopover.tsx#L32)

The project's choices, one checkbox per kind.
