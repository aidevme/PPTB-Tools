# Onboarding — read this first

Welcome. This is the guided path for someone joining a project built on the HSO Power Platform template.
It complements the repo overview in the root [`README.md`](../../README.md) with a **role-ordered
reading path** and a day-one checklist.

## Day one — orient (about 30–45 min)

1. **Root [`README.md`](../../README.md)** — what the template is and how the pieces fit.
2. **[`docs/decisions/ADR-0001`](../decisions/ADR-0001-foundational-principles.md)** — the eight
   principles everything obeys (neutral naming, template-not-hardcode, config-driven, one-source→two-tools,
   core/project skills, buildable+tested).
3. **[`ADR-0002`](../decisions/ADR-0002-canonical-repo-structure.md)** — where everything lives.
4. **[`ADR-0003`](../decisions/ADR-0003-naming-and-token-contract.md)** — the naming/token contract. Read
   this before you touch any file: it explains `HSO.Customer.*`, `hso_customer_*`, and the config chain a
   rename must keep coherent.
5. **`agent/schema.md`** — how the knowledge wiki works (you'll read and write it daily).

## Then — go deep where you'll work

| If you work on… | Read | ADR |
|---|---|---|
| **Plugins / services (C#)** | [`server.md`](server.md) | [0004](../decisions/ADR-0004-server-architecture.md) |
| **Form scripts / web resources (TS)** | [`client.md`](client.md) | [0005](../decisions/ADR-0005-client-architecture.md) |
| **PCF controls** | [`pcf.md`](pcf.md) | [0006](../decisions/ADR-0006-pcf-architecture.md) |
| **Pipelines / ALM / deploys** | [`pipelines.md`](pipelines.md) | [0007](../decisions/ADR-0007-pipeline-architecture.md) |
| **The AI agent / skills / wiki** | [`agent.md`](agent.md) | [0008](../decisions/ADR-0008-agent-sync-mechanism.md) |
| **Starting a brand-new project** | `ProjectTemplate/InitializeProjectScript/HANDOVER-RUNBOOK.md` | [0009](../decisions/ADR-0009-initialization-and-coherence.md) |

## The golden rules (memorise these)

- **Never put a real customer name (or a source client's name) in template files.** Use the ADR-0003
  tokens; the init engine rewrites them. The project/customer name itself is one of those tokens —
  `Customer` / `{CustomerName}` — set **per project** by
  `ProjectTemplate/InitializeProjectScript/Initialize-CustomerProject.ps1` (ADR-0003); the project name is
  already an init-set token, so there is no separate naming skill.
- **Dev is the only environment you write to.** UAT/Prod change only through the pipelines, with an
  explicit go, and the Production gate is approved by a human — never the agent.
- **Don't hand-edit generated files** — the Claude/Copilot views (`.claude/skills`, `.github/skills`,
  `CLAUDE.md`, `copilot-instructions.md`) come from `agent-src/`; the pipeline marker-block interiors come
  from the config. Change the source, re-generate.
- **Server layering is a test, not a suggestion** — no CRUD in the BusinessLogic layer (enforced by
  `LayeringTests`).
- **Build before you believe it.** Every part has passing local build/test; keep it that way.

## Where the reasoning lives

Every part's decision record is in [`docs/decisions/`](../decisions/); the full build audit trail — source
analysis, expert-review iterations, convergence — is in [`docs/review-logs/`](../review-logs/). The live
build status is in [`PLAN.md`](../../PLAN.md).
