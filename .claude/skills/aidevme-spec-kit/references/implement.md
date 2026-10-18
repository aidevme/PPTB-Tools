# Implement

<!-- cspell:ignore speckit -->

Purpose: implement the approved tasks with `/speckit-implement`, one task (or agreed group) at a time, with tests
and a commit offer after each.

## Workflow

1. **Check `tasks.md` is approved.** Asked to "build it" earlier: refuse, and name the phase that's waiting.
2. **Pick the next open task** (or the group the user agreed, for example all `[P]` setup tasks), and say which.
3. **Run `/speckit-implement`** scoped to that task, for example `/speckit-implement T003 only`.
4. **Run the tests** the task and the plan name (for example `npm run build` and `npm test`).
5. **Tests pass:** tick the task (`- [x] T003`) if `/speckit-implement` didn't, show the diff summary, and **offer**
   a commit through aidevme-github ([github-handoff.md](github-handoff.md)): the message references the task ID
   and adds `Refs #n` when the task has an issue. Commit only if the user asks.
6. **Stop** after each task (or group) for review, then continue with the next.

## Review gate

After each task: the user reviews the change and the test result, and decides whether to commit and continue.

## Safety

- **Stop on a failing test, build or hook error.** Report it with the output and the likely cause; don't continue.
- **Never tick a task with failing tests**, and never weaken or skip a test to make it pass.
- Never commit or push directly; don't change code outside the task's scope (note it as a new task instead).

## Example

T003 is implemented, `npm test` passes, T003 is ticked, and the reply ends with "Commit this through aidevme-github
as `feat(export): add zip builder (T003)`?", without running `git commit`.
