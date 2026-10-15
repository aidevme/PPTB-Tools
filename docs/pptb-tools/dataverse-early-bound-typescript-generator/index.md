# Dataverse Early-Bound TypeScript Generator

![Dataverse Early-Bound TypeScript Generator banner—a green database with table cards streams data through a crystal prism, which turns it into floating TypeScript interface and enum panels, on a dark blue background](../../../assets/dataverse-early-bound-typescript-generator-preview.png)

A Power Platform ToolBox (PPTB) tool that generates early-bound TypeScript types and metadata for Dataverse
tables, actions and functions. The generated code works with Scott Durow's
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) library. The tool uses the same
`.dataverse-gen.json` project file as the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI, so
you can switch between the two.

Source: [tools/dataverse-early-bound-typescript-generator](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator)

## Start here

- **Use the tool:** [Getting started](./getting-started/) walks through every step, from loading the tool to using
  the types in your code.
- **Contribute:** [Contributing](./contributing/) covers building, testing and how the code is organized.

## Who it's for

Developers who write TypeScript against Dataverse (form scripts and web resources, PCF controls, React and code
apps, Node scripts) and want typed tables, choices, actions and functions without leaving Power Platform ToolBox.

## Why this tool exists

The dataverse-gen CLI signs in to Dataverse with its companion
[dataverse-auth](https://github.com/scottdurow/dataverse-auth) package. In some tenants that sign-in fails:
[dataverse-auth issue #48](https://github.com/scottdurow/dataverse-auth/issues/48) reports
`Authentication failed: InteractionRequiredAuthError: invalid_grant: AADSTS50076` ("you must use multi-factor
authentication"), without an MFA prompt ever appearing. The same account signs in with MFA everywhere else, other
tenants work with dataverse-auth, and device-code sign-in is blocked in those tenants too. The issue is still
open.

This tool generates the same output without signing in by itself: it uses the Dataverse connection you've
already opened in Power Platform ToolBox, so dataverse-auth isn't involved. If you can connect to an environment
in PPTB, with MFA or any other sign-in method PPTB supports, you can generate types for it. Because the tool
reads and writes the same `.dataverse-gen.json`, a project can keep using the dataverse-gen CLI where its sign-in
works.

## How it differs from the Early Bound Generator

The PPTB marketplace also has the
[Early Bound Generator](https://github.com/mbwilding/PPTB-Tools/tree/main/tools/early-bound-generator)
(`@mbwilding/tool-early-bound-generator`), which generates **C#** early-bound classes for .NET code such as
plug-ins and console apps. This tool generates **TypeScript** instead, for code that runs in the browser or in
Node:

| | This tool | Early Bound Generator |
| --- | --- | --- |
| Language | TypeScript | C# |
| Typical use | Form scripts and web resources, PCF controls, React and code apps, Node scripts | Plug-ins, custom workflow activities, .NET apps |
| Runtime the code is for | [dataverse-ify](https://github.com/scottdurow/dataverse-ify) over the Dataverse Web API | The Dataverse SDK for .NET |
| Output | Table interfaces and attribute constants, `const enum`s for choices, a metadata cache for dataverse-ify, optional typed `Xrm.FormContext` helpers, request types for actions and functions (including private custom APIs) | C# classes for tables, option sets and messages |
| Project file | `.dataverse-gen.json`, shared with the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI | — |

Use this tool for client-side TypeScript, and the Early Bound Generator for server-side .NET code; a solution
with both can use both.

## Credits

Ported from [dataverse-gen](https://github.com/scottdurow/dataverse-gen) 2.0.17 by Scott Durow (MIT). Its licence
and copyright notice are in
[THIRD_PARTY_NOTICES.md](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/THIRD_PARTY_NOTICES.md).
The generated code depends on [dataverse-ify](https://github.com/scottdurow/dataverse-ify), also by Scott Durow
(MIT), which projects install themselves.
