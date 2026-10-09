/* eslint-disable*/

// Entity QueueItem FormContext
export interface QueueItemFormContext extends Xrm.FormContext {
    getAttribute(): Xrm.Attributes.Attribute[];
    getAttribute<T extends Xrm.Attributes.Attribute>(attributeName: string): T;
    getAttribute(attributeName: string): Xrm.Attributes.Attribute;
    getAttribute(index: number): Xrm.Attributes.Attribute;

    getControl(): Xrm.Controls.Control[];
    getControl<T extends Xrm.Controls.Control>(controlName: string): T;
    getControl(controlName: string): Xrm.Controls.Control;
    getControl(index: number): Xrm.Controls.Control;

    /*
    Shows the date and time when the record was created. The date and time are displayed in the time zone selected in Microsoft Dynamics 365 options.
    */
    getAttribute(name: 'createdon'): Xrm.Attributes.DateAttribute;
    /*
    Shows the date and time when the record was created. The date and time are displayed in the time zone selected in Microsoft Dynamics 365 options.
    */
    getControl(name: 'createdon'): Xrm.Controls.DateControl;
    /*
    Shows the date the record was assigned to the queue.
    */
    getAttribute(name: 'enteredon'): Xrm.Attributes.DateAttribute;
    /*
    Shows the date the record was assigned to the queue.
    */
    getControl(name: 'enteredon'): Xrm.Controls.DateControl;
    /*
    Shows the conversion rate of the record's currency. The exchange rate is used to convert all money fields in the record from the local currency to the system's default currency.
    */
    getAttribute(name: 'exchangerate'): Xrm.Attributes.NumberAttribute;
    /*
    Shows the conversion rate of the record's currency. The exchange rate is used to convert all money fields in the record from the local currency to the system's default currency.
    */
    getControl(name: 'exchangerate'): Xrm.Controls.NumberControl;
    /*
    Unique identifier of the data import or data migration that created this record.
    */
    getAttribute(name: 'importsequencenumber'): Xrm.Attributes.NumberAttribute;
    /*
    Unique identifier of the data import or data migration that created this record.
    */
    getControl(name: 'importsequencenumber'): Xrm.Controls.NumberControl;
    /*
    Shows the date and time when the record was last updated. The date and time are displayed in the time zone selected in Microsoft Dynamics 365 options.
    */
    getAttribute(name: 'modifiedon'): Xrm.Attributes.DateAttribute;
    /*
    Shows the date and time when the record was last updated. The date and time are displayed in the time zone selected in Microsoft Dynamics 365 options.
    */
    getControl(name: 'modifiedon'): Xrm.Controls.DateControl;
    /*
    This attribute is used by Unified Routing system to decide whether to Skip Sync Call to Omnichannel Service or not.
    */
    getAttribute(name: 'msdyn_skipursync'): Xrm.Attributes.BooleanAttribute;
    /*
    This attribute is used by Unified Routing system to decide whether to Skip Sync Call to Omnichannel Service or not.
    */
    getControl(name: 'msdyn_skipursync'): Xrm.Controls.OptionSetControl;
    /*
    Select the type of the queue item, such as activity, case, or appointment.
    */
    getAttribute(name: 'objecttypecode'): Xrm.Attributes.OptionSetAttribute;
    /*
    Select the type of the queue item, such as activity, case, or appointment.
    */
    getControl(name: 'objecttypecode'): Xrm.Controls.OptionSetControl;
    /*
    Date and time that the record was migrated.
    */
    getAttribute(name: 'overriddencreatedon'): Xrm.Attributes.DateAttribute;
    /*
    Date and time that the record was migrated.
    */
    getControl(name: 'overriddencreatedon'): Xrm.Controls.DateControl;
    /*
    Priority of the queue item.
    */
    getAttribute(name: 'priority'): Xrm.Attributes.NumberAttribute;
    /*
    Priority of the queue item.
    */
    getControl(name: 'priority'): Xrm.Controls.NumberControl;
    /*
    Sender who created the queue item.
    */
    getAttribute(name: 'sender'): Xrm.Attributes.StringAttribute;
    /*
    Sender who created the queue item.
    */
    getControl(name: 'sender'): Xrm.Controls.StringControl;
    /*
    Status of the queue item.
    */
    getAttribute(name: 'state'): Xrm.Attributes.NumberAttribute;
    /*
    Status of the queue item.
    */
    getControl(name: 'state'): Xrm.Controls.NumberControl;
    /*
    Reason for the status of the queue item.
    */
    getAttribute(name: 'status'): Xrm.Attributes.NumberAttribute;
    /*
    Reason for the status of the queue item.
    */
    getControl(name: 'status'): Xrm.Controls.NumberControl;
    /*
    For internal use only.
    */
    getAttribute(name: 'timezoneruleversionnumber'): Xrm.Attributes.NumberAttribute;
    /*
    For internal use only.
    */
    getControl(name: 'timezoneruleversionnumber'): Xrm.Controls.NumberControl;
    /*
    Shows the title or name that describes the queue record. This value is copied from the record that was assigned to the queue.
    */
    getAttribute(name: 'title'): Xrm.Attributes.StringAttribute;
    /*
    Shows the title or name that describes the queue record. This value is copied from the record that was assigned to the queue.
    */
    getControl(name: 'title'): Xrm.Controls.StringControl;
    /*
    Recipients listed on the To line of the message for email queue items.
    */
    getAttribute(name: 'torecipients'): Xrm.Attributes.StringAttribute;
    /*
    Recipients listed on the To line of the message for email queue items.
    */
    getControl(name: 'torecipients'): Xrm.Controls.StringControl;
    /*
    Time zone code that was in use when the record was created.
    */
    getAttribute(name: 'utcconversiontimezonecode'): Xrm.Attributes.NumberAttribute;
    /*
    Time zone code that was in use when the record was created.
    */
    getControl(name: 'utcconversiontimezonecode'): Xrm.Controls.NumberControl;
    /*
    Shows the date and time when the queue item was last assigned to a user.
    */
    getAttribute(name: 'workeridmodifiedon'): Xrm.Attributes.DateAttribute;
    /*
    Shows the date and time when the queue item was last assigned to a user.
    */
    getControl(name: 'workeridmodifiedon'): Xrm.Controls.DateControl;
}
// Entity QueueItem
export const queueitemMetadata = {
  typeName: "mscrm.queueitem",
  logicalName: "queueitem",
  collectionName: "queueitems",
  primaryIdAttribute: "queueitemid",
  attributeTypes: {
    // Numeric Types
    exchangerate: "Decimal",
    importsequencenumber: "Integer",
    priority: "Integer",
    state: "Integer",
    status: "Integer",
    timezoneruleversionnumber: "Integer",
    utcconversiontimezonecode: "Integer",
    versionnumber: "BigInt",
    // Optionsets
    objecttypecode: "Optionset",
    statecode: "Optionset",
    statuscode: "Optionset",
    // Date Formats
    createdon: "DateAndTime:UserLocal",
    enteredon: "DateAndTime:UserLocal",
    modifiedon: "DateAndTime:UserLocal",
    overriddencreatedon: "DateOnly:UserLocal",
    workeridmodifiedon: "DateOnly:UserLocal",
  },
  navigation: {
    createdby: ["mscrm.systemuser"],
    createdonbehalfby: ["mscrm.systemuser"],
    modifiedby: ["mscrm.systemuser"],
    modifiedonbehalfby: ["mscrm.systemuser"],
    msdyn_liveworkstreamid: ["mscrm.msdyn_liveworkstream"],
    organizationid: ["mscrm.organization"],
    queueid: ["mscrm.queue"],
    transactioncurrencyid: ["mscrm.transactioncurrency"],
    objectid: ["activitypointer","adx_inviteredemption","adx_portalcomment","appointment","bulkoperation","campaignactivity","campaignresponse","chat","email","fax","incident","knowledgearticle","letter","msdyn_copilottranscript","msdyn_iotalert","msdyn_knowledgearticletemplate","msdyn_liveconversation","msdyn_ocliveworkitem","msdyn_ocsession","msdyn_overflowactionconfig","msfp_alert","msfp_surveyinvite","msfp_surveyresponse","phonecall","recurringappointmentmaster","serviceappointment","socialactivity","task"],
    workerid: ["systemuser","team"],
  },
};

// Attribute constants
export const enum QueueItemAttributes {
  CreatedBy = "createdby",
  CreatedByName = "createdbyname",
  CreatedByYomiName = "createdbyyominame",
  CreatedOn = "createdon",
  CreatedOnBehalfBy = "createdonbehalfby",
  CreatedOnBehalfByName = "createdonbehalfbyname",
  CreatedOnBehalfByYomiName = "createdonbehalfbyyominame",
  EnteredOn = "enteredon",
  ExchangeRate = "exchangerate",
  ImportSequenceNumber = "importsequencenumber",
  ModifiedBy = "modifiedby",
  ModifiedByName = "modifiedbyname",
  ModifiedByYomiName = "modifiedbyyominame",
  ModifiedOn = "modifiedon",
  ModifiedOnBehalfBy = "modifiedonbehalfby",
  ModifiedOnBehalfByName = "modifiedonbehalfbyname",
  ModifiedOnBehalfByYomiName = "modifiedonbehalfbyyominame",
  msdyn_liveworkstreamid = "msdyn_liveworkstreamid",
  msdyn_liveworkstreamidName = "msdyn_liveworkstreamidname",
  msdyn_skipursync = "msdyn_skipursync",
  ObjectId = "objectid",
  ObjectIdName = "objectidname",
  ObjectIdTypeCode = "objectidtypecode",
  ObjectTypeCode = "objecttypecode",
  OrganizationId = "organizationid",
  OrganizationIdName = "organizationidname",
  OverriddenCreatedOn = "overriddencreatedon",
  OwnerId = "ownerid",
  OwnerIdType = "owneridtype",
  OwningBusinessUnit = "owningbusinessunit",
  OwningUser = "owninguser",
  Priority = "priority",
  QueueId = "queueid",
  QueueIdName = "queueidname",
  QueueItemId = "queueitemid",
  Sender = "sender",
  State = "state",
  StateCode = "statecode",
  Status = "status",
  StatusCode = "statuscode",
  TimeZoneRuleVersionNumber = "timezoneruleversionnumber",
  Title = "title",
  ToRecipients = "torecipients",
  TransactionCurrencyId = "transactioncurrencyid",
  TransactionCurrencyIdName = "transactioncurrencyidname",
  UTCConversionTimeZoneCode = "utcconversiontimezonecode",
  VersionNumber = "versionnumber",
  WorkerId = "workerid",
  WorkerIdModifiedOn = "workeridmodifiedon",
  WorkerIdName = "workeridname",
  WorkerIdType = "workeridtype",
  WorkerIdYomiName = "workeridyominame",
}
