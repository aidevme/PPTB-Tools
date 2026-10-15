# Grilling Patterns

Question-phrasing templates, scenario-probe library, and conflict-handling playbook for `hso-grill-architect`. The pattern is more important than the words — every question should pair a **named choice**, a **recommended answer**, and a **cited source**.

---

## 1. Question phrasings

### The four-part recommended-answer question

Every grill question follows the same shape:

```
[NAMED CHOICE] · [SOP / SCHEMA / DIGEST RECOMMENDATION] · [REASONING IN ONE CLAUSE] · [ACCEPT / OVERRIDE / REFINE]
```

#### Examples

- **Data modeling — table type**
  > "Table type — the data-modeling SOP §3 recommends a **standard** table here because the record won't appear in timelines or calendars and isn't externally sourced. Agree, or is there an activity / virtual case I'm missing?"

- **Plugin — stage**
  > "Plugin stage — event-handler SOP §2 recommends **PostOperation sync** because you said the rollback-on-failure semantics depend on the parent transaction. Agree, or do you need PreOperation to modify the target?"

- **Custom API — IsFunction**
  > "IsFunction — custom-api SOP §5 says **false** by default. The operation you described creates an audit record, so it has side effects → must be an action. Agree?"

- **Security — privilege depth**
  > "Privilege depth on Account for the Sales Rep role — security SOP §5 recommends starting at **User**. Your discovery digest from 2026-04-22 mentions team-based sharing of named accounts, which means we'd need BU. Which is it: User with explicit share, or BU?"

### Bad question phrasings (avoid)

- ❌ "What table type do you want?" *(no recommendation, no source)*
- ❌ "Should we use a plugin or a Custom API?" *(no source, no reasoning, multiple choices in one question)*
- ❌ "What about security?" *(too broad — pick one node)*
- ❌ "Are you sure?" *(no information; just rephrase the question)*

### When to escalate to a "why" question

If the architect overrides the recommendation without giving a reason, ask **once**:

> "Override noted. Help me understand — the SOP recommends X because Y. What's the constraint that makes Y not apply here?"

If they still don't give a reason, record the override + flag for ADR review, and move on. Don't grind.

---

## 2. Scenario-probe library

Use these to stress-test a node before declaring it resolved. Pick two that target different failure modes (concurrency, scale, permissions, edge state).

### Generic Dataverse scenarios

- **Concurrent edit:** "Two users open this record at the same time, both edit field X, both save within 5 seconds. What happens?"
- **High volume:** "This table has 500k rows in production after 18 months. Does your query / view / plugin still hold?"
- **Permission gap:** "A user with only Read on this table opens the form. Does your form script error? Do they see masked data?"
- **Parent deletion:** "The parent record gets deleted. What happens to this child / lookup / activity?"
- **Mid-process failure:** "The user is halfway through a multi-step process and the plugin throws. What's the state of the records?"
- **Async race:** "The async workflow / Power Automate flow hasn't finished when the user reopens the record. Stale data?"
- **Offline / mobile:** "User creates this record offline on mobile. Does it sync correctly? Does the OnSave script even run?"

### Plugin-specific scenarios

- **Recursion:** "Your plugin writes back to the same record. Depth-check in place?"
- **External-call failure:** "The external service you call from this plugin is down for 30 seconds. Sync mode = user-blocking error. Acceptable?"
- **ExecuteMultiple bulk:** "Someone does a 1000-record bulk import. Does the plugin survive the 2-minute hard limit?"
- **Filtering attribute miss:** "The plugin fires on Update of an unrelated column because filtering attributes weren't set. What's the blast radius?"

### Custom API scenarios

- **Privilege gap:** "A user calls the Custom API but lacks the underlying table privilege. What's the response envelope?"
- **Invalid input type:** "Power Automate passes a string where you expected a Guid. Error path?"
- **Breaking change:** "v2 adds a required parameter. v1 callers break. Plan?"
- **No-output exception:** "The internal plugin throws before populating the output parameters. What does the caller see?"

### Security scenarios

- **BU move:** "User moves from BU-A to BU-B. With `AlwaysMoveRecordToOwnerBusinessUnit` = false, what records do they keep / lose?"
- **Access Team scale:** "An Access Team has 5000 records shared. Performance impact on POA queries?"
- **FLS bypass:** "A workflow / plugin reads the FLS-secured column. Does FLS apply?"
- **Manager leave:** "Hierarchy Security manager goes on PTO. Does coverage exist for their direct reports' access?"

### Power Pages scenarios

- **Anonymous probe:** "External attacker hits the form endpoint with no auth. WAF? Table permission scope?"
- **Lookup AttributePermissionIsMissing:** "User edits profile, lookup column updates fail with `AttributePermissionIsMissing`. Cause?"
- **Liquid + CSP:** "Designer adds an inline script tag. CSP nonce applied?"
- **Plugin elevation:** "Form submit runs an Application User plugin. Does the plugin have higher privilege than the portal user? Intended?"

### Power Automate scenarios

- **Trigger storm:** "1000 records updated in a minute. Concurrency 50, degree-of-parallelism 20. Throttling? Backpressure?"
- **Dataverse-action timeout:** "List Records times out. Pagination set? Retry policy?"
- **Connection mismatch:** "Flow promoted from dev to prod; connection reference points to dev's Application User. Permission diff?"
- **Loop-back:** "Flow updates a record on the same table that triggers it. Recursion guard?"

---

## 3. Conflict-handling playbook

When the architect's answer contradicts a prior decision, the live schema, or a digest, surface it immediately. Don't accumulate; interrupt the flow.

### Conflict types and responses

#### Conflict with live schema

> "Hold on — you said the new lookup should target Account. The schema already has a lookup from this table to Account called `parentaccountid`. Same lookup, or do we need a second one? If second, what's the relationship name?"

**Action:** freeze the node, run `hso-dataverse-data` to confirm, present options.

#### Conflict with prior decision in this session

> "Earlier you said this table is user-owned. Now you're describing org-wide visibility with all users seeing all records. User-owned + Org-depth read = a lot of POA. Re-confirm ownership, or are we promoting to org-owned?"

**Action:** show both decisions side-by-side. Strike-through the loser; record the reason in the spec's Decisions section.

#### Conflict with a prior ADR

> "ADR-0012 (`2025-11-04`) decided we use Custom APIs over plugins for any user-initiated business operation. Your current answer suggests a Pre-validation plugin instead. Override the ADR, or refactor to a Custom API?"

**Action:** if the ADR is overridden, that override is itself an ADR-worthy decision — propose one.

#### Conflict with a digest

> "The discovery transcript from 2026-03-18 (`agent/wiki/digests/2026-03-18-finance-team.md` §`Required workflows`) says the finance team needs approval before posting. Your current flow doesn't include an approval step. Did the requirement change, or did we miss it?"

**Action:** never silently override discovery. Confirm with the architect that the change is intentional.

#### Conflict with a naming convention

> "Column name `Account_Number` — naming convention SOP requires lowercase + type suffix → `hso_accountnumber_text`. Adjust?"

**Action:** strict — naming conventions are non-negotiable; don't grill, just correct.

#### Conflict with an SOP best practice

> "You proposed a polymorphic lookup with 4 targets. Data-modeling SOP §13 strongly recommends avoiding polymorphic unless the targets share a true is-a relationship. What's the is-a here, or should we model 4 separate lookups?"

**Action:** SOPs can be overridden with reason; capture the reason verbatim, flag for ADR.

---

## 4. Sharpening fuzzy language

Watch for these vocabulary traps and correct them on the spot.

| Architect says | Could mean | Sharpen to |
|---|---|---|
| "the account" | Account table, parent Account record, account record displayed in the form, the user's tenant | Specify: Account table / parent record / displayed record |
| "the user" | Logged-in systemuser, contact, portal user, application user, integration user | Specify: systemuser / contact (Power Pages) / appuser / integration appuser |
| "the entity" | Table (Dataverse 9.x+ vocabulary) | Use "table" |
| "field" | Column (Dataverse vocabulary), or form-field-control | Use "column" for metadata; "form field" for UI |
| "validation" | Server-side plugin invariant, business rule, JS OnSave handler, Power Automate post-create check | Specify the layer: plugin / business rule / form script / flow |
| "approval" | Manual user click, automated rule, Approvals connector, custom approval table | Specify the mechanism |
| "the workflow" | Classic workflow, Power Automate flow, business process flow, real-time workflow | Specify: classic workflow / cloud flow / BPF / real-time workflow |
| "sync" | Sync plugin, sync workflow, real-time data sync (Synapse / Fabric), Dual-Write | Specify the technology |
| "async" | Async plugin, async workflow, Power Automate, Service Bus, queue | Specify the mechanism |
| "the API" | Web API, Custom API, Custom Process Action, organization service, Connector API | Specify which |
| "the form" | Main form, Quick Create, Quick View, Card form, mobile form | Specify the form type |
| "permissions" | Table privileges, column-level (FLS), record-level (sharing), role privileges | Specify the layer |

---

## 5. Recommended-answer sourcing — quality bar

Every recommendation must cite a source. Sources rank:

1. **Live schema fact** — strongest. "Schema query just returned `account.parentaccountid` exists."
2. **SOP section** — strong. "data-modeling SOP §3 says…"
3. **ADR** — strong. "ADR-0012 decided…"
4. **Prior digest with citation** — moderate. "The 2026-03-18 transcript said…"
5. **Naming convention** — strict (non-overridable for naming).
6. **Microsoft documentation** — moderate. "Microsoft docs say the limit is 5000…"
7. **Industry standard (CDM, Salesforce, SAP)** — moderate. "CDM models this as…" *(usually via `hso-semantic-data-modeling`)*
8. **"My reading of the patterns is…"** — weakest. Use only when 1–7 don't apply, and SAY SO explicitly so the architect knows to verify.

**Never fabricate a citation.** If you can't find the source, downgrade the recommendation to "my reading is X — please verify" or skip the recommendation and ask the architect.

---

## 6. Exit messages

When the grill ends, the closing summary should look like:

```markdown
## Grill summary

**Feature:** [one-line description]
**Spec draft:** `agent/work/specs/<FeatureName>/<feature-name>.md`
**Duration:** [N] questions across [M] nodes

### Resolved (count: [N])
- [Decision] — [SOP / source]
- [Decision] — [SOP / source]
- ...

### Overridden (count: [N])
- [Decision] — recommended X per [source]; chose Y because [verbatim architect reasoning]

### Open (count: [N])
- [Item] — owner: [name]; deadline: [date]
- ...

### ADRs proposed
- [Title] — status: drafted (`agent/wiki/decisions/[NNNN]-[slug].md`)
- [Title] — status: deferred (will revisit after [trigger])

### Next steps
- Invoke `hso-dataverse-architect` to author the full design doc + slice DAG
- (or) Invoke `hso-wiki-write-decision` for any deferred ADRs
```

The summary is itself a deliverable — write it into the spec under a `## Design discussion` section, with date and participants.
