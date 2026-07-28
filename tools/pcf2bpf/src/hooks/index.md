# Hooks

React-facing hooks that wrap PPTB's host APIs (`window.toolboxAPI`) and this tool's own `ToolContext`
for reuse across components. Following the split noted in the root `CLAUDE.md` — `services/` stays
framework-free (no React), while these hooks are the thin React glue on top: local `useState`/`useMemo`/
`useCallback` bookkeeping around a service call or context value.

## useConnection

Tracks PPTB's active Dataverse connection, fetching it once on mount via
`window.toolboxAPI.connections.getActiveConnection()`.

```ts
function useConnection(): {
    connection: Connection | null;
    isLoading: boolean;
    refresh: () => Promise<void>;
};
```

| Return | Type | Description |
| --- | --- | --- |
| `connection` | `Connection \| null` | The active connection, or `null` before the first fetch resolves, or if it failed. |
| `isLoading` | `boolean` | `true` until the first fetch settles. |
| `refresh` | `() => Promise<void>` | Re-checks the active connection (e.g. call after the user switches connections in PPTB). |

Errors are logged and swallowed rather than thrown — there's no connected environment to report them
against, so `connection` simply stays `null` on failure. `refresh` is stable (`useCallback` with no
dependencies) and is what the mount-time `useEffect` calls.

## useBindFieldOptions

Returns a resolver — `(paramType: string) => string[]` — for the field logical names on a given entity
that are valid bind targets for a PCF parameter of that type. Backs `PcfConfiguratorTable`'s "Param
Value" Dropdown, shown when a parameter isn't static (its "Is Static?" checkbox is unchecked).

```ts
function useBindFieldOptions(entityLogicalName: string): (paramType: string) => string[];
```

| Parameter | Type | Description |
| --- | --- | --- |
| `entityLogicalName` | `string` | Logical name of the entity whose attributes are searched for bind targets. |

| Return | Type | Description |
| --- | --- | --- |
| *(resolver)* | `(paramType: string) => string[]` | Given a PCF parameter type (e.g. `"OptionSet"`, `"Currency"`, `"Lookup.Simple"`), returns the matching field logical names on `entityLogicalName`. |

**Why a resolver function, not a value:** the table needs one lookup per parameter row inside a
`.map()`, and the Rules of Hooks forbid calling a hook per iteration. Call `useBindFieldOptions` once per
table/component, then invoke the returned function once per row.

**Type mapping:** internally calls `getBindableAttributeTypes` (from `services/dataverseservice/
DataverseService.ts`) to map the PCF `paramType` to the Dataverse `AttributeType`(s) that are valid bind
targets, then filters `useToolContext().entityMetadataInfos` down to the requested entity's attributes
of those type(s). That mapping is deliberately narrower than the `ATTRIBUTE_TYPE_TO_PCF_TYPES` map used
elsewhere for control/type compatibility — see `getBindableAttributeTypes`'s own doc comment for why the
two aren't derived from one another.

**Unmapped types:** any PCF parameter type with no entry in `getBindableAttributeTypes` (i.e. field
binding for that type isn't wired up to real entity metadata yet) resolves to a hardcoded placeholder
list (`fullname`, `emailaddress1`, `telephone1`, `address1_city`, `parentcustomerid`) rather than an
empty dropdown, so the UI still has something to show. Currently mapped: Lookup/Customer/Owner
(`"lookup"`), `Picklist` (`"optionset"`), `String` (`"singleline.text"`), `Boolean` (`"twooptions"`),
and `Money` (`"currency"`).
