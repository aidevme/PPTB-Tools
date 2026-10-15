# Rollup & formula columns via the Web API (ADR 0057)

Verified payload shapes for creating **rollup** (SourceType 2) and **Power Fx formula**
(SourceType 3) columns headlessly by POSTing typed attribute metadata with a
`FormulaDefinition` — the surface Microsoft's
[Specialized columns using code](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/specialized-columns)
page declines to support, adopted as an HSO Override by
[ADR 0057](../../../../agent/wiki/decisions/0057-specialized-columns-via-formuladefinition-write.md).
Everything below was live-verified on `a Dev test org` (2026-08-06): API-created columns are
byte-identical to designer-created ones on read-back and compute identical values on live records.

The skill wraps all of this — `AddColumn -ColumnType Rollup|Formula` in
`Invoke-DataverseMetadataOperation.ps1`. This reference exists so the payloads stay inspectable
and so nobody re-derives them.

## 1. Formula column (the easy one)

`FormulaDefinition` is the **raw Power Fx expression** — no wrapper, no YAML document, exactly
what you'd type in the maker portal:

```json
POST EntityDefinitions(LogicalName='hso_serviceagreement')/Attributes
{
  "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
  "SchemaName": "hso_renewalactiondate_date",
  "DisplayName": { "LocalizedLabels": [{ "Label": "Renewal Action Date", "LanguageCode": 1033 }] },
  "RequiredLevel": { "Value": "None" },
  "Format": "DateOnly",
  "DateTimeBehavior": { "Value": "DateOnly" },
  "SourceType": 3,
  "FormulaDefinition": "DateAdd(hso_enddate_date, -hso_renewalnoticeleadtime_num, TimeUnit.Days)"
}
```

Result-type → metadata class (all four live-verified, values computed correctly at read time):

| ResultType | Class | Extras |
|---|---|---|
| String | `StringAttributeMetadata` | `MaxLength` 100, `FormatName` Text |
| Decimal | `DecimalAttributeMetadata` | `Precision` 2 |
| Boolean | `BooleanAttributeMetadata` | standard Yes/No `OptionSet` |
| DateTime | `DateTimeAttributeMetadata` | `Format` + `DateTimeBehavior` DateOnly |

Formula values compute at **read time** — no recalc job, no companions. `SourceTypeMask` reads
back as 1; only bit 32 (Invalid) matters.

## 2. Rollup column

Same POST shape, but `SourceType: 2` and `FormulaDefinition` is a **Windows Workflow XAML**
document. The skill compiles it from a template captured verbatim from a designer-authored
rollup (`hso_coveredassetcount_num`, capture:
`AOSForgeIntegration/agent/work/analysis/readback-hso_coveredassetcount_num.json`); the
generated XAML is **byte-identical** to the designer's for the same inputs. Only these parts
vary:

| Template slot | Example | Notes |
|---|---|---|
| Child table | `hso_assetcoverage` | 3 occurrences (`EntityName=`) |
| Relationship key | `relatedlinked_<relSchemaName>#<lookupColumn>#<childTable>#Temp` | plus the `SetAttributeValue` DisplayName `child.lookup.relationship` |
| Filter (optional) | `statuscode` Equal `100000001` | one `GetEntityProperty` → `CreateCrmType OptionSetValue` → `EvaluateCondition Equal` chain |
| Filter CRM type name | `Status` | 3rd `CreateCrmType` parameter: `statecode` → `State`, `statuscode` → `Status`, custom choice → `Picklist` (State/Status live-verified; Picklist is the expected name, unverified) |
| Aggregate attribute | child PK for Count, else the aggregated column | |
| Aggregate operator | see below | |

**`EvaluateExpression` operator strings are NOT the friendly names** — live-verified set:

| Aggregate | Operator string |
|---|---|
| Count | `Count` |
| Sum | `Sum` |
| Avg | `Average` |
| Max | `Maximum` |
| Min | `Minimum` |

(`Max`/`Min` are **rejected at POST** — the server compiles the workflow at create time, so a
bad operator fails loudly, which is also your safety net for unverified shapes.)

The rollup's **result type mirrors the aggregated column** (Sum over Decimal → Decimal with the
child's Precision; Sum over Money → Money; Count → Integer with full int range, `Format` None).
DateTime child columns support Min/Max only.

## 3. What the platform does after the POST

- **Companions:** `<name>_date` + `<name>_state` are auto-created (with their own short
  propagation delay). `Avg` additionally creates hidden `<name>_count`/`<name>_sum`; Money
  rollups create `<name>_base`. Companions are deleted with the parent — never delete them
  individually.
- **Propagation lag:** a successful POST can 404 on metadata GET **and** DELETE for 10–20 s,
  and the *data* endpoint's EDM model (reads AND writes, independently) lags further. The
  skill's read-back gate retries ~40 s; anything driving records right after a create must
  bounded-retry its first data calls too.
- **Calculation:** the initial *Mass Calculate Rollup Fields* job runs **~12 h after create**
  (then per-column recurring, hourly minimum). For immediate values call
  **`CalculateRollupField` — an UNBOUND function** (this is the WI-342 R2-2 trap: authoring it
  as a bound Dataverse-connector action step fails with `GetMetadataForBoundActionInput`):

```
GET [org]/api/data/v9.2/CalculateRollupField(Target=@p1,FieldName=@p2)
    ?@p1={'@odata.id':'hso_serviceagreements(<guid>)'}&@p2='hso_coveredassetcount_num'
```

- **Read-back gate (mandatory, ADR 0057):** assert `SourceType` (2/3), `SourceTypeMask` bit 32
  (Invalid) clear, `FormulaDefinition` round-trips exactly, and (rollups) companions exist. The
  skill deletes an unverified column and records `[MAKER-PORTAL-TODO]` — no half-builds.

## 4. Limits & exclusions

- ≤ **10 rollup columns per table**, ≤ 100 per org (skill preflights the per-table cap).
- Aggregation over a **1:N** relationship only — no N:N, no ActivityPointer/ActivityParty 1:N,
  no rollup-over-rollup; hierarchy rollups are out of the skill's scope.
- Filter support is a **single Equal condition** on a state/status/choice column (the
  designer-verified shape). Richer filters → maker portal.
- **Editing** an existing specialized column's formula via the API is not blessed by ADR 0057 —
  delete + recreate, or use the maker portal.
- **Classic calculated columns (SourceType 1)** are deprecated and not created — author the
  logic as a formula column.

## 5. Verification record

Live harness (2026-08-06, a Dev test org, 37/37 checks): single + batch creation paths;
Count with statuscode and statecode filters; Sum/Avg/Max/Min over Decimal and Sum over Money;
all four formula result types; generated-XAML byte-equality against the designer capture; value
equivalence against a designer-created rollup **and** against locally computed expectations on
seeded child rows; `CalculateRollupField` immediately after create; clean deletes.
