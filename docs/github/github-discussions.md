# GitHub Discussions

A collaboration space separate from Issues/PRs, for conversations that don't map to a single unit of
work: questions, ideas, announcements, and open-ended conversation. Unlike an issue, a discussion
doesn't need to resolve to a merged PR or a closed ticket — it can just... continue.

## Discussions vs. Issues vs. PRs

| | Purpose | Resolution |
| --- | --- | --- |
| **Issues** | A specific bug or well-scoped feature request — a unit of work to track. | Closed by a fix/PR. |
| **Pull Requests** | A concrete code change under review. | Merged or closed. |
| **Discussions** | Questions, ideas, announcements, general conversation. | Optional — a Q&A discussion can be marked "answered"; others just stay open indefinitely. |

Rule of thumb: if it's actionable and scoped, it's an issue. If it needs conversation before it's even
clear whether there's something to act on, it's a discussion.

## Enabling Discussions

Discussions are off by default on new repositories.

1. Go to the repository's **Settings** tab.
2. Under **General** → **Features**, check **Discussions**.
3. GitHub prompts a one-time setup: it creates a `#general` category and offers to seed a welcome
   post. You can skip the welcome post and just start using it.

Enabling it doesn't require any files committed to the repo — categories and settings live in GitHub's
own data, not in `.github/`. (Category *templates*, covered below, are the one exception.)

## Categories

Every discussion belongs to exactly one category. Categories are configured under the repository's
**Discussions** tab → the gear/settings icon (or **Settings** → **General** → **Features** →
**Discussions** → **Set up discussions** if it's your first time).

### Default categories

| Category | Format | Notes |
| --- | --- | --- |
| **Announcements** | Announcement | Only maintainers (people with write access) can start new threads; anyone can reply. Good for release notes, roadmap updates. |
| **General** | Open-ended discussion | Catch-all. |
| **Ideas** | Open-ended discussion | Feature proposals and brainstorming, before they're concrete enough to be an issue. |
| **Polls** | Poll | Structured voting. |
| **Q&A** | Question / Answer | Any reply can be marked as "the answer" by the original poster or a maintainer, which pins it to the top and marks the thread resolved (shown with a green checkmark in listings). |
| **Show and tell** | Open-ended discussion | Community members sharing what they built with the project. |

### Custom categories

You can add, rename, delete, or reorder categories from the same settings screen. Each category has:

- **Emoji** — shown as its icon everywhere the category appears.
- **Title** and **Description**.
- **Format** — one of `Open-ended discussion`, `Announcement`, `Question / Answer`, or `Poll`. This is
  fixed per category (you can't mix formats within one category), and determines the UI: only Q&A
  categories get the "mark as answer" affordance; only Announcement categories restrict who can post.

Deleting a category doesn't delete its discussions — they move to the "no category"/uncategorized
bucket, or you can move them to another existing category individually first.

### Category-specific templates

Similar to `.github/ISSUE_TEMPLATE/*.yml`, you can seed the "new discussion" form for a specific
category with a Markdown template:

```
.github/DISCUSSION_TEMPLATE/<category-slug>.yml
```

The filename's `<category-slug>` must match the category (lowercase, spaces → hyphens — e.g. a "Q&A"
category's slug is typically `q-a`, "Ideas" is `ideas`). Unlike issue templates, discussion templates
are **not** YAML forms with typed fields — they're plain Markdown body text (with optional YAML
front matter for `title:` and `labels:` isn't supported the same way issue templates support it).
Effectively it's a single body template per category, not a picker of multiple templates.

## Permissions and moderation

- **Who can start a discussion**: anyone with read access to a public repo, in any category except
  Announcement-format ones (maintainers/write-access only for those).
  ✔ For a private repo, anyone with read access.
- **Pinning**: maintainers can pin up to a small number of discussions per category so they stay at
  the top of the list (e.g. a pinned "Read before posting" thread).
- **Locking**: maintainers can lock a discussion to stop new replies, same as locking an issue.
- **Transferring**: a discussion can be transferred to another repository you maintain.
- **Converting issue ↔ discussion**:
  - Issue → Discussion: from an open issue, **"Convert to discussion"** in the sidebar — useful when a
    reported "bug" turns out to be a usage question. The issue is closed and its comments become the
    discussion's replies.
  - Discussion → Issue: from within a discussion (or a specific comment), **"Create issue"** — useful
    once a Q&A or Ideas thread converges on a concrete, actionable task. This creates a *new* linked
    issue; it doesn't delete the discussion.
- **Marking spam/abuse**: maintainers can report or delete individual discussions/comments the same as
  on issues.

## Notifications and following

- Users can **Subscribe** to an individual discussion (bell icon) to get notified of new replies.
- Watching a repo with the default "All Activity" setting includes discussions; the "Custom" watch
  option lets you opt in/out of Discussions specifically, separate from Issues/PRs/Releases.
- Maintainers can require **read access** for discussions to be visible at all, same as any other repo
  content — there's no separate discussions-only visibility toggle.

## Managing via `gh` CLI / API

The REST API has very limited discussion support; almost everything goes through GraphQL.

```bash
# List discussion categories for a repo
gh api graphql -f query='
  query($owner:String!, $repo:String!) {
    repository(owner:$owner, name:$repo) {
      discussionCategories(first: 20) {
        nodes { id name emoji description }
      }
    }
  }' -f owner=OWNER -f repo=REPO

# List recent discussions
gh api graphql -f query='
  query($owner:String!, $repo:String!) {
    repository(owner:$owner, name:$repo) {
      discussions(first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes { title url category { name } }
      }
    }
  }' -f owner=OWNER -f repo=REPO
```

Creating/answering/locking discussions via API also goes through GraphQL mutations
(`createDiscussion`, `markDiscussionCommentAsAnswer`, `updateDiscussion`, etc.) — there's no dedicated
`gh discussion` subcommand as of this writing, unlike `gh issue`/`gh pr`.

## Relevance to PPTB-Tools

This repo doesn't have Discussions enabled yet, and `.github/ISSUE_TEMPLATE/config.yml` currently sets
`blank_issues_enabled: false` with no `contact_links` — meaning there's no template offered for
"I have a question, not a bug." If Discussions get enabled here:

- A **Q&A** category would be the natural home for "how do I port plugin X" or "why doesn't feature Y
  work" questions that don't belong in `bug_report.yml`/`feature_request.yml`.
- An **Ideas** category overlaps somewhat with the existing `tool_port_request.yml` issue template
  (see `.github/ISSUE_TEMPLATE/tool_port_request.yml`) — early-stage "should we port XrmToolBox plugin
  X" conversations could live in Ideas first, then convert to a `tool_port_request` issue once scoped.
- Once enabled, add a `contact_links` entry to `config.yml` pointing at the Q&A category, so the issue
  creation page offers Discussions as an option instead of leaving users to file a mis-scoped bug
  report — this is the standard pairing for repos with `blank_issues_enabled: false`.
