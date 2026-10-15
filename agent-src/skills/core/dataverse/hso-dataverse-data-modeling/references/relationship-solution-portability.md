# Relationship solution-portability: add parent tables to the solution *first*

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md), this is **orchestration of
operations that already exist** — not a new wrapper. The capabilities are already there:

- `AddTableToSolution` — adds a table to the solution **metadata-only** (`-DoNotIncludeSubcomponents $true`, the default).
- `CreateRelationship` (OneToMany / Customer / ManyToMany) and `CreatePolymorphicLookup` — create the relationship.

What was missing is the **order**. This file is the rule.

## The rule

> **Before creating any relationship, every parent (referenced) table must already be a component of the
> target solution. For an out-of-the-box table that isn't, add it first with no subcomponents. Then create
> the relationship.**

- **Regular 1:N** → add the **one** parent (referenced) table.
- **Customer** → add **both** `account` **and** `contact`.
- **Polymorphic** → add **every** entity in the target list.
- **N:N** → add **both** entities.

Custom tables you created in *this* solution are already components (added with all assets) — skip them.
The rule bites on **OOB / externally-owned parents** (`account`, `contact`, or any table that lives in
another solution).

## Why — two distinct failures when you skip it

1. **Dev-environment pollution.** If the referenced table isn't already a component, creating the
   relationship makes the platform **auto-add that table as a root component with ALL its assets**
   (every column, form, view, …). Your solution now drags the entire OOB `account`/`contact` table around.
   Adding it first, metadata-only, means the *only* thing the parent contributes is the relationship.

2. **Silent non-deployment.** On **export**, a relationship whose referenced parent is **not** a solution
   component is **silently dropped** from the exported solution — it never reaches QA/Prod. The dev
   environment looks fine; the target environments are simply missing the relationship, with no error.

> **Polymorphic caveat (seen in testing):** a polymorphic/Customer lookup can register **some** targets and
> not others. In one build the simple `…_maincontact → contact` lookup pulled `contact` in as a dependency,
> but `account` — referenced **only** through the Customer lookup — was added by nothing and was absent from
> the solution. The Customer relationship's `account` leg would not have deployed. Always add **all** targets
> explicitly; don't assume relationship creation registers them for you.

## Orchestration — the call order

`AddTableToSolution` is idempotent in practice: adding a table already present is harmless, and on a custom
table already carrying all its assets it does **not** strip them. So the safe pattern is just "add each OOB
parent, no subcomponents, then create."

### Regular 1:N (OOB parent — e.g. child → `account`)

```powershell
$skill = ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1"

# 1) parent first, metadata-only
powershell -ExecutionPolicy Bypass -File $skill -Operation AddTableToSolution `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "account" -SolutionName "YourSolution" -DoNotIncludeSubcomponents $true

# 2) then the relationship
powershell -ExecutionPolicy Bypass -File $skill -Operation CreateRelationship -RelationshipType OneToMany `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ParentTable "account" -ChildTable "hsot_coveredasset" `
    -LookupName "hsot_account_id" -LookupDisplayName "Account" -LookupDescription "Owning account." `
    -CascadeDelete "RemoveLink" -CascadeAssign "NoCascade" -SolutionName "YourSolution"
```

(When the parent is a **custom table you just created in this solution**, step 1 is unnecessary — it's
already a component. The rule only forces a pre-add for OOB/external parents.)

### Customer (account + contact) — add **both** first

```powershell
foreach ($t in @("account","contact")) {
    powershell -ExecutionPolicy Bypass -File $skill -Operation AddTableToSolution `
        -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
        -TableName $t -SolutionName "YourSolution" -DoNotIncludeSubcomponents $true
}
powershell -ExecutionPolicy Bypass -File $skill -Operation CreateRelationship -RelationshipType Customer `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChildTable "hsot_serviceagreement" -LookupName "hsot_customer_id" `
    -LookupDisplayName "Customer" -LookupDescription "Account or contact this agreement covers." `
    -SolutionName "YourSolution"
```

### Polymorphic — add **every** target first

```powershell
$targets = @("contact","hsot_vendor")     # all entities the lookup will point at
foreach ($t in $targets) {
    powershell -ExecutionPolicy Bypass -File $skill -Operation AddTableToSolution `
        -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
        -TableName $t -SolutionName "YourSolution" -DoNotIncludeSubcomponents $true
}
powershell -ExecutionPolicy Bypass -File $skill -Operation CreatePolymorphicLookup `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChildTable "hsot_serviceagreement" -LookupName "hsot_partyid" -LookupDisplayName "Party" `
    -LookupDescription "Contact or vendor party." -TableNames $targets -SolutionName "YourSolution"
```

### N:N — add **both** entities first, then `CreateRelationship -RelationshipType ManyToMany`.

## Remediating a solution that was built in the wrong order

If a relationship was already created and a referenced parent is missing from the solution (so the
relationship won't export), you do **not** need to drop and recreate it. Just add the missing parent —
metadata-only — and the relationship will be included on the next export:

```powershell
powershell -ExecutionPolicy Bypass -File $skill -Operation AddTableToSolution `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "account" -SolutionName "YourSolution" -DoNotIncludeSubcomponents $true
```

Verify what's actually in the solution (and how) before and after — entity components and their
root-component behavior:

```powershell
# componenttype 1 = Entity; rootcomponentbehavior 0 = ALL ASSETS (the trap), 1 = dependency-only, 2 = metadata/shell
# query solutioncomponents filtered by _solutionid_value, resolve objectid -> EntityDefinitions(objectid).LogicalName
```

A clean result: your own custom tables present (all-assets is fine for tables you own), and each OOB parent
present as **metadata/dependency only** — never an OOB table sitting at `rootcomponentbehavior 0`.

## Gotchas

- **`-DoNotIncludeSubcomponents $true` is the whole point** for OOB parents — omitting it (or passing
  `$false`) re-introduces the all-assets pollution you're trying to avoid.
- **Add every polymorphic/Customer target explicitly.** Relationship creation may register some and not
  others; don't rely on it (see the caveat above).
- This is purely a **solution-membership** concern. The relationship metadata itself is identical either
  way — order only changes what lands in the solution and what exports.

## See also

- [`remove-solution-component-web-api.md`](remove-solution-component-web-api.md) — the inverse: if a parent
  got pulled in with ALL assets (the trap), or you need to take an over-included OOB table back out, this is
  the validated `RemoveSolutionComponent` pattern (removing ≠ deleting).
