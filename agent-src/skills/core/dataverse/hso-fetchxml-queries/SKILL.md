---
name: hso-fetchxml-queries
layer: atomic
scope: core
description: |
  Write, review, and optimize FetchXML queries for Dataverse. Use when:
  (1) User asks to write a FetchXML query, retrieve records, or filter data
  (2) User needs joins across related tables (linked-entity patterns)
  (3) User needs aggregation, grouping, counting, or distinct queries
  (4) User needs pagination (paging cookie) for large result sets
  (5) User asks to use FetchXML via Web API fetchXml parameter or $filter
  (6) User asks about FetchXML vs. QueryExpression — when to use which
  (7) User needs to optimize a slow query or understand performance rules
  Does NOT cover QueryExpression syntax — see hso-plugin-development/references/query-patterns.md.
  Does NOT cover report authoring (SSRS/Power BI) — FetchXML syntax only.
---

# FetchXML Queries

FetchXML is Dataverse's XML-based query language. It is used in plugins (via `FetchExpression`),
Web API calls (`?fetchXml=`), Advanced Find exports, reports, and Canvas App connectors.

## Task → primary authority

When the FetchXML is destined for a UI surface, the relevant SOP is the primary authority for that task — read it before designing the query, then apply the raw-query rules in this skill.

| Task type | Primary authority |
|-----------|-------------------|
| FetchXML driving a model-driven app view (Public, Subgrid, Lookup, Quick Find, Advanced Find) | [`shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md) |
| FetchXML driving a dashboard chart or list (system or personal) | [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md) (layered on top of the view-configuration SOP) |
| Raw FetchXML (plugins, Web API, reports, Canvas App connectors) with no view/dashboard surface | This skill |
| **Whether a given FetchXML construct is structurally legal at all** | [`customizations-xml-schema.md`](../../../agent/wiki/reference/customizations-xml-schema.md) — `Fetch.xsd` is the grammar. Validate against it when hand-authoring, or when a query is rejected and the message names a line rather than a cause |

## When the FetchXML drives a model-driven view

**Authority for FetchXML that drives a model-driven app view (Public, Subgrid, Lookup, Quick Find, Advanced Find) — read [`shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md) before designing or optimizing the view query.**

When the FetchXML you are writing or reviewing is the *query for a model-driven app view* (Public, Subgrid, Lookup, Quick Find, Advanced Find), additional rules apply that go beyond raw query correctness — column count targets, sort discipline, the Quick Find 10K-record cap, anti-patterns Microsoft actively throttles, indexing levers (alternate keys, Dataverse search), and `latematerialize` / `union` hint guidance. Read [`shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md), particularly Section 4 (FetchXML query performance fundamentals — operator efficiency, joins, distinct, paging, hints), Section 5 (indexing — auto-indexed columns, alternate keys, Dataverse search), Section 6 (Quick Find — 10K cap evaluated before security trim, find-column rules), and Section 7 (filter and sort anti-patterns with their Microsoft error codes — `LeadingWildcardCauseTimeout`, `ComputedColumnCauseTimeout`, `OrderOnEnumAttribute`, `OrderOnPropertiesFromJoinedTables`, `LargeAmountOfAttributes`).

## When the FetchXML drives a dashboard chart or list

**Authority for FetchXML that drives a dashboard chart or list (system or personal) — read [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md) before designing the chart/list query (layered on top of the view-configuration SOP).**

When the FetchXML you are writing or reviewing is the *query for a chart or list embedded on a dashboard* (system or personal), additional dashboard-specific rules apply on top of the view-side rules above. Read [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md), particularly Section 5 (charts on dashboards — system-vs-personal ownership rule, the 50K `AggregateQueryRecordLimit` hard cap before aggregation, mandatory time-window filter on every chart, accessibility via hatch + colour, currency labels in M/K), Section 6 (lists on dashboards — the outer-join trap that silently breaks the dashboard designer per [crmtipoftheday #499](https://crmtipoftheday.com/499/outer-joins-and-dashboards/), Power Apps grid control mandatory not Power Apps Read-Only grid, the design-time blindness in the dashboard designer that makes test-in-role mandatory), and Section 18 (performance — ≤ 10K row pre-aggregation HSO target, FastTrack Query Throttling Dashboard for chart/list throttle hits, SQL 4 CDS for execution plans). When a dashboard chart's FetchXML genuinely needs > 30K rows pre-aggregation or cross-source data, graduate it to Power BI per Section 8 (Mark Carrington's [Use FetchXML in Power BI](https://crmchartguy.wordpress.com/2017/09/30/use-fetchxml-in-power-bi-with-dynamics-365-customer-engagement/) preserves the FetchXML investment).

## Core Syntax

### Basic Attribute Query

```xml
<fetch top="50">
  <entity name="hso_project">
    <attribute name="hso_projectname_text" />
    <attribute name="hso_status_code" />
    <attribute name="hso_startdate_date" />
    <filter>
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
    <order attribute="hso_projectname_text" descending="false" />
  </entity>
</fetch>
```

**Rules:**
- Always list specific `<attribute>` elements — NEVER omit all attributes (returns all columns, degrades performance)
- Always include `statecode = 0` filter unless inactive records are intentional
- Use `top` for small bounded result sets; use paging cookie for open-ended sets

---

## Linked Entity (Join) Patterns

### Inner Join (default)

```xml
<fetch>
  <entity name="hso_project">
    <attribute name="hso_projectname_text" />
    <link-entity name="account" from="accountid" to="hso_account_id"
                 link-type="inner" alias="acct">
      <attribute name="name" />
      <attribute name="hso_region_code" />
    </link-entity>
  </entity>
</fetch>
```

### Outer Join (include records with no match)

```xml
<link-entity name="hso_task" from="hso_project_id" to="hso_projectid"
             link-type="outer" alias="task">
  <attribute name="hso_taskname_text" />
</link-entity>
```

### Filter on Linked Entity

```xml
<link-entity name="account" from="accountid" to="hso_account_id"
             link-type="inner" alias="acct">
  <filter>
    <condition attribute="statecode" operator="eq" value="0" />
  </filter>
</link-entity>
```

### Nested Join (multi-hop)

```xml
<link-entity name="account" from="accountid" to="hso_account_id"
             link-type="inner" alias="acct">
  <attribute name="name" />
  <link-entity name="hso_region" from="hso_regionid" to="hso_region_id"
               link-type="inner" alias="region">
    <attribute name="hso_regionname_text" />
  </link-entity>
</link-entity>
```

---

## Aggregation

```xml
<fetch aggregate="true">
  <entity name="hso_project">
    <attribute name="hso_status_code" groupby="true" alias="status" />
    <attribute name="hso_projectid" aggregate="count" alias="projectcount" />
    <attribute name="hso_estimatedcost_amt" aggregate="sum" alias="totalcost" />
    <attribute name="hso_estimatedcost_amt" aggregate="avg" alias="avgcost" />
  </entity>
</fetch>
```

**Supported aggregate functions:** `count`, `countcolumn`, `sum`, `avg`, `min`, `max`

- `count` counts **rows**; `countcolumn` counts **non-null values** of a column — use `countcolumn` on a
  field to measure how often it is populated, and on the primary-id to get a true record count.

**Counting records — do NOT use Web API `/$count`:** the OData `entityset/$count` endpoint **caps at 5000**
(and returns a BOM that breaks `[int]` parsing). For an accurate total use a `countcolumn` aggregate on the
primary id instead.

**`AggregateQueryRecordLimit` = 50,000:** an aggregate over a set larger than 50k rows fails. When a table
exceeds it, **window the set** (e.g. `createdon` in the last N years) so the aggregate runs, and state the
window in the output. Example — % of records where a field is populated, windowed:
```xml
<fetch aggregate="true">
  <entity name="opportunity">
    <attribute name="hso_myfield" aggregate="countcolumn" alias="c" />
    <filter><condition attribute="createdon" operator="ge" value="2023-06-18" /></filter>
  </entity>
</fetch>
```

**Distinct:** Add `distinct="true"` to `<fetch>` to deduplicate non-aggregate results.

**Reading aggregate results in C#:**
```csharp
var count = (int)result.GetAttributeValue<AliasedValue>("projectcount").Value;
```

---

## Pagination

### Top (bounded, simple)

```xml
<fetch top="100">
```

Use only when the total result set is known to be small. Do NOT use `top` for user-facing
lists that could grow beyond the limit.

### Paging Cookie (open-ended, correct approach)

```xml
<!-- First page -->
<fetch page="1" count="50">
  <entity name="hso_project">
    <attribute name="hso_projectname_text" />
    <order attribute="hso_projectname_text" />
  </entity>
</fetch>
```

```csharp
// C# — iterate all pages
string pagingCookie = null;
int page = 1;
bool moreRecords = true;

while (moreRecords)
{
    var fetchXml = BuildFetchXml(page, pagingCookie); // inject cookie + page
    var result = service.RetrieveMultiple(new FetchExpression(fetchXml));

    // process result.Entities

    moreRecords = result.MoreRecords;
    pagingCookie = result.PagingCookie;
    page++;
}
```

**Rules:**
- Always include an `<order>` element when paginating — results are non-deterministic without it
- Encode the paging cookie (XML-encode `<` and `>` before injecting into FetchXML string)

---

## Performance Rules

| Rule | Why |
|------|-----|
| Always specify `<attribute>` elements | Retrieving all columns is expensive — list only what you need |
| Filter server-side in `<filter>` | Never retrieve all records and filter in C# |
| Use indexed fields in filter conditions | `statecode`, `statuscode`, lookup fields, and alternate keys are indexed |
| Avoid `like` with leading wildcard (`%value`) | Cannot use index — full table scan |
| Avoid `<condition>` on memo/multi-line text | Not indexed, very slow on large tables |
| Set `no-lock="true"` on read-only queries | Reduces lock contention; do NOT use on queries preceding a write |
| Use `top` only for small bounded sets | For open-ended lists, always use paging cookie |

---

## Common Filter Conditions

```xml
<!-- Equals -->
<condition attribute="hso_status_code" operator="eq" value="100000000" />

<!-- Not null -->
<condition attribute="hso_account_id" operator="not-null" />

<!-- In list -->
<condition attribute="hso_status_code" operator="in">
  <value>100000000</value>
  <value>100000001</value>
</condition>

<!-- Date range -->
<condition attribute="hso_startdate_date" operator="on-or-after" value="2026-01-01" />
<condition attribute="hso_startdate_date" operator="on-or-before" value="2026-12-31" />

<!-- Current user -->
<condition attribute="ownerid" operator="eq-userid" />

<!-- Last N days -->
<condition attribute="createdon" operator="last-x-days" value="30" />
```

---

## FetchXML vs. QueryExpression

| Use FetchXML when | Use QueryExpression when |
|-------------------|--------------------------|
| Working in Web API, reports, Advanced Find | Writing plugin code that stays server-side |
| Aggregation or distinct queries | Simple retrieve with specific columns |
| Exporting/importing query definitions | Dynamic column selection at runtime |
| Linked entity with complex filter | Performance-critical inner loop query |

For QueryExpression ordering/DateTime edge case patterns, see
[../hso-plugin-development/references/query-patterns.md](../hso-plugin-development/references/query-patterns.md).

---

## Web API Usage

### Execute via fetchXml parameter

```
GET [org]/api/data/v9.2/hso_projects?fetchXml=<encoded-fetch-xml>
```

The FetchXML must be URL-encoded. Example (PowerShell):

```powershell
$fetch = '<fetch top="10"><entity name="hso_project"><attribute name="hso_projectname_text" /></entity></fetch>'
$encoded = [System.Web.HttpUtility]::UrlEncode($fetch)
$url = "$EnvironmentUrl/api/data/v9.2/hso_projects?fetchXml=$encoded"
```

### Prefer $filter for simple queries in Web API

Use `?$filter=` and `?$select=` for single-entity queries without joins or aggregation — they
are easier to construct and equally performant. Reserve `fetchXml=` for joins, aggregation,
and paging cookie scenarios.

For detailed Web API OData patterns, see `hso-dataverse-sdk-reference`.

---

## Critical Rules

- **NEVER** omit all `<attribute>` elements — always project specific columns
- **NEVER** filter in C# after retrieving all records
- **NEVER** use `top` for open-ended lists — use paging cookie
- **ALWAYS** include `<order>` when paginating
- **ALWAYS** filter `statecode = 0` unless inactive records are required
- **ALWAYS** XML-encode the paging cookie before injecting it into the FetchXML string

---

## Reference

For extended examples covering FetchXML in reports, Canvas Apps, and Power Automate:
see [references/extended-examples.md](references/extended-examples.md).

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
