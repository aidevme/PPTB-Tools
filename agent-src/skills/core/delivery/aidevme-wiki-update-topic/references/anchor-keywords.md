# Anchor concept keywords

Sidecar data file for `aidevme-wiki-update-topic` synthesis mode's keyword-fallback pass.

When synthesis mode runs on a repo where most content is not yet tagged with `topics:` frontmatter, the fallback pass grep-matches file bodies (case-insensitive) against the keyword sets below. Each hit becomes a two-edit proposal: (a) add the file as a link under the anchor's matching section, (b) add the anchor slug to the file's `topics:` frontmatter. See `SKILL.md` §4b for the full flow.

Keep keyword sets small and specific. A keyword set that matches too broadly produces noise in the proposal review; a keyword set that's too narrow misses hits the human reviewer would have accepted. When in doubt: add one synonym at a time, run the fallback, look at the proposals, tune.

**Format**: one `## <anchor-slug>` section per anchor page in `wiki/topics/`. Under each, a bullet list of case-insensitive phrases. Phrases, not regexes — the fallback does literal case-insensitive substring matching.

**Scope note**: these are the product-tier anchors for Forge-USA. Project-tier anchors in consuming repos should add their own sections (or maintain their own local `anchor-keywords.md` if the skill is invoked against a project wiki).

---

## configuration-data
- configuration data
- config data
- reference data
- seed data
- environment variable

## custom-api
- custom api
- customapi
- custom_api
- CustomAPI
- messageprocessor

## data-migration
- data migration
- data import
- kingswaysoft
- ssis
- migration package

## dataverse-metadata-and-web-api
- web api
- webapi
- metadata api
- $metadata
- EntityDefinitions
- RetrieveMetadataChanges

## dataverse-naming-conventions
- naming convention
- prefix
- publisher prefix
- schema name
- logical name

## dual-write
- dual-write
- dual write
- dualwrite
- f&o integration
- finance and operations

## pcf-controls
- pcf
- power apps component framework
- control manifest
- ControlManifest
- pcf-scripts

## plugin-development
- plugin
- iplugin
- pluginbase
- IPluginExecutionContext
- RegisterFile
- plug-in

## polymorphic-lookup
- polymorphic
- polymorphic lookup
- customer lookup
- owner lookup
- regardingobjectid

## power-automate
- power automate
- cloud flow
- flow action
- flow trigger
- dataverse connector

## repo-setup
- repo setup
- repository setup
- init-repo
- initialize repo
- shared/dv
- junction

## sample-data
- sample data
- demo data
- test data fixture
- seed sample

## solution-alm
- solution alm
- alm
- managed solution
- unmanaged solution
- solution layering
- pipelines

## ui-guidelines
- ui guideline
- form design
- ribbon
- command bar
- model-driven form

## webresource-development
- webresource
- web resource
- html webresource
- javascript webresource
- form script
