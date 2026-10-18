---
name: aidevme-pptb-tool-developer
metadata:
  layer: atomic
  scope: project
description: |
  Standardize styling in PPTB tools under tools/: move Fluent UI makeStyles hooks defined inside React component
  files into src/styles/ as one ComponentName.styles.ts file per component, exporting useComponentNameStyles from
  the src/styles/index.ts barrel. A read-only analysis and an approval gate come before any change; styling
  questions are checked in Microsoft Learn through the Microsoft Learn MCP Server. Use when:
  (1) User says "extract the styles", "move useStyles out of the components", "standardize the styles" or
      "create .styles.ts files" for a PPTB tool
  (2) A tool's .tsx components define makeStyles hooks inline
  (3) User wants to know which components still define their own useStyles
  Does NOT change style values or behavior, process tools the user didn't select, overwrite a style file without
  confirmation, or change files before approval. Does NOT build, debug or publish tools (pptb-tool-dev) or do
  general refactoring (aidevme-pptb-tool-refactoring).
allowed-tools: Bash, PowerShell, Read, Grep, Glob, Edit, Write, AskUserQuestion, mcp__microsoft-learn__microsoft_docs_search, mcp__microsoft-learn__microsoft_docs_fetch, mcp__microsoft-learn__microsoft_code_sample_search
argument-hint: "[tool-name ... | all]"
---

# aidevme-pptb-tool-developer

<!-- cspell:ignore makeStyles Griffel -->

Moves inline Fluent UI `makeStyles` hooks out of component files into one style file per component. Six phases.
Phases 1–3 change nothing; Phase 4 runs only after explicit approval. It's a purely structural refactor: style
values and behavior stay exactly as they are.

## Naming convention

| What | Pattern | Example (`App`) |
| --- | --- | --- |
| Hook | `use<ComponentName>Styles` | `useAppStyles` |
| File | `src/styles/<ComponentName>.styles.ts` | `src/styles/App.styles.ts` |
| Barrel | `src/styles/index.ts` exports every style file | `export { useAppStyles } from './App.styles';` |

`<ComponentName>` is the name of the component the hook serves (its exported function), in PascalCase, which
normally matches the `.tsx` file name.

## Microsoft Learn MCP Server

Styling questions are answered from Microsoft's documentation through the
[Microsoft Learn MCP Server](https://learn.microsoft.com/en-us/training/support/mcp), never from memory. It's a
public, remote MCP server (streamable HTTP, no authentication) at `https://learn.microsoft.com/api/mcp`, with
three tools:

| Tool | Use it for |
| --- | --- |
| `microsoft_docs_search` | Finding the relevant Learn content first, for example "Fluent UI React v9 makeStyles tokens" |
| `microsoft_docs_fetch` | Reading a whole page that search found, when an excerpt isn't enough |
| `microsoft_code_sample_search` | Official code samples, for example how `makeStyles` and `tokens` are imported and used |

Each client prefixes the tool names with the server's configured name (in Claude Code, for example,
`mcp__microsoft-learn__microsoft_docs_search`); use whichever server in the session exposes these three tools. If
none does, tell the user how to add it, and don't add it yourself:

- **Claude Code:** `claude mcp add --transport http microsoft-learn https://learn.microsoft.com/api/mcp`
- **VS Code / GitHub Copilot** (`.vscode/mcp.json`, under `servers`):
  `"microsoft.docs.mcp": { "type": "http", "url": "https://learn.microsoft.com/api/mcp" }`

**How the skill uses it:**

- **Ground every styling decision** in Phases 2, 3 and 5: questions about `makeStyles`, `tokens`,
  `shorthands`, `mergeClasses`, Griffel, `FluentProvider` or theming. Search first, fetch the page when needed,
  and cite the Learn URL next to the finding or the proposed resolution.
- **Report, don't apply:** where Learn guidance shows a style could be better (for example a hard-coded color
  instead of a token, which breaks the dark theme), list it as a follow-up in the report. This skill never changes
  a style value.
- **Read-only:** the tools only read public documentation; they never touch the workspace.
- **When the server isn't available,** say so, mark the question "Microsoft Learn not checked", and carry on with
  the structural refactor; never present unverified API details as fact. Learn doesn't cover PPTB's own APIs; use
  the `pptb-tool-dev` skill for those.

## Phase 1 — Selection

1. **Discover the tools:** every `tools/<name>/` folder with a `package.json`. A folder without one isn't a tool;
   mention it but don't offer it.
2. **Ask which tools to process** (AskUserQuestion, multi-select, plus an "All tools" option). Tool names passed
   as arguments count as the answer; confirm any that don't match a discovered tool.
3. Only the selected tools are read for analysis and changed; never touch another tool.

## Phase 2 — Analysis (read-only)

**No file may be created or modified in this phase.** For each selected tool:

1. **Scan** every `*.tsx` file under `src/` for a hook defined in the file with `makeStyles`, for example
   `const useStyles = makeStyles({...})`. Search for `makeStyles(` rather than only the name `useStyles`, so
   differently named inline hooks are found too.
2. **Record, per match:**
   - the component file and the component name;
   - the proposed hook name and target file, from the naming convention;
   - what the style object depends on: `makeStyles`, `tokens`, `shorthands`, `mergeClasses` or other Fluent
     imports, and any constants or helpers defined in the component file or imported from elsewhere;
   - every call site of the hook in that file.
3. **Flag edge cases** that need a decision, without resolving them yourself:
   - a file with several components or several style hooks (which name goes with which file?);
   - a target style file that already exists;
   - a hook name that collides with an existing export in `src/styles/` or elsewhere in the tool;
   - styles that use values defined in the component file (they must move with the styles, be exported, or be
     passed in; propose the smallest option);
   - an inline hook that isn't named `useStyles`;
   - a hook used outside its own file.

   For each edge case that involves a Fluent UI styling API, look up the guidance with the Microsoft Learn MCP
   Server (see above) and note the URL with the proposed resolution.
4. **Skip** components whose styles already follow the convention (they import `use<ComponentName>Styles` from the
   styles barrel and define no `makeStyles` hook themselves). List them with the reason.
5. **Note the barrel's conventions** if `src/styles/index.ts` exists: its export style (named exports such as
   `export { useAppStyles } from './App.styles';`, or `export * from './App.styles';`) and its order. New
   entries follow the existing style. A new barrel uses `export * from './<ComponentName>.styles';`.
6. **Note the tool's checks:** its `build`, `test` and `lint` scripts in `package.json`, and whether a formatter
   is configured (a `format` script, Prettier or ESLint config). Say "not configured" when there is none.

## Phase 3 — Approval

Present, per tool:

- a table: component file → new hook → new style file, with the dependencies that move;
- the skipped components, each with its reason;
- the flagged edge cases, each with a proposed resolution and the Microsoft Learn page it's based on (or
  "Microsoft Learn not checked").

Then ask (AskUserQuestion): **Accept all**, **Accept selected components** (then a multi-select of the
components), or **Cancel**. Ask separately about each edge case that needs a decision, including every existing
style file that would be overwritten. **Never modify a file without an accept answer**, and never overwrite an
existing style file without its own explicit confirmation. Cancel ends the skill with nothing changed.

## Phase 4 — Refactoring (only after approval)

Before the first change, check `git status` for the tool's folder; if it has uncommitted changes, say so and ask
whether to continue. Then, for each approved component:

1. **Create** `src/styles/<ComponentName>.styles.ts` with the style definition unchanged, renamed to
   `use<ComponentName>Styles`, as a named export, with every import it needs (Fluent imports, and constants it
   uses, moved or imported as agreed in Phase 3). Add a one-line TSDoc comment when the tool's style files have
   one.
2. **Remove** the original hook definition from the component file.
3. **Replace** every call of the old hook in that file with `use<ComponentName>Styles()`.
4. **Import** the hook from the styles barrel with the right relative path, for example
   `import { useAppStyles } from '../styles';` from `src/`, or `'../../styles'` from `src/components/apps/`.
5. **Remove** imports the component no longer uses (for example `makeStyles`, `tokens`, `shorthands`), keeping
   any still used elsewhere in the file.
6. **Update the barrel:** create `src/styles/index.ts` if it doesn't exist, and add one export per new file in
   the barrel's export style, in alphabetical order, without duplicating an existing entry.

Run the project's formatter on the changed files only if one is configured; otherwise match the surrounding
formatting by hand. Don't change style values, class names, selectors or the order of style rules.

## Phase 5 — Verification

From each processed tool's folder:

1. `npm run build` (the TypeScript check and the bundle).
2. `npm test` when the tool defines it, since component tests render the styles.
3. The lint script, only if configured.

Record each command, its exit code and test counts. **If anything fails, stop**: report the errors with the
affected files and the likely cause (for an error about a Fluent UI styling API, check it with the Microsoft Learn
MCP Server and cite the page), and ask whether to fix forward, undo the component's change, or stop. Don't
change tests or style values to make a check pass.

## Phase 6 — Report

Per tool:

- components refactored (component → hook → file);
- files created and files modified;
- components skipped, with the reason (already following the convention, not approved, edge case left open);
- build, test and lint results with exit codes, or "not configured";
- what wasn't verified, for example the look in light and dark themes inside PPTB;
- follow-ups from the Microsoft Learn guidance (styles that could improve, never changed by this skill), with
  their URLs.

Don't commit unless the user asks; if asked, use Conventional Commits from `CONTRIBUTING.md`, for example
`refactor(<tool-name>): move component styles to src/styles`.

## Rules

- **Read-only until approved;** only selected tools, only approved components.
- **Pure structure:** no style values, class names or behavior change.
- **Never overwrite** an existing style file without explicit confirmation.
- **Stop on errors** and ask; report only checks that actually ran.
- **Ground styling answers in Microsoft Learn** through its MCP Server and cite them; never invent API details.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-16 | aidevme | Created: tool selection, read-only analysis of inline makeStyles hooks with edge-case flags, approval gate, extraction to src/styles/<ComponentName>.styles.ts with the barrel, build/test/lint verification, report. |
| 2026-10-16 | aidevme | Styling questions are answered from Microsoft Learn through the Microsoft Learn MCP Server (search, fetch, code samples), cited in the proposal and the report; Learn-based improvements are reported as follow-ups, never applied. |
