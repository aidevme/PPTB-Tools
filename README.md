# Power Platform ToolBox (PPTB) Tools

[![License](https://img.shields.io/github/license/aidevme/PPTB-Tools)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/aidevme/PPTB-Tools)](https://github.com/aidevme/PPTB-Tools/commits/main)
[![Open issues](https://img.shields.io/github/issues/aidevme/PPTB-Tools)](https://github.com/aidevme/PPTB-Tools/issues)
[![Discussions](https://img.shields.io/github/discussions/aidevme/PPTB-Tools)](https://github.com/aidevme/PPTB-Tools/discussions)
[![CodeQL](https://github.com/aidevme/PPTB-Tools/actions/workflows/codeql.yml/badge.svg)](https://github.com/aidevme/PPTB-Tools/actions/workflows/codeql.yml)


Tools for Power Platform ToolBox (PPTB) - a comprehensive toolkit for working with Microsoft Dataverse and Power Platform.

- [Power Platform ToolBox (PPTB) Tools](#power-platform-toolbox-pptb-tools)
    - [Overview](#overview)
    - [Tools](#tools)
        - [Dataverse Early-Bound TypeScript Generator](#dataverse-early-bound-typescript-generator)
    - [Contributing](#contributing)
    - [License](#license)

## Overview

This repository hosts individual tools that plug into Power Platform ToolBox (PPTB), following the same model as [XrmToolBox](https://www.xrmtoolbox.com/) plugins: each tool is a self-contained add-in that helps administrators, consultants, and developers work more efficiently with Microsoft Dataverse and the Power Platform.

## Tools

### Dataverse Early-Bound TypeScript Generator

This tool generates early-bound TypeScript types and metadata for Dataverse tables, actions and functions. Its output works with Scott Durow's [dataverse-ify](https://github.com/scottdurow/dataverse-ify), and it shares the `.dataverse-gen.json` project file with his [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI, whose generator it ports. Source: [tools/dataverse-type-gen](tools/dataverse-type-gen/) · Docs: [docs/pptb-tools/dataverse-early-bound-typescript-generator](docs/pptb-tools/dataverse-early-bound-typescript-generator/index.md).

- Pick a project folder and load or create `.dataverse-gen.json`.
- Select tables (with search and a solution filter), actions and functions.
- Preview generated files as new, changed, unchanged or orphaned against the output folder.
- Write only what changed and save the config.

**Status:** version 1.0.0. Output verified against dataverse-gen's test fixtures; tested in Power Platform ToolBox against a live environment, with Generate, orphan deletion and the dark theme still to test live ([TESTING.md](tools/dataverse-early-bound-typescript-generator/TESTING.md)).

## Contributing

Contributions are welcome. Please open an issue to discuss a change before submitting a pull request, and keep new tools consistent with the structure of existing ones.

For developer setup and tooling, including the PPTB AI agent skills for Claude Code and GitHub Copilot, see [DEVELOPER.md](DEVELOPER.md).

Have a question, idea, or want to show what you built with a tool from this repo? Use [GitHub Discussions](https://github.com/aidevme/PPTB-Tools/discussions) instead of an issue — issues are for bugs and concrete, actionable feature requests.

If you're using Claude Code, this repo defines custom subagents (architect, developer, tester, code-reviewer, documenter) scoped to the PPTB tool workflow — see [docs/agents/index.md](docs/agents/index.md).

## License

This project is licensed under the [GNU General Public License v2.0](LICENSE).
