# Report and saved file template (Phase 5 and 6)

<!-- cspell:ignore toplevel -->

## File name

`docs/todos/refactoring-<tool-name>-<YYYY-MM-DD>.md`; if it exists, `-02`, `-03`, … before `.md`. Never overwrite:

```powershell
$dir  = Join-Path (git rev-parse --show-toplevel) 'docs/todos'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$base = "refactoring-<tool-name>-$(Get-Date -Format 'yyyy-MM-dd')"
$path = Join-Path $dir "$base.md"; $n = 2
while (Test-Path $path) { $path = Join-Path $dir ('{0}-{1:00}.md' -f $base, $n); $n++ }
# Write the content with a create-only operation (for example the Write tool on a path that doesn't exist yet,
# or New-Item -ItemType File without -Force followed by Set-Content).
```

## Content

```markdown
# Refactoring: <tool-name> (<YYYY-MM-DD>)

<!-- cspell:ignore <one-off words, if any> -->

| | |
| --- | --- |
| Tool | `tools/<tool-name>` (<displayName>, <version>) |
| Date | <YYYY-MM-DD> |
| Skill | `aidevme-pptb-tool-refactoring` |
| Approval decision | Accepted all / Accepted selected steps: S1, S3 |
| Proposal version | v<n> |
| Branch and commits | `<branch>`, <first SHA>..<last SHA> |

## Analysis

<the full Phase 2 proposal: a) current state, b) refactoring plan, c) risk analysis, d) summary — headings one level
lower than in the proposal>

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

## Follow-up TODOs

- [ ] S2: <skipped step, why, what it would take>
- [ ] S3: <failed step, cause, suggested fix>
- [ ] <recommended next action, for example "Test Generate in PPTB, light and dark theme">
```

Every skipped and failed step gets a TODO; recommended next actions follow. If nothing remains, write one item:
`- [ ] Re-run the analysis after the next feature change`.
