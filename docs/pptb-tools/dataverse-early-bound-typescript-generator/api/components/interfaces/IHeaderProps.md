# Interface: IHeaderProps

Defined in: [components/layout/Header.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/layout/Header.tsx#L9)

Props for [Header](../functions/Header.md).

## Properties

### connection

> **connection**: `Connection` \| `null`

Defined in: [components/layout/Header.tsx:14](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/layout/Header.tsx#L14)

The active PPTB connection, shown in the connection pill with its environment name and, in a tooltip, its URL;
`null` shows "Not connected".

***

### onOpenSettings

> **onOpenSettings**: () => `void`

Defined in: [components/layout/Header.tsx:16](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/layout/Header.tsx#L16)

Called when the Settings button is clicked. The button stays enabled without a connection.

#### Returns

`void`
