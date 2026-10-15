---
name: hso-power-pages-authoring
layer: atomic
scope: core
description: Author and update Power Pages design-studio site content on both the standard and enhanced data models — web pages, page templates, web templates (Liquid), content snippets, web files, web link sets, and site settings — via the pac pages download→edit→upload round-trip. Use to create a Power Pages page, add or update a web template / content snippet / web file, or implement a portal page spec. Detects the data model and passes the matching modelVersion. Forms, lists, code sites, CI/CD pipelines, and portal security are out of scope.
---

# Power Pages Authoring (Design Studio)

Author and update **design-studio** Power Pages site content — the low-code Liquid + Bootstrap surface — through the supported **`pac pages` round-trip**: download the site to source files, make surgical edits, upload the deltas back. Supports **both the standard and enhanced data models** — the skill detects the model and passes the matching `--modelVersion`.

This skill is the **executor** of the HSO Power Pages design-studio methodology. It does not redefine that methodology — it carries it out. Read the SOPs below before authoring anything.

## When to use this skill

- "Create a Power Pages page" / "add a page to the portal"
- "Add a web template" / "update the Liquid in a web template"
- "Update a content snippet / site setting / navigation menu"
- "Add a CSS or JS web file to the site"
- Implementing a portal **page** slice from a spec routed by `hso-dataverse-architect`

## When NOT to use this skill

| Need | Use instead |
|------|-------------|
| Basic forms, multistep forms, lists (data-bound components) | **v2 of this skill** — deferred (see [Roadmap](#roadmap)); for now configure in the design studio |
| Code sites / SPAs (React, Vue, Angular, Astro) | `microsoft/power-platform-skills` plugin (code-sites only) |
| Export / build / deploy pipelines (CI/CD YAML) | [`hso-dataverse-pipelines`](../hso-dataverse-pipelines/SKILL.md) (`references/power-pages-pipelines.md`) |
| Web roles, table permissions, column permissions | [`hso-dataverse-securityrole`](../hso-dataverse-securityrole/SKILL.md) + the security SOP |
| Dataverse tables the portal exposes | [`hso-dataverse-data-modeling`](../hso-dataverse-data-modeling/SKILL.md) |
| The visual WYSIWYG canvas | Not automatable — that is hands-on-keyboard design studio work |

## Authoritative SOPs — mandatory pre-read

This skill executes the methodology in these SOPs. **Read the relevant ones before authoring.** When this skill's quick reference and a SOP differ, the SOP wins.

| Before you… | Read |
|---|---|
| Author any design-studio component | [`power-pages-design-studio-best-practices.md`](../../../agent/wiki/sop/power-pages/power-pages-design-studio-best-practices.md) — always-Enhanced data model, Liquid + FetchXML rules (server-render preferred for reads), Bootstrap 5, multi-language, design-studio anti-patterns and pre-merge checklist |
| Decide design-studio vs code-site at all | [`power-pages-best-practices.md`](../../../agent/wiki/sop/power-pages/power-pages-best-practices.md) — site-type decision matrix |
| Build any page that surfaces data | [`power-pages-security-best-practices.md`](../../../agent/wiki/sop/power-pages/power-pages-security-best-practices.md) — web roles + table/column/page permissions; the AppOmni breach pattern; the `AttributePermissionIsMissing` lookup trap. **Load-bearing.** |
| Upload, or reason about why a change isn't showing | [`power-pages-alm-best-practices.md`](../../../agent/wiki/sop/power-pages/power-pages-alm-best-practices.md) — the four caching layers + the `today` cache-buster, environment variables for site settings, source-control hygiene |

Topic anchors: [`power-pages-design-studio`](../../../agent/wiki/topics/power-pages-design-studio.md) · [`power-pages`](../../../agent/wiki/topics/power-pages.md).

## Configuration

Read from `CLAUDE.md`: **Environment URL**
Read from `CLAUDE.local.md`: **PAC CLI path**
Ask the user if missing: **Website ID** (GUID of the target site). Never guess it.

## Prerequisites

1. **PAC CLI** installed (path in `CLAUDE.local.md`). Power Pages support is GA since PAC 1.9.8; `pac pages` is the current command group (older docs use the `pac powerpages` / `pac paportal` aliases — all still work).
2. **Authenticated**: `pac auth create --environment <Environment URL>`. The `pac pages` commands use the PAC auth profile — **not** the MSAL token cache the Web API skills use. (The read-only `ListSites`/`DetectModel` operations here can use either.)
3. **Know the target site's data model.** The skill supports **both** standard and enhanced; it detects the model (`pac pages list -v`) and passes the matching `--modelVersion` (1 = standard, 2 = enhanced) automatically. If detection can't determine the model, it stops and asks you to supply `-ModelVersion` rather than relying on the CLI default of `1`.

## Workflow

1. **Read the SOPs** for the components you're about to touch (table above).
2. **Resolve the site and its data model.** Run `ListSites` to get the Website ID, then `DetectModel`. The reported model (standard or enhanced) drives the `--modelVersion` used by every later op — `Download`/`Upload` auto-detect it from the Website ID, or you can pass `-ModelVersion` to override.
3. **Download the site** to a working folder (`Download`). This is the source of truth for the edit. Gitignore the per-environment manifest; commit the delete-tracking `manifest.yml`.
4. **Author or update component files in the downloaded folder.**
   - **Learn the layout from real files first.** The downloaded folder is ground truth for *this* site's enhanced-model layout (YAML metadata + HTML/CSS/JS/Liquid content files). **To create a new page, mirror the file set of an existing web page** (every site has at least the Home page) — copy its `.yml` + content files, then change the name, partial URL, parent page, page template, and copy. **Do not fabricate YAML field names** — derive them from the files already on disk.
   - See [`references/component-cheatsheet.md`](references/component-cheatsheet.md) for the component relationships (web page → page template → web template), the `powerpagecomponenttype` map, and what to change per component.
   - Honor the design-studio SOP: Liquid for reads over Web API, Bootstrap 5, no DOM-created scripts (CSP).
5. **Upload** the changes (`Upload`, with the **matching `--modelVersion`** — auto-detected from the Website ID, or pass `-ModelVersion`). Same-environment uploads are delta; cross-environment is a full upload. Use `-ForceUploadAll` only for drift recovery.
6. **Verify.** Browse the page. If a change isn't visible, it's almost always **caching** — apply the `today` cache-buster pattern from the ALM SOP, not a re-upload loop.
7. **Hand off promotion** to `hso-dataverse-pipelines` (export/build/deploy). This skill authors against a dev environment; it is not the ALM path to QA/Prod.

## Operations Reference

All operations run through `scripts/Invoke-PowerPagesAuthoring.ps1`.

```powershell
# List sites in the environment (Website IDs + data model)
.\Invoke-PowerPagesAuthoring.ps1 -Operation ListSites -EnvironmentUrl "<env-url>"

# Report the site's data model (standard or enhanced)
.\Invoke-PowerPagesAuthoring.ps1 -Operation DetectModel -WebsiteId "<guid>"

# Download the site to a working folder (modelVersion auto-detected from the Website ID)
.\Invoke-PowerPagesAuthoring.ps1 -Operation Download -WebsiteId "<guid>" -Path ".\PowerPages\<SiteName>"

# Upload edits back (modelVersion auto-detected; or pass -ModelVersion 1|2)
.\Invoke-PowerPagesAuthoring.ps1 -Operation Upload -Path ".\PowerPages\<SiteName>" -WebsiteId "<guid>" [-DeploymentProfile dev] [-ForceUploadAll]
```

| Operation | Mechanism | Notes |
|---|---|---|
| `ListSites` | `pac pages list` | Website IDs + data model per site |
| `DetectModel` | `pac pages list -v` | Reports standard vs enhanced; drives the `--modelVersion` for later ops |
| `Download` | `pac pages download --modelVersion <1\|2> --overwrite` | Version auto-detected from the Website ID (override with `-ModelVersion`) |
| `Upload` | `pac pages upload --modelVersion <1\|2>` | Version auto-detected from `-WebsiteId`, or pass `-ModelVersion`; never relies on the CLI default of 1. Delta on same env; `-ForceUploadAll` for recovery |

> **Page creation and edits are file operations** on the downloaded folder (step 4), not a CLI sub-command — there is no `pac pages create-page`. The script owns the safe pac round-trip; Claude authors the component files by mirroring what `Download` produced.

## Critical Rules

### DO
- Read the design-studio + security + ALM SOPs before authoring.
- **Detect the data model first** and pass the **matching `--modelVersion`** (1 = standard, 2 = enhanced) on every download/upload — never rely on the CLI default of `1`.
- Author new components by **mirroring existing downloaded files**; derive YAML fields from disk.
- Treat caching (not a failed upload) as the first explanation for "my change isn't showing."
- Commit the delete-tracking `manifest.yml`; gitignore the per-environment manifest.

### DO NOT
- On the **enhanced** model, hand-author `powerpagecomponent` JSON or write `mspp_*` tables directly — they're read-only virtual tables; the CLI round-trip is the only supported enhanced write path. (On the **standard** model, record-level `adx_*` Web API writes are acceptable for small edits.)
- Fabricate YAML field names or folder layout — read them from the downloaded site.
- Build a data-surfacing page without the matching table/column permissions (security SOP).
- Use this skill to deploy to QA/Prod — that's `hso-dataverse-pipelines`.
- Author forms or lists yet — deferred to v2.

## Roadmap

- **v2** — basic forms, multistep forms (stage-then-apply pattern), and lists. Deferred because they are entangled with the security model (table/column permissions, the `AttributePermissionIsMissing` lookup trap) and warrant tight coupling to `hso-dataverse-securityrole`.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
