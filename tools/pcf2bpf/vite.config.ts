import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import type { Plugin } from "vite";

/**
 * PPTB loads tools from a local folder (often via a file:// or iframe srcdoc context), where
 * ES module script tags can fail to execute. Bundling as a single IIFE placed at the end of
 * <body> avoids both problems.
 */
function fixHtmlForPPTB(): Plugin {
    return {
        name: "fix-html-for-pptb",
        enforce: "post",
        transformIndexHtml(html) {
            html = html.replace(/\s*type="module"/g, "");
            html = html.replace(/\s*crossorigin/g, "");
            html = html.replace(/\s+>/g, ">");

            const scriptRegex = /(<script[^>]*src="[^"]*"[^>]*><\/script>)/g;
            const scripts: string[] = [];
            html = html.replace(scriptRegex, (match) => {
                scripts.push(match);
                return "";
            });

            if (scripts.length > 0) {
                html = html.replace("</body>", `\n  ${scripts.join("\n  ")}\n</body>`);
            }

            return html;
        },
    };
}

export default defineConfig({
    plugins: [react(), fixHtmlForPPTB()],
    base: "./",
    build: {
        outDir: "dist",
        assetsDir: "assets",
        rollupOptions: {
            output: {
                format: "iife",
                inlineDynamicImports: true,
                manualChunks: undefined,
            },
        },
    },
});
