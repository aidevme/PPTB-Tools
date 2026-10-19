# Footer

The bar at the bottom of the tool. It shows the tool's name and version, credits the projects the tool is
compatible with, reminds users to review generated files, and links to the documentation and repository.

Source: [`src/components/layout/Footer.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/layout/Footer.tsx);
the links and credits are constants in
[`Footer.const.ts`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/layout/Footer.const.ts)
(`DOCUMENTATION_URL`, `REPOSITORY_URL`, `CREDITS`).

## Layout

When the tool opens, the footer is pinned to the bottom of the window for 5 seconds (`FOOTER_AUTO_HIDE_MS` in
`Footer.const.ts`). Then it slides down out of the window (`FOOTER_SLIDE_OUT_MS`, 250 ms; instant when the system
asks for reduced motion) and stays at the end of the page, so it shows again whenever the page is scrolled to the
bottom. If the page is already scrolled to the end, or doesn't scroll, it stays where it is.

`App.tsx` wraps the footer in a container (`stickyFooter` in `App.styles.ts`, which also holds the gap above it) and
applies the phase from `useAutoHideFooter`: `pinned` (sticky), `sliding` (`footerSliding`) and `docked`
(`footerDocked`, in the normal flow). While it's pinned or sliding, its height is published as `--app-footer-height`
for `scroll-padding-bottom`, like the [Header](./header.md)'s; once docked it covers nothing, so the height is `0px`.
The links stay in the page and keyboard focus, so Tab still reaches them and scrolls them into view.

The footer uses the header's soft brand gradient, mirrored, with a top border and shadow. From left to
right:

- **Identity:** a small version of the header's app icon tile (`AppIcon`, size `small`), "Early-Bound TypeScript Generator", and
  "v*version* · Part of PPTB Tools". The version is read from `package.json` at build time.
- **Credits:** "Compatible with Scott Durow's" followed by two link chips,
  [dataverse-ify](https://github.com/scottdurow/dataverse-ify) and
  [dataverse-gen](https://github.com/scottdurow/dataverse-gen), each tagged **MIT**. A tooltip on each says
  what the project is (the runtime the generated types are for, and the CLI this tool shares its project
  file with) and that the link opens in a new window.
- **Reminder** under the credits, with an info icon: files are generated from the connected environment's
  metadata, so review the preview before committing them.
- **Links:** **Documentation** and **GitHub Repo** as subtle buttons with icons and an "opens in a new
  window" marker. They're in a `nav` labelled "Project links".
  - **Documentation** points to the tool's Getting started page on the docs site
    (`DOCUMENTATION_URL` in `Footer.const.ts`).
  - **GitHub Repo** points to <https://github.com/aidevme/PPTB-Tools> (`REPOSITORY_URL`).

All external links open in a new window. On narrow windows the sections wrap onto separate rows.

Styles are in `src/styles/Footer.styles.ts`. Colors come from Fluent theme tokens, so the footer follows PPTB's
light and dark themes.

## Props

None.
