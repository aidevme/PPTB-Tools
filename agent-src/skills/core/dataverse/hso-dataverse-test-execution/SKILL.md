---
name: hso-dataverse-test-execution
layer: orchestration
scope: core
description: Execute a story's authored ADO Test Cases against a live Dataverse model-driven app — verify logic/Custom-API outputs via the Web API and user-facing behavior via playwright-cli, then record results and bugs in ADO. Use for "run/execute the test cases" against a real environment; not for authoring cases or persona-driven hunting.
---

# Dataverse Test Execution (hybrid)

Run a story's authored ADO Test Cases against a **live** model-driven app and record the outcome. This skill is the *executor*; it does not author test cases and does not fix defects.

## When to use this skill
- "Run / execute the test cases for story #N", "test this against TST/DEV", "work the test set".
- A set of ADO Test Cases already exists (linked via `Microsoft.VSTS.Common.TestedBy`) and you need pass/fail evidence.

## When NOT to use
- Authoring or editing Test Cases → `hso-ado-work-items`.
- Open-ended, persona-driven defect hunting at feature close → `hso-dataverse-adversarial-review`.
- Fixing the defects found → `hso-dataverse-triage-remediation`. **Note:** that skill's autonomous loop consumes adversarial-review findings only — defects *this* skill files are triaged and fixed **manually**, not auto-remediated.
- Plugin unit tests / PCF spec tests → the peer SOPs in the **testing** topic.

## Configuration
Read from `CLAUDE.md`: **Environment URL(s)** · **App (model-driven) name** · **Publisher prefix**.
Read from `CLAUDE.local.md`: **Author Name** · **ADO Org URL / Project / PAT** · **playwright-cli path**.
If a value is missing, ask — never hardcode.

**First-use capture (ask once, then persist).** If `CLAUDE.md` has no **Azure DevOps Conventions** / **Test Execution → Recording Results** section, or those sections still carry `<set: …>` stubs, ask the user once — *Is work tracked in ADO? What is the defect work-item type (Bug on Agile/Scrum/CMMI, Issue on Basic)? What is the test-management surface — Test Plans/Suites or comments-only?* — then **write the answers back into `CLAUDE.md`** so later runs don't re-ask. Repo setup intentionally ships these as stubs rather than prompting at scaffold time (the answers are usually unknown then).

## Core principle — hybrid, by assertion
Split every test case's assertions by *layer*, not by convenience:

- **Business logic & calculations, Custom API outputs, record state** → verify via the **Web API**. Triggering a Custom API through the API runs the *same* server code the UI calls, so correctness is validated identically — and you read exact values off the records. This is faster and deterministic.
- **User-facing behavior** (toasts/warnings, on-screen errors, live grid refresh, row highlighting, dialog wording, accessibility attributes) → verify in the **browser** with `playwright-cli`. The API cannot prove what the user sees.

Never give a UI-facing acceptance clause a "pass" from a backend call alone. Report partials honestly.

## Workflow

1. **Pull the test set.** Query the story's Test Cases (`hso-ado-work-items`), read each case's steps, and identify the **prerequisite** case. Read the canonical creation case it references.
2. **Read the source to ground expected values.** For calculation/divisor/gating logic, read the plugin/service C# (e.g. the Custom API handler) so expected numbers and trigger conditions are derived, not guessed. This also locates root causes when a case fails.
3. **Build the fixture from scratch** (never reuse arbitrary org data — see the project's test-execution convention in `CLAUDE.md`). Build deterministic fixtures via the Web API when the standard UI flow can't produce the exact shape a case needs (specific template/role/hours configuration).
4. **Execute** each case on the hybrid split above. Stage data (line values, child records) via the Web API; trigger bound Custom APIs; read results; drive the irreducibly-visual steps in the browser.
5. **Record results in ADO** (per the project's "Test Execution → Recording Results" convention in `CLAUDE.md`):
   - **Match the project's test-management surface:** if it uses **Test Plans/Suites**, record each case's outcome against its **Test Point** via the ADO **Test Runs** API so Test Hub reflects the run (if the ADO tooling — `hso-ado-work-items` — doesn't yet expose Test Runs/Points, surface that gap and record comments as an interim, per "surface missing capabilities, don't work around them"); if it's **comments-only**, record a per-case comment with outcome (Pass / Partial / Fail), date, runner.
   - Test task: an end-user-friendly comment + link to the execution report; assign per project rule; set state per the project's success/blocked policy.
   - Defects: file the project's **defect work item** — `Bug` on Agile/Scrum/CMMI, `Issue` on the Basic process — per the project's ADO process and the **Bug/defect convention in `CLAUDE.md`**, with **Repro Steps + System Info + record IDs/URLs**, assigned to the Build/Dev owner with a review @mention (see the Bug field guide in `hso-ado-work-items`); set **Severity** per the HSO severity table in `testing-best-practices.md` §15.1. **Before filing, check for an existing open defect on the same Test Case / story** (e.g. one already filed by `hso-dataverse-triage-remediation`) and comment on it instead of creating a duplicate.
6. **Write a local execution report** under `agent/Work/Testing/Execution/`.

## Driving a live model-driven app (playwright-cli)

- **Auth**: open a **persistent** profile with the system browser — `playwright-cli -s=<name> open <envUrl> --browser=msedge --headed --persistent`. On managed devices this commonly satisfies Conditional Access without an MFA prompt; save with `state-save`.
- **Web API through the authed browser**: `run-code "async page => page.evaluate(async () => (await fetch('/api/data/v9.2/…')).json())"`. Same-origin, no separate token.
- **Web resources must load inside the app shell**: navigate to `main.aspx?appid=<id>&pagetype=webresource&webresourceName=<name>&data=id%3D<recId>`. A direct `/WebResources/…html` URL fails when the resource uses `Xrm.WebApi`. The resource renders in an iframe — find it via `page.frames()`.
- **Trigger a bound Custom API** via `fetch('/api/data/v9.2/<entityset>(<id>)/Microsoft.Dynamics.CRM.<api_name>', {method:'POST',body:'{}'})`; the response JSON carries `Success`/`Message`/`Warnings` — so warning/error *content* is API-visible even though *surfacing* must be UI-checked.
- **Find lookup navigation-property casing** from metadata: `EntityDefinitions(LogicalName='<entity>')/ManyToOneRelationships?$select=ReferencingAttribute,ReferencingEntityNavigationPropertyName`. Most are lowercase; some are PascalCase.

### ⚠️ An empty read is not evidence of absence
Before recording "the app showed no warning / no rows / no message", prove the surface was attached and rendering when you read it. Three states each return an empty result **with no error**, and each has been mis-filed as a product defect:

- the iframe has not attached yet (a large bundle can take ~20 s under the modern app host — poll, don't fixed-wait);
- the window lost focus, so Chromium throttled the render loop and the control never painted (`page.bringToFront()` before each interaction);
- the frame **detached on a data reload**, so a held reference throws `Frame was detached` and a tolerant `catch` yields `[]`.

Re-acquire the frame inside every poll iteration, never above the loop. Mechanics and code: [playwright-testing-best-practices.md §4.10](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md). Where the assertion can be expressed as data, prefer the Web API — none of these states apply to it.

Related: a UI-facing clause that *fails* deserves the same scrutiny as one that passes. Confirm the harness was in a position to observe the behavior before filing.

### Windows gotchas (important)
- **Pass non-trivial snippets as a base64-encoded file** decoded inside `page.evaluate`, rather than escaping them into the `run-code` argument — a mis-escape silently runs a *different* query instead of erroring. Runner script + node-scope caveats: [§4.6](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md).
- For inline one-offs: `playwright-cli.cmd` is re-parsed by `cmd.exe`, which mangles `&`, `|`, `||`, `&&`, `<`, `>` even inside quotes. **Call the bash shim** (`playwright-cli`, no `.cmd`) from Git Bash so node receives the arg intact. If you must use the `.cmd`, build URLs with `String.fromCharCode(38)` and avoid `||`/`&&` (use `== null` ternaries).
- In PowerShell, `"/workitems/$id?api-version=…"` mis-parses `$id?`; use `${id}`.

## Critical rules
- **DO** read source to derive expected values; **DO NOT** assume a naive formula (e.g. even division) without checking the trigger conditions.
- **DO** build the prerequisite fixture from scratch; **DO NOT** reuse an arbitrary existing record.
- **DO** verify user-facing clauses in the browser; **DO NOT** pass them from an API call alone.
- **DO** prove the surface was attached and rendering before recording an absence; **DO NOT** file a defect off an empty frame read.
- **DO** label partials as partial with the untested clause named.
- **DO NOT** hardcode env URLs, app ids, org/PAT — read from config.

## Standards (SOPs — read for the surrounding discipline)
This skill is the *executor*; it defers to the **testing** topic's SOPs for standards and does not duplicate them:
- [testing-best-practices.md](../../../agent/wiki/sop/testing/testing-best-practices.md) — test strategy, the test-type matrix, the defect lifecycle + **HSO severity table** (§15.1), UAT exit floor, the test-health metrics. Use its severity table when setting Bug severity.
- [playwright-testing-best-practices.md](../../../agent/wiki/sop/testing/playwright-testing-best-practices.md) — the two-mode Playwright model (interactive vs scripted `.spec.ts`), requirement→Test Case→spec **traceability**, session/daemon-safety rules, selector strategy, `storageState` auth.
- [pcf-control-testing-best-practices.md](../../../agent/wiki/sop/testing/pcf-control-testing-best-practices.md) — PCF-specific UI test mechanics.
- [sample-data-validation-workflow.md](../../../agent/wiki/sop/sample-data/sample-data-validation-workflow.md) — the extract-then-analyze data primitive when staging/validating fixtures.

## See also (skills)
- [playwright-cli](../playwright-cli/SKILL.md) — browser primitive · [hso-ado-work-items](../hso-ado-work-items/SKILL.md) — test cases + bugs · [hso-dataverse-data](../hso-dataverse-data/SKILL.md) — Web API · [hso-dataverse-adversarial-review](../hso-dataverse-adversarial-review/SKILL.md) / [hso-dataverse-triage-remediation](../hso-dataverse-triage-remediation/SKILL.md) — review/fix peers.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
