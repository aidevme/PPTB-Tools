/**
 * Presentational components; all data and callbacks come from `apps/App.tsx` as props. `App` itself isn't exported
 * here: it imports this barrel, and `main.tsx` imports it directly.
 */
export { CodeViewer } from './viewers/CodeViewer';
export type { ICodeViewerProps } from './viewers/CodeViewer';
export { Footer } from './layout/Footer';
export { Header } from './layout/Header';
export type { HeaderProps } from './layout/Header';
export { ConfirmationDialog } from './dialogs/ConfirmationDialog';
export type { IConfirmationDialogProps } from './dialogs/ConfirmationDialog';
export { LoadProjectDialog } from './dialogs/LoadProjectDialog';
export type { ILoadProjectDialogProps } from './dialogs/LoadProjectDialog';
export { FileSearchBox } from './shared/FileSearchBox';
export type { IFileSearchBoxProps } from './shared/FileSearchBox';
export { StepCard, StepIndicator } from './shared/StepCard';
export type { IStepCardProps } from './shared/StepCard';
export { WorkflowProgress } from './shared/WorkflowProgress';
export type { IWorkflowProgressProps } from './shared/WorkflowProgress';
export { computeWorkflowSteps, stepElementId } from './shared/workflowSteps';
export type { StepKey, StepState, WorkflowInput } from './shared/workflowSteps';
export type { ProjectOpenTarget, RecentProject } from './cards/ProjectCard';
export { NewProjectDialog } from './dialogs/NewProjectDialog';
export type { INewProjectDialogProps, NewProject } from './dialogs/NewProjectDialog';
export { OptionsCard } from './cards/OptionsCard';
export type { OptionsCardProps } from './cards/OptionsCard';
export { PreviewCard } from './cards/PreviewCard';
export type { PreviewCardProps } from './cards/PreviewCard';
export { ProjectCard } from './cards/ProjectCard';
export type { ProjectCardProps } from './cards/ProjectCard';
export { SelectionCard } from './cards/SelectionCard';
export type { SelectionCardProps, SelectionKind } from './cards/SelectionCard';
export { SettingsPanel } from './panels/SettingsPanel';
export type { SettingsPanelProps } from './panels/SettingsPanel';
