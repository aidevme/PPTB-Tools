# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-skill-recorder** skill: turning a demonstrated or described workflow into a reviewed SKILL.md. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/meta/aidevme-skill-recorder/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.
- **The skill itself.** Ports the skill-recorder method: redact secrets from the evidence, reconstruct one intent
  and ordered steps for approval, generalize, map UI clicks to CLIs and APIs, draft from
  [references/skill-template.md](references/skill-template.md), and show the full SKILL.md before saving; in this
  repository the approved draft goes to `aidevme-skill-creator`. References for redaction and UI-to-API mapping
  (commands checked against `gh` help and Microsoft Learn on 2026-10-21) and five evals. (0834d8f)
