---
name: playwright-cli
layer: atomic
scope: core
description: Automates browser interactions for web testing, form filling, screenshots, and data extraction. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages.
allowed-tools: Bash(playwright-cli:*)
---

# Browser Automation with playwright-cli

## Authoritative Best Practices

Read [`shared/dv/agent/wiki/sop/testing/playwright-testing-best-practices.md`](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md) before driving D365 (CE / F&O / Power Pages) UIs with this CLI. The session-management, daemon-safety (one-shell-per-session, relative-paths-only, post-screenshot PID check), timing, speed, and F&O grid-cell `eval` workarounds in §4 are load-bearing — they come from a real prior-engagement incident on 2026-05-18 where re-opening the browser inside a session and using an absolute Windows path in `--filename` destroyed the authenticated state silently. Selector strategy (§6) and the requirement→Test Case→`.spec.ts` traceability proposal (§2) apply when generating scripted tests from an interactive run.

Authority for PCF-control testing and MCP-server token efficiency — read [`pcf-control-testing-best-practices.md`](../../../agent/wiki/sop/testing/pcf-control-testing-best-practices.md) before testing a PCF control or applying the token-efficiency rules below.

| Task | Primary authority |
|---|---|
| Driving D365 CE / F&O / Power Pages UIs interactively (session, daemon safety, timing, F&O grid quirks) | playwright-testing-best-practices.md §4 |
| Passing a non-trivial snippet to `run-code` on Windows (quoting, base64 file runner) | playwright-testing-best-practices.md §4.6 |
| Fluent UI / PCF / web-resource interaction recipes | playwright-testing-best-practices.md §4.8 |
| A frame or control that "isn't there" — attach timing, render throttling, detach-on-reload | playwright-testing-best-practices.md §4.10 |
| Selector strategy / generating scripted `.spec.ts` from a run | playwright-testing-best-practices.md §6, §2, §5 |
| Testing a deployed PCF control / MCP token-efficiency rules | pcf-control-testing-best-practices.md |

## Quick start

```bash
# open new browser
playwright-cli open
# navigate to a page
playwright-cli goto https://playwright.dev
# interact with the page using refs from the snapshot
playwright-cli click e15
playwright-cli type "page.click"
playwright-cli press Enter
# take a screenshot
playwright-cli screenshot
# close the browser
playwright-cli close
```

## Commands

### Core

```bash
playwright-cli open
# open and navigate right away
playwright-cli open https://example.com/
playwright-cli goto https://playwright.dev
playwright-cli type "search query"
playwright-cli click e3
playwright-cli dblclick e7
playwright-cli fill e5 "user@example.com"
playwright-cli drag e2 e8
playwright-cli hover e4
playwright-cli select e9 "option-value"
playwright-cli upload ./document.pdf
playwright-cli check e12
playwright-cli uncheck e12
playwright-cli snapshot
playwright-cli snapshot --filename=after-click.yaml
playwright-cli eval "document.title"
playwright-cli eval "el => el.textContent" e5
playwright-cli dialog-accept
playwright-cli dialog-accept "confirmation text"
playwright-cli dialog-dismiss
playwright-cli resize 1920 1080
playwright-cli close
```

### Navigation

```bash
playwright-cli go-back
playwright-cli go-forward
playwright-cli reload
```

### Keyboard

```bash
playwright-cli press Enter
playwright-cli press ArrowDown
playwright-cli keydown Shift
playwright-cli keyup Shift
```

### Mouse

```bash
playwright-cli mousemove 150 300
playwright-cli mousedown
playwright-cli mousedown right
playwright-cli mouseup
playwright-cli mouseup right
playwright-cli mousewheel 0 100
```

### Save as

```bash
playwright-cli screenshot
playwright-cli screenshot e5
playwright-cli screenshot --filename=page.png
playwright-cli pdf --filename=page.pdf
```

### Tabs

```bash
playwright-cli tab-list
playwright-cli tab-new
playwright-cli tab-new https://example.com/page
playwright-cli tab-close
playwright-cli tab-close 2
playwright-cli tab-select 0
```

### Storage

```bash
playwright-cli state-save
playwright-cli state-save auth.json
playwright-cli state-load auth.json

# Cookies
playwright-cli cookie-list
playwright-cli cookie-list --domain=example.com
playwright-cli cookie-get session_id
playwright-cli cookie-set session_id abc123
playwright-cli cookie-set session_id abc123 --domain=example.com --httpOnly --secure
playwright-cli cookie-delete session_id
playwright-cli cookie-clear

# LocalStorage
playwright-cli localstorage-list
playwright-cli localstorage-get theme
playwright-cli localstorage-set theme dark
playwright-cli localstorage-delete theme
playwright-cli localstorage-clear

# SessionStorage
playwright-cli sessionstorage-list
playwright-cli sessionstorage-get step
playwright-cli sessionstorage-set step 3
playwright-cli sessionstorage-delete step
playwright-cli sessionstorage-clear
```

### Network

```bash
playwright-cli route "**/*.jpg" --status=404
playwright-cli route "https://api.example.com/**" --body='{"mock": true}'
playwright-cli route-list
playwright-cli unroute "**/*.jpg"
playwright-cli unroute
```

### DevTools

```bash
playwright-cli console
playwright-cli console warning
playwright-cli network
playwright-cli run-code "async page => await page.context().grantPermissions(['geolocation'])"
playwright-cli tracing-start
playwright-cli tracing-stop
playwright-cli video-start
playwright-cli video-stop video.webm
```

### Install

```bash
playwright-cli install --skills
playwright-cli install-browser
```

### Configuration
```bash
# Use specific browser when creating session
playwright-cli open --browser=chrome
playwright-cli open --browser=firefox
playwright-cli open --browser=webkit
playwright-cli open --browser=msedge
# Connect to browser via extension
playwright-cli open --extension

# Use persistent profile (by default profile is in-memory)
playwright-cli open --persistent
# Use persistent profile with custom directory
playwright-cli open --profile=/path/to/profile

# Start with config file
playwright-cli open --config=my-config.json

# Close the browser
playwright-cli close
# Delete user data for the default session
playwright-cli delete-data
```

### Browser Sessions

```bash
# create new browser session named "mysession" with persistent profile
playwright-cli -s=mysession open example.com --persistent
# same with manually specified profile directory (use when requested explicitly)
playwright-cli -s=mysession open example.com --profile=/path/to/profile
playwright-cli -s=mysession click e6
playwright-cli -s=mysession close  # stop a named browser
playwright-cli -s=mysession delete-data  # delete user data for persistent session

playwright-cli list
# Close all browsers
playwright-cli close-all
# Forcefully kill all browser processes
playwright-cli kill-all
```

## Example: Form submission

```bash
playwright-cli open https://example.com/form
playwright-cli snapshot

playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "password123"
playwright-cli click e3
playwright-cli snapshot
playwright-cli close
```

## Example: Multi-tab workflow

```bash
playwright-cli open https://example.com
playwright-cli tab-new https://example.com/other
playwright-cli tab-list
playwright-cli tab-select 0
playwright-cli snapshot
playwright-cli close
```

## Example: Debugging with DevTools

```bash
playwright-cli open https://example.com
playwright-cli click e4
playwright-cli fill e7 "test"
playwright-cli console
playwright-cli network
playwright-cli close
```

```bash
playwright-cli open https://example.com
playwright-cli tracing-start
playwright-cli click e4
playwright-cli fill e7 "test"
playwright-cli tracing-stop
playwright-cli close
```

## Authenticated Sites (Dynamics 365 / Dataverse)

### Headed mode for manual authentication
When navigating to authenticated sites (e.g., Dynamics 365), open in headed mode so the user can log in:
```bash
playwright-cli open "https://example.crm.dynamics.com/..." --browser=msedge --headed --persistent
```
- `--headed` shows the browser window (default is headless)
- `--persistent` keeps the session profile on disk so auth survives across commands
- `--browser=msedge` uses Edge (useful for Microsoft SSO)

### Maximizing the browser window
`playwright-cli resize 1920 1080` only sets the viewport, not the OS window. To actually maximize the headed browser window, use CDP:
```bash
playwright-cli run-code "async page => { const cdp = await page.context().newCDPSession(page); const {windowId} = await cdp.send('Browser.getWindowForTarget'); await cdp.send('Browser.setWindowBounds', {windowId, bounds: {windowState: 'maximized'}}); }"
```

### Zooming out for full-page captures
When content extends below the viewport, zoom out in 10% increments until everything fits:
```bash
playwright-cli run-code "async page => { await page.evaluate(() => { document.body.style.zoom = '90%'; }); await page.waitForTimeout(1000); }"
```
Reset to 100% when switching tabs or contexts if the new content doesn't need zoom adjustment.

### Passing a long snippet to `run-code` on Windows
Don't fight the shell. PowerShell-then-`cmd.exe` mangles `"`, `&`, `'`, `$`, `|` and `&&` inside the `run-code` argument, and a mis-escape does not error — it runs a *different* command. Write the snippet to a `.js` file as a single `(async (page) => { … })`, base64-encode the file, and decode it inside `page.evaluate` (browser scope has `atob` + `TextDecoder`; the `run-code` node scope has **no** `Buffer`/`atob`/`location`/`require`/`fs`). Full runner script and caveats: [`playwright-testing-best-practices.md §4.6`](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md).

### Cropped screenshots — scale the clip by `devicePixelRatio`
`page.screenshot({clip})` applies its rect to the captured **bitmap**, but `getBoundingClientRect()` returns **CSS** pixels. On a scaled display (`devicePixelRatio` 0.75 is common on Windows laptops) the raw rect produces an image offset up-and-left by ~25% — close enough to the target that it reads as a wrong selector rather than a scaling bug. Read the ratio at runtime and multiply the rect; `locator.screenshot()` is offset identically, so prefer the explicit clip. See [`playwright-testing-best-practices.md §4.11`](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md).

### Waiting for content to load (digest only — [`playwright-testing-best-practices.md §4.3`](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md) is authoritative; read it before driving D365)
D365 PCF controls and subgrids load asynchronously, but standalone waits are a documented session-killer. Per the SOP: prefer `snapshot` to check readiness (it returns immediately if the elements exist); if you must wait, embed at most 1000 ms inside an interaction — never a standalone 3000/5000 ms wait, and never run `run-code` as a standalone command (it can spawn a new daemon and destroy the authenticated session).

## Dynamics 365 Patterns

### Collapsing the left navigation
Click the "Site Map" button to toggle the left nav panel for cleaner screenshots:
```bash
Grep "Site Map" in .playwright-cli/page-*.yml
playwright-cli click e41  # ref will vary
```

### Navigating form tabs
D365 form tabs appear as `tab` roles in the accessibility tree:
```bash
Grep "tab.*Properties|tab.*Maintenance" in .playwright-cli/page-*.yml
playwright-cli click e866  # ref will vary per form
```

### Expanding collapsed sections
D365 sections show their state in the button name:
```bash
Grep "collapsed|expanded" in .playwright-cli/page-*.yml
playwright-cli click e1946  # ref will vary
```

### D365 Screenshot Workflow (digest only — [`playwright-testing-best-practices.md §4`](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md) is authoritative; read it before running a session)
Recommended sequence for capturing D365 form tabs:
1. Open browser headed + persistent + maximized
2. Authenticate (user does this manually)
3. Maximize window via CDP
4. Collapse left nav for cleaner shots
5. For each tab:
   - Click the tab (use grep to find ref)
   - Check readiness with `snapshot` (returns immediately if elements exist) rather than a fixed wait; if a wait is unavoidable keep it <=1000 ms embedded in the interaction per SOP §4.3
   - Take screenshot, review it
   - If content is cut off, zoom out by 10% and retake
6. Close browser when done

## Token Efficiency

### Search snapshots with Grep instead of Read
Snapshot YAML files for complex pages (e.g., Dynamics 365 forms) can be 400+ lines with hundreds of element refs. **Do not read the full YAML file.** Instead, use Grep to search for the specific element you need:

```bash
# BAD: Reading the full 400-line YAML (wastes tokens)
Read .playwright-cli/page-2026-02-12T16-47-09-714Z.yml

# GOOD: Grep for the specific element you need
Grep "Properties|Maintenance Dashboard|Maintenance Timeline" in .playwright-cli/page-*.yml
```

This is especially important for Dynamics 365 forms which have deeply nested accessibility trees with command bars, navigation, subgrids, and timeline controls.

### When you do need the full snapshot
- First snapshot on a new page to understand the overall structure
- When you can't predict the element name to grep for

### Avoiding redundant snapshots
The output of `playwright-cli click`, `playwright-cli snapshot`, and other commands already includes a snapshot file path. Don't re-read the file if the command output already told you what you need (e.g., the page URL and title confirm you're on the right tab).

## Specific tasks

* **Tips & patterns (D365, token efficiency)** [references/tips-and-patterns.md](references/tips-and-patterns.md)
* **Request mocking** [references/request-mocking.md](references/request-mocking.md)
* **Running Playwright code** [references/running-code.md](references/running-code.md)
* **Browser session management** [references/session-management.md](references/session-management.md)
* **Storage state (cookies, localStorage)** [references/storage-state.md](references/storage-state.md)
* **Test generation** [references/test-generation.md](references/test-generation.md)
* **Tracing** [references/tracing.md](references/tracing.md)
* **Video recording** [references/video-recording.md](references/video-recording.md)

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
