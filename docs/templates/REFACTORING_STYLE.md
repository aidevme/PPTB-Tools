# Refactoring Style Guide

This guide sets the structure and writing rules for refactoring documents: the analysis and plan written before a
tool is refactored. It applies to every file named `refactoring-<tool>-<YYYY-MM-DD>.md`, whether a person or an agent
skill (such as `aidevme-pptb-tool-refactoring`) writes it. For general writing rules, see
[WRITING_STYLE.md](WRITING_STYLE.md).

**A refactoring document is a decision record, not an essay: every finding cites evidence, every step is a checklist
item with files, effort and risk, and nothing in it changes code.**

## File name and location

- Name: `refactoring-<tool-folder-name>-<YYYY-MM-DD>.md`, using the date of the analysis, for example
  `refactoring-dataverse-early-bound-typescript-generator-2026-10-16.md`.
- One document per analysis. A new analysis of the same tool gets a new file with a new date. Don't overwrite an older
  one; link to it from **Related**.
- A revised proposal for the same analysis stays in the same file and raises the **Proposal version** (v1, v2, …).

## Required structure

Every refactoring document follows this structure, in order:

1. H1 title: `# Refactoring: <tool-folder-name> (<YYYY-MM-DD>)`
1. A cspell comment, if the document uses words cspell doesn't know: `<!-- cspell:ignore word1 word2 -->`
1. Metadata table
1. **Related** line (optional), linking to earlier plans and saying how they overlap
1. `## TODO`: the execution order and the checklist of steps
1. `## Analysis`, with a paths note and four subsections:
    1. `### a) Current state`
    1. `### b) Refactoring plan`
    1. `### c) Risk analysis`
    1. `### d) Summary`

Don't add other top-level sections. Material that doesn't fit belongs in a follow-up document.

## Metadata table

A two-column table with empty headers (`| | |`), with these rows in this order:

| Row | Content | Example |
| --- | --- | --- |
| Tool | Tool path in code format, then display name and version in brackets | `` `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) `` |
| Date | Analysis date, `YYYY-MM-DD`; matches the file name | `2026-10-16` |
| Skill | The skill that produced the document, in code format, or `Manual` | `` `aidevme-pptb-tool-refactoring` `` |
| Decision | What the owner decided about the proposal | `Saved as TODO only` |
| Status | Where the work stands now | `Saved as TODO, no changes made` |
| Proposal version | `v<n>, reviewed at commit` + short SHA + `on` + branch | ``v1, reviewed at commit `adcc2d6` on `features/<branch>` `` |

Use these values for **Decision**, so documents can be compared:

- `Approved`: go ahead with all steps.
- `Approved in part: S1–S6`: go ahead with the steps listed.
- `Saved as TODO only`: record the plan, don't start yet.
- `Rejected`: with a one-line reason.

Update **Status** as the work moves, for example `Saved as TODO, no changes made`, `In progress: S1–S3 done`,
`Done`, `Abandoned: <reason>`. Keep the history in the TODO checkboxes, not in the Status row.

## Related line

Start with `Related:` and a relative link to the earlier document. Then say in one sentence which of its items overlap
with this plan, by ID or row number:

```markdown
Related: [the 2026-10-14 refactoring plan](../dataverse-early-bound-typescript-generator-general-reactoring.md)
plans part of S7: its row 1 is the App.tsx split, and its row 4 overlaps S7's dialog move.
```

## TODO section

The TODO is the part people work from, so it comes first.

### Execution order

The first paragraph gives the order as step IDs joined by `→`, followed by the dependencies:

```markdown
Execution order: S1 → S2 → S3 → S4 → S5 → S6 → S12 → S7 → S8 → S9 → S10 → S11 → S13. S7 needs S2 and S3; S11
needs S7.
```

- Put defects first, then cleanups that make the large steps safer, then the large steps, then tests and docs.
- List every dependency as `<step> needs <step(s)>`.

### Step format

One unchecked task per step:

```markdown
- [ ] S<n>: <optional type>: <what changes, in imperative mood> (files: <files>; effort <S|M|L>; risk <Low|Medium|High>)
```

- **ID:** `S1`, `S2`, … numbered in the order found, not the execution order. IDs never change once the document is
  saved. A dropped step keeps its ID and is struck through with a reason, for example `- [ ] ~~S4: …~~ (dropped:
  covered by S7)`.
- **Type:** add a Conventional Commits type when it isn't plain refactoring: `fix:` for defects, `docs:` for
  documentation. Leave it out for refactoring, so `refactor` is the default.
- **What changes:** imperative and specific. Name the functions, hooks, components or settings involved. Several
  related changes in one step are separated by semicolons.
- **Files:** paths relative to the tool's `src/` (see [Paths](#paths)), comma-separated, in code format. Use
  `hooks/*` or `test/*` only for files that don't exist yet. Say "a new helper" for a new file whose name isn't
  decided.
- **Effort:**
  - `S`: one file or a few small edits, done in one sitting;
  - `M`: several files or a new helper, with tests;
  - `L`: a structural change across many files, best done as several commits.
- **Risk:** the same value as in the risk table.
- One step, one reviewable unit of work, and normally one commit; an `L` step may be several commits.
- Mark a step done by ticking the box. Don't delete done steps.

## Analysis section

Start with a paths note:

```markdown
Paths are relative to `tools/<tool>/src/` unless they start with `test/` or the repository root.
```

### Paths

- Write paths relative to the tool's `src/`, `test/`, or the repository root, as the paths note says.
- Write an evidence location as `file:line` or `file:start-end`, and repeat the file only when it changes:
  `metadataProvider.ts:193-196`, `:215-216`.
- Use the file name alone once the folder is clear from the context.

### a) Current state

Use these H4 subsections, in this order. Leave a subsection out only if it doesn't apply, never because nothing was
checked. If something couldn't be checked, say so in one line.

#### Baseline

The state before any change, as a bullet list of commands and their results:

- build: exit code, bundle size raw and gzipped, expected warnings;
- tests: exit code, passed of total, number of files;
- `npm audit`: number of vulnerabilities;
- whether `git status` was unchanged by the build and test run.

#### Structure and architecture

Bullets that compare the code to the repo's documented architecture (AGENTS.md, docs pages). Say what matches as well
as what doesn't: layering, barrels, `any`, `@ts-ignore`, TODO comments, theming and accessibility.

#### Code quality

One table, one finding per row:

| Area | Finding | Evidence |
| --- | --- | --- |
| Bug | What goes wrong and what the user sees | `file:line` |

- **Area** values, in this order of importance: `Bug`, `Fragile dependency list` (or another fragility), `Dead code`,
  `Complexity`, `Duplication`, `Inconsistent labels`, `Typing`, `Error handling`.
- **Finding** states the fact, with a number where there is one ("858 lines, 28 `useState`"), not a judgement
  ("too big").
- **Evidence** is `file:line` locations, or the method (`grep over src/ and test/`) when the finding is an absence.
- A finding that won't be acted on still goes in the table, with the reason it isn't proposed in the Finding cell.

#### Dependencies

One table:

| Package | Current | Latest | Issue | Evidence |
| --- | --- | --- | --- | --- |

- Include wrong or unexplained constraints (`engines`, exact pins) as well as outdated packages.
- Group patch updates in one row.
- Write `—` where a column doesn't apply.
- End with one paragraph: unused dependencies (or "Every dependency is used"), the audit result, and whether major
  upgrades are in this plan.

#### UI/UX consistency

Compare the tool with the other AIDevMe tools. If there is none to compare with, say so and why, then list
inconsistencies within the tool as bullets with evidence.

#### Performance and maintainability

Bullets with measured or countable facts: re-render causes, unvirtualized tables, test-time breakdowns.

#### Test coverage

State whether coverage is configured and give the numbers if it is. Then list the files and components with no direct
tests.

#### Docs and repository drift

Bullets for every place the docs, AGENTS.md, READMEs or repository config disagree with the code, each with its
location.

### b) Refactoring plan

- One line pointing to the checklist: `The steps are the checklist in [TODO](#todo).` Don't repeat the steps.
- Then `Deliberately not proposed (follow-ups):` and a bullet per item, each with the reason:
  `- <item>: <reason>.` Typical reasons: a separate project, risk to generated output, needs live testing, a product
  decision, better after another step.

### c) Risk analysis

One table:

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |

- One row for each step with Medium or High risk.
- Group all Low-risk steps in one `Others` row.
- **What could break** is concrete behaviour, not "regressions".
- **Mitigation** names the tests that must pass, the order constraints, and any manual check (for example a live
  PPTB check: open, Preview, Generate, change a setting).
- **Rollback** is normally `Revert the commit` or `Revert the S<n> commits`.

After the table, a **Breaking changes** paragraph:

- say `Breaking changes: none.` or list them;
- name what stays unchanged (generated output, saved config keys, file formats, build format, reference fixtures);
- list visible but non-breaking changes, such as label casing or package metadata.

### d) Summary

One paragraph of four to six sentences:

1. the overall state, with the main numbers;
1. the real defects and why they go first;
1. the main structural gain;
1. the low-risk cleanups and the test and docs steps;
1. a smaller first pass, as a list of step IDs, for when the full plan is too much.

## Writing rules

- **Evidence over opinion.** Every finding has a location, a command or a count. If it can't be shown, leave it out or
  mark it as unverified.
- **Numbers, not adjectives.** "474 lines and 20 props", not "a large component".
- **Plain, short sentences** in active voice and present tense. Write for the developer who will do the work.
- **Code format** for paths, file names, functions, hooks, settings keys, commands and package names.
- **No changes in the document's own commit.** The document records analysis and decisions; the code changes come
  later, step by step.
- **Stable IDs.** Refer to steps by ID everywhere (`S7`), never by position ("the seventh step").
- **Line length:** wrap prose and list items at about 120 characters; never break a table row or a code span.
- **Spelling:** add unknown technical words to the cspell comment at the top, not to `cspell.json`, unless the word is
  used across the repo.
- **Links:** relative links for repository files, anchors for sections in the same document (`[TODO](#todo)`).

## Template

```markdown
# Refactoring: <tool-folder-name> (<YYYY-MM-DD>)

<!-- cspell:ignore <words> -->

| | |
| --- | --- |
| Tool | `tools/<tool-folder-name>` (<Display Name>, <version>) |
| Date | <YYYY-MM-DD> |
| Skill | `<skill-name>` |
| Decision | <Approved / Approved in part: S… / Saved as TODO only / Rejected: reason> |
| Status | <current status> |
| Proposal version | v1, reviewed at commit `<sha>` on `<branch>` |

Related: [<earlier plan>](<relative-path>) <how it overlaps>.

## TODO

Execution order: S1 → S2 → …. <Sx> needs <Sy>.

- [ ] S1: fix: <what changes> (files: `<file>`; effort S; risk Medium)
- [ ] S2: <what changes> (files: `<file>`; effort M; risk Low)

## Analysis

Paths are relative to `tools/<tool-folder-name>/src/` unless they start with `test/` or the repository root.

### a) Current state

#### Baseline

- `npm run build`: exit <n>; <bundle size raw> (<gzipped> gzipped).
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
```

## Review checklist

- [ ] The file name, H1 and **Date** row use the same date.
- [ ] The metadata table has all six rows in order, and **Proposal version** names a commit and branch.
- [ ] The execution order lists every step ID once, and every dependency is stated.
- [ ] Every step has an ID, files, effort and risk; defects carry `fix:`.
- [ ] Every Code quality, Dependencies and Docs drift finding has evidence.
- [ ] The Baseline gives exit codes and counts for build, tests and audit.
- [ ] Every Medium or High step has its own risk row; Low steps are grouped under `Others`.
- [ ] The Breaking changes paragraph says what stays unchanged.
- [ ] The Summary names a smaller first pass by step IDs.
- [ ] `npm run lint:md` passes and cspell reports no unknown words.
