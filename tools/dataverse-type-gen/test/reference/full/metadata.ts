/* eslint-disable*/
import { accountMetadata } from "./entities/Account";
import { cdsify_integrationtestMetadata } from "./entities/cdsify_IntegrationTest";
import { opportunitycloseMetadata } from "./entities/OpportunityClose";
import { queueitemMetadata } from "./entities/QueueItem";
import { WinOpportunityMetadata } from "./actions/WinOpportunity";
import { RetrieveMetadataChangesMetadata } from "./functions/RetrieveMetadataChanges";
import { WhoAmIMetadata } from "./functions/WhoAmI";

export const Entities = {
  Account: "account",
  cdsify_IntegrationTest: "cdsify_integrationtest",
  OpportunityClose: "opportunityclose",
  QueueItem: "queueitem",
};

// Setup Metadata
// Usage: setMetadataCache(metadataCache);
export const metadataCache = {
  entities: {
    account: accountMetadata,
    cdsify_integrationtest: cdsify_integrationtestMetadata,
    opportunityclose: opportunitycloseMetadata,
    queueitem: queueitemMetadata,
  },
  actions: {
    WinOpportunity: WinOpportunityMetadata,
    RetrieveMetadataChanges: RetrieveMetadataChangesMetadata,
    WhoAmI: WhoAmIMetadata,
  }
};