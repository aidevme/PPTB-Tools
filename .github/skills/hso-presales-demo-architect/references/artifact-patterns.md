# Demo Artifact Patterns

Reference patterns derived from validated prior-engagement demo artifacts.

---

## Demo Outline Pattern

Plain text format (no markdown headings). Structured as:

```
End-to-End [Solution Name] Demo ([duration])
Scenario
[Narrative description of the demo scenario — who is the customer, what failed, what the SLA is, what we will follow through the demo]

[N]. [Phase Name] – [Short description] ([duration])
   • [Capability 1]
   • [Capability 2]
   • [Capability 3]

[N]. [Phase Name] – [Short description] ([duration])
   • ...

Key Messages
• [Message]
• [Message]
```

**Example section:**

```
2. Manage – Intelligent Scheduling & Dispatch (20 min)
• Real-time scheduling board + GPS tracking
• AI-based resource optimization (skills, location, SLA, parts)
• Route optimization + multi-stop planning
• Workforce visibility (900 internal / 400 external techs)
```

**What NOT to do in the outline:**
- Don't use markdown headers or bold/italic
- Don't list individual UI steps — that belongs in the clickpath
- Don't exceed ~60 words per phase section
- Don't include SAY/SHOW/CLICK notes

---

## Presenter Clickpath Pattern

Plain text format. All-caps section headers. Structured in parts.

### Header block

```
[TITLE IN CAPS]
Duration: [X-Y] minutes | Audience: [Audience type]

DEMO SCENARIO
Customer: [Fictional company] ([Tier/context])
Issue: [Asset/incident description]
SLA: [Response time] / [Resolution time]
```

### Part header

```
PART [N]: [NAME IN CAPS] ([total time])
RFP: [section numbers if applicable]
```

### Subsection

```
[N.n] [Subsection Name] ([time])
SHOW: [What to navigate to]
CLICK THROUGH: [numbered step] [step]...
○ [what appears on screen]
○ [what appears on screen]
SAY: "[Punchy 1–3 sentence talking point]"
```

**Example subsection:**

```
1.2 AI Case Creation (5 min)
SHOW: Create case with Copilot
CLICK THROUGH: 1. Agent creates case 2. Copilot suggests:
○ Similar past cases
○ Knowledge articles
○ Resolution (terminal swap)
○ Time estimate 3. Auto-classification 4. SLA validation (4-hour for Tier 1)
SAY: "AI helps agents work smarter. Faster resolution, better experience."
```

### Optional section marker

```
PART 7: INNOVATION (10 min) [Optional - can shorten]
```

or on a subsection:

```
2.4 Fleet Management (4 min) [Can shorten]
```

### Closing blocks

```
TIMING GUIDE
Section Time Flexible?
[Part name]   X min   [No / Cut Y (save Z min)]
TOTAL         X min   Can cut to Y min
Target: [X] minutes with flexibility
```

```
KEY MESSAGES (Reinforce Throughout) 1. [Theme] - [Explanation] 2. ...
```

```
Q&A
BE READY FOR:
• [Likely hard question]
HAVE READY:
• [Prep item]
```

---

## Voice and Tone

**SAY lines should be:**
- First person from the presenter's perspective (not "the system will...")
- Short, punchy, memorable — "One click. System handles the rest."
- Tied to a client pain point or requirement where possible
- Active voice

**CLICK THROUGH steps should be:**
- Specific enough that someone could do this cold in the demo environment
- Use actual UI element names, not generic descriptions
- Ordered logically (what you see first → what you click → what appears)

**Capability bullets (outline) should be:**
- Noun phrases ("AI-assisted case creation") not verb phrases ("Shows AI case creation")
- Scannable at a glance
- Ordered: data entry / intake → processing → output / visibility

---

## Common Part Structure for Field Service Demos

Two validated structures. Choose based on client type.

### Pattern A: Single-Customer End-to-End Flow

Use when the demo follows one customer / one product / one incident through the full lifecycle. Validated on a prior client engagement.

| Part | Theme | Typical Duration |
|------|-------|-----------------|
| Intro | Platform overview, scenario setup | 10 min |
| Part 1: Intake | Contact center, case creation, work order | 15 min |
| Part 2: Manage | Scheduling board, dispatch, workforce | 20 min |
| Part 3: Deliver | Mobile, field execution, asset scanning | 20 min |
| Part 4: Close | RMA, depot operations, repair lifecycle | 15 min |
| Part 5: Analyze | Dashboards, drill-through, AI insights | 15 min |
| Part 6: Foundation | Contracts, compliance, integration, security | 15 min |
| Part 7: Innovation | Copilot, predictive, low-code (optional) | 10 min |
| Part 8: EOL | End-of-life workflows (optional) | 3 min |
| Closing | RFP coverage recap, timeline, next steps | 10 min |

---

### Pattern B: Multi-Brand Franchise Flow

Use when the client is a franchise operator evaluating a platform that must support multiple different service models simultaneously. Validated on a prior client engagement.

**Core design rule:** Choose one anchor brand as the primary journey thread. Weave secondary brand callouts at natural transition points throughout — do not run separate second demos per brand.

| Part | Theme | Typical Duration |
|------|-------|-----------------|
| Intro | Platform framing, capability scorecard, guardrail | 10 min |
| Part 1: Customer Journey | Self-service portal, booking, service history | 15 min |
| Part 2: Intake | Lead to opportunity, brand-aware routing | 10 min |
| Part 3: Service | Work orders, agreements, cadence, schedule board, RSO | 20 min |
| Part 4: Field Execution | Mobile app, checklist, compliance, completion | 25 min |
| Part 5: Communications | Notification chain, two-way SMS, review request | 15 min |
| Part 6: Billing | Invoice automation, payment methods, accounting sync | 15 min |
| Part 7: Reporting | Cross-brand dashboards, franchise roll-up, drill-through | 10 min |
| Part 8: Platform Config | Field governance, advisor access, extensibility | 10 min |
| Part 9: Innovation | Copilot, predictive, low-code (optional) | 10 min |
| Closing | Coverage recap, phased implementation, next steps | 10 min |

**Brand callout structure** (within each segment):

```
BRAND CALLOUTS:
• [Brand]: "[One-sentence callout — 'For [Brand], this becomes [variant]']"
• [Brand]: "[One-sentence callout]"
```

Place brand callouts immediately after the SAY line for the anchor brand. Limit to 2–4 per segment. Do not pivot into a full second demo — keep callouts to 30–60 seconds each.

**Positioning guardrail language** (use in Introduction):

```
SAY: "Where something belongs in a later implementation phase rather than a live pre-sales demo, we will call that out directly. Our platform analysis covers [N] requirements across [N] brands. [X]% of those requirements are addressed natively or through standard configuration. That is the story we will show today."
```

---

## Additional Required Closing Sections

These sections are required in all Presenter Clickpaths where demo data has been pre-seeded.

### Recovery Moves

```
RECOVERY MOVES

[Failure scenario] → [Recovery language and navigation alternative]
[Failure scenario] → [Recovery language and navigation alternative]
```

Common recovery scenarios to anticipate:
- Schedule board slow or unstable → navigate to bookings list view
- Portal login fails or redirects incorrectly → skip to back-office and revisit at end
- A record is thin / missing data → stay at business outcome level, do not drill into blank sections
- Audience goes off-script on out-of-scope topic → use explicit future-design language, do not improvise capability claims
- Asked what is live vs. mocked → answer directly; do not deflect

### Record Quick Reference

```
RECORD QUICK REFERENCE

[Anchor brand] Records
[Record type]: [Name] — [Purpose / note]
...

Cross-Brand Callout Records
[Brand]: [Record name] — [Use for]
...

Schedule Board Resources
[Name] — [Current booking status]
...

IMPORTANT: [Any date-anchor notes — e.g., "Bookings seeded with [date] as today. Update before demo day."]
```
