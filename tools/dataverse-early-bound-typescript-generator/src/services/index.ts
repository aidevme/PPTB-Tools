/** PPTB-facing services: file system, Dataverse metadata and solutions, project config and write plans. */
export { mapWithConcurrency } from './concurrency';
export { errorStatus, friendlyError, isTransientError, reportError, technicalMessage, withRetries, withRetry } from './errors';
export type { RetryOptions } from './errors';
export { notifyGenerationComplete, notifyPreviewReady, notifyProjectLoaded, projectLoadedMessage, NOTIFICATION_TYPES, notificationOptions } from './notifications';
export type { NotificationType } from './notifications';
export { PptbFileSink, InMemoryFileSink, buildDeleteCommands } from './fileSink';
export type { DirectoryEntry, FileSink } from './fileSink';
export { PptbMetadataProvider, toTableType } from './metadataProvider';
export { QUERY_PAGE_SIZE, buildPageQuery, queryAllPages } from './paging';
export type { PagedQuery, QueryRunner } from './paging';
export { separatorOf, isSamePath, joinPath, dirname, basename, toPosix } from './paths';
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
    pendingWriteCount,
    plural,
    countStatuses,
} from './plan';
export type { WriteOptions } from './plan';
export { CUSTOM_ENUM_TEMPLATE, DATAVERSE_GEN_TEMPLATES, DEFAULT_TEMPLATE_ROOT, dataverseGenTemplateFiles, editedEnumTemplate } from './dataverseGenTemplates';
export type { TemplateFileOptions } from './dataverseGenTemplates';
export type { DeleteResult } from './plan';
export { loadProjectConfig, saveProjectConfig } from './projectConfig';
export type { ProjectConfigState } from './projectConfig';
export { connectionKey, getRememberedProjectFolder, loadStoredToolSettings, loadToolConfig, rememberProjectFolder, saveToolConfig } from './settings';
export { listSolutions, getSolutionMemberIds, getSolutionEntityIds } from './solutions';
