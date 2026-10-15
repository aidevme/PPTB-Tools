---
name: hso-jira-work-items
layer: atomic
scope: core
description: |
  Read, search, create, update, transition, assign, and bulk-load Jira Cloud issues via REST v3 —
  epics, stories, sub-tasks, any hierarchy level, with parent links, labels, components, and any
  custom field addressed by its display name (textarea → ADF, select → option, shaped automatically).
  Bulk mode loads a whole backlog slice from one JSON manifest with "@ref" parent references,
  duplicate adoption, and a crash-safe result file. Use for "read/search Jira", "create a story in
  Jira", "load these stories into Jira", "move PROJ-123 to In Review", "assign", or when
  given an atlassian.net/browse URL. The Jira counterpart to hso-ado-work-items. Does NOT decide
  what belongs on a work item — the client's backlog conventions do — and never writes priority.
---

# Jira work items

Read and write Jira Cloud issues via REST v3. The Jira counterpart to
[`hso-ado-work-items`](../hso-ado-work-items/SKILL.md).

> **Verified against a live Jira Cloud tenant on 2026-09-03** (read, search with pagination,
> field-name resolution, dry-run payloads for every write path). See [CHANGELOG.md](CHANGELOG.md)
> for what was proven and what was not.

## Authority — this skill does not decide what goes on a work item

This skill is the *mechanism*; the *rules* belong to whoever owns the backlog:

| Task | Primary authority |
|---|---|
| The template's own backlog conventions | the repo's conventions file — an ADO-oriented ruling, but the principle that every substantive change carries a work item applies regardless of vendor |
| A consumer project's projection rules (which fields, which statuses, which sub-tasks) | the project's **Jira projection profile** — `agent/wiki/system/jira-projection-profile.md` in the consuming repo, the Jira twin of the ADO process profile |
| Atlassian credentials and settings | [`hso-atlassian-auth`](../hso-atlassian-auth/SKILL.md) |
| The same operations against Azure DevOps | [`hso-ado-work-items`](../hso-ado-work-items/SKILL.md) |
| Jira issue read/write mechanics | **this skill** |

A client's Jira is **their** backlog. Types, required fields, custom fields, and workflow states
are theirs, and this skill does not impose ours on it. Field names, status names, and sub-task
templates are therefore never hard-coded here — they come from the call (or the manifest), and
the consuming repo records them in its projection profile.

## Configuration

Credentials resolve through [`hso-atlassian-auth`](../hso-atlassian-auth/SKILL.md): explicit
parameters, then `ATLASSIAN_BASE_URL` / `ATLASSIAN_EMAIL` / `ATLASSIAN_API_TOKEN`, then a
**gitignored** `auth-settings.json`.

`JIRA_ALLOWED_STATUSES` (env) or `JiraAllowedStatuses` (auth-settings.json) resolves the same way
and **fences which statuses this skill may transition an issue into**. Configure it per
engagement; a transition to a status outside the list is refused.

> The API token is a secret. It never goes in `CLAUDE.md`, `CLAUDE.local.md`, or any tracked file.

## Scripts

All scripts dot-source `scripts/Jira-Common.ps1` (REST wrapper, field resolution, value
shaping, markdown → ADF, paginated search, status guardrail). Pure ASCII, PowerShell 5.1 and 7.

| Script | Does |
|---|---|
| `Invoke-JiraIssueRead.ps1` | `-Operation GetIssue` by key, or `-Operation SearchJql` (paginated to `-MaxResults`, cap 1000). `-IncludeFields "Story","Business Rules"` renders any extra field by name; `-SummaryOnly` prints just the table |
| `Invoke-JiraIssueCreate.ps1` | Create any type at any level: `-ParentIssueKey` (Story → Epic, Sub-task → Story), `-Labels`, `-Components`, `-Fields @{ 'Field Name' = value }` or `-FieldsJsonFilePath`. Duplicate guard on summary + parent. `-DryRun` / `-ConfirmCreate` |
| `Invoke-JiraIssueContentUpdate.ps1` | Summary, description, `-ParentIssueKey` (re-parent), `-Labels` / `-AddLabels` / `-RemoveLabels`, `-Components`, `-Fields` / `-FieldsJsonFilePath`. `-DryRun` / `-ConfirmUpdate` |
| `Invoke-JiraIssueStatusUpdate.ps1` | Transition to a target **status** (matches the transition's destination first, then its name), optionally with sub-tasks. Fenced by the allowed-status list. `-DryRun` / `-ConfirmUpdate` |
| `Invoke-JiraIssueAssigneeUpdate.ps1` | Set, reassign, or clear assignee — single, bulk, or parent-plus-related; strict user resolution; read-back verification. `-DryRun` / `-ConfirmUpdate` |
| `Invoke-JiraIssueBulk.ps1` | Create/update many issues from one JSON manifest — see below. `-DryRun` / `-ConfirmWrite` |

```powershell
$d = "claude-code/skills/hso-jira-work-items/scripts"

& "$d/Invoke-JiraIssueRead.ps1" -Operation GetIssue -IssueKey "PROJ-123" -IncludeFields "Story","Business Rules"
& "$d/Invoke-JiraIssueRead.ps1" -Operation SearchJql -Jql "parent = PROJ-10 ORDER BY created" -MaxResults 300 -SummaryOnly

& "$d/Invoke-JiraIssueCreate.ps1" -IssueType Story -ParentIssueKey PROJ-10 -SummaryText "Generate the contract number on save" `
    -DescriptionFilePath .\story.md -Labels team-x -Components "My Component" `
    -Fields @{ 'Acceptance Criteria' = (Get-Content .\ac.md -Raw); 'MoSCoW Priority' = 'Must' } -DryRun   # then -ConfirmCreate

& "$d/Invoke-JiraIssueStatusUpdate.ps1" -IssueKey PROJ-123 -TargetStatus "In Review" -ConfirmUpdate
```

### Custom fields by name

Pass fields by **display name** (or `customfield_NNNNN`). The name is resolved against the
tenant's field catalog once per run; an unknown or ambiguous name stops the script before any
write. Values are shaped for the field's schema: a textarea gets an ADF document built from
markdown-ish text (headings, bullets, numbered lists, tables, code fences; consecutive lines
become one paragraph with line breaks, so Gherkin steps stay together; inline `**strong**`,
`*em*`, `` `code` ``, `~~strike~~` and `[text](url)` become real ADF marks, and a lone or
unmatched marker is left as typed), a select gets
`{ value }`, a multi-select gets `[{ value }]`, components get `[{ name }]`, numbers are numbers.
An already-shaped hashtable or ADF document passes through untouched.

### Bulk manifest

`Invoke-JiraIssueBulk.ps1 -ManifestPath backlog.json` loads a whole slice —
[references/bulk-manifest-example.json](references/bulk-manifest-example.json) is the template:

- `items[]` each carry a unique `ref`, an `op` (`create` | `update`), and the same content keys as
  the single scripts (`issueType`, `parent`, `summary`, `description` | `descriptionFile`,
  `labels` / `addLabels` / `removeLabels`, `components`, `fields`, `subtasks`).
- `parent` may be an issue key or **`"@ref"`** of an earlier item — create an epic and its
  stories in one manifest. A field value may be `{ "file": "path.md" }` to load text from a file.
- `defaults.labels` / `components` / `fields` are merged into every create (the mandatory
  component a client board requires goes here once).
- **Duplicate adoption.** A create whose summary already exists under the same parent is
  *adopted* (key recorded, nothing created). **Result file** (`<manifest>.result.json`) is
  rewritten after every item; a re-run skips what was created and resolves `@ref` from it.
- `-DryRun` validates every field name and parent reference and prints the plan. Per-item
  isolation: one failure never aborts the batch unless `-StopOnError`.

## Writes require explicit confirmation

Every write path has `-DryRun` (prints the exact payload) and a `-Confirm*` switch that is
required for the real call. Kept deliberately: the bulk operations touch issues the caller did
not name individually, and on a client's live backlog that is not recoverable by undo.

**`JIRA_ALLOWED_STATUSES` is a guardrail, not a convenience.** Configure it per engagement so an
agent cannot move an issue into a state the client's workflow does not expect.

## Notes

- **REST v3** throughout; the legacy `/search` endpoint is gone (May 2025), all search goes
  through `/search/jql` with `nextPageToken` pagination.
- **Priority is deliberately not written.** Silently writing a field nobody asked about is how an
  agent loses a client's trust in its backlog. Any other field is available by name.
- **Transition vs status.** Workflows routinely name the transition ("Start Review") differently
  from the status it leads to ("In Review"). Pass the **status**; the script finds the
  transition.

## Changelog

See **[CHANGELOG.md](CHANGELOG.md)** (skill changelogs live in a sibling file).
