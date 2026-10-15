---
name: hso-dataverse-document-templates
layer: atomic
scope: core
description: Author and deploy native Dataverse/D365 document templates (the `documenttemplate` entity) — Word and Excel — that generate populated documents from a record. Use for "create a Word template", "8D/case report template", "Excel template", or when a hand-built template fails generation with a "SQL Server error". Not for ISV Liquid-template document generation or Power Automate document generation.
---

# Dataverse Document Templates (Word & Excel)

Build and deploy **native D365 document templates** — the out-of-the-box **Word Templates** / **Excel Templates** feature backed by the `documenttemplate` entity. These generate a populated `.docx`/`.xlsx` from a single record via the record command bar (**⋯ → Word Templates / Excel Templates**).

> The hard part is not authoring the layout — it is the **datastore plumbing**. A correctly-formatted, hand-built template can *upload* successfully and still **fail generation** with a generic `SQL Server error (0x80044150)`. This skill encodes the technique that avoids that. **Read [references/gotchas-and-limitations.md](references/gotchas-and-limitations.md) before building.**

## When to use this skill

- "Create / build a Word template" or "Excel template" for a Dataverse entity
- "Generate an 8D report / case summary / inspection form / quote doc from a record"
- A `.docx`/`.xlsx` must merge record field values via the OOB **Word/Excel Templates** command
- An existing template fails to generate with **"A SQL Server error occurred. {1}{0}"** / `0x80044150`
- Renaming, deleting, or auditing `documenttemplate` records

## When NOT to use this skill

- **ISV Liquid-`.docx` templating engines** — a different engine entirely; out of scope for this skill.
- **Power Automate / Word Online connector** document generation, SSRS reports, or mail merge.
- Editing a regular `.docx` for human use (no Dataverse binding).

## Configuration

Read from `CLAUDE.md`: **Environment URL** · **MCP Server / Web API base** · **Default Solution**
Read from `CLAUDE.local.md`: **Author Name** · **Playwright CLI path** (only if driving the UI)

Web API calls (OOB-template retrieval, rename/delete) go through `hso-dataverse-data`. Packaging is local PowerShell — no auth needed.

## Key facts

- One `documenttemplate` row per template. `documenttype`: **2 = Word, 1 = Excel**. `associatedentitytypecode` pins it to one entity (e.g. `incident` = Case, OTC 112).
- D365 binds fields through **content controls** (Word `w:sdt`) / **named ranges** (Excel) wired to a **customXml part** whose root namespace is `urn:microsoft-crm/document-template/<entity>/<otc>/`. The entity/field nodes live in the **empty namespace** (`xmlns=""`).
- D365 **ignores classic Word MERGEFIELD** mail-merge codes. A MERGEFIELD `.docx` is not a valid template.
- The customXml schema part is generated **server-side**; a hand-built `.docx` without it is rejected on upload ("file is not consistent with the template layout").

## Workflow

### 1. Get a known-good base (do NOT hand-build the plumbing)

The robust path — **start from a template D365 itself produced and has proven it can generate**, then change only the body:

- **Preferred — clone an OOB template's plumbing.** Pull an existing, generation-tested OOB template for the same entity (e.g. "Case Summary" for `incident`) via Web API and base64-decode it:
  ```
  GET [Environment URL]/api/data/v9.2/documenttemplates(<id>)?$select=content
  ```
  (Find `<id>`: filter `documenttemplates?$select=name,documenttype&$filter=associatedentitytypecode eq '<entity>'`.) This base already carries correct `itemProps` (dual schemaRefs), the customXml schema, styles, and rels.
- **Alternative — download a blank template** from D365: **Settings → Advanced Settings → Templates → Document Templates → New → <Word/Excel> Template → <entity> → Download Template**, *or* the record command bar **⋯ → Word/Excel Templates → Create**. This carries the schema but **no `itemProps`** — you must add the **dual-schemaRef** datastore item yourself (see references). Riskier; prefer the OOB clone.

### 2. Choose only mappable fields

Bind only fields a **known-good OOB template already binds** for this entity (proven safe). Avoid the traps in [references/gotchas-and-limitations.md](references/gotchas-and-limitations.md): **polymorphic lookup name fields** (e.g. `customeridname`), custom **optionsets**, and other fields can cause the SQL error. When a needed value is unmappable, use **static text** or a type-specific lookup name (`accountidname`/`contactidname`).

### 3. Author the body

Replace only `word/document.xml` (Word) or the sheet XML (Excel) with your layout. For each bound value insert a content control whose `dataBinding` matches D365's emit **exactly** (xpath, prefixMappings with **trailing space**, and `storeItemID` = the base's datastore-item GUID). Full format in [references/content-controls.md](references/content-controls.md).

### 4. Package

Repackage as valid OOXML (ordered entries, forward-slash names, `[Content_Types].xml` first). Use the helper:

```powershell
powershell -File scripts/Build-DocumentTemplate.ps1 `
  -BaseTemplate "<path to OOB base .docx>" `
  -BodyXml "<path to your document.xml>" `
  -OutFile "<path to output .docx>"
```

### 5. Upload

Document Templates grid (**Upload Template → Upload Word/Excel Template → choose file → Upload**). Row count increments; no error = schema accepted. (UI automation via `playwright-cli`: the file input sits in an iframe — use `setInputFiles` on `input[type=file]`.)

### 6. Generate-test on a real record — REQUIRED

Open a real record → **⋯ → Word/Excel Templates → <your template>** → confirm it **downloads a populated document** with no error. **This step is mandatory** — uploading proves nothing about generation (see Limitations).

### 7. (Optional) Rename / clean up

Via `hso-dataverse-data` Web API: `PATCH documenttemplates(<id>)` `{ "name": "<display name>" }`; `DELETE documenttemplates(<id>)` to remove failed attempts.

## Diagnosing a generation failure (`SQL Server error 0x80044150`)

The error is generic and unfilled (`{1}{0}`). It means D365 built a bad query from the template's bindings. Procedure:

1. Confirm the **environment/record** are fine — generate a stock OOB template (e.g. "Case Summary") on the *same record*. If that also errors, it is the record, not your template.
2. If OOB works but yours fails, it is **your template** — a structural plumbing gap or an unmappable field.
3. **Bisect**: compare your bound fields to the set the working OOB template binds. Drop any field the OOB template does not use; re-test. Rebuild on the OOB base (Step 1) to eliminate plumbing as a variable.

Details and the full root-cause analysis: [references/gotchas-and-limitations.md](references/gotchas-and-limitations.md).

## Limitations

- **Generation safety is empirical, not static.** You **cannot** know a field is mappable from metadata alone — it must pass a **generate-test** (Step 6). This skill is "build + verify," never "build blind." Always generate-test before declaring done.
- **Hand-built datastore plumbing is fragile.** A single-schemaRef `itemProps`, a missing empty-namespace schemaRef, or a malformed `dataBinding` produces `0x80044150` even though the upload succeeds. Cloning an OOB base is the reliable mitigation.
- **Some values can only be shown as static text** (polymorphic customer name, certain optionsets). Static values make the template **record-specific** — acceptable for a fixed demo case, not for a reusable template. Generalize later by binding a type-specific field (e.g. `accountidname`) once the customer type is known.
- **Excel** uses the same `documenttemplate` entity and upload path but maps via named ranges, not content controls; the plumbing/field caveats still apply.

## Critical rules

**DO**
- Build on an **OOB known-good template's plumbing**; change only the body.
- Bind only fields a working OOB template already binds for the entity.
- **Generate-test on a real record** before finalizing.
- Keep the customXml schema part **byte-identical** to the base.

**DO NOT**
- Hand-build the `itemProps`/customXml plumbing when an OOB base exists.
- Use Word **MERGEFIELD** codes — D365 ignores them.
- Bind polymorphic lookup name fields (`customeridname`) or assume custom optionsets are safe.
- Treat a successful **upload** as proof the template works — only generation proves it.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
