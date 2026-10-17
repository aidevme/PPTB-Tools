---
adr: 0001
title: Foundational principles for the HSO Power Platform project template
status: accepted
date: 2026-09-10
author: aidevme
supersedes: []
---

# ADR-0001 — Foundational principles

## Context

We are building one reusable, best-in-class Power Platform / Dataverse project template by merging three
sources: **CDX** (`HSO-Power Platform Pipeline Template - CDX`), **HINT** (`HINT-Pipelines`), and a
**live-delivery reference** (an HSO engagement). The template must serve **any** engagement (HSO and beyond), not just that source client.
This ADR records the cross-cutting decisions that hold across every part (agent, server, client,
pipelines, PCF) and are settled independently of the per-part source analyses.

## Decisions

1. **Neutral by construction.** No customer identity is baked into the reusable core. Namespaces and
   project tokens use `HSO.Customer.*` / `Customer`; a documented initialize/rename step personalises a
   new project. Rationale: reusability is the primary success metric.

2. **Template, not hardcode.** Code and pipeline shapes live as **editable blueprints** that the agent/
   skills *read and generate from* — never as logic hardcoded inside skills. Changing a template changes
   what the agent produces. (From HINT's model; strengthened.) Rationale: the template must be openable,
   inspectable, and evolvable without touching skill code.

3. **Config-driven generation.** Where artefacts repeat with variation (pipelines especially), they are
   **generated from declarative config + templates**, not copy-pasted. A project describes what it needs;
   the generator emits the concrete artefacts. (From CDX's `PipelinesHelpers`.) Rationale: a build-suite
   assembled to measurement beats N hand-maintained near-duplicates.

4. **Dual-assistant, single source of truth.** Skills/knowledge are authored **once** and served to
   **both** Claude (`.claude/`) and GitHub Copilot (`.github/`) via a sync mechanism — never maintained
   twice by hand. (From HINT's parallel skill trees.) Rationale: parity without drift.

5. **Product skills vs project skills are separated.** Reusable HSO product skills live apart from
   **project-specific** skills (a dedicated folder). A project may add its own skills without polluting
   the reusable core, and the core can be updated without clobbering project skills. Rationale: explicit
   user requirement; clean upgrade path.

6. **Buildable and tested, not just documented.** Every code template must compile and its tests must run
   locally (`dotnet build` + unit tests; `npm ci && build` + jest). Hard-won runtime lessons are encoded
   as guards/tests, not just prose. Rationale: "bulletproof" means proven, not asserted.

7. **Every part is fully documented — twice.** Each part ships (a) an **architecture/decision** write-up
   for reviewers and (b) an **onboarding** guide for people joining a project. Plus a **review log**
   capturing each build→critique→improve iteration. Rationale: the template is also a teaching artefact.

8. **Local-only build.** All work is produced locally in `C:\Repos\workspace\NewTemplate`; the three
   sources are strictly read-only; no git push, no remotes, no environment/pipeline/deploy actions.

## Consequences

- A per-part source analysis (`docs/review-logs/partN-*-01-source-analysis.md`) precedes each build so the
  merge is deliberate, not accidental.
- The agent layer must include skill-authoring + skill-sync + template-maintenance skills so the template
  can maintain itself.
- Naming, folder layout, and config schemas are themselves design artefacts with their own ADRs.

## Method (per part, then integration)

`review 3 sources → build merged best version → expert self-review (written critique) → improve →
re-review → loop until converged`. After all five parts converge, run a **whole-solution integration**
loop applying the same cycle to how the parts fit together.
