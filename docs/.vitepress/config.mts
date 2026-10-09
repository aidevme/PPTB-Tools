import { defineConfig } from "vitepress";

export default defineConfig({
    title: "PPTB Tools",
    description: "Documentation for Power Platform ToolBox (PPTB) tools.",
    themeConfig: {
        nav: [
            { text: "Home", link: "/" },
            { text: "Security Tools", link: "/pptb-tools/security-tooling/" },
            { text: "Dataverse Type Forge", link: "/pptb-tools/dataverse-type-gen/" },
        ],
        sidebar: [
            {
                text: "PPTB Tools",
                items: [
                    { text: "Security Tools", link: "/pptb-tools/security-tooling/" },
                    { text: "Dataverse Type Forge", link: "/pptb-tools/dataverse-type-gen/" },
                ],
            },
        ],
        socialLinks: [{ icon: "github", link: "https://github.com/aidevme/PPTB-Tools" }],
        search: {
            provider: "local",
        },
    },
});
