/* eslint-disable*/
import { queueitemMetadata } from "./entities/QueueItem";

export const Entities = {
  QueueItem: "queueitem",
};

// Setup Metadata
// Usage: setMetadataCache(metadataCache);
export const metadataCache = {
  entities: {
    queueitem: queueitemMetadata,
  },
  actions: {
  }
};