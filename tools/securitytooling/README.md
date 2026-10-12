# Security Tools

A Power Platform Tool Box (PPTB) dashboard for Microsoft's **Security Posture** toolset — a launcher that
presents each posture-assessment module as a card and links out to its hosted app.

> For the community: releasing a Microsoft Security Posture toolset covering Entra, Copilot Studio, Power
> Platform, Azure AI Foundry and agent migration. All apps are hosted as single-tenant apps (most secure).
> Feedback (bug fixes and/or feature requests) is welcome.

This dashboard is based on the Security Posture toolset created by
[Ing. Derk van der Woude](https://www.linkedin.com/in/derkvanderwoude/); this tool provides a PPTB-native
launcher for it. Thank you, Derk, for building and sharing this toolset with the community!

## Modules

| Module | Status |
| --- | --- |
| Entra User Security Posture | Preview |
| Entra Workload Security Posture | Preview |
| Entra Blueprint Security Posture | Preview |
| Shadow AI Assessment | Private Preview |
| Copilot Studio Agent Security Posture | Preview |
| Power Platform Security Posture | Preview |
| Azure AI Foundry Security Posture | Preview |
| Classic → Modern Agent Migrator | Preview |
| Microsoft Agent 365 Explainer | — |
| Agent 365 Security Overview | Preview |

Each module's title, description, icon, accent color and launch link are data-driven from
`src/consts/modulecard.consts.ts` (`MODULE_CARDS`) — add or edit an entry there to change what the dashboard
shows.

## Features

- ✅ Grid of module cards (`ModuleCard`), each with an icon, category tag, title, description and a
  "Launch Module" link out to the hosted app.
- ✅ Light/Dark theme toggle in the header toolbar, syncing both the app and the card palette to the PPTB
  host's theme.
- ✅ Settings panel (Fluent `Drawer`) opened from the header toolbar.

## Installation

### Prerequisites

- Node.js 18 or higher
- Power Platform Tool Box desktop application

### Install dependencies

```bash
npm install
```

### Build

```bash
npm run build
```

Type-checks with `tsc` and bundles `src/` to `dist/` as a single IIFE (see "Vite configuration" below for
why).

### Development mode

```bash
npm run dev
```

The dev server runs standalone; the module cards render normally, but ToolBox host APIs (theme detection,
etc.) are only available when the tool is loaded inside Power Platform Tool Box.

### Testing locally in PPTB

1. Build the tool (see above).
2. In Power Platform Tool Box, enable the Debug Menu in Settings.
3. Debug section → Browse → select this tool's directory (or the `dist` folder).
4. Reopen the tool tab after each rebuild to pick up changes.

## Project structure

```
securitytooling/
├── src/
│   ├── components/
│   │   ├── Header.tsx              # "Security Tools" branding
│   │   ├── HeaderToolbar.tsx       # Light/Dark toggle + Settings button
│   │   ├── Footer.tsx              # Package name/version
│   │   ├── cards/
│   │   │   └── ModuleCard.tsx      # One module's card (icon, tag, title, description, launch link)
│   │   ├── panels/
│   │   │   └── SettingsPanel.tsx   # Fluent Drawer opened from the header toolbar
│   │   └── modules/
│   │       └── Module.tsx          # Placeholder module content view
│   ├── consts/
│   │   └── modulecard.consts.ts    # MODULE_CARDS data — the dashboard's module grid
│   ├── styles/
│   │   └── index.ts                # useAppStyles (root, header, toolbar row, grid, footer)
│   ├── themeModeContext.ts         # ThemeModeContext / SetThemeModeContext (light/dark)
│   ├── main.tsx                     # FluentProvider, theme detection, entry point
│   ├── App.tsx                      # Top-level layout: Header, HeaderToolbar, module grid, Footer
│   └── vite-env.d.ts
├── index.html
├── vite.config.ts
├── tsconfig.json / tsconfig.node.json
└── package.json
```

## Vite configuration

PPTB loads tools from a local folder (often `file://` or an iframe `srcdoc`), where
`<script type="module">` can fail to execute. The `fixHtmlForPPTB` Vite plugin strips
`type="module"`/`crossorigin` from the built HTML and moves script tags to the end of `<body>`; Rollup output
is forced to `iife` with `inlineDynamicImports: true` so the whole app ships as one script. Don't reintroduce
code-splitting or ESM output — it will break loading inside PPTB even though `npm run dev` still works fine.

## License

GPL-3.0 — see the repository [LICENSE](../../LICENSE).
