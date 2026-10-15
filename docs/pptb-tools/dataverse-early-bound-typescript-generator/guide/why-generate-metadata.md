# Why generate metadata?

<!-- cspell:ignore Optionset exchangerate odataify opportunityclose queueid queueitemid queueitems sdkify systemuser transactioncurrency transactioncurrencyid workerid workeridmodifiedon -->

Unlike the old SOAP endpoint, the Dataverse Web API doesn't carry enough information to work out the metadata of
requests and responses from the values alone. For example, Integer, Float, Money, Decimal and Choice (option set)
values are all transmitted as plain numbers. Many navigation properties also depend on knowing the structure of
the metadata in advance.

For this reason, [dataverse-ify](https://github.com/scottdurow/dataverse-ify) expects some metadata to be
available when you use `odataify` and `sdkify`. This tool writes that metadata when it generates the types, just
like the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI (see
[Getting started](../getting-started/)).

## Using the metadata

To use all of the generated metadata:

```ts
setMetadataCache(metadataCache);
```

To use only a subset:

```ts
setMetadataCache({
  entities: {
    opportunity: opportunityMetadata,
    opportunityclose: opportunitycloseMetadata,
  },
  actions: { WinOpportunity: WinOpportunityMetadata },
});
```

The metadata objects are constants defined in the generated files under `entities/`, `actions/` and
`functions/`. `metadataCache` comes from the generated `metadata.ts`.

## What the metadata looks like

You could also populate the metadata yourself, or even load it from the server at runtime. It takes this form:

```ts
export const queueitemMetadata = {
  typeName: "mscrm.queueitem",
  logicalName: "queueitem",
  collectionName: "queueitems",
  primaryIdAttribute: "queueitemid",
  attributeTypes: {
    // Numeric types, so values are converted to the right kind of number
    exchangerate: "Decimal",
    status: "Integer",
    // ...
    // Choices (option sets)
    statecode: "Optionset",
    // ...
    // Date formats
    workeridmodifiedon: "DateOnly:UserLocal",
    // ...
  },
  // Navigation: which entity logical names are valid for each relationship
  navigation: {
    transactioncurrencyid: ["mscrm.transactioncurrency"],
    queueid: ["mscrm.queue"],
    workerid: ["systemuser", "team"],
    // ...
  },
};
```

---

Adapted from the [dataverse-ify README](https://github.com/scottdurow/dataverse-ify) by Scott Durow (MIT).
