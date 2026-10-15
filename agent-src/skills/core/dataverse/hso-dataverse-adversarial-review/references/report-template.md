# Report template — findings.md structure, JSON schema, severity rubric, owner routing

Authority for the skill's Phase 7 — read before writing the report. The report is **triage input for the architect**: every finding must be actionable by someone who did not run the review.

## Severity rubric

| Severity | Meaning | Test |
|---|---|---|
| **S1 Blocker** | A persona cannot reach or complete a promised FR at all | The walk dies — no navigation node, no command, broken artifact, or wrong result on the primary path |
| **S2 High** | The FR completes only via a path the persona doesn't have (admin help, direct URL, advanced find), or scope/correctness is violated | Workaround exists but is not the promised path; or a user sees data/results they shouldn't, or wrong totals |
| **S3 Medium** | The story degrades: meaningless/degenerate data on a promised surface, an invisible failure path, or a promise no acceptance line ever verified (behavior plausibly works but is unproven) | The persona can proceed, but the artifact can't demonstrate or prove its claim |
| **S4 Low** | Polish: demo realism, labels, documentation, minor layout vs the brief's intent | No FR is at risk |

Calibration rules:

- Severity is judged from the **persona's seat**, not the engineer's. A server that correctly refuses with an error the user never sees is S3, not a pass.
- An **unverified promise** (family E) defaults to S3; raise to S2/S1 only when the env shows the behavior actually fails, in which case it usually becomes a family A–D finding instead.
- A **degenerate dataset** on a demo-facing artifact defaults to S3; raise to S2 when the artifact's entire purpose is the missing dimension (e.g. a "5-year trend" with one FY).
- A **standards violation** (family F) defaults to S2; raise to S1 when it renders delivered scope unusable-by-standards (e.g. admin-maintained reference data shipped as free-text columns — the data model itself must be rebuilt); S3 for deviations from advisory-level SOP guidance recorded without a waiver. Family-F severity is judged against the SOP, not against whether the spec's own promises still hold.

## Owner routing (exactly one per finding)

| Owner | Meaning | Typical fix |
|---|---|---|
| `spec-gap` | The brief promises it; no spec slice ever designed it — or the spec's design violates a mandatory SOP (family F), regardless of how faithfully it was built | Architect: spec delta + new slice |
| `build-gap` | The spec declares it; the env doesn't honor it (missing, inactive, mis-wired) | Executor slice / remediation script |
| `data-gap` | Artifact is correct; the dataset is empty/degenerate/unrepresentative | Sample-data package augmentation |
| `manual-followup` | Needs a human: client decision, licensing, visual/UX judgment, or a scoped test principal that only an admin may create | Named action for the architect/PM |

## findings.md structure

```markdown
---
title: "Adversarial Review — <Feature>"
type: analysis
status: active
scope: project
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# Adversarial Review — <Feature>

**Feature:** <name> (spec: <path>, brief: <path>) · **App:** <AppUniqueName> · **Env:** <url>
**Mode:** ReadOnly | WriteProbes · **Run (UTC):** <start>–<end> · **Reviewer:** <skill name + version/date>

## Verdict

One paragraph: can the brief's personas live this feature today? The single worst finding, the count by severity, and the dominant gap family.

## Findings summary

| ID | Sev | Family | Persona | FRs | Title | Owner |
|---|---|---|---|---|---|---|

## Findings

### F-<NN> · <S?> · <family> — <title>
- **Persona / scenario step:** <who> at <which step of which FR walk>
- **Promise:** <verbatim quote from brief/spec, cited>
- **Acceptance coverage:** <verbatim acceptance line, or NONE>
- **Observed:** <what the env actually shows>
- **Evidence:** <query/script + response excerpt + UTC timestamp; re-verified <UTC timestamp>>
- **Owner:** <spec-gap | build-gap | data-gap | manual-followup>
- **Suggested fix:** <one line — a suggestion, not a work item>

For family-F findings, **Promise** is replaced by **Standard:** <the SOP section violated, quoted verbatim with file + §>, and **Observed** quotes the spec decision and/or built artifact that violates it.

## Standards grounding (REQUIRED — a report without this section is an invalid review)

One row per area the feature touches: the mandatory SOP(s) loaded and the sections read. This is the family-F foundation and the dispatching orchestrator's rejection criterion — an empty or missing table means the review must be re-dispatched, and the pipeline ledger records this list with the Stage-2 entry.

| Area touched | SOP loaded | Sections read |
|---|---|---|

## Accepted boundaries (NOT findings)

Spec-recorded deferrals/boundaries confirmed as recorded — quote the spec text and the env evidence that the boundary holds.

## Fixed-before-review (NOT findings)

Known past gaps verified as fixed live — cite the fix evidence and the fresh read-back.

## Pass evidence

One line per executed check that held, with its query + timestamp. This section is what makes "no findings" credible.

## Stats

Checks executed / passed / findings by severity / by family / by owner.
```

## findings.json schema

```json
{
  "feature": "<name>",
  "spec_path": "<path>", "brief_path": "<path>",
  "app": "<AppUniqueName>", "environment": "<url>",
  "mode": "ReadOnly|WriteProbes",
  "generated_utc": "<ISO8601>",
  "skill": "hso-dataverse-adversarial-review",
  "findings": [
    {
      "id": "F-01",
      "severity": "S1|S2|S3|S4",
      "family": "A-surfacing|B-command-surface|C-data-semantics|D-scenario-walk|E-acceptance-gap|F-standards-conformance",
      "title": "",
      "persona": "",
      "fr_refs": ["FR-XXX-n"],
      "scenario_step": "",
      "promise": "<verbatim, with source>",
      "acceptance_coverage": "<verbatim line or NONE>",
      "observed": "",
      "evidence": [ { "query": "", "excerpt": "", "timestamp_utc": "" } ],
      "reverified_utc": "",
      "owner": "spec-gap|build-gap|data-gap|manual-followup",
      "suggested_fix": ""
    }
  ],
  "standards_grounding": [ { "area": "", "sop": "", "sections": "" } ],
  "accepted_boundaries": [ { "boundary": "<spec quote>", "evidence": "" } ],
  "fixed_before_review": [ { "gap": "", "fix_evidence": "", "readback_utc": "" } ],
  "passes": [ { "check": "", "query": "", "timestamp_utc": "" } ],
  "stats": { "checks": 0, "passes": 0, "findings_by_severity": {}, "findings_by_family": {}, "findings_by_owner": {} }
}
```

Rules:

- IDs are stable within a report (`F-01`…); the consolidating orchestrator namespaces them per feature.
- `standards_grounding` is **non-empty** — an empty list means family F never ran, the review is invalid, and the orchestrator rejects and re-dispatches it.
- `promise` and `acceptance_coverage` are **verbatim quotes** — paraphrase kills triage. On a family-F finding, `promise` carries the **SOP section violated** (verbatim, with file + §) and `observed` quotes the offending spec decision / built artifact; env re-verification applies to the artifact side, the SOP quote is re-read at report time.
- Every finding has ≥1 evidence entry AND a `reverified_utc` newer than the first capture.
- Findings that failed re-verification are dropped, not downgraded.
- One finding per root cause: if a missing sitemap node hides three views, that is ONE family-A finding listing all three artifacts and all affected FRs.
