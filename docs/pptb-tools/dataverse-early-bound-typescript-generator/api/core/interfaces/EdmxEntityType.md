# Interface: EdmxEntityType

Defined in: [core/types.ts:35](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L35)

An `<EntityType>` in the CSDL.

## Properties

### Abstract

> **Abstract**: `boolean`

Defined in: [core/types.ts:38](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L38)

***

### BaseType?

> `optional` **BaseType?**: `string`

Defined in: [core/types.ts:37](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L37)

***

### EntitySetName?

> `optional` **EntitySetName?**: `string`

Defined in: [core/types.ts:42](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L42)

Resolved from the EntityContainer's `<EntitySet>` elements.

***

### KeyName?

> `optional` **KeyName?**: `string`

Defined in: [core/types.ts:40](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L40)

`Key/PropertyRef@Name` — the primary id attribute.

***

### Name

> **Name**: `string`

Defined in: [core/types.ts:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L36)

***

### NavigationProperties

> **NavigationProperties**: [`EdmxNavigationProperty`](EdmxNavigationProperty.md)[]

Defined in: [core/types.ts:44](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L44)

***

### Properties

> **Properties**: [`EdmxProperty`](EdmxProperty.md)[]

Defined in: [core/types.ts:43](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L43)
