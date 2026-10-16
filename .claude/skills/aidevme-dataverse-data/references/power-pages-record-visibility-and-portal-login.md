# Power Pages — making records visible to a portal contact + provisioning a portal login

Data-side patterns for a **standard (`adx_`) data model** portal. For the page/form/nav config side see `hso-power-pages-config`; for the security model read [`shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md`](../../../shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md).

## 1. Surface a record to a portal contact = set the scope-relationship field

A portal user sees a row only if a matching **`adx_entitypermission`** grants it. The scope decides which field links the row to the user:

| Scope | The user sees rows where… |
|---|---|
| **Account** (756150002) | the permission's `adx_accountrelationship` field = the **logged-in contact's parent account** |
| **Contact** (756150001) | the permission's `adx_contactrelationship` field = the **logged-in contact** |
| **Global** (756150000) | any (role-gated only) |

So to make a record visible to a partner, **set that scope-relationship field to the partner's account/contact**. Examples seen in the wild:
- Quote: `quote.msdyn_account` (rel `msdyn_account_quote_Account`, Account scope) → set to the partner agency account.
- Invoice: `invoice.customerid` (rel `invoice_customer_accounts`, Account scope) → set to the partner account. *(Caveat: this is the bill-to; re-homing it for portal visibility is a demo expedient — the real model is a partner-AR relationship/integration.)*
- Case: `incident.customerid` (Account or Contact scope).
- Opportunity (partner portal / PRM): `opportunity.msa_partnerid` (Account) and `opportunity.msa_partneroppid` (Contact) feed the Managed/Distributed/Assigned Opportunities lists.

Resolve the exact field for a relationship: `GET RelationshipDefinitions(SchemaName='<rel>')/Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata?$select=ReferencingEntity,ReferencingAttribute`.

Inspect a permission's scope + relationship: `GET adx_entitypermissions?$select=adx_entityname,adx_scope,adx_accountrelationship,adx_contactrelationship&$filter=_adx_websiteid_value eq <site> and adx_entitylogicalname eq '<entity>'`.

> After any permission/data change, **clear the portal cache** — table permissions are cached aggressively.

## 2. Provision a portal login (local authentication)

For a portal using **local auth** (username/password stored on the `contact`), provision a login on a contact via the `adx_identity_*` fields:
- `adx_identity_username`, `adx_identity_logonenabled = true`, `adx_identity_passwordhash`, `adx_identity_securitystamp`.

**Pragmatic provisioning (demo / non-prod):** copy `adx_identity_passwordhash` **and** `adx_identity_securitystamp` from an existing working portal user, set a fresh `adx_identity_username` + `logonenabled = true` on the new contact, and the **same password** works (the ASP.NET Identity hash is self-salted — username isn't part of it). Then assign web role(s) via the N:N `adx_webrole_contact`.

> Local auth passwords are **not** plain-PATCH-able (the hash is computed) — copying a known-good hash is the reliable non-interactive path, vs. the browser-based invitation-redemption flow. Use only in dev/demo; production logins go through proper invitation/Entra auth.

| Date | Author | Description |
|------|--------|-------------|
| 2026-06-11 | Meghan Reed | Initial — scope-relationship record-visibility pattern (Account/Contact/Global + the field each uses) and the copy-passwordhash local-auth login provisioning trick, from the Marmon partner-portal build. |