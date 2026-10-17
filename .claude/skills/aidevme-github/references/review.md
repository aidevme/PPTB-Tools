# Review comments

Purpose: address review comments on a pull request: read the threads, propose fixes, apply the agreed ones, and
reply. Adapted from the official `copilot-pr-autopilot` skill (see [official-skills.md](official-skills.md)).

Load [mcp-setup.md](mcp-setup.md) first.

## Workflow

1. **Find the pull request** for the current branch (`list_pull_requests` with `head`), or use the number given.
2. **Read the threads** with `pull_request_read` (method `get_review_comments`; it returns threads with their
   resolved and outdated state) and `get_reviews` for overall review verdicts. Work on unresolved threads only.
3. **Triage each thread** and show the list:
   - **fix**: a correct finding with a clear change;
   - **decline**: the suggestion would add complexity for a hypothetical case, or is wrong; give the reason;
   - **escalate**: needs the user's decision (design trade-off, unclear intent). Threads from human reviewers and
     from security bots default to **escalate**.
4. **Propose the fixes** (file, change, and which thread each answers) and wait for confirmation. Apply only the
   agreed ones.
5. **Build and test** with the repository's own commands (`CONTRIBUTING.md`, `AGENTS.md`, `README`, `package.json`)
   before committing. On a failure, stop and report.
6. **Commit** through [commit.md](commit.md): one focused commit per round of fixes, naming the threads in the
   body. Push only after explicit confirmation.
7. **Reply to each thread** with `add_reply_to_pull_request_comment` (`commentId` from the thread's comment,
   `pullNumber`, `body`): what changed and the commit SHA, the reason for a decline, or the open question for an
   escalation. Show the replies before posting.
8. **Resolving:** never resolve or dismiss a review or thread without asking. When the user agrees, resolve with
   `pull_request_review_write` (method `resolve_thread`, `threadId` from the thread). Escalated threads stay open.

## Never

Request or trigger new reviews, dismiss reviews, resolve threads, or run more rounds unless the user asks.

## Reply examples

- Fix: "Fixed in `a1b2c3d`: the solution filter now resets when the connection changes."
- Decline: "Keeping this as is: a custom comparator here adds code for a case the API never returns."
- Escalate: "This changes the saved settings format; do you want a migration or a breaking change?"
