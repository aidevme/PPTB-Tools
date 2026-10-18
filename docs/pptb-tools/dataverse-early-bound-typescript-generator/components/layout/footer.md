# Footer

The bar at the bottom of the tool. It shows the tool's name and version, credits the projects the tool is
compatible with, reminds users to review generated files, and links to the documentation and repository.

Source: [`src/components/layout/Footer.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/layout/Footer.tsx)

## Layout

The footer stays at the bottom of the window while the page scrolls: `App.tsx` wraps it in a sticky container
(`stickyFooter` in `App.styles.ts`), which also holds the gap above it. Its height is published as
`--app-footer-height` for `scroll-padding-bottom`, like the [Header](./header.md)'s.

The footer uses the header's soft brand gradient, mirrored, with a top border and shadow. From left to
right:

- **Identity:** a small version of the header's app icon tile (`AppIcon`, size `small`), "Early-Bound TypeScript Generator", and
  "v*version* · Part of PPTB Tools". The version is read from `package.json` at build time.
- **Credits:** "Compatible with Scott Durow's" followed by two link chips,
  [dataverse-ify](https://github.com/scottdurow/dataverse-ify) and
  [dataverse-gen](https://github.com/scottdurow/dataverse-gen), each tagged **MIT**. A tooltip on each says
  what the project is: the runtime the generated types are for, and the CLI this tool shares its project
  file with.
- **Reminder** under the credits, with an info icon: files are generated from the connected environment's
  metadata, so review the preview before committing them.
- **Links:** **Documentation** and **GitHub Repo** as subtle buttons with icons and an "opens in a new
  window" marker. They're in a `nav` labelled "Project links".
  - **Documentation** points to the tool's Getting started page on the docs site
    (`DOCUMENTATION_URL` in `Footer.tsx`).
  - **GitHub Repo** points to <https://github.com/aidevme/PPTB-Tools>.

All external links open in a new window. On narrow windows the sections wrap onto separate rows.

Styles are in `src/styles/Footer.styles.ts`. Colors come from Fluent theme tokens, so the footer follows PPTB's
light and dark themes.

## Props

None.
