---
name: hso-timesheet-builder
layer: atomic
scope: core
description: Build the user's daily/weekly timesheet for D365 F&O project timesheets + HSO Bnext. Gathers meetings (Krisp/calendar) and work (agent log / changelog / git / audit), classifies each by customer+project from a config-driven customer map (asks and remembers when a customer is unknown - never hardcodes clients), applies the entry rules (one line per customer+project, 30-min blocks min 0.5h, <=4h work lines, 128-char ASCII comments forbidding + and >, Jira/ADO refs, truthful-no-pad), emits a draft for approval, then enters and verifies. Use for "make me a timesheet", "build my timesheet for <day/week>".
---

# HSO Timesheet Builder

Builds a **per customer, per project** timesheet from what actually happened, applies the hard
entry rules, shows a **draft for approval**, then (only on explicit OK) enters it into the timesheet
system and verifies.

The timesheet system is **D365 F&O project timesheets** plus HSO's **Bnext** software.

> **Never auto-enter and never Submit.** Emit the draft, get the user's approval, enter as **Created
> (draft)** only, and never click Submit without a separate explicit OK.

## When to use this skill

- "Make me a timesheet for yesterday / last week / <date range>"
- "Build / draft my timesheet"
- "Enter my approved timesheet into F&O / Bnext"

## When NOT to use

- Generating documentation, specs, or changelogs (those are *sources* this skill reads).
- Any client other than the user's mix without first confirming the customer+project mapping.

## Configuration

Read from `CLAUDE.local.md` (`## Timesheet` section):
- **Author Name** — timesheet author attribution.
- **Customer map** — a per-developer table mapping each Customer -> Project -> Activity, plus
  **classify hints** (title keywords / attendee email domains) for auto-classification.
- **Timesheet system** — F&O env URL + company, and the Bnext target.

Read from `CLAUDE.md`: project context (which customer/project the current repo's work belongs to).

The skill is **customer-agnostic — never hardcode a client list.** When the data shows a customer
not in the map, ASK, book the line, then offer to add the new row to `CLAUDE.local.md` so it is
remembered next time. If the `## Timesheet` section is missing, offer to scaffold it.

---

## The model: one line per customer + per project

Every timesheet line carries, at minimum:

| Field | Notes |
|-------|-------|
| **Customer** | e.g. Contoso. One line never mixes customers. |
| **Project** | e.g. `Contoso Support Project`. One line never mixes projects. |
| **Activity** | F&O activity, e.g. `Algemene activiteiten`. |
| **Hours** | Rounded to 0.5h (see rules). |
| **Comment** | <=128 chars, ASCII, basic punctuation only (see Comment rules). |
| **Ticket** | Jira or ADO work-item number where one exists. |

The Customer -> Project -> Activity mapping comes from the **Customer map** in `CLAUDE.local.md`
(not hardcoded here). Example shape:

| Customer | Project | Activity | Classify hints |
|----------|---------|----------|----------------|
| *(example)* Contoso | `Contoso Support Project` | `Algemene activiteiten` | contoso, CRM, Conversation Map; @contoso.com |
| *(example)* HSO internal | *(internal code)* | — | staffing, career, 1:1, skills, agentic dev; @hso.com |

When the data shows a customer not in the map, ASK rather than guess, then offer to persist it.

---

## Hard rules (enforce on every line)

1. **Per customer + per project.** Split any block that would span two customers or two projects.
2. **30-minute blocks. Minimum block = 0.5h.** Round every entry to the nearest 0.5h
   (0.25 -> 0.5, 0.75 -> 1.0). A 15-minute standup books as 0.5h.
3. **Work lines: <=4h. 4h is the upper limit.** Split any task larger than 4h into multiple
   lines (e.g. 6h -> 4h + 2h, or two themed 3h blocks). Never an 8h line.
4. **Meetings = one line each, at actual duration rounded to 0.5h.** Comment = the meeting name
   (sanitised). Add a separate follow-up line only if real follow-up work happened.
5. **Work = estimated effort per task**, each as its own <=4h line. Comment = the task.
6. **Comments <=128 chars, ASCII, basic punctuation only.** See Comment rules below.
7. **Add a Jira or ADO ticket number where possible.** Pull from the agent log / ADO / Jira.
   Leave blank when no ticket genuinely exists (do not invent one).
8. **Be truthful. Do NOT pad to 40h.** ~32-36h/week or ~52-76h/week is fine, it is what it is; the user tops up from other clients.
   Always report the honest weekly/daily total. Inflating one client's hours to hit a target is
   wrong - billing must be accurate per customer.
9. **Each customer's time stays on its own codes.** Never fold one customer's (or internal) time
   into another to inflate a total. List internal / other-customer time **separately** so it is
   booked on the right code.

### Comment rules (F&O hard limit + clean text)

F&O rejects comments over 128 chars and mangles non-ASCII. **Strip everything that is not plain
ASCII basic punctuation.**

- **Forbidden, always:** `+`  `>`  `<`  `=`  `|`  `*`  `~`  `^`, and **all** non-ASCII
  ("weird AI characters"): em/en dashes `—` `–`, smart quotes `“ ” ‘ ’`, ellipsis `…`,
  arrows `→`, bullets `•`, non-breaking spaces.
- **Allowed:** letters, digits, space, and `. , - ( ) / : ' ?`
- **Transform before writing:**

  | Replace | With |
  |---------|------|
  | `+` | `and` (or `plus`) |
  | `>` / `->` | `to` or `then` |
  | `—` `–` (dashes) | `-` |
  | `“ ” ‘ ’` | `"` `'` (straight) |
  | `…` | `...` |
  | `&` | `and` |
  | any other non-ASCII | nearest ASCII, else drop |

- **Then enforce <=128 chars.** If too long, tighten the wording - do not truncate mid-word.

Self-check before emitting: every comment matches `^[\x20-\x7E]{1,128}$` and contains no
`+ > < = | * ~ ^`.

---

## Workflow

1. **Resolve the date range.** "Yesterday" = the prior calendar day in the user's timezone (+01:00).
   Confirm the exact date(s) with the Krisp `date_time` tool.
2. **Gather meetings** (durations + names) - see Data sources. Krisp = what actually happened;
   calendar = authoritative start/end. Cross-reference; resolve overlaps and cancelled/moved
   invites (a "moved to next week" note means it did NOT happen - exclude it).
3. **Gather work** - agent log (`agent/log.md`), `agent/work/build/changelog/`, git commits by the
   author, Power Platform `modifiedon`/audit. Each distinct task is a candidate work line.
4. **Classify every item by customer + project** using the customer map (match the title and
   attendee email domains against each customer's classify hints). For anything the map does not
   clearly resolve - generic 1:1s, internal syncs - ASK rather than guess (a meeting's customer
   drives who gets billed). Persist any new customer the user confirms back to `CLAUDE.local.md`.
5. **Estimate work effort** honestly per task; round to 0.5h; split >4h.
6. **Sanitise comments** (ASCII, <=128, transforms above).
7. **Attach tickets** (Jira/ADO) where they exist.
8. **Emit the draft** - one table per customer, plus a separate "not this client" section, with
   per-customer subtotals and an honest day/week total. (Output format below.)
9. **Get the user's approval / corrections.** Do not proceed to entry without it.
10. **Enter** into F&O / Bnext as Created (draft) - see
    [references/fno-bnext-entry-mechanics.md](references/fno-bnext-entry-mechanics.md).
    Before choosing an automation route, read
    [references/bnext-powerapp-automation.md](references/bnext-powerapp-automation.md) - it records
    the BNext Power App surface and the three routes already proven blocked (flow payloads,
    direct flow calls, direct F&O OData), so they are not re-investigated.
11. **Verify** by reopening the saved record (the Due-list aggregate is stale after back-nav).
12. **Never Submit** without a separate explicit OK.

## Data sources

| Source | Gives | Tool |
|--------|-------|------|
| **Krisp meetings** | what happened, names, start times | `search_meetings` (filter `after`/`before`; widen +/-1 day for tz) |
| **Krisp date_time** | today / yesterday resolution | `date_time` |
| **Calendar** | authoritative start/end = durations, attendees, cancelled/moved notes | calendar `list_events` |
| **agent/log.md** | the day's deliverables (specs, builds, deploys) | Read |
| **changelog/** | implementation notes | Read `agent/work/build/changelog/` |
| **git** | commits by author on the date | `git log --since --until --author` |
| **Power Platform audit** | `modifiedon` on records touched | data skill (optional) |

> Krisp's meeting object does **not** expose a duration field - get durations from the calendar,
> or infer from the gap to the next meeting, defaulting a short sync to 0.5h.

## Output format (the draft)

**Always a markdown table - the SAME layout for every day, in chat AND in the saved file. Never
bullets, even for a one-line or meeting-only day.** One table per customer+project per day with
columns `Hours | Comment | Ticket` and a bold subtotal row, then a separate small table for
internal / other-client lines. Repeat the identical block for each day in the range.

```markdown
TIMESHEET DRAFT - <date range>   (author: keithwhatling)

### Wed 2026-06-17 - Contoso - Contoso Support Project / Algemene activiteiten
| Hours | Comment | Ticket |
|---|---|---|
| 0.5 | Contoso daily CRM connect standup | |
| 3.5 | Conversation Map P2 validation plugin - build, tests, deploy | 32054 |
| **7.5** | **Contoso subtotal** (3.0 measured meetings + 4.5 estimated) | |

| Hours | Comment (not Contoso - internal) | Ticket |
|---|---|---|
| 1.0 | Pizza session - Project 007 | |

### Thu 2026-06-18 - Contoso - Contoso Support Project / Algemene activiteiten
| Hours | Comment | Ticket |
|---|---|---|
| ... | (same layout, every day) | |
```

After the per-day tables, add two summary blocks:
- **Measured meeting totals** (firm, from calendar/Krisp) vs **estimated** work hours - keep the two
  visibly separate so the reader sees what is counted vs guessed.
- **Flags:** ambiguous classifications, overlaps, moved/cancelled meetings, calendar-only attendance,
  missing internal project/activity code, and any day whose total is an estimate awaiting real hours.

Write the same tables to a git-ignored `Timesheets/` draft file (never commit timesheets - see DO list).

---

## Critical rules

**DO**
- Emit a draft and get approval BEFORE entering anything.
- Render EVERY day as the same markdown table (`Hours | Comment | Ticket` + bold subtotal), in chat
  and in the saved file - never bullets, even for a one-line or meeting-only day.
- Keep measured meeting hours and estimated work hours visibly separate; never tune work hours to
  land on a standard day (7.5h/8h). Anchor on the user's real worked hours when given.
- Save the draft to a git-ignored `Timesheets/` folder; add `/Timesheets/` to `.gitignore` if missing
  and untrack any already-committed timesheet (`git rm --cached`). Never commit timesheets.
- Keep every comment ASCII, <=128 chars, no `+ > < = | * ~ ^`.
- One line per customer+project; round to 0.5h; split work >4h.
- Report the honest total; keep each customer's time on its own codes.
- Add Jira/ADO numbers where they exist; ASK when a customer is not in the map.

**DO NOT**
- Auto-enter or Submit without explicit OK.
- Pad hours to hit 40, or fold one customer's time into another.
- Hardcode a client list, invent ticket numbers, or include a cancelled/moved meeting.
- Use F&O "Duplicate" / "Copy period" (locks the sheet - see entry-mechanics reference).

## Changelog

| Date | Author | Description |
|------|--------|-------------|
| 2026-06-17 | keithwhatling | Initial creation. Encodes per customer+project lines, 30-min/0.5h blocks, <=4h work lines, 128-char ASCII comments (forbids `+` `>` and non-ASCII), Jira/ADO ticketing, truthful-no-pad, per-customer separation, and the draft-then-approve-then-enter workflow for D365 F&O + Bnext. Entry mechanics in references/. |
| 2026-06-17 | keithwhatling | Made customer-agnostic per the user: no hardcoded client list. Customer -> Project -> Activity + classify hints now read from a `## Timesheet` customer map in CLAUDE.local.md; unknown customers are asked and persisted. Works with whatever client mix. |
| 2026-08-11 | keithwhatling | Added references/bnext-powerapp-automation.md: reconnaissance of the BNext Power App as an alternative to the F&O grid. Records the app/env ids, the nine-Power-Automate-flow architecture behind it, the three blocked routes (flow payloads unreachable behind a cross-origin iframe, flows not shared, F&O OData 403 on every timesheet entity) with the exact F&O view names an access request would need, the reusable browser-session OData technique, and the page-zoom trap that silently breaks coordinate clicks. |
| 2026-06-19 | keithwhatling | Consistency fix per the user: output format is now a mandated markdown table for EVERY day (chat + saved file), never bullets - replaced the old ASCII-art block with a multi-day markdown example. Added DO rules: keep measured-vs-estimated hours separate and never tune to a standard 7.5/8h day; save drafts to a git-ignored `Timesheets/` folder and untrack any already-committed timesheet. |
