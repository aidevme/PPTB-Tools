---
name: hso-solution-security-scan
layer: atomic
scope: core
description: |
  Static security scan of an unpacked Dataverse solution tree - the risk surface Solution
  Checker does not cover. Reports which Power Automate flows reach OUTSIDE Dataverse
  (connector egress), what external domains they call, secrets committed as literals, and
  risky patterns in web resources and plugin source. Produces a markdown report suitable for
  a PR comment plus a JSON report for pipelines. Use when: (1) user asks to "scan the
  solution for security issues", "check what our flows connect to", "find secrets in the
  solution", or "run the security scan"; (2) reviewing an export PR before merge;
  (3) wiring a security gate into a build pipeline. EVERY RULE IS ADVISORY by default -
  findings block a build only where a human explicitly set "enforcement": "block".
---

# Solution Security Scan

Solution Checker is Microsoft's static analysis of solution **code and metadata patterns**.
It says nothing about **where a solution sends data**. This skill fills that gap: it reads an
unpacked solution tree and reports the egress and secret-exposure surface.

> **Read first:** [`solution-checker-and-component-validation-best-practices.md`](../../../agent/wiki/sop/dataverse-solutions/solution-checker-and-component-validation-best-practices.md)
> is the authority for Solution Checker itself, its severity policy, and its suppression
> rules. This skill is a **complement**, not a replacement - see [Boundaries](#boundaries).

## Enforcement model - read this before wiring it into a pipeline

The governing rule, deliberate and non-negotiable in the default configuration:

> **Everything is informational or a warning. Nothing is a hard stop unless a human has
> explicitly declared it one.**

Concretely:

| Layer | Behavior |
|---|---|
| Rule default | `"enforcement": "warn"` - reported, never fails the caller |
| Explicit block | Only a human editing `solution-security-policy.json` to `"enforcement": "block"` makes a rule enforcing |
| Rule off | `"enforcement": "off"` removes the rule from the run entirely |
| New rules | A rule added in a future version of this skill lands as `warn`. Upgrading the scanner can never turn a green build red on its own. |
| Caller override | `-FailOn None` guarantees exit 0 regardless of policy. Use it for the first pilot run. |

Severity (`error` / `warning` / `info`) is the **reader-facing label only**. It does not gate
anything. A rule can be `severity: error, enforcement: warn` - that means "this is serious,
go look at it", not "the build stops".

### Why default-advisory

An egress finding is not a defect. `shared_sql` in a flow is a fact about the design; whether
it is *acceptable* depends on the DLP policy, the environment, and the contract. A scanner
that guesses wrong and blocks the build gets switched off within a sprint, and then you have
no report at all. Advisory-by-default keeps the report in front of reviewers, and lets each
project promote the handful of rules it genuinely wants enforced.

## Where the script lives

**`DeploymentScripts\Invoke-SolutionSecurityScan.ps1`** in the consumer repo - a real
committed file, not a skill junction.

This is deliberate and load-bearing. `.claude\skills\` in a consumer repo is a per-machine,
**gitignored** junction (ADR 0034), so it does not exist on a build agent that cloned from
git. A pipeline step pointing into `.claude\skills\...` fails on the agent while working
perfectly on the developer machine that wrote it. The script is therefore maintained in this
repo at
[`hso-dataverse-init-repo/assets/DeploymentScripts/`](../hso-dataverse-init-repo/assets/DeploymentScripts/Invoke-SolutionSecurityScan.ps1)
and scaffolded into every consumer repo by `Initialize-DataverseRepo.ps1`, alongside the
other deployment scripts the pipelines call.

## Running it

```powershell
# Consumer repo - advisory scan of .\Solutions using the repo policy
powershell -ExecutionPolicy Bypass -File .\DeploymentScripts\Invoke-SolutionSecurityScan.ps1

# First run on an existing project - guarantee it cannot fail anything
.\DeploymentScripts\Invoke-SolutionSecurityScan.ps1 -FailOn None

# Pipeline use - JSON only, honor the policy's block declarations
.\DeploymentScripts\Invoke-SolutionSecurityScan.ps1 -Format json -Quiet
```

Run it from the repo root - the working directory is what the scanner treats as the repo root
for relative paths and for finding `solution-security-policy.json`.

| Parameter | Default | Notes |
|---|---|---|
| `-SolutionPath` | `Solutions` | Root holding unpacked solution folders. A solution folder is one containing `Other\Solution.xml`; if none are found, the path itself is scanned. |
| `-PolicyPath` | repo root `solution-security-policy.json`, then the skill template, then a built-in all-advisory default | The scan always runs; an unconfigured repo simply cannot fail it |
| `-OutputPath` | `<SolutionPath>\.security` | |
| `-Format` | `both` | `md` \| `json` \| `both` |
| `-FailOn` | `Block` | `None` \| `Block` \| `Warning` \| `Any` |
| `-Quiet` | off | Suppress console summary; reports and exit code unaffected |

**Exit codes:** `0` threshold not exceeded - `1` threshold exceeded - `2` scanner error.

No authentication, no network, no Dataverse connection. Pure file parsing, so it runs on a
build agent with nothing installed and on a developer machine before a commit.

## Policy file

Copy [`assets/solution-security-policy.json`](assets/solution-security-policy.json) to the
consumer repo root and edit. Four sections:

- **`connectorAllowlist`** - connectors that are *expected*. Anything else raises
  `flow-external-connector`. Ships with the Dataverse/M365 first-party set. Wildcards allowed
  (`shared_hso*`).
- **`domainAllowlist`** - hosts a raw HTTP action may call. Wildcards allowed; `*.contoso.com`
  also matches the apex `contoso.com`.
- **`codePaths`** - folders scanned for C# plugin source. Skipped silently when absent.
- **`rules`** - per-rule `severity` + `enforcement`.
- **`suppressions`** - see below.

### Suppressions

Modeled on the Solution Checker SOP's §6 expiration policy, and enforced the same way:

```json
{
  "rule": "flow-external-connector",
  "path": "Solutions/Sales/Workflows/*.json",
  "match": "shared_ftp",
  "reason": "Vendor SFTP drop approved in ARB-2026-14.",
  "approvedBy": "architect@hso.com",
  "expires": "2027-06-30"
}
```

- `expires` is **required**. A suppression with a missing or unparseable date is **not
  honored** - the finding comes back.
- An expired suppression is ignored *and* raises `policy-suppression-expired`, so a lapsed
  exception surfaces rather than silently reverting to noise. No silent re-suppression.
- `path` is a wildcard against the repo-relative path; `match` is an optional substring test
  against the finding's evidence.

## Rules

Full catalog with rationale and fixes: [`references/rules.md`](references/rules.md).

| Rule | Catches |
|---|---|
| `flow-external-connector` | Flow declares or uses a connector outside the allowlist |
| `flow-http-action` | Raw `Http` / `HttpWebhook` action - egress no connector DLP policy classifies |
| `flow-external-domain` | HTTP action targets a host outside the domain allowlist |
| `flow-embedded-secret` | Secret-looking literal in a flow definition |
| `connectionref-embedded-value` | Connection reference bound at author time instead of deploy time |
| `settings-literal-secret` | Secret-looking literal in deployment settings, web resources, or code |
| `webresource-eval` | `eval()` / `new Function()` in a web resource |
| `webresource-remote-script` | Web resource loads script from a remote origin |
| `webresource-external-fetch` | Web resource calls an external origin directly |
| `plugin-outbound-http` | `HttpClient` / `WebClient` / `WebRequest` in server-side code |
| `plugin-dynamic-execution` | Reflection invoke, `Assembly.Load`, `Process.Start` in server-side code |
| `policy-suppression-expired` | A suppression lapsed and was ignored |

The flow walker descends into `Scope`, `If`/`else`, `Switch` cases and `default`, and
`ForEach`/`Until` bodies, so a connector buried four containers deep is still found.

## Boundaries

**This is a risk-surface report against a declared allowlist. It is not malware detection.**
It catches the careless and the undeclared. A motivated insider who wants to exfiltrate data
through an allowlisted connector will not be caught by static analysis, and the report should
never be presented as though they would be.

The preventive control is a **DLP policy** in the Power Platform admin center - connector
classification so an unapproved pairing cannot be saved at all. See
[`power-automate-alm-and-governance.md`](../../../agent/wiki/sop/power-automate/power-automate-alm-and-governance.md)
and [`environment-strategy-best-practices.md`](../../../agent/wiki/sop/environment-strategy/environment-strategy-best-practices.md).
This scanner is the **detective** half: it proves what shipped and produces the audit trail.

### Related skills - what this does NOT do

| Concern | Skill |
|---|---|
| Solution Checker rules, deprecated APIs, plugin patterns | Microsoft Solution Checker via the build pipeline; policy in the SOP |
| Branch-to-branch component diff, segmentation, naming | [`hso-analyze-dataverse-solution-changes`](../hso-analyze-dataverse-solution-changes/SKILL.md) |
| C# plugin architecture and layering review | [`hso-plugin-code-review`](../hso-plugin-code-review/SKILL.md) |
| Flow behavior documentation | [`hso-dataverse-flow-docs`](../hso-dataverse-flow-docs/SKILL.md) |
| Pipeline authoring | [`hso-dataverse-pipelines`](../hso-dataverse-pipelines/SKILL.md) |

`connectionref-embedded-value` overlaps deliberately with the PR-analysis skill: this scanner
must be useful standalone, on a machine with no git history to diff against.

## Pipeline wiring

[`SecurityScan.yaml`](../hso-dataverse-init-repo/assets/Pipelines/SecurityScan.yaml) is the
ADO template. It runs advisory by default and publishes both reports as build artifacts.
See that file's header for the PR-comment step and how to promote it to a branch policy.

## After a run

1. Read `<SolutionPath>/.security/solution-security-scan.md`.
2. Present the summary table, and lead with anything under **Blocking findings**.
3. For each egress finding, ask the real question: *is this connector supposed to be here?*
   - Yes -> add it to `connectorAllowlist` with a comment naming who approved it.
   - Yes, but temporarily -> add a suppression with an `expires` date.
   - No -> that is a genuine finding; route it to the architect.
4. Never edit the report by hand. It is regenerated on every run.
