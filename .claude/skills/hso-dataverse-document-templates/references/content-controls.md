# Authoring Content Controls (Word) & Named Ranges (Excel)

How to wire a value in the body to a Dataverse field. Format must match D365's own emit **exactly** — copy it from your OOB base when in doubt.

## Word — the customXml schema

A downloaded/OOB Word template contains `customXml/itemN.xml`:

```xml
<DocumentTemplate xmlns="urn:microsoft-crm/document-template/<entity>/<otc>/">
  <<entity> xmlns="">
    <ticketnumber>ticketnumber</ticketnumber>
    <createdon>createdon</createdon>
    ...
  </<entity>>
</DocumentTemplate>
```

- Root `DocumentTemplate` is in the CRM namespace; `<entity>` and every field node are in the **empty namespace** (`xmlns=""`). This is why the datastore item needs both schemaRefs (see gotchas doc).
- `<otc>` is the entity's object type code (Case/`incident` = 112).

## Word — a bound content control (inline)

```xml
<w:sdt>
  <w:sdtPr>
    <w:rPr><w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI"/><w:sz w:val="20"/></w:rPr>
    <w:alias w:val="Case Number"/>
    <w:tag w:val="ticketnumber"/>
    <w:id w:val="101"/>
    <w:dataBinding
       w:prefixMappings="xmlns:ns0='urn:microsoft-crm/document-template/<entity>/<otc>/' "
       w:xpath="/ns0:DocumentTemplate[1]/<entity>[1]/ticketnumber[1]"
       w:storeItemID="{DATASTORE-ITEM-GUID}"/>
    <w:text/>
  </w:sdtPr>
  <w:sdtContent>
    <w:r><w:rPr><w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI"/><w:sz w:val="20"/></w:rPr><w:t>ticketnumber</w:t></w:r>
  </w:sdtContent>
</w:sdt>
```

Format rules that must match D365 exactly:
- **`prefixMappings`** declares `ns0` = the CRM namespace and ends with a **trailing space** before the closing quote.
- **`w:xpath`** prefixes only `DocumentTemplate` with `ns0:`; `<entity>` and the field are **unprefixed** (empty namespace). Always `/ns0:DocumentTemplate[1]/<entity>[1]/<field>[1]`.
- **`w:storeItemID`** = the `ds:itemID` of the datastore item in `customXml/itemPropsN.xml`. When you clone an OOB base, reuse **its** GUID for every binding.
- Multi-line memo fields: use `<w:text w:multiLine="1"/>`.
- The `sdtContent` run holds placeholder text (the field name); D365 replaces it at generation.

A field is referenced by the **last xpath segment** (the logical name). Repeated bindings of the same field are fine.

## Static values

When a value is unmappable (polymorphic customer, optionset) or intentionally fixed, drop the `w:sdt` and use a plain run:

```xml
<w:r><w:rPr><w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI"/><w:sz w:val="20"/></w:rPr><w:t>Some fixed text</w:t></w:r>
```

Escape XML entities (`&amp;`, `&lt;`, `&gt;`). Static values make the template record-specific — see the Limitations section of the gotchas doc.

## Excel

Excel templates use the same `documenttemplate` entity and upload path, but bind via **named ranges / table columns** mapped to the entity schema rather than `w:sdt` content controls. The schema part, dual-schemaRef datastore requirement, and unmappable-field caveats are the same. Build on an OOB Excel base for the entity and edit the sheet XML; generate-test identically.

## Quick reference — finding proven-safe fields

From a working OOB template's `word/document.xml`:

```bash
grep -oE '<entity>\[1\]/([a-z0-9_]+)\[1\]' word/document.xml | sort -u
```

Every field listed is generation-proven for that entity. Build your first version from this set, then add others one at a time with a generate-test.
