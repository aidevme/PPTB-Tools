# CI status

Purpose: read the latest CI results for a branch or pull request, summarise failures from the job logs, and propose
a fix. Read-only.

Load [mcp-setup.md](mcp-setup.md) first.

## Workflow

1. **Find the run.**
   - For a pull request: `pull_request_read` (method `get_check_runs`, or `get_status` for combined commit status)
     on its number.
   - For a branch: `actions_list` (method `list_workflow_runs`, `workflow_runs_filter: { branch: <branch> }`) and
     take the newest run;
     `actions_get` (method `get_workflow_run`, `resource_id`: the run ID) for its details.
2. **Report the status** per workflow and job: passed, failed, cancelled, in progress. If it's still running, say
   so and stop; don't poll in a loop.
3. **Summarise failures** from `get_job_logs` (`run_id`, `failed_only: true`, `return_content: true`): the failing
   job and step, the first real error (not the cascade after it), and the file and line when the log names one.
   Keep log excerpts short.
4. **Propose a fix:** the likely cause, the change, and how to verify it locally (the repo's own build and test
   commands). Making the change and committing it follows the normal flow ([commit.md](commit.md)) and only when
   the user asks.

## Never

Re-run, cancel or trigger a workflow without explicit confirmation. If the user asks for a re-run, name the run and
workflow and confirm first; `actions_run_trigger` isn't in this skill's `allowed-tools`, so the client asks as well.

## Example summary

> **CI: failed.** Workflow `build` → job `test` → step `npm test`: 1 failing test,
> `settings.test.ts > stays open when the folder picker is cancelled` (timeout after 5000 ms). Likely a slow runner;
> it passes locally. Suggested fix: raise this test's timeout, then run `npm test`.
