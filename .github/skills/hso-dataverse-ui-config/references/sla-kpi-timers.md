# SLA KPI timers on a case (incl. setting them live for a demo)

The "Response By / Resolve By" **countdown timer** at the top of a Case form is the **Enhanced SLA** timer control reading `slakpiinstance` rows linked to the record. Two things must both be true for it to render: an **active SLA is applied** AND the **form carries the timer control**.

## Which case forms show the timer

Verify by searching the form's `formxml` for `TimerControl` / `msdyn_slakpi` / `SLA`. On a standard CS-enabled org:
- **Have it**: `Case`, `Case - HSO`, `Case | Extended`, `Enhanced full case form` (+ the interactive variants).
- **Lack it**: `Enhanced quick case form`, `Case for swarming`, `Case for Customer Card`.
- `isdefault` is usually unset on OOB incident main forms (order is managed separately) — so don't rely on it; just ensure the demo opens a timer-bearing form, and use the **form selector** (Case / Case - HSO) as the fallback.

## How the timer reads the data

- `incident._slaid_value` / `_slainvokedid_value` = the applied SLA (e.g. OOB **"Primary Case SLA"**, active, default).
- `incident.firstresponsebykpiid` / `resolvebykpiid` → the **active** `slakpiinstance` rows.
- The timer renders each instance's countdown from its **`failuretime`** (red breach) / **`warningtime`** (amber), gated by **`status`** (In Progress / Nearing noncompliance / Succeeded / Noncompliant / Canceled). Only In-Progress instances show as a live countdown; **Canceled** ones are superseded clutter.

## Making the timer live for a specific demo time (demo data technique)

The SLA computes `failuretime` from the case's create date + SLA terms, so an old case shows **breached** timers. To present a clean, counting-down clock at a fixed demo time:

1. **Delete the stale `Canceled` `slakpiinstance` rows** for the case (so only the live ones show).
2. **PATCH the In-Progress instances' `warningtime` + `failuretime`** to values comfortably **after the demo start time** (`slakpiinstance.failuretime` / `warningtime` are **API-writable**). Give headroom for the run length (e.g. Response By a few hours out, Resolve By a few days). Keep `status` = In Progress.
3. The case's `firstresponsebykpiid` / `resolvebykpiid` already point at those instances — no repointing needed.

> ⚠️ This is **time-anchored demo data** — valid only for the targeted demo date/time. If the slot moves, re-anchor the two instances. Log the assumption (see `hso-presales-demo-architect` → demo-data-fidelity §2).

| Date | Author | Description |
|------|--------|-------------|
| 2026-06-11 | Meghan Reed | Initial — which case forms carry the timer; how the timer reads `slakpiinstance`; and the delete-Canceled + re-anchor-`failuretime` technique to set a live countdown for a fixed demo time. |
