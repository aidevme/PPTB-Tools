# Power Pages Design-Studio Component Cheatsheet

Load when authoring or editing components in a downloaded site folder. This is a *reference for mirroring real files* — always derive exact YAML field names and folder layout from the files `pac pages download` produced for the target site, not from memory.

## How a page is actually composed

A rendered page is **three records working together**:

```
Web page  ──(required)──>  Page template  ──(Type = Web Template)──>  Web template (Liquid + HTML)
   │
   ├─ Parent page  (builds the sitemap hierarchy; the single Home page has no parent, Partial URL = "/")
   ├─ Partial URL  (the path segment; joined by "/" up the parent chain to form the full URL)
   ├─ Publishing State
   └─ Copy         (the editable HTML body; injected into the template via {% include 'page_copy' %})
```

- **Web template** holds the Liquid/HTML `Source`. A page template with **Use Website Header and Footer** checked renders the template *between* the global header/footer; unchecked, the template owns the whole response (needed for non-HTML output via MIME type).
- **Multi-language:** a web page splits into a **root web page** + one **localized content page per language**. The localized record carries per-language **Copy**, **Custom JavaScript**, **Custom CSS**.

## To create a page (mirror pattern)

1. In the downloaded folder, find an **existing web page** (the Home page always exists).
2. Copy its file set (the `.yml` metadata file(s) + content files such as the copy HTML, custom JS/CSS).
3. Change: **Name**, **Partial URL**, **Parent Page**, **Page Template** reference, **Publishing State**, **Title/Summary**, and the **Copy** HTML.
4. If the page needs a new layout, also create/point to a **web template** (Liquid) and a **page template** that references it.
5. Wire navigation by adding a **web link** to the appropriate **web link set** (e.g. primary navigation).
6. `Upload` (always `--modelVersion 2`).

> Generate IDs/GUIDs only where the existing files show them being author-supplied. If the layout uses content-keyed files, mirror that convention exactly.

## Component types in scope (pages-first v1)

| Component | Renders / does | Edit by |
|---|---|---|
| **Web page** | a URL node in the sitemap | mirror an existing page's files; set parent, partial URL, template, copy |
| **Page template** | required layout pointer for a page (Type = Web Template or Rewrite) | point at a web template; set Is Default / Table Name as the existing ones do |
| **Web template** | Liquid + HTML source; the central Liquid integration point | edit the source file; `include`/`extends` other templates by Name |
| **Content snippet** | reusable named HTML/text fragment | edit the content file; rendered via `{% include 'snippet' snippet_name:'Name' %}` |
| **Web file** | static asset (CSS/JS/image/PDF); binary stored as a note attachment | add/replace the asset + its metadata file |
| **Web link set** + **web links** | navigation menus (e.g. Primary Navigation) | add/edit links; rendered via `{% include 'top_navigation' %}` |
| **Site setting** | key/value site config | edit the value; some are ALM-managed via environment variables (ALM SOP) |

## Deferred to v2 (do NOT author with this skill yet)

Basic forms, multistep forms (+ steps), lists — data-bound and entangled with table/column permissions. Configure in the design studio for now; v2 will add them with `hso-dataverse-securityrole` coupling.

## `powerpagecomponenttype` map (enhanced model)

On the enhanced model, configuration lives as JSON in `powerpagecomponent`, discriminated by `powerpagecomponenttype`. The `mspp_*` tables that project these are **read-only** — never write them; the CLI is the only supported write path. Type values (load-bearing for read-only queries):

```
1  Publishing State        9  Site Setting          17 List
2  Web Page               10 Web Page Access Rule   18 Table Permission
3  Web File               11 Web Role               19 Advanced Form
4  Web Link Set           12 Website Access         20 Advanced Form Step
5  Web Link               13 Site Marker            21 Advanced Form Metadata
6  Page Template          15 Basic Form             30 Redirect
7  Content Snippet        16 Basic Form Metadata     32 Shortcut
8  Web Template                                       34 UX Component
```

## Common built-in Liquid includes

```liquid
{% include 'page_copy' %}                          {# the page's editable Copy field #}
{% include 'snippet' snippet_name:'Name' %}        {# a content snippet #}
{% include 'top_navigation' %}                     {# primary nav from a web link set #}
{% include 'breadcrumbs' %}
{% extends 'layout_2_column_wide_left' %}{% block main %}…{% endblock %}
```

## Footguns

- **`--modelVersion` defaults to 1 (standard).** Detect the site's model first and pass the **matching** version (1 = standard, 2 = enhanced); never rely on the default. Download and upload of the same folder must use the same version.
- **Caching, not a failed upload, is the usual reason a change isn't visible.** Apply the ALM SOP `today` cache-buster.
- **Cross-environment upload is a full upload**, not a delta (the delta manifest is per-environment). For dev→dev iteration the delta applies.
- **Enhanced vs standard write path differs.** On **enhanced**, round-trip through the CLI — never hand-write `powerpagecomponent` JSON or `mspp_*` tables (read-only). On **standard**, the `adx_*` config tables are real, writable entities, so record-level Web API writes are acceptable for small edits (the CLI round-trip still works and is preferred for anything multi-file).

## Sources

- Power Pages design-studio + ALM + security SOPs (`shared/dv/agent/wiki/sop/power-pages/`)
- Microsoft Learn: [pac pages reference](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/pages) · [enhanced data model](https://learn.microsoft.com/en-us/power-pages/admin/enhanced-data-model) · [web templates](https://learn.microsoft.com/en-us/power-pages/configure/web-templates) · [web pages](https://learn.microsoft.com/en-us/power-pages/configure/web-page) · [Power Platform CLI for Power Pages](https://learn.microsoft.com/en-us/power-pages/configure/power-platform-cli)
