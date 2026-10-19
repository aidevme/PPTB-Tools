# Function: useStickyBarHeights()

> **useStickyBarHeights**(`header`, `footer`, `footerPinned?`): `void`

Defined in: [hooks/useStickyBarHeights.ts:14](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useStickyBarHeights.ts#L14)

Publishes the heights of the sticky header and footer as the CSS variables `--app-header-height` and
`--app-footer-height` on `<html>`, and keeps them current as the bars resize (the header wraps on narrow tool
tabs). `index.css` turns them into `scroll-padding`, so scrolling to a step card lands below the header instead
of under it.

## Parameters

### header

`RefObject`\<`HTMLElement` \| `null`\>

The sticky header's wrapper.

### footer

`RefObject`\<`HTMLElement` \| `null`\>

The footer's wrapper.

### footerPinned?

`boolean` = `true`

Whether the footer is pinned over the content; once it's docked at the end of the page it
covers nothing, so its height is published as `0px`.

## Returns

`void`
