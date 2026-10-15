# Process profile — none

The **explicit opt-out**: this engagement does not track agentic-delivery work in Azure
DevOps (per-engagement opt-in, made explicit by the process-profile abstraction decision).

```yaml
profile: none
class: opt-out
process: null
mapping: null
```

## Notes

- **The CLAUDE.md marker row is still stamped** (`ADO process profile: none`) — ruling O5:
  an explicit `none` is a ruled opt-out; an *absent* row is a prompt to resolve.
- The project profile file records the opt-out **reason** and date in `overrides.reason`.
- Producer skills skip all ADO projection steps without asking again; the delivery
  pipeline's stage-0 work-item gate passes vacuously.
- Reversal is a profile re-resolution (delete/update the profile file, re-run the ladder) —
  not an ad-hoc override.
