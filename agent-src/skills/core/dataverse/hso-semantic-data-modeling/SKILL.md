---
name: hso-semantic-data-modeling
layer: atomic
scope: core
description: |
  Research industry standards and CDM before designing any new Dataverse table. Use when:
  (1) User is about to design a new custom table or entity
  (2) hso-dataverse-architect invokes this as a mandatory prerequisite for new table design
  (3) User asks "what does CDM say about X" or "how does Salesforce/SAP/Oracle model X"
  (4) User needs to assess integration readiness (Dual Write, Virtual Tables, connectors)
  (5) User needs naming conventions for AI-augmented fields, document pointers, or PA correlation fields
  (6) User is designing a hub-and-spoke or type-extension schema pattern
  Does NOT create tables or columns — that is hso-dataverse-data-modeling.
  Does NOT produce the full feature spec — that is hso-dataverse-architect.
  This skill is the RESEARCH GATE that runs before design decisions are made.
---

# Semantic Data Modeling

Strategic research skill — determines *what* to build before *how* to build it.
Run before `hso-dataverse-architect` produces any new table design.

## When This Skill Is Invoked

`hso-dataverse-architect` invokes this skill whenever a new custom table is being proposed.
It can also be invoked directly when evaluating integration scenarios or naming conventions.

**The gate is the RUN of this skill, not the existence of a summary.** A "Semantic Research
Summary" the architect authors itself "from CDM/OOB knowledge" does not satisfy the
semantic-research gate — the downstream gates (architect DoR, `Validate-SpecJson.ps1`,
the SOP-conformance review) require the dedicated `semantic-research.md` artifact this
skill produces, in the feature's spec folder. **No self-granted waivers:** a client
constraint (licensing tier, "no first-party apps") narrows the candidate space and is
recorded inside the research as elimination rationale — it never waives the research.

---

## Mandatory Research Checklist

Complete ALL steps before proposing any new table or column:

### Step 1 — Microsoft CDM Research

1. Search [Common Data Model GitHub](https://github.com/Microsoft/CDM/tree/master/schemaDocuments) for the entity domain
2. Check if Microsoft D365 has an OOB entity that covers the requirement — prefer OOB over custom
3. If OOB exists: document the standard entity name, key fields, and relationships
4. If no OOB: note that a custom table is justified and document the justification

**Questions to answer:**
- Does an OOB D365 CE / F&O / Field Service entity exist for this concept?
- Are there standard CDM fields that should be adopted (same logical name)?
- What relationships does CDM define for this entity?

---

### Step 2 — Industry Equivalent Research

For every proposed table, document the equivalent in at least two of:

| Platform | Research target |
|----------|----------------|
| **Salesforce** | Object API name, standard fields, relationships |
| **SAP S/4HANA** | Business object, key fields, integration tables |
| **Oracle** | Module, table name, key columns |
| **ISV / industry standard** | Relevant ISV schema (e.g., Field Service ISV, insurance, financial) |

**Why:** Integration projects assume semantic alignment. If our `hso_project` maps to
Salesforce `Opportunity`, column names and data types must be compatible for connectors
and Dual Write scenarios.

**Output format per table:**

```
Table: hso_project
CDM equivalent: msdyn_project (Project Operations)
Salesforce: Opportunity (partial) / Project__c (custom)
SAP: PS_PROJECT_DEF (Project Definition)
Integration readiness: Data type compatible; hso_startdate_date → PS_PSPNR.PSPID (text mismatch — store as text, convert on export)
```

---

### Step 3 — Column-Level Semantic Mapping

For every proposed column, document:

| Column (HSO `_suffix`) | Data type | CDM / external equivalent | Integration notes |
|------------------------|-----------|--------------------------|-------------------|
| `hso_projectname_text` | Text 200 | `msdyn_subject` (Project Ops) | Direct map |
| `hso_startdate_date` | DateOnly | `msdyn_scheduledstart` | Direct map |
| `hso_estimatedcost_amt` | Currency | SAP `KOSTO` | Precision: 2 decimal places required |

---

### Step 4 — Integration Readiness Assessment

| Integration scenario | Assessment |
|---------------------|-----------|
| **Dual Write** | Is the entity in the Dual Write entity map? Does it require Finance & Operations alignment? |
| **Virtual Tables** | Does an external system own this data? Should this be a Virtual Table instead of a native table? |
| **Connector compatibility** | Does the Dataverse connector expose this entity? Are field types connector-compatible (no multi-select, no customer fields)? |
| **External API** | Will this entity be exposed via Custom API? Document payload shape and type requirements now. |

---

### Step 5 — Naming Convention Verification

**Authority for Dataverse column/table naming** — read [`dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) before naming any column or table. The tables in this step are a digest of that SOP for quick verification — they are not a substitute. The SOP is authoritative; design names from it, then verify against the tables below.

| Pattern | Correct | Prohibited |
|---------|---------|------------|
| Boolean fields | `hso_isapproved_yn` | `hso_IsApproved`, `hso_isapproved` |
| DateTime | `hso_duedate_date` | `hso_DueDate`, `hso_due_date` |
| Text | `hso_projectname_text` | `hso_ProjectName`, `hso_projectname` |
| Lookup | `hso_account_id` | `hso_AccountId`, `hso_accountid` |
| Choice | `hso_status_code` | `hso_Status`, `hso_statuscode` |
| Custom API (exception) | `hso_SubmitForApproval` | `hso_submitforapproval` |

#### Special Field Conventions

The AI-field, document-pointer and PA-correlation names below are a digest of the [`dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) SOP — read the SOP before designing these fields; the names here are pointers for verification, not the authority.

**AI-augmented fields** (read-only outputs from AI processing):

| Purpose | Column name | Type |
|---------|-------------|------|
| AI processing flag | `hso_isaiprocessed_yn` | Yes/No |
| Confidence score | `hso_confidencescore_dec` | Decimal |
| Extracted text value | `hso_aiextractedvalue_text` | Text |
| AI model version | `hso_aimodelversion_text` | Text |

Rules: AI output fields are **read-only** — only the processing service writes them. Never expose in editable form sections.

**Document storage pointer fields:**

| Purpose | Column name | Type |
|---------|-------------|------|
| SharePoint document link | `hso_sharepointurl_text` | Text 2000 |
| Azure Blob URI | `hso_azurebloburi_text` | Text 2000 |
| Blob integrity checksum | `hso_blobchecksum_text` | Text 100 |

**Power Automate flow correlation:**

| Purpose | Column name | Type |
|---------|-------------|------|
| PA flow run ID (for audit/retry) | `hso_paflowrunid_text` | Text 100 |

---

### Step 6 — Design Pattern Selection

Choose the structural pattern before proceeding to schema design:

#### Hub-and-Spoke

Use when: One core entity (hub) exists across multiple business domains, each domain extends it with type-specific columns.

```
hso_contract (hub — shared fields: parties, dates, status, value)
    ├── hso_salescontract     (spoke — sales-specific columns)
    ├── hso_procurementcontract (spoke — procurement-specific)
    └── hso_employmentcontract  (spoke — HR-specific)
```

Each spoke has a 1:1 lookup to the hub. The hub holds universal lifecycle status.

#### Type Extension (polymorphic)

Use when: A single table needs different field sets per record type, but the number of types is small and stable.

Add `hso_type_code` to the base table. Show/hide field groups in form scripts based on type.
Only use when types share >60% of fields — otherwise use hub-and-spoke.

#### Simple Custom Table

Use when: No type variation, no cross-domain reuse. Most common case.

---

### Step 6a — Config/Reference-Data Posture Classification (MANDATORY for every coded column)

**Every coded or enumerable column gets an explicit, recorded classification** — one of
**config-table lookup**, **global choice**, or **free text** — with the decision and its
rationale recorded per column in the output artifact. The failure this step kills:
framing the decision as *choices vs text* and never evaluating config tables at all.
Authority: [`data-modeling-best-practices.md` §9](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md) (the config-table posture subsection) and the
[configuration-data SOP](../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md).

| Signal on the code set | Classification |
|---|---|
| **Admin-maintained**, values change **without a deployment**, or values **carry behavior** (flags, template mappings, rates the app reads) | **Config TABLE** — OrgOwned, `Restrict` delete on lookups from transactional tables, a `hso_code_text` + code **alternate key**, and a **config-data load slice** in the spec (per the configuration-data SOP) |
| Small, **closed**, developer-owned set — changes legitimately ride a deployment | **Global choice** |
| Genuinely uncoded, free-form values | **Free text** — the only case text is legal |

Hard rules:

- **The burden of proof is on NOT creating the config table.** When in doubt between
  table and choice, the default is the table.
- **"Current values unknown" is NEVER a reason for text** when a legacy extraction
  contains the values — load them (a config-data load slice: legacy CSVs upserted via the
  code alternate keys, acceptance = row counts reconcile to source). An argument against
  *inventing choice values* is not an argument for *text*; it is an argument for the
  config table plus the data load.
- A reference list shipped as a free-text column is a data model that must be rebuilt —
  classify now, not at remediation.
- **A *Type* on a transactional table defaults to a config-table lookup** (SOP §9 "The
  Type column pattern"): a small, currently-closed value set is *necessary but not
  sufficient* for a choice. A business-domain concept — Contract Type, Order Category,
  Case Type — is a table even when few / closed / stable, because domain codes accrue
  payload (behavior flags, routing, subtype hierarchies) and choice→table promotion is a
  rebuild plus migration; choices are reserved for technical enumerations and pure labels.
  **Requirements silence is not evidence for the choice** — record the trajectory
  argument, not the current count.
- **Calendar dimensions (fiscal year / period, budget cycle, plan year, term, rate period)
  classify as config-table lookup** — never Whole Number alone, never Choice; rules and the
  denormalised-number exception in SOP §9 "[Fiscal year, periods, and other calendar
  dimensions](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md#fiscal-year-periods-and-other-calendar-dimensions--a-table-not-a-scalar)".
- **When the values come from a legacy extraction, record the curation posture** — full
  legacy domain (with a dedupe/retire plan) vs curated go-forward set (with the source
  list and crosswalk) — per the configuration-data SOP §1a; it rides on the load slice.

---

## Output Format

Produce the **dedicated gate artifact** `semantic-research.md` **in the feature's spec
folder** — `agent/work/specs/[Feature]/semantic-research.md` — one file per feature,
with a numbered section per proposed entity. This is the file the downstream gates key
on (`spec.json` `newTables[]` + `Validate-SpecJson.ps1`); a summary embedded in the spec,
or a file elsewhere, does not satisfy them. It carries wiki frontmatter (`type: analysis`)
and **dated provenance** — a `**Written by / Date / Skill**` byline, and the date of every
volatile Microsoft page cited (the restricted-tables list changes; pin what you read).

```markdown
---
title: "Semantic Research Summary — [Feature]"
type: analysis
status: active
scope: project
client: [client-id]
project: [project-id]
topics: []
people: [author-slug]
sources: [requirements.md]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Semantic Research Summary — [Feature]

**Written by:** [author] · **Date:** YYYY-MM-DD · **Skill:** `hso-semantic-data-modeling` (research gate, run before `hso-dataverse-architect` designs any table)

## 1. [Entity] (legacy source, row counts where known)

### CDM Research
- **OOB equivalent: [verdict].** One nested bullet per candidate evaluated, each ending in
  a hard verdict — with **deprecation citations** (link + date) and **restricted-table
  citations** (the Learn restricted-entities list, page date) where they drive the
  elimination, and the licensing consequence quantified.
- **CDM fields adopted:** [list or "none — reason"]
- **Custom table justified: YES/NO — reason.** (For any external party: the
  Account/Contact rejection must be defended here — see Critical Rules.)

### Industry Equivalents
| Platform | Object | Key fields / pattern |
|----------|--------|-----------|

### Column Semantic Map
[table from Step 3]

### Integration Readiness
[table from Step 4]

### Design Pattern: [pattern]
[rationale; end with] **Proposed table(s):** `hso_[tablename]`

## N. Configuration lookups — table vs global choice vs text
[the classification table from Step 6a — every coded/enumerable column, decision + rationale]

## N+1. Naming verification (against `dataverse-naming-conventions.md`)
## N+2. Red flags for the architect

## Sources, References, and Research Methodology
**Method:** [checklist executed, in order]. Then sources — Microsoft pages with page
dates, vendor docs, project sources, SOPs read (with §s).

**Handoff:** `hso-dataverse-architect` consumes this file with the requirements brief;
open questions that block a shape are named here.
```

Hand this document to `hso-dataverse-architect` to proceed with spec creation; the spec's
`newTables[]` must match the tables proposed here.

---

## Critical Rules

- **NEVER** propose a new table without completing Steps 1–2 (CDM + industry research)
- **NEVER** use PascalCase for column names — `_suffix` pattern is mandatory (Custom APIs excepted)
- **ALWAYS** check for OOB D365 entity before creating a custom table
- **Party-posture hard rule:** any **external legal or natural party** — anything carrying a tax id / FEIN / UEI / addresses — defaults to **Account** (organization) / **Contact** (person). This applies to **SECONDARY parties too** (subcontractors, sponsors, partner organizations), not just the primary customer/provider: a party's role in the process does not change what it *is*. A custom party table is legal only with a **defended rejection of Account/Contact recorded in `semantic-research.md`** — a side-by-side decision matrix (licensing, OOB capability you would rebuild: addresses, dedupe, merge; cross-platform semantic alignment; baggage). Sales-flavored baggage columns are curable by form/view curation, never a reason to fork the party model. A defensible-sounding custom-party rationale that skips this matrix is a default, not a decision.
- **ALWAYS** assess Dual Write / Virtual Table suitability before committing to native table
- **ALWAYS** classify every coded/enumerable column (Step 6a): config-table lookup vs global choice vs free text, decision recorded per column — the burden of proof is on NOT creating the config table
- **ALWAYS** produce the dedicated `semantic-research.md` in the feature's spec folder before handing off to hso-dataverse-architect — an inline summary in the spec does not satisfy the gate
- **NEVER** accept or record a waiver of this research that the design session granted itself — client constraints narrow the candidate space inside the research; only a human disposition can stand a table up without it
- **For master-data tables (customer / contact / product / location / worker):**
  - **Authority for the master-data system-of-record and domain-decomposition decision** — read the [MDM umbrella SOP §4](../../../shared/dv/agent/wiki/sop/master-data-management/master-data-management-best-practices.md#4-domain-decomposition-for-hso-engagements) before designing a customer / contact / product / location / worker table. It names the six canonical MDM domains and the cross-domain join question (Customer ↔ Worker, Customer ↔ Vendor) that affects the table's identity model.
  - **Authority for external-MDM alternate-key columns** — read the [external-MDM peer SOP §11](../../../shared/dv/agent/wiki/sop/master-data-management/external-mdm-integration-best-practices.md#11-alternate-keys-for-external-system-reference) before designing any table that subscribes to Profisee / Reltio / Stibo / SAP MDG / Informatica. It names the composite `hso_externalsystemname_code + hso_externalsystemid_text` columns required for that subscription.
  - The names cited here are pointers; the [Master Data Management SOP family](../../../shared/dv/agent/wiki/sop/master-data-management/) is authoritative.

---

## Task → Primary Authority

This skill defers to several authoritative SOPs. For a standalone task, read the primary authority below before designing:

| Task | Primary authority |
|------|-------------------|
| Name any column or table (`_suffix` pattern, AI / document-pointer / PA-correlation fields) | [`dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) |
| Decide system-of-record / domain decomposition for a master-data table | [MDM umbrella SOP §4](../../../shared/dv/agent/wiki/sop/master-data-management/master-data-management-best-practices.md#4-domain-decomposition-for-hso-engagements) |
| Add external-MDM alternate-key columns (Profisee / Reltio / Stibo / SAP MDG / Informatica) | [external-MDM peer SOP §11](../../../shared/dv/agent/wiki/sop/master-data-management/external-mdm-integration-best-practices.md#11-alternate-keys-for-external-system-reference) |

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
