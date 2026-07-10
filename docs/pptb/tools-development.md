# Tool Development

## Overview

Tools are web applications that run in isolated environments and communicate with the PPTB host through
secure APIs. Key characteristics:

- **Sandboxed iframe execution** with restricted API access.
- **Namespaced APIs** for connections, utilities, terminals, events, and Dataverse.
- **Structured message protocol** (`postMessage`) for host communication.
- **Context-awareness** — automatic tool ID and connection context management.
- **TypeScript support** — full compatibility via the `@pptb/types` package.

> If porting an existing XrmToolBox plugin, respectfully contact the original tool author before cloning
> their work. See the PPTB Discord server for discussion and community support.

Source: [docs.powerplatformtoolbox.com/tool-development](https://docs.powerplatformtoolbox.com/tool-development)

## Package Manifest

## API Reference

## ToolBox API

## Dataverse API

## PowerPlatform API

## Events API

## Settings API

## File System API

## Error Handling

## CSP Configuration

## Local Validation

## Inter-Tool Invocation

## Agent Integration

## Publishing Tools
