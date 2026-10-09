# Security Tools

A Power Platform Tool Box (PPTB) dashboard for Microsoft's **Security Posture** toolset — a launcher that
presents each posture-assessment module as a card and links out to its hosted app.

Based on the Security Posture toolset created by
[Ing. Derk van der Woude](https://www.linkedin.com/in/derkvanderwoude/).

Source: [tools/securitytooling](https://github.com/aidevme/PPTB-Tools/tree/main/tools/securitytooling) ·
[README](https://github.com/aidevme/PPTB-Tools/tree/main/tools/securitytooling#readme)

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

## Features

- Grid of module cards, each with an icon, category tag, title, description and a "Launch Module" action.
- Light/Dark theme toggle in the header toolbar, syncing both the app and the card palette to the PPTB
  host's theme.
- Breadcrumb navigation between the dashboard and an open module.
- Settings panel opened from the header toolbar.

## Installation

```bash
npm install
npm run dev      # Vite dev server, for iterating in a regular browser tab
npm run build    # type-check + bundle src/ to dist/ (single IIFE, per PPTB's loading constraints)
```

### Testing locally in PPTB

1. Build the tool (see above).
2. In Power Platform Tool Box, enable the Debug Menu in Settings.
3. Debug section → Browse → select this tool's directory (or the `dist` folder).
4. Connect to a Dataverse environment, then reopen the tool tab after each rebuild.
