# TODO file template (Phases 4, 6 and 7)

<!-- cspell:ignore toplevel -->

Phase 4 creates the file before any change. Phase 7 edits the same file after execution; nothing else in
`docs/todos/` (including the tool folders) is touched.

## File name

`docs/todos/<tool-name>/refactoring-<tool-name>-<YYYY-MM-DD>.md` (one folder per tool); if it exists, `-02`, `-03`, … before `.md`. Never overwrite:

```powershell
$dir  = Join-Path (git rev-parse --show-toplevel) 'docs/todos/<tool-name>'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$base = "refactoring-<tool-name>-$(Get-Date -Format 'yyyy-MM-dd')"
$path = Join-Path $dir "$base.md"; $n = 2
while (Test-Path $path) { $path = Join-Path $dir ('{0}-{1:00}.md' -f $base, $n); $n++ }
# Write the content with a create-only operation (for example the Write tool on a path that doesn't exist yet,
# or New-Item -ItemType File without -Force followed by Set-Content).
```

## Content written in Phase 4

```markdown
# Refactoring: <tool-name> (<YYYY-MM-DD>)

<!-- cspell:ignore <one-off words, if any> -->

| | |
| --- | --- |
| Tool | `tools/<tool-name>` (<displayName>, <version>) |
| Date | <YYYY-MM-DD> |
| Skill | `aidevme-pptb-tool-refactoring` |
| Decision | Accepted all / Accepted selected steps: S1, S3 / Saved as TODO only |
| Status | Planned / Saved as TODO, no changes made |
| Proposal version | v<n>, reviewed at commit <short SHA> on `<branch>` |

## TODO

- [ ] S1: <change> (files: `...`; effort S; risk Low). Approved
- [ ] S2: <change> (files: `...`; effort M; risk Medium). Not approved
- [ ] S3: <change> (files: `...`; effort S; risk Low). Approved

## Analysis

<the full Phase 2 proposal: a) current state, b) refactoring plan, c) risk analysis, d) summary — headings one level
lower than in the proposal>
```

After "Save as TODO only", leave every step without an approval note: they're all open work for later.

## Changes made in Phase 7

1. Header: `Status` becomes `Executed` or `Partially executed`; add a row `Branch and commits` with
   `` `<branch>`, <first SHA>..<last SHA> ``.
2. `## TODO`: tick completed steps and add the commit, for example `- [x] S1: ... Done in abc1234`; leave skipped and
   failed steps open with the reason (`Not approved`, `Failed: build error ..., reverted`).
3. Append at the end:

```markdown
## Execution report

### Steps

| ID | Step | Result | Commit | Notes |
| --- | --- | --- | --- | --- |
| S1 | ... | Completed | abc1234 | |
| S2 | ... | Skipped (not approved) | | |
| S3 | ... | Failed (reverted) | | build error: ... |

### Files changed

<git diff --stat for the steps' commits>

### Verification

| Step | Command | Exit code | Result |
| --- | --- | --- | --- |
| S1 | npm run build | 0 | OK |
| S1 | npm test | 0 | 203 passed |

Not verified: <for example live PPTB host, dark theme>

Microsoft Learn pages used: <URLs the fixes relied on, found through the Microsoft Learn MCP Server; or "none">

## Follow-up TODOs

- [ ] <recommended next action, for example "Test Generate in PPTB, light and dark theme">
```

Skipped and failed steps stay open in `## TODO`; `## Follow-up TODOs` holds the other next actions. If nothing
remains, write one item: `- [ ] Re-run the analysis after the next feature change`.
