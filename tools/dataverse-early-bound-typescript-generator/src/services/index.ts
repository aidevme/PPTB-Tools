/** PPTB-facing services: file system, Dataverse metadata and solutions, project config and write plans. */
export { mapWithConcurrency } from './concurrency';
export { STATUS_MESSAGES, errorStatus, friendlyError, isTransientError, reportError, technicalMessage, withRetries, withRetry } from './errors';
export type { RetryOptions } from './errors';
export { notifyGenerationComplete, notifyPreviewReady, notifyProjectLoaded, projectLoadedMessage, NOTIFICATION_TYPES, notificationOptions } from './notifications';
export type { NotificationType } from './notifications';
export { PptbFileSink, InMemoryFileSink, buildDeleteCommands, isWindowsPath } from './fileSink';
export type { DirectoryEntry, FileSink } from './fileSink';
export { PptbMetadataProvider, METADATA_CONCURRENCY, toTableType } from './metadataProvider';
export { QUERY_MAX_PAGES, QUERY_PAGE_SIZE, buildPageQuery, queryAllPages } from './paging';
export type { PagedQuery, QueryRunner } from './paging';
export { separatorOf, isAbsolutePath, isSamePath, joinPath, dirname, basename, toPosix } from './paths';
export {
    resolveOutputRoot,
    createWritePlan,
    applyWritePlan,
    deleteOrphanedFiles,
    summarizeGeneration,
    summarizePlan,
    writeStatusOf,
    willWrite,
    writeCounts,
    countStatuses,
} from './plan';
export type { WriteOptions } from './plan';
export { DATAVERSE_GEN_TEMPLATES, DATAVERSE_GEN_TEMPLATES_VERSION, DEFAULT_TEMPLATE_ROOT, dataverseGenTemplateFiles } from './dataverseGenTemplates';
export type { DeleteResult } from './plan';
export { configPathFor, loadProjectConfig, saveProjectConfig } from './projectConfig';
export type { ProjectConfigState } from './projectConfig';
export { connectionKey, getRememberedProjectFolder, loadToolConfig, rememberProjectFolder, saveToolConfig } from './settings';
export { listSolutions, getSolutionMemberIds, getSolutionEntityIds } from './solutions';
