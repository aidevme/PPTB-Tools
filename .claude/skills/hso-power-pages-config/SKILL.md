---
name: hso-power-pages-config
layer: atomic
scope: core
description: |
  Configure an existing STANDARD data model (`adx_*`) Power Pages / Power Apps portal via the Dataverse Web API — table permissions, basic forms, web pages, navigation, content, and surfacing records to a portal contact. Use when:
  (1) Editing a portal's pages, navigation, forms, or buttons and the site uses the standard `adx_*` tables (not the enhanced `mspp_*`/`powerpagecomponent` model)
  (2) Making Dataverse records visible to a portal contact (table-permission scope + relationship)
  (3) Adding/removing a button or pre-filling a lookup on a portal basic form
  (4) Provisioning a portal login for a contact
  This is the STANDARD-model counterpart to the (proposed) enhanced-only `hso-power-pages-authoring` (PAC `pac pages` round-trip). Detect the model first; if the site is enhanced, use that skill instead.
---

# Power Pages — Standard (`adx_`) Config via Web API

A field guide for configuring an **existing standard-data-model** Power Pages portal through the Dataverse Web API. Most long-lived HSO portals are standard (`adx_*`); the design-studio "enhanced" model (`mspp_*` / `powerpagecomponent`) is a different surface (see the proposed `hso-power-pages-authoring`).

> **Authoritative methodology**: read [`shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md`](../../../shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md) before granting any data access (web roles + table/column permissions; the AppOmni breach pattern is the bar).

## 0. Detect the data model FIRST

- **Standard**: the site's content lives in `adx_website` + `adx_webpage` / `adx_webtemplate` / `adx_entityform` / `adx_entitylist` / `adx_entitypermission` / `adx_weblink`. `pac pages download --modelVersion 1` pulls real content.
- **Enhanced**: `powerpagesite` + `powerpagecomponent` (+ read-only `mspp_*`). If the portal is enhanced, **stop** — this skill's `adx_` writes won't render; use the PAC `pac pages` round-trip.
- A site can have an `adx_website` AND a same-named `powerpagesite`; confirm which one the live domain binds to (`adx_website.adx_primarydomainname`).

## 1. ⚠️ The #1 trap: live content can render from a WEB TEMPLATE, not `adx_copy`

A web page's visible HTML may come from a bound **`adx_webtemplate` (`adx_source`)** via the page template — **not** the page's own `adx_copy` field. Editing `adx_copy` then silently does nothing.

**Before editing page content:** find where the rendered HTML actually lives — search `adx_webtemplate.adx_source` (and content snippets) for a unique string you see on the page, not just `adx_webpage.adx_copy`. The page template (`adx_pagetemplate.type = 756150001`) tells you it's web-template-based.

## 2. Pages are TWO records (root + language content)

Creating a page in the standard model = **two `adx_webpage` rows**:
- **Root** (`adx_isroot = true`) — the structural page.
- **Content** (`adx_isroot = false`) — binds `adx_rootwebpageid` + `adx_webpagelanguageid` (→ entity set **`adx_websitelanguages`**, NOT `adx_webpagelanguages`).

Both carry `adx_pagetemplateid`, `adx_publishingstateid` (**Published**), `adx_parentpageid`, and the `adx_entityform`/`adx_entitylist` binding. Mirror an existing working page (e.g. an OOB "Create …" page) for the exact field set.

## 3. Navigation links need a Published publishing state

A new `adx_weblink` **will not render** unless `adx_publishingstateid` = the site's **Published** state (a working sibling link has it; a missing one is the usual "my nav link doesn't show" cause). Child links nest via `adx_parentweblinkid` under a parent in the same `adx_weblinkset` (e.g. "Primary Navigation").

## 4. Portal URLs are the FULL hierarchical path

A page's URL = the chain of ancestor `adx_partialurl`s + its own. A bare `/customer-quotes` 404s if the page is a child of "Customers" — the real URL is `/customers/customer-quotes/`. **Hardcoded `href`s in dashboard tiles / HTML must use the full path.** Resolve it by walking `adx_parentpageid` up to Home. (Nav `adx_weblink` records that reference a page by id resolve the path automatically — only raw HTML hrefs need the full path.)

## 5. Surfacing records to a portal contact = scope + relationship

The `adx_entitypermission` `adx_scope` + its relationship decide which rows a portal user sees:

| Scope | Value | Sees rows where… | Field used |
|---|---|---|---|
| Global | 756150000 | any (role-gated) | — |
| Contact | 756150001 | the `adx_contactrelationship` lookup = logged-in contact | e.g. `incident.customerid` (contact) |
| Account | 756150002 | the `adx_accountrelationship` lookup = logged-in contact's parent account | e.g. `quote.msdyn_account`, `invoice.customerid`, `incident.customerid` |

To make a record visible to a partner, **set that scope-relationship field to the partner's account/contact** (e.g. `quote.msdyn_account = <agency account>`; `invoice.customerid = <agency account>`). Resolve the exact field per relationship via `RelationshipDefinitions(SchemaName='<rel>')/…OneToManyRelationshipMetadata?$select=ReferencingEntity,ReferencingAttribute`.

## 6. Buttons & lookup-prefill live in `adx_registerstartupscript`

Custom buttons (e.g. "Accept Quote", "Submit Feedback") on a basic form are **injected JavaScript in the form's `adx_registerstartupscript`** — not page HTML. To add/remove a button, edit that script field on the `adx_entityform`.

**Lookup prefill from query string**: `adx_entityformmetadata`'s `adx_prepopulatetype` has only **Value / Today / Current Portal User** (no Query-String option) in current versions. Prefill a lookup from `?param` via a startup-script that sets the hidden inputs: `#<field>` (id), `#<field>_name` (display), `#<field>_entityname` (logical name).

## 7. Auth & backup

- **PAC reuse**: point an existing `pac auth` profile at the target org with `pac org select --environment <url>` — no new sign-in. `pac pages list` to find the website id.
- **Backup before edits**: `pac pages download --path <dir> --webSiteId <id> --modelVersion 1`.

## 8. Always: clear the portal cache after changes

Standard-model `adx_` config (permissions, forms, pages, nav, web-template content) is cached. Changes won't show until you **Clear Cache** (`/_services/about` signed in as an *Administrators*-web-role contact) or **Restart** the site in the Power Pages admin center. Browser cache ≠ server cache.

## Common entity sets / discriminators (quick ref)

`adx_websites` · `adx_webpages` · `adx_webtemplates` · `adx_pagetemplates` · `adx_entityforms` · `adx_entitylists` · `adx_entitypermissions` (+ N:N `adx_entitypermission_webrole`) · `adx_weblinksets` / `adx_weblinks` · `adx_webroles` (N:N `adx_webrole_contact`) · `adx_publishingstates` · `adx_websitelanguages` · `adx_contentsnippets`. Local-auth login fields on `contact`: `adx_identity_username`, `adx_identity_logonenabled`, `adx_identity_passwordhash`, `adx_identity_securitystamp`.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
