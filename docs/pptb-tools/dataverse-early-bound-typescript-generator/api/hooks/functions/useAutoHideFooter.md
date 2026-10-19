# Function: useAutoHideFooter()

> **useAutoHideFooter**(`pinnedMs`, `slideOutMs`): [`FooterPhase`](../type-aliases/FooterPhase.md)

Defined in: [hooks/useAutoHideFooter.ts:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useAutoHideFooter.ts#L26)

Pins the footer for `pinnedMs` after mount, then slides it out over `slideOutMs` and docks it at the end of the
page.

## Parameters

### pinnedMs

`number`

How long the footer stays pinned, in milliseconds.

### slideOutMs

`number`

How long the slide-out takes, in milliseconds; matches the footer's CSS transition.

## Returns

[`FooterPhase`](../type-aliases/FooterPhase.md)

The footer's current phase.

## Remarks

If the page is already scrolled to the end (or doesn't scroll), the docked footer would sit exactly where
the pinned one is, so it docks straight away instead of sliding out and back in. The timers are cleared on
unmount.
