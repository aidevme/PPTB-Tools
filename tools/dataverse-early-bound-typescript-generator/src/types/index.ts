export type { EntitySummary, TableType } from './EntitySummary';
export type { OperationSummary } from './OperationSummary';
export type { SolutionSummary } from './SolutionSummary';
export type { FileStatus, PlannedFile, WritePlan, WriteResult, WriteStatus } from './WritePlan';

/** Progress of a multi-step background task, shown in the UI. */
export interface Progress {
    /** Short description of what is happening right now. */
    message: string;
    completed: number;
    total: number;
}
