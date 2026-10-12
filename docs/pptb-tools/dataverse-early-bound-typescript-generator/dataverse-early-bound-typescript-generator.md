# Dataverse Type Forge: Implementation Guide

A Power Platform ToolBox (PPTB) tool that generates early-bound TypeScript types and metadata for Dataverse, compatible with Scott Durow's `dataverse-ify` runtime library.

Research date: 9 October 2026. Working name: **Dataverse Type Forge** (`@aidevme/pptb-dataverse-type-forge`). The name has not been checked against the PPTB marketplace or npm yet.

---

## 1. What is being rebuilt

| Original package | What it does | Role in this project |
|---|---|---|
| `dataverse-auth` | Node sign-in (Electron + MSAL) that stores a token for other Node apps | **Dropped.** PPTB owns connections and tokens. |
| `dataverse-gen` | CLI that generates early-bound TypeScript from `.dataverse-gen.json` using EJS templates | **This is the tool.** Logic is ported into a pure TypeScript core. |
| `dataverse-ify` | Runtime library: `Xrm.WebApi` with `IOrganizationService`-style types | **Unchanged npm dependency** of the generated code. |

All three repos are MIT licensed. Keep attribution in the README and contact Scott Durow before publishing (PPTB asks the same courtesy for XrmToolBox clones).

## 2. PPTB platform facts

- A tool is a web app in a **sandboxed iframe**. It talks to the host over postMessage. There is no Node runtime.
- One build runs in both hosts: the **desktop app** (Electron) and the **VS Code extension**.
- Desktop-only today: Terminal API, Inter-Tool Invocation, Agent Integration (MCP).
- Types: `npm install --save-dev @pptb/types` (1.2.5 at research time). Validator: `@pptb/validate`.
- Scaffold: `npx --package yo --package generator-pptb -- yo pptb`

### APIs this tool uses

| Need | API |
|---|---|
| Active connection | `toolboxAPI.connections.getActiveConnection()` |
| Connection change | `toolboxAPI.events.on(...)`, event `connection:updated` |
| Table list | `dataverseAPI.getAllEntitiesMetadata(['LogicalName','SchemaName','DisplayName','EntitySetName','PrimaryIdAttribute','PrimaryNameAttribute'])` |
| One table | `dataverseAPI.getEntityMetadata(logicalName, true, props)` |
| Columns, keys, relationships | `dataverseAPI.getEntityRelatedMetadata(logicalName, 'Attributes' \| 'Keys' \| 'ManyToOneRelationships' \| 'OneToManyRelationships' \| 'ManyToManyRelationships', props)` |
| One column's choices | `getEntityRelatedMetadata(logicalName, "Attributes(LogicalName='x')/OptionSet")` |
| Actions, functions, complex types, enums | `dataverseAPI.getCSDLDocument()` (raw EDMX, 1 to 5 MB, parse with `DOMParser`) |
| Solution filter | `dataverseAPI.getSolutions([...])` plus `queryData` on `solutioncomponents` |
| Raw Web API GET | `dataverseAPI.queryData(odataQuery)` |
| Pick project folder | `toolboxAPI.fileSystem.selectPath({ type: 'folder' })` |
| Read/write files | `fileSystem.readText`, `writeText`, `createDirectory`, `readDirectory`, `exists`, `stat` (absolute paths only) |
| Per-tool settings | `toolboxAPI.settings` |
| Notifications | `toolboxAPI.utils.showNotification(...)` |

## 3. Architecture

Monorepo, three packages:

```
dataverse-type-forge/
├── packages/
│   ├── core/          # pure TS, no I/O
│   ├── pptb-tool/     # React + Fluent UI, PPTB adapters
│   └── cli/           # optional Node wrapper for CI
└── fixtures/          # saved metadata JSON + CSDL for tests
```

### core (no I/O, no DOM, no Node APIs)

```ts
interface MetadataProvider {
  listEntities(): Promise<EntitySummary[]>;
  getEntity(logicalName: string): Promise<EntityModel>;
  getOperations(): Promise<{ actions: OperationModel[]; functions: OperationModel[];
                             complexTypes: ComplexTypeModel[]; enums: EnumModel[] }>;
}

interface FileSink {
  list(dir: string): Promise<string[]>;      // for the casing rule, see section 6
  read(path: string): Promise<string | null>;
  write(path: string, content: string): Promise<void>;
}

interface GeneratedFile { path: string; content: string; }

function generate(config: GenConfig, model: SchemaModel, templates: TemplateSet): GeneratedFile[];
```

`generate` is synchronous and deterministic so it can be snapshot-tested.

### pptb-tool

- `PptbMetadataProvider` wraps `dataverseAPI`.
- `PptbFileSink` wraps `toolboxAPI.fileSystem`.
- UI screens: section 5.

### cli (optional, later)

Node `MetadataProvider` and `FileSink` around the same core, for pipelines where nobody opens a toolbox.

## 4. Compatibility target

Stay compatible with the existing ecosystem so users can mix this tool with `npx dataverse-gen`:

1. Read and write **`.dataverse-gen.json`** in the project root. It is the only file the CLI needs.
2. Emit output that works with **`dataverse-ify` v2** and `setMetadataCache(...)`.

### Metadata shape that dataverse-ify expects

```ts
export const queueitemMetadata = {
  typeName: "mscrm.queueitem",
  logicalName: "queueitem",
  collectionName: "queueitems",
  primaryIdAttribute: "queueitemid",
  attributeTypes: {
    exchangerate: "Decimal",
    status: "Integer",
    statecode: "Optionset",
    workeridmodifiedon: "DateOnly:UserLocal",
  },
  navigation: {
    transactioncurrencyid: ["mscrm.transactioncurrency"],
    queueid: ["mscrm.queue"],
    workerid: ["systemuser", "team"],
  },
};
```

Why it exists: the Web API sends integers, decimals, money and option sets all as plain numbers, and navigation properties need prior knowledge of lookup targets.

### Mapping from Dataverse metadata

| Output field | Source |
|---|---|
| `logicalName` | `EntityMetadata.LogicalName` |
| `collectionName` | `EntityMetadata.EntitySetName` |
| `primaryIdAttribute` | `EntityMetadata.PrimaryIdAttribute` |
| `typeName` | `mscrm.` + logical name |
| `attributeTypes[x]` | `AttributeMetadata.AttributeType`, plus `DateTimeBehavior` and `Format` for dates |
| `navigation[x]` | `LookupAttributeMetadata.Targets` or `ManyToOneRelationships` |
| Option-set enums | `OptionSet.Options[].Value` and `Label` |
| Action/function requests | `Action` / `Function` elements in the CSDL, with `Parameter` and `ReturnType` |

**To verify in source before coding:** the exact strings used in `attributeTypes` (all type names and date format variants), the mixed `mscrm.` prefix usage in `navigation`, and the full `.dataverse-gen.json` schema. Read `.dataverse-gen.template.json`, `_templates/` and `src/` in `scottdurow/dataverse-gen`.

## 5. Tool workflow and screens

1. **Project**: pick folder with `selectPath`. Load `.dataverse-gen.json` if present. Remember the folder per connection in `toolboxAPI.settings`.
2. **Select**: searchable grid of tables, actions and functions, with a solution filter and "selected only" toggle.
3. **Options**: output root, which artefacts to emit (entity types, attribute constants, enums, metadata index, form context types).
4. **Preview**: file tree with a diff against what is on disk (new, changed, unchanged, orphaned).
5. **Generate**: write files, save config, show a summary notification.
6. **Regenerate**: one click when config already exists.

## 6. Known risks and how to handle them

| Risk | Detail | Plan |
|---|---|---|
| EJS in the sandbox | EJS compiles templates with `new Function`, which iframe CSP normally blocks. Not confirmed whether PPTB can grant `unsafe-eval`. | Built-in templates as plain TS functions. For user templates use an eval-free engine (LiquidJS or Mustache). Accept that ejected `_templates` EJS files will not be supported in the tool; the CLI can still use them. |
| Bulk option-set metadata | Documented path fetches one attribute's OptionSet at a time. | Spike: test `queryData("EntityDefinitions(LogicalName='x')/Attributes/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?$select=LogicalName&$expand=OptionSet,GlobalOptionSet")`. Same for Status, State, MultiSelectPicklist and Boolean casts. Fall back to per-attribute calls with a concurrency limit. |
| File name casing | `dataverse-gen` reuses an existing file name even if casing differs, to avoid import errors. | In `FileSink.list`, match existing names case-insensitively and reuse them. |
| CSDL size | 1 to 5 MB XML. | Fetch once per connection, cache in memory, parse lazily. Use namespace-aware queries. |
| Large selections | Many tables means many metadata calls. | Limit concurrency (4 to 6), show progress, cache per session. |
| Absolute paths | File API rejects relative paths; separators differ per OS. | Small path helper in the adapter; core only deals in forward-slash relative paths. |
| VS Code host gaps | Terminal, inter-tool and MCP are desktop-only. | Do not depend on them for the core flow. |
| Name or feature overlap | PPTB tool list could not be read during research. | Search the PPTB marketplace in-app and run `npm view <name>` before committing. |

Names to avoid: "Early Bound Generator" (XrmToolBox, Daryl LaBar), "Dataverse DevTools" (VS Code extension), `dataverse-gen` / `dataverse-ify` (Scott Durow's packages).

## 7. Build order

1. **Spikes (half a day each)**
   - CSP: does a template engine run in the iframe?
   - Bulk option-set query through `queryData`.
   - Write 50 files to a folder through `fileSystem`.
2. **core**: port metadata-to-types logic. Snapshot tests against fixtures, compared with real `npx dataverse-gen` output for the same tables.
3. **Tool MVP**: connection, table picker, generate to folder.
4. **Actions and functions** from the CSDL document.
5. **Config round-trip** with `.dataverse-gen.json`, then preview/diff.
6. **Custom templates**, then the CLI.
7. **Later**: MCP/headless "regenerate types" for coding agents (desktop only).

## 8. Dev loop and publishing

Develop:

```bash
npm run build -- --watch
```

In PPTB: Settings > Show Debug Menu > Debug > Load Local Tool > select the tool root. Close and reopen the tool tab to pick up changes.

`package.json` essentials:

```json
{
  "name": "@aidevme/pptb-dataverse-type-forge",
  "version": "0.1.0",
  "displayName": "Dataverse Type Forge",
  "description": "Generate early-bound TypeScript types and metadata for Dataverse",
  "main": "index.html",
  "icon": "icons/icon.svg",
  "features": { "minAPI": "1.2.0" },
  "license": "MIT",
  "repository": { "type": "git", "url": "https://github.com/aidevme/..." }
}
```

Icon: SVG with `fill="currentColor"` so it follows the theme. Path is relative to the `dist` root.

Publish:

```bash
npm run validate          # pptb-validate
npm run finalize-package
npm publish --access public
```

Then submit at https://www.powerplatformtoolbox.com/submit-tool (npm package name, display name, description, repo URL, tags).

## 9. Open questions

- [ ] Exact `.dataverse-gen.json` schema and all `attributeTypes` strings (read the source).
- [ ] Can PPTB grant `unsafe-eval`? If yes, is EJS compatibility worth the consent prompt?
- [ ] Does `queryData` pass cast-and-expand metadata URLs through?
- [ ] Is the name free in the PPTB marketplace and on npm?
- [ ] Contact Scott Durow.
- [ ] Target dataverse-ify v2 only, or also offer a dependency-free output mode (plain interfaces and enums)?

## 10. References

- https://github.com/scottdurow/dataverse-auth
- https://github.com/scottdurow/dataverse-gen
- https://github.com/scottdurow/dataverse-ify
- https://github.com/scottdurow/dataverse-ify/blob/master/docs/why-metadata.md
- https://docs.powerplatformtoolbox.com/tool-development
- https://docs.powerplatformtoolbox.com/tool-development/manifest
- https://docs.powerplatformtoolbox.com/tool-development/api-reference/dataverse-api
- https://docs.powerplatformtoolbox.com/tool-development/api-reference/filesystem-api
- https://docs.powerplatformtoolbox.com/tool-development/csp-configuration
- https://docs.powerplatformtoolbox.com/tool-development/validation
- https://docs.powerplatformtoolbox.com/tool-development/publishing
- https://docs.powerplatformtoolbox.com/tool-development/ai-agent-skills
- https://github.com/PowerPlatformToolBox/sample-tools
- https://github.com/PowerPlatformToolBox/desktop-app
