/**
 * How long the footer stays pinned to the bottom of the window after the tool opens, in milliseconds. After that it
 * slides out and sits at the end of the page, so it shows again when the page is scrolled to the bottom.
 */
export const FOOTER_AUTO_HIDE_MS = 5000;

/** How long the footer takes to slide out when it stops being pinned, in milliseconds. */
export const FOOTER_SLIDE_OUT_MS = 250;

/** The tool's Getting started page on the published docs site (GitHub Pages). */
export const DOCUMENTATION_URL = 'https://aidevme.github.io/PPTB-Tools/pptb-tools/dataverse-early-bound-typescript-generator/getting-started/';

/** The repository the tool's source is in, for the footer's GitHub Repo link. */
export const REPOSITORY_URL = 'https://github.com/aidevme/PPTB-Tools';

/**
 * The projects the footer credits, in display order: each one's name, link and what it is to this tool (shown in
 * its tooltip as "the `role`").
 */
export const CREDITS = [
    { name: 'dataverse-ify', url: 'https://github.com/scottdurow/dataverse-ify', role: 'runtime the generated types are for' },
    { name: 'dataverse-gen', url: 'https://github.com/scottdurow/dataverse-gen', role: 'CLI this tool shares its project file with' },
];
