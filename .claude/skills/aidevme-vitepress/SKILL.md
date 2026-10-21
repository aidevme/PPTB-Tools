---
name: aidevme-vitepress
metadata:
  layer: atomic
  scope: core
description: |
  Work on a VitePress documentation site: write and move pages, change the sidebar, nav and site config, and fix
  build errors and dead links, with VitePress questions answered from the official VitePress docs through the
  Vue Docs MCP server (vue-mcp.org). Use when:
  (1) User asks to add, move or restructure docs pages, or change the VitePress sidebar, nav or config
  (2) `vitepress build` / `docs:build` fails (Vue template errors in Markdown, dead links) or a page renders wrong
  (3) User asks how something works in VitePress (config options, frontmatter, theme, data loaders, deploy)
  (4) User wants the Vue Docs MCP server set up for Claude Code or VS Code Copilot
  Does NOT deploy, push or change CI workflows without being asked, add MCP configuration to the repository or the
  user's settings without asking, or answer VitePress API questions from memory when the docs can be checked.
allowed-tools: Bash, PowerShell, Read, Grep, Glob, Edit, Write, AskUserQuestion, mcp__vue-docs__vitepress_docs_search, mcp__vue-docs__vitepress_api_lookup, mcp__vue-docs__vitepress_get_related, mcp__vue-docs__set_framework_preferences
argument-hint: "[task, e.g. 'nest the component pages in the sidebar' or 'fix docs:build']"
---

# aidevme-vitepress

<!-- cspell:ignore vitepress srcExclude pre -->

Changes to a VitePress site, checked against the official VitePress documentation through the
[Vue Docs MCP server](https://vue-mcp.org/frameworks/vitepress), and verified with a build.

## Vue Docs MCP server

A hosted MCP server with the official docs of the Vue ecosystem (VitePress, Vue, Vite and others), refreshed every
24 hours. Free, no API key: `https://mcp.vue-mcp.org/mcp`, streamable HTTP.

### Set it up

Check first whether the session already has the tools (`vitepress_docs_search` and the others below, prefixed by the
server name your client uses). If not, tell the user how to add it; don't change their settings or the repository's
MCP files yourself unless they ask.

- **Claude Code** ([guide](https://vue-mcp.org/clients/claude-code)):

  ```bash
  claude mcp add --scope user vue-docs --transport streamable-http https://mcp.vue-mcp.org/mcp
  claude mcp list      # vue-docs should be listed
  ```

  `--scope user` makes it available in every project; `--scope project` only in the current one. Claude Code's own
  name for this transport is `http`: if the CLI rejects `streamable-http`, use `--transport http` with the same URL.
  Remove it with `claude mcp remove vue-docs`.
- **VS Code with GitHub Copilot** ([guide](https://vue-mcp.org/clients/vscode)): in `.vscode/mcp.json` (VS Code uses
  `servers`, not `mcpServers`, and needs `type`), save, then open Copilot Chat; the Vue Docs tools appear in the tools
  list.

  ```json
  {
    "servers": {
      "vue-docs": {
        "type": "http",
        "url": "https://mcp.vue-mcp.org/mcp"
      }
    }
  }
  ```

  The Copilot coding agent takes the same URL under `mcpServers` in the repository's Settings → Copilot → Coding agent
  → MCP configuration.
- **Other clients** ([list](https://vue-mcp.org/clients/)): streamable HTTP with the same URL, no headers. A
  self-hosted server runs over stdio instead (see the site's self-hosting guide).

### Use it

1. **Enable VitePress**, which isn't on by default: `set_framework_preferences(vitepress=true)`.
2. **Look things up:**

   | Tool | Use it for | Parameters |
   | --- | --- | --- |
   | `vitepress_docs_search` | Semantic search over the VitePress docs | `query` (up to 2000 characters), `scope` (`all`, `guide`, `reference`; default `all`), `max_results` (1–20, default 3) |
   | `vitepress_api_lookup` | Exact API reference with type signature and example | `api_name`, for example `defineConfig`, `useData` |
   | `vitepress_get_related` | Related APIs, concepts and pages for a topic | `topic` |

   The server also offers prompts (`debug_vitepress_issue`, `compare_vitepress_apis`, `migrate_vitepress_pattern`) and
   resources (table of contents, raw pages, API index).
3. **Cite** the VitePress docs page an answer or change relies on.
4. **Check the version.** Read the site's VitePress version in `package.json`; the docs describe the current release,
   so for a pre-release (for example `2.0.0-alpha`) or an older major, say when guidance may differ and let the build
   decide.
5. **When the server isn't available,** say so, show the setup above, mark the answer "VitePress docs not checked",
   and rely on the build and the existing config; never present unverified options as fact.

## Workflow

1. **Find the site.** The docs scripts in `package.json` (for example `docs:dev`, `docs:build`, `docs:preview`) name
   the source folder; the config is `<folder>/.vitepress/config.(mts|ts|js)`. Read the repository's documentation
   rules (`AGENTS.md`, `CONTRIBUTING.md`): which pages need sidebar entries, link style, required checks.
2. **Look up VitePress behavior** with the Vue Docs MCP server before changing config or relying on a feature
   (sidebar shape, `srcExclude`, `rewrites`, frontmatter, `cleanUrls`, `base`).
3. **Make the change.**
   - **Pages:** relative links to `.md` files (`../cards/preview-card.md`), so dead links are caught at build time.
     Moving pages changes their URLs: update every relative link into and out of the moved pages, the sidebar and nav
     links (which are root-relative and have no `.md`), and say that old URLs stop working unless redirects are added.
   - **Sidebar and nav:** groups are `{ text, collapsed?, items: [...] }`; a group can have its own `link`; links are
     root-relative to the source folder (the site's `base` is added automatically).
   - **Markdown is compiled as a Vue template.** Text like `<short title>` reads as an unclosed HTML tag and
     `{{ … }}` as an interpolation, even in inline code in a table. Put such text in a fenced code block, escape the
     brackets, add `v-pre` to the element (for example `<span v-pre>{{ x }}</span>`), or keep files that aren't
     pages out of the build with `srcExclude`.
4. **Verify.**
   - Run the build script (`npm run docs:build`); it fails on Vue template errors and dead links. Quote the exit code.
   - When the build is blocked by files outside your change, report them, and check your own links another way (a
     relative-link check over the changed pages) instead of calling the build passed.
   - For layout and sidebar changes, ask the user to look with the dev server (`npm run docs:dev`) or preview, since
     the build doesn't show how navigation looks.
   - Run the repository's Markdown checks on changed pages when it has them (for example the `aidevme-docs-maintenance`
     skill or a `lint:md` script).
5. **Report** what changed, the build and check results, the VitePress docs pages relied on, and what wasn't verified
   (for example how the sidebar renders). Don't commit, deploy or push unless asked.

## Rules

- **Docs before memory:** VitePress behavior comes from the Vue Docs MCP server, cited; say "not checked" otherwise.
- **Build is the gate:** a change isn't done until the build passes, or the remaining failure is shown to be outside it.
- **Keep URLs in mind:** moved or renamed pages break old links; say so.
- **No silent setup:** suggest MCP configuration; add it only when the user asks.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-17 | aidevme | Created: VitePress site changes (pages, sidebar, nav, config, build errors and dead links), grounded in the official VitePress docs through the Vue Docs MCP server, with setup for Claude Code and VS Code Copilot. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
