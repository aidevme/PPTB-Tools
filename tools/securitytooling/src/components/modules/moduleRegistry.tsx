import React from "react";
import { Connect } from "./Connect";
import { RunLiveScan } from "./RunLiveScan";

export interface IModuleContentProps {
    /** Identifier for the module, matching its `MODULE_CARDS` entry. */
    module?: string;
}

const ConnectModuleContent: React.FC<IModuleContentProps> = ({ module }) => (
    <Connect redirectUri={module && `https://blue16.nl/${module}.html`} />
);

const RunLiveScanModuleContent: React.FC<IModuleContentProps> = () => <RunLiveScan />;

/** Maps a `MODULE_CARDS` module id to the component `Module` renders for it. Modules without an
 * entry fall back to `DEFAULT_MODULE_CONTENT` (`Connect`). */
export const MODULE_COMPONENTS: Record<string, React.ComponentType<IModuleContentProps>> = {
    "copilot-studio-agent-security-posture": RunLiveScanModuleContent,
};

/** Component rendered for a module id with no `MODULE_COMPONENTS` entry. */
export const DEFAULT_MODULE_CONTENT: React.ComponentType<IModuleContentProps> = ConnectModuleContent;

/** Resolves the component to render for a module id, falling back to {@link DEFAULT_MODULE_CONTENT}. */
export function getModuleContent(module?: string): React.ComponentType<IModuleContentProps> {
    return (module && MODULE_COMPONENTS[module]) || DEFAULT_MODULE_CONTENT;
}
