# Marp Authoring Guide — HSO Theme

Reference for authoring slide markdown with the `hso-knowledge` theme.
Loaded by the `DevOps Weekly Recap` skill (and any future deck-producing skill).

## Frontmatter (required, top of every deck)

```markdown
---
marp: true
theme: hso-knowledge
paginate: true
size: 16:9
title: <Deck title>
---
```

## Slide layouts

Marp splits slides on `---` rulers. Each slide can opt into a layout via a scoped
local directive `<!-- _class: NAME -->` placed on its first line.

### 1. Cover (use exactly twice — slide 1 and the closing slide)

```markdown
<!-- _class: cover -->

# Weekly Engineering Recap

Week of April 23–30, 2026

<div class="byline">77 commits · 8 themes · headline: <strong>monetization is unblocked</strong></div>
```

Use a short, declarative title. One short subtitle line. Byline is a `<div class="byline">` block — CSS pulls it to the page bottom in cyan.

### 2. Section divider (between major themes)

```markdown
<!-- _class: section -->

# Live Meeting Capture

Same pipeline, live or after-the-fact. Voice, video, and outcomes flow into project memory.
```

One `#` headline (the theme name). One supporting sentence. No bullets. This slide exists to give the audience a breath between modules.

### 3. Content (the workhorse — bullet/numbered slides)

```markdown
# Frame extraction got 5x faster

This week we collapsed the per-frame pipeline into a single ffmpeg pass and
parallelized everything downstream — uploads, LLM calls, DB inserts.

- **Single ffmpeg pass + batch DB insert** — was 9 separate invocations per video
- **Parallel chunked ffmpeg** for long videos — bounded concurrency = 4
- **dHash + Hamming change detection** — only analyze frames that actually changed
- **Parallel blob uploads** with `SemaphoreSlim(8)` — was sequential
- **Batch screenshots** to stay under OpenAI's 50-image cap per call

*Net effect:* a 90-min recording that took ~12min to analyze now takes ~3min.
```

Rules of thumb:
- Title is a *claim*, not a label. "Frame extraction got 5x faster" beats "Frame extraction".
- One short paragraph of context (optional).
- 3–6 bullets max — bold the lead phrase, plain-text the explanation.
- Close with one `*italic*` summary line if there's a punchy takeaway. For exec decks, prefix with `*Net: …*`.

### 4. Stat slide (impact / hero number)

```markdown
<!-- _class: stat -->

<div class="number">77</div>

## commits this week

a billing platform shipped, **digital consultants now join live Teams meetings**, and meeting analysis runs 4-5x faster
```

Use sparingly (1–2 per deck, max). Big number is the hook.

### 5. Columns (compact module overview — good as deck summary)

```markdown
# What shipped this week

<div class="cols three">
<div class="card">

### Live Meeting Capture
End-to-end pipeline. Lifecycle states. Recap + decks reachable from 1:1 DMs.

</div>
<div class="card">

### Vision & Multimodal
Frame extraction 5x faster via parallelization.

</div>
<div class="card">

### ACS Hardening
Standalone probe project + persisted call-end reasons.

</div>
</div>
```

Use `cols two` for richer descriptions, `cols three` for headlines only. Cards get a cyan top border automatically — don't add inline styles.

## Inline emphasis conventions

- **`**bold**`** — anything the audience should remember; navy color applied automatically.
- **`*italic*`** — accent color (cyan), used for callouts and `*Net:*` lines.
- **`` `code` ``** — file paths, function names, identifiers — gets a navy/grey pill. **Use only in `engineering`-audience decks.**
- **`[link](url)`** — cyan, underlined; use for PR or commit links if available.

## What NOT to do

- **Don't use raw HTML for styling.** The theme handles it. Inline `style=""` is sanitized away.
- **Don't paste long code blocks** — they overflow. Keep under 8 lines and use a single language fence.
- **Don't try to put images side-by-side in markdown.** Use the columns layout.
- **Don't title slides with the date** — it's already in the cover. Title with the *story*.

## Deck shape for a weekly recap

A good 7-module week produces ~12–15 slides:

1. Cover
2. Stat (commits / modules / hero feature)
3. Columns overview (3-up summary of all themes)
4. Section divider — Theme 1
5. Content — Theme 1 details
6. Section divider — Theme 2
7. Content — Theme 2 details
8. ... (repeat per theme)
9. Closing cover (mirror of slide 1, past tense)

Skip section dividers for thin themes (<3 commits) — fold into a single content slide.

## Theme color cycling

The CSS exposes 4 section-divider color treatments via scoped directives that override `_color` and `_backgroundColor` on a `_class: section` slide. Cycle through them in order so consecutive sections look distinct (the BLUE/Green/Salmon/Caramel cycle from the source PowerPoint template). Reuse the cycle if you have more than 4 themes.

## Brand palette (for reference)

- Navy: `#00395F` (primary — titles, headings)
- Cyan: `#079FC3` (accent — italic, cards, page numbers)
- Teal: `#00B294` (success / bullet markers)
- Red: `#F1554B` (highlight / warning — use sparingly)
- Yellow: `#F2B949` (highlight — use sparingly)
- Slate: `#44546A` / Mute: `#737373` (secondary text)

Font: **Segoe UI** throughout. System-installed on Windows; falls back gracefully on macOS/Linux.
