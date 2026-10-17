import { defineConfig } from "vitepress";

export default defineConfig({
    title: "PPTB Tools",
    // Published as a GitHub Pages project site at https://aidevme.github.io/PPTB-Tools/.
    base: "/PPTB-Tools/",
    description: "Documentation for Power Platform ToolBox (PPTB) tools.",
    // The agent template's decision records, review logs and onboarding guides stay in the repository but aren't part
    // of the site: they're not in the navigation, use template placeholders and expressions Vue can't compile
    // (`<title>`, `${{ … }}`), and link to folders that only exist in the template.
    srcExclude: ["decisions/**", "review-logs/**", "onboarding/**"],
    themeConfig: {
        nav: [
            { text: "Home", link: "/" },
            { text: "Dataverse Early-Bound TypeScript Generator", link: "/pptb-tools/dataverse-early-bound-typescript-generator/" },
            { text: "Repository", link: "/repository/agentic-workflows" },
        ],
        sidebar: {
            "/repository/": [
                {
                    text: "Repository",
                    items: [{ text: "GitHub Agentic Workflows", link: "/repository/agentic-workflows" }],
                },
            ],
            "/pptb-tools/dataverse-early-bound-typescript-generator/": [
                {
                    text: "Dataverse Early-Bound TypeScript Generator",
                    link: "/pptb-tools/dataverse-early-bound-typescript-generator/",
                },
                {
                    text: "User guide",
                    items: [
                        { text: "Getting started", link: "/pptb-tools/dataverse-early-bound-typescript-generator/getting-started/" },
                        { text: "Using the generated code", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/using-the-generated-code" },
                        { text: "Why generate metadata?", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/why-generate-metadata" },
                        { text: "What gets generated", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/what-gets-generated" },
                        { text: "Project file reference", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/project-file" },
                        { text: "Tool settings", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/tool-settings" },
                        { text: "Moving from dataverse-gen", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/moving-from-dataverse-gen" },
                        { text: "Safety: what the tool changes", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/safety" },
                        { text: "Troubleshooting & limitations", link: "/pptb-tools/dataverse-early-bound-typescript-generator/guide/troubleshooting" },
                    ],
                },
                {
                    text: "Contributor guide",
                    items: [
                        { text: "Contributing", link: "/pptb-tools/dataverse-early-bound-typescript-generator/contributing/" },
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
                                {
                                    text: "Apps",
                                    collapsed: true,
                                    items: [
                                        { text: "App", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/apps/app" },
                                    ],
                                },
                                {
                                    text: "Cards",
                                    collapsed: true,
                                    items: [
                                        { text: "ProjectCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/cards/project-card" },
                                        { text: "SelectionCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/cards/selection-card" },
                                        { text: "OptionsCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/cards/options-card" },
                                        { text: "PreviewCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/cards/preview-card" },
                                    ],
                                },
                                {
                                    text: "Dialogs",
                                    collapsed: true,
                                    items: [
                                        { text: "ProjectFormDialog", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/dialogs/project-form-dialog" },
                                        { text: "LoadProjectDialog", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/dialogs/load-project-dialog" },
                                        { text: "ConfirmationDialog", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/dialogs/confirmation-dialog" },
                                    ],
                                },
                                {
                                    text: "Layout",
                                    collapsed: true,
                                    items: [
                                        { text: "Header", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/layout/header" },
                                        { text: "Footer", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/layout/footer" },
                                    ],
                                },
                                {
                                    text: "Panels",
                                    collapsed: true,
                                    items: [
                                        { text: "SettingsPanel", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/panels/settings-panel" },
                                    ],
                                },
                                {
                                    text: "Shared",
                                    collapsed: true,
                                    items: [
                                        { text: "WorkflowProgress", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/shared/workflow-progress" },
                                        { text: "StepCard", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/shared/step-card" },
                                        { text: "FileSearchBox", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/shared/file-search-box" },
                                    ],
                                },
                                {
                                    text: "Tables",
                                    collapsed: true,
                                    items: [
                                        { text: "FileTable", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/tables/file-table" },
                                        { text: "ProjectsTable", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/tables/projects-table" },
                                        { text: "SelectionTable", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/tables/selection-table" },
                                        { text: "SortableHeaderCell", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/tables/sortable-header-cell" },
                                    ],
                                },
                                {
                                    text: "Viewers",
                                    collapsed: true,
                                    items: [
                                        { text: "FileViewer", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/viewers/file-viewer" },
                                        { text: "CodeViewer", link: "/pptb-tools/dataverse-early-bound-typescript-generator/components/viewers/code-viewer" },
                                    ],
                                },
                            ],
                        },
                        { text: "Testing", link: "/pptb-tools/dataverse-early-bound-typescript-generator/contributing/testing" },
                        { text: "Design history", link: "/pptb-tools/dataverse-early-bound-typescript-generator/contributing/design-history" },
                    ],
                },
            ],
        },
        socialLinks: [{ icon: "github", link: "https://github.com/aidevme/PPTB-Tools" }],
        search: {
            provider: "local",
        },
    },
});
