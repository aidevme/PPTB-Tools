# Tool Development

## Table of Contents

| Section | Description |
| --- | --- |
| [Overview](#overview) | What a PPTB tool is and the key characteristics of the tool runtime. |
| [Package Manifest](#package-manifest) | Required and optional `package.json` fields that describe a tool to the ToolBox host. |
| [API Reference](#api-reference) | Index of the namespaced APIs exposed to tools inside the sandboxed iframe. |
| [ToolBox API](#toolbox-api) | Host utilities for connection management and general ToolBox interaction. |
| [Dataverse API](#dataverse-api) | Complete HTTP client for CRUD, queries, metadata, and schema customization against Microsoft Dataverse. |
| [PowerPlatform API](#powerplatform-api) | Operations at the Power Platform level, beyond a single Dataverse environment. |
| [Events API](#events-api) | Subscribing to and emitting events between a tool and the ToolBox host. |
| [Settings API](#settings-api) | Persisting and retrieving per-tool user settings. |
| [File System API](#file-system-api) | Reading and writing files on behalf of a tool. |
| [Error Handling](#error-handling) | Conventions for surfacing and handling API errors in a tool. |
| [CSP Configuration](#csp-configuration) | Declaring Content Security Policy exceptions a tool needs. |
| [Local Validation](#local-validation) | Validating a tool's manifest and package locally before publishing. |
| [Inter-Tool Invocation](#inter-tool-invocation) | Launching or communicating with other tools from within a tool. |
| [Agent Integration](#agent-integration) | Integrating a tool with AI agent workflows. |
| [Publishing Tools](#publishing-tools) | Steps to package and publish a tool to the registry. |

## Overview

Tools are web applications that run in isolated environments and communicate with the PPTB host through
secure APIs. Key characteristics:

- **Sandboxed iframe execution** with restricted API access.
- **Namespaced APIs** for connections, utilities, terminals, events, and Dataverse.
- **Structured message protocol** (`postMessage`) for host communication.
- **Context-awareness** — automatic tool ID and connection context management.
- **TypeScript support** — full compatibility via the `@pptb/types` package.

> If porting an existing XrmToolBox plugin, respectfully contact the original tool author before cloning
> their work. See the PPTB Discord server for discussion and community support.

Source: [docs.powerplatformtoolbox.com/tool-development](https://docs.powerplatformtoolbox.com/tool-development)

## Package Manifest

Every Power Platform ToolBox tool requires a `package.json` file at the root of the distribution. This
file describes your tool to the ToolBox host and the npm registry.

> **Deprecated:** `iconURL` under `configurations` is no longer supported. Use the top-level `icon` field
> instead with an SVG path relative to your dist root.

### Overview

The `package.json` follows the standard npm package format with additional PPTB-specific fields.
Required fields must be present for your tool to load correctly.

### Required Fields

| Field | Type | Description | Sample |
| --- | --- | --- | --- |
| `name` | string | Scoped npm package name — lowercase, no spaces | `"@myorg/my-tool"` |
| `version` | string | SemVer-compatible version | `"1.0.0"` |
| `displayName` | string | Human-readable name shown in the ToolBox UI | `"My Awesome Tool"` |
| `description` | string | Short description of what the tool does | `"Manage Dataverse solutions"` |
| `main` | string | Entry-point file relative to the dist root | `"index.html"` |
| `icon` | string | Path to SVG icon relative to the dist root. Use `fill="currentColor"` to support light/dark themes | `"icons/tool.svg"` |
| `license` | string | An approved open-source license identifier | `"MIT"` |
| `contributors` | array | One or more objects with a `name` and optional `url` | See below |
| `configurations` | object | PPTB-specific links and metadata | See Configurations Object |

#### `contributors` array

Each entry must have at minimum a `name`.

```json
"contributors": [
  { "name": "Jane Dev", "url": "https://janedev.com" },
  { "name": "John Doe" }
]
```

Allowed licenses: `MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `GPL-2.0`, `GPL-3.0`, `LGPL-3.0`,
`ISC`, `AGPL-3.0-only`.

#### Configurations Object

Nested inside the top-level `configurations` key.

| Field | Required | Type | Description | Sample |
| --- | --- | --- | --- | --- |
| `repository` | Yes | string | URL of the tool's source repository — shown in the ToolBox help menu | `"https://github.com/myorg/my-tool"` |
| `website` | No | string | Tool website or documentation URL | `"https://docs.myorg.com/my-tool"` |
| `readmeUrl` | No | string | Raw githubusercontent.com URL for the README — used to display docs inside ToolBox | `"https://raw.githubusercontent.com/myorg/my-tool/main/README.md"` |

### Optional Fields

| Field | Type | Description | Sample |
| --- | --- | --- | --- |
| `homepage` | string | Public homepage URL | `"https://myorg.com"` |
| `repository` | object | Standard npm repository object | `{ "type": "git", "url": "https://github.com/…" }` |
| `cspExceptions` | object | Additional Content Security Policy origins your tool connects to | See CSP Exceptions Object |
| `features` | object | Declare special ToolBox capabilities required by your tool | See Features Object |

### Features Object

Declare ToolBox-specific capabilities your tool needs. Omit this section entirely if neither field
applies.

| Field | Type | Values | Description | Sample |
| --- | --- | --- | --- | --- |
| `multiConnection` | string | `"optional"` \| `"required"` | Whether the tool supports or requires a second Dataverse connection | `"optional"` |
| `minAPI` | string | SemVer | Minimum ToolBox API version the tool requires | `"1.2.0"` |

```json
"features": {
  "multiConnection": "optional",
  "minAPI": "1.2.0"
}
```

#### Specifying a Minimum API Version

The `minAPI` field lets you declare the lowest ToolBox API version your tool is compatible with. When a
user installs or opens your tool, Power Platform ToolBox checks this value against the currently
installed ToolBox version. If the installed version is older than the minimum required, ToolBox will
alert the user and recommend upgrading before they can use the tool.

When to set `minAPI`:

- Your tool calls an API or uses a feature that was introduced in a specific ToolBox release (for
  example, `multiConnection` requires 1.2.0 or later).
- You want to prevent runtime errors caused by a user running an older, incompatible version of ToolBox.

How to determine the correct value: each function in the API Reference includes a `Requires vX.Y.Z`
badge showing the minimum ToolBox version it needs (where applicable). Set `minAPI` to the highest such
version across all the functions your tool depends on.

You only need to set `minAPI` if your tool relies on features that were not available in the very first
public release. If your tool only uses core APIs that have been available from the start, you can omit
this field.

Setting `minAPI` too high (higher than necessary) will prevent users with older but compatible ToolBox
versions from running your tool. Always use the lowest version that includes all the features you
actually need.

### CSP Exceptions Object

Declare additional external origins that your tool's iframe is permitted to connect to. Omit this section
entirely if your tool only communicates with Dataverse endpoints. All fields are optional.

Each directive accepts an array of entries. An entry can be either a plain string (just the domain) or an
object with the following properties:

| Field | Type | Required | Description | Sample |
| --- | --- | --- | --- | --- |
| `domain` | string | Yes | The origin/domain to allow | `"api.example.com"` |
| `exceptionReason` | string | No | Markdown description explaining why this CSP exception is needed. Displayed to users in the consent dialog. | `"Used to **read** configuration details."` |
| `optional` | boolean | No | When `true`, indicates the exception is optional — the core tool works without it, but granting it enables additional functionality. Defaults to `false`. | `true` |

The supported CSP directives are:

| Directive | Description | Sample domain |
| --- | --- | --- |
| `connect-src` | Fetch, XHR, WebSocket, and EventSource origins | `"api.example.com"` |
| `script-src` | Additional origins allowed to serve scripts | `"cdn.example.com"` |
| `style-src` | Additional origins allowed to serve stylesheets | `"fonts.googleapis.com"` |
| `img-src` | Additional origins allowed to serve images | `"img.example.com"` |
| `font-src` | Additional origins allowed to serve fonts | `"fonts.gstatic.com"` |
| `frame-src` | Origins allowed to be embedded in iframes | `"embed.example.com"` |
| `media-src` | Origins allowed to serve audio/video media | `"media.example.com"` |

```json
"cspExceptions": {
  "connect-src": [
    {
      "domain": "api.example.com",
      "exceptionReason": "Used to **fetch** live data for the dashboard."
    }
  ],
  "script-src": [
    {
      "domain": "cdn.example.com",
      "exceptionReason": "Loads the charting library used to render reports."
    }
  ],
  "style-src": [
    {
      "domain": "fonts.googleapis.com",
      "exceptionReason": "Provides the UI font family.",
      "optional": true
    }
  ],
  "img-src": ["img.example.com"],
  "font-src": ["fonts.gstatic.com"],
  "frame-src": ["embed.example.com"],
  "media-src": ["media.example.com"]
}
```

Only add origins you genuinely need. Unnecessary CSP exceptions will be flagged during registry
submission review.

### Full Example

```json
{
  "name": "@myorg/my-awesome-tool",
  "version": "1.0.0",
  "displayName": "My Awesome Tool",
  "description": "Manage Dataverse solutions across environments with ease.",
  "main": "index.html",
  "icon": "icons/tool.svg",
  "license": "MIT",
  "contributors": [
    { "name": "Jane Dev", "url": "https://janedev.com" },
    { "name": "John Doe" }
  ],
  "configurations": {
    "repository": "https://github.com/myorg/my-awesome-tool",
    "website": "https://docs.myorg.com/my-awesome-tool",
    "readmeUrl": "https://raw.githubusercontent.com/myorg/my-awesome-tool/main/README.md"
  },
  "features": {
    "multiConnection": "optional",
    "minAPI": "1.2.0"
  },
  "cspExceptions": {
    "connect-src": [
      {
        "domain": "api.example.com",
        "exceptionReason": "Used to **fetch** live configuration data for the dashboard."
      }
    ],
    "img-src": [
      {
        "domain": "img.example.com",
        "exceptionReason": "Loads thumbnails for the media browser.",
        "optional": true
      }
    ]
  },
  "keywords": ["dataverse", "power-platform", "solutions"],
  "homepage": "https://docs.myorg.com/my-awesome-tool",
  "repository": {
    "type": "git",
    "url": "https://github.com/myorg/my-awesome-tool.git"
  },
  "bugs": {
    "url": "https://github.com/myorg/my-awesome-tool/issues"
  },
  "dependencies": {},
  "devDependencies": {
    "@pptb/types": "^1.0.0",
    "typescript": "^5.0.0",
    "vite": "^5.0.0"
  },
  "scripts": {
    "build": "vite build",
    "dev": "vite"
  }
}
```

Source: [docs.powerplatformtoolbox.com/tool-development/manifest](https://docs.powerplatformtoolbox.com/tool-development/manifest)

## API Reference

Comprehensive reference for the ToolBox API, PowerPlatform API, and Dataverse API available to all
tools running in Power Platform ToolBox. For complete TypeScript definitions, install the `@pptb/types`
package:

```bash
npm install --save-dev @pptb/types
```

### Overview

Power Platform ToolBox provides a comprehensive set of APIs that enable tool developers to create
powerful, integrated experiences. These APIs are organized into several categories, each serving a
specific purpose:

- **ToolBox API** — Platform features including connections, utilities, and terminal management
- **Dataverse API** — Complete HTTP client for interacting with Microsoft Dataverse
- **PowerPlatform API** — Direct access to Power Platform service endpoints and management operations
- **Settings API** — Persistent storage for tool-specific preferences and configuration
- **File System API** — Secure file operations for reading, writing, and managing files
- **Events API** — Subscribe to platform events like connection changes and settings updates
- **Error Handling** — Best practices for handling errors gracefully

### Quick Links

| API | Description |
| --- | --- |
| [ToolBox API](#toolbox-api) | Platform features, connections, utilities, and terminal management |
| [Dataverse API](#dataverse-api) | Complete HTTP client for Microsoft Dataverse operations |
| [PowerPlatform API](#powerplatform-api) | Direct access to Power Platform management and service endpoints |
| [Events API](#events-api) | Subscribe to platform and lifecycle events |
| [Settings API](#settings-api) | Persistent tool-specific settings and configuration |
| [File System API](#file-system-api) | Secure file operations and directory management |
| [Error Handling](#error-handling) | Best practices for error handling and user feedback |

### Getting Started

For developers new to Power Platform ToolBox, the recommended starting order is:

1. **Quickstart Guide** — Get up and running quickly
2. **[ToolBox API](#toolbox-api)** — Learn about platform features
3. **[PowerPlatform API](#powerplatform-api)** — Call Power Platform service endpoints
4. **[Dataverse API](#dataverse-api)** — Start interacting with Dataverse
5. **[Error Handling](#error-handling)** — Implement robust error handling

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference](https://docs.powerplatformtoolbox.com/tool-development/api-reference)

## ToolBox API

The ToolBox API provides access to platform features and utilities via `window.toolboxAPI`. For complete
TypeScript definitions, install the `@pptb/types` package:

```bash
npm install --save-dev @pptb/types
```

### Connections

Get information about the active Dataverse connection(s).

> In `@pptb/types`, `DataverseConnection` is deprecated and has been renamed to `Connection`.

#### `toolboxAPI.connections.getActiveConnection()`

_Requires v1.2.0_ — Returns the currently active connection or `null` if none is selected.

```typescript
const connection = await toolboxAPI.connections.getActiveConnection()

if (connection) {
  console.log('Connected to:', connection.name)
  console.log('Environment:', connection.environment)
  console.log('URL:', connection.url)
} else {
  console.log('No active connection')
}
```

Returns: `Promise<Connection | null>`

```typescript
interface Connection {
  id: string // Unique identifier of the connection
  name: string // Friendly name of the connection
  url: string // Base URL of the Dataverse instance
  environment: 'Dev' | 'Test' | 'UAT' | 'Production' // Environment classification
  environmentColor?: string // Hex color code associated with the environment (added in 1.2.0)
  category?: string // Category label assigned to the connection (added in 1.2.0)
  categoryColor?: string // Hex color code for the category badge (added in 1.2.0)
  createdAt: string // ISO date string of when the connection was created
  lastUsedAt?: string // ISO date string of when the connection was last used
  enabledForPowerPlatformAPI?: boolean // True when this connection is enabled for Power Platform API usage
  scopesForPowerPlatformAPI?: string[] // Granted scopes for Power Platform API calls
  isActive?: boolean // @deprecated legacy field retained for backwards compatibility
}

// Deprecated compatibility alias
type DataverseConnection = Connection
```

Example values that may appear in `scopesForPowerPlatformAPI`:

```typescript
[
  'https://api.powerplatform.com/EnvironmentManagement.Environments.Read',
  'https://api.powerplatform.com/EnvironmentManagement.Groups.Read',
  'https://api.powerplatform.com/EnvironmentManagement.Groups.ReadWrite',
  'https://api.powerplatform.com/EnvironmentManagement.Settings.Read',
  'https://api.powerplatform.com/EnvironmentManagement.Settings.ReadWrite',
  'https://api.powerplatform.com/Governance.CrossTenantConnectionReports.Read',
  'https://api.powerplatform.com/Governance.CrossTenantConnectionReports.ReadWrite',
  'https://api.powerplatform.com/PowerApps.Apps.Play',
  'https://api.powerplatform.com/PowerApps.Apps.Read',
  'https://api.powerplatform.com/PowerAutomate.Flows.Read',
  'https://api.powerplatform.com/.default',
]
```

### Secondary Connections

As a tool developer, you may require access to a second Dataverse connection. This can be useful for
copying data or configuration between environments.

To enable this feature, you must update the `package.json` file to indicate your tool requires
multi-connections:

```json
{
  "name": "@toolname",
  "version": "0.1.10",
  "displayName": "My Awesome Tool",
  "description": "A Power Platform Tool Box tool to do awesome things",
  "main": "index.html",
  "icon": "icons/test.svg",
  "contributors": ["Awesome Developer"],
  // Other properties...
  // This section enables multiple connections
  "features": {
    "multiConnection": "required", // or "optional"
    "minAPI": "1.2.0"
  }
}
```

Use the top-level `icon` field for your SVG icon path (relative to the dist root, for example
`icons/test.svg`). To ensure the icon adapts to dark/light theme, set the SVG `fill` to `currentColor`.

When the user opens your tool, they are presented with the option to connect to a primary and secondary
environment.

#### `toolboxAPI.connections.getSecondaryConnection()`

_Requires v1.2.0_ — Returns the currently active secondary connection or `null` if none is configured.

```typescript
const secondaryConnection =
  await toolboxAPI.connections.getSecondaryConnection()

if (secondaryConnection) {
  console.log('Connected to:', secondaryConnection.name)
  console.log('Environment:', secondaryConnection.environment)
  console.log('URL:', secondaryConnection.url)
} else {
  console.log('No active secondary connection')
}
```

Returns: `Promise<Connection | null>` — same `Connection` type as documented above.

When interacting with Dataverse and you want to use the secondary connection, pass the
`connectionTarget` parameter as `'secondary'`. `connectionTarget` is optional and defaults to
`'primary'`.

```typescript
// Example usage of dataverseAPI using secondary connection
const myTables = await dataverseAPI.getAllEntitiesMetadata(
  ['logicalName'],
  'secondary',
)
```

### Utils

Utility functions for notifications, clipboard, and more.

> **Breaking change:** `saveFile()` and `selectPath()` have been migrated to the [File System
> API](#file-system-api).

#### `toolboxAPI.utils.showNotification(options)`

_Requires v1.0.17_ — Display a notification to the user.

```typescript
await toolboxAPI.utils.showNotification({
  title: 'Success',
  body: 'Operation completed successfully',
  type: 'success', // 'info' | 'success' | 'warning' | 'error'
  duration: 3000, // Auto-dismiss after 3 seconds
})
```

Parameters:

- `options` — Notification configuration object
  - `type: 'info' | 'success' | 'warning' | 'error'`
  - `duration` — Number in milliseconds (`0` = persistent)

#### `toolboxAPI.utils.copyToClipboard(text)`

_Requires v1.0.17_ — Copy text to the system clipboard.

```typescript
const data = JSON.stringify({ accounts: [], contacts: [] }, null, 2)
await toolboxAPI.utils.copyToClipboard(data)

await toolboxAPI.utils.showNotification({
  title: 'Copied',
  body: 'Data copied to clipboard',
  type: 'success',
})
```

#### `toolboxAPI.utils.getCurrentTheme()`

_Requires v1.0.17_ — Get the current application theme.

```typescript
const theme = await toolboxAPI.utils.getCurrentTheme()
document.body.classList.add(`theme-${theme}`)
```

Returns: `Promise<'light' | 'dark'>`

#### `toolboxAPI.utils.executeParallel(...promises)`

_Requires v1.0.17_ — Execute multiple async operations in parallel.

```typescript
const [account, contact, opportunities] =
  await toolboxAPI.utils.executeParallel(
    dataverseAPI.retrieve('account', accountId, ['name']),
    dataverseAPI.retrieve('contact', contactId, ['fullname']),
    dataverseAPI.fetchXmlQuery(opportunityFetchXml),
  )

console.log('All data fetched:', account, contact, opportunities)
```

#### `toolboxAPI.utils.openInConnectionBrowser(url, connectionTarget?)`

_Requires v1.2.2_ — Open a URL in the external browser associated with the tool's active connection.
When the connection has a browser profile configured (e.g. a specific Chrome or Edge profile), the URL
is opened in that browser and profile so the user is already authenticated. Falls back to the system
default browser when no profile is configured.

Only `https:` and `http:` URLs are allowed.

```typescript
// Open a record in the browser using the primary connection's browser profile
await toolboxAPI.utils.openInConnectionBrowser(
  'https://contoso.crm.dynamics.com/main.aspx?etn=account&id=guid-here&pagetype=entityrecord',
)

// Open a URL using the secondary connection's browser profile
await toolboxAPI.utils.openInConnectionBrowser(
  'https://contoso-dev.crm.dynamics.com/main.aspx?pagetype=entitylist&etn=account',
  'secondary',
)
```

Parameters:

- `url: string` — The URL to open (must use `https:` or `http:` protocol)
- `connectionTarget?: 'primary' | 'secondary'` — Which connection's browser profile to use. Defaults to
  `'primary'`.

Returns: `Promise<void>`

### Terminal

Create and manage terminal sessions (context-aware to your tool).

#### `toolboxAPI.terminal.create(options)`

_Requires v1.0.17_ — Create a new terminal.

```typescript
const terminal = await toolboxAPI.terminal.create({
  name: 'Build Terminal',
  cwd: '/path/to/project',
  env: {
    NODE_ENV: 'production',
  },
})

console.log('Terminal created:', terminal.id)
```

#### `toolboxAPI.terminal.execute(terminalId, command)`

_Requires v1.0.17_ — Execute a command in a terminal.

```typescript
const result = await toolboxAPI.terminal.execute(terminal.id, 'npm install')

if (result.exitCode === 0) {
  console.log('Command completed successfully')
} else {
  console.error('Command failed:', result.error)
}
```

#### `toolboxAPI.terminal.setVisibility(terminalId, visible)`

_Requires v1.0.17_ — Show or hide a terminal's UI panel.

```typescript
await toolboxAPI.terminal.setVisibility(terminal.id, true)
```

#### `toolboxAPI.terminal.list()`

_Requires v1.0.17_ — List all terminals created by your tool.

```typescript
const terminals = await toolboxAPI.terminal.list()
console.log(`This tool has ${terminals.length} terminals`)
```

#### `toolboxAPI.terminal.close(terminalId)`

_Requires v1.0.17_ — Close a terminal.

```typescript
await toolboxAPI.terminal.close(terminal.id)
```

### Invocation API

The Invocation API enables inter-tool communication — one tool can launch another, pass prefill data,
and receive a return value when the callee finishes. See [Inter-Tool Invocation](#inter-tool-invocation)
for a fuller walkthrough.

#### `toolboxAPI.invocation.launchTool(targetToolId, prefillData?, options?)`

_Requires v1.2.2-beta_ — Launch another installed tool from within your tool and optionally pass
prefill data. Returns a Promise that resolves with the data the target tool sends back via
`returnData()`, or `null` if the target tool closes without returning data.

```typescript
// Tool A: launch an entity-picker tool and wait for the result
const result = await toolboxAPI.invocation.launchTool(
  '@my-org/entity-picker',
  { entityName: 'account' },
)

if (result) {
  console.log('Selected ID:', result.selectedId)
  console.log('Selected name:', result.selectedName)
}
```

Parameters:

- `targetToolId: string` — npm package name (toolId) of the tool to launch
- `prefillData?: Record<string, unknown>` — Data to pre-populate the target tool's state
- `options?: object` — Optional connection overrides: `{ primaryConnectionId?, secondaryConnectionId? }`

Returns: `Promise<unknown>` — Data returned by the target tool, or `null` if it closes without
returning data

#### `toolboxAPI.invocation.getLaunchContext()`

_Requires v1.2.2-beta_ — Read the prefill data passed by the tool that launched this tool. Returns
`null` if this tool was not launched via an inter-tool invocation.

```typescript
// Tool B: read the launch context on startup
const ctx = await toolboxAPI.invocation.getLaunchContext()

if (ctx) {
  console.log('Launched with entity:', ctx.entityName)
  // Pre-populate UI based on ctx...
}
```

Returns: `Promise<Record<string, unknown> | null>`

#### `toolboxAPI.invocation.returnData(returnData)`

_Requires v1.2.2-beta_ — Return data back to the tool that launched this tool. This resolves the
Promise returned by the caller's `launchTool()` call. If this tool was not launched by another tool, the
call is a no-op.

```typescript
// Tool B: after the user makes a selection, return it to the caller
await toolboxAPI.invocation.returnData({
  selectedId: 'guid-here',
  selectedName: 'Contoso Ltd',
})
```

Parameters:

- `returnData: Record<string, unknown>` — Data to pass back to the caller

Returns: `Promise<void>`

### Tool Context

#### `toolboxAPI.getToolContext()`

_Requires v1.0.17_ — Returns the current tool context used by the framework.

```typescript
const context = await toolboxAPI.getToolContext()

console.log('Tool ID:', context.toolId)
console.log('Instance ID:', context.instanceId)
console.log('Primary URL:', context.connectionUrl)
console.log('Secondary URL:', context.secondaryConnectionUrl)
```

Returns: `Promise<ToolContext>`

```typescript
interface ToolContext {
  toolId: string | null
  instanceId?: string | null
  connectionUrl: string | null
  connectionId?: string | null
  secondaryConnectionUrl?: string | null
  secondaryConnectionId?: string | null
}
```

`ToolContext` intentionally does not contain access tokens. Use `dataverseAPI` for authenticated
Dataverse operations.

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/toolbox-api](https://docs.powerplatformtoolbox.com/tool-development/api-reference/toolbox-api)

## Dataverse API

Complete HTTP client for interacting with Microsoft Dataverse. For complete TypeScript definitions,
install the `@pptb/types` package:

```bash
npm install --save-dev @pptb/types
```

Each method accepts an optional `connectionTarget` parameter (`'primary' | 'secondary'`, defaults to
`'primary'`) to specify which connection to use for multi-connection tools.

### CRUD Operations

#### `dataverseAPI.create(entityLogicalName, record, connectionTarget?)`

_Requires v1.0.17_ — Creates a new record in the primary or secondary dataverse.

- `entityLogicalName: string` — Logical name of the entity
- `record: Record<string, unknown>` — Object containing the record data to create
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target for multi-connection tools. Defaults to `'primary'`.

Returns: `Promise<CreateResult>` — Object containing the created record ID (`id`) and any returned fields.

```typescript
// Create account using primary connection
const accountResult = await dataverseAPI.create('account', {
  name: 'Contoso Ltd',
  telephone1: '555-1234',
  websiteurl: 'https://contoso.com',
})
console.log('Created account:', accountResult.id)

// Create contact using secondary connection
const contactResult = await dataverseAPI.create(
  'contact',
  {
    firstname: 'Dave',
  },
  'secondary',
)
console.log('Created contact in secondary connection:', contactResult.id)
```

#### `dataverseAPI.retrieve(entityLogicalName, id, columns?, connectionTarget?)`

_Requires v1.0.17_ — Retrieve a single record.

- `entityLogicalName: string` — Logical name of the entity
- `id: string` — GUID of the record to retrieve
- `columns?: string[]` — Optional array of column names to retrieve (retrieves all if not specified)
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<Record<string, any>>` — Object representing the retrieved record.

```typescript
// Retrieve an account record using the primary connection
const account = await dataverseAPI.retrieve('account', accountResult.id, [
  'name',
  'telephone1',
  'emailaddress1',
])
console.log('Account name:', account.name)

// Retrieve all fields for a contact record using the secondary connection
// Best practice to only retrieve needed columns to optimize performance
const contact = await dataverseAPI.retrieve(
  'contact',
  contactResult.id,
  undefined,
  'secondary',
)
console.log('Contact name:', contact.fullname)
```

#### `dataverseAPI.update(entityLogicalName, id, record, connectionTarget?)`

_Requires v1.0.17_ — Update an existing record.

- `entityLogicalName: string` — Logical name of the entity
- `id: string` — GUID of the record to update
- `record: Record<string, unknown>` — Object containing the record data to update
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<void>`.

```typescript
// Updating an account record using the primary connection
await dataverseAPI.update('account', accountResult.id, {
  telephone1: '555-5678',
  websiteurl: 'https://www.contoso.com',
})

// Updating a contact record using the secondary connection
await dataverseAPI.update(
  'contact',
  contactResult.id,
  { firstname: 'David', lastname: 'Smith' },
  'secondary',
)
```

#### `dataverseAPI.delete(entityLogicalName, id, connectionTarget?)`

_Requires v1.0.17_ — Deletes a record.

- `entityLogicalName: string` — Logical name of the entity
- `id: string` — GUID of the record to delete
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<void>`.

```typescript
// Deleting an account record using the primary connection
await dataverseAPI.delete('account', 'e15a8347-f958-4c20-b964-a8d7105f645f')

// Deleting a contact record using the secondary connection
await dataverseAPI.delete(
  'contact',
  'e15a8347-f958-4f20-b964-a8d7105f645f',
  'secondary',
)
```

#### `dataverseAPI.createMultiple(entityLogicalName, records, connectionTarget?)`

_Requires v1.0.17_ — Creates multiple records in Dataverse.

- `entityLogicalName` — Logical name of the entity
- `records` — Array of record data to create, each including the `"@odata.type"` property
- `connectionTarget` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<string[]>` — Array of strings representing the created record IDs.

```typescript
const results = await dataverseAPI.createMultiple('account', [
  { name: 'Contoso Ltd', '@odata.type': 'Microsoft.Dynamics.CRM.account' },
  { name: 'Fabrikam Inc', '@odata.type': 'Microsoft.Dynamics.CRM.account' },
])
```

#### `dataverseAPI.updateMultiple(entityLogicalName, records, connectionTarget?)`

_Requires v1.0.17_ — Updates multiple records in Dataverse.

- `entityLogicalName` — Logical name of the entity
- `records` — Array of record data to update, each including the `"id"` property and the `"@odata.type"` property
- `connectionTarget` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<void>`.

```typescript
await dataverseAPI.updateMultiple('account', [
  {
    accountid: 'guid-1',
    name: 'Updated Name 1',
    '@odata.type': 'Microsoft.Dynamics.CRM.account',
  },
  {
    accountid: 'guid-2',
    name: 'Updated Name 2',
    '@odata.type': 'Microsoft.Dynamics.CRM.account',
  },
])
```

### Relationship Associations

#### `dataverseAPI.associate(primaryEntityName, primaryEntityId, relationshipName, relatedEntityName, relatedEntityId, connectionTarget?)`

_Requires v1.0.17_ — Associate two records in a many-to-many relationship.

- `primaryEntityName: string` — Logical name of the primary entity (e.g., `'systemuser'`, `'team'`)
- `primaryEntityId: string` — GUID of the primary record
- `relationshipName: string` — Logical name of the N-to-N relationship (e.g., `'systemuserroles_association'`, `'teammembership_association'`)
- `relatedEntityName: string` — Logical name of the related entity (e.g., `'role'`, `'systemuser'`)
- `relatedEntityId: string` — GUID of the related record
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<void>`.

```typescript
// Assign a security role to a user
await dataverseAPI.associate(
  'systemuser',
  'user-guid-here',
  'systemuserroles_association',
  'role',
  'role-guid-here',
)

// Add a user to a team
await dataverseAPI.associate(
  'team',
  'team-guid-here',
  'teammembership_association',
  'systemuser',
  'user-guid-here',
)

// Multi-connection tool using secondary connection
await dataverseAPI.associate(
  'systemuser',
  'user-guid',
  'systemuserroles_association',
  'role',
  'role-guid',
  'secondary',
)
```

#### `dataverseAPI.disassociate(primaryEntityName, primaryEntityId, relationshipName, relatedEntityId, connectionTarget?)`

_Requires v1.0.17_ — Disassociate two records in a many-to-many relationship.

- `primaryEntityName: string` — Logical name of the primary entity (e.g., `'systemuser'`, `'team'`)
- `primaryEntityId: string` — GUID of the primary record
- `relationshipName: string` — Logical name of the N-to-N relationship (e.g., `'systemuserroles_association'`, `'teammembership_association'`)
- `relatedEntityId: string` — GUID of the related record to disassociate
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<void>`.

```typescript
// Remove a security role from a user
await dataverseAPI.disassociate(
  'systemuser',
  'user-guid-here',
  'systemuserroles_association',
  'role-guid-here',
)

// Remove a user from a team
await dataverseAPI.disassociate(
  'team',
  'team-guid-here',
  'teammembership_association',
  'user-guid-here',
)

// Multi-connection tool using secondary connection
await dataverseAPI.disassociate(
  'systemuser',
  'user-guid',
  'systemuserroles_association',
  'role-guid',
  'secondary',
)
```

### Queries

#### `dataverseAPI.fetchXmlQuery(fetchXml, connectionTarget?)`

_Requires v1.0.17_ — Execute a FetchXML query.

- `fetchXml: string` — FetchXML query string
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target for multi-connection tools.

Returns: `Promise<FetchXmlResult>` — Object with a `value` array containing query results, OData context and paging cookie.

`FetchXmlResult` type:

- `value: Record<string, unknown>[]` — Array of records returned by the query
- `@odata.context: string` — OData context URL
- `@Microsoft.Dynamics.CRM.fetchxmlpagingcookie?: string` — Paging cookie for retrieving additional pages

```typescript
const fetchXml = `
  <fetch top="10">
    <entity name="account">
      <attribute name="name" />
      <attribute name="accountid" />
      <filter>
        <condition attribute="statecode" operator="eq" value="0" />
      </filter>
      <order attribute="name" />
    </entity>
  </fetch>
`

const result = await dataverseAPI.fetchXmlQuery(fetchXml)

result.value.forEach((account) => {
  console.log('Account:', account.name)
})
```

#### `dataverseAPI.retrieveMultiple(fetchXml, connectionTarget?)`

_Requires v1.0.17_ — Alias of `fetchXmlQuery()` for backward compatibility.

- `fetchXml: string` — FetchXML query string
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<FetchXmlResult>` — Object with a `value` array containing query results.

```typescript
const result = await dataverseAPI.retrieveMultiple(fetchXml)
console.log(`Found ${result.value.length} records`)
```

#### `dataverseAPI.queryData(odataQuery, connectionTarget?)`

_Requires v1.0.17_ — Retrieve multiple records with OData query options.

- `odataQuery: string` — OData query string with parameters like `$select`, `$filter`, `$orderby`, `$top`, `$skip`, `$expand`
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<{ value: Record<string, unknown>[] }>` — Object with a `value` array containing query results.

```typescript
// Get top 10 active accounts with specific fields
const result = await dataverseAPI.queryData(
  'accounts?$select=name,emailaddress1,telephone1&$filter=statecode eq 0&$orderby=name&$top=10',
)
console.log(`Found ${result.value.length} records`)
result.value.forEach((record) => {
  console.log(`${record.name} - ${record.emailaddress1}`)
})

// Query with expand to include related records
const result2 = await dataverseAPI.queryData(
  'accounts?$select=name,accountid&$expand=contact_customer_accounts($select=fullname,emailaddress1)&$top=5',
)

// Simple query with just a filter
const result3 = await dataverseAPI.queryData(
  `contacts?$filter=contains(fullname, 'Smith')&$top=20`,
)

// Multi-connection tool using secondary connection
const result4 = await dataverseAPI.queryData(
  'contacts?$filter=statecode eq 0',
  'secondary',
)
```

### Metadata

#### `dataverseAPI.getEntityMetadata(entityLogicalName, searchByLogicalName, entityProperties?, connectionTarget?)`

_Requires v1.0.17_ — Get entity metadata.

- `entityLogicalName: string` — Logical name or entity id of the entity
- `searchByLogicalName: boolean` — Whether to search by logical name (`true`) or metadata ID (`false`)
- `entityProperties?: string[]` — Optional array of property or column names to retrieve (retrieves all if not specified)
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<EntityMetadata>` — Object containing entity metadata.

```typescript
const metadata = await dataverseAPI.getEntityMetadata('account', true, [
  'LogicalName',
  'DisplayName',
  'EntitySetName',
])
console.log('Logical Name:', metadata.LogicalName)
console.log('Display Name:', metadata.DisplayName?.LocalizedLabels[0]?.Label)

// Get entity metadata by metadata ID
const metadataById = await dataverseAPI.getEntityMetadata(
  '00000000-0000-0000-0000-000000000001',
  false,
  ['LogicalName', 'DisplayName'],
)
console.log('Entity Metadata ID:', metadataById.MetadataId)

// Multi-connection tool using secondary connection
const metadataSecondary = await dataverseAPI.getEntityMetadata(
  'account',
  true,
  ['LogicalName'],
  'secondary',
)
```

#### `dataverseAPI.getEntityRelatedMetadata(entityLogicalName, relatedPath, relatedProperties?, connectionTarget?)`

_Requires v1.0.17_ — Get related metadata for a specific entity (attributes, relationships, etc.).

- `entityLogicalName: string` — Logical name of the entity
- `relatedPath: EntityRelatedMetadataPath` — Path after `EntityDefinitions(LogicalName='name')`. Supports collections and specific records, e.g. `Attributes`, `Keys`, `ManyToOneRelationships`, `Attributes(LogicalName='name')`, `Attributes(LogicalName='industrycode')/OptionSet`
- `relatedProperties?: string[]` — Optional array of property or column names to retrieve (retrieves all if not specified)
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<EntityRelatedMetadataResponse<P>>` — Returns either a collection (`{ value: [...] }`) or a single metadata object depending on `relatedPath`.

```typescript
// Get all attributes for an entity
const attributes = await dataverseAPI.getEntityRelatedMetadata(
  'account',
  'Attributes',
)

// Get specific attributes with select
const filteredAttributes = await dataverseAPI.getEntityRelatedMetadata(
  'account',
  'Attributes',
  ['LogicalName', 'DisplayName', 'AttributeType'],
)

// Get one-to-many relationships
const relationships = await dataverseAPI.getEntityRelatedMetadata(
  'account',
  'OneToManyRelationships',
)

// Get a single attribute definition (returns an object)
const nameAttribute = await dataverseAPI.getEntityRelatedMetadata(
  'account',
  "Attributes(LogicalName='name')",
)
console.log('Attribute type:', nameAttribute.AttributeType)

// Multi-connection tool using secondary connection
const attributesSecondary = await dataverseAPI.getEntityRelatedMetadata(
  'account',
  'Attributes',
  ['LogicalName'],
  'secondary',
)
```

#### `dataverseAPI.getAllEntitiesMetadata(entityProperties?, connectionTarget?)`

_Requires v1.0.17_ — Get metadata for all entities.

- `entityProperties?: string[]` — Optional array of property or column names to retrieve (retrieves `LogicalName`, `DisplayName`, `MetadataId` by default)
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<{ value: any[] }>` — Object with a `value` array containing all entity metadata.

```typescript
const allEntities = await dataverseAPI.getAllEntitiesMetadata([
  'LogicalName',
  'DisplayName',
  'EntitySetName',
])
console.log(`Total entities: ${allEntities.value.length}`)

// Multi-connection tool using secondary connection
const allEntitiesSecondary = await dataverseAPI.getAllEntitiesMetadata(
  ['LogicalName'],
  'secondary',
)
```

#### `dataverseAPI.getEntitySetName(logicalName)`

_Requires v1.0.17_ — Get the entity set name for a given logical name. No `connectionTarget` needed. This
works in most scenarios, but if you have custom entities with non-standard pluralization you may need to
retrieve the metadata instead.

- `logicalName: string` — Logical name of the entity

Returns: `Promise<string>` — Entity set name as a string.

```typescript
const tableSetName = await dataverseAPI.getEntitySetName('contact')
console.log('Entity Set Name for contact:', tableSetName) // Outputs: contacts
```

### CSDL Metadata Document

#### `dataverseAPI.getCSDLDocument(connectionTarget?)`

_Requires v1.0.20_ — Retrieve the complete CSDL/EDMX metadata document for the Dataverse environment.
Returns the full OData service document as raw XML containing comprehensive metadata for all entities,
actions, functions, and complex types in the environment. The response is automatically compressed with
gzip during transfer and decompressed transparently.

- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<string>` — Raw CSDL/EDMX XML document (typically 1-5MB).

What's included in the CSDL document:

- `EntityType` definitions (tables/entities)
- `Property` elements (attributes/columns)
- `NavigationProperty` elements (relationships)
- `ComplexType` definitions (return types for actions/functions)
- `EnumType` definitions (picklist/choice enumerations)
- `Action` definitions (OData Actions - POST operations)
- `Function` definitions (OData Functions - GET operations)
- `EntityContainer` metadata

```typescript
// Get the CSDL metadata document
const csdlXml = await dataverseAPI.getCSDLDocument()

// Parse it using DOMParser
const parser = new DOMParser()
const xmlDoc = parser.parseFromString(csdlXml, 'text/xml')

// Example 1: Extract all custom actions
// Actions are defined with <Action> elements in the schema
const actions = xmlDoc.querySelectorAll('Action')
const customActions = []

actions.forEach((action) => {
  const actionName = action.getAttribute('Name')
  const isBound = action.getAttribute('IsBound') === 'true'

  // Get parameters
  const parameters = []
  action.querySelectorAll('Parameter').forEach((param) => {
    parameters.push({
      name: param.getAttribute('Name'),
      type: param.getAttribute('Type'),
      nullable: param.getAttribute('Nullable') !== 'false',
    })
  })

  // Get return type
  const returnType = action.querySelector('ReturnType')

  customActions.push({
    name: actionName,
    isBound,
    parameters,
    returnType: returnType ? returnType.getAttribute('Type') : null,
  })
})

console.log('Found', customActions.length, 'actions')
customActions.forEach((action) => {
  console.log(`- ${action.name} (${action.isBound ? 'Bound' : 'Unbound'})`)
  action.parameters.forEach((param) => {
    console.log(`  Parameter: ${param.name} (${param.type})`)
  })
  if (action.returnType) {
    console.log(`  Returns: ${action.returnType}`)
  }
})

// Example 2: Extract all functions
// Functions are defined with <Function> elements in the schema
const functions = xmlDoc.querySelectorAll('Function')
const customFunctions = []

functions.forEach((func) => {
  const funcName = func.getAttribute('Name')
  const isBound = func.getAttribute('IsBound') === 'true'
  const isComposable = func.getAttribute('IsComposable') === 'true'

  const parameters = []
  func.querySelectorAll('Parameter').forEach((param) => {
    parameters.push({
      name: param.getAttribute('Name'),
      type: param.getAttribute('Type'),
      nullable: param.getAttribute('Nullable') !== 'false',
    })
  })

  const returnType = func.querySelector('ReturnType')

  customFunctions.push({
    name: funcName,
    isBound,
    isComposable,
    parameters,
    returnType: returnType ? returnType.getAttribute('Type') : null,
  })
})

console.log('Found', customFunctions.length, 'functions')

// Example 3: Find a specific action by name
function findAction(xmlDoc, actionName) {
  const actions = xmlDoc.querySelectorAll('Action')
  for (const action of actions) {
    if (action.getAttribute('Name') === actionName) {
      return {
        name: actionName,
        isBound: action.getAttribute('IsBound') === 'true',
        parameters: Array.from(action.querySelectorAll('Parameter')).map(
          (p) => ({
            name: p.getAttribute('Name'),
            type: p.getAttribute('Type'),
            nullable: p.getAttribute('Nullable') !== 'false',
          }),
        ),
        returnType: action.querySelector('ReturnType')?.getAttribute('Type'),
      }
    }
  }
  return null
}

// Search for a common Dataverse action like GrantAccess
const grantAccessAction = findAction(xmlDoc, 'GrantAccess')
if (grantAccessAction) {
  console.log('GrantAccess action details:', grantAccessAction)
}

// You can also search for functions using a similar pattern
function findFunction(xmlDoc, functionName) {
  const functions = xmlDoc.querySelectorAll('Function')
  for (const func of functions) {
    if (func.getAttribute('Name') === functionName) {
      return {
        name: functionName,
        isBound: func.getAttribute('IsBound') === 'true',
        isComposable: func.getAttribute('IsComposable') === 'true',
        parameters: Array.from(func.querySelectorAll('Parameter')).map((p) => ({
          name: p.getAttribute('Name'),
          type: p.getAttribute('Type'),
          nullable: p.getAttribute('Nullable') !== 'false',
        })),
        returnType: func.querySelector('ReturnType')?.getAttribute('Type'),
      }
    }
  }
  return null
}

// WhoAmI is a function, not an action
const whoAmIFunction = findFunction(xmlDoc, 'WhoAmI')

// Example 4: Extract entity type definitions
const entityTypes = xmlDoc.querySelectorAll('EntityType')

entityTypes.forEach((entityType) => {
  const name = entityType.getAttribute('Name')

  const properties = []
  entityType.querySelectorAll('Property').forEach((prop) => {
    properties.push({
      name: prop.getAttribute('Name'),
      type: prop.getAttribute('Type'),
      nullable: prop.getAttribute('Nullable') !== 'false',
    })
  })

  const navProps = []
  entityType.querySelectorAll('NavigationProperty').forEach((nav) => {
    navProps.push({
      name: nav.getAttribute('Name'),
      type: nav.getAttribute('Type'),
      partner: nav.getAttribute('Partner'),
    })
  })

  console.log(`Entity: ${name}`)
})

// Example 5: Extract complex types (return types for actions/functions)
const complexTypes = xmlDoc.querySelectorAll('ComplexType')

complexTypes.forEach((complexType) => {
  const name = complexType.getAttribute('Name')
  const properties = []

  complexType.querySelectorAll('Property').forEach((prop) => {
    properties.push({
      name: prop.getAttribute('Name'),
      type: prop.getAttribute('Type'),
    })
  })

  console.log(`ComplexType: ${name}`)
})

// Example 6: Find all actions that return a specific type
function findActionsByReturnType(xmlDoc, returnType) {
  const actions = xmlDoc.querySelectorAll('Action')
  const matchingActions = []

  actions.forEach((action) => {
    const actionReturnType = action.querySelector('ReturnType')
    if (
      actionReturnType &&
      actionReturnType.getAttribute('Type').includes(returnType)
    ) {
      matchingActions.push(action.getAttribute('Name'))
    }
  })

  return matchingActions
}

const actionsReturningGuid = findActionsByReturnType(xmlDoc, 'Edm.Guid')
console.log('Actions returning Guid:', actionsReturningGuid)
```

> **Pro tip:** The CSDL document is large (1-5MB). Consider caching it if you need to reference it
> multiple times, or use specific metadata endpoints like `getEntityMetadata()` or
> `getEntityRelatedMetadata()` for targeted queries.
>
> **XML namespaces:** The CSDL document uses XML namespaces. When querying, you may need to handle
> namespaces appropriately. The examples above use simple `querySelectorAll()` which works for element
> names, but for more complex queries, consider using namespace-aware XML parsing.

#### `dataverseAPI.getSolutions(selectColumns, connectionTarget?)`

_Requires v1.0.17_ — Get solutions from the environment.

- `selectColumns: string[]` — Required array of column names to retrieve (must contain at least one column)
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<{ value: any[] }>` — Object with a `value` array containing solutions.

```typescript
const solutions = await dataverseAPI.getSolutions([
  'solutionid',
  'uniquename',
  'friendlyname',
  'version',
  'ismanaged',
])
console.log(`Total solutions: ${solutions.value.length}`)
solutions.value.forEach((solution) => {
  console.log(
    `${solution.friendlyname} (${solution.uniquename}) - v${solution.version}`,
  )
})

// Multi-connection tool using secondary connection
const solutionsSecondary = await dataverseAPI.getSolutions(['uniquename'], 'secondary')
```

### Helper Methods

Power Platform ToolBox provides comprehensive metadata operations to programmatically create, read,
update, and delete Dataverse schema elements including entities, attributes, relationships, and option
sets.

> **Important:** Always call `dataverseAPI.publishCustomizations()` after making metadata changes to
> apply them to your environment.

#### `dataverseAPI.buildLabel(text, languageCode?)`

_Requires v1.0.20_ — Build a properly formatted `Label` object for use in metadata operations.

- `text: string` — The label text
- `languageCode?: number` — Optional language code (defaults to 1033 for English)

Returns: `Label` — Properly formatted label object.

```typescript
// Create a simple label (English by default)
const label = dataverseAPI.buildLabel('Customer Name')

// Create label with specific language code
const labelFrench = dataverseAPI.buildLabel('Nom du client', 1036)

// Label structure returned:
// {
//   LocalizedLabels: [{ Label: "Customer Name", LanguageCode: 1033, IsManaged: false }],
//   UserLocalizedLabel: { Label: "Customer Name", LanguageCode: 1033, IsManaged: false }
// }
```

#### `dataverseAPI.getAttributeODataType(attributeType)`

_Requires v1.0.20_ — Get the OData type name for a given attribute type. Useful when creating attribute
definitions.

- `attributeType: AttributeMetadataType` — Attribute type enum value

Returns: `string` — OData type name (e.g., `'Microsoft.Dynamics.CRM.StringAttributeMetadata'`).

```typescript
const odataType = dataverseAPI.getAttributeODataType(
  DataverseAPI.AttributeMetadataType.String,
)
console.log(odataType) // Output: "Microsoft.Dynamics.CRM.StringAttributeMetadata"

const lookupType = dataverseAPI.getAttributeODataType(
  DataverseAPI.AttributeMetadataType.Lookup,
)
console.log(lookupType) // Output: "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
```

### Entity Operations

#### `dataverseAPI.createEntityDefinition(entityDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Create a new entity (table) in Dataverse.

- `entityDefinition: object` — Entity metadata definition
- `options?: object` — Optional settings (e.g., `{ solutionUniqueName: "MySolution" }`)
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<{ id: string }>` — Object with the new entity's `MetadataId`.

```typescript
// Create a custom entity
const newEntity = await dataverseAPI.createEntityDefinition(
  {
    '@odata.type': 'Microsoft.Dynamics.CRM.EntityMetadata',
    LogicalName: 'new_project',
    DisplayName: dataverseAPI.buildLabel('Project'),
    DisplayCollectionName: dataverseAPI.buildLabel('Projects'),
    Description: dataverseAPI.buildLabel('Custom project tracking entity'),
    OwnershipType: 'UserOwned', // UserOwned, TeamOwned, OrganizationOwned, None
    IsActivity: false,
    HasActivities: true,
    HasNotes: true,
    Attributes: [
      {
        '@odata.type': 'Microsoft.Dynamics.CRM.StringAttributeMetadata',
        SchemaName: 'new_Name',
        DisplayName: dataverseAPI.buildLabel('Project Name'),
        RequiredLevel: { Value: 'ApplicationRequired' },
        MaxLength: 100,
        FormatName: { Value: 'Text' },
      },
    ],
  },
  { solutionUniqueName: 'MyCustomSolution' },
)

console.log('Created entity with ID:', newEntity.id)

// Publish to make it available
await dataverseAPI.publishCustomizations('new_project')
```

#### `dataverseAPI.updateEntityDefinition(entityIdentifier, entityDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Update an existing entity's metadata.

- `entityIdentifier: string` — Entity `MetadataId` or `LogicalName`
- `entityDefinition: object` — Updated entity metadata
- `options?: object` — Optional settings (e.g., `{ mergeLabels: true }`)
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Update entity display name and description
await dataverseAPI.updateEntityDefinition(
  'new_project',
  {
    DisplayName: dataverseAPI.buildLabel('Project Management'),
    Description: dataverseAPI.buildLabel(
      'Enhanced project tracking and management',
    ),
    HasNotes: false, // Disable notes
  },
  { mergeLabels: true },
)

await dataverseAPI.publishCustomizations('new_project')
```

#### `dataverseAPI.deleteEntityDefinition(entityIdentifier, connectionTarget?)`

_Requires v1.0.20_ — Delete an entity from Dataverse.

- `entityIdentifier: string` — Entity `MetadataId` or `LogicalName`
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Delete an entity - WARNING: This is permanent!
await dataverseAPI.deleteEntityDefinition('new_project')

// No need to publish after deletion - takes effect immediately
```

### Attribute Operations

#### `dataverseAPI.createAttribute(entityLogicalName, attributeDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Create a new attribute (column) on an entity.

- `entityLogicalName: string` — Logical name of the entity
- `attributeDefinition: object` — Attribute metadata definition
- `options?: object` — Optional settings (e.g., `{ solutionUniqueName: "MySolution" }`)
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<{ id: string }>` — Object with the new attribute's `MetadataId`.

```typescript
// Create a text field
const textAttribute = await dataverseAPI.createAttribute('new_project', {
  '@odata.type': dataverseAPI.getAttributeODataType(
    DataverseAPI.AttributeMetadataType.String,
  ),
  SchemaName: 'new_Description',
  DisplayName: dataverseAPI.buildLabel('Description'),
  Description: dataverseAPI.buildLabel('Project description'),
  RequiredLevel: { Value: 'None' }, // None, ApplicationRequired, SystemRequired
  MaxLength: 2000,
  FormatName: { Value: 'TextArea' }, // Text, TextArea, Email, Url, etc.
})

// Create a whole number field
const numberAttribute = await dataverseAPI.createAttribute('new_project', {
  '@odata.type': dataverseAPI.getAttributeODataType(
    DataverseAPI.AttributeMetadataType.Integer,
  ),
  SchemaName: 'new_EstimatedHours',
  DisplayName: dataverseAPI.buildLabel('Estimated Hours'),
  RequiredLevel: { Value: 'None' },
  MinValue: 0,
  MaxValue: 10000,
  Format: 'None', // None, Duration, Locale, TimeZone, Language
})

// Create a decimal field
const decimalAttribute = await dataverseAPI.createAttribute('new_project', {
  '@odata.type': dataverseAPI.getAttributeODataType(
    DataverseAPI.AttributeMetadataType.Decimal,
  ),
  SchemaName: 'new_Budget',
  DisplayName: dataverseAPI.buildLabel('Budget'),
  RequiredLevel: { Value: 'None' },
  MinValue: 0,
  MaxValue: 1000000000,
  Precision: 2,
})

// Create a date field
const dateAttribute = await dataverseAPI.createAttribute('new_project', {
  '@odata.type': dataverseAPI.getAttributeODataType(
    DataverseAPI.AttributeMetadataType.DateTime,
  ),
  SchemaName: 'new_StartDate',
  DisplayName: dataverseAPI.buildLabel('Start Date'),
  RequiredLevel: { Value: 'None' },
  Format: 'DateOnly', // DateOnly, DateAndTime
})

// Create a choice (option set) field - local
const choiceAttribute = await dataverseAPI.createAttribute('new_project', {
  '@odata.type': dataverseAPI.getAttributeODataType(
    DataverseAPI.AttributeMetadataType.Picklist,
  ),
  SchemaName: 'new_Priority',
  DisplayName: dataverseAPI.buildLabel('Priority'),
  RequiredLevel: { Value: 'ApplicationRequired' },
  OptionSet: {
    '@odata.type': 'Microsoft.Dynamics.CRM.OptionSetMetadata',
    IsGlobal: false,
    OptionSetType: 'Picklist',
    Options: [
      { Value: 1, Label: dataverseAPI.buildLabel('Low') },
      { Value: 2, Label: dataverseAPI.buildLabel('Medium') },
      { Value: 3, Label: dataverseAPI.buildLabel('High') },
    ],
  },
})

// Create a lookup field (single entity)
const lookupAttribute = await dataverseAPI.createAttribute('new_project', {
  '@odata.type': dataverseAPI.getAttributeODataType(
    DataverseAPI.AttributeMetadataType.Lookup,
  ),
  SchemaName: 'new_AccountId',
  DisplayName: dataverseAPI.buildLabel('Account'),
  RequiredLevel: { Value: 'None' },
  Targets: ['account'], // Entity types this lookup can reference
})

await dataverseAPI.publishCustomizations('new_project')
```

#### `dataverseAPI.updateAttribute(entityLogicalName, attributeIdentifier, attributeDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Update an existing attribute's metadata.

- `entityLogicalName: string` — Logical name of the entity
- `attributeIdentifier: string` — Attribute `MetadataId` or `LogicalName`
- `attributeDefinition: object` — Updated attribute metadata
- `options?: object` — Optional settings (e.g., `{ mergeLabels: true }`)
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Update attribute display name and requirement level
await dataverseAPI.updateAttribute(
  'new_project',
  'new_description',
  {
    DisplayName: dataverseAPI.buildLabel('Project Details'),
    RequiredLevel: { Value: 'ApplicationRequired' },
    MaxLength: 4000, // Increase max length
  },
  { mergeLabels: true },
)

await dataverseAPI.publishCustomizations('new_project')
```

#### `dataverseAPI.deleteAttribute(entityLogicalName, attributeIdentifier, connectionTarget?)`

_Requires v1.0.20_ — Delete an attribute from an entity.

- `entityLogicalName: string` — Logical name of the entity
- `attributeIdentifier: string` — Attribute `MetadataId` or `LogicalName`
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Delete an attribute - WARNING: This is permanent!
await dataverseAPI.deleteAttribute('new_project', 'new_description')

// Publish to complete the deletion
await dataverseAPI.publishCustomizations('new_project')
```

### Polymorphic Lookup Attributes

#### `dataverseAPI.createPolymorphicLookupAttribute(entityLogicalName, attributeDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Create a polymorphic lookup attribute that can reference multiple entity types
(e.g., a Customer field that can reference both Account and Contact).

- `entityLogicalName: string` — Logical name of the entity
- `attributeDefinition: object` — Lookup attribute metadata with `Targets` array
- `options?: object` — Optional settings
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<{ AttributeId: string }>` — Object with the new attribute's ID.

```typescript
// Create a Customer lookup (Account or Contact)
const customerLookup = await dataverseAPI.createPolymorphicLookupAttribute(
  'new_order',
  {
    SchemaName: 'new_CustomerId',
    DisplayName: dataverseAPI.buildLabel('Customer'),
    Description: dataverseAPI.buildLabel('The customer for this order'),
    RequiredLevel: { Value: 'ApplicationRequired' },
    Targets: ['account', 'contact'], // Can reference both entities
  },
)

// Create a Regarding lookup for notes (multiple custom entities)
const regardingLookup = await dataverseAPI.createPolymorphicLookupAttribute(
  'new_note',
  {
    SchemaName: 'new_RegardingId',
    DisplayName: dataverseAPI.buildLabel('Regarding'),
    RequiredLevel: { Value: 'None' },
    Targets: ['new_project', 'new_task', 'new_milestone'],
  },
)

await dataverseAPI.publishCustomizations()
```

> **Alternative:** For customer lookups specifically, you can use the `CreateCustomerRelationships`
> action via `dataverseAPI.execute()`, which creates both the lookup and relationships in a single
> operation.

### Relationship Operations

#### `dataverseAPI.createRelationship(relationshipDefinition, options?, connectionTarget?)`

_Requires v1.0.18_ — Create a new entity relationship (1:N or N:N).

- `relationshipDefinition: object` — Relationship metadata definition
- `options?: object` — Optional settings
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<{ id: string }>` — Object with the new relationship's `MetadataId`.

```typescript
// Create a One-to-Many (1:N) relationship
// Account (1) -> Projects (N)
const oneToManyRelationship = await dataverseAPI.createRelationship({
  '@odata.type': 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata',
  SchemaName: 'new_account_project',
  ReferencedEntity: 'account', // The "One" side
  ReferencedAttribute: 'accountid',
  ReferencingEntity: 'new_project', // The "Many" side
  Lookup: {
    '@odata.type': dataverseAPI.getAttributeODataType(
      DataverseAPI.AttributeMetadataType.Lookup,
    ),
    SchemaName: 'new_AccountId',
    DisplayName: dataverseAPI.buildLabel('Account'),
    RequiredLevel: { Value: 'None' },
  },
  CascadeConfiguration: {
    Assign: 'NoCascade', // NoCascade, Cascade, Active, UserOwned
    Delete: 'RemoveLink', // Cascade, RemoveLink, Restrict
    Merge: 'NoCascade',
    Reparent: 'NoCascade',
    Share: 'NoCascade',
    Unshare: 'NoCascade',
  },
})

// Create a Many-to-Many (N:N) relationship
// Projects (N) <-> Users (N) for team members
const manyToManyRelationship = await dataverseAPI.createRelationship({
  '@odata.type': 'Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata',
  SchemaName: 'new_project_systemuser',
  Entity1LogicalName: 'new_project',
  Entity1IntersectAttribute: 'new_projectid',
  Entity2LogicalName: 'systemuser',
  Entity2IntersectAttribute: 'systemuserid',
  IntersectEntityName: 'new_project_systemuser',
})

await dataverseAPI.publishCustomizations()
```

#### `dataverseAPI.updateRelationship(relationshipIdentifier, relationshipDefinition, options?, connectionTarget?)`

_Requires v1.0.18_ — Update an existing relationship's metadata.

- `relationshipIdentifier: string` — Relationship `MetadataId` or `SchemaName`
- `relationshipDefinition: object` — Updated relationship metadata
- `options?: object` — Optional settings
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Update cascade configuration for a relationship
// First retrieve the current relationship
const relationship = await dataverseAPI.queryData(
  `RelationshipDefinitions(SchemaName='new_account_project')`,
)

// Update cascade delete behavior
relationship.CascadeConfiguration.Delete = 'Cascade' // Change from RemoveLink to Cascade

await dataverseAPI.updateRelationship('new_account_project', relationship, {
  mergeLabels: true,
})

await dataverseAPI.publishCustomizations()
```

#### `dataverseAPI.deleteRelationship(relationshipIdentifier, connectionTarget?)`

_Requires v1.0.18_ — Delete a relationship.

- `relationshipIdentifier: string` — Relationship `MetadataId` or `SchemaName`
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Delete a relationship - WARNING: This is permanent!
await dataverseAPI.deleteRelationship('new_account_project')

await dataverseAPI.publishCustomizations()
```

### Global Option Sets

#### `dataverseAPI.createGlobalOptionSet(optionSetDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Create a new global option set (choice) that can be shared across multiple
entities.

- `optionSetDefinition: object` — Option set metadata definition
- `options?: object` — Optional settings
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<{ id: string }>` — Object with the new option set's `MetadataId`.

```typescript
// Create a global option set for project status
const globalOptionSet = await dataverseAPI.createGlobalOptionSet(
  {
    '@odata.type': 'Microsoft.Dynamics.CRM.OptionSetMetadata',
    Name: 'new_projectstatus',
    DisplayName: dataverseAPI.buildLabel('Project Status'),
    Description: dataverseAPI.buildLabel('Status values for projects'),
    OptionSetType: 'Picklist',
    IsGlobal: true,
    Options: [
      {
        Value: 1,
        Label: dataverseAPI.buildLabel('Planning'),
        Description: dataverseAPI.buildLabel('Project is in planning phase'),
      },
      { Value: 2, Label: dataverseAPI.buildLabel('In Progress') },
      { Value: 3, Label: dataverseAPI.buildLabel('On Hold') },
      { Value: 4, Label: dataverseAPI.buildLabel('Completed') },
      { Value: 5, Label: dataverseAPI.buildLabel('Cancelled') },
    ],
  },
  { solutionUniqueName: 'MyCustomSolution' },
)

console.log('Created global option set:', globalOptionSet.id)

await dataverseAPI.publishCustomizations()

// Retrieve the created option set
const optionSet = await dataverseAPI.queryData(
  "GlobalOptionSetDefinitions(Name='new_projectstatus')",
)
```

#### `dataverseAPI.updateGlobalOptionSet(optionSetIdentifier, optionSetDefinition, options?, connectionTarget?)`

_Requires v1.0.20_ — Update an existing global option set.

- `optionSetIdentifier: string` — Option set `Name` or `MetadataId`
- `optionSetDefinition: object` — Updated option set metadata
- `options?: object` — Optional settings
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Update global option set display name
await dataverseAPI.updateGlobalOptionSet(
  'new_projectstatus',
  {
    DisplayName: dataverseAPI.buildLabel('Project Lifecycle Status'),
    Description: dataverseAPI.buildLabel(
      'Tracks the full lifecycle of a project',
    ),
  },
  { mergeLabels: true },
)

await dataverseAPI.publishCustomizations()
```

#### `dataverseAPI.deleteGlobalOptionSet(optionSetIdentifier, connectionTarget?)`

_Requires v1.0.20_ — Delete a global option set.

- `optionSetIdentifier: string` — Option set `Name` or `MetadataId`
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Delete a global option set - WARNING: This is permanent!
await dataverseAPI.deleteGlobalOptionSet('new_projectstatus')

await dataverseAPI.publishCustomizations()
```

### Option Value Operations

#### `dataverseAPI.insertOptionValue(params, connectionTarget?)`

_Requires v1.0.20_ — Insert a new option value into a local or global option set.

- `params: object` — Parameters for the option value
  - `EntityLogicalName?: string` — Entity name (for local option sets)
  - `AttributeLogicalName?: string` — Attribute name (for local option sets)
  - `OptionSetName?: string` — Option set name (for global option sets)
  - `Value: number` — Integer value for the new option
  - `Label: Label` — Label object for the option
  - `Description?: Label` — Optional description
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<void>`.

```typescript
// Add option to a local option set
await dataverseAPI.insertOptionValue({
  EntityLogicalName: 'new_project',
  AttributeLogicalName: 'new_priority',
  Value: 4,
  Label: dataverseAPI.buildLabel('Critical'),
  Description: dataverseAPI.buildLabel('Requires immediate attention'),
})

// Add option to a global option set
await dataverseAPI.insertOptionValue({
  OptionSetName: 'new_projectstatus',
  Value: 6,
  Label: dataverseAPI.buildLabel('Archived'),
})

await dataverseAPI.publishCustomizations()
```

> **Status columns:** For status choice columns (`statuscode`), use the `InsertStatusValue` action via
> `dataverseAPI.execute()` instead, which requires a `StateCode` parameter.

#### `dataverseAPI.updateOptionValue(params, connectionTarget?)`

_Requires v1.0.20_ — Update an existing option value.

- `params: object` — Parameters for the update
  - `EntityLogicalName?: string` — Entity name (for local option sets)
  - `AttributeLogicalName?: string` — Attribute name (for local option sets)
  - `OptionSetName?: string` — Option set name (for global option sets)
  - `Value: number` — Integer value to update
  - `Label?: Label` — New label
  - `Description?: Label` — New description
  - `MergeLabels?: boolean` — Whether to merge or replace labels
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<Record<string, unknown>>`.

```typescript
// Update local option set value
await dataverseAPI.updateOptionValue({
  EntityLogicalName: 'new_project',
  AttributeLogicalName: 'new_priority',
  Value: 3,
  Label: dataverseAPI.buildLabel('High Priority'),
  MergeLabels: true,
})

await dataverseAPI.publishCustomizations()
```

#### `dataverseAPI.deleteOptionValue(params, connectionTarget?)`

_Requires v1.0.20_ — Delete an option value from an option set.

- `params: object` — Parameters for deletion
  - `EntityLogicalName?: string` — Entity name (for local option sets)
  - `AttributeLogicalName?: string` — Attribute name (for local option sets)
  - `OptionSetName?: string` — Option set name (for global option sets)
  - `Value: number` — Integer value to delete
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<Record<string, unknown>>`.

```typescript
// Delete option from local option set
await dataverseAPI.deleteOptionValue({
  EntityLogicalName: 'new_project',
  AttributeLogicalName: 'new_priority',
  Value: 4,
})

await dataverseAPI.publishCustomizations()
```

#### `dataverseAPI.orderOption(params, connectionTarget?)`

_Requires v1.0.20_ — Reorder option values in an option set.

- `params: object` — Parameters for reordering
  - `EntityLogicalName?: string` — Entity name (for local option sets)
  - `AttributeLogicalName?: string` — Attribute name (for local option sets)
  - `OptionSetName?: string` — Option set name (for global option sets)
  - `Values: number[]` — Array of values in the desired order
- `connectionTarget?: 'primary' | 'secondary'` — Connection target

Returns: `Promise<Record<string, unknown>>`.

```typescript
// Reorder local option set values
await dataverseAPI.orderOption({
  EntityLogicalName: 'new_project',
  AttributeLogicalName: 'new_priority',
  Values: [3, 2, 1], // High, Medium, Low
})

await dataverseAPI.publishCustomizations()
```

### Actions & Functions

#### `dataverseAPI.execute(request, connectionTarget?)`

_Requires v1.0.17_ — Execute a custom action or function using a unified interface. Supports both bound
(entity-specific) and unbound (global) operations.

- `request.entityName: string` — Logical name of the entity (required for bound operations)
- `request.entityId: string` — GUID of the record (required for bound operations)
- `request.operationName: string` — Name of the action/function
- `request.operationType: 'action' | 'function'` — Type of operation
- `request.parameters: Record<string, unknown>` — Operation parameters (optional)
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<Record<string, unknown>>` — Operation result.

```typescript
// Bound action - operates on a specific entity record
const boundResult = await dataverseAPI.execute({
  entityName: 'systemuser',
  entityId: 'user-guid',
  operationName: 'SetBusinessSystemUser',
  operationType: 'action',
  parameters: {
    BusinessUnit: 'businessunits(bu-guid)',
    ReassignPrincipal: 'systemusers(user-guid)',
    DoNotMoveAllRecords: true,
  },
})

// Unbound function - global operation
const unboundResult = await dataverseAPI.execute({
  operationName: 'WhoAmI',
  operationType: 'function',
})

// Multi-connection tool using secondary connection
const unboundResultSecondary = await dataverseAPI.execute(
  {
    operationName: 'WhoAmI',
    operationType: 'function',
  },
  'secondary',
)
```

### Customizations

#### `dataverseAPI.publishCustomizations(tableLogicalName?, connectionTarget?)`

_Requires v1.0.17_ — Publish customizations for the current environment.

- `tableLogicalName?: string` — Optional table (entity) logical name to publish. If omitted, all pending
  customizations are published.
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<void>`.

```typescript
// Publish all customizations for the primary connection
await dataverseAPI.publishCustomizations()

// Publish only the account table customizations for the secondary connection
await dataverseAPI.publishCustomizations('account', 'secondary')
```

#### `dataverseAPI.deploySolution(solutionContent, options?, connectionTarget?)`

_Requires v1.0.17_ — Deploy (import) a Dataverse solution.

- `solutionContent: string | ArrayBuffer | ArrayBufferView` — Base64 solution zip or binary data
- `options?: { importJobId?: string; publishWorkflows?: boolean; overwriteUnmanagedCustomizations?: boolean; skipProductUpdateDependencies?: boolean; convertToManaged?: boolean }` — Optional import settings
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<{ ImportJobId: string }>` — Import job identifier for tracking status.

```typescript
const solutionFile = await toolboxAPI.fileSystem.readBinary('/path/to/solution.zip')

const result = await dataverseAPI.deploySolution(solutionFile, {
  publishWorkflows: true,
  overwriteUnmanagedCustomizations: false,
})

console.log('Solution deployment started. Import Job ID:', result.ImportJobId)
```

#### `dataverseAPI.getImportJobStatus(importJobId, connectionTarget?)`

_Requires v1.0.17_ — Get the status of a solution import job.

- `importJobId: string` — Import job GUID returned by `deploySolution()`
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target. Defaults to `'primary'`.

Returns: `Promise<Record<string, unknown>>` — Import status details and progress data.

```typescript
const deployResult = await dataverseAPI.deploySolution(solutionFile)
const importJobId = deployResult.ImportJobId

const status = await dataverseAPI.getImportJobStatus(importJobId)
console.log('Import status:', status)
```

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/dataverse-api](https://docs.powerplatformtoolbox.com/tool-development/api-reference/dataverse-api)

## PowerPlatform API

The PowerPlatform API provides direct access to Power Platform service endpoints from tool webviews. For
the Microsoft reference, see the [Power Platform REST API
documentation](https://learn.microsoft.com/en-us/rest/api/power-platform/). For complete TypeScript
definitions, install the `@pptb/types` package:

```bash
npm install --save-dev @pptb/types
```

### Overview

Use the API through `window.powerplatformAPI`. The surface is organized into service namespaces, and
each namespace exposes the same shared HTTP client methods.

Prerequisite setup is required before using `window.powerplatformAPI`:

- Create and configure your own Microsoft Entra app registration for Power Platform API authentication,
  following [Enable programmability and API
  support](https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2).
- Configure the required Power Platform API permissions on that app registration, based on the
  [Programmability permission
  reference](https://learn.microsoft.com/en-us/power-platform/admin/programmability-permission-reference).
- In your Power Platform ToolBox connection settings, populate the App Registration Client ID.
- In that same connection, enable the **Enabled for Power Platform** option.

You can inspect this state from the ToolBox connections API through
`Connection.enabledForPowerPlatformAPI` and `Connection.scopesForPowerPlatformAPI` (see
[ToolBox API](#toolbox-api)).

### Shared Client Methods

Every namespace on `window.powerplatformAPI` exposes the same method shape.

#### `Get(path?, connectionTarget?, headers?)`

Make a GET request to the namespace endpoint.

#### `Post(path?, body?, connectionTarget?, headers?)`

Make a POST request to the namespace endpoint.

#### `Put(path?, body?, connectionTarget?, headers?)`

Make a PUT request to the namespace endpoint.

#### `Patch(path?, body?, connectionTarget?, headers?)`

Make a PATCH request to the namespace endpoint.

#### `Delete(path?, connectionTarget?, headers?, body?)`

Make a DELETE request to the namespace endpoint. A request body is supported when the API requires
payload deletion.

Common parameters:

- `path?: string` — Relative path after the namespace base URL, including query string when needed
- `body?: unknown` — Optional request payload for write operations
- `connectionTarget?: 'primary' | 'secondary'` — Optional connection target, defaults to `'primary'`
- `headers?: Record<string, string>` — Optional custom request headers

Returns: `Promise<PowerPlatformResponse>`

```typescript
const powerplatform = window.powerplatformAPI

const response = await powerplatform.EnvironmentManagement.Get(
  'environments?api-version=2024-10-01',
)

console.log(response)
```

### Namespace Catalog

The type file currently exposes these namespaces. Each one uses the same shared client methods, so the
usage pattern stays consistent.

| Namespace | Example Usage |
| --- | --- |
| `Analytics` | `await powerplatform.Analytics.Get('reports?api-version=2024-10-01')` |
| `AppManagement` | `await powerplatform.AppManagement.Get('apps?api-version=2024-10-01')` |
| `Authorization` | `await powerplatform.Authorization.Get('roles?api-version=2024-10-01')` |
| `Connectivity` | `await powerplatform.Connectivity.Get('connections?api-version=2024-10-01')` |
| `CopilotStudio` | `await powerplatform.CopilotStudio.Get('environments?api-version=2024-10-01')` |
| `Dynamics` | `await powerplatform.Dynamics.Get('environments?api-version=2024-10-01')` |
| `EnvironmentManagement` | `await powerplatform.EnvironmentManagement.Get('environments?api-version=2024-10-01')` |
| `Governance` | `await powerplatform.Governance.Get('policies?api-version=2024-10-01')` |
| `Licensing` | `await powerplatform.Licensing.Get('subscriptions?api-version=2024-10-01')` |
| `PowerApps` | `await powerplatform.PowerApps.Get('environments/{environmentId}/apps/{app}?api-version=2024-10-01')` |
| `PowerAutomate` | `await powerplatform.PowerAutomate.Get('flows?api-version=2024-10-01')` |
| `PowerPages` | `await powerplatform.PowerPages.Get('sites?api-version=2024-10-01')` |
| `ResourceQuery` | `await powerplatform.ResourceQuery.Get('queries?api-version=2024-10-01')` |
| `UserManagement` | `await powerplatform.UserManagement.Get('users?api-version=2024-10-01')` |
| `WorkflowAgents` | `await powerplatform.WorkflowAgents.Get('agents?api-version=2024-10-01')` |

These examples show the naming pattern from the type file and the style of relative paths each namespace
accepts. The actual operation path depends on the specific Power Platform API you are calling.

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/powerplatform-api](https://docs.powerplatformtoolbox.com/tool-development/api-reference/powerplatform-api)

## Events API

Subscribe to platform events to respond to connection changes, settings updates, and tool lifecycle
events.

### Event Subscription

#### `toolboxAPI.events.on(handler)`

_Requires v1.0.17_ — Subscribe to events relevant to your tool.

```typescript
toolboxAPI.events.on((details, payload) => {
  switch (payload.event) {
    case 'connection:updated':
      refreshConnectionInfo()
      break
    case 'terminal:command:completed':
      handleCommandCompleted(payload.data)
      break
    case 'settings:updated':
      if (payload.data && payload.data.theme) {
        applyTheme(payload.data.theme)
      }
      break
  }
})
```

Parameters:

- `handler: (event: any, payload: ToolBoxEventPayload) => void` — Callback function to handle events

`ToolBoxEventPayload`:

```typescript
interface ToolBoxEventPayload {
  event: ToolBoxEvent
  data: unknown
  timestamp: string
}
```

### Event Types

The following events are available for subscription:

#### `tool:loaded` / `tool:unloaded`

_Requires v1.0.17_ — Fired when a tool instance is loaded or unloaded.

```typescript
toolboxAPI.events.on((_, payload) => {
  if (payload.event === 'tool:loaded') {
    initializeTool()
  }

  if (payload.event === 'tool:unloaded') {
    cleanupResources()
  }
})
```

#### `connection:created` / `connection:updated` / `connection:deleted`

_Requires v1.0.17_ — Fired when Dataverse connections are created, updated, or deleted.

```typescript
toolboxAPI.events.on((_, payload) => {
  if (payload.event === 'connection:updated') {
    console.log('Connection event:', payload.data)
    refreshConnectionInfo()
  }
})
```

#### `settings:updated`

_Requires v1.0.17_ — Fired when tool settings are changed.

```typescript
toolboxAPI.events.on((_, payload) => {
  if (payload.event === 'settings:updated') {
    console.log('Settings updated:', payload.data)
  }
})
```

#### `notification:shown`

_Requires v1.0.17_ — Fired when a notification is displayed.

```typescript
toolboxAPI.events.on((_, payload) => {
  if (payload.event === 'notification:shown') {
    console.log('Notification shown:', payload.data)
  }
})
```

#### `terminal:created` / `terminal:closed` / `terminal:output` / `terminal:command:completed` / `terminal:error`

_Requires v1.0.17_ — Fired for terminal lifecycle, output streaming, command completion, and terminal
errors.

```typescript
toolboxAPI.events.on((_, payload) => {
  switch (payload.event) {
    case 'terminal:created':
      console.log('Terminal created:', payload.data)
      break
    case 'terminal:output':
      console.log('Terminal output:', payload.data)
      break
    case 'terminal:command:completed':
      console.log('Command completed:', payload.data)
      break
    case 'terminal:error':
      console.error('Terminal error:', payload.data)
      break
  }
})
```

### Best Practices

> **Event handler registration:** Subscribe to events early in your tool's initialization to avoid
> missing important events.

#### Register Once

Register your event handler only once during initialization:

```typescript
// Good: Register once during initialization
function initializeTool() {
  toolboxAPI.events.on(handleEvent)
}

function handleEvent(event, payload) {
  // Handle all events in one place
}

initializeTool()
```

#### Avoid Multiple Handlers

Don't register multiple event handlers for the same events:

```typescript
// Bad: Multiple handlers
toolboxAPI.events.on(handler1)
toolboxAPI.events.on(handler2)

// Good: Single handler with routing
toolboxAPI.events.on((event, payload) => {
  switch (event) {
    case 'connection:updated':
      handleConnectionUpdate(payload)
      break
    case 'settings:updated':
      handleSettingsUpdate(payload)
      break
  }
})
```

#### Error Handling

Always wrap event handler logic in try-catch blocks:

```typescript
toolboxAPI.events.on((event, payload) => {
  try {
    switch (payload.event) {
      case 'connection:updated':
        refreshData()
        break
      case 'settings:updated':
        applySettings(payload.data)
        break
    }
  } catch (error) {
    console.error('Error handling event:', payload.event, error)
  }
})
```

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/events](https://docs.powerplatformtoolbox.com/tool-development/api-reference/events)

## Settings API

The Settings API allows tool-specific settings to be stored and retrieved between sessions.

### Reading Settings

#### `toolboxAPI.settings.getAll()`

_Requires v1.0.17_ — Retrieve all settings for your tool.

Returns: `Promise<Record<string, any>>` — Object containing all settings key-value pairs.

```typescript
const settings = await toolboxAPI.settings.getAll()
console.log('All settings:', JSON.stringify(settings))

// Example output:
// {
//   "pageSize": 50,
//   "defaultColor": "blue",
//   "showAdvancedOptions": true,
//   "lastUsedFilter": "active"
// }
```

#### `toolboxAPI.settings.get(key)`

_Requires v1.0.17_ — Retrieve a specific setting by key.

- `key: string` — The setting key to retrieve

Returns: `Promise<any>` — Value of the setting or `undefined` if not found.

```typescript
const pageSize = await toolboxAPI.settings.get('pageSize')
console.log('Page Size setting:', pageSize) // Output: 50

// Handle missing settings with defaults
const pageSize2 = (await toolboxAPI.settings.get('pageSize')) || 25
const theme = (await toolboxAPI.settings.get('theme')) || 'light'
```

### Writing Settings

#### `toolboxAPI.settings.set(key, value)`

_Requires v1.0.17_ — Set a specific setting by key.

- `key: string` — The setting key to set
- `value: any` — The value to store for the setting (will be serialized to JSON)

Returns: `Promise<void>`.

```typescript
await toolboxAPI.settings.set('pageSize', 50)
await toolboxAPI.settings.set('defaultColor', 'blue')
await toolboxAPI.settings.set('showAdvancedOptions', true)

// Store complex objects
await toolboxAPI.settings.set('lastFilter', {
  type: 'status',
  value: 'active',
  appliedAt: new Date().toISOString(),
})
```

#### `toolboxAPI.settings.setAll(settings)`

_Requires v1.0.17_ — Set multiple settings at once.

- `settings: Record<string, any>` — Object containing key-value pairs to set

Returns: `Promise<void>`.

```typescript
await toolboxAPI.settings.setAll({
  defaultColor: 'blue',
  pageSize: 50,
  showAdvancedOptions: true,
  lastUsedFilter: 'active',
})
```

### Best Practices

#### Use Meaningful Keys

Use descriptive, namespaced keys to avoid conflicts:

```typescript
// Good: Descriptive keys
await toolboxAPI.settings.set('ui.pageSize', 50)
await toolboxAPI.settings.set('ui.theme', 'dark')
await toolboxAPI.settings.set('data.cacheExpiry', 3600)

// Bad: Vague keys
await toolboxAPI.settings.set('size', 50)
await toolboxAPI.settings.set('value', 'dark')
```

#### Provide Default Values

Always provide fallback values when reading settings:

```typescript
// Good: Default values
const pageSize = (await toolboxAPI.settings.get('pageSize')) || 25
const theme = (await toolboxAPI.settings.get('theme')) || 'light'

// Even better: Use a defaults object
const DEFAULTS = {
  pageSize: 25,
  theme: 'light',
  showWelcome: true,
}

async function getSetting(key) {
  const value = await toolboxAPI.settings.get(key)
  return value !== undefined ? value : DEFAULTS[key]
}
```

#### Validate Settings

Validate settings before using them:

```typescript
async function getPageSize() {
  const pageSize = await toolboxAPI.settings.get('pageSize')

  // Validate the value
  if (typeof pageSize === 'number' && pageSize > 0 && pageSize <= 100) {
    return pageSize
  }

  // Return default if invalid
  return 25
}
```

#### Batch Updates

When updating multiple settings, use `setAll()` for better performance:

```typescript
// Good: Batch update
await toolboxAPI.settings.setAll({
  pageSize: 50,
  sortColumn: 'name',
  sortDirection: 'asc',
  filters: { status: 'active' },
})

// Bad: Multiple individual updates
await toolboxAPI.settings.set('pageSize', 50)
await toolboxAPI.settings.set('sortColumn', 'name')
await toolboxAPI.settings.set('sortDirection', 'asc')
await toolboxAPI.settings.set('filters', { status: 'active' })
```

#### Store Only User Preferences

Store only user preferences, not application state or temporary data:

```typescript
// Good: User preferences
await toolboxAPI.settings.set('defaultView', 'grid')
await toolboxAPI.settings.set('itemsPerPage', 50)

// Bad: Temporary/application state (use local state instead)
await toolboxAPI.settings.set('currentPageNumber', 3)
await toolboxAPI.settings.set('selectedItems', [1, 2, 3])
```

#### Handle Errors

Always handle potential errors when working with settings:

```typescript
try {
  await toolboxAPI.settings.set('pageSize', 50)
} catch (error) {
  console.error('Failed to save setting:', error)
  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: 'Failed to save preferences',
    type: 'error',
  })
}
```

### Examples

#### Save and Load Form Preferences

```typescript
// Save form state
async function saveFormPreferences(formData) {
  await toolboxAPI.settings.setAll({
    'form.defaultEnvironment': formData.environment,
    'form.showAdvanced': formData.showAdvanced,
    'form.autoRefresh': formData.autoRefresh,
  })
}

// Load form state
async function loadFormPreferences() {
  const settings = await toolboxAPI.settings.getAll()

  return {
    environment: settings['form.defaultEnvironment'] || 'production',
    showAdvanced: settings['form.showAdvanced'] || false,
    autoRefresh: settings['form.autoRefresh'] || true,
  }
}
```

#### Theme Preference

```typescript
// Apply and save theme preference
async function setTheme(theme) {
  // Apply theme to UI
  document.body.classList.remove('theme-light', 'theme-dark')
  document.body.classList.add(`theme-${theme}`)

  // Save preference
  await toolboxAPI.settings.set('ui.theme', theme)
}

// Load theme on startup
async function loadTheme() {
  const theme = (await toolboxAPI.settings.get('ui.theme')) || 'light'
  document.body.classList.add(`theme-${theme}`)
}
```

#### Data Grid Preferences

```typescript
// Save grid configuration
async function saveGridConfig(config) {
  await toolboxAPI.settings.setAll({
    'grid.pageSize': config.pageSize,
    'grid.sortColumn': config.sortColumn,
    'grid.sortDirection': config.sortDirection,
    'grid.visibleColumns': config.visibleColumns,
    'grid.density': config.density,
  })
}

// Load grid configuration
async function loadGridConfig() {
  const settings = await toolboxAPI.settings.getAll()

  return {
    pageSize: settings['grid.pageSize'] || 25,
    sortColumn: settings['grid.sortColumn'] || 'name',
    sortDirection: settings['grid.sortDirection'] || 'asc',
    visibleColumns: settings['grid.visibleColumns'] || [
      'name',
      'status',
      'date',
    ],
    density: settings['grid.density'] || 'comfortable',
  }
}
```

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/settings-api](https://docs.powerplatformtoolbox.com/tool-development/api-reference/settings-api)

## File System API

The File System API provides secure access to read and write files, manage directories, and interact
with the local file system. All functions include path validation for security.

> **Migration notice:** `saveFile()` and `selectPath()` have been migrated from `toolboxAPI.utils` to
> `toolboxAPI.fileSystem`. Update your code accordingly.

### Reading Files

#### `toolboxAPI.fileSystem.readText(path)`

_Requires v1.0.20_ — Read a UTF-8 text file (useful for configs, JSON files, manifests, etc.).

- `path: string` — Absolute path to the file

Returns: `Promise<string>` — File content as UTF-8 string.

```typescript
try {
  const configPath = '/path/to/config.json'
  const content = await toolboxAPI.fileSystem.readText(configPath)
  const config = JSON.parse(content)
  console.log('Config loaded:', config)
} catch (error) {
  console.error('Failed to read config:', error)
}
```

#### `toolboxAPI.fileSystem.readBinary(path)`

_Requires v1.0.20_ — Read a binary file as a Buffer (useful for ZIPs, images for hashing/upload, etc.).
Properly serializes over IPC.

- `path: string` — Absolute path to the file

Returns: `Promise<Buffer>` — File content as Buffer.

```typescript
try {
  const imagePath = '/path/to/image.png'
  const buffer = await toolboxAPI.fileSystem.readBinary(imagePath)
  console.log('Image size:', buffer.length, 'bytes')

  // Use buffer for hashing, upload, or other operations
  const hash = crypto.createHash('sha256').update(buffer).digest('hex')
  console.log('Image hash:', hash)
} catch (error) {
  console.error('Failed to read image:', error)
}
```

### File System Queries

#### `toolboxAPI.fileSystem.exists(path)`

_Requires v1.0.20_ — Lightweight check to verify if a file or directory exists before performing I/O
operations.

- `path: string` — Absolute path to check

Returns: `Promise<boolean>` — `true` if path exists, `false` otherwise.

```typescript
const configPath = '/path/to/config.json'

if (await toolboxAPI.fileSystem.exists(configPath)) {
  const content = await toolboxAPI.fileSystem.readText(configPath)
  console.log('Config exists and loaded')
} else {
  console.log('Config file not found, using defaults')
}
```

#### `toolboxAPI.fileSystem.stat(path)`

_Requires v1.0.20_ — Get metadata about a file or directory.

- `path: string` — Absolute path to the file or directory

Returns: `Promise<FileStats>` — File/directory metadata.

```typescript
const filePath = '/path/to/file.txt'
const stats = await toolboxAPI.fileSystem.stat(filePath)

console.log('Type:', stats.type) // 'file' or 'directory'
console.log('Size:', stats.size, 'bytes')
console.log('Modified:', new Date(stats.mtime))
```

`FileStats` interface:

```typescript
interface FileStats {
  type: 'file' | 'directory' // Type of the path
  size: number // Size in bytes
  mtime: string // Last modified timestamp (ISO string)
}
```

#### `toolboxAPI.fileSystem.readDirectory(path)`

_Requires v1.0.20_ — List the contents of a directory.

- `path: string` — Absolute path to the directory

Returns: `Promise<DirectoryEntry[]>` — Array of directory entries.

```typescript
const dirPath = '/path/to/directory'
const contents = await toolboxAPI.fileSystem.readDirectory(dirPath)

contents.forEach((item) => {
  console.log(`${item.name} (${item.type})`)
})

// Filter for specific types
const files = contents.filter((item) => item.type === 'file')
const directories = contents.filter((item) => item.type === 'directory')

console.log(`Found ${files.length} files and ${directories.length} directories`)
```

`DirectoryEntry` interface:

```typescript
interface DirectoryEntry {
  name: string // Name of the file or directory
  type: 'file' | 'directory' // Type of the entry
}
```

### Writing Files

#### `toolboxAPI.fileSystem.writeText(path, content)`

_Requires v1.0.20_ — Save text content to a file without a dialog prompt. Useful for automated exports
and backups.

- `path: string` — Absolute path where the file should be saved
- `content: string` — Text content to write

Returns: `Promise<void>`.

```typescript
const exportData = {
  accounts: [],
  contacts: [],
  timestamp: new Date().toISOString(),
}

const exportPath = '/path/to/export.json'
await toolboxAPI.fileSystem.writeText(
  exportPath,
  JSON.stringify(exportData, null, 2),
)

console.log('Export saved to:', exportPath)
```

#### `toolboxAPI.fileSystem.createDirectory(path)`

_Requires v1.0.20_ — Create a directory recursively (creates parent directories as needed).

- `path: string` — Absolute path of the directory to create

Returns: `Promise<void>`.

```typescript
const backupDir = '/path/to/backups/2024/january'
await toolboxAPI.fileSystem.createDirectory(backupDir)

console.log('Directory created:', backupDir)

// Now you can write files to this directory
await toolboxAPI.fileSystem.writeText(
  `${backupDir}/backup.json`,
  JSON.stringify(data),
)
```

### User-Interactive Operations

#### `toolboxAPI.fileSystem.saveFile(defaultPath, content, filters?)`

_Requires v1.0.20_ — Save content to a file with a user-selected location. Opens a native save dialog.

> **Migrated from Utils:** This function was previously `toolboxAPI.utils.saveFile()`. Update your code
> to use `toolboxAPI.fileSystem.saveFile()`.

- `defaultPath: string` — Suggested file name and path for the save dialog
- `content: string | Buffer` — Content to save (text or binary)
- `filters: FileDialogFilter[]` — Optional file type filters. If not provided, filters are auto-derived
  from the file extension

Returns: `Promise<string | null>` — File path or `null` if cancelled.

`FileDialogFilter` interface:

```typescript
interface FileDialogFilter {
  name: string // Display name for the filter (e.g., "JSON Files")
  extensions: string[] // File extensions without dots (e.g., ["json", "txt"])
}
```

```typescript
// Save with custom filters
const jsonData = { accounts: [], contacts: [] }
const filePath = await toolboxAPI.fileSystem.saveFile(
  'export.json',
  JSON.stringify(jsonData, null, 2),
  [
    { name: 'JSON', extensions: ['json'] },
    { name: 'Text', extensions: ['txt'] },
  ],
)

if (filePath) {
  console.log('File saved to:', filePath)

  await toolboxAPI.utils.showNotification({
    title: 'Export Successful',
    body: `Data exported to ${filePath}`,
    type: 'success',
  })
} else {
  console.log('Save cancelled')
}
```

```typescript
// Save without filters (auto-derived from extension)
const configXml = '<config><setting>value</setting></config>'
const filePath = await toolboxAPI.fileSystem.saveFile('config.xml', configXml)

if (filePath) {
  console.log('File saved to:', filePath)
}
```

#### `toolboxAPI.fileSystem.selectPath(options?)`

_Requires v1.0.20_ — Open a native dialog to select either a file or a folder and return the chosen
path.

> **Migrated from Utils:** This function was previously `toolboxAPI.utils.selectPath()`. Update your
> code to use `toolboxAPI.fileSystem.selectPath()`.

- `options` — Optional configuration object
  - `type: 'file' | 'folder'` — Type of selection dialog
  - `title: string` — Dialog window title
  - `message: string` — Message shown in the dialog
  - `buttonLabel: string` — Custom label for the confirm button
  - `defaultPath: string` — Initial file/folder path
  - `filters: Array<{ name: string; extensions: string[] }>` — File filters (file dialogs only)

Returns: `Promise<string | null>` — Selected path or `null` if cancelled.

```typescript
// Select a folder
const folderPath = await toolboxAPI.fileSystem.selectPath({
  type: 'folder',
  title: 'Select Export Folder',
})

if (folderPath) {
  console.log('Selected folder:', folderPath)
  // Save files to the selected folder
  await toolboxAPI.fileSystem.writeText(
    `${folderPath}/export.json`,
    JSON.stringify(data),
  )
} else {
  console.log('Selection cancelled')
}
```

```typescript
// Select a file
const filePath = await toolboxAPI.fileSystem.selectPath({
  type: 'file',
  title: 'Select Configuration File',
  filters: [
    { name: 'JSON Files', extensions: ['json'] },
    { name: 'All Files', extensions: ['*'] },
  ],
})

if (filePath) {
  console.log('Selected file:', filePath)
  // Read the selected file
  const content = await toolboxAPI.fileSystem.readText(filePath)
  console.log('File content:', content)
}
```

### Best Practices

#### Always Use Absolute Paths

The File System API requires absolute paths for security:

```typescript
// Good: Absolute path
const filePath = '/Users/john/Documents/export.json'
await toolboxAPI.fileSystem.readText(filePath)

// Bad: Relative path (will fail)
const filePathBad = './export.json'
await toolboxAPI.fileSystem.readText(filePathBad)
```

#### Check File Existence

Always check if a file exists before reading:

```typescript
const configPath = '/path/to/config.json'

if (await toolboxAPI.fileSystem.exists(configPath)) {
  const content = await toolboxAPI.fileSystem.readText(configPath)
  // Process content
} else {
  // Use defaults or prompt user
  console.log('Config not found, using defaults')
}
```

#### Handle Errors Gracefully

Wrap file operations in try-catch blocks:

```typescript
try {
  const content = await toolboxAPI.fileSystem.readText(filePath)
  return JSON.parse(content)
} catch (error) {
  console.error('Failed to read file:', error)

  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: 'Failed to read configuration file',
    type: 'error',
  })

  return null
}
```

#### Create Directories Before Writing

Ensure directories exist before writing files:

```typescript
const exportDir = '/path/to/exports'
const exportFile = `${exportDir}/data.json`

// Create directory if it doesn't exist
await toolboxAPI.fileSystem.createDirectory(exportDir)

// Now write the file
await toolboxAPI.fileSystem.writeText(exportFile, JSON.stringify(data))
```

#### Use Proper Encodings

Use `readText` for text files and `readBinary` for binary files:

```typescript
// Good: Text files
const jsonContent = await toolboxAPI.fileSystem.readText('/path/to/config.json')
const xmlContent = await toolboxAPI.fileSystem.readText('/path/to/data.xml')

// Good: Binary files
const imageBuffer = await toolboxAPI.fileSystem.readBinary('/path/to/image.png')
const zipBuffer = await toolboxAPI.fileSystem.readBinary('/path/to/archive.zip')
```

### Examples

#### Export Data with User Selection

```typescript
async function exportData(data) {
  try {
    // Generate filename with timestamp
    const timestamp = new Date().toISOString().replace(/:/g, '-')
    const filename = `export-${timestamp}.json`

    // Let user choose where to save
    const filePath = await toolboxAPI.fileSystem.saveFile(
      filename,
      JSON.stringify(data, null, 2),
    )

    if (filePath) {
      await toolboxAPI.utils.showNotification({
        title: 'Export Successful',
        body: `Data exported to ${filePath}`,
        type: 'success',
      })
    }
  } catch (error) {
    console.error('Export failed:', error)

    await toolboxAPI.utils.showNotification({
      title: 'Export Failed',
      body: error.message,
      type: 'error',
    })
  }
}
```

#### Import Configuration File

```typescript
async function importConfig() {
  try {
    // Let user select a config file
    const filePath = await toolboxAPI.fileSystem.selectPath({
      type: 'file',
      title: 'Select Configuration File',
      filters: [{ name: 'JSON Files', extensions: ['json'] }],
    })

    if (!filePath) {
      console.log('Import cancelled')
      return null
    }

    // Read and parse the file
    const content = await toolboxAPI.fileSystem.readText(filePath)
    const config = JSON.parse(content)

    await toolboxAPI.utils.showNotification({
      title: 'Import Successful',
      body: 'Configuration loaded successfully',
      type: 'success',
    })

    return config
  } catch (error) {
    console.error('Import failed:', error)

    await toolboxAPI.utils.showNotification({
      title: 'Import Failed',
      body: 'Failed to load configuration file',
      type: 'error',
    })

    return null
  }
}
```

#### Batch Export to Directory

```typescript
async function batchExport(datasets) {
  try {
    // Let user select export directory
    const exportDir = await toolboxAPI.fileSystem.selectPath({
      type: 'folder',
      title: 'Select Export Directory',
    })

    if (!exportDir) {
      console.log('Export cancelled')
      return
    }

    // Create timestamped subdirectory
    const timestamp = new Date().toISOString().split('T')[0]
    const batchDir = `${exportDir}/export-${timestamp}`
    await toolboxAPI.fileSystem.createDirectory(batchDir)

    // Export each dataset
    for (const [name, data] of Object.entries(datasets)) {
      const filePath = `${batchDir}/${name}.json`
      await toolboxAPI.fileSystem.writeText(
        filePath,
        JSON.stringify(data, null, 2),
      )
    }

    await toolboxAPI.utils.showNotification({
      title: 'Batch Export Complete',
      body: `${Object.keys(datasets).length} files exported to ${batchDir}`,
      type: 'success',
    })
  } catch (error) {
    console.error('Batch export failed:', error)

    await toolboxAPI.utils.showNotification({
      title: 'Export Failed',
      body: error.message,
      type: 'error',
    })
  }
}
```

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/filesystem-api](https://docs.powerplatformtoolbox.com/tool-development/api-reference/filesystem-api)

## Error Handling

All API calls may throw errors. This section covers best practices for handling errors gracefully and
providing meaningful feedback to users.

### Basic Error Handling

Always wrap API calls in try-catch blocks to handle potential errors:

```typescript
try {
  const account = await dataverseAPI.retrieve('account', accountId)
  // Process account
} catch (error) {
  console.error('Failed to retrieve account:', error)

  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: error.message,
    type: 'error',
    duration: 0, // Persistent
  })
}
```

#### Handling Multiple Operations

When performing multiple operations, decide whether to stop on first error or continue:

```typescript
// Stop on first error
async function importRecords(records) {
  try {
    for (const record of records) {
      await dataverseAPI.create('account', record)
    }

    await toolboxAPI.utils.showNotification({
      title: 'Success',
      body: `${records.length} records imported`,
      type: 'success',
    })
  } catch (error) {
    console.error('Import failed:', error)

    await toolboxAPI.utils.showNotification({
      title: 'Import Failed',
      body: error.message,
      type: 'error',
    })
  }
}
```

```typescript
// Continue on errors and collect results
async function importRecordsWithReport(records) {
  const results = {
    success: [],
    failed: [],
  }

  for (const record of records) {
    try {
      const id = await dataverseAPI.create('account', record)
      results.success.push({ record, id })
    } catch (error) {
      results.failed.push({ record, error: error.message })
    }
  }

  // Show summary
  await toolboxAPI.utils.showNotification({
    title: 'Import Complete',
    body: `${results.success.length} succeeded, ${results.failed.length} failed`,
    type: results.failed.length > 0 ? 'warning' : 'success',
  })

  return results
}
```

### API-Specific Errors

#### Dataverse API Errors

Dataverse API errors typically include HTTP status codes and detailed messages:

```typescript
try {
  await dataverseAPI.retrieve('account', invalidId)
} catch (error) {
  console.error('Dataverse error:', error)

  // Error object structure
  // {
  //   message: "Error message",
  //   status: 404,
  //   statusText: "Not Found"
  // }

  let userMessage = 'Failed to retrieve record'

  if (error.status === 404) {
    userMessage = 'Record not found'
  } else if (error.status === 403) {
    userMessage = 'You do not have permission to access this record'
  } else if (error.status === 401) {
    userMessage = 'Authentication failed. Please reconnect.'
  }

  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: userMessage,
    type: 'error',
  })
}
```

#### Connection Errors

Handle cases where no connection is available:

```typescript
async function fetchData() {
  try {
    const connection = await toolboxAPI.connections.getActiveConnection()

    if (!connection) {
      await toolboxAPI.utils.showNotification({
        title: 'No Connection',
        body: 'Please connect to a Dataverse environment',
        type: 'warning',
      })
      return
    }

    // Proceed with data fetch
    const data = await dataverseAPI.queryData('accounts?$top=10')
    return data
  } catch (error) {
    console.error('Failed to fetch data:', error)

    await toolboxAPI.utils.showNotification({
      title: 'Error',
      body: 'Failed to fetch data from Dataverse',
      type: 'error',
    })
  }
}
```

#### File System Errors

Handle file system operations with specific error messages:

```typescript
async function loadConfiguration(filePath) {
  try {
    // Check if file exists
    const exists = await toolboxAPI.fileSystem.exists(filePath)

    if (!exists) {
      await toolboxAPI.utils.showNotification({
        title: 'File Not Found',
        body: `Configuration file not found at ${filePath}`,
        type: 'warning',
      })
      return null
    }

    // Read and parse file
    const content = await toolboxAPI.fileSystem.readText(filePath)
    const config = JSON.parse(content)

    return config
  } catch (error) {
    console.error('Failed to load configuration:', error)

    let message = 'Failed to load configuration file'

    if (error.name === 'SyntaxError') {
      message = 'Configuration file contains invalid JSON'
    } else if (error.message.includes('permission')) {
      message = 'Permission denied. Check file permissions.'
    }

    await toolboxAPI.utils.showNotification({
      title: 'Error',
      body: message,
      type: 'error',
    })

    return null
  }
}
```

### User Feedback

#### Notification Types

Use appropriate notification types for different scenarios:

```typescript
// Success - Operation completed successfully
await toolboxAPI.utils.showNotification({
  title: 'Success',
  body: 'Data exported successfully',
  type: 'success',
  duration: 3000,
})

// Info - Informational message
await toolboxAPI.utils.showNotification({
  title: 'Info',
  body: 'Processing 100 records...',
  type: 'info',
  duration: 5000,
})

// Warning - Non-critical issue
await toolboxAPI.utils.showNotification({
  title: 'Warning',
  body: 'Some records were skipped',
  type: 'warning',
  duration: 0, // Persistent
})

// Error - Critical failure
await toolboxAPI.utils.showNotification({
  title: 'Error',
  body: 'Failed to connect to Dataverse',
  type: 'error',
  duration: 0, // Persistent
})
```

### Best Practices

#### 1. Always Use Try-Catch

Never assume an API call will succeed:

```typescript
// Good
try {
  const data = await dataverseAPI.queryData('accounts')
} catch (error) {
  handleError(error)
}

// Bad
const data = await dataverseAPI.queryData('accounts')
```

#### 2. Log Errors for Debugging

Always log errors with context:

```typescript
try {
  await dataverseAPI.create('account', record)
} catch (error) {
  // Log with context
  console.error('Failed to create account:', {
    error: error.message,
    record: record,
    timestamp: new Date().toISOString(),
  })

  // Show user-friendly message
  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: 'Failed to create account',
    type: 'error',
  })
}
```

#### 3. Provide Actionable Messages

Tell users what went wrong and what they can do:

```typescript
// Good: Specific and actionable
await toolboxAPI.utils.showNotification({
  title: 'Connection Failed',
  body: 'Could not connect to Dataverse. Please check your connection and try again.',
  type: 'error',
})

// Bad: Vague
await toolboxAPI.utils.showNotification({
  title: 'Error',
  body: 'Something went wrong',
  type: 'error',
})
```

#### 4. Hide Technical Details

Don't expose technical errors to users:

```typescript
try {
  await dataverseAPI.create('account', record)
} catch (error) {
  // Good: User-friendly message
  await toolboxAPI.utils.showNotification({
    title: 'Failed to Create Record',
    body: 'Unable to create the account. Please verify your data and try again.',
    type: 'error',
  })

  // Technical details go to console
  console.error('Technical error:', error)
}

// Bad: Exposing technical details
await toolboxAPI.utils.showNotification({
  title: 'Error',
  body: error.stack, // Don't show stack traces to users
  type: 'error',
})
```

#### 5. Clean Up Resources

Always clean up resources in finally blocks:

```typescript
let terminal

try {
  terminal = await toolboxAPI.terminal.create({ name: 'Build' })
  await toolboxAPI.terminal.execute(terminal.id, 'npm install')
} catch (error) {
  console.error('Build failed:', error)

  await toolboxAPI.utils.showNotification({
    title: 'Build Failed',
    body: error.message,
    type: 'error',
  })
} finally {
  // Always close terminal
  if (terminal) {
    await toolboxAPI.terminal.close(terminal.id)
  }
}
```

#### 6. Validate Input

Validate user input before making API calls:

```typescript
async function createAccount(name, email) {
  // Validate input
  if (!name || name.trim() === '') {
    await toolboxAPI.utils.showNotification({
      title: 'Validation Error',
      body: 'Account name is required',
      type: 'warning',
    })
    return
  }

  if (email && !isValidEmail(email)) {
    await toolboxAPI.utils.showNotification({
      title: 'Validation Error',
      body: 'Please enter a valid email address',
      type: 'warning',
    })
    return
  }

  // Proceed with API call
  try {
    const id = await dataverseAPI.create('account', {
      name,
      emailaddress1: email,
    })

    await toolboxAPI.utils.showNotification({
      title: 'Success',
      body: 'Account created successfully',
      type: 'success',
    })

    return id
  } catch (error) {
    console.error('Failed to create account:', error)

    await toolboxAPI.utils.showNotification({
      title: 'Error',
      body: 'Failed to create account',
      type: 'error',
    })
  }
}
```

#### 7. Implement Retry Logic

For transient errors, implement retry logic:

```typescript
async function retryOperation(operation, maxRetries = 3, delay = 1000) {
  let lastError

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await operation()
    } catch (error) {
      lastError = error
      console.log(`Attempt ${i + 1} failed:`, error.message)

      if (i < maxRetries - 1) {
        // Wait before retrying
        await new Promise((resolve) => setTimeout(resolve, delay * (i + 1)))
      }
    }
  }

  // All retries failed
  throw lastError
}

// Usage
try {
  const data = await retryOperation(() =>
    dataverseAPI.queryData('accounts?$top=10'),
  )
} catch (error) {
  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: 'Failed to fetch data after multiple attempts',
    type: 'error',
  })
}
```

### Common Error Scenarios

#### HTTP Error Codes

| Status | Meaning | User Message |
| --- | --- | --- |
| 400 | Bad Request | Invalid request. Please check your data. |
| 401 | Unauthorized | Authentication failed. Please reconnect. |
| 403 | Forbidden | You don't have permission to perform this action. |
| 404 | Not Found | Record not found. It may have been deleted. |
| 429 | Too Many Requests | Too many requests. Please wait and try again. |
| 500 | Internal Server Error | Server error. Please try again later. |
| 503 | Service Unavailable | Service temporarily unavailable. Please try again later. |

#### Example Implementation

```typescript
async function handleDataverseError(error) {
  const statusMessages = {
    400: 'Invalid request. Please check your data.',
    401: 'Authentication failed. Please reconnect.',
    403: "You don't have permission to perform this action.",
    404: 'Record not found. It may have been deleted.',
    429: 'Too many requests. Please wait and try again.',
    500: 'Server error. Please try again later.',
    503: 'Service temporarily unavailable. Please try again later.',
  }

  const message = statusMessages[error.status] || 'An unexpected error occurred'

  await toolboxAPI.utils.showNotification({
    title: 'Error',
    body: message,
    type: 'error',
    duration: 0,
  })
}
```

Source: [docs.powerplatformtoolbox.com/tool-development/api-reference/error-handling](https://docs.powerplatformtoolbox.com/tool-development/api-reference/error-handling)

## CSP Configuration

Configure Content Security Policy exceptions for your tools to access external resources while
maintaining security.

### Overview

Power Platform ToolBox implements per-tool Content Security Policy (CSP) configuration to allow tools to
make external API calls and load external resources while maintaining security. This feature requires
explicit user consent before granting any CSP exceptions.

### What is CSP?

Content Security Policy (CSP) is a security standard that helps prevent Cross-Site Scripting (XSS)
attacks and other code injection attacks by controlling which resources can be loaded by a web page.

By default, PPTB enforces a strict CSP for all tools:

- Scripts and styles can only be loaded from the tool itself
- Network requests can only be made to the tool itself
- Images can be loaded from the tool, data URIs, or HTTPS sources
- External fonts and other resources are restricted

### Why Per-Tool CSP?

Some tools need to:

- Make API calls to other external services
- Load external libraries from CDNs (e.g., visualization libraries)
- Load external stylesheets or fonts
- Embed external content

Rather than weakening security for all tools, PPTB allows each tool to request only the specific CSP
exceptions it needs, and users must explicitly grant these permissions.

### How It Works

#### For Tool Users

- **First Launch** — When you launch a tool that requires CSP exceptions for the first time, you'll see
  a consent dialog.
- **Review Permissions** — The dialog shows exactly what external resources the tool wants to access.
- **Grant or Decline** — You can choose to accept or decline the permissions. If you accept, the tool
  loads with the requested CSP exceptions; if you decline, the tool will not load.
- **Stored Consent** — If you accept, your consent is stored and you won't be asked again for that tool.
- **Security Enforcement** — The system enforces that CSP exceptions are only applied if consent has
  been granted.
- **Revoke Consent** — You can revoke consent at any time via the IPC API.

#### For Tool Developers

Tools can specify CSP exceptions in their `package.json` manifest (see [CSP Exceptions
Object](#csp-exceptions-object) for the full field reference):

```json
{
  "name": "@power-maverick/dataverse-erd-generator",
  "displayName": "Dataverse ERD Generator",
  "version": "1.0.0",
  "description": "Generate Entity Relationship Diagrams from Dataverse",
  "author": "Power Maverick",
  "icon": "icons/test.svg",
  "features": {
    "minAPI": "1.2.0"
  },
  "cspExceptions": {
    "connect-src": [
      {
        "domain": "https://*.dynamics.com",
        "exceptionReason": "Required to **fetch** metadata and records from Dataverse."
      },
      {
        "domain": "https://*.crm*.dynamics.com",
        "exceptionReason": "Required to connect to region-specific Dataverse environments."
      }
    ],
    "script-src": [
      {
        "domain": "https://cdn.jsdelivr.net",
        "exceptionReason": "Loads the Mermaid diagram library used to render ERDs."
      }
    ],
    "style-src": [
      {
        "domain": "https://cdn.jsdelivr.net",
        "exceptionReason": "Loads Mermaid's bundled stylesheet.",
        "optional": true
      }
    ],
    "img-src": [
      {
        "domain": "https://example.com/images",
        "exceptionReason": "Displays entity icons in the diagram."
      }
    ],
    "mailto": [
      {
        "domain": "mailto:url",
        "exceptionReason": "Allows users to click email links in the tool."
      }
    ]
  }
}
```

Once the CSP exception is added, the tool must be reloaded to trigger the consent dialog on next launch.

### Security Considerations

#### Implementation Details

CSP enforcement flow:

1. Tool's CSP exceptions are read from `package.json` during installation/loading.
2. When a tool is launched, the system checks if it has CSP exceptions.
3. If exceptions exist, the system checks if user has granted consent.
4. If not granted, a consent dialog is shown to the user.
5. When the tool's HTML is served, `WebviewProtocolManager` checks consent status.
6. CSP exceptions are only applied if consent has been granted.
7. Without consent, the tool receives only the default restrictive CSP.

This ensures that even if a tool declares CSP exceptions, they are not applied until the user explicitly
grants permission.

#### For Users

- Only install tools from trusted sources.
- Review CSP exceptions carefully before granting consent.
- Watch for suspicious patterns like requests to unusual domains.
- Revoke consent if you no longer use a tool.

#### Developer Guidelines

- Never request `*` or overly broad wildcards.
- Validate and sanitize all user input.
- Use HTTPS for all external resources.
- Keep dependencies up to date.
- Follow the principle of least privilege.

### Supported CSP Directives

PPTB supports the following CSP directives for per-tool configuration (see [CSP Exceptions
Object](#csp-exceptions-object) for the shared entry shape — `domain`, `exceptionReason`, `optional`):

| Directive | Description |
| --- | --- |
| `connect-src` | Controls which URLs can be loaded via XHR, fetch, WebSocket, etc. |
| `script-src` | Controls which sources can load JavaScript. |
| `style-src` | Controls which sources can load CSS. |
| `img-src` | Controls which sources can load images. |
| `font-src` | Controls which sources can load fonts. |
| `frame-src` | Controls which sources can be embedded in frames. |
| `media-src` | Controls which sources can load video/audio. |
| `mailto` | Controls whether `mailto:` links are allowed. |

```json
// connect-src example
[
  {
    "domain": "https://*.dynamics.com",
    "exceptionReason": "Fetches metadata and records from Dataverse."
  }
]
```

```json
// frame-src example
[
  {
    "domain": "https://trusted-domain.com",
    "exceptionReason": "Embeds the interactive report viewer."
  }
]
```

```json
// mailto example
[
  {
    "domain": "mailto:url",
    "exceptionReason": "Allows users to click email links in the tool."
  }
]
```

### Default CSP Policy

Tools start with this default CSP policy:

```
default-src 'self';
script-src 'self' 'unsafe-inline';
style-src 'self' 'unsafe-inline';
img-src 'self' data: https:;
font-src 'self' data:;
connect-src 'self';
```

Tool-specified exceptions are added to these defaults, not replaced.

### Best Practices

#### 1. Request Only What You Need

Only request CSP exceptions for resources your tool actually needs. Users are more likely to trust
tools that request minimal permissions.

Bad example:

```json
{
  "cspExceptions": {
    "connect-src": ["*"], // Too broad!
    "script-src": ["*"] // Dangerous!
  }
}
```

Good example:

```json
{
  "cspExceptions": {
    "connect-src": [
      {
        "domain": "https://api.powerbi.com",
        "exceptionReason": "Embeds Power BI reports."
      },
      {
        "domain": "https://*.dynamics.com",
        "exceptionReason": "Fetches Dataverse metadata."
      }
    ],
    "script-src": [
      {
        "domain": "https://cdn.jsdelivr.net/npm/mermaid@9",
        "exceptionReason": "Loads the Mermaid diagram library."
      }
    ]
  }
}
```

#### 2. Use Specific Domains

Use the most specific domain patterns possible. Wildcards should be used sparingly.

- Prefer: `https://cdn.example.com`
- Over: `https://*.example.com`
- Avoid: `https:` (allows any HTTPS site)

#### 3. Document Your Requirements

Use the `exceptionReason` property on each entry to explain why your tool needs the exception. This
description supports markdown and is shown to users in the consent dialog, helping them make an informed
decision.

```json
"cspExceptions": {
  "connect-src": [
    {
      "domain": "https://*.dynamics.com",
      "exceptionReason": "Required to **fetch metadata** from Dataverse"
    }
  ],
  "script-src": [
    {
      "domain": "https://cdn.jsdelivr.net",
      "exceptionReason": "Required to load the **Mermaid** diagram library"
    }
  ]
}
```

Mark any exception as `"optional": true` when the core tool works without it and it only enables
additional functionality:

```json
"cspExceptions": {
  "style-src": [
    {
      "domain": "https://fonts.googleapis.com",
      "exceptionReason": "Loads the preferred UI font. The tool works with the system font if this is declined.",
      "optional": true
    }
  ]
}
```

#### 4. Consider Alternatives

Before requesting CSP exceptions, consider if there are alternatives:

- Can you bundle the library instead of loading from CDN?
- Can you proxy API calls through a secure backend?
- Can you use PPTB's built-in [Dataverse API](#dataverse-api) instead of direct calls?

### Revoking Consent

> UI for this is planned for a future release.

Users can revoke CSP consent for any tool:

1. Go to Settings.
2. Navigate to Security / CSP Permissions (future feature).
3. Find the tool and click "Revoke Consent".
4. The next time the tool is launched, the consent dialog will appear again.

Alternatively, consent is stored in the user settings file and can be manually edited.

### Registry Configuration

When publishing a tool to the PPTB registry, include the `cspExceptions` in your registry entry:

```json
{
  "id": "dataverse-erd-generator",
  "name": "Dataverse ERD Generator",
  "version": "1.0.0",
  "author": "Power Maverick",
  "downloadUrl": "...",
  "cspExceptions": {
    "connect-src": [
      {
        "domain": "https://*.dynamics.com",
        "exceptionReason": "Fetches metadata and records from Dataverse."
      }
    ],
    "script-src": [
      {
        "domain": "https://cdn.jsdelivr.net",
        "exceptionReason": "Loads the Mermaid diagram library."
      }
    ]
  }
}
```

Local tools can also specify CSP exceptions in their `package.json`. The same consent flow applies when
loading local development tools.

### Troubleshooting

#### Tool Shows CSP Violation Errors

Symptom: Browser console shows CSP violation errors.

Solution:

- Check if you've granted CSP consent for the tool.
- Verify the tool's CSP exceptions include the blocked resource.
- Contact the tool developer if the exceptions are incorrect.

#### CSP Dialog Doesn't Appear

Symptom: Tool doesn't load but no consent dialog is shown.

Solution:

- Check browser console for JavaScript errors.
- Clear the tool from the open tabs and try again.
- Check if consent was already granted in settings.

#### Can't Revoke Consent

Symptom: Want to revoke consent but can't find the option.

Solution:

- Use the developer console: `window.toolboxAPI.revokeCspConsent('tool-id')`.
- Manually edit the settings file located in the app's user data directory.
- Full UI for consent management is planned for a future release.

### Complete Example

Here's a complete example for a tool that needs Dataverse access and external libraries:

```json
{
  "name": "@your-org/your-tool",
  "displayName": "My Awesome Tool",
  "version": "1.0.0",
  "description": "A tool that does amazing things with Dataverse",
  "author": "Your Name",
  "main": "dist/index.html",
  "icon": "icons/test.svg",
  "features": {
    "minAPI": "1.2.0"
  },
  "cspExceptions": {
    "connect-src": [
      {
        "domain": "https://*.dynamics.com",
        "exceptionReason": "Required to **fetch metadata and records** from Dataverse."
      },
      {
        "domain": "https://*.crm*.dynamics.com",
        "exceptionReason": "Required to connect to region-specific Dataverse environments."
      }
    ],
    "script-src": [
      {
        "domain": "https://cdn.jsdelivr.net/npm/mermaid@10",
        "exceptionReason": "Loads the **Mermaid** library used to render entity relationship diagrams."
      }
    ],
    "style-src": [
      {
        "domain": "https://cdn.jsdelivr.net/npm/mermaid@10",
        "exceptionReason": "Loads Mermaid's bundled stylesheet for diagram rendering.",
        "optional": true
      }
    ]
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/your-org/your-tool"
  },
  "license": "MIT"
}
```

### Future Enhancements

Planned improvements for CSP configuration:

- **UI for Managing Consent** — Settings page to view and revoke all CSP consents.
- **Temporary Consent** — Option to grant one-time permission.
- **Detailed Audit Log** — Track when tools use their CSP permissions.
- **CSP Templates** — Pre-approved templates for common use cases (e.g., "Dataverse Access").
- **Warning Levels** — Different UI treatment for low-risk vs high-risk permissions.

### References

- [MDN: Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)
- [OWASP: Content Security Policy Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)

Source: [docs.powerplatformtoolbox.com/tool-development/csp-configuration](https://docs.powerplatformtoolbox.com/tool-development/csp-configuration)

## Local Validation

Use the `pptb-validate` CLI — shipped with `@pptb/types` — to validate your tool's `package.json`
against the same rules as the official Power Platform ToolBox review process, before you publish to
npm.

### Overview

When you submit a tool to the ToolBox registry, automated checks run the same validation pipeline that
`pptb-validate` mirrors locally. Running the validator before publishing helps you:

- Catch configuration problems early, without wasting npm version numbers.
- Reduce failed intake reviews caused by minor setup issues.
- Speed up the overall review process for you and for maintainers.

`pptb-validate` is a standalone copy of the review rules. If validation rules change in the official
pipeline, a new version of `@pptb/types` will be released — keep your dev dependency up to date to stay
in sync.

### Prerequisites

Install `@pptb/types` as a dev dependency in your tool project:

```bash
npm install --save-dev @pptb/types
```

The `pptb-validate` binary is automatically added to `node_modules/.bin/` on install.

### Quick Start

#### Option 1 — npm script (recommended)

Add a `validate` script to your tool's `package.json`:

```json
{
  "scripts": {
    "validate": "pptb-validate"
  }
}
```

Then run:

```bash
npm run validate
```

The npm script name (e.g. `validate`) is your choice. The binary installed by npm is always
`pptb-validate` — ensure the script value matches exactly.

#### Option 2 — npx (no script entry needed)

Run without adding a script entry, as long as `@pptb/types` is installed:

```bash
npx pptb-validate
```

#### Option 3 — point at a specific file

```bash
npx pptb-validate path/to/package.json
```

By default the tool looks for `package.json` in the current working directory.

### CLI Options

| Option | Description |
| --- | --- |
| `--skip-url-checks` | Skip URL reachability checks — faster and works offline |
| `--json` | Print results as a JSON object, suitable for CI pipelines |
| `--help`, `-h` | Show help information |

Examples:

```bash
# Full validation including URL reachability
npm run validate

# Fast / offline run — skip URL checks
npm run validate -- --skip-url-checks

# JSON output for CI pipelines
npx pptb-validate --json

# Validate a specific package.json
npx pptb-validate ./dist/package.json --skip-url-checks
```

### What Is Validated

The validator checks every field that the official review pipeline inspects:

| Field | Required | Rules |
| --- | --- | --- |
| `name` | ✅ | Must be a non-empty string |
| `version` | ✅ | Must be a non-empty string |
| `displayName` | ✅ | Must be a non-empty string |
| `description` | ✅ | Must be a non-empty string |
| `license` | ✅ | Must be one of the approved open-source identifiers |
| `contributors` | ✅ | Must be a non-empty array; each entry must have a `name` |
| `configurations.repository` | ✅ | Must be a valid GitHub URL |
| `configurations.readmeUrl` | ✅ | Must be a valid `raw.githubusercontent.com` URL |
| `icon` | ⚠️ optional | If present: relative POSIX SVG path under `dist/`; no absolute, Windows, or URL paths |
| `configurations.website` | ⚠️ optional | If present: must be a valid HTTPS URL |
| `configurations.funding` | ⚠️ optional | If present: must be a valid URL |
| `cspExceptions` | ⚠️ optional | Each directive must be an array of valid origin strings |
| `features.multiConnection` | ⚠️ optional | If present: must be `"required"`, `"optional"`, or `"none"` |
| `features.minAPI` | ⚠️ optional | If present: must be a valid semantic version string |

Approved licenses: `MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `GPL-2.0`, `GPL-3.0`, `LGPL-3.0`,
`ISC`, `AGPL-3.0-only`.

For the full reference of all `package.json` fields, see [Package Manifest](#package-manifest).

### Warnings vs Errors

| Category | Behaviour |
| --- | --- |
| Required fields missing or invalid (`name`, `version`, `displayName`, `description`, `license`, `contributors`, `configurations.repository`, `configurations.readmeUrl`) | ✖ Error — validation fails, exit code 1 |
| Optional fields absent (`icon`, `configurations.website`, `configurations.funding`) | ⚠ Warning — validation still passes, you are nudged to add them |
| Optional fields present but malformed (bad URL, invalid icon path, Windows absolute path, backslash separator, etc.) | ⚠ Warning or ✖ Error as appropriate |

A clean run with no errors exits with code 0. Any error exits with code 1. Warnings alone do not cause a
non-zero exit.

Sample human-readable output:

```
✔ Validation passed

  ✖ configurations.readmeUrl is missing
  ⚠ icon is not set (optional but recommended)
  ⚠ configurations.website is not set (optional but recommended)
```

### CI Pipeline Integration

Use `--json` to get machine-readable output and integrate `pptb-validate` into your GitHub Actions
workflow or other CI pipeline:

```yaml
# .github/workflows/validate.yml
name: Validate tool package

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npx pptb-validate --skip-url-checks
```

For structured results (e.g. to post a PR comment), capture the JSON output:

```bash
npx pptb-validate --json --skip-url-checks
```

```json
{
  "valid": true,
  "errors": [],
  "warnings": ["icon is not set (optional but recommended)"]
}
```

> Add `--skip-url-checks` in CI to avoid flaky failures caused by transient network issues or rate
> limiting from URL reachability checks.

Source: [docs.powerplatformtoolbox.com/tool-development/validation](https://docs.powerplatformtoolbox.com/tool-development/validation)

## Inter-Tool Invocation

Let one tool hand off to another — pass data in, get a result back, and keep the user's workflow
uninterrupted.

### Overview

Inter-Tool Invocation lets any installed PPTB tool launch another installed tool, pre-populate it with
data, and optionally receive a result when the second tool finishes.

```
Tool A (Caller)                            Tool B (Callee)
──────────────                             ───────────────
invocation.launchTool(                     invocation.getLaunchContext()
  "@my-org/entity-picker",      ─────►       → { entityName: "account" }
  { entityName: "account" }
)                                          // user picks a record …

        ◄──────────────────────────────    invocation.returnData(
result                                       { selectedId: "a1b2c3",
= { selectedId: "a1b2c3",                    selectedName: "Contoso" }
  selectedName: "Contoso" }               )
                                           ← PPTB auto-closes callee window
```

Key properties at a glance:

| Property | Detail |
| --- | --- |
| Promise-based | `launchTool()` returns a Promise that resolves when the callee calls `returnData()`, or resolves to `null` if the callee closes without returning. |
| Isolated windows | The callee opens in its own `BrowserView`, just like a normally launched tool. |
| Auto-close callee | After `returnData()` is called, PPTB automatically closes the callee window — the callee doesn't need to close itself. |
| Connection auto-inheritance | The callee automatically inherits the caller's active Dataverse connection (can be overridden). |
| One-at-a-time | Only one active callee per caller is supported. A second `launchTool` while a callee is active rejects immediately. |
| Optional contract | Shape of prefill data and return value is declared in `pptb.config.json` and validated by `pptb-validate`, but not enforced at runtime. |
| Capability tags | Callee tools declare capability tags; callers discover matching installed tools by tag. |
| "Return to Caller" banner | PPTB injects a dismissable banner in the callee window so users can return to the caller at any time. |
| Graceful degradation | Both data payloads are plain JSON (`Record<string, unknown>`), so missing fields degrade gracefully. |

### Part 1 – Callee (Accepting Invocations)

A callee is a tool that receives a launch request from another tool. You declare what data you accept
and what you return, then read the context on startup and send back your result when done.

#### Declaring the Invocation Contract

Create a `pptb.config.json` file at the root of your tool package (next to `package.json`). This file
tells PPTB — and any caller — what data your tool accepts as input and what it returns as output.

| Field | Required | Description |
| --- | --- | --- |
| `invocation.version` | Yes (when `invocation` is present) | Semver version of your contract (e.g. `"1.0.0"`). Bump when the shape of `prefill` or `returnTopic` changes. |
| `invocation.capabilities` | No | Array of capability tag strings (e.g. `["entity-picker"]`). Used by callers to discover your tool. |
| `invocation.prefill` | No | JSON-schema–style object describing the data a caller can pass in. |
| `invocation.prefill.properties` | No | Map of property names to `{ type?, enum?, items? }` descriptors. |
| `invocation.returnTopic` | No | JSON-schema–style object describing the data your tool returns. |
| `invocation.returnTopic.properties` | No | Map of property names to `{ type?, enum?, items? }` descriptors. |

Supported `type` values: `"string"`, `"number"`, `"boolean"`, `"object"`, `"array"`. Use `"enum"` to
restrict a string property to a fixed set of values. Use `"items"` to describe the element type of an
array.

Example `pptb.config.json`:

```json
{
  "invocation": {
    "version": "1.0.0",
    "capabilities": ["entity-picker"],
    "prefill": {
      "properties": {
        "entityName": { "type": "string" },
        "allowMultiSelect": { "type": "boolean" }
      }
    },
    "returnTopic": {
      "properties": {
        "selectedId": { "type": "string" },
        "selectedName": { "type": "string" }
      }
    }
  }
}
```

Run `pptb-validate` in your tool directory to validate both `package.json` and `pptb.config.json` before
publishing. See [Local Validation](#local-validation) for details.

#### Reading the Launch Context

When your tool starts up, call `toolboxAPI.invocation.getLaunchContext()` to check whether another tool
launched it and to read any prefill data.

```typescript
const ctx = await toolboxAPI.invocation.getLaunchContext()

if (ctx !== null) {
  // Tool was launched via inter-tool invocation
  const entityName = ctx.entityName as string
  // … use prefill data to set up your UI …
} else {
  // Tool was opened normally by the user
}
```

Signature:

```typescript
getLaunchContext(): Promise<Record<string, unknown> | null>
```

- Returns the prefill data object when invoked by another tool.
- Returns `null` when opened directly by the user.
- All values are `unknown` — cast or validate them before use.

#### Returning Data to the Caller

Once the user completes their task (selects a record, fills a form, etc.), call
`toolboxAPI.invocation.returnData()` to send the result back.

```typescript
await toolboxAPI.invocation.returnData({
  selectedId: 'a1b2c3d4-...',
  selectedName: 'Contoso Ltd.',
})
// PPTB automatically closes this window after delivering the result.
```

Signature:

```typescript
returnData(returnData: Record<string, unknown>): Promise<void>
```

- Resolves the Promise the caller is awaiting in `launchTool()`.
- PPTB automatically closes the callee window after delivery — no need to close it yourself.
- If the tool was not launched by another tool, this call is a no-op — safe to call unconditionally.

#### Standalone vs. Invoked Mode

A well-behaved callee works in both modes without any special configuration.

| Mode | `getLaunchContext()` returns | Expected behaviour |
| --- | --- | --- |
| Standalone (normal launch) | `null` | Show the full UI, no pre-populated state |
| Invoked by another tool | `Record<string, unknown>` | Pre-populate UI from context, show a confirm / return action |

```typescript
async function initTool() {
  const ctx = await toolboxAPI.invocation.getLaunchContext()

  if (ctx) {
    // Invoked mode — show a compact, targeted picker UI
    renderPickerUI({
      entityName: ctx.entityName as string,
      allowMultiSelect: (ctx.allowMultiSelect as boolean) ?? false,
      onConfirm: async (selection) => {
        await toolboxAPI.invocation.returnData(selection)
        // PPTB will auto-close this window after returnData completes
      },
    })
  } else {
    // Standalone mode — show the full explorer UI
    renderFullExplorerUI()
  }
}
```

#### Complete Callee Example

A minimal but complete callee for an entity-picker tool.

`pptb.config.json`:

```json
{
  "invocation": {
    "version": "1.0.0",
    "capabilities": ["entity-picker"],
    "prefill": {
      "properties": {
        "entityName": { "type": "string" },
        "allowMultiSelect": { "type": "boolean" }
      }
    },
    "returnTopic": {
      "properties": {
        "selectedId": { "type": "string" },
        "selectedName": { "type": "string" }
      }
    }
  }
}
```

`index.ts`:

```typescript
async function main() {
  const ctx = await toolboxAPI.invocation.getLaunchContext()

  if (ctx) {
    // Invoked by another tool — show a targeted picker
    const entityName = (ctx.entityName as string) ?? 'account'
    const records = await loadRecords(entityName)

    renderPicker(records, async (selected) => {
      // Send the selection back; PPTB auto-closes this window
      await toolboxAPI.invocation.returnData({
        selectedId: selected.id,
        selectedName: selected.name,
      })
    })
  } else {
    // Standalone — show the full entity browser
    renderFullBrowser()
  }
}

main()
```

### Part 2 – Caller (Launching Other Tools)

A caller is a tool that initiates an invocation — it opens another tool, optionally passes data, and
waits for a result.

#### Launching a Tool

Use `toolboxAPI.invocation.launchTool()` to open another installed tool and pass it prefill data.

```typescript
const result = await toolboxAPI.invocation.launchTool(
  '@my-org/entity-picker', // npm package name of the target tool
  { entityName: 'account' }, // prefill data (should match callee's prefill schema)
)
```

Signature:

```typescript
launchTool(
  targetToolId: string,
  prefillData?: Record<string, unknown>,
  options?: {
    primaryConnectionId?: string | null
    secondaryConnectionId?: string | null
    noReturn?: boolean
  },
): Promise<unknown>
```

| Parameter | Type | Description |
| --- | --- | --- |
| `targetToolId` | `string` | The npm package name of the tool to launch (e.g. `"@my-org/entity-picker"`). Must be installed. |
| `prefillData` | `Record<string, unknown>` | Optional data to pre-populate the callee's state. Shape should match the callee's `invocation.prefill` schema. |
| `options.primaryConnectionId` | `string \| null` | Override the primary Dataverse connection for the callee. Omit to auto-inherit the caller's connection. |
| `options.secondaryConnectionId` | `string \| null` | Override the secondary Dataverse connection. Omit to let PPTB prompt for it if the callee is a multi-connection tool. |
| `options.noReturn` | `boolean` | When `true`, signals the caller does not expect data back. The "Return to [Caller]" banner is suppressed in the callee. The Promise still resolves with `null` when the callee closes. |

Return value: A Promise that resolves with the `Record<string, unknown>` passed to `returnData()` by
the callee, or `null` if:

- the callee closes without calling `returnData`, or
- the user clicks the "Return to [this tool]" banner before `returnData` is called.

Only one callee per caller is active at a time. Calling `launchTool` a second time while a callee is
still open throws `"A callee invocation is already in progress"`.

The target tool must be installed in PPTB. If it is not found, `launchTool` throws an error.

If the callee declares `features.multiConnection: "required"` or `"optional"` and no
`options.secondaryConnectionId` is provided, PPTB automatically opens the multi-connection selector
before launching the callee. If the user cancels, `launchTool` throws `"Connection selection cancelled"`.

#### Handling the Return Value

Always check for `null` before using the result. The Promise resolves to `null` in two scenarios:

- The user closes the callee window without calling `returnData`.
- The user clicks the "Return to [CallerTool]" banner before the callee calls `returnData`.

```typescript
const result = await toolboxAPI.invocation.launchTool('@my-org/entity-picker', {
  entityName: 'contact',
})

if (result !== null) {
  const { selectedId, selectedName } = result as {
    selectedId: string
    selectedName: string
  }
  // Use the selection returned by the callee
  populateField('regardingobjectid', selectedId, selectedName)
} else {
  // User dismissed the picker without selecting — no change needed
}
```

#### Connection Auto-Inheritance

By default, the callee automatically inherits the caller's active Dataverse connection — no extra
configuration needed.

```typescript
// Callee automatically receives the same primary connection as this tool
const result = await toolboxAPI.invocation.launchTool('@my-org/entity-picker', {
  entityName: 'account',
})
```

To override with a specific connection, pass `options.primaryConnectionId`:

```typescript
const result = await toolboxAPI.invocation.launchTool(
  '@my-org/solution-importer',
  { solutionName: 'MySolution' },
  { primaryConnectionId: specificConnectionId },
)
```

Pass `null` to launch the callee with no connection at all:

```typescript
const result = await toolboxAPI.invocation.launchTool(
  '@my-org/entity-picker',
  {},
  { primaryConnectionId: null },
)
```

#### Tag-Based Capability Discovery

Instead of hard-coding a tool ID, you can discover all installed tools that declare a given capability
tag — great for building dynamic flyouts or "send to" menus.

```typescript
const pickers = await toolboxAPI.invocation.findToolsByCapability('entity-picker')
// pickers: Tool[] — all installed tools with "entity-picker" in their capabilities

if (pickers.length > 0) {
  const picker = pickers[0] as { id: string }
  const result = await toolboxAPI.invocation.launchTool(picker.id, {
    entityName: 'account',
  })
}
```

Signatures:

```typescript
findToolsByCapability(tag: CapabilityTag): Promise<unknown[]>
getKnownCapabilityTags(): Promise<Array<{ tag: string; description: string }>>
```

- `findToolsByCapability` — returns an array of matching installed `Tool` objects (empty array if none
  found).
- `getKnownCapabilityTags` — returns the full capability registry (fetched from Supabase, cached for 5
  minutes, falls back to a built-in list when offline).

Well-known capability tags:

| Tag | Description |
| --- | --- |
| `fetchxml` | Accept or process FetchXML queries |
| `entity-picker` | Browse and select a Dataverse entity (table) |
| `record-selector` | Browse and select a Dataverse record |
| `solution-selector` | Pick a Power Platform solution |
| `odata` | Accept or process OData queries |

The registry is updated without an app release — new tags are added to the backend table and become
immediately discoverable via `getKnownCapabilityTags()`. If you need a capability tag that is not in the
registry, submit a request to the PPTB team to have it added.

For IDE auto-complete on capability tags, import `CapabilityTag` from `@pptb/types`:

```typescript
import type { CapabilityTag } from '@pptb/types/pptbConfig'

const tag: CapabilityTag = 'fetchxml' // IDE will suggest known tags
const tools = await toolboxAPI.invocation.findToolsByCapability(tag)
```

Capability tags are a powerful way to build flexible, extensible tools that can integrate with any other
tool declaring the same tag — without needing to know specific tool IDs in advance. For example, a
"Send To ▾" flyout can list all installed tools with the `"fetchxml"` tag, letting the user pick their
preferred tool for processing a FetchXML query.

#### Complete Caller Example

```typescript
async function openEntityPicker(entityName: string) {
  let result: unknown

  try {
    result = await toolboxAPI.invocation.launchTool(
      '@my-org/entity-picker',
      { entityName, allowMultiSelect: false },
      // primaryConnectionId omitted → callee inherits this tool's connection
    )
  } catch (err) {
    // Tool not installed, already has an active callee, or launch failed
    await toolboxAPI.utils.showNotification({
      title: 'Cannot open picker',
      body: err instanceof Error ? err.message : String(err),
      type: 'error',
    })
    return
  }

  if (result === null) {
    // User dismissed the picker (closed window or clicked "Return to Caller")
    return
  }

  const { selectedId, selectedName } = result as {
    selectedId: string
    selectedName: string
  }
  setSelectedRecord(selectedId, selectedName)
}
```

### Publishing and Versioning

#### Publishing

When you publish your tool to npm, ensure that `pptb.config.json` is included in the published package
(next to `package.json`) so that PPTB can read the invocation contract when the tool is installed. To
include `pptb.config.json` in the npm package, add the following to your `package.json`:

```json
{
  "files": ["dist", "npm-shrinkwrap.json", "pptb.config.json"]
}
```

If `pptb.config.json` is missing from the published package, your tool will not be discoverable by
capability and callers will not know what prefill data to send or what return data to expect.

#### Versioning

When you publish a new version of your tool, the invocation contract is automatically updated in PPTB.
However, if you change the shape of `prefill` or `returnTopic`, you should also bump the
`invocation.version` field in `pptb.config.json` to signal to callers that the contract has changed.

PPTB does not enforce version compatibility — if a caller built against version 1.0.0 launches version
2.0.0 of the callee, it is the caller's responsibility to handle any differences in the prefill or
return data shape. Always design your contract with graceful degradation in mind.

### End-to-End Scenario

This section walks through a real-world example: FetchXML Studio (FXS) exposes a "Send To ▾" flyout that
lets users push the current FetchXML query into another installed tool — such as BDS (Bulk Data Studio)
or DM (Data Migrator) — without expecting a return value.

#### Scenario Steps

| Step | What happens |
| --- | --- |
| 1 | User composes a FetchXML query in FXS. |
| 2 | User clicks the "Send To ▾" flyout button. |
| 3 | PPTB queries all installed tools declaring the `"fetchxml"` capability. Both BDS and DM qualify. The flyout lists them. |
| 4 | User selects DM. |
| 5 | PPTB opens DM, inheriting FXS's active Dataverse connection. |
| 6 | DM requires a secondary connection — PPTB automatically shows the multi-connection selector. The user picks the target environment. |
| 7 | DM opens pre-populated with the FetchXML from step 1. |
| 8 | Because `noReturn: true` was set, no banner is shown in the DM window. |
| 9 | The user continues in DM independently. Closing DM resolves the Promise on the FXS side with `null`. |

#### Step 1 — Both callee tools declare the "fetchxml" capability

```json
{
  "invocation": {
    "version": "1.0.0",
    "capabilities": ["fetchxml"],
    "prefill": {
      "properties": {
        "fetchXml": { "type": "string" }
      }
    }
  }
}
```

#### Step 2 — FXS discovers fetchxml-capable tools and builds the flyout

```typescript
// Called during tool initialisation
async function setupSendToFlyout() {
  const fetchXmlTools = await toolboxAPI.invocation.findToolsByCapability('fetchxml')
  renderSendToFlyout(fetchXmlTools as Array<{ id: string; name: string }>)
}
```

#### Step 3 — User selects DM; FXS launches it with `noReturn: true`

```typescript
async function sendCurrentQueryToTool(targetToolId: string) {
  const currentFetchXml = getEditorContent()

  try {
    await toolboxAPI.invocation.launchTool(
      targetToolId,
      { fetchXml: currentFetchXml },
      {
        // primaryConnectionId omitted → FXS's active connection is inherited
        // secondaryConnectionId omitted → PPTB shows selector if DMS requires it
        noReturn: true,
      },
    )
    // Resolves with null once DMS is closed
  } catch (err) {
    toolboxAPI.utils.showNotification({
      title: 'Send To failed',
      body: err instanceof Error ? err.message : String(err),
      type: 'error',
    })
  }
}
```

#### Step 4 — DM reads the prefill data

```typescript
async function main() {
  const ctx = await toolboxAPI.invocation.getLaunchContext()

  if (ctx) {
    const fetchXml = ctx.fetchXml as string | undefined
    if (fetchXml) {
      loadQueryIntoEditor(fetchXml)
    }
    // DM does NOT call returnData — FXS launched it with noReturn: true.
  } else {
    renderEmptyEditor()
  }
}

main()
```

DM does not need to detect `noReturn` explicitly. The `noReturn` flag only suppresses the banner — it
does not change the invocation lifecycle. If `returnData` is never called and the tool closes, the
caller's Promise resolves with `null`.

#### Full Sequence Diagram

```
FXS (Caller)                        PPTB Shell                       DM (Callee)
────────────                         ──────────                       ────────────
findToolsByCapability("fetchxml")
  → [BDS, DM]

User clicks "Send to DM"
launchTool("dm", { fetchXml },
  { noReturn: true })
        │
        ▼
                            DM needs secondary connection
                            → show multi-connection selector
                            ← user picks target env
                                    │
                                    ▼
                            Launch DM (primary = FXS conn,
                                       secondary = user pick)
                            No banner shown (noReturn: true)
                                    │
                                    ▼
                                                         getLaunchContext()
                                                           → { fetchXml: "…" }
                                                         loadQueryIntoEditor(fetchXml)
                                                         // user works in DM …

User closes DM tab normally
        ◄──────────────────────────────────────────────
Promise resolves (null)     DM closed
// No result to process
```

### Invocation Lifecycle

Understanding the full lifecycle helps when reasoning about edge cases.

```
Caller calls launchTool(...)
        │
        ▼
One-at-a-time check: rejects if caller already has an active callee
        │
        ▼
PPTB creates a new BrowserView for the callee
Dataverse connection auto-inherited from caller (unless overridden)
        │
        ▼
Callee loads and receives toolContext with:
  • toolId, instanceId
  • callerInstanceId  ← present only during invocations
  • prefillData       ← the object passed by the caller
  • connectionId      ← auto-inherited from caller's connection
        │
        ▼
PPTB injects "Return to [CallerToolName]" banner in the callee window
(skipped if launchTool was called with noReturn: true)
        │
        ▼
Callee calls getLaunchContext() → returns prefillData
        │
        ▼  (user interacts with callee UI)
        │
    ┌───┴──────────────────────────┬──────────────────────────┐
    │                              │                          │
    ▼                              ▼                          ▼
Callee calls returnData(...)  User closes callee window  User clicks "Return to Caller" banner
    │                              │                          │
    ▼                              ▼                          ▼
PPTB sends result to caller   PPTB sends null to caller  PPTB sends null to caller
PPTB auto-closes callee               │                  PPTB auto-closes callee
    │                                 │                          │
    └──────────────────┬──────────────┘──────────────────────────┘
                       │
                       ▼
        Caller's Promise resolves (returnData value OR null)
```

Key points to remember:

- The callee opens in its own window (`BrowserView`) and appears as a separate tab in the PPTB tool
  panel.
- `launchTool()` never rejects under normal operation — it always resolves (possibly with `null`).
  Rejections only occur if the tool is not installed, the caller already has an active callee, or the
  launch itself fails.
- **Auto-close:** after `returnData` is called, PPTB automatically closes the callee. The callee does
  not need to close itself.
- **Banner early-return:** if the user clicks "Return to [CallerToolName]" before `returnData` is
  called, the caller's Promise resolves with `null` and the callee window is closed.
- **Banner dismiss (✕):** clicking ✕ hides the banner for the session but does not end the invocation.
  The callee stays open and can still call `returnData` normally.
- **One-at-a-time:** only one active callee per caller. A second `launchTool` while a callee is active
  rejects with `"A callee invocation is already in progress"`.
- A callee that never calls `returnData` keeps the caller's Promise pending until the user closes the
  callee window.

### Validation and Tooling

#### `pptb-validate`

Run `pptb-validate` from your tool directory to validate both `package.json` and `pptb.config.json`:

```bash
npx pptb-validate
# or, if @pptb/types is installed locally:
./node_modules/.bin/pptb-validate
```

The validator checks:

- `invocation.version` is present and a valid semver string.
- `invocation.capabilities` (when present) is an array of non-empty strings, each a recognised
  capability tag (a warning is issued for unrecognised tags).
- `invocation.prefill.properties` values are valid JSON-schema property descriptors.
- `invocation.returnTopic.properties` values are valid JSON-schema property descriptors.

See [Local Validation](#local-validation) for a full CLI reference.

#### TypeScript Types

The `@pptb/types` package ships full type definitions for the invocation API:

```typescript
// All methods live on toolboxAPI.invocation
toolboxAPI.invocation.getLaunchContext() // Promise<Record<string, unknown> | null>
toolboxAPI.invocation.returnData(data) // Promise<void>  (auto-closes callee after call)
toolboxAPI.invocation.launchTool(...) // Promise<unknown>
toolboxAPI.invocation.findToolsByCapability(tag) // Promise<unknown[]>  — tag is CapabilityTag
toolboxAPI.invocation.getKnownCapabilityTags() // Promise<Array<{ tag: string; description: string }>>
```

For auto-complete on capability tags, import from the bundled declaration file:

```typescript
import type {
  PPTBConfig,
  InvocationConfig,
  CapabilityTag,
  KnownCapabilityTag,
} from '@pptb/types/pptbConfig'

// IDE will suggest known tags when typing:
const tag: CapabilityTag = 'fetchxml'
const tools = await toolboxAPI.invocation.findToolsByCapability(tag)
```

### Troubleshooting

#### `launchTool` throws "Tool not found"

The target tool is not installed. Ask the user to install it from the PPTB Marketplace, or verify that
the `targetToolId` exactly matches the `name` field in the tool's `package.json`.

#### `launchTool` throws "A callee invocation is already in progress"

Your tool already has an active callee open. Wait for the current invocation to resolve (or reject)
before calling `launchTool` again. Only one callee per caller is supported.

#### `getLaunchContext()` returns `null` when expecting prefill data

The tool was opened directly by the user rather than via `launchTool`. Ensure the caller is using
`toolboxAPI.invocation.launchTool()` and not the standard tool launch mechanism.

#### Caller Promise resolves with `null` unexpectedly

One of the following occurred:

- The callee window was closed by the user before `returnData()` was called.
- The user clicked the "Return to [CallerTool]" banner button before the callee called `returnData()`.

Both are by design — always handle the `null` case in the caller.

#### Changes to `pptb.config.json` are not picked up

Capabilities and the invocation contract are read when a tool is installed. If you changed
`pptb.config.json` in a locally-loaded development tool, reload or reinstall the tool in PPTB.

#### `returnData` appears to do nothing

Confirm that `getLaunchContext()` returned a non-null value first. If it returned `null`, `returnData`
is a no-op because the tool was not launched by another tool.

#### `findToolsByCapability` returns an empty array

No installed tools declare the queried capability tag in their `pptb.config.json`. Verify the target
tool's `pptb.config.json` has the correct tag in `invocation.capabilities` and was reinstalled after the
change.

Source: [docs.powerplatformtoolbox.com/tool-development/inter-tool-invocation](https://docs.powerplatformtoolbox.com/tool-development/inter-tool-invocation)

## Agent Integration

Power Platform ToolBox can expose selected tools to AI assistants through its built-in MCP server. As a
tool developer, you can decide whether your tool is discoverable by assistants, what input it accepts,
what result it returns, and whether it supports only interactive runs or both interactive and automated
runs.

### Overview

Agent integration builds on the same invocation model used for [inter-tool workflows](#inter-tool-invocation),
but the caller is an external assistant instead of another PPTB tool.

At a high level, you need to do three things:

1. Declare an invocation contract.
2. Mark the tool as invokable by agents.
3. Add an automated runtime if you want the tool to work without opening its UI.

### MCP Contract

There are two distinct layers in the contract:

| Layer | Purpose |
| --- | --- |
| `invocation` | Describes the input payload the caller can send and the structured result the tool may return |
| `agents` | Declares that the tool is available to assistants and how it should behave when called through MCP |

The same `prefill` and `returnTopic` shapes used by PPTB invocation are also what assistants rely on for
predictable tool calls.

### Interactive and Automated Runs

These docs use end-user language for the two execution styles:

| User-facing term | MCP runtime value | Meaning |
| --- | --- | --- |
| Interactive tool run | `executionMode: "windowed"` | PPTB opens the tool UI and the assistant works through the normal interactive experience |
| Automated tool run | `executionMode: "headless"` | PPTB runs the tool without opening the UI and returns a structured result when available |

Interactive runs are a good fit for existing UI-driven tools. Automated runs are a good fit for
repeatable tasks, direct data returns, and unattended workflows.

### Declare Tool Metadata

Add both `invocation` and `agents` to `pptb.config.json`.

```json
{
  "invocation": {
    "version": "1.0.0",
    "capabilities": ["fetchxml-builder"],
    "prefill": {
      "properties": {
        "entityName": { "type": "string" }
      }
    },
    "returnTopic": {
      "properties": {
        "fetchXml": { "type": "string" }
      }
    }
  },
  "agents": {
    "version": "1.0.0",
    "invokable": true,
    "modes": ["one-way", "two-way"],
    "defaultMode": "two-way",
    "timeoutMS": 12000,
    "headless": true,
    "executionModes": ["windowed", "headless"],
    "defaultExecutionMode": "headless",
    "headlessEntry": "dist/headless.js"
  }
}
```

Field summary:

- `agents.invokable` exposes the tool through MCP discovery.
- `agents.modes` declares whether the tool supports fire-and-forget calls, result-returning calls, or
  both.
- `agents.defaultMode` defines the fallback when the caller does not specify one.
- `agents.timeoutMS` gives a timeout hint for result-returning calls.
- `agents.headless` enables automated headless execution of the tool.
- `agents.executionModes` lists the supported execution modes (e.g., `windowed`, `headless`).
- `agents.defaultExecutionMode` sets the default execution mode when none is specified.
- `agents.headlessEntry` points to the compiled automated runtime entry point.

In prose we refer to "automated runs," but the runtime field value remains `executionMode: "headless"`.
Use the real field names and values in your code and configuration.

### Add an Automated Runtime

If you want your tool to support automated runs, export an `invokeHeadless(input, context)` function
from a file that PPTB can discover.

PPTB checks for an automated entry in this order:

1. `agents.headlessEntry` in `pptb.config.json`
2. `dist/headless.js`
3. `headless.js`
4. `package.json.main`

This sample is based on the HTML sample tool and returns a simple FetchXML payload without opening the
UI:

```typescript
/// <reference types="@pptb/types" />

async function invokeHeadless(input, context) {
  const { toolId, toolName, invocationMode, authToken, updateProgress, logger } =
    context

  logger.info(
    `Starting headless run for ${toolName} (${toolId}) in mode ${invocationMode}`,
  )
  updateProgress(10, 'validating input')

  const entityName =
    typeof input.entityName === 'string' && input.entityName.trim() !== ''
      ? input.entityName.trim()
      : 'account'

  if (authToken) {
    updateProgress(40, 'auth token received')
  } else {
    updateProgress(40, 'running without auth token')
  }

  updateProgress(80, 'building FetchXML')

  const fetchXml = `<fetch top="10">
  <entity name="${entityName}">
    <attribute name="name" />
    <attribute name="${entityName}id" />
    <order attribute="name" />
  </entity>
</fetch>`

  updateProgress(100, 'done')
  logger.info(`Headless run complete for entity: ${entityName}`)

  return { fetchXml }
}

module.exports = {
  invokeHeadless,
}
```

For two-way calls, return a JSON object that matches `invocation.returnTopic`.

### Invocation Metadata

Assistants can pass PPTB-specific metadata under `arguments.__pptb`.

```json
{
  "entityName": "account",
  "__pptb": {
    "mode": "two-way",
    "executionMode": "headless",
    "timeoutMs": 60000,
    "authToken": "optional-caller-token",
    "connectionName": "optional-saved-connection"
  }
}
```

Key fields:

- `mode`: `one-way` or `two-way`
- `executionMode`: `windowed` or `headless`
- `timeoutMs`: per-call timeout hint
- `authToken`: optional token provided by the caller
- `connectionName`: optional saved PPTB connection name

When your UI-based tool is launched through MCP, `toolboxAPI.invocation.getLaunchContext()` includes the
original prefill data and a `__pptb` metadata object such as:

```json
{
  "entityName": "account",
  "__pptb": {
    "source": "mcp",
    "mode": "two-way",
    "correlationId": "mcp-...",
    "timeoutMs": 60000,
    "expectsResponse": true
  }
}
```

### Design for Both Run Styles

If your tool supports both interactive and automated runs, keep the contract aligned across both paths.

- Accept the same core input shape in the UI and automated runtime.
- Return the same result shape regardless of how the tool was executed.
- Treat automated runs as task-oriented operations, not hidden UI automation.
- Use progress updates and structured logging so callers can reason about long-running work.
- Keep secrets out of logs and return payloads.

The cleanest pattern is to move business logic into shared functions and have both the UI path and
`invokeHeadless` call the same domain layer.

### Validation and Testing

Before publishing or sharing your tool with assistant users:

- Validate `pptb.config.json` locally with [Local Validation](#local-validation).
- Check that the tool appears in MCP discovery only when `agents.invokable` is `true`.
- Test both one-way and two-way calls if you advertise both modes.
- Confirm that your automated runtime returns a payload matching `returnTopic`.
- Use MCP Inspector as the manual test harness for tool discovery and tool calls.

If a call fails, compare the request and response payloads against `prefill` and `returnTopic`, then
verify that the automated entry file can be discovered from your built output.

Source: [docs.powerplatformtoolbox.com/tool-development/agent-integration](https://docs.powerplatformtoolbox.com/tool-development/agent-integration)

## Publishing Tools

Once you've tested your tool locally and are ready to share it with the community, follow this guide to
publish it to npm and submit it to the ToolBox registry.

### Prerequisites

Before publishing, ensure your tool:

- ✅ Builds successfully without errors
- ✅ Has been tested in local debug mode
- ✅ Passes local validation with `pptb-validate` (see [Local Validation](#local-validation))
- ✅ Follows this Tool Development guide
- ✅ Has complete `package.json` metadata
- ✅ Has appropriate license (open source recommended)
- ✅ Has documentation (README.md)

We do not support direct HTML code inside the README for security reasons. If you want to include
images or links, use markdown syntax instead. Please ensure that you are using full URLs for any
external resources.

### Step 1: Prepare Your Package

#### Update `package.json`

Ensure all required fields are present (see [Package Manifest](#package-manifest) for the full
reference):

```json
{
  "name": "@your-org/your-tool-name",
  "version": "1.0.0",
  "displayName": "Your Tool Name",
  "description": "Clear, concise description of what your tool does",
  "main": "index.html",
  "icon": "icons/test.svg",
  "license": "MIT",
  "contributors": [
    {
      "name": "Your Name",
      "url": "https://yourwebsite.com"
    },
    {
      "name": "Additional Contributor(s)"
    }
  ],
  "configurations": {
    // Where your tool's source code lives and is used in the help menu of the app
    "repository": "https://github.com/yourusername/your-tool",
    // Optional
    "website": "https://the tool website or documentation URL",
    // This is used to display the README in ToolBox, and must be hosted
    // on raw.githubusercontent.com (optional but recommended)
    "readmeUrl": "https://raw.githubusercontent.com/yourusername/your-tool/refs/heads/main/README.md"
  },
  "cspExceptions": {
    // This is an optional section, do not include unless your tool needs to connect to more than dataverse endpoints
    "connect-src": [
      {
        "domain": "www.api.example.com",
        "exceptionReason": "Explain **why** your tool needs this exception.",
        "optional": false // set to true if the core tool works without this exception
      }
    ]
  },
  "features": {
    // Optional section to declare special features your tool needs
    "multiConnection": "optional", // or "required" if your tool needs multiple connections
    "minAPI": "1.2.0" // minimum supported ToolBox API version
  }
}
```

> `iconURL` under `configurations` is no longer supported. Use the top-level `icon` field instead, with
> an SVG path relative to your dist root (for example, `icons/test.svg`).

To support light and dark themes, your SVG icon should use `fill="currentColor"` (or
`stroke="currentColor"` as needed).

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Package name (use scoped naming to differentiate your tool from others: `@org/tool-name`) |
| `displayName` | string | Human-readable name shown in ToolBox |
| `description` | string | Brief description (1-2 sentences) |
| `main` | string | Entry point file (usually `index.html`) |
| `icon` | string | Relative path to your tool icon SVG from the dist root (for example, `icons/test.svg`) |
| `contributors` | array | List of authors/contributors with names and optional URLs |
| `license` | string | License type (e.g., MIT, Apache-2.0). Must be an approved open-source license: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, GPL-2.0, GPL-3.0, LGPL-3.0, ISC, or AGPL-3.0-only (required) |
| `configurations` | object | Repository URL and optional website/documentation links |
| `cspExceptions` | object | Content Security Policy exceptions if needed |
| `features` | object | Special features your tool requires (e.g., `multiConnection`, `minAPI`) |

#### Including Your Icon in `dist/`

Your SVG icon must be present in the `dist/` folder after building. How you achieve this depends on your
build setup.

##### No Bundler (manual copy)

Use [shx](https://www.npmjs.com/package/shx) for a cross-platform copy that works on Windows, macOS, and
Linux:

```bash
npm install --save-dev shx
```

Then wire up individual copy steps and call them from your build script:

```json
{
  "scripts": {
    "build": "tsc && npm run copy-html && npm run copy-css && npm run copy-icon",
    "copy-html": "shx cp src/index.html dist/",
    "copy-css": "shx cp src/styles.css dist/",
    "copy-icon": "shx cp -r icon/ dist/icon/"
  }
}
```

Adjust the paths to match your project structure. The `copy-icon` step recursively copies your entire
`icon/` folder into `dist/icon/`, so whatever path you reference in `package.json`'s `icon` field (e.g.,
`icon/test.svg`) will be available after the build.

##### Vite

Vite automatically copies everything inside the `public/` directory to `dist/` at build time — no
plugin required. Place your icon there:

```
public/
  icon/
    test.svg
```

If your `public/` folder is in a non-default location, point Vite to it via `publicDir`:

```typescript
// vite.config.ts
import { defineConfig } from 'vite'

export default defineConfig({
  publicDir: 'public', // default — change this if your folder is elsewhere
})
```

Your `package.json` `icon` field should then be `icon/test.svg`, which will resolve to
`dist/icon/test.svg` after the build.

##### Webpack

Webpack has no built-in public folder, but you can achieve the same result by placing your icon under
`public/` and using
[copy-webpack-plugin](https://www.npmjs.com/package/copy-webpack-plugin) to copy that folder to `dist/`:

```bash
npm install --save-dev copy-webpack-plugin
```

```javascript
// webpack.config.js
const CopyPlugin = require('copy-webpack-plugin')

module.exports = {
  plugins: [
    new CopyPlugin({
      patterns: [{ from: 'public', to: '.' }],
    }),
  ],
}
```

With your icon at `public/icon/test.svg`, it will be output to `dist/icon/test.svg`, matching the `icon`
field in `package.json`.

Whatever method you use, confirm the icon is present at the path referenced by the top-level `icon`
field in `package.json` (e.g., `icons/test.svg`) relative to your `dist/` root before publishing.

### Step 2: Build Your Tool

Build your tool to create the distributable files:

```bash
npm run build
```

Verify that your `dist/` directory contains:

- `index.html` (entry point)
- `icons/test.svg` (or similar SVG path referenced by top-level `icon`)
- All compiled JavaScript/CSS files
- Any required assets (images, icons, etc.)

### Step 3: Validate Locally

Before finalizing and publishing, run the `pptb-validate` CLI to check your `package.json` against the
same rules used by the official review pipeline:

```bash
npm run validate
```

Or without a script entry:

```bash
npx pptb-validate
```

Fix any errors reported before proceeding. Warnings indicate optional-but-recommended fields that are
absent or misconfigured — address them where possible.

See [Local Validation](#local-validation) for full details on CLI options, what is validated, and how to
integrate with CI pipelines.

### Step 4: Finalize Package

Run the finalization script to prepare your package:

```bash
npm run finalize-package
```

This ensures your package is ready for npm with correct file structure and dependencies.

### Step 5: Publish to npm

#### First-Time Setup

If you haven't published to npm before:

```bash
# Create npm account (if needed)
npm login
```

#### Publish Your Package

```bash
# For scoped packages
npm publish --access public

# For unscoped packages
npm publish
```

> Scoped packages (e.g., `@myorg/tool-name`) require the `--access public` flag to be publicly
> accessible.

#### Verify Publication

Check that your package is live:

```bash
npm view @your-org/your-tool-name
```

Or visit: `https://www.npmjs.com/package/@your-org/your-tool-name`

### Step 6: Test Published Version

Before submitting to the registry, test your published npm package:

1. Open Power Platform ToolBox.
2. Navigate to the Debug section.
3. In the "Install from npm" section, enter your package name: `@your-org/your-tool-name`.
4. Click Install.
5. Test thoroughly to ensure everything works as expected.

### Step 7: Submit to ToolBox Registry

Once your tool is working correctly from npm:

#### Fill Out the Tool Submission Form

Visit the Tool Submission Form at powerplatformtoolbox.com (you need to log in) and provide:

| Field | Type | Description |
| --- | --- | --- |
| npm Package Name | string | Your published npm package name (e.g., `@your-org/tool-name`) |
| Tags/Categories | array | Select up to 3 from: Comparisons, Data, Development, Diagrams, Documentation, Environments, Migration, Solutions, Troubleshooting, and Users & Security |

#### Automated Validation

After submission, automated checks will validate:

- ✅ npm package exists and is accessible
- ✅ Package contains appropriate metadata
- ✅ License is appropriate (open source preferred)
- ✅ No known security vulnerabilities
- ✅ Package structure is correct

#### Manual Review

Maintainers will review your submission for:

- Security (no malicious code)
- Quality (follows guidelines)
- Functionality (works as described)
- Documentation (README is clear)

Review typically takes 48-72 hours.

### Versioning and Updates

#### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):

- **Patch (1.0.X)** — Bug fixes:

  ```bash
  npm version patch
  ```

- **Minor (1.X.0)** — New features (backward compatible):

  ```bash
  npm version minor
  ```

- **Major (X.0.0)** — Breaking changes:

  ```bash
  npm version major
  ```

#### Publishing Updates

```bash
# Update version
npm version patch  # or minor, or major

# Build
npm run build

# Publish
npm publish --access public
```

The ToolBox registry automatically syncs with npm. Users will receive update notifications when new
versions are published.

### Best Practices

#### Before Publishing

- ✅ Test thoroughly in debug mode
- ✅ Run `pptb-validate` and fix all errors before publishing
- ✅ Write comprehensive README with usage instructions
- ✅ Include screenshots or demo GIFs
- ✅ Document all features and limitations
- ✅ Add proper error handling
- ✅ Follow UI/UX guidelines for consistency

#### After Publishing

- ✅ Monitor GitHub issues for bug reports
- ✅ Respond to user feedback promptly
- ✅ Keep dependencies up to date
- ✅ Maintain a CHANGELOG
- ✅ Provide migration guides for breaking changes
- ✅ Consider semantic versioning strictly

#### Security

- ⚠️ Never include hardcoded credentials or API keys
- ⚠️ Validate all user inputs
- ⚠️ Use HTTPS for external API calls
- ⚠️ Don't access sensitive system resources
- ⚠️ Follow principle of least privilege

### Troubleshooting

#### `npm publish` fails

Error: `You must be logged in to publish packages.`

Solution:

```bash
npm login
# Re-try publish
```

Error: `Package name too similar to existing package.`

Solution: Choose a more unique name or use scoped naming: `@your-org/tool-name`

#### Tool not appearing in registry

Check:

- Ensure automated validation passed.
- Check submission issue for maintainer feedback.
- Verify npm package is publicly accessible.
- Confirm `package.json` has all required fields.

#### Users reporting issues

Steps:

1. Reproduce the issue in debug mode.
2. Fix in your local version.
3. Update version number.
4. Publish update to npm.
5. Notify users in the issue thread.

### Support

Need help publishing your tool?

- GitHub Discussions: [Ask the community](https://github.com/PowerPlatformToolBox/desktop-app/discussions)
- Issues: [Report problems](https://github.com/PowerPlatformToolBox/desktop-app/issues)
- Documentation: [Full tool dev guide](https://github.com/PowerPlatformToolBox/desktop-app/blob/main/docs/TOOL_DEV.md)

Source: [docs.powerplatformtoolbox.com/tool-development/publishing](https://docs.powerplatformtoolbox.com/tool-development/publishing)
