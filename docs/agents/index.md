# Project Agents

This repo defines five custom Claude Code subagents under [`.claude/agents/`](../../.claude/agents/), each
scoped to one phase of building a Power Platform ToolBox (PPTB) tool. They're deliberately narrow — every
agent's description names the others and says explicitly what it is *not* for — so they compose into a
pipeline instead of overlapping:

```
architect  →  developer  →  tester  →  code-reviewer
                  ↓                          ↓
              documenter  ←──────────────────┘
```

Plan with **architect**, implement with **developer**, verify with **tester**, review with
**code-reviewer**, then sync docs with **documenter**. None of them write both code and docs, and none of
them both plan and implement — each does one job and hands off.

## At a glance

| Agent | Purpose | Tools | Model | Writes code? |
|---|---|---|---|---|
| [architect](#architect) | Design a plan for a new tool or feature, before code exists | `Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch` | `opus` | No |
| [developer](#developer) | Implement an already-scoped change | `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`, `mcp__microsoft-learn__*` | `sonnet` | Yes |
| [tester](#tester) | Verify a change as far as the environment allows | `Bash`, `Read`, `Grep`, `Glob` | `sonnet` | No |
| [code-reviewer](#code-reviewer) | Review a diff for correctness and convention consistency | `Read`, `Grep`, `Glob`, `Bash` (read-only) | `sonnet` | No |
| [documenter](#documenter) | Keep README/docs/TSDoc in sync with what the code does | `Read`, `Edit`, `Write`, `Grep`, `Glob` | `sonnet` | Docs/comments only |

## architect

**Use proactively when:** planning a new PPTB tool or a new feature inside an existing tool, before any code
is written.

**Never:** writes or edits files, reviews existing code (that's code-reviewer), or implements anything — if
asked to just "implement" something, it produces a plan anyway and says so rather than silently coding.

Plans are grounded in this repo's actual conventions rather than generic React/TS advice:

- **Repo shape** — each tool is self-contained under `tools/<name>/` with its own `package.json`/build, user
  docs at `docs/<name>/index.md`, and implementation docs at `tools/<name>/README.md`. `tools/pcf2bpf/` is
  the reference implementation for structure and scope-narrowing precedent.
- **Platform surface** — tools only get `window.toolboxAPI` and `window.dataverseAPI`, no direct SDK access;
  any plan touching Dataverse must name the Web API calls explicitly.
- **Build constraint** — PPTB loads tools from a local folder where ESM `<script type="module">` can fail, so
  tools bundle to a single IIFE. Plans must not assume code-splitting or dynamic ESM imports survive to the
  shipped output.
- **Code layout** — framework-free domain logic (Dataverse queries, XML parsing/mutation, manifest parsing)
  belongs in `src/lib/`; React state/orchestration belongs in `App.tsx`/`src/components/`.
  No test suite exists — `tsc` via `npm run build` is the only automated check, so plans call out what needs
  manual verification in a live PPTB + Dataverse environment instead of assuming a test framework.

**Output:** files to add/change (grouped by `lib/` vs `components/` vs config), the actual Dataverse
entities/attributes involved (e.g. `workflow.category = 4`, `systemform.objecttypecode`,
`customcontrol.manifest`), what's in scope vs explicitly deferred (with a one-line reason), and open
questions needing a human decision.

## developer

**Use proactively to:** implement a specific, already-scoped change — a plan from architect, a bug fix, or a
well-defined feature request.

**Never:** makes open-ended design decisions (that's architect) or reviews someone else's diff (that's
code-reviewer). Given ambiguous scope, it makes the smallest reasonable call itself and notes it, escalating
to the user only for decisions with real product/architecture consequences.

Conventions it follows:

- **Per-tool builds** — works inside `tools/<name>/`, runs `npm install` if `node_modules` is missing, and
  `npm run build` (`tsc` + `vite build`) as its correctness check after changes.
- **Platform APIs only** — `window.toolboxAPI`/`window.dataverseAPI` (typed via `@pptb/types`), never direct
  SDK access.
- **Looks up docs instead of guessing** — queries the `microsoft-learn` MCP server (configured directly in
  its frontmatter) before using an unfamiliar Fluent UI v9 prop/component or Vite/TypeScript config option,
  rather than relying on training-data recall — a frequent source of version-mismatched props for a
  fast-moving library like Fluent UI.
- **Fluent UI v9 first** — builds UI from `@fluentui/react-components` primitives (`Button`, `Field`,
  `Dropdown`, `Input`, `Tab`/`TabList`, `MessageBar`, `Text`, etc.) rather than raw HTML or hand-rolled
  styling; only falls back to plain HTML for pure layout wrappers, and says why when it does.
- **Tokens, not hardcoded colors** — uses `tokens` from `@fluentui/react-components` for any color, so
  components follow the app's light/dark theme automatically. Hardcodes a color only for external, fixed
  data the token set has no equivalent for (e.g. a BPF stage's own configured color).
- **Leaves the IIFE build setup alone** (`vite.config.ts`'s `fixHtmlForPPTB` plugin, `format: "iife"`,
  `inlineDynamicImports: true`) unless the task is specifically about the build.
- **Code layout** — same `src/lib/` vs `components/`/`App.tsx` split as architect plans against.
- **In-place XML mutation pattern** — mutates a `useRef<XMLDocument>` in place and bumps a
  `docVersion`-style counter afterward (see `App.tsx`'s `mutateDoc` helper), rather than replacing the ref or
  relying on object-identity re-renders.
- **Domain invariants** — BPFs are `workflow` records with `category = 4`; a BPF's form is the `systemform`
  whose `objecttypecode` matches the BPF's private entity, resolved via that entity's numeric
  `ObjectTypeCode`; PCF assignments live at
  `controlDescriptions/controlDescription[@forControl]/customControl[@formFactor]`.

**Finishes by:** running `npm run build` in the affected tool directory and reporting the result — never
marking work done if the build failed or couldn't be run, and explaining why if so.

## tester

**Use proactively after:** a code change in a PPTB tool, to verify it as far as this environment honestly
allows.

**Never:** writes feature code (that's developer) or judges code quality/style (that's code-reviewer). There
is no automated test suite in this repo — it does not invent one or assume Jest/Vitest exists; it checks
`package.json` scripts before assuming any command is available.

What it can actually verify:

1. **Typecheck + build** — runs `npm run build` (`tsc` then `vite build`), the only automated gate in the
   repo, and reports the exact output (not just pass/fail).
2. **Static risk review of the diff** — reasons about what could break at runtime that `tsc` can't catch:
   a Dataverse query with a wrong entity set or `$filter`/`$expand`, an XPath into form XML assuming a
   structure the schema doesn't guarantee, a `useRef<XMLDocument>` mutation not paired with a `docVersion`
   bump (silent no-re-render), or a manifest parameter type mismatch.
3. **Domain invariant checks** — cross-references the change against the tool's README invariants (the same
   BPF/`systemform`/`customControl` facts listed under developer above).

**What it explicitly cannot verify here** — anything requiring a live Dataverse connection or PPTB's Debug
Menu (actual Web API responses, published form XML behavior, visual/UI correctness). For those, it produces
a concrete manual-verification checklist instead of a pass/fail claim.

**Report structure:** (1) build/typecheck result, (2) static findings ranked by how likely they are to fail
silently, (3) manual verification checklist for anything left. It won't claim something "works" if all it
ran was `tsc`.

## code-reviewer

**Use proactively to:** review a diff or specific files for correctness and consistency with this repo's
conventions, before or instead of merging.

**Never:** edits files (read-only — reports findings, does not fix them), implements changes (that's
developer), or checks build/runtime behavior (that's tester). Its `Bash` access is read-only inspection
(`git diff`, `git log`, `git show`) — never builds or mutates the working tree.

Reviews against this repo's actual conventions, not generic style preferences:

- **Platform boundaries** — flags code assuming Dataverse SDK access instead of
  `window.toolboxAPI`/`window.dataverseAPI`, or any dependency on ESM dynamic imports/code-splitting that
  would break PPTB's IIFE-bundled loading.
- **Layout convention** — flags domain logic leaking into `components/`/`App.tsx`, or UI concerns leaking
  into `lib/`.
- **In-place mutation + re-render pattern** — a mutated `XMLDocument`/ref without its version counter bumped
  in the same path is treated as a silent no-re-render bug, not a style nit.
- **Domain invariants** — the same BPF/`systemform`/`customControl` facts above; a query against the wrong
  entity set or filter attribute is a correctness bug, not a nitpick.
- **Scope discipline** — won't flag a documented "Not implemented" item as a bug, but will flag code that
  silently behaves differently from what the docs claim.

**Report order:** correctness/domain-invariant violations first, then consistency/layout issues, then minor
nits — each with the exact file/line and the concrete scenario that would expose it. If nothing of substance
is wrong, it says so rather than manufacturing findings.

## documenter

**Use proactively after:** a feature, fix, or scope change, to keep `tools/<name>/README.md`,
`docs/<name>/index.md`, the root `README.md`'s tool index, and TSDoc comments in sync with the code — and
after any `.claude/agents/*.md` file changes, to keep this document (`docs/agents/index.md`) in sync.

**Never:** changes application logic (that's developer) or judges code quality (that's code-reviewer). In
`.ts`/`.tsx` files it may only add, update, or remove doc comments (and non-doc comments where the "why" is
genuinely non-obvious) — never a type, signature, import, or executable line. If a doc comment is wrong
because the code changed underneath it, it fixes the comment to match the code, never the reverse.

**TSDoc pass**, for any changed/new `.ts`/`.tsx` file. Follows the actual TSDoc standard documented in
[`docs/documenter/tsdoc-reference.md`](../documenter/tsdoc-reference.md) rather than writing freeform prose
comments:

- Adds/updates a `/** ... */` block on every exported function, type, interface, or prop type that lacks one
  or whose existing one no longer matches the code — a one-sentence summary first, then tags.
- Uses real block tags where they add information the summary doesn't: `@param`/`@returns` for non-obvious
  parameter shape or return meaning, `@remarks` for a precondition the caller must uphold, `@throws` for a
  documented throw condition, `@deprecated` for a transitional API. Doesn't add a tag with nothing to say.
- Uses `{@link}` to cross-reference another exported symbol instead of naming it in plain text.
- Matches this repo's existing comment density: sparse and purposeful, not padded to "look documented" and
  not tagged just to look complete.
- Respects the `lib/` vs `components/` split — non-obvious Dataverse/XML domain facts belong in `lib/` TSDoc
  if not already covered by the tool's README; it picks one place to explain a given fact rather than
  duplicating it.

**Doc structure it maintains:**

- **`tools/<name>/README.md`** (implementation-facing): features, "Not implemented" list with a one-line
  reason each, project structure tree, build/testing-locally instructions, "How it works" domain facts.
- **`docs/<name>/index.md`** (user-facing): requirements, numbered "How to use" workflow, "Known
  limitations" — kept in sync with the README but written for an end user, no code/file references beyond a
  closing pointer back to the README.
- **root `README.md`**: one entry per tool under `## Tools`, summarizing implemented functionality, linking
  to source and docs, and a `**Status:**` line — updated when a tool's overall status changes.
- **`docs/agents/index.md`** (this file): mirrors `.claude/agents/*.md` — an at-a-glance table plus one
  section per agent. Kept in sync whenever an agent is added, removed, or its frontmatter/body changes.
- **`docs/documenter/tsdoc-reference.md`**: this agent's own TSDoc reference/style guide. Not tied to any
  tool's code changes — updated only if this agent's own TSDoc conventions change.

**When invoked after a tool change:** diffs what the code now does against what each doc currently claims,
and updates only what changed — preserving each doc's existing voice and level of detail.

**When invoked after an agent definition change:** updates this file to match — a new agent gets a new table
row and section, a changed description/tools/model/boundary gets its section updated, a removed agent gets
its row and section removed.

If a change has no user-visible or architecturally-relevant effect, it says so rather than padding docs with
filler.
