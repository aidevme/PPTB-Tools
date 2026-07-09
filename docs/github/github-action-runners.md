# GitHub Actions runners: Node.js 20 deprecation

Reference notes on GitHub's Node.js 20 → Node.js 24 migration for Actions runners, condensed from the
[official changelog post](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)
(2025-09-19). Every JavaScript/TypeScript GitHub Action runs on a Node.js runtime bundled with the
Actions runner; GitHub is retiring Node 20 as that runtime and moving to Node 24. This affects **every**
workflow using third-party or first-party JS actions (`actions/checkout`, `github/codeql-action`,
`actions/upload-artifact`, etc.) — not just actions this repo owns — since the *runner*, not the
workflow author, decides which Node runtime an action's JS executes under.

## Timeline

| Date | What happens |
| --- | --- |
| **April 2026** | Node.js 20 reaches end-of-life upstream (no more security patches from the Node.js project itself). |
| **June 16, 2026** | GitHub Actions runners begin defaulting to Node 24 for all JavaScript actions. |
| **Fall 2026** | Migration completes; Node 20 is removed from runners entirely — no opt-out survives past this point. |

## What "deprecated" means in practice

An action's `action.yml` declares which Node runtime it expects (`runs.using: "node20"` or
`"node24"`). Before the runner fully switches over, actions still declaring `node20` are **forced** to
actually execute on Node 24 anyway (the runtime bump happens regardless), but the runner still emits an
end-of-run deprecation warning because the action's own manifest hasn't been updated to declare
`node24`:

> Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on
> Node.js 24: `<action>@<version>`.

This warning is **informational, not a failure** — the job still runs correctly, forced onto Node 24
under the hood. There's a known runner-side quirk here (tracked in
[`actions/runner#4295`](https://github.com/actions/runner/issues/4295)): the action gets flagged as
"targeting Node 20" based on its *declared* version before the runner checks whether it should force
Node 24, so the warning can fire even though the step genuinely executed on Node 24 the whole time.
There's no way to silence the warning from the workflow side — the only real fix is bumping to a
release of the action that has actually updated its `action.yml` to `runs.using: "node24"`.

## Testing Node 24 early

To opt in before the June 2026 default-switch date, set this environment variable — either as an `env:`
entry in the workflow YAML, or as an environment variable on a self-hosted runner machine:

```yaml
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

## Compatibility concerns

- **macOS 13.5+ required.** Node 24 does not run on macOS 13.4 or lower; `macos-latest`-style
  GitHub-hosted runners already satisfy this, but older self-hosted macOS runners may not.
- **No ARM32 support.** Node 24 has no official ARM32 build. Self-hosted ARM32 runners lose support
  once Node 20 is removed in fall 2026 — there's no forward path for that architecture on this runtime.

## What to actually do

- **Action maintainers** (if you publish an action): update it to declare `runs.using: "node24"` and
  bundle/target Node 24 in its implementation.
- **Workflow authors** (this repo's situation): pin to the newest major version of each action you
  consume that has already made the Node 24 migration — check each action's release notes, since "the
  latest major tag" doesn't always mean "already migrated" (see the `upload-artifact` case below, where
  v5 quietly *didn't* default to Node 24 despite being newer than v4).
- **Temporary opt-out after June 16, 2026**, if a workflow breaks and you need breathing room: set
  `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true`. This only works until runners are upgraded again in
  fall 2026 — it is not a permanent escape hatch, and the name is a deliberate signal that running an
  EOL Node runtime is a security posture regression, not a neutral choice.

## Relevance to this repo

`.github/workflows/codeql.yml` hit this warning three separate times as each dependency's Node-24
migration landed at a different pace — worth recording exactly which version fixed which action, since
"bump to latest" isn't reliably the same as "bump to Node-24-native":

| Action | Warned at | Fixed at | Node 24 default since |
| --- | --- | --- | --- |
| `actions/checkout` | `@v4` | `@v5` | v5.0.0 |
| `github/codeql-action/{init,analyze}` | `@v3` | `@v4` | v4 (v3 is being deprecated entirely in December 2026 — a separate, harder deadline than the general runner migration above) |
| `actions/upload-artifact` | `@v4` | `@v6` | v6.0.0 — **not** v5; v5.0.0 added Node 24 as opt-in support only and still defaulted to Node 20, so bumping v4 → v5 alone would not have cleared the warning |

All three bumps needed at least Actions Runner `v2.327.1`, which GitHub-hosted `ubuntu-latest` runners
already satisfy — this only matters for self-hosted runners, which this repo doesn't use.
