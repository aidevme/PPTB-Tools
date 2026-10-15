# Rule catalog

Every rule is **advisory** unless the repo's `solution-security-policy.json` sets
`"enforcement": "block"` for it. Severity is a reader-facing label and gates nothing.

Rule ids are stable. A rule is never renamed once shipped, because suppressions reference it
by id.

---

## Flow egress

### `flow-external-connector`

**Catches:** a flow that declares (in `connectionReferences`) or uses (in an action's
`host.apiId` / `host.connectionName`) a connector that is not on `connectorAllowlist`.

**Why it matters:** this is the "is data leaving Dataverse?" question in its most direct
form. Every connector other than `shared_commondataserviceforapps` is, by definition, a path
to somewhere else. That is frequently legitimate and frequently invisible in review, because
the connector name is buried in a 900-line JSON file nobody opens.

**Not a defect by itself.** The finding says "an egress path exists and nobody has declared
it approved". Resolve it by approving it (add to the allowlist, with a comment naming who
signed off) or by removing it.

**Fix / accept:**
- Approved permanently -> add to `connectorAllowlist`.
- Approved temporarily -> add a suppression with an `expires` date.
- Not approved -> route to the architect. Then confirm the environment's DLP policy would
  have blocked it, because if the scanner is the only thing that caught this, the preventive
  control is missing.

---

### `flow-http-action`

**Catches:** an action of type `Http` or `HttpWebhook`.

**Why it matters:** a raw HTTP action is arbitrary outbound egress to any address the author
types. Crucially, **connector-level DLP does not classify it** the way it classifies
`shared_sql` or `shared_ftp` - it is the standard way to route around a connector policy,
whether deliberately or by accident.

**Fix:** prefer a first-party connector, or wrap the endpoint in a **custom connector** so
DLP can govern it as a connector like any other.

---

### `flow-external-domain`

**Catches:** an HTTP action whose `uri` host is not on `domainAllowlist`.

**Why it matters:** narrows `flow-http-action` to the specific endpoints in play, which is
what a reviewer actually needs to make a decision.

**Limitation, stated plainly:** the host is only extractable when the URI is a literal. A URI
built from an expression (`@{variables('endpoint')}`) yields no host, so this rule sees
nothing and `flow-http-action` is the only signal. Treat a raw HTTP action with a computed
URI as *higher* risk, not lower.

---

### `connectionref-embedded-value`

**Catches:** a connection reference with `runtimeSource: embedded`, or carrying a
`connection.name`.

**Why it matters:** the connection was bound at author time rather than at deploy time. The
solution then carries a specific connection into every environment it is imported to, which
is both an ALM defect and a security one - a DEV connection reaching production data.

**Fix:** move the binding to the deployment settings file. See
[`hso-dataverse-deployment-settings`](../../hso-dataverse-deployment-settings/SKILL.md).

**Overlap:** [`hso-analyze-dataverse-solution-changes`](../../hso-analyze-dataverse-solution-changes/SKILL.md)
reports this too, from a branch diff. Deliberate - this scanner must work standalone.

---

## Secrets

### `flow-embedded-secret` / `settings-literal-secret`

**Catches:** literals matching a secret shape - keyed values (`"password"`, `"clientSecret"`,
`"apiKey"`, `"accountKey"`, `"connectionString"`, ...), storage `AccountKey=`, `Bearer`
tokens, JWTs, SAS `sig=` parameters, and PEM private keys.

Scanned in flow definitions (`flow-embedded-secret`) and in deployment settings, web
resources, and C# source (`settings-literal-secret`).

**Placeholders are excluded:** empty values, `{{token}}`, `#{token}`, `$(var)`, `@{expr}`,
bare GUIDs, and the words placeholder / changeme / example / dummy / sample / todo. Multiple
patterns hitting the same line report once.

**Fix:** move to an environment variable, connection reference, or Key Vault. **Then rotate
the value** - it is in git history regardless of what the working tree now says. A commit
that only removes the literal is not a remediation.

**False positives are expected** on test fixtures and documentation. Suppress those by path,
with an expiry, rather than weakening the pattern.

---

## Web resources

### `webresource-eval`

**Catches:** `eval(` or `new Function(` in a `.js` / `.html` web resource.

**Why it matters:** arbitrary code execution, and blocked by the CSP that model-driven apps
and Power Pages enforce - so it is a functional break as well as a security one. Solution
Checker's `avoid-eval` is Critical and covers the same ground; this rule exists so the scan
is useful before a Solution Checker run has happened.

**Known false positive:** minified/webpack **debug** bundles trip `avoid-eval`. The SOP's §5
answer applies here too - fix the build (`--buildMode production`, webpack
`mode: 'production'`), do not suppress the rule.

---

### `webresource-remote-script`

**Catches:** `<script src="https://...">` pointing at a host outside `domainAllowlist`.

**Why it matters:** the referenced script is outside solution version control. It can change
after the solution ships, with no deployment, no review, and no trace in the repo. This is
the Power Platform shape of a supply-chain risk.

**Fix:** vendor the library into a web resource so it versions with the solution.

---

### `webresource-external-fetch`

**Catches:** `fetch` / `XMLHttpRequest` / `$.ajax` / `axios` against a host outside
`domainAllowlist`.

**Why it matters:** client-side egress, invisible to any server-side control.

**Default severity is `info`** - this one has the highest false-positive rate of the set,
because the regex correlates a call to a nearby URL literal and can pair the wrong two.
Treat it as a pointer to go read the file, not as a finding on its own.

---

## Server-side code

Scanned only under the folders listed in `codePaths`. Silently skipped when they do not
exist, so the scanner stays useful in a config-only repo.

### `plugin-outbound-http`

**Catches:** `new HttpClient`, `new WebClient`, `WebRequest.Create`, `HttpWebRequest`.

**Why it matters:** two distinct problems. Security - a sandboxed plugin reaching an external
endpoint is egress from the platform's trust boundary. Reliability - a synchronous outbound
call inside a plugin risks the published 2-minute execution limit, which is what Solution
Checker's `use-async` rule is about.

**Fix:** move the integration out of the plugin - a flow, a Service Bus / webhook listener,
or an Azure Function. See [`hso-integration-patterns`](../../hso-integration-patterns/SKILL.md).

---

### `plugin-dynamic-execution`

**Catches:** `Assembly.Load`, `Activator.CreateInstance`, `MethodInfo.Invoke`,
`Process.Start`, `Type.GetType(`.

**Why it matters:** the closest thing in this catalog to "potentially malicious code".
Loading an assembly or spawning a process from a plugin is not permitted in the sandbox and
has no legitimate reason to appear in Dataverse plugin code. Reflection is the standard way
to hide what code actually does from a reviewer reading it linearly.

**Expect false positives** from legitimate DI containers and generic factories using
`Activator.CreateInstance`. That is the intended trade - the pattern is rare enough in plugin
code that a human glance is cheap, and the failure mode of missing a real one is severe.

---

## Policy hygiene

### `policy-suppression-expired`

**Catches:** a suppression whose `expires` date has passed, or which has no parseable
`expires` at all.

**Behavior:** the suppression is **ignored** (so the underlying rule re-applies and its
findings return) *and* this finding is raised naming the lapsed exception and its recorded
reason.

**Why it matters:** this implements the SOP's "no silent re-suppression". An exception that
quietly expires into a wall of noise teaches people to ignore the report. An exception that
expires *loudly*, naming who approved it and why, forces the re-justification the SOP asks
for.

**Fix:** re-justify with a new `expires` date, or delete the suppression and fix the finding.
