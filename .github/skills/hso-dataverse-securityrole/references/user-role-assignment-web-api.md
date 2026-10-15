# Assigning security roles to users — validated Web API examples

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): known-good,
copy-pasteable calls. Adapt the example; don't compose from scratch. Validated against a real
environment (08 2026) — see [Validation status](#validation-status) for the one claim that is *not*
environment-proven.

This skill's script operations cover roles and **privileges**. Binding a role to a **user** has no
wrapper and does not need one — it is a thin `$ref` association that fails the helper test in
[ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md) Rule 2. The
durable content is the traps below, not the POST.

**Setup** (auth + shared invoker), assumed at the top of each snippet:

```powershell
# the hso-shared-scripts modules are copied to .claude/skills/hso-shared-scripts/scripts in a project,
# and the session's working directory is the repo root — so dot-source by this repo-root-relative path.
$shared = ".claude\skills\hso-shared-scripts\scripts"
. "$shared\Dataverse-Auth.ps1"; . "$shared\Dataverse-WebApi.ps1"
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl
```

Placeholders: `<userId>` / `<roleId>` / `<buId>` = resolved GUIDs; `New Custom Role` = your role name.

> **HSO rule (security SOP):** user-to-role assignments are **environment configuration** — they do
> **not** travel in a solution. Roles and their privileges do; who holds them does not. Provisioning
> is therefore per-environment and must be repeated in each target. Same rule as Field Security
> Profile team assignments — see [`field-security-profiles-web-api.md`](field-security-profiles-web-api.md).

> **A security role is not a licence.** Assigning the correct role does not grant a Power Apps /
> Dynamics licence. A correctly-roled user with no licence is still blocked at the app door, and the
> failure surfaces as an access error that reads like a role problem. When provisioning a cohort,
> confirm licensing separately before reporting the users as ready.

---

## 1. Resolve the users

Accounts are matched on **either** `internalemailaddress` (primary email) or `domainname` (UPN).
These diverge in many tenants — filtering on only one silently misses people:

```http
GET /api/data/v9.2/systemusers?$select=fullname,internalemailaddress,domainname,isdisabled,accessmode,_businessunitid_value&$filter=internalemailaddress eq 'someone@example.com' or domainname eq 'someone@example.com'
```
```powershell
$addr = "someone@example.com"
$f = [uri]::EscapeDataString("internalemailaddress eq '$addr' or domainname eq '$addr'")
$u = Invoke-DataverseApi -Method GET `
    -Endpoint "systemusers?`$select=fullname,internalemailaddress,domainname,isdisabled,accessmode,_businessunitid_value&`$filter=$f"
```

Check `isdisabled` and `accessmode` before assigning — a disabled or non-interactive
(`accessmode` ≠ 0) account will accept the role and still not be able to use the app. Escape the
address for OData: double single-quotes, then URL-encode.

---

## 2. Resolve the role — business-unit aware

In a multi-business-unit org the platform replicates every role into each BU, so `name eq '<x>'`
returns **N copies**. Naïvely taking `[0]` is a latent bug that never shows up in a single-BU test
environment.

**Note the direction, because it is the inverse of the privilege rule.** This skill's
`Find-RoleByName` deliberately resolves to the **root** role (`parentroleid` null) — correct for
*privilege edits*, which belong on the root and cascade to the copies. For a *user assignment* you
want the copy sitting in **the user's own business unit**:

```http
GET /api/data/v9.2/roles?$select=name,roleid,_businessunitid_value,_parentroleid_value,_parentrootroleid_value&$filter=name eq 'New Custom Role' and _businessunitid_value eq <buId>
```
```powershell
$roleName = "New Custom Role"
$f = [uri]::EscapeDataString("name eq '$($roleName.Replace("'","''"))'") 
$roles = (Invoke-DataverseApi -Method GET `
    -Endpoint "roles?`$select=name,roleid,_businessunitid_value,_parentroleid_value&`$filter=$f").value

# pick the copy in the user's BU; fall back to the root role in a single-BU org
$role = $roles | Where-Object { $_._businessunitid_value -eq $userBuId } | Select-Object -First 1
if (-not $role) { $role = $roles | Where-Object { -not $_._parentroleid_value } | Select-Object -First 1 }
if (-not $role) { throw "Role '$roleName' not resolvable for BU $userBuId" }
```

On the **root** role, `_parentroleid_value` is empty and `_parentrootroleid_value` points at itself —
useful for telling a root from a BU copy in the result set.

Do **not** `throw` merely because more than one row came back; in a multi-BU org that is the normal
shape, and a guard written as "multiple roles named X → error" will fail every real environment while
passing every single-BU one.

---

## 3. Assign the role — `systemuserroles_association`

```http
POST /api/data/v9.2/systemusers(<userId>)/systemuserroles_association/$ref
Content-Type: application/json; charset=utf-8
```
```json
{ "@odata.id": "https://yourorg.crm.dynamics.com/api/data/v9.2/roles(<roleId>)" }
```
```powershell
$base = $EnvironmentUrl.TrimEnd('/')
Invoke-DataverseApi -Method POST -Endpoint "systemusers($userId)/systemuserroles_association/`$ref" `
    -Body @{ "@odata.id" = "$base/api/data/v9.2/roles($roleId)" }
```

The `@odata.id` must be an **absolute** URL including the `/api/data/v9.2/` path.

**This call is naturally idempotent.** Re-posting an association the user already holds returns
success and changes nothing — it does *not* error (verified 08 2026). So a pre-check is **not**
required for correctness. It is still worth reading the existing assignments first, for a different
reason: so the run can report *added* versus *already present* instead of reporting every user as
freshly provisioned. Don't describe that guard as error-avoidance.

---

## 4. Read back — what a user actually holds

The POST returning success does not prove the intended end state; read back, in the same spirit as
the role-privilege **depth** read-back gap in [`SKILL.md`](../SKILL.md):

```http
GET /api/data/v9.2/systemusers(<userId>)/systemuserroles_association?$select=name&$orderby=name
```
```powershell
$held = (Invoke-DataverseApi -Method GET `
    -Endpoint "systemusers($userId)/systemuserroles_association?`$select=name&`$orderby=name").value.name
```

The inverse — every user holding a given role — is the query to run before deleting or re-scoping a
role:

```http
GET /api/data/v9.2/roles(<roleId>)/systemuserroles_association?$select=fullname,internalemailaddress,isdisabled
```

---

## 5. Unassign

```http
DELETE /api/data/v9.2/systemusers(<userId>)/systemuserroles_association(<roleId>)/$ref
```

Removing the last role from a user does not disable them; it leaves an account that can sign in and
see nothing. To remove access, disable the user (or remove the licence) rather than only stripping
roles.

---

## Cohort provisioning — recommended shape

Provisioning a group (a test cohort, a new project team) is the common case. Keep it as a
**read → diff → assign → read back** loop rather than a blind assign:

1. Resolve every user first and **report the misses before writing anything** — an address that
   matches nothing is usually a typo or an unlicensed account, and it is much cheaper to surface it
   up front than to discover it half-way through a partially-applied run.
2. Read each user's current roles; compute what is genuinely missing.
3. Assign only the difference, logging `[ADD]` / `[SKIP]` per user per role.
4. Re-read all users at the end and print the final state — the run's evidence.

Because step 3 is idempotent, the whole loop is safely re-runnable, which matters when a cohort
arrives in stages.

---

## Validation status

| Claim | Status |
|---|---|
| `systemusers` lookup on `internalemailaddress` **or** `domainname` | Validated (08 2026) |
| Role select incl. `_parentroleid_value` / `_parentrootroleid_value`; root role self-references | Validated (08 2026) |
| `systemuserroles_association` `$ref` POST assigns the role | Validated (08 2026) |
| Re-posting an existing association is a **silent no-op**, not an error | Validated (08 2026) |
| Read-back via `systemuserroles_association` | Validated (08 2026) |
| **A user assignment requires the role copy in the user's own BU** | **Not environment-proven** — the validating org had a single business unit. The query shape above ran clean; the multi-BU *necessity* is carried over from the platform's role-replication behaviour and this skill's existing root-role resolution note (CHANGELOG 2026-06-13). Confirm against a multi-BU org before relying on it. |
| `DELETE …/systemuserroles_association(<roleId>)/$ref` | Endpoint shape only — not executed |
