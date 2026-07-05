# Power Platform ToolBox (PPTB) Tools

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

This is a planned port of [Carfup's XTBPlugins.PCF2BPF](https://github.com/carfup/XTBPlugins.PCF2BPF) XrmToolBox plugin to PPTB, reusing its concept and workflow while adapting the implementation to PPTB's tool architecture.

Planned functionality (based on the original plugin):

- Load all Business Process Flow entities from the connected environment and browse their stages and fields.
- Select a field on a stage and see which PCF controls are compatible with its data type.
- Add, edit, or remove a PCF control on a field, per form factor (Web, Mobile, Tablet).
- Configure a PCF control's parameters through a generated input panel.
- Copy a PCF control's configuration from one form factor to another (e.g. Web → Mobile).
- Preview the original and modified form XML before committing changes.
- Update and publish the Business Process Flow form directly from the tool.

**Status:** planned / not yet implemented.

## Contributing

Contributions are welcome. Please open an issue to discuss a change before submitting a pull request, and keep new tools consistent with the structure of existing ones.

## License

This project is licensed under the [MIT License](LICENSE).