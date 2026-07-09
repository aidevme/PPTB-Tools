# Power Platform ToolBox (PPTB) Tools

[![License](https://img.shields.io/github/license/aidevme/PPTB-Tools)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/aidevme/PPTB-Tools)](https://github.com/aidevme/PPTB-Tools/commits/main)
[![Open issues](https://img.shields.io/github/issues/aidevme/PPTB-Tools)](https://github.com/aidevme/PPTB-Tools/issues)
[![CodeQL](https://github.com/aidevme/PPTB-Tools/actions/workflows/codeql.yml/badge.svg)](https://github.com/aidevme/PPTB-Tools/actions/workflows/codeql.yml)
[![CodeQL last run](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/aidevme/PPTB-Tools/main/.github/badges/codeql-last-run.json)](https://github.com/aidevme/PPTB-Tools/actions/workflows/codeql.yml)

Tools for Power Platform ToolBox (PPTB) - a comprehensive toolkit for working with Microsoft Dataverse and Power Platform.

- [Power Platform ToolBox (PPTB) Tools](#power-platform-toolbox-pptb-tools)
    - [Overview](#overview)
    - [Tools](#tools)
        - [PCF2BPF](#pcf2bpf)
    - [Contributing](#contributing)
    - [License](#license)

## Overview

This repository hosts individual tools that plug into Power Platform ToolBox (PPTB), following the same model as [XrmToolBox](https://www.xrmtoolbox.com/) plugins: each tool is a self-contained add-in that helps administrators, consultants, and developers work more efficiently with Microsoft Dataverse and the Power Platform.

## Tools

### PCF2BPF

PCF2BPF lets you manage PCF (PowerApps Component Framework) controls on the fields of a Business Process Flow (BPF), without hand-editing form XML.

This is a port of [Carfup's XTBPlugins.PCF2BPF](https://github.com/carfup/XTBPlugins.PCF2BPF) XrmToolBox plugin to PPTB, reusing its concept and workflow while adapting the implementation to PPTB's tool architecture. Source: [tools/pcf2bpf](tools/pcf2bpf/) · Docs: [docs/pcf2bpf](docs/pcf2bpf/index.md).

Implemented functionality (based on the original plugin):

- Load all Business Process Flow entities from the connected environment and browse their stages and fields.
- Select a field on a stage and see which PCF controls are compatible with its data type.
- Add, edit, or remove a PCF control on a field, per form factor (Web, Phone, Tablet).
- Configure a PCF control's parameters through a generated input panel.
- Preview the modified form XML before committing changes.
- Save the Business Process Flow form, or save and publish it directly from the tool.

Not yet implemented: copying a PCF configuration from one form factor to another, and binding a parameter to another field (see the [tool's README](tools/pcf2bpf/README.md#not-implemented-compared-to-the-original-xrmtoolbox-plugin) for the full list).

**Status:** initial implementation available; not yet validated against a live environment.

## Contributing

Contributions are welcome. Please open an issue to discuss a change before submitting a pull request, and keep new tools consistent with the structure of existing ones.

If you're using Claude Code, this repo defines custom subagents (architect, developer, tester, code-reviewer, documenter) scoped to the PPTB tool workflow — see [docs/agents/index.md](docs/agents/index.md).

## License

This project is licensed under the [GNU General Public License v2.0](LICENSE).