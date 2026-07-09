/**
 * Scopes a Business Process Flow query to one solution or one publisher's solutions, via
 * `solutioncomponent` (see `docs/pcf2bpf/dataverse/solution-component.md`). Omit entirely to load
 * every BPF in the environment, unfiltered.
 */
export type BpfScope = { solutionId: string } | { publisherId: string };
