# SOP & Companion-Skill Index (on-demand)

Load a row only when the spec touches its trigger. Paths are relative to this skill. The SKILL.md "Standards routing" table is the short list; this file carries the section anchors and the multi-peer SOP families. **Mandatory pre-read** rows must be read before authoring a spec in that area — and this is a **checked contract**: the spec's Sources section must cite each mandatory-pre-read SOP with the sections used for every touched area, and `scripts/Validate-SpecJson.ps1` fails a spec whose touched area lacks the citation. Never cite a SOP you did not open.

## Naming, data model, migration

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Any schema (tables, columns, choices, Custom API, web resource names) | `hso-dataverse-naming-conventions` → [`dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) | Errors here propagate into implementation. |
| Tables / relationships / lifecycle / choices / alt-keys / cascade / deprecation | `hso-dataverse-data-modeling` → [`data-modeling-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md) | §1 OOB-vs-custom, §3 type/ownership, §6 DateTime trap, §9 global choices / config-table posture (incl. the [calendar-dimensions](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md#fiscal-year-periods-and-other-calendar-dimensions--a-table-not-a-scalar) subsection when a spec is fiscal-year- or period-scoped), §10 statecode/statuscode, §11–12 cascade, §13 polymorphic, §15 alt-keys, §19 Dual-Write, §23 pre-merge checklist. Mandatory pre-read. |
| Any data-migration workstream (tooling, sequencing, app-user pattern, bulk-write, mock cutover, reconciliation, PII) | umbrella [`migration-strategy-and-tooling-best-practices.md`](../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md); peers [`ssis-kingswaysoft-best-practices.md`](../../../shared/dv/agent/wiki/sop/data-migration/ssis-kingswaysoft-best-practices.md) (HSO default toolchain), [`powershell-script-based-migration-best-practices.md`](../../../shared/dv/agent/wiki/sop/data-migration/powershell-script-based-migration-best-practices.md) (small one-offs only) | SSIS+KWS for any non-trivial volume. |
| Reference/config data | [`configuration-data/configuration-data-strategy.md`](../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md) | GUID-preservation, remap pattern, shared `Common-Functions.ps1`. |
| Sample / demo / seed / test data | `hso-dataverse-sample-data` → [`sample-data/sample-data-validation-workflow.md`](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md) | The runnable authoring skill (scaffolds the per-dataset CSV + manifest + Import/Export/Remove trio; idempotent GUID-preserving seed). Route sample/seed slices here, **not** to `hso-dataverse-data` (that's ad-hoc one-off CRUD only). |
| New customer/product/location/worker master, cross-source sync, CI-D unification, external MDM hub | umbrella [`master-data-management-best-practices.md`](../../../shared/dv/agent/wiki/sop/master-data-management/master-data-management-best-practices.md); peers `duplicate-detection-`, `data-cleansing-and-standardization-`, `external-mdm-integration-best-practices.md` | Defaults to consolidation/coexistence. 7 HSO Overrides. Mandatory pre-read. |

## Code (plugins / Custom API / PCF / form scripts)

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Plugin / server-side business logic | `hso-plugin-development` → umbrella [`plugin-development.md`](../../../shared/dv/agent/wiki/sop/plugin-development/plugin-development.md) (load first; 24 rules + decision matrix), peers: solution-structure, layered-architecture, business-logic-layer, event-handler-layer, packaging-and-deployment, azure-functions-reuse, common-query-patterns, azure-devops-code-review (all under [`plugin-development/`](../../../shared/dv/agent/wiki/sop/plugin-development/)); testing peer [`testing/plugin-testing-best-practices.md`](../../../shared/dv/agent/wiki/sop/testing/plugin-testing-best-practices.md) | Load only the peers the spec touches. Mandatory pre-read. |
| Custom API (function/action + params) | `hso-dataverse-customapi` → [`custom-api-best-practices.md`](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md) | §1 decision matrix, §3 metadata model, §4 binding, §5 IsFunction default, §10 response envelope, §22 solution layering, §26 checklist. Mandatory pre-read. |
| Form scripts / ribbon / HTML web resource | `hso-formscript-development` → [`webresource-best-practices.md`](../../../shared/dv/agent/wiki/sop/webresource-development/webresource-best-practices.md) | §2 WR-vs-PCF-vs-business-rule, §6 formContext, §8 async budgets, §9 Xrm.WebApi, §16 Solution Checker, §28 checklist. Mandatory pre-read. |
| PCF control | `hso-pcf-control-development` | Virtual controls, Fluent UI, accessibility. PCF perf in [`pcf-performance-best-practices.md`](../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-performance-best-practices.md). |

## UI configuration (forms / views / apps / dashboards / security)

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Forms / views / sitemap / app / subgrids / timeline | `hso-dataverse-ui-config` → [`form-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md), [`view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md), [`app-module-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/app-module-configuration-best-practices.md) | Record Log tab standard (SOP §6); timeline in own section (SOP §9). Consult before any form/view/app spec. |
| Dashboards | `hso-dataverse-dashboards` → [`dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md) | 6-component cap, kind selection, iframe security, Power BI embedded. |
| Security roles / privileges / BU / FLS / sharing | `hso-dataverse-securityrole` → [`security-best-practices.md`](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md); spec template [`security-role-spec-template.md`](../../../shared/dv/agent/wiki/reference/security-role-spec-template.md) | §1 access formula, §3 matrix model, §5 privileges/depths, §9 POA bloat, §10 hierarchy, §11 FLS, §19 checklist. Mandatory pre-read. |
| Form XML / customizations XSD | [`form-xml-schema.md`](../../../shared/dv/agent/wiki/references/form-xml-schema.md), [`customizations-xsd/`](../../../shared/dv/agent/wiki/reference/customizations-xsd/) | ClassIDs, parameters; official Microsoft XSDs. |

## Automation, integration, analytics

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Cloud flow (logic-bearing) | `hso-powerautomate-writer` → [`power-automate-cloud-flow-best-practices.md`](../../../shared/dv/agent/wiki/sop/power-automate/power-automate-cloud-flow-best-practices.md), [`power-automate-alm-and-governance.md`](../../../shared/dv/agent/wiki/sop/power-automate/power-automate-alm-and-governance.md) | Design, error handling, ALM. |
| Service Bus / Webhooks / Event Grid / Functions / Logic Apps / Custom Connectors / VNet / SPN auth | [`azure-integration-best-practices.md`](../../../shared/dv/agent/wiki/sop/azure-integration/azure-integration-best-practices.md) | §1 mechanism matrix, §8 auth (never SysAdmin on app user), §9 service-protection limits. Mandatory pre-read. |
| Power BI / Synapse Link / Fabric Link / TDS | umbrella [`synapse-fabric-link-best-practices.md`](../../../shared/dv/agent/wiki/sop/analytics-integration/synapse-fabric-link-best-practices.md); peers [`tds-endpoint-best-practices.md`](../../../shared/dv/agent/wiki/sop/analytics-integration/tds-endpoint-best-practices.md), [`power-bi-on-dataverse-best-practices.md`](../../../shared/dv/agent/wiki/sop/analytics-integration/power-bi-on-dataverse-best-practices.md) | Load umbrella first. Mandatory pre-read. |
| Platform performance (high-volume integration, sync plugins, sub-grid-heavy forms, observability, capacity, go-live readiness) | [`platform-performance-best-practices.md`](../../../shared/dv/agent/wiki/sop/platform-performance/platform-performance-best-practices.md) | §2 service-protection, §3 journey budgets, §5 sync plugin P95 ≤ 1s, §8 FastTrack workbooks, §16 checklist. Mandatory pre-read. |
| Copilot in D365 / Copilot Studio | [`copilot-in-d365-best-practices.md`](../../../shared/dv/agent/wiki/sop/copilot/copilot-in-d365-best-practices.md), [`copilot-studio-best-practices.md`](../../../shared/dv/agent/wiki/sop/copilot/copilot-studio-best-practices.md) | Quarterly review cadence. Load only the relevant SOP. |

## Solution architecture & ALM

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Segmentation / layering / managed properties / publishers / versioning / patches / Solution Checker | umbrella [`dataverse-solutions-best-practices.md`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/dataverse-solutions-best-practices.md); peers: solution-segmentation, solution-layering-and-managed-properties, solution-publishers-and-versioning, solution-patches-upgrades-and-holding-solutions, solution-checker-and-component-validation (all under [`dataverse-solutions/`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/)) | Load umbrella first. Mandatory pre-read for new solution architecture or component deletion. |
| Per-work-item traceability / change attribution / CAB change-log requirements / Dataverse Git integration + environment-per-work-stream proposals | [`per-work-item-traceability-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/per-work-item-traceability-best-practices.md) | The four-rung ladder (inferred / declared / pipeline-declared / structural). §2 rung choice per client; §6 Tier-3 Managed Environments licensing prerequisite + roadblocks — consult before proposing Git-integration isolation to a client. |
| Power Pages / portal | `hso-dataverse-pipelines` (owns export/import YAML) + six-SOP family under [`power-pages/`](../../../shared/dv/agent/wiki/sop/power-pages/) (umbrella + security, design-studio, code-sites, claude-code-plugin, alm) | Load umbrella first. Mandatory pre-read. |
| Multi-language, multi-currency, localized error messages, users across regions (US/EU/Asia), data residency | [`localization-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/localization-best-practices.md) | §1 provisioning one-way doors (region / base language / base currency), §3 translation ALM, §5 localized errors, §6 currency + `_base` semantics, §7 Dual Write currency, §9 region/residency, §12 checklist. Mandatory pre-read for any multi-language or multi-currency spec. |

## First-party apps

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Field Service (work orders, agreements, scheduling, assets, IoT, FS Mobile, FS↔ERP) | umbrella [`field-service-best-practices.md`](../../../shared/dv/agent/wiki/sop/field-service/field-service-best-practices.md); peers: work-orders-and-incidents, scheduling-and-resources, field-service-mobile, field-service-erp-integration (under [`field-service/`](../../../shared/dv/agent/wiki/sop/field-service/)) | Quarterly cadence. FS↔F&O direct integration retires Feb 2027. Mandatory pre-read. |
| Project Operations (deployment-type, project sales, resourcing, T&E, invoicing, Dual-Write) | umbrella [`project-operations-best-practices.md`](../../../shared/dv/agent/wiki/sop/project-operations/project-operations-best-practices.md); peers: project-sales-and-contracts, resource-management, time-expense-and-invoicing (under [`project-operations/`](../../../shared/dv/agent/wiki/sop/project-operations/)) | Deployment-type decision is the load-bearing kickoff choice (expensive to reverse). Mandatory pre-read. |
| M365 (Exchange / SharePoint / Teams as Dataverse surface) | umbrella [`m365-integration-best-practices.md`](../../../shared/dv/agent/wiki/sop/m365-integration/m365-integration-best-practices.md); peers: exchange-server-side-sync, sharepoint-integration, teams-integration (under [`m365-integration/`](../../../shared/dv/agent/wiki/sop/m365-integration/)) | Mandatory pre-read. |
| Mobile / offline (model-driven mobile, offline profile, offline-surviving form/view/PCF/WR/rule) | [`mobile-and-offline-best-practices.md`](../../../shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md) | Platform baseline every mobile engagement inherits. Mandatory pre-read. |

## CRM processes (cross-app customer-centric design)

Five peers under [`crm-processes/`](../../../shared/dv/agent/wiki/sop/crm-processes/). Each may carry program/governance positions recorded in the engagement wiki (see the Governance & Overrides prerequisite in SKILL.md). **Mandatory pre-read** when the spec touches that process.

| Trigger | SOP |
|---|---|
| Account/Contact model, B2B-vs-B2C shape, customer on Case/WO/Project, dual-write Prospect-to-Cash, multi-LE mastering | [`customer-management-best-practices.md`](../../../shared/dv/agent/wiki/sop/crm-processes/customer-management-best-practices.md) |
| Lead capture/route/qualify/score, Sales Qualification Agent, CIJ→Lead handoff, lead-aging | [`lead-management-best-practices.md`](../../../shared/dv/agent/wiki/sop/crm-processes/lead-management-best-practices.md) |
| Forecast config/columns, Forecast Adjustments, Premium Forecasting, Forecast API daily-sync | [`sales-forecasting-best-practices.md`](../../../shared/dv/agent/wiki/sop/crm-processes/sales-forecasting-best-practices.md) |
| Opportunity BPF/products/pricing, Predictive Scoring, team selling, Goals, dual-write Quote-side | [`opportunity-management-best-practices.md`](../../../shared/dv/agent/wiki/sop/crm-processes/opportunity-management-best-practices.md) |
| Quote/Order/Invoice lifecycle, Quote authoring/revision/e-sign/approval, dual-write Quote-to-Cash, PO `msdyn_quote` path | [`quote-to-cash-best-practices.md`](../../../shared/dv/agent/wiki/sop/crm-processes/quote-to-cash-best-practices.md) |

## Licensing, methodology, testing, go-live, FastTrack

| Trigger | Skill / SOP | Notes |
|---|---|---|
| Any licence-sensitive choice (premium connector, F&O write for CE persona, table on seeded tier, embedded Power BI, Power Pages, Copilot/AI Builder) | `hso-d365-licensing` → [`d365-and-power-platform-licensing-best-practices.md`](../../../shared/dv/agent/wiki/sop/licensing/d365-and-power-platform-licensing-best-practices.md) | This architect skill does NOT carry licensing depth — route to the companion. Name the licence implication in the spec. Mandatory pre-read for licence-sensitive choices. |
| Implementation methodology, business-process alignment, reference architectures | `hso-d365-guidance-reference` | Success by Design, change management, go-live readiness. |
| Test strategy, UAT/SIT gates, smoke pack, test-data management | [`testing-best-practices.md`](../../../shared/dv/agent/wiki/sop/testing/testing-best-practices.md) | Umbrella; owns cross-cutting test types. Mandatory pre-read. |
| Go-live event, cutover plan, hypercare, rollback decision tree | [`go-live-and-operate-best-practices.md`](../../../shared/dv/agent/wiki/sop/go-live-and-operate/go-live-and-operate-best-practices.md) | Mandatory pre-read for any go-live/cutover spec. |
| FastTrack validation (CE/Dataverse only — exclude F&O-only areas) | `hso-fasttrack-reference` | ALM templates, monitoring dashboards, Dual-write KQL, CE integration patterns. |

## Expert reference skills (consult for domain depth)

| Skill | Consult for |
|---|---|
| `hso-ce-apps-sdk-reference` | Sales/CS/Marketing functionality; OOB entity behaviors; licence implications; Project Operations entity reference (project / project-contract / quote / contract-line / time-entry / expense-entry / invoice / `msdyn_actual` / bookable-resource / schedule-board) — Microsoft entity depth behind the `project-operations` SOP family |
| `hso-dataverse-sdk-reference` | Plugin patterns; Web API/OData optimization; client SDK; Custom API design |
| `hso-fieldservice-reference` | Work-order lifecycle; agreement/booking; resource management; mobile (Microsoft official + decompiled) |
| `hso-semantic-data-modeling` | CDM research, industry equivalents (Salesforce/SAP/Oracle), integration readiness — **mandatory before designing any new table** |
