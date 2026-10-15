# Document Templates — Gotchas, Root Cause & Limitations

Hard-won knowledge for native D365 document templates. The symptoms below are non-obvious and cost hours if rediscovered from scratch.

## The core failure: `SQL Server error 0x80044150` on generation

**Symptom.** The template **uploads successfully** (a `documenttemplate` row is created — the upload only validates the customXml *schema* matches the entity). Then, when you generate it on a record, D365 throws a modal:

> **SQL Server Error** — A SQL Server error occurred. {1}{0}
> Error code: 0x80044150

The `{1}{0}` placeholders are unfilled — the message is generic. The real meaning: **D365 built an invalid SQL/query from the template's field bindings.** Two independent causes, both seen in practice:

### Cause A — datastore plumbing (structural)

D365 generation reads the content controls, resolves each `dataBinding` xpath against the template's **customXml datastore item**, and builds a query for those fields. If the datastore item is wired wrong, field resolution fails → bad query → SQL error. The non-obvious requirement:

- **`customXml/itemPropsN.xml` must declare TWO schemaRefs**, not one:
  ```xml
  <ds:datastoreItem ds:itemID="{GUID}" xmlns:ds="...customXml">
    <ds:schemaRefs>
      <ds:schemaRef ds:uri="urn:microsoft-crm/document-template/<entity>/<otc>/"/>
      <ds:schemaRef ds:uri=""/>   <!-- REQUIRED: the entity/field nodes live in the empty namespace -->
    </ds:schemaRefs>
  </ds:datastoreItem>
  ```
  The customXml looks like `<DocumentTemplate xmlns="urn:microsoft-crm/...">` → `<<entity> xmlns="">` → fields. The `<<entity>>` and field nodes are in the **empty namespace**, so the datastore item must reference both `urn:...` **and** `""`. A hand-built single-schemaRef `itemProps` uploads fine but **fails generation**.
- The `dataBinding` `prefixMappings` has a **trailing space** in D365's own output: `xmlns:ns0='urn:microsoft-crm/document-template/<entity>/<otc>/' ` — match it exactly.
- `storeItemID` must equal the datastore item's `itemID`.

**Reliable mitigation:** do not author plumbing by hand. **Clone an OOB template** (one D365 made and can already generate) and replace only the body — you inherit correct `itemProps`, customXml, and rels for free.

### Cause B — unmappable fields

Even with perfect plumbing, **specific fields cannot be bound** and will trigger `0x80044150`:

| Field type | Example | Why it fails / what to do |
|---|---|---|
| **Polymorphic lookup name** | `customeridname` (Customer = account *or* contact) | D365 can't build a clean join for the polymorphic name. OOB templates deliberately avoid it — use the **type-specific** `accountidname` / `contactidname`, or static text. |
| **Custom optionset** | `<prefix>_reason_code` | Optionset rendering can fail in generation. Prefer static text, or test individually. |
| **Fields a known-good template never binds** | (entity-specific) | Treat as unproven until a generate-test passes. |

**How to tell which fields are safe:** pull a working OOB template for the entity, list the fields it binds (`grep` the `incident[1]/<field>[1]` xpaths in its `document.xml`). Those are **proven safe**. Anything outside that set is unproven — bind it only if a generate-test passes.

## The upload paradox

A template can be in any of three states:

1. **Rejected on upload** — "file is not consistent with the template layout." The customXml schema doesn't match the entity (wrong entity, corrupted/absent schema part).
2. **Uploads OK, fails generation** — `0x80044150`. Schema is fine; plumbing or a field is bad. **This is the trap** — the grid shows a happy new row.
3. **Uploads OK, generates OK** — the only state that matters.

**Therefore: a successful upload proves nothing.** Always reach state 3 with a generate-test.

## LIMITATION — generation safety is empirical, not static

You **cannot** determine from entity metadata alone whether a template will generate. The mappability of a field, and the correctness of plumbing, are only confirmed by **generating on a real record**. Consequences:

- Treat template building as **build → upload → generate-test → (bisect on failure)**. Never declare a template done on upload alone.
- When introducing a field outside the proven-safe set, **add it and re-test**; if it breaks, it is the new field.
- Because some values must be **static** (polymorphic customer, certain optionsets), a template carrying static values is **record-/case-specific** and not safely reusable across records until those values are replaced with mappable, type-specific fields.

## Diagnostic recipe (deterministic)

1. **Is it the record or the template?** Generate a stock OOB template on the *same record*. OOB fails too → record/environment issue. OOB works → your template.
2. **Eliminate plumbing.** Rebuild on the OOB base (clone, swap body only). Still fails → it's a field.
3. **Bisect fields.** Remove fields not in the OOB-proven set; re-test. Re-add one at a time to find the offender.
4. Keep the customXml schema part **byte-identical** to the base throughout.

## Packaging notes (OOXML)

- Repackage with **forward-slash** entry names and `[Content_Types].xml` first.
- If you add an `itemProps` part, register it in `[Content_Types].xml` (`Override … customXmlProperties+xml`) and link it from `customXml/_rels/itemN.xml.rels`.
- PowerShell `Copy-Item` treats `[Content_Types].xml` brackets as **wildcards** — use `-LiteralPath`.
- Validate well-formedness of every changed part before zipping.
