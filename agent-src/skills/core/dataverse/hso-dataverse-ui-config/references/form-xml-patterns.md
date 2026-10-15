# Dataverse Form XML Patterns Reference

Common patterns and examples for building Dataverse form XML.

## Complete Form Structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<forms xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <systemform>
    <formid>{form-guid}</formid>
    <IntroducedVersion>1.0.0.0</IntroducedVersion>
    <FormPresentation>1</FormPresentation>
    <FormActivationState>1</FormActivationState>
    <form showImage="true">
      <tabs>
        <!-- Tabs go here -->
      </tabs>
      <header id="{header-guid}">
        <!-- Header fields -->
      </header>
      <footer id="{footer-guid}">
        <!-- Footer fields -->
      </footer>
    </form>
    <CanBeDeleted>1</CanBeDeleted>
    <LocalizedNames>
      <LocalizedName description="Form Name" languagecode="1033" />
    </LocalizedNames>
    <Descriptions>
      <Description description="Form description" languagecode="1033" />
    </Descriptions>
  </systemform>
</forms>
```

---

## Tab Patterns

### Single Column Tab

```xml
<tab name="tab_general" id="{guid}" showlabel="true" expanded="true">
  <labels>
    <label description="General" languagecode="1033" />
  </labels>
  <columns>
    <column width="100%">
      <sections>
        <!-- Sections go here -->
      </sections>
    </column>
  </columns>
</tab>
```

### Two Column Tab

```xml
<tab name="tab_details" id="{guid}" showlabel="true" expanded="true">
  <labels>
    <label description="Details" languagecode="1033" />
  </labels>
  <columns>
    <column width="50%">
      <sections>
        <!-- Left column sections -->
      </sections>
    </column>
    <column width="50%">
      <sections>
        <!-- Right column sections -->
      </sections>
    </column>
  </columns>
</tab>
```

### Three Column Tab

```xml
<tab name="tab_overview" id="{guid}" showlabel="true">
  <labels>
    <label description="Overview" languagecode="1033" />
  </labels>
  <columns>
    <column width="33%">
      <sections>
        <!-- Column 1 -->
      </sections>
    </column>
    <column width="34%">
      <sections>
        <!-- Column 2 -->
      </sections>
    </column>
    <column width="33%">
      <sections>
        <!-- Column 3 -->
      </sections>
    </column>
  </columns>
</tab>
```

### Tab Without Label (Header-style)

```xml
<tab name="tab_header" id="{guid}" showlabel="false" expanded="true">
  <labels>
    <label description="Header" languagecode="1033" />
  </labels>
  <columns>
    <column width="100%">
      <sections>
        <!-- Header section -->
      </sections>
    </column>
  </columns>
</tab>
```

---

## Section Patterns

> **Naming rules**: Schema name = `{tab_name}_section_{descriptor}` (all lowercase snake_case). Label = Title Case.
> See [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) → **Form Element Schema Names**.

### Standard Two-Column Section

```xml
<section name="tab_general_section_info" id="{guid}" columns="2" showlabel="true" labelwidth="115">
  <labels>
    <label description="Information" languagecode="1033" />
  </labels>
  <rows>
    <row>
      <cell id="{guid}">
        <labels><label description="Field 1" languagecode="1033" /></labels>
        <control id="field1" classid="{classid}" datafieldname="field1" />
      </cell>
      <cell id="{guid}">
        <labels><label description="Field 2" languagecode="1033" /></labels>
        <control id="field2" classid="{classid}" datafieldname="field2" />
      </cell>
    </row>
  </rows>
</section>
```

### Single Column Section

```xml
<section name="tab_general_section_notes" id="{guid}" columns="1" showlabel="true">
  <labels>
    <label description="Notes" languagecode="1033" />
  </labels>
  <rows>
    <row>
      <cell id="{guid}">
        <labels><label description="Description" languagecode="1033" /></labels>
        <control id="description" classid="{E0DECE4B-6FC8-4a8f-A065-082708572369}" datafieldname="description" />
      </cell>
    </row>
  </rows>
</section>
```

### Section Without Label

```xml
<section name="tab_general_section_hidden" id="{guid}" columns="2" showlabel="false">
  <labels>
    <label description="" languagecode="1033" />
  </labels>
  <rows>
    <!-- rows -->
  </rows>
</section>
```

### Section With Custom Label Width

```xml
<section name="tab_general_section_wide" id="{guid}" columns="2" showlabel="true" labelwidth="200">
  <labels>
    <label description="Long Labels Section" languagecode="1033" />
  </labels>
  <rows>
    <!-- rows -->
  </rows>
</section>
```

---

## Field Cell Patterns

### Standard Field

```xml
<cell id="{guid}">
  <labels>
    <label description="Field Label" languagecode="1033" />
  </labels>
  <control id="hso_fieldname" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
           datafieldname="hso_fieldname" />
</cell>
```

### Full-Width Field (Colspan)

```xml
<row>
  <cell id="{guid}" colspan="2">
    <labels>
      <label description="Description" languagecode="1033" />
    </labels>
    <control id="hso_description_memo" classid="{E0DECE4B-6FC8-4a8f-A065-082708572369}"
             datafieldname="hso_description_memo" />
  </cell>
</row>
```

### Read-Only Field

```xml
<cell id="{guid}">
  <labels>
    <label description="Contract Number" languagecode="1033" />
  </labels>
  <control id="hso_contractnumber_text" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
           datafieldname="hso_contractnumber_text" disabled="true" />
</cell>
```

### Hidden Field

```xml
<cell id="{guid}" visible="false">
  <labels>
    <label description="Hidden Field" languagecode="1033" />
  </labels>
  <control id="hso_hiddenfield" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
           datafieldname="hso_hiddenfield" />
</cell>
```

### Field Without Label

```xml
<cell id="{guid}" showlabel="false">
  <labels>
    <label description="" languagecode="1033" />
  </labels>
  <control id="hso_fieldname" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
           datafieldname="hso_fieldname" />
</cell>
```

### Field With Row Height (for multi-line)

```xml
<cell id="{guid}" rowspan="4">
  <labels>
    <label description="Program Description" languagecode="1033" />
  </labels>
  <control id="hso_programdesc_memo" classid="{E0DECE4B-6FC8-4a8f-A065-082708572369}"
           datafieldname="hso_programdesc_memo" />
</cell>
```

> **Important:** Do not include `locklevel` on a cell that sets `rowspan`. Dataverse normalizes
> formxml on write and silently strips `rowspan` from any cell that also carries `locklevel`
> (HTTP 204 is returned -- no error). The `locklevel="0"` emitted by most tooling is the
> trigger. Omit `locklevel` (and optionally `showlabel`) whenever `rowspan` is set.
>
> ```xml
> <!-- BROKEN -- rowspan silently stripped on save: -->
> <cell id="{guid}" showlabel="true" locklevel="0" rowspan="4">
>   ...
> </cell>
> ```

---

## Subgrid Patterns

### Basic Subgrid

```xml
<cell id="{guid}" rowspan="10">
  <labels>
    <label description="Related Records" languagecode="1033" />
  </labels>
  <control id="subgrid_related" classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}">
    <parameters>
      <TargetEntityType>hso_childtable</TargetEntityType>
      <ViewId>{view-guid}</ViewId>
      <ViewIds>{view-guid}</ViewIds>
      <RelationshipName>hso_parent_child</RelationshipName>
    </parameters>
  </control>
</cell>
```

### Subgrid With All Options

```xml
<cell id="{guid}" rowspan="15" colspan="2">
  <labels>
    <label description="Amendments" languagecode="1033" />
  </labels>
  <control id="subgrid_amendments" classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}">
    <parameters>
      <TargetEntityType>hso_amendment</TargetEntityType>
      <ViewId>{default-view-guid}</ViewId>
      <ViewIds>{view1-guid},{view2-guid}</ViewIds>
      <RelationshipName>hso_contract_amendment</RelationshipName>
      <EnableQuickFind>true</EnableQuickFind>
      <EnableViewPicker>true</EnableViewPicker>
      <EnableChartPicker>false</EnableChartPicker>
      <EnableJumpBar>false</EnableJumpBar>
      <RecordsPerPage>10</RecordsPerPage>
      <AutoExpand>true</AutoExpand>
    </parameters>
  </control>
</cell>
```

### Subgrid With Specific Columns (Override View)

```xml
<cell id="{guid}" rowspan="8">
  <labels>
    <label description="Rates" languagecode="1033" />
  </labels>
  <control id="subgrid_rates" classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}">
    <parameters>
      <TargetEntityType>hso_contractrate</TargetEntityType>
      <ViewId>{view-guid}</ViewId>
      <RelationshipName>hso_contract_rate</RelationshipName>
      <EnableContextualActions>true</EnableContextualActions>
    </parameters>
  </control>
</cell>
```

---

## Quick View Form Pattern

```xml
<cell id="{guid}" rowspan="4" colspan="1">
  <labels>
    <label description="Provider Details" languagecode="1033" />
  </labels>
  <control id="quickview_provider" classid="{5C5600E0-1D6E-4205-A272-BE80DA87FD42}">
    <parameters>
      <QuickForms>{quickform-id}</QuickForms>
      <TargetEntityType>account</TargetEntityType>
      <RelationshipName>hso_account_id</RelationshipName>
    </parameters>
  </control>
</cell>
```

---

## Header Section Pattern

```xml
<header id="{guid}">
  <rows>
    <row>
      <cell id="{guid}">
        <labels>
          <label description="Status" languagecode="1033" />
        </labels>
        <control id="hso_status_code" classid="{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
                 datafieldname="hso_status_code" />
      </cell>
      <cell id="{guid}">
        <labels>
          <label description="Owner" languagecode="1033" />
        </labels>
        <control id="ownerid" classid="{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
                 datafieldname="ownerid" />
      </cell>
    </row>
  </rows>
</header>
```

---

## Timeline Control Pattern

```xml
<section name="{tab_name}_section_timeline" id="{guid}" columns="1" showlabel="false">
  <labels>
    <label description="Timeline" languagecode="1033" />
  </labels>
  <rows>
    <row>
      <cell id="{guid}" rowspan="25">
        <labels>
          <label description="Timeline" languagecode="1033" />
        </labels>
        <control id="notescontrol" classid="{06375649-c143-495e-a496-c962e5b4488e}">
          <parameters>
            <NotesEntityName>annotation</NotesEntityName>
            <isaborttimeline>true</isaborttimeline>
          </parameters>
        </control>
      </cell>
    </row>
  </rows>
</section>
```

---

## Web Resource Pattern

```xml
<cell id="{guid}" rowspan="10" colspan="2">
  <labels>
    <label description="Custom Control" languagecode="1033" />
  </labels>
  <control id="webresource_custom" classid="{9FDF5F91-88B1-47f4-AD53-C11EFC01A01D}">
    <parameters>
      <Url>hso_/html/customcontrol.html</Url>
      <PassParameters>true</PassParameters>
      <Security>false</Security>
      <Scrolling>auto</Scrolling>
      <Border>false</Border>
    </parameters>
  </control>
</cell>
```

---

## Complete Tab Example (Contract Financial Tab)

```xml
<tab name="tab_financial" id="{new-guid}" showlabel="true" expanded="true">
  <labels>
    <label description="Financial" languagecode="1033" />
  </labels>
  <columns>
    <column width="100%">
      <sections>
        <!-- Current Year Amounts -->
        <section name="tab_financial_section_currentyear" id="{new-guid}" columns="2" showlabel="true" labelwidth="150">
          <labels>
            <label description="Current Year Amounts" languagecode="1033" />
          </labels>
          <rows>
            <row>
              <cell id="{new-guid}">
                <labels><label description="Current FY Obligation" languagecode="1033" /></labels>
                <control id="hso_currentfyobligation_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
                         datafieldname="hso_currentfyobligation_amt" />
              </cell>
              <cell id="{new-guid}">
                <labels><label description="Max Approved Amount" languagecode="1033" /></labels>
                <control id="hso_maxapprovedamount_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
                         datafieldname="hso_maxapprovedamount_amt" />
              </cell>
            </row>
            <row>
              <cell id="{new-guid}">
                <labels><label description="Direct Services" languagecode="1033" /></labels>
                <control id="hso_directservices_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
                         datafieldname="hso_directservices_amt" />
              </cell>
              <cell id="{new-guid}">
                <labels><label description="Expenses" languagecode="1033" /></labels>
                <control id="hso_expenses_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
                         datafieldname="hso_expenses_amt" />
              </cell>
            </row>
          </rows>
        </section>

        <!-- Total Amounts -->
        <section name="tab_financial_section_totals" id="{new-guid}" columns="2" showlabel="true" labelwidth="150">
          <labels>
            <label description="Total Amounts" languagecode="1033" />
          </labels>
          <rows>
            <row>
              <cell id="{new-guid}">
                <labels><label description="Total Obligation" languagecode="1033" /></labels>
                <control id="hso_totalobligation_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
                         datafieldname="hso_totalobligation_amt" disabled="true" />
              </cell>
              <cell id="{new-guid}">
                <labels><label description="Previous Obligation" languagecode="1033" /></labels>
                <control id="hso_previousobligation_amt" classid="{533B9E00-756B-4312-95A0-DC888637AC78}"
                         datafieldname="hso_previousobligation_amt" />
              </cell>
            </row>
          </rows>
        </section>

        <!-- Appropriations Subgrid -->
        <section name="tab_financial_section_appropriations" id="{new-guid}" columns="1" showlabel="true">
          <labels>
            <label description="Appropriations" languagecode="1033" />
          </labels>
          <rows>
            <row>
              <cell id="{new-guid}" rowspan="8">
                <labels><label description="Contract Appropriations" languagecode="1033" /></labels>
                <control id="subgrid_appropriations" classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}">
                  <parameters>
                    <TargetEntityType>hso_contractappropriation</TargetEntityType>
                    <ViewId>{appropriations-view-guid}</ViewId>
                    <RelationshipName>hso_contract_appropriation</RelationshipName>
                    <EnableQuickFind>true</EnableQuickFind>
                    <EnableViewPicker>true</EnableViewPicker>
                    <RecordsPerPage>5</RecordsPerPage>
                  </parameters>
                </control>
              </cell>
            </row>
          </rows>
        </section>
      </sections>
    </column>
  </columns>
</tab>
```

---

## Record Log Tab (Standard Pattern)

Add as the **last tab before any Related tab** on every main form. The right section is hidden via the form OnLoad script unless the spec defines admin content for it.

```xml
<tab name="tab_recordlog" id="{guid}" showlabel="true" expanded="true">
  <labels>
    <label description="Record Log" languagecode="1033" />
  </labels>
  <columns>
    <!-- Left: audit fields, section label hidden -->
    <column width="50%">
      <sections>
        <section name="tab_recordlog_section_details" id="{guid}" columns="1" showlabel="false">
          <labels>
            <label description="Details" languagecode="1033" />
          </labels>
          <rows>
            <row>
              <cell id="{guid}">
                <labels><label description="Modified On" languagecode="1033" /></labels>
                <control id="modifiedon" classid="{6D0E476D-F753-4be8-B03F-7D3D7D4E6C1E}"
                         datafieldname="modifiedon" disabled="true" />
              </cell>
            </row>
            <row>
              <cell id="{guid}">
                <labels><label description="Modified By" languagecode="1033" /></labels>
                <control id="modifiedby" classid="{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
                         datafieldname="modifiedby" disabled="true" />
              </cell>
            </row>
            <row>
              <cell id="{guid}">
                <labels><label description="Created On" languagecode="1033" /></labels>
                <control id="createdon" classid="{6D0E476D-F753-4be8-B03F-7D3D7D4E6C1E}"
                         datafieldname="createdon" disabled="true" />
              </cell>
            </row>
            <row>
              <cell id="{guid}">
                <labels><label description="Created By" languagecode="1033" /></labels>
                <control id="createdby" classid="{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
                         datafieldname="createdby" disabled="true" />
              </cell>
            </row>
          </rows>
        </section>
      </sections>
    </column>
    <!-- Right: admin section, hidden by default via OnLoad script -->
    <column width="50%">
      <sections>
        <section name="tab_recordlog_section_admin" id="{guid}" columns="1" showlabel="false">
          <labels>
            <label description="Admin" languagecode="1033" />
          </labels>
          <rows>
            <!-- Add admin-only fields here when spec defines them -->
          </rows>
        </section>
      </sections>
    </column>
  </columns>
</tab>
```

**OnLoad script to hide the right section (add to form OnLoad handler):**

```javascript
// Hide admin section unless user has admin role (implement role check as needed)
formContext.ui.sections.get("tab_recordlog_section_admin").setVisible(false);
```

**Notes:**
- All four audit fields (`modifiedon`, `modifiedby`, `createdon`, `createdby`) are OOB system fields — always `disabled="true"`
- The left section label is hidden (`showlabel="false"`) — the tab label provides sufficient context
- The right section label is also hidden; populate its rows only when the spec defines admin content
- Ask the user whether the right section needs admin fields and if/when it should be visible

---

## GUID Generation

Every element needs a unique GUID. Generate in PowerShell:

```powershell
# Single GUID (formatted for XML)
"{$([guid]::NewGuid().ToString())}"

# Multiple GUIDs
1..10 | ForEach-Object { "{$([guid]::NewGuid().ToString())}" }
```

---

## Best Practices

1. **Always use unique GUIDs** - Never copy/paste GUIDs between elements
2. **Follow naming conventions** - Tabs: `tab_{descriptor}`. Sections: `{tab_name}_section_{descriptor}`. Labels: Title Case.
3. **Set `showlabel="true"`** for sections unless they follow a labeled tab
4. **Use `labelwidth`** appropriate for your field labels (default 115)
5. **Set `rowspan`** for subgrids and multi-line fields to give them space
6. **Use `colspan`** for fields that need full width in a multi-column section
7. **Keep language code 1033** for English
8. **Test incrementally** - Add one tab at a time and verify
