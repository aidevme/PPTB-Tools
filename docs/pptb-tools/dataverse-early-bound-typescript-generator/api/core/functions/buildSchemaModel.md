# Function: buildSchemaModel()

> **buildSchemaModel**(`edmx`, `config`, `getEntityMetadata`): [`SchemaModel`](../interfaces/SchemaModel.md)

Defined in: [core/model.ts:460](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/model.ts#L460)

Build the full schema model for the selection.

## Parameters

### edmx

[`EdmxSchema`](../interfaces/EdmxSchema.md)

Parsed CSDL document.

### config

[`ResolvedConfig`](../interfaces/ResolvedConfig.md)

Resolved `.dataverse-gen.json` options.

### getEntityMetadata

[`EntityMetadataLookup`](../type-aliases/EntityMetadataLookup.md)

Dataverse metadata for every entity in `resolveSelection(edmx, config).entities`.

## Returns

[`SchemaModel`](../interfaces/SchemaModel.md)

## Throws

when metadata (or an attribute's option set) is missing for a required entity.
