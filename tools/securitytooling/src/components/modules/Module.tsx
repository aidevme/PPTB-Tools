import React from "react";
import { Card, Text, Title2, makeStyles, tokens } from "@fluentui/react-components";
import { useAppContext } from "../../hooks";
import { Agent365SecurityOverviewModule } from "./Agent365SecurityOverviewModule";
import { AzureAIFoundrySecurityPostureModule } from "./AzureAIFoundrySecurityPostureModule";
import { ClassicModernAgentMigratorModule } from "./ClassicModernAgentMigratorModule";
import { CopilotStudioAgentSecurityPostureModule } from "./CopilotStudioAgentSecurityPostureModule";
import { EntraBlueprintSecurityPostureModule } from "./EntraBlueprintSecurityPostureModule";
import { EntraUserSecurityPostureModule } from "./EntraUserSecurityPostureModule";
import { EntraWorkloadSecurityPostureModule } from "./EntraWorkloadSecurityPostureModule";
import { MicrosoftAgent365ExplainerModule } from "./MicrosoftAgent365ExplainerModule";
import { PowerPlatformSecurityPostureModule } from "./PowerPlatformSecurityPostureModule";
import { ShadowAIAssessmentModule } from "./ShadowAIAssessmentModule";

export interface IModuleProps {
    /** Icon representing the tool, rendered in the accent-tinted badge next to the category tag. */
    icon: React.ReactElement;
    /** Name of the module shown as the placeholder's heading. Defaults to `"Module"`. */
    title?: string;
    /** Short description of what the module does. */
    description?: string;
    /** Identifier for the module, matching its `MODULE_CARDS` entry. */
    module?: string;
}

const useModuleStyles = makeStyles({
    header: {
        display: "flex",
        alignItems: "center",
        gap: tokens.spacingHorizontalS,
    },
    icon: {
        fontSize: "32px",
    },
});

/** Maps a `MODULE_CARDS` module id to the component that renders its content. Module ids with no
 * entry here render no extra content beyond the placeholder header/description. */
const MODULE_COMPONENTS: Record<string, React.ComponentType> = {
    "entra-user-security-posture": EntraUserSecurityPostureModule,
    "entra-workload-security-posture": EntraWorkloadSecurityPostureModule,
    "entra-blueprint-security-posture": EntraBlueprintSecurityPostureModule,
    "shadow-ai-assessment": ShadowAIAssessmentModule,
    "copilot-studio-agent-security-posture": CopilotStudioAgentSecurityPostureModule,
    "power-platform-security-posture": PowerPlatformSecurityPostureModule,
    "azure-ai-foundry-security-posture": AzureAIFoundrySecurityPostureModule,
    "classic-to-modern-agent-migrator": ClassicModernAgentMigratorModule,
    "microsoft-agent-365-control-plane": MicrosoftAgent365ExplainerModule,
    "agent-365-security": Agent365SecurityOverviewModule,
};

/** Placeholder content view for a Security Tools module. */
export const Module: React.FC<IModuleProps> = ({ icon, title = "Module", description, module }) => {
    const styles = useModuleStyles();
    const appContext = useAppContext();
    const ModuleContent = module ? MODULE_COMPONENTS[module] : undefined;

    return (
        <Card>
            <div className={styles.header}>
                <span className={styles.icon}>{icon}</span>
                <Title2>{title}</Title2>
            </div>
            <Text>{JSON.stringify(appContext)}</Text>
            {description && <Text>{description}</Text>}
            {module && <Text>{module}</Text>}
            {ModuleContent && <ModuleContent />}
        </Card>
    );
};
