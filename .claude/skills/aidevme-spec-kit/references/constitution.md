# Constitution

<!-- cspell:ignore speckit -->

Purpose: write the project constitution (`.specify/memory/constitution.md`) with `/speckit-constitution`, once per
project, before any spec.

## Workflow

1. **Check the current file.** It still has template placeholders (`[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`, …): this
   is the first constitution. It's already filled in: this is a change, which needs an explicit request (see
   Safety).
2. **Pick a profile** with the user: [power-platform](profiles/power-platform.md),
   [typescript-web](profiles/typescript-web.md), both, or none. Ask for the values a profile leaves open (for
   example the publisher prefix). Add the repository's own rules from `AGENTS.md` / `CONTRIBUTING.md`.
3. **Run `/speckit-constitution`** with the chosen principles as its argument, written as short, checkable
   statements.
4. **Check the result:**
   - no placeholders left;
   - each principle can be checked against a pull request ("every new function has a unit test", not "high
     quality");
   - no client names, environment URLs, IDs or secrets.
5. **Show the file** and stop.

## Review gate

The user approves the constitution before the first `/speckit-specify`.

## Safety

- Later changes only on an explicit request. Each change adds a dated line to a changelog section at the end of the
  constitution (date, what changed, why).
- Don't edit `.specify/templates/constitution-template.md`; customize through an override or preset instead.

## Example

```text
/speckit-constitution Principles: (1) All Dataverse changes ship in a solution with the publisher prefix "cnt".
(2) No environment URLs, IDs or secrets in source; use environment variables and connection references.
(3) Every plugin and PCF change has a test listed in its tasks. (4) Production changes go only through the pipeline.
```
