# Verification-leg quick client (token-file + curl) — blessed pattern and limits

**Policy decision.** Agents have been observed hand-rolling
Web API clients — python `requests` probes, a token minted to `/tmp/dv_token.txt`, multi-call curl
harnesses — instead of the pwsh skill scripts. Measured trade-off: the ad-hoc calls
are 2–10× faster per call (0.5–2.4 s vs 4.7 s for a pwsh skill-script invocation) and everything
worked; but they bypass the skills' guardrails (publish-collision retries, read-back verification,
`[FATAL]` contracts) and produce non-uniform evidence. Rather than leave each agent to re-decide,
this document makes the call:

## The policy

| Operation class | Surface |
|---|---|
| Read-only probes (metadata checks, state reads, counts, evidence collection) | **Quick client OK** |
| Throwaway test fixtures (records created solely to exercise logic, deleted afterwards) | **Quick client OK — cleanup mandatory** |
| Metadata WRITES (tables, columns, forms, views, sitemaps, flows, plugin registration, security) | **Skill scripts ONLY — never the quick client** |
| Configuration/data changes that outlive the run | **Skill scripts ONLY** |

Rationale: reads and throwaway fixtures carry no drift risk and benefit most from per-call speed
(verification legs are read-heavy). Metadata writes are exactly where the skill guardrails
(read-back, publish ordering, collision retry, naming enforcement) earn their latency.

## The blessed recipe

Mint once per leg with the same SPN the skill scripts use, into a token file; curl with the file.
On a hosted agent the SPN is typically supplied in env vars:

```bash
python3 - <<'EOF'
import os, requests
tenant = os.environ["DATAVERSE_TENANT_ID"]
env_url = os.environ["DATAVERSE_ENVIRONMENT_URL"].rstrip("/")
r = requests.post(
    f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token",
    data={"grant_type": "client_credentials",
          "client_id": os.environ["DATAVERSE_CLIENT_ID"],
          "client_secret": os.environ["DATAVERSE_CLIENT_SECRET"],
          "scope": f"{env_url}/.default"})
r.raise_for_status()
open("/tmp/dv_token.txt", "w").write(r.json()["access_token"])
EOF

TOKEN=$(cat /tmp/dv_token.txt)
ENV="$DATAVERSE_ENVIRONMENT_URL/api/data/v9.2"
curl -s "$ENV/EntityDefinitions(LogicalName='hso_serviceagreement')/Attributes?\$select=LogicalName" \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" | python3 -m json.tool
```

Notes:

- **Token reuse across agents in one run is fine** (the file outlives the minting agent) — tokens
  expire in ~60–75 min; re-mint on a 401.
- On a developer machine (no SPN env vars), get the token from the settings-resolved auth the
  skills use: `. Dataverse-Auth.ps1; Get-DataverseToken -EnvironmentUrl <url>` — do NOT invent a
  third auth path, and never trigger interactive sign-in from a headless leg.
- Batch related reads into one `$batch` or one script block where possible — the verification
  cost driver is turns, not call latency.

## Mandatory cleanup

Before the leg ends:

1. Delete every fixture record the quick client created (keep the IDs as you create them).
2. `rm -f /tmp/dv_token.txt` (and any other token/scratch files).
3. Nothing quick-client-related may be committed: no token files, no probe scripts left in the
   repo tree, no `TestResult.xml`-style residue. `git status --porcelain` must come back clean of
   tool artifacts.

## Evidence discipline

Quick-client evidence is free-form; when a finding will be cited in a report or bug, prefer
re-verifying the final state through the relevant skill script (uniform `[OK]`/`[FATAL]` output)
or quote the exact curl + response in the report so the reader can replay it.
