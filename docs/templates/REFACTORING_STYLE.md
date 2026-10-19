# Refactoring Style Guide

This guide sets the structure and writing rules for refactoring documents in this repository: the analysis, plan,
decision and execution record for refactoring one tool under `tools/`. It applies to every
`docs/todos/<tool-name>/refactoring-<tool-name>-<YYYY-MM-DD>.md` file, whether a person writes it or the
`aidevme-pptb-tool-refactoring` skill does. For general writing rules, see [WRITING_STYLE.md](WRITING_STYLE.md).

**A refactoring document is a decision record, not an essay: every finding cites evidence, every step is a checklist
item with files, effort and risk, the decision and the commits are recorded in it, and it's written before any code
changes.**

The skill's templates (`.claude/skills/aidevme-pptb-tool-refactoring/references/todo-template.md` and
`proposal-template.md`) follow this guide. If the two disagree, update the template to match this guide.

## File name and location

- Folder: `docs/todos/<tool-name>/`, one folder per tool, named after the folder under `tools/`. Create it if it
  doesn't exist.
- Name: `refactoring-<tool-name>-<YYYY-MM-DD>.md`, using the date of the run, for example
  `docs/todos/dataverse-early-bound-typescript-generator/refactoring-dataverse-early-bound-typescript-generator-2026-10-16.md`.
- A second run on the same day adds `-02`, `-03`, … before `.md`:
  `refactoring-<tool-name>-<YYYY-MM-DD>-02.md`.
- **Never overwrite or edit an older document.** Each run creates a new file and only that file is edited later (for
  the execution record). To continue earlier work, link to the earlier file (see [Follows line](#follows-line)).
- Don't update indexes or other files in `docs/todos/` when you add a document.

## Lifecycle

A document is written in two moments:

1. **Before any change:** the header, the TODO with the decision on each step, and the analysis. The file exists
   before the first code change, even when the decision is "Saved as TODO only".
1. **After execution:** the header's status, branch and commits, ticked TODO items, an `## Execution report` and
   `## Follow-up TODOs`. Nothing above the execution report is rewritten, apart from those fields.

The document isn't part of a step's commit. Commit it on its own (for example `docs(todos): …`), after execution or
when it's saved as a TODO.

## Required structure

In this order:

1. H1: `# Refactoring: <tool-name> (<YYYY-MM-DD>)`
1. A cspell comment, if the document uses words cspell doesn't know: `<!-- cspell:ignore word1 word2 -->`
1. Metadata table
1. **Follows** or **Related** line (optional)
1. `## TODO`: execution order and the steps
1. `## Analysis`: a paths note, then `### a) Current state`, `### b) Refactoring plan`, `### c) Risk analysis`,
   `### d) Summary` (see [Full and focused analyses](#full-and-focused-analyses))
1. `## Execution report` (after execution only)
1. `## Follow-up TODOs` (after execution only)

Don't add other top-level sections.

## Metadata table

A two-column table with empty headers (`| | |`), with these rows in this order. Leave out a row that doesn't apply yet;
never leave a value empty.

| Row | When | Content | Example |
| --- | --- | --- | --- |
| Tool | Always | Tool path in code format, then display name and version in brackets | `` `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) `` |
| Date | Always | Run date, `YYYY-MM-DD`; matches the file name | `2026-10-17` |
| Skill | Always | The skill that ran, in code format, or `Manual` | `` `aidevme-pptb-tool-refactoring` `` |
| Scope | Focused runs only | The part of the tool analysed | ``The card components in `src/components/cards/` `` |
| Decision | Always | The owner's decision, recorded verbatim (see below) | `Accepted selected steps: S2, S3, S4, S5` |
| Status | Always | Where the work stands (see below) | `Executed` |
| Branch | After execution | Branch in code format, and whether it's pushed | `` `features/<branch>` (not pushed) `` |
| Commits | After execution | First and last short SHA, and the count | `` `2e6bbfd`..`af441ed` (9 commits) `` |
| Proposal version | Always | `v<n>`, what changed from the previous version if any, the reviewed commit and branch | ``v2 (v1 without S1), reviewed at commit `7e5bd05` on `features/<branch>` `` |

**Decision** values (as the skill's approval question records them):

- `Accepted all`, optionally with the choice made on an open question in brackets:
  `Accepted all (C2: delete the hidden history menu)`;
- `Accepted selected steps: S1, S3`;
- `Saved as TODO only`.

A rejected proposal isn't saved, so there's no `Rejected` value.

**Status** values:

- `Saved as TODO, no changes made`: after "Saved as TODO only";
- `Planned`: accepted, execution not started;
- `Executed`: every accepted step completed;
- `Partially executed`: at least one accepted step was skipped or failed.

If your own commits sit between the run's commits, say so in **Commits**:
`` `b948df6`..`9d0ebef` (with two of your own commits in between: `0988e06`, `287a4a3`) ``.

Older documents use one `Branch and commits` row; new documents use the separate **Branch** and **Commits** rows.

## Follows line

When a run continues earlier work, add one line under the table with a relative link to the previous document in the
same folder:

```markdown
Follows [refactoring-dataverse-early-bound-typescript-generator-2026-10-17-02.md](./refactoring-dataverse-early-bound-typescript-generator-2026-10-17-02.md).
```

To point to an older plan that isn't a refactoring document (for example one directly in `docs/todos/`), use
`Related:` and say in one sentence which of its items overlap with this plan:

```markdown
Related: [the 2026-10-14 refactoring plan](../dataverse-early-bound-typescript-generator-general-reactoring.md)
plans part of S7: its row 1 is the App.tsx split, and its row 4 overlaps S7's dialog move.
```

## TODO section

The TODO is the part people work from, so it comes first.

### Execution order

The first line gives the order as step IDs joined by `→`, then the dependencies:

```markdown
Execution order: S1 → S2 → S3 → S4 → S5 → S6 → S12 → S7 → S8 → S9 → S10 → S11 → S13. S7 needs S2 and S3; S11
needs S7.
```

- Put defects first, then tests that protect the next steps, then cleanups that make the large steps safer, then the
  large steps, then docs.
- State every dependency as `<step> needs <step(s)>`.

### Step IDs

- A full analysis uses `S1`, `S2`, …
- A focused run uses one capital letter for its scope, for example `C1` for cards, `L1` for layout, `D1` for docs.
  Name the prefix's meaning in the **Scope** row.
- IDs are numbered in the order the findings were made, not in execution order, and never change once the document
  is saved. A revised proposal keeps the existing IDs and adds new ones.
- A step dropped before the decision keeps its ID and is struck through with a reason:
  `- [ ] ~~S4: …~~ (dropped: covered by S7)`.

### Step format

Before execution:

```markdown
- [ ] S<n>: <optional type>: <what changes, in imperative mood> (files: <files>; effort <S|M|L>; risk <Low|Medium|High>). <Approved|Not approved>
```

After execution, tick completed steps and put the commit SHAs in brackets after the ID:

```markdown
- [x] C7 (`389756d`, `af441ed`): group the wide props of SelectionCard and PreviewCard into objects (files: 2 cards, App, tests, docs; effort M; risk Medium). Approved
```

- **Type:** add a Conventional Commits type when the step isn't plain refactoring: `fix:` for defects, `docs:` for
  documentation, `test:` for test-only steps. Leave it out for refactoring.
- **What changes:** imperative and specific. Name the functions, hooks, components, props or settings. Separate
  related changes in one step with semicolons.
- **Files:** paths relative to the paths note (see [Paths](#paths)), in code format, comma-separated. Short forms are
  fine once the files are clear: `2 cards, App, tests, docs`, `new test`, `a new helper`.
- **Effort:**
  - `S`: one file or a few small edits;
  - `M`: several files or a new helper, with tests;
  - `L`: a structural change across many files, done as several commits.
- **Risk:** `Low`, `Medium` or `High`, the same as in the risk table. Add `, visible` when users will see the change
  (a label, a layout, a focus ring): `risk Low, visible`.
- **Decision note:** `Approved` or `Not approved` after the closing bracket. After "Saved as TODO only", leave the
  note out: every step is open work.
- **Execution notes** follow the decision note, in one or two clauses:
  - a change made with approval: `Approved. Changed during execution, with approval, to fail Preview with an error`;
  - a skipped step stays unticked: `Not approved`;
  - a failed step stays unticked with the reason: `Approved. Failed: build error in App.tsx, reverted`.
- One step is one reviewable unit of work and normally one commit; an `L` or `Medium` step may be several commits.
- Never delete a step.

## Analysis section

### Paths

Start the section with a paths note, matching the scope:

```markdown
Paths are relative to `tools/<tool-name>/src/` unless they start with `test/` or the repository root.
```

- A focused run may set the root to its scope folder, for example `tools/<tool-name>/src/components/`.
- Write evidence as `file:line` or `file:start-end`, and repeat the file only when it changes:
  `metadataProvider.ts:193-196`, `:215-216`.

### Full and focused analyses

- **Full analysis** (no **Scope** row): all four subsections, `a)` to `d)`, with every `a)` subsection below.
- **Focused analysis** (a **Scope** row): at least `a) Current state` and `c) Risk analysis`; `b)` and `d)` only if
  they add something. `a)` may be one table of the files in scope (`| File | Lines | Notes |`) plus the findings that
  matter, a one-line baseline and the Microsoft Learn line.

### a) Current state

For a full analysis, use these H4 subsections in this order. Leave one out only if it doesn't apply, never because it
wasn't checked; if something couldn't be checked, say so in one line.

#### Baseline

The state before any change, as a list of commands and results:

- `npm run build`: exit code, bundle size raw and gzipped, expected warnings;
- `npm test`: exit code, passed of total, number of files;
- `npm audit`: number of vulnerabilities;
- whether `git status` was unchanged by the build and test run.

A focused run that follows a recent one may use one line instead:
`Baseline: no tool code change since c098e53, where npm run build passed and npm test passed 245 tests in 21 files.`

#### Structure and architecture

Bullets that compare the code with the tool's AGENTS.md and architecture docs: layering, barrels, `any`,
`@ts-ignore`, TODO comments, Fluent UI tokens and theming, accessible names. Say what matches as well as what doesn't.

#### Code quality

One table, one finding per row:

| Area | Finding | Evidence |
| --- | --- | --- |
| Bug | What goes wrong and what the user sees | `file:line` |

- **Area** values, roughly in order of importance: `Bug`, `Fragile dependency list` (or another fragility), `Dead
  code`, `Complexity`, `Duplication`, `Inconsistent labels`, `Naming`, `Typing`, `Error handling`.
- **Finding** states the fact with a number where there is one ("858 lines, 28 `useState`"), never a judgement
  ("too big").
- **Evidence** is `file:line`, or the method (`grep over src/ and test/`) when the finding is an absence.
- A finding that won't be acted on stays in the table, with the reason in the Finding cell.

#### Dependencies

| Package | Current | Latest | Issue | Evidence |
| --- | --- | --- | --- | --- |

- Include wrong or unexplained constraints (`engines`, exact pins) as well as outdated packages.
- Group patch updates in one row; write `—` where a column doesn't apply.
- End with one paragraph: unused dependencies (or "Every dependency is used"), the `npm audit` result, and whether
  major upgrades are in this plan.

#### UI/UX consistency

Compare with the other AIDevMe tools in `tools/`, naming the files compared. If there is none to compare with, say so
and why, then list inconsistencies within the tool as bullets with evidence.

#### Performance and maintainability

Bullets with measured or countable facts: re-render causes, unvirtualized tables, test-time breakdowns.

#### Test coverage

Whether coverage is configured, with numbers only if measured. Then the files and components without direct tests.

#### Docs and repository drift

Bullets for every place the docs, AGENTS.md, READMEs or repository config (`.gitattributes`, `package.json`)
disagree with the code, each with its location.

#### Microsoft Learn references

The Microsoft Learn pages (found through the Microsoft Learn MCP Server) that findings or steps rely on, one line each
with the finding or step that uses it. If none is needed, one line with the reason:
`Microsoft Learn references: not needed; nothing depends on Microsoft platform behavior.`

### b) Refactoring plan

- One line pointing to the checklist: `The steps are the checklist in [TODO](#todo).` Don't repeat the steps.
- Then `Deliberately not proposed (follow-ups):` and one bullet per item with its reason: `- <item>: <reason>.`
  Typical reasons: a separate project (major upgrades), risk to generated output, needs live PPTB testing, a product
  decision, better after another step.

### c) Risk analysis

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |

- A row for each Medium or High step. Low steps are either grouped in one `Others` row (long plans) or listed in a few
  rows sharing IDs, for example `C3, C4` (short plans).
- **What could break** is concrete behaviour (hook ordering, row order, test fixtures), never "regressions".
- **Mitigation** names the tests that must pass, the order constraint, and any manual check, for example "live check
  in PPTB: open, Preview, Generate, change a setting" or "check light and dark themes in PPTB".
- **Rollback** is normally `Revert the commit` or `Revert the commits`; a test-only step may be `Delete the test`.

After the table, a **Breaking changes** paragraph:

- `Breaking changes: none.` or the list;
- what stays unchanged: generated output, `.dataverse-gen.json`, saved tool-config keys, the manifest, the IIFE
  build, `test/reference`;
- visible but non-breaking changes, by step ID.

### d) Summary

One paragraph of four to six sentences:

1. the overall state, with the main numbers;
1. the real defects and why they go first;
1. the main structural gain;
1. the low-risk cleanups, tests and docs steps;
1. a smaller first pass as a list of step IDs, for when the full plan is too much.

## Execution report

Added after execution, directly after the analysis. Open with one or two sentences: how many approved steps ran, in
which order, which were skipped or failed, and how each was verified (for example: "verified from the tool folder
with `npm run build` and `npm test`, then committed").

### Steps

One row per step, or per commit when a step has several:

```markdown
| ID | Step | Result | Commit | Notes |
| --- | --- | --- | --- | --- |
| S1 | Stop caching failed custom API reads | Completed | `7e5bd05` | Scope changed, with approval |
| S2–S13 | See [TODO](#todo) | Skipped (not approved) | | |
```

- **Result:** `Completed`, `Skipped (not approved)` or `Failed (reverted)`.
- Group a run of skipped steps in one row.
- Under the table, add `<ID> as built:` bullets when the result differs from the plan or needs explaining.

### Files changed

The `git diff --stat` output for the run's commits, in a `text` code block, or one line for a long list:
`Files changed since eccded8: 30 files, 768 insertions, 414 deletions.`

### Verification

| Step | Command | Exit code | Result |
| --- | --- | --- | --- |
| S1 | `npm run build` | 0 | OK |
| S1 | `npm test` | 0 | 206 passed in 17 files (203 before, plus 3 new tests) |

- Record failures too, and say whether they existed before the step: `One MD040 finding at line 96, already in the
  committed file before S1`.
- Include `npm run docs:build` and Markdown validation when docs changed.

Then, as short paragraphs or lists:

- **Deviations from the plan:** what was done differently and why, by step ID (an extra docs page, an amended commit,
  an `aria-label` instead of a visible label).
- **Not verified:** what wasn't checked and which steps it matters for, for example "a live PPTB host, light and dark
  themes; that matters most for C5 and C7".
- **Microsoft Learn pages used:** the URLs the fixes relied on, or "none" with the reason.

## Follow-up TODOs

Last section, an unchecked list of next actions, most important first:

- live checks that weren't done ("Test live in PPTB, light and dark themes: …", then record the results in
  `contributing/testing.md`);
- issues found during execution and left out of scope;
- cleanups planned for later (removing deprecated aliases in a later major version);
- decisions still open ("Decide on the remaining steps S2–S13; S2 is recommended next");
- pushing the branch, if it isn't pushed: "Push the branch when ready (needs your confirmation)".

Skipped and failed steps stay open in `## TODO`; don't repeat them here except as a decision. If nothing remains,
write one item: `- [ ] Re-run the analysis after the next feature change`.

## Writing rules

- **Evidence over opinion.** Every finding has a location, a command or a count. If it can't be shown, leave it out or
  mark it as unverified.
- **Numbers, not adjectives.** "474 lines and 20 props", not "a large component"; "19 to 14 props", not "simpler".
- **Plain, short sentences** in active voice and present tense; past tense only in the execution report. Write for
  the developer who will do or review the work.
- **Code format** for paths, file names, functions, hooks, props, settings keys, commands, package names and SHAs.
- **Stable IDs.** Refer to steps by ID everywhere (`S7`, `C5`), never by position.
- **Record decisions verbatim.** The Decision row and the `Approved` / `Not approved` notes are what was agreed;
  changes during execution are recorded as such, with "with approval".
- **Line length:** wrap prose and list items at about 120 characters; never break a table row, a link or a code span.
- **Spelling:** put one-off technical words in the cspell comment at the top, not in `cspell.json`, unless the word is
  used across the repo.
- **Links:** relative links to repository files (`./` for documents in the same folder), anchors for sections in the
  same document (`[TODO](#todo)`).

## Template

```markdown
# Refactoring: <tool-name> (<YYYY-MM-DD>)

<!-- cspell:ignore <words> -->

| | |
| --- | --- |
| Tool | `tools/<tool-name>` (<displayName>, <version>) |
| Date | <YYYY-MM-DD> |
| Skill | `aidevme-pptb-tool-refactoring` |
| Scope | <focused runs only> |
| Decision | <Accepted all / Accepted selected steps: S1, S3 / Saved as TODO only> |
| Status | <Saved as TODO, no changes made / Planned / Executed / Partially executed> |
| Branch | `<branch>` (<pushed / not pushed>) |
| Commits | `<first>`..`<last>` (<n> commits) |
| Proposal version | v1, reviewed at commit `<sha>` on `<branch>` |

Follows [<previous file>](./<previous file>).

## TODO

Execution order: S1 → S2 → …. <Sx> needs <Sy>.

- [ ] S1: fix: <what changes> (files: `<file>`; effort S; risk Medium). Approved
- [ ] S2: <what changes> (files: `<file>`; effort M; risk Low). Not approved

## Analysis

Paths are relative to `tools/<tool-name>/src/` unless they start with `test/` or the repository root.

### a) Current state

#### Baseline

- `npm run build`: exit <n>; <raw size> (<gzipped> gzipped).
- `npm test`: exit <n>; <passed> of <total> tests passed in <files> files.
- `npm audit`: <n> vulnerabilities.
- `git status` was the same before and after the build and test run.

#### Structure and architecture

- <what matches the documented architecture>
- <what doesn't>

#### Code quality

| Area | Finding | Evidence |
| --- | --- | --- |
| Bug | <finding> | `<file>:<line>` |

#### Dependencies

| Package | Current | Latest | Issue | Evidence |
| --- | --- | --- | --- | --- |
| `<package>` | <current> | <latest> | <issue> | `npm outdated` |

<Unused dependencies, audit result, whether major upgrades are in scope.>

#### UI/UX consistency

- <finding with evidence>

#### Performance and maintainability

- <measured fact>

#### Test coverage

<Coverage configured or not; files without direct tests.>

#### Docs and repository drift

- <drift with location>

#### Microsoft Learn references

- <URL>: <finding or step that uses it>

### b) Refactoring plan

The steps are the checklist in [TODO](#todo).

Deliberately not proposed (follow-ups):

- <item>: <reason>.

### c) Risk analysis

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |
| S1 | Medium | <behaviour> | <tests, order, manual check> | Revert the commit |
| Others | Low | <behaviour> | <mitigation> | Revert the commit |

Breaking changes: <none / list>. <What stays unchanged.> <Visible non-breaking changes.>

### d) Summary

<Four to six sentences: state, defects first, main gain, cleanups, smaller first pass.>

## Execution report

<How many steps ran, in which order, how each was verified.>

### Steps

| ID | Step | Result | Commit | Notes |
| --- | --- | --- | --- | --- |
| S1 | <step> | Completed | `<sha>` | |

### Files changed

<git diff --stat, or one summary line>

### Verification

| Step | Command | Exit code | Result |
| --- | --- | --- | --- |
| S1 | `npm run build` | 0 | OK |

Deviations from the plan: <by step ID, or "none">.

Not verified: <what, and which steps it matters for>.

Microsoft Learn pages used: <URLs, or "none" with the reason>.

## Follow-up TODOs

- [ ] <next action>
```

## Review checklist

- [ ] The file is in `docs/todos/<tool-name>/`, is new (no older document was changed), and its name, H1 and **Date**
  row use the same date.
- [ ] The metadata rows are in order; **Decision** and **Status** use the listed values; **Proposal version** names a
  commit and branch.
- [ ] The execution order lists every step ID once, and every dependency is stated.
- [ ] Every step has an ID, files, effort and risk, and a decision note unless saved as TODO only; defects carry
  `fix:`.
- [ ] Every Code quality, Dependencies and Docs drift finding has evidence; the Microsoft Learn line is present.
- [ ] A full analysis has a Baseline with exit codes and counts for build, tests and audit.
- [ ] Every Medium or High step has its own risk row, and the Breaking changes paragraph says what stays unchanged.
- [ ] After execution: **Status**, **Branch** and **Commits** are filled in, completed steps are ticked with their
  SHAs, and the execution report has Steps, Files changed, Verification, Not verified and Microsoft Learn lines.
- [ ] `## Follow-up TODOs` ends the document and includes the push step if the branch isn't pushed.
- [ ] `npm run lint:md` passes and cspell reports no unknown words.
