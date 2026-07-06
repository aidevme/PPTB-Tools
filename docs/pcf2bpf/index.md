# Power Platform ToolBox (PPTB) Tools - PCF2BPF

PCF2BPF lets you add, edit, or remove PCF (PowerApps Component Framework) controls on the fields of a
Business Process Flow (BPF), per form factor (Web, Phone, Tablet), without hand-editing form XML.

It is a port of [Carfup's XTBPlugins.PCF2BPF](https://github.com/carfup/XTBPlugins.PCF2BPF) XrmToolBox
plugin to Power Platform ToolBox. Source lives at [tools/pcf2bpf](../../tools/pcf2bpf/).

## Requirements

- A connection to a Dataverse environment in PPTB, with privileges to read/update system forms and
  customizations.
- The PCF controls you want to assign must already be registered in the environment (imported as part of a
  solution).

## How to use

1. Open the PCF2BPF tool and confirm the connection status shown at the top.
2. Click **Load BPFs** to fetch the active Business Process Flows and the registered PCF controls in the
   environment.
3. Select a Business Process Flow from the dropdown — its stages load automatically.
4. Choose **Web**, **Phone**, or **Tablet** to configure that form factor. Assignments are independent per
   form factor.
5. Expand a stage and click a field. Fields that already have a PCF control assigned for the selected form
   factor show a **PCF** badge.
6. Pick a compatible PCF control from the dropdown (only controls whose manifest supports the field's data
   type are listed) and fill in any configurable parameters.
7. Click **Add Control** (or **Update Control** / **Remove Control** for an existing assignment). The form
   XML preview at the bottom updates immediately.
8. Click **Save** to persist the change, or **Save & Publish** to also publish the BPF's customizations so
   the change takes effect immediately.

## Known limitations

- Copying a configuration from one form factor to another is not implemented — configure each form factor
  separately.
- Parameters can only be set to static values; binding a parameter to another field is not supported.
- Manifest `display-name-key` values are shown as-is rather than resolved through localization resources.

See the [tool's README](../../tools/pcf2bpf/README.md) for implementation details (data model, form XML
structure, build instructions).
