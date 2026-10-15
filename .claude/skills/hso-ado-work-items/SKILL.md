---
name: hso-ado-work-items
layer: atomic
scope: core
description: Create, update, and query Azure DevOps work items via the REST API. Use when user asks to create/update/query work items (Requirements, Bugs, Tasks, Features, Epics, Test Cases), link work items, bulk-create from specs, add test steps, or comment on a work item (including @mentioning someone to notify them). Uses PowerShell script with MSAL.PS interactive auth.
---

# Azure DevOps Work Items

Create, update, query, link, and comment on work items in Azure DevOps using the `Invoke-AdoWorkItemOperation.ps1` script.

## MANDATORY: First Step - Determine Work Item Type

**Before creating any work item**, use `AskUserQuestion` to determine the type (unless the user has already specified it):

```
Which type of work item should be created?
- Feature: A major capability or deliverable (parent of Requirements/PBIs)
- Requirement / PBI / User Story: A specific functional requirement (process-template-dependent name)
- Test Case: A test scenario with step-by-step test steps, actions, and expected results
- Bug: A defect or issue to be fixed
- Task: An implementation work item (child of a Requirement/PBI)
- Epic: A large strategic initiative (parent of Features)
```

**The work item type drives which fields are required and how the work item is populated.** See the "Work Item Type Guide" section below.

## Authentication

**No auth flag is needed — interactive MSAL browser login is the default.** Pass `-Pat "<token>"` only for PAT-based auth (see [PAT Fallback](#pat-fallback-for-restricted-orgs)). No configuration required.

The script uses MSAL.PS interactive login by default:
1. First call opens a browser for Azure AD login
2. Token is cached at `%TEMP%\AdoAuthCache_<hash>.json` (~1 hour validity)
3. Subsequent calls reuse the cached token automatically — no repeated logins

> **Interactive login needs a foreground terminal.** The browser prompt cannot complete if the call is detached/backgrounded — run the first (auth-priming) call in the foreground, then cached calls are non-interactive.

**Process template affects available fields.** Use `ListTypes` operation to discover available types if unsure.

## Script Path

```
.claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1
```

A second script, `scripts/Get-AdoProcessProfile.ps1`, detects a project's ADO process
and matches it to a canonical process profile — see "Process-profile resolution
(consumer projects)" below.

All examples below assume the working directory is the repository root.

| Type | Common Process Templates |
|------|------------------------|
| **Epic** | CMMI, Agile, Scrum |
| **Feature** | CMMI, Agile, Scrum |
| **Requirement** | CMMI |
| **User Story** | Agile |
| **Product Backlog Item** | Scrum |
| **Task** | CMMI, Agile, Scrum |
| **Bug** | CMMI, Agile, Scrum |
| **Test Case** | CMMI, Agile, Scrum |

## Operations Reference

### 1. LIST TYPES

List available work item types for the project.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation ListTypes `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project"
```

### 2. CREATE A WORK ITEM

Create a new work item of any type. The body must be a JSON patch array.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Create `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemType "Requirement" `
    -JsonPatchFilePath "C:\temp\requirement-patch.json"
```

**JSON patch file format:**
```json
[
  { "op": "add", "path": "/fields/System.Title", "value": "My Requirement Title" },
  { "op": "add", "path": "/fields/System.Description", "value": "<div><p>Description here</p></div>" },
  { "op": "add", "path": "/fields/Microsoft.VSTS.Common.Priority", "value": 2 },
  { "op": "add", "path": "/fields/System.Tags", "value": "Tag1; Tag2" },
  {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "System.LinkTypes.Hierarchy-Reverse",
      "url": "https://dev.azure.com/MyOrg/_apis/wit/workItems/12345"
    }
  }
]
```

**IMPORTANT:** Always use `op: "add"` (not `"replace"`) for setting fields — `replace` returns 400 on fields not previously set.

**IMPORTANT:** Always write the JSON patch to a file (`-JsonPatchFilePath`) rather than passing inline (`-JsonPatchBody`) for anything containing HTML or special characters. Inline JSON gets mangled by PowerShell argument parsing.

### 3. UPDATE A WORK ITEM

Update fields on an existing work item.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Update `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemId 12345 `
    -JsonPatchFilePath "C:\temp\update-patch.json"
```

### 4. GET A WORK ITEM

Retrieve a single work item by ID.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Get `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemId 12345 `
    -ExpandRelations
```

### 5. QUERY (WIQL)

Run a WIQL query and return full work item details.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Query `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -Wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.WorkItemType] = 'Requirement' AND [System.TeamProject] = 'My Project' ORDER BY [System.Id]" `
    -ExpandRelations
```

The script automatically batch-fetches full work item details (up to 200 per batch) from WIQL results.

### 6. LINK WORK ITEMS

Add a link between two work items.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Link `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemId 12345 `
    -LinkTargetId 67890 `
    -LinkType "System.LinkTypes.Hierarchy-Reverse"
```

**Common link types:**

| Relation | Type String |
|----------|-------------|
| Parent (set parent on child) | `System.LinkTypes.Hierarchy-Reverse` |
| Child (add child to parent) | `System.LinkTypes.Hierarchy-Forward` |
| Related | `System.LinkTypes.Related` |
| Predecessor (this item depends on target) | `System.LinkTypes.Dependency-Reverse` |
| Successor (target depends on this item) | `System.LinkTypes.Dependency-Forward` |
| Tested By (test case tests a work item) | `Microsoft.VSTS.Common.TestedBy-Reverse` |
| Tests (work item is tested by test case) | `Microsoft.VSTS.Common.TestedBy-Forward` |

### 7. ADD TEST STEPS

Set test steps XML on a Test Case work item. The script handles XML entity encoding correctly (avoids the `ConvertTo-Json` double-escaping bug).

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation AddTestSteps `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemId 12345 `
    -TestStepsFilePath "C:\temp\test-steps.xml"
```

**Test steps XML format:**
```xml
<steps id="0" last="3">
  <step id="1" type="ValidateStep">
    <parameterizedString isformatted="true">&lt;DIV&gt;&lt;P&gt;Open the form&lt;/P&gt;&lt;/DIV&gt;</parameterizedString>
    <parameterizedString isformatted="true">&lt;DIV&gt;&lt;P&gt;Form loads successfully&lt;/P&gt;&lt;/DIV&gt;</parameterizedString>
    <description/>
  </step>
  <step id="2" type="ValidateStep">
    <parameterizedString isformatted="true">&lt;DIV&gt;&lt;P&gt;Click Submit&lt;/P&gt;&lt;/DIV&gt;</parameterizedString>
    <parameterizedString isformatted="true">&lt;DIV&gt;&lt;P&gt;Record saved with confirmation&lt;/P&gt;&lt;/DIV&gt;</parameterizedString>
    <description/>
  </step>
</steps>
```

- `last` attribute = total number of steps
- Each `<step>` has sequential `id` starting at 1
- `type="ValidateStep"` for steps with expected results, `type="ActionStep"` for action-only
- First `<parameterizedString>` = **Action**, second = **Expected Result**
- HTML inside must be **entity-encoded** (`<` -> `&lt;`, `>` -> `&gt;`)

### 8. COMMENT ON A WORK ITEM

Post a comment to a work item's **Discussion**. Use this — not an `Update` on `System.History` — whenever a
convention calls for "add a comment", "post the outcome", or "notify someone on the work item".

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Comment `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemId 12345 `
    -CommentFilePath "C:\temp\comment.html"
```

- **Write the body to a file** (`-CommentFilePath`) for anything containing HTML. `-CommentText` exists for
  trivial one-liners, but inline strings get mangled by PowerShell argument parsing — the same trap as
  `-JsonPatchBody`.
- The body follows the same **HTML Formatting Standards** as Description (below): use `<ul><li>`, never
  `<pre>` — `<pre>` renders as a grey monospace box in ADO.
- No manual escaping is needed. The body is sent as plain JSON (not json-patch), and entities round-trip
  intact — verified against a live work item.
- Returns the new comment's `id`, so a caller can reference or delete it afterwards.

#### @mentions — the GUID is mandatory

A bare `@Name` string posts successfully and **notifies nobody**. ADO only raises a notification for this
exact markup:

```html
<a href="#" data-vss-mention="version:2.0,{identityGuid}">@Display Name</a>
```

Because that failure is silent, let the script build it. `-MentionFromField` reads the identity from a work
item field and prepends the anchor:

```powershell
    -Operation Comment -WorkItemId 12345 `
    -CommentFilePath "C:\temp\comment.html" `
    -MentionFromField "System.AssignedTo"      # or System.CreatedBy, etc.
```

| Parameter | Purpose |
|-----------|---------|
| `-MentionFromField` | Identity field to read (`System.AssignedTo`, `System.CreatedBy`, …) |
| `-MentionFromWorkItemId` | Read the identity from a *different* work item; defaults to `-WorkItemId` |
| `-MentionIdentityId` + `-MentionDisplayName` | Supply the identity directly; must be used together |

Resolving from a work item field is deliberate: those payloads already carry `{id, displayName}`, so no
identity-search call is made and **no PAT scope beyond Work Items (Read & Write) is required**. If the field
is empty, or returns a bare string with no GUID, the script fails loudly rather than posting a comment that
silently notifies nobody.

### 9. GET COMMENTS

Read a work item's Discussion thread. Useful for **idempotency** — checking whether this run already posted
its result before posting again, which matters because the test-execution and handoff conventions get re-run.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation GetComments `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -WorkItemId 12345
```

Returns `totalCount` plus, per comment, `id` / `createdBy` / `createdDate` / `modifiedDate` / `text`.

> **API version note.** Both comment operations run against `7.1-preview.4`, not the `7.1` used everywhere
> else — the Comments routes reject the non-preview version string. The script handles this; don't "fix" it
> to match the other operations.

---

## Process-profile resolution (consumer projects)

Per the process-profile abstraction decision (resolve-then-realize), every ADO-connected
**consumer** project resolves an **ADO process profile** once — detected, never assumed —
and all projection (FRs, build slices, defects, decisions) realizes per that profile.
Canonical profiles + file shapes:
[references/process-profiles/](references/process-profiles/INDEX.md). A project's own
template backlog may be exempted and governed by the repo's own conventions ledger directly.

### Detection script

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Get-AdoProcessProfile.ps1" `
    -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project"
```

- Org/project auto-detect from `git remote get-url origin` when omitted (dev.azure.com,
  legacy visualstudio.com, and v3 SSH shapes). `-Pat` overrides interactive auth.
  Read-only scopes only.
- `-ListProcesses` — diagnostic: dump every process in the org (used to re-verify the
  pinned stock GUIDs against a new org).
- **Exit codes:** `0` matched — JSON `matchedProfile` is `agile | scrum | cmmi | basic |
  custom-inherited`; when `confirmRequired` is true (custom-inherited signature, treated as
  proposed pending confirmation) confirm with the user before recording. `3` needs-interview — inherited
  process with no known signature; JSON carries `base` (stock parent) + `witVocabulary`
  to seed the interview. `4` no-access — API unreachable / auth failed / no context;
  fall back to asking the user. `2` hard error.

### When to resolve (three moments)

1. **Repo init** — the workspace-init skill runs detection when the repo is ADO-connected.
2. **First projection** — a producer skill (`hso-requirements-author`,
   `hso-dataverse-architect`, `hso-dataverse-delivery-pipeline`) finding no
   `agent/wiki/system/ado-projection-profile.md` in the consumer repo runs the script,
   then records the answer (below).
3. **Drift** — a create call failing on a missing type/field, or a `witSnapshot`
   mismatch, re-runs detection and surfaces the diff to the user **before any write**.

### Recording the answer (ask once, record, then obey)

- **Matched:** write the project profile file (`agent/wiki/system/ado-projection-profile.md`
  per [_schema.md](references/process-profiles/_schema.md) — canonical id, process
  identity, `detectedVia: api`, `detectedAt`, `witSnapshot` from `witVocabulary`) and the
  `CLAUDE.md` Project-config marker row (`ADO process profile: <id>` + pointer).
- **No access:** ask one chip question — `Agile / Scrum / CMMI / Basic /
  Custom inherited / Other custom / Not ADO-tracked` — record `detectedVia: user`, and
  re-verify opportunistically on the first authenticated projection.
- **Not ADO-tracked:** profile `none` still stamps the marker row (ruling O5) with the
  reason in `overrides.reason`.

### Interview (unknown custom processes)

Seeded from the `base` profile — inherited processes keep their parent's types unless
disabled, so ask **only the deltas**, with base-profile defaults preselected:

1. Show what detection found: process name, base, `witVocabulary`, disabled types.
2. Ask: FR target type → acceptance-criteria home → slice realization → defect type →
   decision mirroring (default **none**) → engagement mandates (required fields, area paths).
3. Write the answers as `overrides` in the project profile file
   (`profile: custom:<slug>`, `base: <stock id>`); the canonical base profile fills every
   unasked dimension.
4. **Never** append client-project customs to the repo's own conventions ledger — they are
   project-tier knowledge. A custom recurring across engagements is promoted to a named
   canonical profile in `references/process-profiles/` via PR.

---

## Work Item Type Guide

### Custom / inherited-process types (inherited custom process template)

`-WorkItemType` accepts **any** type string and URL-encodes it — custom types from
inherited processes work exactly like stock ones: `Requirement` (the inherited custom
type — distinct from CMMI's), Build Management types with spaces (`Data Migration`,
`Security role`, `Batch job`), `Key decision`, `End to end`, `Process area`, `Process`.
When the target project runs an **inherited custom process template**, the governing rules
are the consumer-project profile in the repo's own conventions ledger: FR → `Requirement`
parented under its process node (`Hierarchy-Reverse`), **Test Case children as the
acceptance criteria**, build items realized as native Build Management types (predecessor
links from `blocked_by`, optional Related links per lineage), ADRs mirrored to
`Key decision`. Custom field reference names for that template are recorded in the profile
as field discovery fills them — never guessed. Use `ListTypes` / `_apis/wit/fields` to
discover a project's actual types and fields.

### Feature

**Purpose:** Major capability or deliverable. Parent of Requirements/PBIs/User Stories.
**Typical parent:** Epic | **Typical children:** Requirements, PBIs, User Stories

| Field | Required | Path | Notes |
|-------|----------|------|-------|
| Title | Yes | `/fields/System.Title` | Short capability name |
| Description | Yes | `/fields/System.Description` | HTML |
| Priority | Yes | `/fields/Microsoft.VSTS.Common.Priority` | 1-4 |
| Tags | Only if requested | `/fields/System.Tags` | Semicolon-separated. Do NOT add unless user explicitly provides them. |

### Requirement / PBI / User Story

**Purpose:** Specific functional requirement. Name depends on process template:
- **CMMI** → `Requirement` (URL-encode as `$Requirement`)
- **Agile** → `User Story` (URL-encode as `$User%20Story`)
- **Scrum** → `Product Backlog Item` (URL-encode as `$Product%20Backlog%20Item`)

| Field | Required | Path | Notes |
|-------|----------|------|-------|
| Title | Yes | `/fields/System.Title` | Descriptive title |
| Description | Yes | `/fields/System.Description` | HTML with Gherkin AC |
| Priority | Yes | `/fields/Microsoft.VSTS.Common.Priority` | 1-4 |
| Parent link | Recommended | `/relations/-` | `Hierarchy-Reverse` to parent Feature |
| Impact Assessment | CMMI only | `/fields/Microsoft.VSTS.CMMI.ImpactAssessmentHtml` | Origin tracking |
| Acceptance Criteria | Agile only | `/fields/Microsoft.VSTS.Common.AcceptanceCriteria` | HTML |
| Tags | Only if requested | `/fields/System.Tags` | Semicolon-separated. Do NOT add unless user explicitly provides them. |

### Test Case

**Purpose:** Test scenario with structured test steps.

**Three-step creation process:**
1. **Create** the Test Case with Title, Description, Priority, Tags, and `TestedBy` link(s)
2. **Add Test Steps** via `AddTestSteps` operation
3. **Link** to additional Requirements if needed

| Field | Required | Path | Notes |
|-------|----------|------|-------|
| Title | Yes | `/fields/System.Title` | Test scenario name |
| Description | Yes | `/fields/System.Description` | What the test validates |
| Priority | Yes | `/fields/Microsoft.VSTS.Common.Priority` | 1-4 |
| TestedBy link | **Yes (1+)** | `/relations/-` | `Microsoft.VSTS.Common.TestedBy-Reverse` |

#### Test Case Naming Convention

**MANDATORY: Confirm naming format before creating test cases.**

**Standard Format**: `[Feature]_[Number] [Process/User Story Title]`

**Example**: `Estimating_1 Single Solution Area Estimation`

**Before creating test cases:**
1. Ask the user to confirm the naming format OR provide a different format
2. If the user provides a custom format, check for a project-level naming convention:
   - Look in `CLAUDE.md` under "Azure DevOps Conventions" section. That section may
     delegate to a dedicated conventions file at the repo root — follow the pointer and
     treat that file as governing.
   - If not found, suggest adding it to the conventions file (or `CLAUDE.md` if the
     project has no dedicated file) for project-wide consistency
3. Use the confirmed format for all test cases in that session

**Components:**
- **[Feature]**: The feature area from the parent Requirement/User Story (e.g., "Estimating", "Approvals", "WBS")
- **[Number]**: Sequential number starting from 1 for each test case in the set
- **[Process/User Story Title]**: Brief description of what the test validates (e.g., "Single Solution Area Estimation", "Multi-level Approval Flow")

**Example conversation:**
```
User: "Create test cases for work item 58726"
Assistant: "I'll create test cases for work item 58726. For naming, I'll use the standard format:
[Feature]_[Number] [Process/User Story Title]

For example: Estimating_1 Single Solution Area Estimation

Is this format okay, or would you like to use a different naming convention?"
```

**Custom format storage:**
- Store project-wide naming conventions in `CLAUDE.md` under "Azure DevOps Conventions" (or in the dedicated conventions file that section points to, when the project has one)
- This allows consistency across sessions and team members

### Bug

| Field | Required | Path | Notes |
|-------|----------|------|-------|
| Title | Yes | `/fields/System.Title` | Short defect description |
| Description | Yes | `/fields/System.Description` | HTML summary of the defect |
| Repro Steps | Yes | `/fields/Microsoft.VSTS.TCM.ReproSteps` | HTML, numbered steps **as executed**, with Expected vs Actual. (Agile Bug field.) |
| System Info | Yes | `/fields/Microsoft.VSTS.TCM.SystemInfo` | HTML — environment + URL, app, trigger/API, date, tester, method |
| Priority | Yes | `/fields/Microsoft.VSTS.Common.Priority` | 1-4 (integer) |
| Severity | Recommended | `/fields/Microsoft.VSTS.Common.Severity` | **String picklist** — e.g. `"1 - Critical"`, `"2 - High"`, `"3 - Medium"`, `"4 - Low"`. Integer values are rejected. Omit if unsure. |
| Parent link | Optional | `/relations/-` | `Hierarchy-Reverse` to parent Requirement/Feature |
| Related link | Recommended | `/relations/-` | `System.LinkTypes.Related` to the User Story the defect was found under |
| Tags | Only if requested — **unless the project mandates one** | `/fields/System.Tags` | Semicolon-separated. Do NOT add unless the user explicitly provides them, **or** the project's `CLAUDE.md` defines a required lifecycle tag. A common pattern is a "fix is in TST but not yet in PRD" tag, so the next release batch is a single query rather than a re-read of every resolved Bug. Check the project's Bug conventions before deciding, and use the tag string **exactly** as the project defines it — near-miss variants fragment the query the tag exists to serve. |

> **Project-specific Bug requirements live in `CLAUDE.md`** (Azure DevOps Conventions → "Bug Work Items"), the same way naming and test-case conventions do. **Read CLAUDE.md before creating a Bug** — a project may mandate Repro Steps, System Info, record IDs/URLs, assignment, and review @mentions. When that section exists, it governs; if it delegates to a dedicated conventions file at the repo root, read that file — it carries the full required-field tables and choreography.

### Task

| Field | Required | Path | Notes |
|-------|----------|------|-------|
| Title | Yes | `/fields/System.Title` | Work description |
| Parent link | Yes | `/relations/-` | `Hierarchy-Reverse` to parent Requirement/PBI |
| Description | Optional | `/fields/System.Description` | Implementation details |
| Priority | Optional | `/fields/Microsoft.VSTS.Common.Priority` | 1-4 |
| Remaining Work | Optional | `/fields/Microsoft.VSTS.Scheduling.RemainingWork` | Hours |

### Epic

| Field | Required | Path | Notes |
|-------|----------|------|-------|
| Title | Yes | `/fields/System.Title` | Strategic initiative name |
| Description | Yes | `/fields/System.Description` | HTML scope/goals |
| Priority | Yes | `/fields/Microsoft.VSTS.Common.Priority` | 1-4 |
| Tags | Only if requested | `/fields/System.Tags` | Semicolon-separated. Do NOT add unless user explicitly provides them. |

---

## HTML Formatting Standards

### Description Field with Gherkin AC

Format acceptance criteria as **bulleted lists**, NOT `<pre>` blocks:

```html
<div>
<h3>Overview</h3>
<p>Brief description of the requirement.</p>

<h3>Acceptance Criteria</h3>
<p><strong>Scenario: Descriptive scenario name</strong></p>
<ul>
<li><strong>Given</strong> the precondition</li>
<li><strong>When</strong> the action occurs</li>
<li><strong>Then</strong> the expected outcome</li>
<li><strong>And</strong> additional conditions</li>
</ul>
</div>
```

**DO NOT use `<pre>` tags** - they render as grey monospace boxes in ADO.

### Impact Assessment / Origin Tracking

```html
<div>
<strong>Origin:</strong> Spec &mdash; <em>SpecFileName.md</em>
</div>
```

---

## Workflow: Bulk Create from Specs

1. **Read all spec files** to understand scope and titles
2. **Query existing work items** to check for duplicates (WIQL)
3. **Query Features** to map parent relationships
4. **Present the mapping** to the user for approval before creating
5. **Write JSON patch files** to temp directory (one per work item)
6. **Execute Create operations** for each, capturing IDs
7. **Clean up** temp files after execution

## Workflow: Bulk Create from Meeting Digests

1. **Read the digest** and identify concrete enhancement requests
2. **Exclude** open questions, observations, and out-of-scope items
3. **Include origin metadata** in Impact Assessment field
4. **Follow the same create workflow** as specs

## Workflow: Creating a Complete Test Case

1. **Ask the user** which Requirement(s) this test case validates
2. **Create** the Test Case with Title, Description, Priority, Tags, and TestedBy link(s) — write JSON patch to file, run Create
3. **Capture the ID** from the response
4. **Write test steps XML** to a temp file
5. **Run AddTestSteps** with the captured ID and XML file
6. **Clean up** temp files

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| 400 Bad Request on update | Used `op = "replace"` | Use `op = "add"` |
| 400 on test steps | XML entity double-escaping | Use `AddTestSteps` operation (handles encoding) |
| 401 Unauthorized | Token/PAT expired | Re-authenticate (token auto-refreshes on next call) |
| `<pre>` renders as grey box | HTML `<pre>` tags in ADO | Use `<ul><li>` bullets |
| Special chars in JSON | Inline PowerShell arg parsing | Write to `-JsonPatchFilePath` instead |
| Interactive login blocked | Org policy blocks OAuth consent | Use PAT fallback (see below) |
| @mention posted but nobody notified | Comment contains plain `@Name` text with no identity GUID | Use `-MentionFromField` so the script builds the `data-vss-mention` anchor |
| 400 on Comment / GetComments | Non-preview `api-version` on the Comments routes | Already handled — these operations use `7.1-preview.4` by design |

### PAT Fallback (for restricted orgs)

If your organization blocks interactive OAuth consent, use a Personal Access Token instead:

1. Create a PAT at `https://dev.azure.com/{org}/_usersSettings/tokens`
   - Scopes required: **Work Items: Read & Write**
2. Pass `-Pat "<token>"` instead of the default interactive login on all script calls

```powershell
# Example with PAT instead of Interactive
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-ado-work-items/scripts/Invoke-AdoWorkItemOperation.ps1" `
    -Operation Query `
    -OrgUrl "https://dev.azure.com/MyOrg" `
    -Project "My Project" `
    -Wiql "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = 'My Project'" `
    -Pat "your-pat-token-here"
```

## Changelog

Moved out of this file into a sibling changelog (per the skill-changelogs-in-sibling-file convention) — see **[CHANGELOG.md](CHANGELOG.md)**.
