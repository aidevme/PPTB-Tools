# Demo Build Spec Template

A Demo Build Spec maps every segment of a Presenter Clickpath to the specific D365 configuration, data, custom development, and integrations required to support it. It is the developer-facing companion to the presenter-facing Clickpath.

**Output location:** `clients/<ClientName>/PROJ-<project>/04_solutioning/specs/Demo_Build_Spec.md`

---

## Document Header

```markdown
# <ClientName> Demo — Clickpath Implementation Spec

**Status**: In Progress
**Last Updated**: <date>
**Author**: <author from CLAUDE.local.md>
**Source of Truth for Live Execution**: `clients/<ClientName>/PROJ-<project>/04_solutioning/Presenter_Clickpath.md`
**Demo Date**: <date>
**Target Environment**: <environment URL from CLAUDE.md>
**RSO / Secondary Environment**: <if applicable>
```

---

## Required Sections

### 1. Purpose
One paragraph. States what the spec covers: "defines every D365 component, configuration item, data record, and automation that must exist for the Presenter_Clickpath.md to run end-to-end without improvisation."

### 2. Current State Assessment

Two subsections:

**2.1 What Exists** — table of reusable components from existing environment builds:

| Component | Exists? | Reuse Decision |
|-----------|---------|---------------|
| [PCF control] | Yes | Adapt / Reuse / Not applicable |
| [Azure backend] | Yes | Extend with new endpoints |
| [D365 app config] | Partial | Configure for this demo |

**2.2 What Does NOT Exist** — table of net-new items:

| Area | Status |
|------|--------|
| [Feature area] | ❌ Not built |

### 3. Fit-to-Standard Evaluation

Required by `hso-dataverse-architect` for every custom component. Evaluate each capability:

| Capability | OOB? | Declarative? | PA Flow? | Plugin? | Decision |
|-----------|------|------------|---------|---------|---------|
| [Capability] | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | **Chosen approach** |

Document why each step was skipped if reaching Plugin.

### 4. Clickpath-to-Build Mapping

**This is the core section.** For each Part and Section in the Presenter Clickpath:

```markdown
### PART N: [NAME] (Sections N.1–N.x) — X min

#### N.x [Section Name]

**What the clickpath shows:**
[Quote the SHOW + CLICK THROUGH narrative from the clickpath]

**What must exist:**

| Item | Type | Spec |
|------|------|------|
| [Config/data/flow item] | Config / Data / PA Flow / PCF / Integration | [Exact values, record names, field names] |

**Priority:** P0 / P1 / P2
**Skill route:** `hso-<skill-name>`
```

Priority rules:
- **P0** — clickpath segment fails completely without this item
- **P1** — segment is degraded but survivable with a screenshot/fallback
- **P2** — optional branch content; can be omitted from live run

### 5. Data Configuration Spec

Subsections for each data domain. Include exact record names, field values, and relationships for demo data.

Typical subsections:
- Accounts (with SLA tier, key fields)
- Contacts (with demo role)
- Service Agreements + Entitlements
- Customer Assets (primary anchor asset + full hierarchy)
- Bookable Resources (key demo technician in full detail)
- Depots / Warehouses (with inventory quantities — include intentional low-stock for supply chain narrative)
- Historical Work Orders (target count, SLA breach rate to match dashboard numbers)

### 6. PCF Control Specs

For each PCF control required (if any):

| Attribute | Value |
|-----------|-------|
| Based on | [Existing control to adapt, or "new"] |
| Namespace | `HSOMfg` or relevant namespace |
| Constructor | `ControlName` |
| Control type | `standard` or `virtual` |
| Bound field | [Schema name + table] |
| Data source | [WebAPI query] |
| Display | [Visual description] |
| Placement | [Form name, tab name, section name] |

Include fallback note: what the demo shows if PCF is not ready (list/subgrid backup).

### 7. Power Automate Flows

Table format:

| # | Name | Trigger | Key Actions | Demo Section |
|---|------|---------|-------------|-------------|
| PA-1 | [Name] | [Trigger condition] | [Action list] | [Clickpath ref] |

### 8. Mock Integration Layer

If applicable — list backend endpoints required:

| Endpoint | Method | Response Shape | Demo Use |
|----------|--------|---------------|---------|
| `/api/[system]/[operation]` | GET/POST | `{field: value}` | [Which demo segment uses it] |

Note which endpoints are called by Power Automate vs. polled vs. manually triggered.

### 9. Custom Data Model Extensions

Tables of custom fields needed on standard entities. Use `hso_<clientprefix>_<fieldname>_<suffix>` naming:

| Schema Name | Type | Purpose |
|------------|------|---------|
| `hso_bs_fieldname_text` | Single Line Text | [Why needed] |

Group by table. Only list fields not already in the environment.

### 10. Security Roles

Table of roles needed for the demo with base role and key permission differences.

### 11. Implementation Sequence

5-gate structure:
- **Phase A: Data Foundation** — all master data; gate = core scenario WO can be created end-to-end
- **Phase B: Core Workflow** — P0 clickpath segments; gate = Parts 1–4 (or equivalent) run live
- **Phase C: Analytics + Integration** — dashboards, PA flows, mock endpoints; gate = Parts 5–6 run live
- **Phase D: PCF + RSO** — custom controls, external environment validation; gate = visual controls on forms, RSO recommends correctly
- **Phase E: Polish + Rehearsal** — audit config, backup content, timed dress rehearsal; gate = full run ≤ 90 min with no critical failures

### 12. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk] | Low/Medium/High | Low/Medium/High | [Specific mitigation] |

Always include: Copilot underperforms, mobile sync fails, mock endpoint unavailable.

### 13. Skill Routes (Quick Reference)

| Work Item | Skill |
|-----------|-------|
| [Work area] | `hso-<skill-name>` |

---

## How to Generate This Document

Invoke `hso-dataverse-architect` in **Demo Build Spec** mode:

1. Load the completed `Presenter_Clickpath.md` (source of truth)
2. Load all discovery digests from `agent/wiki/digests/`
3. Check the current environment for what already exists (query Dataverse metadata, review existing PCF controls and Azure backend)
4. For each Part/Section in the clickpath, enumerate what must exist and classify by type
5. Run fit-to-standard evaluation for all custom components
6. Write the spec to `agent/work/specs/Demo_Build_Spec.md`

The spec is complete when every SHOW/CLICK THROUGH step in the clickpath can be traced to at least one row in the build mapping table.
