# Plan

<!-- cspell:ignore speckit -->

Purpose: produce the technical plan (`plan.md` and its design files) with `/speckit-plan` and check it against the
constitution.

## Workflow

1. **Check `spec.md` is approved.** If not, stop and say so.
2. **Ask for the technical context** if the user hasn't given it: stack, architecture, constraints, the repository's
   existing conventions. Don't invent a stack.
3. **Run `/speckit-plan <technical context>`.** It writes `plan.md` and design files (for example `research.md`,
   `data-model.md`, `contracts/`, `quickstart.md`) in the feature folder.
4. **Check the plan against the constitution:** every principle is met, or the plan names the exception and why.
   With the [power-platform](profiles/power-platform.md) profile, a PCF feature names the
   `ControlManifest.Input.xml` + `index.ts` change, the new properties' documentation and the solution it's packaged
   in.
5. **Record big or hard-to-reverse choices** (a new dependency, a data model, an integration) as a short ADR note.
   In a repository with an ADR folder, use its process (here: `agent/wiki/decisions/` through
   `aidevme-wiki-write-decision`); otherwise a "Decisions" section in `plan.md`.
6. **Show `plan.md`** and the design files, and stop.

`/speckit-analyze` (cross-artifact consistency) runs after `/speckit-tasks` in v1.2.1; see [tasks.md](tasks.md).
`/speckit-checklist` is an optional quality gate here, when the user wants a requirements checklist.

## Review gate

The user approves `plan.md` (and any ADR notes) before `/speckit-tasks`.

## Safety

- Don't change the spec while planning; a gap in the spec goes back to [specify.md](specify.md).
- Don't edit `plan-template.md`; use an override or preset.

## Example

`/speckit-plan Use the existing React + Fluent UI v9 app; zip with an in-browser library; no new PPTB APIs.` → the
plan lists the files touched, the test approach (`npm test`), and a Decisions note for the new zip dependency.
