# Review logs

This folder is the **audit trail** of how each part of the template was built — the record that proves the
result is deliberate and converged, not a first draft. Per ADR-0001 (method), every part goes through:

> `review 3 sources → build → expert self-review (written critique) → improve → re-review → loop until converged`,
> then a whole-solution **integration** loop.

## File naming

```
partN-<area>-01-source-analysis.md     # comparative read of CDX vs HINT vs the live-delivery source + best-in-class recommendation
partN-<area>-02-review-rNN.md          # expert critique of iteration NN of the build (findings, severity, actions)
partN-<area>-03-convergence.md         # final: what changed across iterations, why it is now best-in-class, residual risks
integration-01-review-rNN.md           # whole-solution integration critiques
```

Where `<area>` ∈ `agent | server | client | pipelines | pcf`.

## What a review entry contains

- **Scope**: which files/decisions were reviewed, at which iteration.
- **Findings**: concrete issues, each with a severity (blocker / major / minor / nit) and a file:line or path.
- **What "best-in-class" demands here**: the bar the part is measured against.
- **Actions**: what will change in the next iteration (or "none — converged").
- **Verification**: build/test evidence (`dotnet build`, `npm test`) where applicable.

The parts are indexed from the master `../../PLAN.md` progress tracker.
