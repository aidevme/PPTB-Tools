---
name: hso-ado-pull-requests
layer: atomic
scope: core
description: |
  Create, update, query, and comment on Azure DevOps pull requests via the REST API. Use when:
  (1) User asks to "create a PR", "open a pull request", or "push and open PR"
  (2) User asks to update an existing PR's title or description
  (3) User asks to list, get, or look up PRs in a repo / branch
  (4) User asks to comment on a PR or link work items to a PR
  (5) Existing CLI-based PR creation produced mangled non-ASCII characters (em-dashes, §, smart quotes, etc.) in the description and a clean re-create or update is needed
  Uses PowerShell with settings-resolved auth and posts UTF-8 bodies directly to the ADO REST API, sidestepping the `az` CLI's Windows ANSI-codepage issue with non-ASCII characters. Does NOT replace the `az repos pr` CLI for read-only browsing or `gh pr` for GitHub.
---

# HSO Azure DevOps Pull Requests

Create, update, query, comment on, and link work items to Azure DevOps pull requests using the `Invoke-AdoPullRequestOperation.ps1` script.

**Why this exists:** `az repos pr create --description "..."` mangles non-ASCII characters (em-dashes, `§`, smart quotes, accented letters) on Windows because PowerShell passes the argument through the active ANSI code page (cp1252) before `az` sees it — the UTF-8 bytes get re-interpreted as Latin-1 and corrupted into `�` replacement chars. This skill posts the body directly to the ADO REST API as UTF-8 bytes, so any character set the source file can hold ends up intact in the PR.

## When this skill is NOT applicable

The skill scopes itself to Azure DevOps. It will **exit cleanly (no error)** when:

- The working directory is not a git checkout.
- The repo's `origin` remote isn't an Azure DevOps URL (e.g. GitHub, GitLab, local-only with no remote).
- No explicit `-OrgUrl` / `-Project` / `-Repository` were supplied.

In these cases the script prints a short "not applicable" message and exits 0. Agents that invoke the skill speculatively can treat the silent exit as "this repo has no PR workflow here — move on." For GitHub repos use `gh pr create`; for local-only repos no PR step is needed.

If `hso-dataverse-init-repo` recorded "this repo does not require PRs" in the project's `CLAUDE.md`, do not invoke this skill on that repo at all.

## Authentication

**Authentication mode is resolved automatically from settings on script calls.** When browser sign-in is used, the token is cached at `%TEMP%\AdoAuthCache_<hash>.json` for **~1 hour** and reused silently on subsequent calls within that window. `-Pat <token>` remains available as an explicit override when needed.

For scripted batch operations where the first call's browser flow would be intrusive, warm the cache up front with a cheap read: `-Operation Get -PullRequestId <any-existing-id>` against the target org. The cached bearer token then flows through every subsequent call.

> **GOTCHA — interactive sign-in HANGS in a headless/unattended session (skill-gap #7).** When the `%TEMP%\AdoAuthCache_<hash>.json` token has **expired** and the session has no TTY (an autonomous lane, a CI/cron run, a background agent), the browser sign-in flow has nowhere to prompt and the call **blocks forever** with zero output. Do not diagnose this as a script bug — it is the auth flow waiting on a human that isn't there. For any headless run: pass an explicit **`-Pat <token>`** (PAT auth is non-interactive), or **pre-warm the cache in an attended session** within the ~1-hour window before the unattended work starts. (The register's old workaround was `az repos pr create`; do **not** use it — that reintroduces the non-ASCII mangling this skill exists to avoid. `-Pat` is the correct non-interactive path.)

The script dot-sources the shared modules `..\..\hso-shared-scripts\scripts\Dataverse-Auth.ps1` (for the `Install-MsalModuleIfMissing` bootstrap) and `..\..\hso-shared-scripts\scripts\ADO-Auth.ps1` (for `Get-AdoToken` / `Get-AdoHeaders`). Authentication runs once at script start; the resulting headers are reused across all REST calls in a single invocation. No skill-local auth code.

## Configuration

Read from `CLAUDE.local.md` when present:
- **ADO Org URL** (e.g. `https://dev.azure.com/<OrgName>`)
- **ADO Project** name
- **Repository** name

Or **let the script auto-detect** these from `git remote get-url origin` when the working directory is a clone of an ADO repo. Both Azure DevOps URL shapes (`dev.azure.com/<Org>/<Project>/_git/<Repo>` and the legacy `<Org>.visualstudio.com/<Project>/_git/<Repo>`) are recognised.

Read from `CLAUDE.md`:
- *(none required — repo context comes from git or explicit parameters)*

## Script Path

```
claude-code/skills/hso-ado-pull-requests/scripts/Invoke-AdoPullRequestOperation.ps1
```

All examples below assume the working directory is the repository root.

---

## How to invoke the script (CRITICAL — read this before running anything)

**There is exactly ONE correct way to run this script: call the `.ps1` directly in your *current* PowerShell session with the call operator `&`.** Copy this — it is the proven, first-attempt-works invocation:

```powershell
$out = & "claude-code/skills/hso-ado-pull-requests/scripts/Invoke-AdoPullRequestOperation.ps1" `
    -Operation Create `
    -SourceBranch "feat/your-branch" -TargetBranch "main" `
    -Title "feat(scope): your title" `
    -DescriptionFilePath "agent/work/pr-body.md" *>&1 | Out-String
"EXIT=$LASTEXITCODE"; "OUTPUT:`n$out"
```

Three rules that make it work every time:

1. **Use the call operator `&` on the script path, in the PowerShell session you already have.** Do not spawn a new shell (see the anti-pattern below).
2. **Capture every stream with `*>&1 | Out-String`.** The script writes structured auth-log objects to the information/verbose streams; `2>&1` alone drops them and you lose the auth trace.
3. **Run it in the FOREGROUND and let it finish.** The first call after a cold start can sit for **10–15 seconds with ZERO output** while `MSAL.PS` imports and the token resolves. **This is normal — do NOT background it, do NOT add a short timeout, do NOT kill it.** With a warm token cache it returns in ~2 seconds; on first auth a browser opens once and the token is then cached (~1 h).

### The anti-pattern that wastes hours — DO NOT do this

```powershell
# WRONG — never wrap the script in `powershell -File` / `pwsh -File`:
powershell -ExecutionPolicy Bypass -File "claude-code/skills/hso-ado-pull-requests/scripts/Invoke-AdoPullRequestOperation.ps1" -Operation Create ...
```

The `powershell -File` (or `pwsh -File`) wrapper launches a **brand-new child process** that cold-starts a second runtime, re-imports `MSAL.PS` from scratch, and **cannot see the warm in-memory token in your current session**. The result is 10–15 seconds of total silence that looks exactly like a hang — so it gets killed before the REST call ever fires. **Every "my calls never reach ADO" report traces back to this wrapper.** The fix is always the same: drop the `powershell -ExecutionPolicy Bypass -File` prefix and call `& "<script path>"` directly.

---

## Operations Reference

### 1. CREATE

Creates a new PR. Source branch defaults to the current branch; target branch defaults to `origin/HEAD`. Description should be supplied via a UTF-8 file (`-DescriptionFilePath`) — see §UTF-8 safety below.

```powershell
& "claude-code/skills/hso-ado-pull-requests/scripts/Invoke-AdoPullRequestOperation.ps1" `
    -Operation Create `
    -Title "Short title under 70 chars" `
    -DescriptionFilePath "C:\tmp\pr-body.md" `
    -WorkItemIds "12345,12346"
```

With explicit context (skips git auto-detect):
```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation Create `
    -OrgUrl "https://dev.azure.com/<OrgName>" `
    -Project "<ProjectName>" `
    -Repository "<RepoName>" `
    -SourceBranch "feat/example" `
    -TargetBranch "main" `
    -Title "Short title" `
    -DescriptionFilePath "C:\tmp\pr-body.md"
```

Additional `Create` flags:
- `-IsDraft` — create as draft.
- `-AutoComplete` — set auto-complete-on-policy-satisfaction. Requires creator-level permission; uses no-fast-forward merge strategy by default.
- `-WorkItemIds "12345,12346"` — attach work items at creation time.

### 2. UPDATE

Update title and/or description on an existing PR. Useful for fixing a description after the body was corrupted by a prior `az` CLI invocation.

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation Update `
    -PullRequestId 735 `
    -DescriptionFilePath "C:\tmp\fixed-body.md"
```

### 3. GET

Look up a single PR's status, branches, merge state, and linked-work-item count.

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation Get -PullRequestId 735
```

### 4. LIST

List PRs filtered by status (default `active`) and optionally by source/target branch.

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation List -Status active -TargetBranch main
```

Use `-Status all` to include completed and abandoned PRs. `-Top` caps the result count (default 50).

### 5. ADDCOMMENT

Post a new comment thread to a PR. Body via UTF-8 file (recommended) or `-Comment "<inline>"`.

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation AddComment `
    -PullRequestId 735 `
    -CommentFilePath "C:\tmp\review-note.md"
```

### 6. LINKWORKITEMS

Attach work items to an existing PR. Uses the ADO ArtifactLink pattern (the supported approach — there's no direct PR↔workitem REST endpoint).

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation LinkWorkItems `
    -PullRequestId 735 `
    -WorkItemIds "12345,12346"
```

---

## HSO PR body template

Pass this as a `.md` file to `-DescriptionFilePath`. Markdown renders correctly in the ADO PR description pane.

```markdown
## Summary

Two-to-four sentences describing the change in **business terms** — what
problem it solves, who benefits, why now. Avoid file-level mechanics here.

## Why this matters

One short paragraph or 2–3 bullets connecting the change to delivery
outcomes (risk reduction, time saved, defect class avoided, capability
unlocked, compliance posture).

## Test plan

- [ ] Concrete verification step 1
- [ ] Concrete verification step 2
- [ ] Concrete verification step 3
```

Optional sections to add when relevant:
- `## Screenshots` — for UI changes
- `## Breaking changes` — call out any consumer-facing change
- `## Migration notes` — for schema or interface changes
- `## Linked work items` — bullet list if `-WorkItemIds` wasn't used at create time

## ADO field length limits

Azure DevOps enforces hard limits on PR fields. The script pre-validates **title** and **description** lengths and aborts with a clear error before the network call when they would be rejected; the other limits below are reference-only.

| Field | ADO API hard limit | Script behaviour | HSO style guidance |
|---|---|---|---|
| PR title | **400 characters** | Pre-flight check; throws before the API call | Keep ≤ 70 characters so it fits in branch / commit-history listings without truncation. The full PR body is the right place for nuance — don't pack it into the title. |
| PR description | **4000 characters** at both create AND update time. The API returns `400 InvalidArgumentValue` with no partial-create fallback. | Pre-flight check on Create AND Update; throws before the API call with a message recommending a trim target | Aim for **under ~3500 characters** to leave rendering headroom and stay scannable. Summary in 2–4 sentences, Why-this-matters in one paragraph or 3 bullets, Test plan as a checklist. Move long detail into linked design docs / ADRs — do not dump them into the PR. |
| Comment thread content (`AddComment`) | **150,000 characters** (effectively unlimited for normal use) | No pre-flight; the API limit is rarely hit | One topic per comment thread; long-form review notes belong in a checked-in `.md` deliverable, not inline. |
| Branch ref name | **~250 characters** (Git's general limit; ADO accepts up to the Git ceiling) | No pre-flight | HSO convention: `<type>/<short-slug>` — e.g. `feat/hso-ado-pull-requests`. Avoid encoding metadata in the branch name; that's what work-item links are for. |
| Work item IDs (`-WorkItemIds`) | integer, no length limit | n/a | Comma-separated list, e.g. `"12345,12346"`. The script handles whitespace around commas. |

**Related field limits in sibling skills:**

- `hso-ado-work-items`: System.Title max **255 characters**; System.Description is HTML and effectively unlimited. See [hso-ado-work-items/SKILL.md](../hso-ado-work-items/SKILL.md) for work-item-specific field constraints.

**If the API rejects with HTTP 400** (a limit the script doesn't pre-check, or one ADO added after this doc was written): the response's `value.exception.message` field names the offending field and its limit explicitly. Open an issue / PR to add the pre-flight check.

---

## UTF-8 safety (root cause + how this skill avoids it)

`az repos pr create --description "..."` on Windows passes the argument through PowerShell's argument parser, which converts the UTF-8 bytes of the string literal to the active ANSI code page (cp1252 on most en-US installs). Bytes outside the cp1252 range — em-dashes (`—`, U+2014), section symbols (`§`, U+00A7), smart quotes, accented characters — get replaced with `?` or the U+FFFD replacement character `�`. The mangling is silent.

This skill avoids the issue by:

1. **Reading description / comment bodies from UTF-8 files** via `Get-Content -LiteralPath <path> -Raw -Encoding UTF8`. No CLI argument round-trip.
2. **Posting bodies as raw UTF-8 bytes** via `[System.Text.Encoding]::UTF8.GetBytes($json)` directly to `Invoke-RestMethod`. PowerShell's default Latin-1 body encoding never runs.
3. **Setting `Content-Type: application/json; charset=utf-8`** explicitly on every request.

For inline `-Description` / `-Comment` values, the script warns if non-ASCII characters are present and recommends switching to the file-based parameter.

---

## Auto-detection logic

| Field | Detection source | Fallback |
|---|---|---|
| `-OrgUrl` | `git remote get-url origin`, parsed for `dev.azure.com/<org>` or `<org>.visualstudio.com` | none — error |
| `-Project` | same | none — error |
| `-Repository` | same | none — error |
| `-SourceBranch` (Create) | `git rev-parse --abbrev-ref HEAD` | none — error |
| `-TargetBranch` (Create) | `git symbolic-ref refs/remotes/origin/HEAD` | `main` |

When the script is run outside a git checkout, all four context parameters become mandatory.

**Parent / sibling working-tree trap:** when invoking the script from a *parent* repo that has a junctioned `shared/dv/` (the typical HSO consuming-repo layout) targeting the shared-best-practices repo, git's auto-detection picks up the **parent** repo's origin, not the shared repo's. Symptoms: the script tries to open a PR in the wrong project, or auto-fills the wrong source/target branches. Fix: pass `-OrgUrl` / `-Project` / `-Repository` / `-SourceBranch` / `-TargetBranch` explicitly when working across repos.

---

## Critical Rules (DO / DO NOT)

### DO

- **Always use `-DescriptionFilePath` / `-CommentFilePath`** for any body that *might* contain non-ASCII characters. Don't second-guess the encoding — a file is always safe.
- **Author the file as UTF-8.** Most editors default to UTF-8; PowerShell's `Out-File -Encoding UTF8` writes UTF-8 with BOM (acceptable — the script's `Get-Content -Encoding UTF8` handles both forms).
- **Authentication mode is resolved automatically from settings for personal sessions.** Use `-Pat` only in CI / unattended contexts or when you need an explicit ADO auth override.
- **Auto-detect when in a clone.** Only specify `-OrgUrl` / `-Project` / `-Repository` explicitly when running outside the target repo or when working across repos.
- **Use `-WorkItemIds` at Create time** when the linked items are known up front — saves a follow-up `LinkWorkItems` call.

### DO NOT

- **Do not paste the PR body inline as `-Description "..."`** when the body has em-dashes, `§`, smart quotes, accented characters, or anything outside basic ASCII. The Windows ANSI codepage will corrupt it.
- **Do not use `az repos pr create --description "..."`** as a workaround for this script. That's the bug this skill exists to avoid.
- **Do not skip the script and `Invoke-RestMethod` manually** without setting `Content-Type: application/json; charset=utf-8` and posting bytes. PowerShell's default body encoding is Latin-1 (cp1252) and will re-introduce the mangling.
- **Do not hardcode tokens** anywhere — `-Pat` is for CI and should come from a pipeline secret, never a checked-in file.
- **Do not use `-AutoComplete` on shared/protected branches** without confirming the branch policies. Auto-complete bypasses some interactive merge confirmations and can land work earlier than expected.

---

## Examples

### Real-world: re-create a PR with a body that the `az` CLI mangled

Given a `pr-body.md` containing em-dashes and `§` references:

```powershell
# Author the body file (any editor, save as UTF-8)
# Then:
& "claude-code/skills/hso-ado-pull-requests/scripts/Invoke-AdoPullRequestOperation.ps1" `
    -Operation Create `
    -Title "feat(skill): add insert_after + curated engine reference" `
    -DescriptionFilePath ".\pr-body.md"
```

### Real-world: fix an existing mangled PR description

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation Update -PullRequestId 735 -DescriptionFilePath ".\pr-body.md"
```

### Pre-flight: check what's currently outstanding before opening a new PR

```powershell
& "...Invoke-AdoPullRequestOperation.ps1" `
    -Operation List -Status active -TargetBranch main
```

---

## Changelog

Moved out of this file to keep skill changelogs in a sibling file — see **[CHANGELOG.md](CHANGELOG.md)**.
