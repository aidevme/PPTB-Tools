# D365 Word Templates (document generation from a record)

How to author a **Word Template** that generates from a Dataverse record via the command bar (**⋯ → Word Templates**). These are `documenttemplate` rows (`documenttype = 2`, `associatedentitytypecode = <otc>`). Hard-won rules — a hand-built `.docx` that *looks* right still fails generation unless these hold.

## The two non-negotiables

1. **Content controls, not MERGEFIELDs.** D365's engine renders **content controls (`w:sdt`)** data-bound (via the Word XML Mapping Pane) to D365's own per-entity custom XML part. Classic Word `MERGEFIELD` codes (`«field»`) are **ignored entirely**. A docx full of MERGEFIELDs produces a blank/unbound document.
2. **The datastore plumbing must match what D365 emits — exactly.** Even a docx built from D365's own *Download Template* fails generation with a generic **"SQL Server Error" (`0x80044150`)** if the plumbing is off. Two non-obvious requirements:
   - **`itemProps` needs TWO schemaRefs** — the CRM namespace **and** an empty `ds:uri=""` (the entity field nodes live in `xmlns=""`). A single schemaRef → D365 can't resolve the field nodes → bad query → SQL error.
   - Bound controls reference the datastore item's storeItemID and a `prefixMappings` like `xmlns:ns0='urn:microsoft-crm/document-template/<entity>/<otc>/' ` **including the trailing space** (match the emit byte-for-byte).

## Fields that can't be bound (drop them)

- **Polymorphic `customeridname`** triggers the `0x80044150` SQL error — the OOB templates deliberately avoid it, using `accountidname` / `contactidname` instead. For a fixed demo record whose customer is set via the polymorphic `customerid` (so `accountid` is empty), **hard-code the customer name** in the template body and note it's not reusable as-is.
- Custom optionsets and frequently-null fields (e.g. a `resolveby` that's null) can also misbehave — prefer fields proven safe by an OOB template.

## The reliable build pattern (do this)

Don't hand-assemble the plumbing. **Base your template on an OOB known-good (generation-tested) template and swap only the body:**

1. Pull an OOB template's bytes via Web API: `GET documenttemplates(<id>)?$select=content` → base64-decode to a `.docx` (e.g. the "Case Summary" template for `incident`).
2. Replace **only `word/document.xml`** with your layout + content controls (bound to the same datastore item / `prefixMappings` the base uses). You inherit the correct dual-schemaRef `itemProps`, the two `customXml` parts, styles and rels.
3. Repackage as valid OOXML (ordered entries, forward-slash names, `[Content_Types].xml` first).
4. Upload as a new `documenttemplate`; **generate-test on a real record** and confirm the merge before declaring done.

## Notes

- Static narrative placeholders are fine for sections with no dedicated field ("shape over field-level completeness").
- The generated file downloads from the command bar; no flow needed.

| Date | Author | Description |
|------|--------|-------------|
| 2026-06-11 | David Reinsvold / Meghan Reed | Initial — distilled from the Marmon 8D (Case) Word-template build: content-controls-not-MERGEFIELDs, the `0x80044150` dual-schemaRef root cause, `customeridname` unusable, and the OOB-base-template + swap-`document.xml` pattern. |
