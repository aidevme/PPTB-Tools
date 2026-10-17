# Refactoring proposal template (Phase 2 and 3)

One proposal per selected tool. Step IDs (`S1`, `S2`, …) are stable: the approval, the commits, the report and the
saved file all refer to them. When the plan is revised in Phase 3, keep existing IDs and add new ones; mark the
proposal version (`v1`, `v2`, …).

```markdown
## <tool-name> — refactoring proposal (v1)

Reviewed: <YYYY-MM-DD>, commit <short SHA>, branch <branch>

### a) Current-state analysis

#### Structure and architecture
<folders, entry points, key components, how state and data flow; cite paths>

#### Code quality
| Area | Finding | Evidence |
| --- | --- | --- |
| Duplication | ... | `src/...ts:42` |
| Complexity | ... | ... |
| Typing gaps | ... | ... |
| Dead code | ... | ... |
| Naming | ... | ... |
| Error handling | ... | ... |

#### Dependencies
| Package | Current | Latest | Issue (outdated / vulnerable / unused) | Evidence |
| --- | --- | --- | --- | --- |

`npm audit`: <counts by severity, or "not run" and why>

#### UI/UX consistency with other AIDevMe tools
<Fluent UI v9 usage, theming (light/dark), layout, notifications, wording; compare with named files in other tools>

#### Performance and maintainability
<findings with evidence>

#### Test coverage
<what's tested, what isn't, coverage numbers only if measured>

### b) Refactoring plan

| ID | Change | Rationale | Expected benefit | Files | Effort | Risk | Breaking? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S1 | ... | ... | ... | ... | S | Low | No |

Execution order: S1 → S2 → ... (dependencies: S3 needs S2)

### c) Risk analysis

| ID | Risk | What could break | Impact (users / dependencies / other tools) | Mitigation | Rollback |
| --- | --- | --- | --- | --- | --- |
| S2 | Medium | ... | ... | ... | revert the step's commit |

Breaking changes: <list, or "none">

### d) Summary

<overall recommendation in two or three sentences; overview of all steps>
```

## Approval question (Phase 3)

Ask with AskUserQuestion, one question per decision:

1. "How do you want to proceed with the <tool-name> proposal?": **Accept all proposed changes**, **Accept selected
   steps only**, **Save as TODO only (no changes)**, **Reject**. AskUserQuestion allows four options; "Request
   changes to the plan" is the free-text "Other" answer, so say so in the question.
2. For "Accept selected steps only": a multi-select of the step IDs and titles (several questions if more than four
   steps), then name any dependency on an unselected step and ask again if needed.
3. If an accepted step is breaking, a separate confirmation naming the step and what breaks.

Record the answer verbatim for the TODO file: `Accepted all`, `Accepted selected steps: S1, S3` or
`Saved as TODO only`.
