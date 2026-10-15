# Data-governance context (load on demand)

Authority pointers and digests for governed data work with the `hso-dataverse-data` skill. Kept out of `SKILL.md` so it loads only when a task actually touches one of these governed surfaces (pipeline slices, bulk/migration writes, master data, configuration/sample data) — per [ADR 0019](../../../../agent/wiki/decisions/0019-shared-scripts-as-sibling-library-skill.md)'s "keep SKILL.md lean, move heavy content out" spirit. Each block below is a **digest + pointer**; the cited SOP is authoritative — read it before designing the operation.

## Slice Consumption Contract (executor side of the architect→builder pipeline) — *conditional*

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

**This contract is conditional — it applies only when a slice's `touches` include sample/seed data.** When they do, treat the sample data as a **slice touch-type**: build **exactly** the records the slice specifies, trust and verify — don't rebuild — your `blocked_by` slices (the tables/columns/lookups the records bind to already exist), and **read the records back against the slice's `acceptance`, not against an SOP rule the spec never invoked**. This is **NOT** a blanket contract on every ad-hoc data op — out-of-pipeline CRUD (a one-off query, a manual patch) is governed by this skill's own standards, not the slice contract (see the SOP's [*Who this governs*](../../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md#who-this-governs-and-who-it-does-not)).

| When a slice's `touches` include… | What this skill owns | Read-back against `acceptance` |
|---|---|---|
| **sample / seed data** | the seed records the slice specifies (counts, parent lookups, required fields populated) | query the records back — **record counts match**, **lookups resolve** to the right parents, required fields populated — against the slice's `acceptance` |

> All executor skills share the **same** [Slice Consumption Contract](../../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md); the schema the records bind to is the [`hso-dataverse-data-modeling`](../../hso-dataverse-data-modeling/SKILL.md) half of the slice.

## Bulk-write and data-migration context

Authority for bulk-write, status-transition, and post-cutover verification operations — read before designing any migration-workstream data operation: **[Data Migration SOP family](../../../../shared/dv/agent/wiki/sop/data-migration/)**.

The bullets below are a digest only — the Data Migration SOP family is authoritative; read the cited sections before designing any bulk write.

- **Tool fit:** PowerShell + Web API (this skill) is the right path for *post-import patches*, *status transitions* (Win/Lose Opportunity, ResolveIncident, SetState), and the *seven-report verification suite* in [`powershell-script-based-migration-best-practices.md` §5](../../../../shared/dv/agent/wiki/sop/data-migration/powershell-script-based-migration-best-practices.md#5-the-post-cutover-verification-suite--seven-reports). For bulk *transactional* loads, HSO defaults to SSIS + KingswaySoft per [`migration-strategy-and-tooling-best-practices.md` §3](../../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md#3-tool-selection--the-decision-matrix) — don't reinvent that pipeline here.
- **Bulk-write fundamentals:** the umbrella [`migration-strategy-and-tooling-best-practices.md` §7](../../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md#7-bulk-write-fundamentals-every-tool-path-must-respect) names `CreateMultiple` (100–1000 starting batch size, 23× faster than Create, all-or-nothing on standard tables) and `$batch`/`ExecuteMultiple` (1000-op cap, start at batch=10 + raise concurrency until 429s). Bulk operations from this skill apply both contracts directly.
- **Service-protection envelope:** per [§8](../../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md#8-throttling--service-protection-api-limits-and-what-they-mean-for-migration) — 6,000 requests / 1,200,000 ms execution / 52 concurrent per 5-min sliding window per user. Handle 429 by honouring `Retry-After`; for sustained throughput beyond one user, use the user-multiplexing pattern (multiple application users in a pool, round-robin by row hash).
- **`overriddencreatedon`** to preserve historic created dates ([§9](../../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md#9-preserving-historic-timestamps--overriddencreatedon-and-the-modifiedon-problem)) — requires `prvOverrideCreatedOnCreatedBy` on the application user.
- **`BypassCustomPluginExecution`** per call ([§10.1](../../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md#101-bypasscustompluginexecution--the-modern-bypass)) — requires `prvBypassCustomPlugins`. **Default to enabling on migration scripts**, sync plugins are bypassed, async still run.
- **`SuppressCallbackRegistrationExpanderJob`** to suppress Power Automate flow triggers during bulk loads ([§10.3](../../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md#103-power-automate-flow-suppression)).
- **Upsert by alternate key for idempotent re-runs** — every migrated table should carry a `xxx_legacyid` alternate key; the dress-rehearsal contract is that the same script can run multiple times against the same target without creating duplicates ([§6](../../../../shared/dv/agent/wiki/sop/data-migration/ssis-kingswaysoft-best-practices.md#6-upsert-with-alternate-keys--the-idempotency-pattern) of the SSIS peer covers the same pattern).
- **Verification suite:** the `$count` per-entity / FetchXML aggregate per money field / sampled accuracy pattern in [`powershell-script-based-migration-best-practices.md` §5](../../../../shared/dv/agent/wiki/sop/data-migration/powershell-script-based-migration-best-practices.md#5-the-post-cutover-verification-suite--seven-reports) is the canonical post-cutover reconciliation. **Do not use the TDS SQL endpoint for `COUNT(*)` or `SUM()`** — it's unreliable; use Web API `$count` and FetchXML aggregates instead.

## Master Data Management context

Authority for CRUD against customer / contact / lead / product / location / worker master-data tables — read before designing any master-data write: **[Master Data Management SOP family](../../../../shared/dv/agent/wiki/sop/master-data-management/)**.

Digest only — the Master Data Management SOP family is authoritative; read it before designing any master-data CRUD. The three rules below are the load-bearing ones for this skill's surface:

- **The `MSCRM.SuppressDuplicateDetection` header on PATCH** — [duplicate-detection peer §4.2](../../../../shared/dv/agent/wiki/sop/master-data-management/duplicate-detection-best-practices.md#4-the-web-api-contract--mscrmsuppressduplicatedetection-and-0x80040333) names the HSO Override: **PATCH operations against master-data tables must explicitly send `MSCRM.SuppressDuplicateDetection: false`** because the platform default suppresses dedupe on PATCH. **The skill enforces this automatically** — `Create` / `Update` / `BatchCreate` / `BatchUpsert` / `BatchPatch` send `false` on writes to the duplicate-detection-enabled master tables (`accounts` / `contacts` / `leads`); pass `-SuppressDuplicateDetection` only to deliberately skip detection (bulk migration).
- **The `0x80040333` duplicate-detected error** is HTTP `500` (not `409 Conflict`) — handle as a **terminal** error, never retry on the generic 5xx retry policy. Route to the dead-letter / steward queue.
- **Upsert via alternate key** for any master-data inbound integration — the [external-MDM peer §11](../../../../shared/dv/agent/wiki/sop/master-data-management/external-mdm-integration-best-practices.md#11-alternate-keys-for-external-system-reference) names the composite `hso_externalsystemname_code + hso_externalsystemid_text` pattern + PATCH-against-the-alternate-key-URL as the standard idempotent inbound integration shape.

For bulk duplicate detection: `BulkDetectDuplicates` returns max 5,000 duplicates per job — engagements exceeding that threshold need a commercial bulk-merge tool per the dedupe peer §13.

## Configuration-data and sample-data context

Authority for configuration reference-data CRUD against `ConfigurationData/Datasets/` — read before designing any configuration-data upsert: **[`configuration-data-strategy.md`](../../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md)**.

Authority for sample / seed data CRUD against `SampleData/Datasets/` — read before designing any sample-data load: **[`sample-data-validation-workflow.md`](../../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md)**.

Digest only — the two SOPs above are authoritative; read them before designing. CRUD operations on `ConfigurationData/Datasets/` and `SampleData/Datasets/` follow these SOPs for the 3-phase upsert architecture (Resolve+Validate / Fetch+Classify / Batch Write), the GUID-preservation contract (deterministic GUIDs from Dev), the four classification outcomes (NEW / CHANGED / UNCHANGED / CONFLICT, where same-name / different-GUID CONFLICT fails loudly), and the bulk-write batch sizing (default 100; service-protection envelope per the data-migration umbrella).
</content>
