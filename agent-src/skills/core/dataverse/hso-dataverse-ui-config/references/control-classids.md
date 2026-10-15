# Dataverse Form Control ClassIDs Reference

Complete reference of control classids used in Dataverse form XML.

## Overview

The `classid` attribute in form XML identifies the control type used to render a field. Using the correct classid ensures the field displays and behaves correctly.

## How to Use

In form XML, the classid is specified in the `<control>` element:

```xml
<control id="hso_fieldname" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="hso_fieldname" />
```

---

## Standard Field Controls

### Text Controls

| Field Type | ClassID | Use For |
|------------|---------|---------|
| Single Line Text | `{4273EDBD-AC1D-40d3-9FB2-095C621B552D}` | String fields (`_text` suffix) |
| Multi-Line Text | `{E0DECE4B-6FC8-4a8f-A065-082708572369}` | Memo fields (`_memo` suffix) |
| URL | `{71716B6C-711E-476c-8AB8-5D11542BFB47}` | URL fields (clickable link) |
| Email | `{ADA2203E-B4CD-49be-9DDF-234642B43B52}` | Email fields (mailto link) |
| Phone | `{8C10015A-B339-4982-9474-A95FE05631A5}` | Phone fields (tel link) |
| Ticker Symbol | `{1E1FC551-F7A8-43af-AC34-A8DC35C7B6D4}` | Stock ticker lookup |

### Numeric Controls

| Field Type | ClassID | Use For |
|------------|---------|---------|
| Whole Number | `{C6D124CA-7EDA-4a60-AEA9-7FB8D318B68F}` | Integer fields (`_num` suffix) |
| Decimal Number | `{C3EFE0C3-0EC6-42be-8349-CBD9079DFD8E}` | Decimal fields (`_dec` suffix) |
| Currency | `{533B9E00-756B-4312-95A0-DC888637AC78}` | Money fields (`_amt` suffix) |
| Duration | `{AA987274-CFC3-4e3d-94D2-4A7EF200F0A2}` | Duration (minutes) |
| Language | `{B634828E-C390-444A-AFE6-E07315D9D970}` | Language code field |

### Date/Time Controls

| Field Type | ClassID | Use For |
|------------|---------|---------|
| Date Only | `{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}` | Date fields (`_date` suffix, DateOnly format) |
| Date and Time | `{6D0E476D-F753-4be8-B03F-7D3D7D4E6C1E}` | DateTime fields (DateAndTime format) |

### Lookup Controls

| Field Type | ClassID | Use For |
|------------|---------|---------|
| Lookup | `{270BD3DB-D9AF-4782-9025-509E298DEC0A}` | Lookup fields (`_id` suffix) |
| Customer | `{270BD3DB-D9AF-4782-9025-509E298DEC0A}` | Customer type (Account/Contact) |
| Owner | `{270BD3DB-D9AF-4782-9025-509E298DEC0A}` | Owner field |
| Regarding | `{270BD3DB-D9AF-4782-9025-509E298DEC0A}` | Regarding field |
| Party List | `{CBFB742C-14E7-4a17-96BB-1A13F7F64AA2}` | Multiple lookups (activities) |

### Choice Controls

| Field Type | ClassID | Use For |
|------------|---------|---------|
| OptionSet (Choice) | `{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}` | Picklist fields (`_code` suffix) |
| MultiSelect OptionSet | `{4AA28AB7-9C13-4F57-A73D-AD894D048B5F}` | Multi-select choices (`_codes` suffix) |
| Status | `{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}` | Status field |
| Status Reason | `{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}` | Status reason field |

### Boolean Controls

| Field Type | ClassID | Use For |
|------------|---------|---------|
| Two Options (Toggle) | `{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}` | Yes/No toggle (`_yn` suffix) |
| Two Options (Checkbox) | `{B0C6723A-8503-4FD7-BB28-C8A06AC933C2}` | Yes/No checkbox |
| Two Options (Radio) | `{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}` | Yes/No radio buttons |

---

## Special Controls

### Grid and List Controls

| Control Type | ClassID | Use For |
|--------------|---------|---------|
| Subgrid | `{E7A81278-8635-4d9e-8D4D-59480B391C5B}` | Related records grid |
| Editable Grid | `{E7A81278-8635-4d9e-8D4D-59480B391C5B}` | Inline editing grid |
| Quick View Form | `{5C5600E0-1D6E-4205-A272-BE80DA87FD42}` | Embedded quick view |

### Timeline and Activity Controls

| Control Type | ClassID | Use For |
|--------------|---------|---------|
| Notes/Timeline | `{06375649-c143-495e-a496-c962e5b4488e}` | Activities timeline |
| Action Cards | `{F9A8A302-114E-466A-B582-6771B2AE0D92}` | Action cards panel |

### Embedded Content Controls

| Control Type | ClassID | Use For |
|--------------|---------|---------|
| Web Resource | `{9FDF5F91-88B1-47f4-AD53-C11EFC01A01D}` | HTML/JS web resources |
| IFRAME | `{FD2A7985-3187-444e-908D-6624B21F69C0}` | External page iframe |
| Knowledge Base Search | `{756B513A-6D54-4361-AD1B-AF9B93CFAD1C}` | KB article search |

### Map and Address Controls

| Control Type | ClassID | Use For |
|--------------|---------|---------|
| Map | `{62B0DF79-0464-470F-8AF7-4483CFEA0C7D}` | Bing Maps control |
| Address Composite | `{E0DECE4B-6FC8-4a8f-A065-082708572369}` | Address composite |

### Utility Controls

| Control Type | ClassID | Use For |
|--------------|---------|---------|
| Spacer | `{00AD73DA-BD4D-49C6-88A8-2F4F4CAD4A20}` | Empty space |
| Hidden Data | `{5546E6CD-394C-4bee-94A8-4425E17EF6C6}` | Hidden field value |
| Timer | `{9C5CA0A1-AB4D-4781-BE7E-8DFBE867B87E}` | Timer control |

---

## Modern Controls (Unified Interface)

These controls are available in Unified Interface apps:

| Control Type | ClassID | Description |
|--------------|---------|-------------|
| PCF Control | `{3D8FABC4-2F6D-4D17-93DD-0F3B0AB4D5E0}` | Custom PCF controls |
| Rich Text Editor | `{E0DECE4B-6FC8-4a8f-A065-082708572369}` | With RTE parameters |
| Star Rating | Use PCF | Custom rating control |
| Toggle | Use PCF | Modern toggle switch |

---

## Usage Examples

### Standard Text Field

```xml
<cell id="{guid}">
  <labels>
    <label description="Contract Number" languagecode="1033" />
  </labels>
  <control id="hso_contractnumber_text" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
           datafieldname="hso_contractnumber_text" />
</cell>
```

### Lookup Field

```xml
<cell id="{guid}">
  <labels>
    <label description="Provider" languagecode="1033" />
  </labels>
  <control id="hso_account_id" classid="{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
           datafieldname="hso_account_id" />
</cell>
```

### Currency Field

```xml
<cell id="{guid}">
  <labels>
    <label description="Total Amount" languagecode="1033" />
  </labels>
  <control id="hso_totalamount_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
           datafieldname="hso_totalamount_amt" />
</cell>
```

### Yes/No Toggle

```xml
<cell id="{guid}">
  <labels>
    <label description="Is Active" languagecode="1033" />
  </labels>
  <control id="hso_isactive_yn" classid="{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}"
           datafieldname="hso_isactive_yn" />
</cell>
```

### Subgrid

```xml
<cell id="{guid}" rowspan="10">
  <labels>
    <label description="Amendments" languagecode="1033" />
  </labels>
  <control id="subgrid_amendments" classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}">
    <parameters>
      <TargetEntityType>hso_amendment</TargetEntityType>
      <ViewId>{view-guid}</ViewId>
      <ViewIds>{view-guid}</ViewIds>
      <RelationshipName>hso_contract_amendment</RelationshipName>
      <EnableQuickFind>true</EnableQuickFind>
      <EnableViewPicker>true</EnableViewPicker>
      <RecordsPerPage>10</RecordsPerPage>
    </parameters>
  </control>
</cell>
```

---

## Field Type to ClassID Quick Reference

Based on naming conventions used in this project:

| Field Name Suffix | ClassID | Control Type |
|-------------------|---------|--------------|
| `_text` | `{4273EDBD-AC1D-40d3-9FB2-095C621B552D}` | Single Line Text |
| `_memo` | `{E0DECE4B-6FC8-4a8f-A065-082708572369}` | Multi-Line Text |
| `_num` | `{C6D124CA-7EDA-4a60-AEA9-7FB8D318B68F}` | Whole Number |
| `_dec` | `{C3EFE0C3-0EC6-42be-8349-CBD9079DFD8E}` | Decimal |
| `_amt` | `{533B9E00-756B-4312-95A0-DC888637AC78}` | Currency |
| `_yn` | `{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}` | Two Options |
| `_date` | `{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}` | Date Only |
| `_code` | `{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}` | OptionSet |
| `_codes` | `{4AA28AB7-9C13-4F57-A73D-AD894D048B5F}` | MultiSelect |
| `_id` | `{270BD3DB-D9AF-4782-9025-509E298DEC0A}` | Lookup |

---

## Sources

- Extracted from existing Dataverse forms
- Microsoft Power Apps documentation
- Community resources and blogs
