# Complete Data Model Workflow Example

This document provides a step-by-step example of creating a complete data model using the dataverse-data-modeling skill.

**IMPORTANT:** All commands require `-EnvironmentUrl`. Authentication mode is resolved automatically from settings.

---

## Scenario: Project Management Data Model

Create tables for Project, Task, Resource with relationships.

### Data Model Overview

```
Tables:
- hso_project (Project)
- hso_task (Task) - child of Project
- hso_resource (Resource)
- hso_project_resource (N:N intersection)

Global Choices:
- hso_projectstatus (Draft, In Progress, Completed, etc.)
- hso_taskpriority (High, Medium, Low)
```

---

## Step 1: Plan the Data Model

Before creating anything, document the data model:

| Table | Purpose | Key Fields |
|-------|---------|------------|
| hso_project | Main project entity | Name, Start Date, End Date, Budget, Status |
| hso_task | Tasks within projects | Name, Description, Due Date, Priority, Estimated Hours |
| hso_resource | Team members | Name, Email, Hourly Rate |

| Relationship | Type | Description |
|--------------|------|-------------|
| Project -> Task | 1:N | Each project has many tasks |
| Project <-> Resource | N:N | Projects have many resources, resources work on many projects |

---

## Step 2: Create Global Choices First

Global choices must exist before tables that reference them.

**Note:** Option values are auto-generated using the publisher's option value prefix. You only need to provide labels.

### Create Project Status

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateGlobalChoice `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChoiceName "hso_projectstatus" `
    -ChoiceDisplayName "Project Status" `
    -Options @(
        @{Label="Draft"},
        @{Label="In Progress"},
        @{Label="On Hold"},
        @{Label="Completed"},
        @{Label="Cancelled"}
    ) `
    -SolutionName "<YourSolutionUniqueName>"
```

### Create Task Priority

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateGlobalChoice `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChoiceName "hso_taskpriority" `
    -ChoiceDisplayName "Task Priority" `
    -Options @(
        @{Label="High"},
        @{Label="Medium"},
        @{Label="Low"}
    ) `
    -SolutionName "<YourSolutionUniqueName>"
```

---

## Step 3: Create Tables

### Create Project Table

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "project" `
    -DisplayName "Project" `
    -DisplayNamePlural "Projects" `
    -Description "Tracks project information" `
    -OwnershipType "UserOwned" `
    -HasActivities $true `
    -HasNotes $true `
    -SolutionName "<YourSolutionUniqueName>"
```

### Create Task Table

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "task" `
    -DisplayName "Task" `
    -DisplayNamePlural "Tasks" `
    -Description "Tasks within projects" `
    -OwnershipType "UserOwned" `
    -HasActivities $false `
    -HasNotes $true `
    -SolutionName "<YourSolutionUniqueName>"
```

### Create Resource Table

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "resource" `
    -DisplayName "Resource" `
    -DisplayNamePlural "Resources" `
    -Description "Team members and resources" `
    -OwnershipType "UserOwned" `
    -HasActivities $false `
    -HasNotes $false `
    -SolutionName "<YourSolutionUniqueName>"
```

---

## Step 4: Add Columns to Tables

### Add Columns to Project

```powershell
# Start Date
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_project" `
    -ColumnName "hso_startdate_date" `
    -ColumnDisplayName "Start Date" `
    -ColumnType "DateTime" `
    -DateTimeFormat "DateOnly" `
    -SolutionName "<YourSolutionUniqueName>" `

# End Date
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_project" `
    -ColumnName "hso_enddate_date" `
    -ColumnDisplayName "End Date" `
    -ColumnType "DateTime" `
    -DateTimeFormat "DateOnly" `
    -SolutionName "<YourSolutionUniqueName>" `

# Budget
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_project" `
    -ColumnName "hso_budget_amt" `
    -ColumnDisplayName "Budget" `
    -ColumnType "Money" `
    -SolutionName "<YourSolutionUniqueName>" `

# Status (using global choice)
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_project" `
    -ColumnName "hso_status_code" `
    -ColumnDisplayName "Status" `
    -ColumnType "Picklist" `
    -GlobalChoiceName "hso_projectstatus" `
    -SolutionName "<YourSolutionUniqueName>"
```

### Add Columns to Task

```powershell
# Description
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_task" `
    -ColumnName "hso_description_memo" `
    -ColumnDisplayName "Description" `
    -ColumnType "Memo" `
    -MaxLength 2000 `
    -SolutionName "<YourSolutionUniqueName>" `

# Due Date
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_task" `
    -ColumnName "hso_duedate_date" `
    -ColumnDisplayName "Due Date" `
    -ColumnType "DateTime" `
    -DateTimeFormat "DateOnly" `
    -SolutionName "<YourSolutionUniqueName>" `

# Estimated Hours
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_task" `
    -ColumnName "hso_estimatedhours_dec" `
    -ColumnDisplayName "Estimated Hours" `
    -ColumnType "Decimal" `
    -Precision 2 `
    -SolutionName "<YourSolutionUniqueName>" `

# Priority (using global choice)
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_task" `
    -ColumnName "hso_priority_code" `
    -ColumnDisplayName "Priority" `
    -ColumnType "Picklist" `
    -GlobalChoiceName "hso_taskpriority" `
    -SolutionName "<YourSolutionUniqueName>"
```

### Add Columns to Resource

```powershell
# Email
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_resource" `
    -ColumnName "hso_email_text" `
    -ColumnDisplayName "Email" `
    -ColumnType "String" `
    -StringFormat "Email" `
    -MaxLength 100 `
    -SolutionName "<YourSolutionUniqueName>" `

# Hourly Rate
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_resource" `
    -ColumnName "hso_hourlyrate_amt" `
    -ColumnDisplayName "Hourly Rate" `
    -ColumnType "Money" `
    -SolutionName "<YourSolutionUniqueName>"
```

---

## Step 5: Create Relationships

### Project -> Task (1:N Relationship)

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType OneToMany `
    -ParentTable "hso_project" `
    -ChildTable "hso_task" `
    -LookupName "hso_project_id" `
    -LookupDisplayName "Project" `
    -CascadeDelete "Cascade" `
    -CascadeAssign "Cascade" `
    -SolutionName "<YourSolutionUniqueName>"
```

### Project <-> Resource (N:N Relationship)

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType ManyToMany `
    -Entity1 "hso_project" `
    -Entity2 "hso_resource" `
    -IntersectEntityName "hso_project_resource" `
    -SolutionName "<YourSolutionUniqueName>"
```

---

## Step 6: Publish Customizations

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation Publish `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TablesToPublish @("hso_project", "hso_task", "hso_resource") `
    -SolutionName "<YourSolutionUniqueName>"
```

---

## Step 7: Verify Creation

Query to verify all components exist:

```powershell
# Verify Project table
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_project" `

# Verify Task table
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_task" `

# Verify Resource table
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_resource"
```

---

## Summary Checklist

- [ ] Global choices created first
- [ ] Tables created with primary name column
- [ ] Additional columns added to tables
- [ ] Choice columns reference global choices (not local option sets)
- [ ] 1:N relationships created with appropriate cascade settings
- [ ] N:N relationships created with meaningful intersection names
- [ ] Customizations published
- [ ] All components verified
