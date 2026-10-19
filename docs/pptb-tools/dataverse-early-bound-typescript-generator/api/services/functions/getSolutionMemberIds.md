# Function: getSolutionMemberIds()

> **getSolutionMemberIds**(`solutionId`, `objectIds`): `Promise`\<`Set`\<`string`\>\>

Defined in: [services/solutions.ts:33](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/solutions.ts#L33)

Which of the given component record ids (custom API ids, process-action workflow ids, …) are part of
a solution. Queried in chunks by id rather than listing every component of the solution, which can be
tens of thousands of rows for the Default solution.

## Parameters

### solutionId

`string`

### objectIds

readonly `string`[]

## Returns

`Promise`\<`Set`\<`string`\>\>
