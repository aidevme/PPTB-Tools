import { defineConfig } from "vitepress";

export default defineConfig({
    title: "PPTB Tools",
    // Published as a GitHub Pages project site at https://aidevme.github.io/PPTB-Tools/.
    base: "/PPTB-Tools/",
    description: "Documentation for Power Platform ToolBox (PPTB) tools.",
    themeConfig: {
        nav: [
            { text: "Home", link: "/" },
            { text: "Dataverse Early-Bound TypeScript Generator", link: "/pptb-tools/dataverse-early-bound-typescript-generator/" },
        ],
        sidebar: [
            {
                text: "PPTB Tools",
                items: [
                    {
                        text: "Dataverse Early-Bound TypeScript Generator",
                        link: "/pptb-tools/dataverse-early-bound-typescript-generator/",
                        items: [
                            { text: "Getting Started", link: "/pptb-tools/dataverse-early-bound-typescript-generator/getting-started/" },
                            {
                                text: "Architecture",
                                link: "/pptb-tools/dataverse-early-bound-typescript-generator/architecture/",
                                collapsed: true,
                                items: [
                                    { text: "Core", link: "/pptb-tools/dataverse-early-bound-typescript-generator/architecture/core" },
                                    { text: "Services", link: "/pptb-tools/dataverse-early-bound-typescript-generator/architecture/services" },
                                    { text: "App state and hooks", link: "/pptb-tools/dataverse-early-bound-typescript-generator/architecture/app-state" },
                                    { text: "Build and testing", link: "/pptb-tools/dataverse-early-bound-typescript-generator/architecture/build-and-testing" },
                                ],
                            },
                            {
                                text: "Components",
                                link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/",
                                collapsed: true,
                                items: [
                                    { text: "Header", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/header" },
                                    { text: "WorkflowProgress", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/workflow-progress" },
                                    { text: "StepCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/step-card" },
                                    { text: "SettingsPanel", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/settings-panel" },
                                    { text: "ProjectCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/project-card" },
                                    { text: "NewProjectDialog", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/new-project-dialog" },
                                    { text: "LoadProjectDialog", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/load-project-dialog" },
                                    { text: "ConfirmationDialog", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/confirmation-dialog" },
                                    { text: "SelectionCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/selection-card" },
                                    { text: "OptionsCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/options-card" },
                                    { text: "PreviewCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/preview-card" },
                                    { text: "FileViewer", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/file-viewer" },
                                    { text: "CodeViewer", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/code-viewer" },
                                    { text: "Footer", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/footer" },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
        socialLinks: [{ icon: "github", link: "https://github.com/aidevme/PPTB-Tools" }],
        search: {
            provider: "local",
        },
    },
});
