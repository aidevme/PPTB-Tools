# D365 F&O / Bnext timesheet entry mechanics

Hard-won detail for entering an **approved** draft into the timesheet system. Read this only after
the user has approved the draft. Entry is via Claude-in-Chrome against the F&O web client.

- Workspace: `PSOTSTimesheetUserWorkSpace`
- Env: `bnext-prd.operations.dynamics.com`, company **DAT**
- Weekly sheets sit under the **Due** tile; line type `60.Work hours`.
- Status flow: **Created (draft) -> Submit**. **Never Submit without a separate explicit OK.**

## Golden rules

1. **Create EVERY line fresh with "+ Hours".** Set Project + Activity by type-ahead + Tab to
   resolve each lookup, then Value, then comment. ~22-27 lines for a granular week.
2. **Billable hours auto-fills = Value.** Leave it (setting it to 0 does not hold).
3. **DO NOT use "Duplicate", "Duplicate to rest of week", or "Copy period".** Duplicated rows fail
   at save with *"Unable to find a unique WBS record"* / *"Activity must be filled"* and **lock the
   entire sheet**. "Copy period" also zeroes Values. Fresh "+ Hours" lines are the only reliable
   path. Multi-select duplicate is disabled (one row at a time).

## View setup for browser automation

- Full-size Chrome window at 100% page zoom, then set CSS `document.body.style.zoom='0.67'` via JS
  **and** collapse the Details FastTab -> all ~22 rows + the External-comment column are visible at
  stable coordinates (no vertical scroll; the grid resists scrolling anyway).
- A small/zoomed window shrinks the viewport (<700px) and the grid becomes unusable.

## Reliable per-row VALUE entry (keyboard, position-independent - the winning method)

`+ Hours`; then keyboard only:
- `Tab Tab` (to Project), type `RBX Architect` + `Tab` (resolves -> Activity),
- type `Algemene` + `Tab Tab Tab` (Work item has an extra tab-stop, so 3 Tabs land on Value),
- `ctrl+a` + value + `Tab`.

A new "+ Hours" row **inherits the active row's weekday** (within a day, no weekday step needed).
New rows insert **after the selected row** - select the last row first to append at the bottom and
keep each day's rows contiguous.

## Weekday (first row of each new day) = its OWN separate batch

Open the Weekday dropdown chevron, arrow `Down` to the target day, `Return`. **NEVER combine the
weekday-dropdown change and the value-fill in one action batch** - it triggers a *"Select a record
type to create"* modal + blank/corrupt rows that lock the sheet (very hard to recover).

## Comments: enter DOWN the External-comment column

Double-click each cell directly, **no Tab between cells**. Tab from a comment scrolls the grid
horizontally, so the next fixed-x click lands in the WRONG column (e.g. pollutes the *Remote*
combobox).
- **Empty** comment cell: double-click + type only (NO `ctrl+a` - on an empty cell `ctrl+a` leaks a
  stray leading "a").
- **Existing** comment: `ctrl+a` then type to overwrite.

Keep comments ASCII, <=128 chars, no `+ > < = | * ~ ^` (see SKILL.md Comment rules).

## Verify

Verify by **reopening the record** and reading the line values - the Due-list "Created/Total hours"
aggregate is **stale after back-nav** (showed 25.50 when the record actually held 31.5h). Save per
day; saved rows persist even if the buffer/aggregate looks wrong.

## Browser-stability recovery (Claude-in-Chrome)

- The extension disconnects mid-session - reconnect + re-select the "Hso Work" browser.
- A stuck F&O modal / dirty form **freezes the shared renderer** (screenshots time out) -> remove
  the modal via JS `dialog.remove()`, and `window.stop()` + clear all timers on the stuck tab.
- A dirty form's `beforeunload` blocks tab close/reload; the navigate tool's `force:true` discards a
  lightly-dirty tab to reload clean but FAILS on a heavily-stuck one.
- Bundle `{JS window.stop on stuck tab}` + `{screenshot}` in ONE batch for reliable captures.

## Auth

To the env: see the device-code / refresh-token path in the shared `Dataverse-Auth.ps1` (the
`contoso-device-login-msal-broken` memory). One sign-in shared across chats.
