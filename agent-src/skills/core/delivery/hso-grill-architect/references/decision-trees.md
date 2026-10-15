# Decision Trees per Feature Type

Seed question trees for `hso-grill-architect`. Each node maps to a specific SOP section so the recommended answer always has a sourced citation. Walk the tree top-to-bottom; later nodes depend on earlier ones.

These trees are starting points, not exhaustive. The grill should branch dynamically when the architect's answers expose hidden complexity.

---

## A. Data-modeling spec (new table or table extension)

SOP root: `shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md`

1. **OOB-vs-custom** (SOP §1) — does an out-of-box table already model this? If yes, extend OOB unless a specific constraint blocks it. *Recommended default:* extend OOB.
2. **Industry standard pre-check** — delegate to `hso-semantic-data-modeling` if the table is genuinely new. CDM, Salesforce, SAP equivalents matter for integration readiness.
3. **Table type** (SOP §3) — standard / activity / virtual. *Recommended default:* standard. Activity only if the record needs to appear in timelines/calendars. Virtual only if the source-of-truth is external.
4. **Ownership** (SOP §3) — user/team-owned vs organization-owned. *Default:* **`UserOwned`, every table — global config included.** A user-owned table with Global depth reads identically to org-owned, but stays narrowable; org-owned can only be secured by recreating the table. Do not accept "it's config" as a reason. `OrganizationOwned` needs the architect to ask explicitly and give a rationale — grill for it, and record who and why.
5. **Primary name column** — auto-numbered? composite? user-entered? *Recommended default:* user-entered unless uniqueness is enforced elsewhere.
6. **Alternate keys** (SOP §15) — what external system needs to look this record up?
7. **Audit + change tracking** — auditing on by default; change tracking only if downstream sync (Synapse Link / Fabric Link / Dual Write) requires it.
8. **Relationships + cascade behavior** (SOP §§11–12) — for each relationship: cardinality, type behavior (parental / referential / configurable cascading / system), assign / share / reparent / delete cascades.
9. **Polymorphic lookup** (SOP §13) — does this lookup target multiple tables? *Recommended default:* avoid polymorphic; use multiple non-polymorphic lookups instead unless ALL target tables share a true is-a relationship.
10. **Choices** (SOP §9) — local vs global. *HSO mandate:* always global. No local option sets in new HSO designs.
11. **Status reasons / statecode lifecycle** (SOP §10) — what transitions exist? Are any invalid?
12. **DateTime behavior** (SOP §6) — user-local / date-only / time-zone-independent. *Trap:* changing this after deploy is destructive.
13. **Dual-Write readiness** (SOP §19) — if F&O integration is in scope, what's the mapping?
14. **Solution placement** — which segmented solution? *(See solution-segmentation SOP)*

### Scenario probes for data-modeling
- "What happens to child records when the parent is deleted? Walk me through it."
- "If two users edit the same record simultaneously, who wins? Is that acceptable?"
- "The lookup target gets deactivated. Is the lookup still valid?"
- "This table has 500k rows in production. Does your design still hold?"

---

## B. Plugin / server-side-logic spec

SOP root: `shared/dv/agent/wiki/sop/plugin-development/plugin-development.md`

1. **Plugin vs Custom API vs Power Automate vs Workflow vs Azure Function vs PCF vs form script** (SOP §decision-matrix) — *Recommended default flow:* sync server-side data invariant → plugin; async fire-and-forget → Power Automate or Service Bus; user-initiated business operation → Custom API; long-running or external compute → Azure Function.
2. **Trigger** — table + message (Create/Update/Delete/Associate/Disassociate/SetState/custom message).
3. **Stage** (event-handler SOP §2) — PreValidation / PreOperation / PostOperation. *Recommended default:* PostOperation unless you need to block the operation or modify the target.
4. **Mode** — sync vs async. *Recommended default:* sync if user-blocking + fast; async if external call or slow.
5. **Filtering attributes** (event-handler SOP §3) — for Update messages, ALWAYS specify. *Trap:* missing this causes the plugin to fire on every column change.
6. **Pre-image / post-image** (event-handler SOP §4) — what columns do you need? Specify columns, never `AllAttributes`.
7. **Recursion depth check** (event-handler SOP §7) — needed if the plugin writes back to the same record. `context.Depth > 1` exit.
8. **Layered architecture** (business-logic SOP §1) — confirm: zero `IOrganizationService` calls in business-logic layer. Repository pattern only.
9. **Error handling** (business-logic SOP §6) — what user-facing message on failure? `InvalidPluginExecutionException` only at the Layer-4 boundary.
10. **Performance budget** — 2-second target, 2-minute hard limit. Use `ExecuteMultipleRequest` for >5 record operations.
11. **Solution placement** — which `*Plugins` solution? (One per domain.)
12. **NuGet plugin package** (packaging SOP §1) — never ILMerge for new development.

### Scenario probes for plugin
- "The plugin throws mid-transaction. What does the user see, and what's the state?"
- "Two requests fire this plugin concurrently for the same record. Race condition?"
- "The downstream system you're calling is down for 30 seconds. What happens?"
- "Someone calls this message from a workflow that already ran the plugin. Recursion?"

---

## C. Custom API spec

SOP root: `shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md`

1. **Custom API vs plugin vs Custom Process Action** (SOP §1) — *Recommended default:* Custom API for any new SDK-exposed action. Plugins for invariant enforcement on standard messages.
2. **Action vs function** (SOP §5) — `IsFunction`: false unless the operation is read-only AND idempotent AND has no side effects. *Default:* false.
3. **Binding type** (SOP §4) — Global / Entity / EntityCollection. *Trap:* the URL shape and `/api/data/v9.2/` invocation differ.
4. **IsPrivate** (SOP §7) — true only if internal-only and never user-callable.
5. **AllowedCustomProcessingStepType** (SOP §6) — only `None` blocks "When an action is performed" Power Automate triggers. Default to `AsyncOnly` to allow async-only Power Automate consumers.
6. **ExecutePrivilegeName** (SOP §8) — **Do NOT grill this.** HSO ruling (Ivan Kurtev, 2026-06-13): leave it empty; table privileges are the gate. A dedicated execute privilege would only be worth it if Dataverse let us mint a purpose-built privilege for the API — it does not. Absence is not a gap; do not raise it.
7. **Request parameters** (SOP §9) — name, type (note Workflow type restrictions), required, description.
8. **Response properties** — follow the HSO standard envelope (SOP §10): `Success` (Boolean), `Message` (String), optional `*Count` and `RecordId`.
9. **Plugin implementation** (SOP §11) — stage 30, output on every code path including exceptions, depth check, configuration-data limitation.
10. **Error handling** (SOP §17) — atomic operations: `ExecuteTransactionRequest`. Non-atomic: catch + envelope.
11. **Solution placement** (SOP §22) — `Hso<Domain>CustomApis` + `Hso<Domain>Plugins` separation.
12. **Versioning** (SOP §21) — breaking changes: rename, don't mutate.

### Scenario probes for Custom API
- "The Custom API returns Success=false. What does the calling form script do?"
- "A Power Automate flow calls this with the wrong type. What's the error path?"
- "Someone removes a request parameter in v2. What breaks?"
- "The internal plugin throws. Does the response envelope still fire?"

---

## D. Form / UI-config spec

SOP root: `shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md` (forms) + `view-configuration-best-practices.md` (views)

1. **Main form vs Quick Create vs Quick View** — what's the user task?
2. **Tab strategy** — one-tab-per-process-phase vs domain grouping. *Recommended default:* tab-per-phase for transactional records.
3. **Header strategy** — what stays visible when scrolling? Max 4 fields in header.
4. **Subgrids** — related table + view + add/edit/delete privileges + view selector locked or open.
5. **Timeline** — which activity types? Default sort? Filters?
6. **Quick View Controls** — for lookups that need inline detail.
7. **Business rules vs JS** — *Recommended default:* business rules for simple show/hide/require; JS for anything conditional, async, or involving Xrm.WebApi.
8. **Form events** — OnLoad / OnSave / OnChange handlers. Async OnSave only if necessary (10-second budget per the web-resource SOP).
9. **Form libraries** — namespace pattern (web-resource SOP §5).
10. **Mobile + offline** — does this form work on the mobile app? Offline-enabled?
11. **Accessibility** — keyboard nav, screen-reader labels, WCAG 2.1 AA compliance.

### Scenario probes for forms
- "A user with read-only access opens this form. What's visible / editable?"
- "Slow network, OnLoad makes 3 Xrm.WebApi calls. What does the user see?"
- "The lookup return record is deactivated. Filter rules still apply?"
- "Mobile screen size. Tabs / subgrids still usable?"

---

## E. Security-role spec

SOP root: `shared/dv/agent/wiki/sop/security/security-best-practices.md`

1. **BU strategy** (SOP §4) — *Recommended default:* minimize BUs. One BU unless geographical / regulatory / data-isolation drives more.
2. **Role taxonomy** (SOP §6) — modular / self-contained / base-delta. *Recommended default:* modular (composable per-table or per-feature). Never copy System Administrator.
3. **Privilege depth per table** (SOP §5) — User / BU / Parent:Child / Organization. Start at the narrowest depth that works.
4. **Team type** (SOP §8) — Owner / Access / Entra Group. *Recommended default:* Owner Team for shared work; Access Team for ad-hoc sharing; Entra Group when role assignment should follow Entra membership.
5. **POA implications** (SOP §9) — if Access Teams or explicit sharing are in design, estimate POA growth.
6. **Hierarchy Security** (SOP §10) — only if manager-sees-employee data is a requirement. ≤50 users per node, ≤5 depth.
7. **Field Security Profile** (SOP §11) — for column-level security. Assign to teams, never users.
8. **Custom API ExecutePrivilegeName** (SOP §12) — **not grilled** (HSO ruling 2026-06-13: leave empty, table privileges govern). Do not raise its absence.
9. **ALM travel** (SOP §15) — does the role survive solution deployment? Reference the component-travel table.

### Scenario probes for security
- "A user changes BUs. What records do they lose / gain access to?"
- "An Access Team has 500 records shared. Performance impact?"
- "Manager goes on leave; their direct reports need temporary elevation. How?"
- "FLS field shows masked value. What does the form script see?"

---

## F. Power Pages spec

SOP root: `shared/dv/agent/wiki/sop/power-pages/power-pages-best-practices.md`

1. **Site type** (umbrella SOP) — design studio / code site / Claude Code plugin. *Recommended default:* design studio for forms-over-data; code site for custom React UX.
2. **Enhanced data model** — *HSO mandate:* always Enhanced. Standard is deprecated for new sites.
3. **Authentication** (security SOP) — Entra External ID. Local auth is deprecated.
4. **Web roles** — Authenticated Users / Anonymous Users / custom roles.
5. **Table permissions** (security SOP) — 5 scopes: Global / Contact / Account / Self / Parent. *Trap:* `AttributePermissionIsMissing` on lookups.
6. **Column permissions** — for any sensitive column.
7. **Page permissions** — anonymous vs authenticated.
8. **CSP + nonces** — auto-nonced Liquid; review any inline scripts.
9. **WAF + deep scan** — production checklist.
10. **PCF in Pages** — QA gauntlet from the design-studio SOP.

### Scenario probes for Power Pages
- "Authenticated user with no role hits the page. What happens?"
- "Form submits, plugin runs as Application User. Does it have the privilege?"
- "User edits their profile; lookup column updates fail. AttributePermissionIsMissing?"
- "External attacker probes a contact form. WAF rules in play?"

---

## G. Power Automate cloud flow spec

SOP root: `shared/dv/agent/wiki/sop/power-automate/power-automate-cloud-flow-best-practices.md`

1. **Trigger** — Dataverse / scheduled / instant / HTTP. *Recommended default:* Dataverse trigger with filtering attributes.
2. **Run-as** — flow owner vs connection reference. *Recommended default:* connection reference (ALM-friendly).
3. **Error handling** — Try-Catch scope + Terminate(Failed) + error logging table.
4. **Concurrency control** — does the flow need a singleton lock? Concurrency 1?
5. **Idempotency** — what if the same trigger fires twice?
6. **Solution placement** (ALM SOP) — `*Automations` solution.
7. **Connection references + environment variables** — *HSO mandate:* never hardcode environment-specific values.
8. **Performance** — degree-of-parallelism on Apply-to-each; pagination on List Records.
9. **Monitoring** — Application Insights or table-based logging?

### Scenario probes for Power Automate
- "Trigger fires 1000 times in a minute. Throttling?"
- "The Dataverse action times out. What's the state of the record?"
- "Flow runs as System Administrator in dev, but production uses an Application User. Permission gaps?"
- "The flow loops back into the same table — recursion?"

---

## H. Solution-architecture decisions (cross-cutting)

SOP root: `shared/dv/agent/wiki/sop/dataverse-solutions/dataverse-solutions-best-practices.md`

These often come at the END of a grill, after feature-specific decisions are resolved.

1. **One solution vs many** (segmentation SOP) — *Recommended default:* horizontal segmentation: Core / Feature / Automations / UIExtensions.
2. **Publisher** (publishers-and-versioning SOP) — *HSO mandate:* never use Default Publisher. Confirm publisher exists, prefix is correct.
3. **Versioning** — semver `major.minor.build.revision`; BuildId-suffix in pipelines.
4. **Managed vs unmanaged** — *HSO mandate:* managed in all non-dev environments.
5. **Patches vs upgrades vs holding solutions** (patches SOP) — only relevant if removing components from production.
6. **Solution Checker policy** (checker SOP) — which severity blocks merge?

---

## Cross-cutting questions to always include

Regardless of feature type, the grill should always touch:

- **Telemetry** — what metrics / logs prove this feature works in production?
- **Failure mode** — what does the user see when this feature breaks?
- **Performance budget** — explicit target latency / throughput.
- **Rollback** — if we deploy and it's wrong, how do we revert without data loss?
- **Test strategy** — unit / integration / UI. What's the minimum coverage?
- **Documentation** — who reads this design doc in 18 months, and what do they need?

These five are the most-skipped questions in HSO design reviews; never let the grill exit without addressing them.
