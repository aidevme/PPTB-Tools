# Flow Documentation Output Format

Each flow produces a markdown file with these sections in order:

## Sections

### 1. Overview (table)
Metadata table: Flow Name, Flow ID, Type, State, Primary Entity, Version, Solution.

### 2. Trigger
Parsed trigger details. Varies by type:
- **Dataverse Trigger** (`OpenApiConnectionWebhook`): Table, change type, scope, filtering attributes, filter expression
- **HTTP / Instant** (`Request`): Input schema JSON
- **Scheduled** (`Recurrence`): Frequency, interval, start time, timezone
- **Other**: Raw type name

### 3. Flow Architecture
ASCII box-drawing diagram showing all actions with nesting for:
- Conditions (IF/TRUE/FALSE branches)
- Apply to Each loops
- Scopes
- Switch/Case
- Do Until loops

Each box shows: action name, action type, and (for Dataverse ops) entity name or (for variables) variable name/type.

### 4. Detailed Flow Steps
Numbered steps, one per top-level action. Each step includes:
- Action type
- Entity name (Dataverse ops)
- Filter, Top, OrderBy, FetchXML (for List Records)
- Condition logic with clause breakdown (for If actions)
- Variable name/type/initial value (for variable actions)
- Scope/loop child action list
- RunAfter dependencies

### 5. Data Model Relationships
Code block listing each Dataverse entity and the CRUD operations performed on it.

### 6. Connection References
API name, runtime source, and connection reference logical name.

### 7. Dependencies
- **Dataverse Tables:** list of all entities used
- **Connections:** list of all connection APIs

### 8. Related Documentation
Links to solution overview and workflow index.

## Workflow Index (README.md)
Auto-generated table of all flows with columns: Flow, State, Trigger Type, Documentation link.

## File Naming Convention
- GUID suffix stripped from flow filename
- CamelCase split with hyphens (e.g., `AccountCreate-OnCreate.md`)
- Output location: `Solutions/.docs/[SolutionName]/Workflows/`
