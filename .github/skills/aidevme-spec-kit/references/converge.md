# Converge

<!-- cspell:ignore speckit -->

Purpose: check that the code still matches the spec, plan and tasks before a pull request, and decide with the user
how to resolve any drift.

## Workflow

1. **Run `/speckit-converge`.** In v1.2.1 it ends with one of:
   - **Converged:** `tasks.md` is unchanged; the feature is ready for review or a pull request.
   - **Tasks appended:** it adds the gaps as new tasks under a Convergence section in `tasks.md`.
2. **If the command isn't available**, compare by hand: `git diff <base>...HEAD` (base branch from aidevme-github's
   `references/branch.md`) against `spec.md` and `tasks.md`. List behavior in the code that no requirement covers,
   requirements with no code, and open tasks.
3. **Report the drift** and ask, item by item, whether to **update the spec** (the behavior is wanted) or **fix the
   code** (it isn't). Appended tasks that the user rejects are removed from `tasks.md` only after asking.
4. **Repeat** [implement.md](implement.md) and converge until it reports Converged.

## Review gate

The user accepts the converge result (Converged, or each drift item resolved) before the pull request handoff.

## Safety

- Required before a pull request through aidevme-github ([github-handoff.md](github-handoff.md)).
- Never change the spec to match the code without the user's decision.

## Example

The code adds a "Download log" button no requirement mentions; converge appends a task for it; the reply asks
whether to add a requirement to `spec.md` or remove the button, and waits.
