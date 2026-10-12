import { defineConfig } from "vitepress";

export default defineConfig({
    title: "PPTB Tools",
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
                    { text: "Dataverse Early-Bound TypeScript Generator", link: "/pptb-tools/dataverse-early-bound-typescript-generator/" },
                ],
            },
        ],
        socialLinks: [{ icon: "github", link: "https://github.com/aidevme/PPTB-Tools" }],
        search: {
            provider: "local",
        },
    },
});
