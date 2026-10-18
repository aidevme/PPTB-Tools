# Sources

<!-- cspell:ignore tsdoc typedoc inthhq consentdotio -->

Purpose: where this skill's rules come from, what was checked when, and what was adopted from community skills.

## Standard and tools (checked 2026-10-18)

| Source | Version | Used for |
| --- | --- | --- |
| [TSDoc](https://tsdoc.org/), [microsoft/tsdoc](https://github.com/microsoft/tsdoc) (MIT) | `main` at `76dcd8e` | The 29 standard tags with kind and group (`tsdoc/src/details/StandardTags.ts`), `tsdoc.json` keys (`tsdoc/schemas/tsdoc.schema.json`) |
| `@microsoft/tsdoc` | 0.17.1 | The parser |
| `@microsoft/tsdoc-config` | 0.18.3 | `tsdoc.json` loading (README: location, `extends`) |
| `eslint-plugin-tsdoc` | 0.5.4 | The `tsdoc/syntax` rule; the legacy config from its README; exports one rule and no presets (`eslint-plugin/src/index.ts`) |
| `typedoc` | 0.28.20 | Optional doc generation |
| `@microsoft/api-extractor` | 7.59.4 | Optional API reports; release tags |

## Community skills

Used as sources of rules only; neither is installed.

**bm629/agent-skills `tsdoc`** ([skills.sh](https://www.skills.sh/bm629/agent-skills/tsdoc),
[repository](https://github.com/bm629/agent-skills), MIT, read at `6f1504c`). Thanks to its author.

- Adopted (rewritten here): no types in comments; document the public surface and skip trivial and generated code;
  the hyphen in `@param` and `@typeParam`; `@returns` over `@return`; `@deprecated` is a block tag that names the
  replacement; `{@inheritDoc}` excludes its own summary and `@remarks`; prefer the `override` keyword over the
  `@override` tag; an `@example`'s first line is its title; never invent tags.
- Not adopted: "convention only, don't add eslint-plugin-tsdoc by default" (this skill uses the rule as the check,
  offered with the user's approval); "TypeDoc setup is out of scope" (setup.md mentions it as optional).

**consentdotio/agent-skills `tsdoc-jsdoc-authoring`**
([skills.cat](https://skills.cat/skills/consentdotio/agent-skills/tsdoc-jsdoc-authoring); the repository now
redirects to `inthhq/agent-skills`, which has no license). Treated as data only: no text was copied from its
`SKILL.md`, `reference.md` or rule files, and only general ideas were taken.

- Adopted (as ideas): never mix TSDoc and JSDoc syntax in one comment; document object parameters on a named type
  with a comment per property; for JavaScript, JSDoc types in braces, bracket syntax for optional and default
  parameters, `@typedef` and `@property` for shapes.
- Not adopted: rules about `@access` consistency and `@implements`, which are niche JSDoc topics outside this skill.

## Re-checking

When TSDoc or the plugin releases a new version, re-read `StandardTags.ts`, the schema and the plugin README, update
tags.md and setup.md, and change the dates and versions here.
