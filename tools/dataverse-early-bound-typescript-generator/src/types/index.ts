export type { EntitySummary } from './EntitySummary';
export type { OperationSummary } from './OperationSummary';
export type { SolutionSummary } from './SolutionSummary';
export type { FileStatus, PlannedFile, WritePlan, WriteResult } from './WritePlan';

/** Progress of a multi-step background task, shown in the UI. */
export interface Progress {
    /** Short description of what is happening right now. */
    message: string;
    completed: number;
    total: number;
}

export interface LogEntry {
    timestamp: Date;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
}
