# Tasks

<!-- cspell:ignore speckit taskstoissues -->

Purpose: break the approved plan into `tasks.md` with `/speckit-tasks`, check consistency with `/speckit-analyze`,
and optionally create GitHub issues through aidevme-github.

## Workflow

1. **Check `plan.md` is approved.** If not, stop and say so.
2. **Run `/speckit-tasks`.** It writes `tasks.md` with numbered items (`- [ ] T001 …`, `[P]` for tasks that can run
   in parallel).
3. **Check the tasks:**
   - each is small enough for one review;
   - they're in dependency order;
   - each traces to a requirement or user story in `spec.md`;
   - each with logic names its test.
4. **Run `/speckit-analyze`** (read-only consistency check across spec, plan and tasks). Gaps in the spec go back to
   [specify.md](specify.md); gaps in the plan to [plan.md](plan.md).
5. **Show `tasks.md`** and the analysis, and stop.
6. **GitHub issues (optional, only when asked):** create them through aidevme-github's issues capability
   (`references/issues.md`), one confirmed batch, then add the issue numbers to the tasks. **Don't use
   `/speckit-taskstoissues`** (deprecated in v1.2.1) or the `github` extension, so GitHub writes stay under
   aidevme-github's rules.

## Review gate

The user approves `tasks.md` before any code is written ([implement.md](implement.md)).

## Safety

- Regenerating an existing `tasks.md` needs the user's approval; ticked tasks must not be lost.
- No issues without explicit confirmation of the list.

## Example

`/speckit-tasks` produces T001–T009; `/speckit-analyze` reports that FR-004 has no task; the spec gap is shown, the
user adds a task, and the updated `tasks.md` is approved.
