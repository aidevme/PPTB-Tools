---
title: Event Log
type: system-state
status: active
scope: project
created: 2026-09-10
updated: 2026-09-10
---

# Log

Append-only event stream, **newest at the top**. Each entry:

```
## [YYYY-MM-DD] <kind> | <subject> | <title>
<optional detail / link>
```

`<kind>` ∈ { ingest, decision, milestone, spec, design, build, test, deliverable, lint }.

---

## [2026-09-10] milestone | agent-layer | Wiki scaffolded from the template
Project-tier `agent/` wiki initialised (schema, README, index, empty raw/_inbox/wiki/work layers).
Product tier is inherited via `shared/dv/agent/wiki/`. First real entries land as work begins.
