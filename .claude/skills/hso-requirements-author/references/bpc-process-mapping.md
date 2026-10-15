# BPC Process Mapping — the map-or-propose contract

How the Requirements Brief aligns every functional requirement to Microsoft's **Business
Process Catalog (BPC)**, and how it proposes a well-formed custom process where none fits.
This is the Forge half of the shared Forge ↔ the orchestration platform requirements contract
([ADR 0047](../../../../shared/dv/agent/wiki/decisions/0047-bpc-aligned-portable-requirements.md)):
both tools represent a requirement's process coordinates the same way, so a brief can be
derived from the orchestration platform `ProjectWorkItem` rows and vice versa — without loss.

**Non-goals (hard boundary):** this skill *carries or proposes* mappings against a supplied
catalog. It never owns catalog storage, an import UI, or a scoping surface — those live in
the orchestration platform (`CatalogVersion` / `CatalogProcess` / `ProcessScope`).

## 1. The catalog

The base catalog is Microsoft's standard BPC — product-agnostic across Dynamics 365.
15 end-to-end scenarios with stable Catalog IDs:

| ID | End-to-end scenario | | ID | End-to-end scenario |
|---|---|---|---|---|
| 10 | Acquire to dispose | | 65 | Order to cash |
| 20 | Case to resolution | | 70 | Plan to produce |
| 30 | Concept to market | | 75 | Source to pay |
| 40 | Design to retire | | 80 | Project to profit |
| 50 | Forecast to plan | | 85 | Prospect to quote |
| 55 | Hire to retire | | 90 | Record to report |
| 60 | Inventory to deliver | | 95 | Service to deliver |
| | | | 99 | Administer to operate |

CE/Dataverse-heavy scenarios: **20 Case to resolution, 30 Concept to market, 85 Prospect to
quote, 95 Service to deliver** — but map against the whole catalog; app-dev requirements
frequently land in others (e.g. 99 Administer to operate).

**Levels & numbering** (`ProcessSequenceId`, per the JUL 2026 release): IDs are
**fully-qualified, zero-padded dotted codes** — one segment per level. All six levels are
numbered: L1 end-to-end (`10.00.000.000`, "This to That" naming) › L2 business process area
(`10.05.000.000`, verb–noun) › L3 business process (`10.05.010.000`, verb–noun) › L4
scenario/pattern (`65.20.025.250`) › L5 system process (`65.20.025.250.100`) › L6 test case
(`65.20.025.250.100.100`). **Treat IDs as opaque verbatim strings** — never trim the `.000`
padding, never re-derive segments. Map FRs at **L2–L4** — L3 is the sweet spot; use L4 only
when the FR is genuinely scenario-specific.

**Releases drift.** Microsoft updates the catalog at least quarterly, and processes **move**:
each release's `Alternate process sequence ID` column records a node's prior coordinates
(169 moves in JUL 2026; the 85 subtree was renumbered wholesale). Always record the **catalog
release** mapped against — in the brief's `catalogRelease:` frontmatter and its Process
Mapping header — so tags can be re-validated after a refresh
([reference page](../../../agent/wiki/reference/business-process-catalog.md)).

## 2. Catalog input resolution (export wins, clone as fallback)

1. **Engagement-supplied catalog export** — authoritative when present. An orchestration-platform or
   BPC Excel export (columns `Title 1..6`, `Work Item Type`, `Process Sequence ID`,
   `Module`, `Scope`, `Fit Gap Status`) or a JSON export. This is the *project* catalog: it
   includes ratified custom processes and per-project scoping the standard catalog lacks.
   Look in `agent/raw/discovery/` / ask the user where it lives; record the path in the
   brief's Sources section. Respect its scope column — prefer in-scope processes.
2. **Forge-distributed reference copy** — the standard-catalog fallback. Lives in the
   product wiki at `agent/wiki/reference/business-process-catalog/` (in a consuming repo:
   `shared/dv/agent/wiki/reference/business-process-catalog/`): the four tree workbooks of
   the current release plus **`bpc-process-index.csv`** — a grep-friendly flat index
   (`Level, Title, ParentPath, ProcessSequenceId, WorkItemType, Module, ApplicationFamily,
   Products, …`). Search it by business language; it carries sequence IDs and the full
   six-level tree that the article clone lacks. The wrapper page records the release —
   copy it into the brief's `catalogRelease:`.
3. **Local clone of the standard catalog articles** — last-resort fallback.
   `microsoft/dynamics365-guidance`, `guidance/business-processes/` (`overview.md` +
   per-scenario articles; prose only, no sequence IDs at depth). Ask the user for the clone
   path (commonly a sibling repo, e.g. `..\dynamics365-guidance`); record it in
   `CLAUDE.local.md` once known.
4. **None available** — map at L1/L2 from the table above plus web knowledge of the
   catalog, mark the brief's Process Mapping section "mapped against catalog summary only —
   re-map when a catalog export is available", and say so in Open Questions.

## 3. Per-FR process tag

Every FR carries a process line (directly under the FR bullet) and a row in the Process
Mapping table. Mapping status is one of:

- **`mapped`** — an existing catalog process fits. Tag carries `ProcessSequenceId`, process
  name, and the level path.
- **`proposed-custom`** — no existing process fits; the FR references a proposal `key` from
  the proposals block (§4). *Never leave an FR silently untagged — propose instead.*
- **`unmapped`** — deliberate, rare, with a stated reason (e.g. purely technical NFR-like
  FR). An `unmapped` FR with no reason is a defect in the brief.

Format under the FR:

```markdown
- **FR-1** — Sales staff can convert an accepted quote into an order without re-keying.
  - *Process:* `65.20.025.000` Enter sales orders — 65 Order to cash › 65.20 Manage sales orders — `mapped`
- **FR-4** — Technicians track loaner equipment issued to customers during repairs.
  - *Process:* proposal `loaner-equipment` — under `95.00.000.000` Service to deliver — `proposed-custom`
```

The frontmatter `processes:` field is the rollup — every distinct mapped
`ProcessSequenceId` plus `proposal:<key>` entries — and `catalogRelease:` names the
release mapped against:

```yaml
processes: ["65.20.025.000", "85.25.200.000", "proposal:loaner-equipment"]
catalogRelease: "JUL 2026"
```

## 4. Custom-process proposal block (mirrors `PendingCatalogAddition`)

Proposals live in the brief's **Process Mapping** section as one fenced YAML block. The
shape mirrors the orchestration platform's `PendingCatalogAddition` entity and the `proposedParent` object
its extraction skill emits, so an platform-orchestrated run can ingest proposals into
the approval queue directly; standalone projects ratify them in the brief.

```yaml
proposals:
  - key: loaner-equipment            # local id; FR tags and nested proposals reference it
    name: "Manage loaner equipment"  # verb–noun, per BPC naming conventions
    level: L3                        # proposed catalog level (L2–L4)
    underProcessSequenceId: "95"     # parent existing process (omit when using underKey)
    underKey:                        # parent proposal's key — nested proposals, ratified root-first
    rationale: "Loaner pools have no standard-catalog home; needed for repair-loop outcomes"
    frIds: [FR-4, FR-7]              # originating FRs (traceability)
    status: proposed                 # proposed | ratified | rejected
    assignedProcessId:               # minted at ratification per ADR 0050 (HSO namespace, e.g. HSO100.INS.ACME.007); blank while proposed
```

Field ⇄ `PendingCatalogAddition`: `key` → extraction `proposedParent.key` (dedup),
`name` → `Name`, `level` → `Level`, `underProcessSequenceId` → resolved to
`ParentCatalogProcessId`, `underKey` → `ParentPendingAdditionId`, `rationale` → `Rationale`,
`frIds` → the requirement rows whose `ProposedParentAdditionId` points at the addition,
`status` → `Status` (Pending/Approved/Rejected).

**Naming:** follow the catalog's conventions (§1) — L2 and L3 are verb–noun pairs
("Manage loaner equipment", not "Loaner module"). Check the parent scenario's existing
children first; a proposal that duplicates an existing process is a mapping miss, not a gap.

**Identity & numbering rule ([ADR 0050](../../../agent/wiki/decisions/0050-custom-processes-numbered-hso-namespace.md),
amending ADR 0047's numbering portion — draft; shapes provisional):** custom and
HSO-authored processes **are numbered in an HSO namespace** — a publisher-prefix-style
first segment (provisionally `HSO100`) that can never collide with Microsoft's numeric L1
codes. Provisional shapes: industry-vertical process `HSO100.<vertical>.<seq>` (e.g.
`HSO100.INS.010`); client-specific `HSO100.<vertical>.<client>.<seq>` (e.g.
`HSO100.INS.ACME.007`). **The ID is the identity; the name is a mutable label** — never
key anything on a process name. IDs are minted **at approval/ratification** (pending
proposals keep the `key` as their temporary handle), are never reused, and never encode
Microsoft tree coordinates (parents get renumbered — JUL 2026 moved 169 nodes; see the
[reference page](../../../agent/wiki/reference/business-process-catalog.md)). Never mint
from a numeric band (the retired ADR 0047 `.900+` band collides: standard IDs reach L3
`.950` / L4 `.990`). On ratification, record the minted ID in the proposal's
`assignedProcessId:` and re-tag `BPC:proposed:<key>` → `BPC:<id>`. Code-review evidence on
the orchestration platform mechanics (ID column format-free; two the orchestration platform changes needed — title-parser +
mint-at-approval):
[05-custom-process-identity-evidence.md](../../../agent/work/analysis/orchestration-integration/05-custom-process-identity-evidence.md).
Governance: HSO-central vertical-code registry; per-client sequences; promotion to a
shared HSO extension catalog vian orchestration-platform publish-to-global, not in this skill.

## 5. Portability rule (brief ⇄ `ProjectWorkItem`)

Everything is derivable in both directions. When the orchestration platform supplies requirements, build
the brief from its rows; when Forge authors standalone, the brief carries everything an
import needs.

| Brief element | the orchestration platform `ProjectWorkItem` side |
|---|---|
| FR id (`FR-n`) | row identity (via ADO Tracking map ⇄ `ExternalWorkItemId`) |
| FR text | `Title` / `Description`, `Type = "Requirement"` |
| Process tag (`ProcessSequenceId` + name + path) | `CatalogProcessId` — resolved through the project catalog instance's `CatalogProcess.ProcessSequenceId` |
| Catalog release (`catalogRelease:` frontmatter + Process Mapping header) | the project's `CatalogVersion` instance |
| Status `mapped` / `proposed-custom` / `unmapped` | `CatalogProcessId` set / `ProposedParentAdditionId` set / both null |
| Proposal block entry | `PendingCatalogAddition` row (field map in §4) |
| Fit-gap column (when supplied) | `CustomFieldsJson.fitGapStatus` (`Fit` \| `FitWithHsoSolution` \| `FitWithHarvestedIp` \| `PartialFit` \| `Gap`) |
| Source digest citation (`sources:`) | `SourceKnowledgeSourceId` + `TranscriptExcerpt` provenance |

Two consequences:

- **Use `ProcessSequenceId` (+ name + level path), never a Guid**, as the portable process
  identifier — the orchestration platform `CatalogProcessId` Guids are only meaningful inside one catalog
  instance. For customs without a sequence id, identity is *name + parent path*.
- **Fit-gap is read-only here.** When the orchestration platform (or a catalog export) supplies fit-gap
  verdicts, carry them in the Process Mapping table; never author or overwrite them — the
  fit-gap ladder is the orchestration platform Stage 3.

## 6. ADO projection (tags + parent link)

Ruled in the consuming project's ADO conventions ledger (for Forge-USA itself:
`ADO_CONVENTIONS.md` § "Catalog & process mapping"). Summary:

- Each Requirement/User Story work item gets one tag per mapped process:
  **`BPC:<ProcessSequenceId>`** (e.g. `BPC:65.20.025.000`) — the ID **verbatim from the
  catalog release**, padded segments intact. Proposed-custom FRs get
  **`BPC:proposed:<key>`** until ratification (then re-tag `BPC:<assigned id>` per
  [ADR 0050](../../../agent/wiki/decisions/0050-custom-processes-numbered-hso-namespace.md));
  deliberate unmapped FRs get **`BPC:unmapped`**.
- When the catalog hierarchy exists as work items in the ADO project (the orchestration platform hydrate,
  or the FNO ADO-setup tooling), **also parent the work item under its process node**
  (`System.LinkTypes.Hierarchy-Reverse`) — matching the orchestration platform's own projection (BPC code
  in the process node's title, hierarchy links for lineage). Tags stay on regardless, so
  flat backlogs and hydrated backlogs query the same way.
- No custom fields, no area-path encoding — zero process-template customization required.

**Profile-dependent dimensions** ([ADR 0051](../../../agent/wiki/decisions/0051-ado-process-profile-abstraction.md)
— the ADO process profile is read from the consumer repo's
`agent/wiki/system/ado-projection-profile.md`, never assumed; resolve it per the
`hso-ado-work-items` skill when absent). The FR's work-item type, acceptance-criteria home
(`field` / `description` / `test-case-children`), rule-FR n:1 folding, parenting target,
and shared-field obligations all come from the **canonical profile**
(`hso-ado-work-items/references/process-profiles/<id>.md`) — do not hard-code them here.
[ADR 0049](../../../agent/wiki/decisions/0049-new-format-consumer-project-profile.md)
remains the authority on the `hso-us-new-format` profile's content (custom `Requirement`
type, test-case-as-AC, BPC Process-node parenting, `Client Owner`/`HSO Owner`/`Due Date`
skip-and-note while reference names are TBD).

**Tags (this section's rules) and the FR → work-item map are identical on every profile.**

## 7. Workflow insert (the map-or-propose pass)

Runs after requirement extraction, before the brief is written:

1. Resolve the catalog input (§2), load it once, and note the **catalog release** for the
   brief (`catalogRelease:` frontmatter + Process Mapping header).
2. For each FR: find the best-fitting process (search by business language, not module
   names — with the reference copy, grep `bpc-process-index.csv`; check the in-scope subset
   first when the export carries scoping). Record the tag.
3. Where nothing fits at L2–L4: draft a proposal (§4) — name per conventions, parent
   scenario chosen, rationale written, FR ids attached. Batch-review all proposals with the
   user before finalizing (they are sign-off items, like the FRs themselves).
4. `unmapped` only with a written reason.
5. Fill the Process Mapping section + frontmatter `processes:` rollup; carry fit-gap
   verdicts only if supplied (§5).
6. On ADO projection (SKILL step 7), apply the tag + parent-link rules (§6).
