# Specify

<!-- cspell:ignore speckit -->

Purpose: turn a feature description into `specs/NNN-<slug>/spec.md` with `/speckit-specify`, then remove ambiguity
with `/speckit-clarify`.

## Workflow

1. **Check the constitution is approved** (SKILL.md phase detection). If not, stop and say so.
2. **Run `/speckit-specify <description>`.** It creates `specs/NNN-<slug>/spec.md` and records the folder in
   `.specify/feature.json`. Pass the user's description as given; don't add technology choices (they belong in the
   plan).
3. **Check the spec:**
   - it says what and why, not how (no frameworks, libraries or schemas);
   - user scenarios are present;
   - each requirement has acceptance criteria that can be tested;
   - out-of-scope items are listed;
   - anything unclear is a `[NEEDS CLARIFICATION: …]` marker, not a guess.
4. **Run `/speckit-clarify`** when markers remain or the spec is vague. It asks up to five questions and writes the
   answers into `spec.md`; repeat for other areas if needed.
5. **Show `spec.md`** (and `checklists/requirements.md` if it was created) and stop.

## Review gate

The user approves `spec.md` with no `[NEEDS CLARIFICATION]` markers left (or accepts the ones left, in writing)
before `/speckit-plan`.

## Safety

- An existing `spec.md` for the same feature is updated only after asking; never start a second folder for the same
  feature silently.
- Don't edit `spec-template.md`; use an override or preset.

## Example

"Spec this feature: let users export the generated files as a zip." → `/speckit-specify Let users export the
generated files as a zip…`; the spec gets a `[NEEDS CLARIFICATION: include orphaned files in the zip?]` marker;
`/speckit-clarify` asks about it; the updated spec is shown for approval.
