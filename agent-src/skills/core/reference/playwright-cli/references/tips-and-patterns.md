# Playwright CLI Tips & Patterns

## Browser Setup

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

## Token Efficiency

### Searching snapshots with Grep instead of Read
Snapshot YAML files for complex pages (e.g., Dynamics 365 forms) can be 400+ lines with hundreds of element refs. **Do not read the full YAML file.** Instead, use Grep to search for the specific element you need:

```
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

## Dynamics 365 Patterns

### Collapsing the left navigation
Click the "Site Map" button to toggle the left nav panel for cleaner screenshots:
```bash
# Find the ref first with grep
Grep "Site Map" in .playwright-cli/page-*.yml
# Then click it
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
# Output: button "Maintenance Summary section. Currently collapsed. Press Enter to expand."
playwright-cli click e1946  # ref will vary
```

### Waiting for content to load
D365 PCF controls and subgrids load asynchronously. Always wait after navigation or tab switches:
```bash
playwright-cli run-code "async page => { await page.waitForTimeout(3000); }"
```

## Screenshot Workflow

Recommended sequence for capturing D365 form tabs:
1. Open browser headed + persistent + maximized
2. Authenticate (user does this manually)
3. Maximize window via CDP
4. Collapse left nav for cleaner shots
5. For each tab:
   - Click the tab (use grep to find ref)
   - Wait 2-3 seconds for async content
   - Take screenshot, review it
   - If content is cut off, zoom out by 10% and retake
6. Close browser when done