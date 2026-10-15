---
name: hso-confluence-pages
layer: atomic
scope: core
description: |
  Read, create, and update Confluence Cloud wiki pages through the REST API — list spaces, list
  pages in a space (full pagination), search by title, full-text search via CQL, get page content
  (storage format or readable text), create a page, update an existing one from markdown. Use when
  asked to publish docs to Confluence, update or read a Confluence page, discover spaces, find a
  page by title or content, or when given an `atlassian.net/wiki/...` URL and asked to use or
  update "this page". Does NOT manage space permissions, attachments, or Confluence macros. Does
  NOT maintain the repo's own knowledge base — that is `agent/` and the hso-wiki-* skills. Every
  write requires explicit confirmation.
---

# Confluence pages

Read and write Confluence Cloud pages via REST v2. **A client's wiki is not our wiki** — see scope.

> ## Verification status — read is proven live, write is not
>
> **Read operations were exercised against a real Confluence Cloud instance on 2026-08-27** —
> auth, space resolution, listing, title search, full-text search, and page retrieval (including a
> 65 KB macro-heavy page) all returned correct data. See [CHANGELOG.md](CHANGELOG.md) for the run.
>
> **`CreatePage` and `UpdatePage` have never been run against a live instance.** The only real
> instance available was a client's wiki, and writing there was deliberately avoided. Their REST
> paths and payload shapes are still carried over from the upstream source unproven.
> Treat the first real write as a test: create a throwaway page in a space you own before letting
> the first use be an `UpdatePage` against something that matters. When write has been exercised,
> narrow this callout again and record the result in [CHANGELOG.md](CHANGELOG.md).

## Authority — read before publishing anything

**Know what may leave your control before writing to a client's Confluence.** Your organization's
client-deliverable standards govern what content may be published. Publishing to a client's
Confluence **is** publishing: the content leaves your organization's control and lands somewhere the
client and often third parties can read. That it went via an API rather than an email attachment
changes nothing about which content is allowed to go.

> **This skill does not enforce that boundary — you do.** Its sibling
> [`hso-client-publish`](../hso-client-publish/SKILL.md) *does*: policy file, hard exclusions
> (`agent/`, `CLAUDE.md`, `.claude/`, `shared/`), a scrub that strips internal pointers, dry-run by
> default, and destination remapping so an internal folder layout is never recreated in a client
> repo. **This skill has none of that.** It writes what you hand it, to the page you name.
>
> So before publishing anything sourced from the internal repo — a spec, a deliverable, a digest —
> apply that boundary by hand: check the content against your organization's client-deliverable
> standards and the exclusions `hso-client-publish` would have applied. Closing this gap properly is
> tracked as a known gap and deferred until a real Confluence publishing scenario exists to design
> against.

| Task | Primary authority |
|---|---|
| Whether this content may leave your organization at all | your organization's client-deliverable standards |
| Publishing deliverables to a client repo (the gated channel) | [`hso-client-publish`](../hso-client-publish/SKILL.md) |
| Atlassian credentials and Basic headers | [`hso-atlassian-auth`](../hso-atlassian-auth/SKILL.md) |
| The **repo's own** knowledge base | [`hso-wiki-*` skills](../hso-wiki-query/SKILL.md) and `agent/schema.md` |
| Capturing a Confluence page as an immutable source | [`hso-wiki-capture`](../hso-wiki-capture/SKILL.md) |
| Confluence page read/write mechanics | **this skill** |

## Scope — three different wikis, do not confuse them

| Wiki | What it is | Skill |
|---|---|---|
| **`agent/`** | Our repo-local knowledge base — SOPs, ADRs, digests, topics | `hso-wiki-*` |
| **A client's Confluence** | The client's own space, outside your organization's control | **this skill** |
| **A Confluence page as a *source*** | Something to cite, not to edit | [`hso-wiki-capture`](../hso-wiki-capture/SKILL.md) |

Reading a client's Confluence page to inform our work is a **capture** (immutable — pointer plus
snapshot). Editing that page is this skill. Do not use this skill to mirror our `agent/` content
into a client space without going through the deliverable standards above.

## Configuration

Credentials resolve through [`hso-atlassian-auth`](../hso-atlassian-auth/SKILL.md): explicit
parameters, then `ATLASSIAN_BASE_URL` / `ATLASSIAN_EMAIL` / `ATLASSIAN_API_TOKEN` environment
variables, then a **gitignored** `auth-settings.json`.

> The API token is a secret. It never goes in `CLAUDE.md`, `CLAUDE.local.md`, or any tracked file.

## Operations

```powershell
$s = "claude-code/skills/hso-confluence-pages/scripts/Invoke-ConfluencePageOperation.ps1"

& $s -Operation ListSpaces                                          # global spaces (team wikis)
& $s -Operation ListPages     -SpaceKey "ENG" -MaxResults 0         # every page, paginated
& $s -Operation SearchPages   -SpaceKey "ENG" -Title "Integration Design"
& $s -Operation SearchContent -SpaceKey "ENG" -Query "module boundary"
& $s -Operation GetPage       -PageId 123456 -AsText -OutFile ".\page.md"
& $s -Operation CreatePage    -SpaceKey "ENG" -Title "New Page" -BodyFilePath ".\doc.md" -ConfirmWrite
& $s -Operation UpdatePage    -PageId 123456 -BodyFilePath ".\doc.md" -ConfirmWrite
```

| Operation | Does |
|---|---|
| `ListSpaces` | Spaces on the site — key, id, name. Defaults to `global` (team) spaces; `-SpaceType all` includes personal ones |
| `ListPages` | Pages in a space, sorted by title, following pagination |
| `SearchPages` | Find page IDs by **title** (exact, then partial fallback) |
| `SearchContent` | **Full-text** search via CQL `text ~ "..."` — site-wide, or one space with `-SpaceKey` |
| `GetPage` | Page content — storage format by default, readable markdown-style text with `-AsText`; `-OutFile` writes the body to a file |
| `CreatePage` | New page from markdown |
| `UpdatePage` | Replace an existing page's body from markdown |

**Result caps are never silent.** List and search operations default to `-MaxResults 25`; when a
cap cuts a list off, the output says so and names the fix (`-MaxResults 0` fetches everything).
Trust a list as complete only when the output says it is complete.

## Writes require explicit confirmation

`CreatePage` and `UpdatePage` do nothing without `-ConfirmWrite`. This is deliberate and inherited
from the source: an accidental `UpdatePage` **replaces** a page body, and Confluence's version
history is the only thing standing between that and data loss on a client's wiki.

Confirm the target page with `SearchPages` or `GetPage` before any update — a wrong `PageId`
overwrites an unrelated page just as willingly as the right one.

## Reading a page as a capture source

Reading a client's Confluence page to inform our work is a **capture** — immutable, pointer plus
snapshot. The mechanical feed for that is:

```powershell
& $s -Operation GetPage -PageId 123456 -AsText -OutFile ".\snapshot.md"
```

then hand the snapshot to [`hso-wiki-capture`](../hso-wiki-capture/SKILL.md) /
[`hso-wiki-ingest-discovery-artifact`](../hso-wiki-ingest-discovery-artifact/SKILL.md), which own
the capture's frontmatter, target path, and log entry. A `-Capture` switch was **considered and
rejected** (2026-08-27): this skill is reusable and must stay ignorant of any consuming repo's
`agent/` layout — encoding capture frontmatter and paths here would duplicate the ingest skills'
contract and drift from it. The seam is deliberate: this skill produces a clean text snapshot; the
wiki skills decide where it lives.

## Notes

- **REST v2** (`/wiki/api/v2/`) throughout, except `SearchContent` — CQL full-text search only
  exists on the v1 REST API (`/wiki/rest/api/search`), which v2 has no equivalent for.
- **`-AsText` is lossy by design** — macros become `[macro: name]` stubs or panel markers, layout
  is flattened. It is for reading and capturing. `UpdatePage` needs storage format; never
  round-trip a page through `-AsText` and write it back.
- **Markdown → Confluence storage format** conversion is handled by the script; the first H1 is
  skipped because Confluence renders the page title as the H1.
- Relative `.md` links are resolved to Confluence URLs where a `confluence-page-id` marker is
  present; where it is not, the original link is kept and a warning is emitted rather than a broken
  link being written silently.

## Changelog

See **[CHANGELOG.md](CHANGELOG.md)**.
