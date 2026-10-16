---
title: "Onboarding — the agent layer"
author: maciejnowicki
type: analysis
status: active
created: 2026-09-10
scope: template-build
dimension: agent-tooling
---

# Onboarding — the agent layer

How the AI-assistant layer of this template fits together, and what to do when you join a project or
change a skill. Full rationale: [ADR-0008](../decisions/ADR-0008-agent-sync-mechanism.md); repo
structure: [ADR-0002](../decisions/ADR-0002-canonical-repo-structure.md); tokens:
[ADR-0003](../decisions/ADR-0003-naming-and-token-contract.md).

## The one rule

**Edit the source, then sync. Never edit a generated file.**

| You want to change… | Edit this SOURCE | Then run |
|---|---|---|
| Assistant instructions | `AGENTS.md` (root) | `pwsh -File agent-src/sync/sync.ps1` |
| A skill | `agent-src/skills/<scope>/<group>/<name>/` | `sync.ps1` |
| Which skills exist / their scope | `agent-src/sync/skills-manifest.json` | `sync.ps1` |

Generated (do **not** hand-edit): `CLAUDE.md`, `.github/copilot-instructions.md`, `.claude/skills/`,
`.github/skills/`.

## What generates what

```
AGENTS.md ───┐                          ┌─▶ CLAUDE.md            (Claude preamble + AGENTS.md body)
             ├─ sync.ps1 ──────────────▶┤
preambles/ ──┘                          └─▶ .github/copilot-instructions.md

agent-src/skills/core/**  ─┐
                           ├─ sync.ps1 ─▶ .claude/skills/**  ==  .github/skills/**   (byte-identical)
agent-src/skills/project/**┘
```

`verify-parity.ps1` then proves the outputs match the source (MD5) — **fail on any drift**.

## First-run checklist (new clone / new machine)

1. **Provision the inherited product tier** (`shared/`). The wiki and core skills read
   `shared/dv/agent/wiki/...`. Point the junction at your local product-tier repo:
   ```powershell
   cmd /c mklink /J shared\dv "C:\path\to\your\product-tier\repo"
   pwsh -File agent-src/sync/check-shared.ps1 -Strict   # must exit 0
   ```
2. **Generate the tool outputs:** `pwsh -File agent-src/sync/sync.ps1`
3. **Verify:** `pwsh -File agent-src/sync/verify-parity.ps1` (expect "PARITY OK").
4. **git ignores** — ensure the root `.gitignore` contains at least:
   ```
   Worklog/
   .worktrees/
   shared/
   CLAUDE.local.md
   .github/copilot-instructions.local.md
   ```
   (The generated `.claude/skills`, `.github/skills`, `CLAUDE.md`, and `copilot-instructions.md` are
   **committed** so the tools work on a fresh clone; the parity gate keeps them honest. If your team
   prefers to treat them as pure build artifacts, gitignore them and run `sync.ps1` post-clone.)

## Adding a skill

1. `aidevme-skill-creator` with a **required** `--scope core|project`.
   - `core` → `agent-src/skills/core/<group>/` (reusable; round-trips to `shared/`).
   - `project` → `agent-src/skills/project/` (engagement-specific; never upstream).
   - Rule: a skill naming a client, env URL, pipeline ID, or sprint convention is `project`.
2. Register it in `skills-manifest.json` (`scope`, `group`, `ported: true`).
3. `sync.ps1` → `verify-parity.ps1` (must be clean).

## The wiki (`agent/`)

Four layers — `raw/` (immutable + captures) · `_inbox/` (transient) · `wiki/` (durable knowledge) ·
`work/` (deliverables). Rules and the linter invariants: [`agent/schema.md`](../../agent/schema.md).
Product-tier SOPs/topics are inherited at `shared/dv/agent/wiki/`. Start any task at the topic anchor
for the subject; append to `agent/log.md` on every significant write.

## CI / pre-commit

Wire `pwsh -File agent-src/sync/verify-parity.ps1` (drift = non-zero = block) and
`pwsh -File agent-src/sync/check-shared.ps1 -Strict` (in environments that must have the product tier)
into the pipeline and the pre-commit hook.
