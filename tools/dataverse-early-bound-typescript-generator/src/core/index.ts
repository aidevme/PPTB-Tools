/**
 * I/O-free generator core. Nothing in here touches PPTB, the network or the file system, so the same
 * code can later back a Node CLI.
 */
export * from './types';
export * from './config';
export { parseCsdl, isCollectionType, stripCollection, shortTypeName } from './csdl';
export type { XmlParser } from './csdl';
export { buildSchemaModel, resolveSelection, makeCodeSafe, labelText } from './model';
export type { Selection, EntityMetadataLookup } from './model';
export { generate, findDuplicateEnumMembers, renameDuplicateEnumMembers, OUTPUT_FOLDERS } from './generator';
export type { GenerateOptions } from './generator';
export { createMetadataSchema, navigationFromRelationships } from './metadataSchema';
export type { EntityTypeSource } from './metadataSchema';
export * from './templates';
