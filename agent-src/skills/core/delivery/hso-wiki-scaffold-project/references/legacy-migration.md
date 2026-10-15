# Legacy `agent/` Migration Reference

Playbook for migrating a repo from the **old numbered `agent/` layout** (`00_system/` … `09_deliverables/`)
to the **new hybrid layout** (`raw/`, `_inbox/`, `wiki/`, `work/`).

This is a reference document, not an automated script. The folder moves are mechanical, but the
**raw-vs-processed triage** for artifacts and transcripts requires human judgment per file. Expect a one-off
per repo, not a repeatable batch job.

---

## Detect the current layout

Before doing anything, figure out which layout the repo is on:

| Layout | Signals | Action |
|---|---|---|
| **Legacy numbered** | `00_system/`, `02_analysis/`, … present under `agent/` | Run the numbered-layout migration below |
| **Hidden-scaffolding** | `.agent/` and/or a single `.shared/` junction | Rename `.agent/` → `agent/` and replace `.shared/` with `shared/<slug>/` (see below), then check for numbered folders |
| **Current** | `agent/` + `shared/<slug>/` (e.g. `shared/dv/`) | No rename needed; check whether the numbered-folder layout still applies |

The numbered-folder layout is orthogonal to the hidden-scaffolding rename and can apply on top of either.
Run both migrations back-to-back if the repo hits both.

---

## Migration: hidden-scaffolding rename (`.agent/` → `agent/`, `.shared/` → `shared/<slug>/`)

The template makes the agent scaffolding folder visible (`agent/`, not `.agent/`) and mounts each inherited
product tier as a child junction under a `shared/` parent (`shared/dv/`, `shared/fo/`, …) rather than a single
hidden `.shared/` junction.

Steps (run from the consuming repo root):

1. **Drop the old `.shared/` junction if present.** Junctions are removed with `rmdir`, not `del`:
   ```cmd
   rmdir .shared
   ```
   `rmdir` on a junction removes only the junction, not its target. Confirm with `dir .shared` that it's gone.

2. **Rename `.agent/` → `agent/`.** Use `git mv` to preserve blame history:
   ```bash
   git mv .agent agent
   ```

3. **Create the new `shared/` parent and the product-tier child junction** (where `..\ProductTierClone` is
   the sibling clone of the shared product-tier repo):
   ```powershell
   New-Item -ItemType Directory -Path shared | Out-Null
   New-Item -ItemType Junction -Path shared\dv -Target ..\ProductTierClone | Out-Null
   ```
   Verify: `Get-Item shared\dv | Select-Object LinkType,Target` should show `Junction` and the absolute path.

4. **Add `shared/` to `.gitignore`** (if it isn't already). The parent is gitignored; child junctions resolve
   through the OS, not through git.

5. **Re-sync the inherited skill content** so it references `agent/` and `shared/dv/agent/` paths.

6. **Fix up any local references.** Grep the consuming repo's own docs (`README.md`, project-tier wiki, local
   scripts) for `.agent/` and `.shared/` and rewrite them to `agent/` and `shared/dv/`.

7. **Run `hso-wiki-lint`** — any residual broken link is almost certainly a missed path rewrite.

Additional product tiers are wired with additional child junctions (`shared/fo/`, `shared/pp/`) when those
repos exist — one `New-Item -ItemType Junction` per tier.

---

## When to use this doc

- A repo was scaffolded before the hybrid layout existed and still has `00_system/`, `02_analysis/`,
  `03_digests/`, etc.
- `hso-wiki-lint` fails because the numbered folders don't match the current schema.
- You want to adopt `hso-wiki-capture`, `hso-wiki-write-decision`, or any other hybrid-layout-aware skill.

If the repo has **no** `agent/` at all, skip this doc and run `hso-wiki-scaffold-project` directly.

---

## Migration phases

### Phase 1 — Scaffold the new layout (non-destructive)

Run `hso-wiki-scaffold-project` on the repo. The skill is idempotent and creates the hybrid folders
**alongside** the existing numbered ones without touching them. After this step the repo has both layouts
side-by-side. Verify the new scaffold passes `hso-wiki-lint` before moving any content.

### Phase 2 — Move content per the mapping table

Use `git mv` (not plain `mv`) so history follows the files. Work folder-by-folder.

| Old (numbered)                       | New (hybrid)                        | Notes |
|--------------------------------------|-------------------------------------|-------|
| `00_system/`                         | `wiki/system/`                      | Straight move. Curated reference pages. |
| `02_analysis/*.md`                   | `work/analysis/`                    | Analysis docs are work products. |
| `02_analysis/artifacts/` (raw)       | `raw/discovery/`                    | Original client PDFs, xlsx, docx — **triage required**. |
| `02_analysis/artifacts/digests/`     | `wiki/digests/`                     | Processed markdown summaries. |
| `03_digests/transcripts/full/`       | `raw/transcripts/`                  | Full transcript text (immutable sources). |
| `03_digests/*.md` (digest summaries) | `wiki/digests/`                     | Human-readable meeting digests. |
| `04_specs/`                          | `work/specs/`                       | Straight move. |
| `05_design/` (design docs)           | `work/design/`                      | Implementation-level design documents. |
| `05_design/` (ADRs)                  | `wiki/decisions/`                   | ADRs are wiki entries. |
| `06_build/changelog/`                | `work/build/changelog/`            | Straight move. |
| `06_build/implementation-notes/`     | `work/build/implementation-notes/` | Straight move. |
| `07_testing/`                        | `work/testing/`                     | Straight move. |
| `09_deliverables/`                   | `work/deliverables/`               | Straight move. |
| `README.md` (root of `agent/`)      | — (delete; scaffold wrote a new one) | Diff first; fold project-specific content into the new `README.md` or `wiki/system/`. |

### Phase 3 — Triage the ambiguous folders

Two folders in the old layout conflate raw sources with processed output; these need per-file judgment.

**`02_analysis/artifacts/`** — per file:
- Binary client docs (`.pdf`, `.xlsx`, `.docx`, `.pptx`), raw exports, screenshots → `raw/discovery/`
- Markdown digests/summaries **you** wrote about those docs → `wiki/digests/`
- Your own gap analyses, discovery writeups → `work/analysis/`

**`03_digests/`** — per file:
- `.docx` / `.txt` / `.vtt` transcript sources → `raw/transcripts/`
- Markdown summaries you wrote from those transcripts → `wiki/digests/`

Rule of thumb: **raw/** is anything you didn't author and can't edit without losing fidelity. **wiki/** is
curated, human-written content. **work/** is in-flight project artifacts tied to a specific deliverable.

### Phase 4 — Add frontmatter to migrated files

Legacy files almost certainly lack the frontmatter `hso-wiki-lint` expects. For each moved file:

1. Add the required frontmatter block for its new location (see `schema.md` for required fields per folder).
2. Run `hso-wiki-lint` and fix drift iteratively — don't try to perfect every file in one pass.
3. Reference pages in `wiki/reference/` and SOPs in `wiki/sop/` have stricter schemas than `work/` documents.

### Phase 5 — Remove empty legacy folders

Once all content has moved and `hso-wiki-lint` is clean:

```bash
git rm -r agent/00_system agent/02_analysis agent/03_digests \
          agent/04_specs agent/05_design agent/06_build \
          agent/07_testing agent/09_deliverables
```

### Phase 6 — Update the repo's instruction file

The "Documentation Structure" section of the repo's `AGENTS.md` / `CLAUDE.md` in legacy repos describes the
numbered layout. Replace it with the hybrid layout (copy from a freshly-scaffolded repo).

---

## Things that commonly go wrong

- **Lost git history.** Using `mv` or File Explorer drag-and-drop instead of `git mv` breaks `git log --follow`.
- **Over-eager `raw/` classification.** Not every file in `02_analysis/artifacts/` belongs in `raw/`. A markdown digest you wrote goes to `wiki/digests/`.
- **Skipping frontmatter fixes.** `hso-wiki-lint` keeps failing until frontmatter matches the schema for each file's new home. Fix in small batches as you move files.
- **Moving legacy `README.md` verbatim.** The scaffold already wrote a new `README.md`. Diff the old one, salvage project-specific content, then delete the old.
- **Committing mid-migration.** Commit at phase boundaries so a mistake is a `git reset` to the last clean boundary.

---

## When to promote this doc to a script

Keep this as a reference doc as long as migrations are rare (< ~3 repos). Convert to a
`Migrate-LegacyAgentLayout.ps1` under `hso-wiki-scaffold-project/scripts/` only if you run the migration more
than 3 times **and** legacy repos are consistent enough that ~80% of moves can be mechanical (the Phase-3
triage always needs human judgment — a script should flag those folders and stop). Do **not** build a full
skill for this — migration is a bounded, one-time event per repo.
