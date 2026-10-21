# Redaction checklist

<!-- cspell:ignore AKIA xoxb xoxp ghp ghs ghu github_pat Ocp Apim microsoftonline ctso -->

Run this on all the evidence (text, logs, screenshots, exports) before reconstructing anything. Replace each hit with a
`{{camelCaseName}}` placeholder that says what it is, reuse the same placeholder for the same value, and keep a list of
what was removed: **kind and placeholder only, never the value**.

## Always remove

| Kind | What it looks like | Placeholder |
| --- | --- | --- |
| Passwords | `Password=`, `pwd=`, `-p <value>`, `--password`, values typed into a password field | `{{password}}` (better: say to use the tool's own sign-in) |
| Bearer and access tokens | `Authorization: Bearer …`, JWTs (three base64url parts separated by dots, often starting `eyJ`) | remove; the skill signs in instead |
| Personal access tokens and API keys | `ghp_`, `ghs_`, `ghu_`, `github_pat_`, Azure DevOps PATs, `AKIA…` (AWS), `sk-…`, `xoxb-`/`xoxp-` (Slack), `Ocp-Apim-Subscription-Key` | remove; name the secret store or sign-in instead |
| Client secrets and certificates | `client_secret=`, `--secret`, `.pfx` passwords, certificate thumbprints | `{{clientSecretName}}` (a reference to the vault entry, not the value) |
| Connection strings | `AccountKey=`, `SharedAccessSignature=`, `AuthType=ClientSecret;…;ClientSecret=`, `Server=…;Password=` | `{{connectionStringName}}` |
| Cookies and session IDs | `Cookie:`, `Set-Cookie:`, `ARRAffinity`, `CrmOwinAuth` | remove |
| Signed URLs | `sig=`, `se=`, `sv=` query strings (SAS), pre-signed links | `{{downloadUrl}}` |

## Replace with parameters

| Kind | What it looks like | Placeholder |
| --- | --- | --- |
| Tenant, client (app) and subscription IDs | GUIDs next to "tenant", "client", "app", "subscription", or in `login.microsoftonline.com/<guid>` | `{{tenantId}}`, `{{clientId}}`, `{{subscriptionId}}` |
| Environment and org URLs | `https://<org>.crm*.dynamics.com`, `make.powerapps.com/environments/<guid>`, `dev.azure.com/<org>/<project>`, `<org>.visualstudio.com` | `{{environmentUrl}}`, `{{environmentId}}`, `{{adoOrganization}}`, `{{adoProject}}` |
| Resource names | resource groups, storage accounts, key vaults, app registrations, repositories, pipelines and their IDs | `{{resourceGroup}}`, `{{repository}}`, `{{pipelineId}}` |
| Solution, table and publisher names that belong to a customer | `contoso_`, `ctso_` prefixes, solution names | `{{solutionName}}`, `{{publisherPrefix}}` |
| Record data | record GUIDs, names, amounts, addresses, any field values from a real record | `{{recordId}}`, or describe the field ("the account's name") |

## Personal data

| Kind | What it looks like | What to do |
| --- | --- | --- |
| Names and email addresses | people in the evidence, `@<company>.com` addresses, display names in screenshots | `{{userEmail}}`, or "the signed-in user" |
| Phone numbers, addresses, IDs | any | remove |
| User paths | `C:\Users\<name>\…`, `/home/<name>/…` | `{{workingFolder}}` or a relative path |
| Machine and host names | `DESKTOP-…`, internal host names, IP addresses | remove or `{{hostName}}` |
| Customer and company names | in text, URLs, file names, screenshots | `{{customer}}` only if the skill needs it; usually drop |

## Screenshots

Read each image for the same things: account names in the corner, environment names in the header, URLs in the
address bar, record values in forms and grids, names in chat panes. Don't copy any of them into the skill; describe
the screen instead ("the Solutions page", "the Export dialog").

## Report and warning

After redacting, show:

| Removed | Replaced with |
| --- | --- |
| 1 personal access token | removed; the skill uses `az login` |
| 1 environment URL | `{{environmentUrl}}` |
| 3 record names | described as "the account" |

If any row is a credential (password, token, key, secret, connection string, cookie), add **one** warning: the
evidence contained a secret, it isn't in the skill, and the user may want to rotate it if it was shared beyond this
conversation.
