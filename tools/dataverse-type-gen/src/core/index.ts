/**
 * I/O-free generator core. Nothing in here touches PPTB, the network or the file system, so the same
 * code can later back a Node CLI.
 */
export * from './types';
export * from './config';
export { parseCsdl, isCollectionType, stripCollection, shortTypeName } from './csdl';
export type { XmlParser } from './csdl';
export { buildSchemaModel, resolveSelection, makeCodeSafe } from './model';
export type { Selection, EntityMetadataLookup } from './model';
export { generate, OUTPUT_FOLDERS } from './generator';
export * from './templates';
