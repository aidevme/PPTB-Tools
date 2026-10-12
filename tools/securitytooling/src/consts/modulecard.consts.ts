import type { FluentIcon } from "@fluentui/react-icons";
import {
    ArrowSyncRegular,
    BotRegular,
    BrainCircuitRegular,
    CloudRegular,
    DesignIdeasRegular,
    HeadsetRegular,
    PersonRegular,
    PlugConnectedRegular,
    ShieldCheckmarkRegular,
    ShieldLockRegular,
} from "@fluentui/react-icons";

/** Data for one entry in the Security Tools dashboard's module grid — see `ModuleCard`'s props for
 * what each field renders. `icon` is the component itself (not an element) so this file stays plain
 * `.ts` (no JSX); callers instantiate it, e.g. `<tool.icon />`. */
export interface IModuleCardData {
    key: string;
    icon: FluentIcon;
    tag: string;
    eyebrow?: string;
    title: string;
    description: string;
    module: string;
    accentColor: string;
}

/** The Security Tools dashboard's module grid. */
export const MODULE_CARDS: IModuleCardData[] = [
    {
        key: "entra-user-security-posture",
        icon: PersonRegular,
        tag: "USER",
        eyebrow: "User Security",
        title: "Entra User Security Posture (Preview)",
        description:
            "Score every member account 0-100 across MFA strength, privileged access, account hygiene and Identity Protection risk, with a tenant grade and per-account remediation.",
        module: "entra-user-security-posture",
        accentColor: "#f85149",
    },
    {
        key: "entra-workload-security-posture",
        icon: PlugConnectedRegular,
        tag: "WORKLOAD",
        eyebrow: "Service Principal Security",
        title: "Entra Workload Security Posture (Preview)",
        description:
            "Risk-score every consented enterprise app on its permissions, credential hygiene, tenancy and publisher trust, then map a per-app attack path with remediation.",
        module: "entra-workload-security-posture",
        accentColor: "#d29922",
    },
    {
        key: "entra-blueprint-security-posture",
        icon: DesignIdeasRegular,
        tag: "AGENT",
        eyebrow: "Agent Security",
        title: "Entra Blueprint Security Posture (Preview)",
        description:
            "Audit Entra Agent ID blueprints and the agents they spawn across declared-vs-granted permissions, credential hygiene, dormant agents and CA coverage, scored 0-100.",
        module: "entra-blueprint-security-posture",
        accentColor: "#58a6ff",
    },
    {
        key: "shadow-ai-assessment",
        icon: BrainCircuitRegular,
        tag: "GENAI/AGENTS",
        eyebrow: "AI Exposure",
        title: "Shadow AI Assessment (Private Preview)",
        description:
            "Discover GenAI and Shadow-AI usage across Microsoft Entra to surface rogue apps and models, data oversharing, GDPR exposure and Agent 365 protection posture.",
        module: "shadow-ai-assessment",
        accentColor: "#39c5cf",
    },
    {
        key: "copilot-studio-agent-security-posture",
        icon: BotRegular,
        tag: "COPILOT STUDIO",
        title: "Copilot Studio Agent Security Posture (Preview)",
        description:
            "Audit Copilot Studio agents for authentication gaps, over-permissioned connectors, anonymous no-auth bots and Agent 365 governance posture across your tenant.",
        module: "copilot-studio-agent-security-posture",
        accentColor: "#bc8cff",
    },
    {
        key: "power-platform-security-posture",
        icon: ShieldLockRegular,
        tag: "POWER PLATFORM",
        title: "Power Platform Security Posture (Preview)",
        description:
            "Baseline each Power Platform environment 0-100 across agent authentication, connector and data-movement risk, cloud-flow egress, privileged admins and DLP coverage.",
        module: "power-platform-security-posture",
        accentColor: "#db61a2",
    },
    {
        key: "azure-ai-foundry-security-posture",
        icon: CloudRegular,
        tag: "AZURE AI",
        title: "Azure AI Foundry Security Posture (Preview)",
        description:
            "Read-only ARM scan of Azure OpenAI, AI Services and Foundry hubs across network exposure, API-key auth, identity, logging and model-deployment filtering, scored 0-100.",
        module: "azure-ai-foundry-security-posture",
        accentColor: "#56d4dd",
    },
    {
        key: "classic-to-modern-agent-migrator",
        icon: ArrowSyncRegular,
        tag: "MIGRATION",
        title: "Classic → Modern Agent Migrator (Preview)",
        description:
            "Inventory classic, Copilot Studio and Azure AI Foundry agents, then recreate them as modern Entra Agent ID identities with the right migration path per platform.",
        module: "classic-to-modern-agent-migrator",
        accentColor: "#3fb950",
    },
    {
        key: "microsoft-agent-365-explainer",
        icon: HeadsetRegular,
        tag: "AGENT 365",
        eyebrow: "IT Control Plane for Agents",
        title: "Microsoft Agent 365 Explainer",
        description:
            "Interactive explainer of Microsoft Agent 365: the control plane that lets IT observe, govern and secure the agent fleet — and exactly how Entra, Defender and Purview each plug in.",
        module: "microsoft-agent-365-control-plane",
        accentColor: "#79c0ff",
    },
    {
        key: "agent-365-security-overview",
        icon: ShieldCheckmarkRegular,
        tag: "AGENT 365",
        eyebrow: "Security Overview",
        title: "Agent 365 Security Overview (Preview)",
        description:
            "Sign in with an app registration for a live security overview of your tenant's Entra Agent ID estate — risky agents, inherited blueprint permissions, owners & sponsors, Defender AgentsInfo hunting and CA coverage — mapped onto the clickable control plane.",
        module: "agent-365-security",
        accentColor: "#79c0ff",
    },
];
