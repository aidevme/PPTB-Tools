# Using the generated code

<!-- cspell:ignore dataverse-ify -->

The generated code is built for Scott Durow's [dataverse-ify](https://github.com/scottdurow/dataverse-ify)
library, which projects install themselves. This page shows how to wire the output into your project. For what
each generated file contains, see [What gets generated](./what-gets-generated.md).

## Install dataverse-ify

In your TypeScript project (the folder you opened in the tool):

```bash
npm install dataverse-ify
```

## Register the metadata

The Dataverse Web API sends integers, decimals, money and choices all as plain numbers, so dataverse-ify needs
the generated metadata at runtime. Register it once, before you make any calls:

```ts
import { setMetadataCache } from "dataverse-ify";
import { metadataCache } from "./dataverse-gen";

setMetadataCache(metadataCache);
```

`metadataCache` comes from the generated `metadata.ts`. To register only some tables and operations, and for
what the metadata looks like, see [Why generate metadata?](./why-generate-metadata.md).

## Call Dataverse with the generated types

```ts
import { setMetadataCache, XrmContextDataverseClient } from "dataverse-ify";
import { metadataCache, Account, accountMetadata } from "./dataverse-gen";

setMetadataCache(metadataCache);
const client = new XrmContextDataverseClient(Xrm.WebApi);
const account = await client.retrieve<Account>(accountMetadata.logicalName, id, ["name"]);
```

The import path assumes the default output folder (`./src/dataverse-gen`) and the `index.ts` barrel file. With
the barrel turned off, import from the individual files instead, for example `./dataverse-gen/entities/Account`.

## Form-context helpers

With **Form context helpers** turned on in the Options card, each table's file also contains a typed
`FormContext`, so form scripts get typed controls and attributes:

```ts
import { AccountFormContext } from "./dataverse-gen";

export function onLoad(context: Xrm.Events.EventContext) {
    const form = context.getFormContext() as AccountFormContext;
    form.getAttribute("name"); // typed as Xrm.Attributes.StringAttribute
}
```

The option is off by default. Attributes with no known Xrm type are left out of the form context rather than
typed as `Xrm.Attributes.undefinedAttribute`, which wouldn't compile (see
[Moving from dataverse-gen](./moving-from-dataverse-gen.md)).

## Keeping the types current

When tables change in Dataverse, open the project, click **Preview** to see what changed, then **Generate**.
Commit the generated files with the rest of your project.
