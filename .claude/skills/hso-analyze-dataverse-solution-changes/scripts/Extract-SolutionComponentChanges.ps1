<#
.SYNOPSIS
    Extracts detailed component changes from Dataverse solution files between git branches.

.DESCRIPTION
    Analyzes git diff between branches to identify and extract comprehensive
    details about changed Dataverse solution components including:
    - Custom APIs (parameters, response properties, bindings)
    - Plugin Steps (messages, entities, stages, modes)
    - Forms (subgrids, views, controls, field changes)
    - Power Automate Workflows (triggers, field references)
    - Web Resources (files, changes, deletions)
    - Entity Metadata (views, fields, relationships)

    Generates a detailed markdown report optimized for solution change analysis.

.PARAMETER SourceBranch
    The source branch to analyze (required).
    Example: "origin/solution-export/168" or "solution-export/168"

.PARAMETER PullRequestId
    Optional: Identifier for documentation purposes (e.g., PR number, build number)
    If provided, will be included in the report header and filename

.PARAMETER TargetBranch
    Target branch for comparison (default: origin/master)

.PARAMETER SolutionPath
    Path to Solutions folder (default: Solutions)

.PARAMETER OutputPath
    Where to save the analysis (default: Solutions/PR_Analysis)

.EXAMPLE
    .\Extract-SolutionComponentChanges.ps1 -SourceBranch "origin/solution-export/168"

.EXAMPLE
    .\Extract-SolutionComponentChanges.ps1 -PullRequestId 13 -SourceBranch "origin/solution-export/168" -TargetBranch "origin/master"

.NOTES
    Author: HSO Development Team
    Purpose: Generate comprehensive Dataverse solution change analysis
    Designed to be called by the analyze-dataverse-solution-changes skill
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceBranch,

    [string]$PullRequestId,
    [string]$TargetBranch = "origin/master",
    [string]$SolutionPath = "Solutions",
    [string]$OutputPath = "Solutions/PR_Analysis"
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Continue"

Write-Host "=================================================="
Write-Host "PR Component Changes - Comprehensive Extractor"
Write-Host "=================================================="
Write-Host ""

if ([string]::IsNullOrWhiteSpace($PullRequestId)) {
    Write-Host "Source Branch: $SourceBranch"
} else {
    Write-Host "Pull Request: $PullRequestId"
    Write-Host "Source Branch: $SourceBranch"
}
Write-Host "Target Branch: $TargetBranch"
Write-Host ""

# Create safe filename from branch name
$safeBranchName = $SourceBranch -replace '/', '_'
if ([string]::IsNullOrWhiteSpace($PullRequestId)) {
    $reportFileName = "PR_${safeBranchName}_Comprehensive_Analysis.md"
} else {
    $reportFileName = "PR_${PullRequestId}_${safeBranchName}_Comprehensive_Analysis.md"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-GitChangedFiles {
    param([string]$source, [string]$target)

    Write-Host "Fetching git diff between $target and $source..."
    try {
        $diff = & git diff "$target...$source" --name-status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARNING: Git diff failed. Trying alternative diff method..."
            $diff = & git diff "$target..$source" --name-status 2>&1
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARNING: Git diff still failed. Checking if branch exists..."
            & git fetch origin 2>&1 | Out-Null
            $diff = & git diff "$target...$source" --name-status 2>&1
        }

        $filtered = $diff | Where-Object { $_ -match $SolutionPath }
        Write-Host "  Found $($filtered.Count) solution files changed in $SolutionPath"
        return $filtered
    } catch {
        Write-Host "  ERROR: Could not get git diff: $_"
        return @()
    }
}

function Get-FileContent {
    param([string]$filePath, [string]$branch)

    try {
        $content = & git show "${branch}:${filePath}" 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $content
        }
        return $null
    } catch {
        return $null
    }
}

function Parse-XML-Safe {
    param([string]$content)

    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    try {
        [xml]$xml = $content
        return $xml
    } catch {
        return $null
    }
}

# Extract Custom API Details
function Extract-CustomAPIProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.customapi) {
        return $null
    }

    # Extract display name and description from 'default' attribute
    $displayNameValue = $xml.customapi.displayname.GetAttribute("default")
    if ([string]::IsNullOrWhiteSpace($displayNameValue)) {
        $displayNameValue = ""
    }

    $descriptionValue = $xml.customapi.description.GetAttribute("default")
    if ([string]::IsNullOrWhiteSpace($descriptionValue)) {
        $descriptionValue = ""
    }

    $api = @{
        ChangeType = $changeType
        UniqueName = $xml.customapi.uniquename
        DisplayName = $displayNameValue
        Description = $descriptionValue
        BindingType = if ($xml.customapi.bindingtype -eq 0) { "Unbound (0)" } else { "Bound ($($xml.customapi.bindingtype))" }
        IsFunction = if ($xml.customapi.isfunction -eq 0) { "No (Action)" } else { "Yes (Function)" }
        IsPrivate = $xml.customapi.isprivate
        AllowedProcessing = $xml.customapi.allowedcustomprocessingsteptype
        Parameters = @()
        ResponseProperties = @()
    }

    # Extract request parameters
    if ($xml.customapi.requestparameters.customapirequestparameter) {
        $params = $xml.customapi.requestparameters.customapirequestparameter
        if ($params -isnot [array]) {
            $params = @($params)
        }

        foreach ($param in $params) {
            $api.Parameters += @{
                Name = $param.uniquename
                Type = $param.type
                Required = if ($param.isrequired -eq 1) { "Yes" } else { "No" }
                Description = $param.description
            }
        }
    }

    # Extract response properties
    if ($xml.customapi.responseproperties.customapiresponseproperty) {
        $props = $xml.customapi.responseproperties.customapiresponseproperty
        if ($props -isnot [array]) {
            $props = @($props)
        }

        foreach ($prop in $props) {
            $api.ResponseProperties += @{
                Name = $prop.uniquename
                Type = $prop.type
                Description = $prop.description
            }
        }
    }

    return $api
}

# Extract Form Details
function Extract-FormProperties {
    param([string]$filePath, [string]$branch, [string]$changeType, [string]$entityName)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    # Form XML structure: <forms><systemform>...</systemform></forms>
    if (-not $xml -or -not $xml.forms -or -not $xml.forms.systemform) {
        return $null
    }

    $systemForm = $xml.forms.systemform

    # Safely extract text values
    $formId = if ($systemForm.formid) {
        if ($systemForm.formid.InnerText) { $systemForm.formid.InnerText } else { $systemForm.formid }
    } else { "" }

    # Extract form name from localized names
    $formName = ""
    if ($systemForm.LocalizedNames -and $systemForm.LocalizedNames.LocalizedName) {
        $formName = $systemForm.LocalizedNames.LocalizedName.GetAttribute("description")
    }
    if ([string]::IsNullOrWhiteSpace($formName)) {
        $formName = $entityName
    }

    # Extract form type from FormPresentation element
    $formType = "Unknown"
    if ($systemForm.FormPresentation) {
        $typeCode = if ($systemForm.FormPresentation.InnerText) { $systemForm.FormPresentation.InnerText } else { $systemForm.FormPresentation }
        $typeMap = @{
            "0" = "Interactive"
            "1" = "Main"
            "2" = "Mobile"
            "3" = "Quick"
            "4" = "Mobile Express"
        }
        $formType = if ($typeMap.ContainsKey($typeCode)) { $typeMap[$typeCode] } else { "Type $typeCode" }
    }

    $form = @{
        ChangeType = $changeType
        EntityName = $entityName
        FormId = $formId
        FormName = $formName
        FormType = $formType
        Subgrids = @()
        SubgridNames = @()
        Controls = @()
        ControlIds = @()
        Tabs = @()
    }

    # Extract form element details - look for controls/subgrids in the form XML
    if ($systemForm.OuterXml) {
        $xmlString = $systemForm.OuterXml

        # Extract subgrid controls with IDs
        $subgridMatches = [regex]::Matches($xmlString, '<control id="([^"]+)"[^>]*controltype="subgrid"')
        foreach ($match in $subgridMatches) {
            $subgridId = $match.Groups[1].Value
            if ($subgridId -notin $form.SubgridNames) {
                $form.SubgridNames += $subgridId
            }
        }
        $form.Subgrids = $form.SubgridNames.Count

        # Extract control IDs (all controls)
        $controlMatches = [regex]::Matches($xmlString, '<control id="([^"]+)"')
        foreach ($match in $controlMatches) {
            $controlId = $match.Groups[1].Value
            if ($controlId -notin $form.ControlIds) {
                $form.ControlIds += $controlId
            }
        }
        $form.Controls = $form.ControlIds.Count

        # Extract tab names
        $tabMatches = [regex]::Matches($xmlString, '<tab[^>]+name="([^"]+)"')
        foreach ($match in $tabMatches) {
            $tabName = $match.Groups[1].Value
            if ($tabName -notin $form.Tabs) {
                $form.Tabs += $tabName
            }
        }
    }

    return $form
}

# Compare form versions between target (old) and source (new) branches
function Compare-FormVersions {
    param(
        [string]$filePath,
        [string]$targetBranch,
        [string]$sourceBranch,
        [string]$entityName
    )

    try {
        # Extract old form (from target branch)
        $oldForm = Extract-FormProperties -filePath $filePath -branch $targetBranch -changeType "M" -entityName $entityName

        # Extract new form (from source branch)
        $newForm = Extract-FormProperties -filePath $filePath -branch $sourceBranch -changeType "M" -entityName $entityName

        if (-not $oldForm -or -not $newForm) {
            return $null
        }

        # Compare subgrids
        $addedSubgrids = @($newForm.SubgridNames | Where-Object { $_ -notin $oldForm.SubgridNames })
        $removedSubgrids = @($oldForm.SubgridNames | Where-Object { $_ -notin $newForm.SubgridNames })

        # Compare controls
        $addedControls = @($newForm.ControlIds | Where-Object { $_ -notin $oldForm.ControlIds })
        $removedControls = @($oldForm.ControlIds | Where-Object { $_ -notin $newForm.ControlIds })

        # Compare tabs
        $addedTabs = @($newForm.Tabs | Where-Object { $_ -notin $oldForm.Tabs })
        $removedTabs = @($oldForm.Tabs | Where-Object { $_ -notin $newForm.Tabs })

        # Return comparison results
        return [PSCustomObject]@{
            HasChanges = ($addedSubgrids.Count -gt 0 -or $removedSubgrids.Count -gt 0 -or
                         $addedControls.Count -gt 0 -or $removedControls.Count -gt 0 -or
                         $addedTabs.Count -gt 0 -or $removedTabs.Count -gt 0)
            OldSubgridCount = $oldForm.SubgridNames.Count
            NewSubgridCount = $newForm.SubgridNames.Count
            AddedSubgrids = $addedSubgrids
            RemovedSubgrids = $removedSubgrids
            OldControlCount = $oldForm.ControlIds.Count
            NewControlCount = $newForm.ControlIds.Count
            AddedControls = $addedControls
            RemovedControls = $removedControls
            OldTabCount = $oldForm.Tabs.Count
            NewTabCount = $newForm.Tabs.Count
            AddedTabs = $addedTabs
            RemovedTabs = $removedTabs
        }
    }
    catch {
        Write-Host "WARNING: Failed to compare form versions for $filePath - $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# Extract Web Resource Details
function Extract-WebResourceProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.WebResource) {
        return $null
    }

    # Extract Web Resource properties - values are in InnerText or as direct elements
    $logicalName = if ($xml.WebResource.Name) {
        $xml.WebResource.Name.InnerText
    } else { "" }

    $displayName = if ($xml.WebResource.DisplayName) {
        $xml.WebResource.DisplayName.InnerText
    } else { "" }

    # WebResourceType is numeric: 1=HTML, 2=CSS, 3=JavaScript, 4=XML, 5=PNG, 6=JPG, 7=GIF, 8=Silverlight, 9=XAP, 10=XPS, 11=Audio, 12=Video, 13=Document, 14=Web Page (IFrame), 15=Image
    $typeNum = if ($xml.WebResource.WebResourceType) {
        [int]$xml.WebResource.WebResourceType.InnerText
    } else { 0 }

    $typeMap = @{
        1 = "HTML"
        2 = "CSS"
        3 = "JavaScript"
        4 = "XML"
        5 = "PNG"
        6 = "JPG"
        7 = "GIF"
        8 = "Silverlight"
        9 = "XAP"
        10 = "XPS"
        11 = "Audio"
        12 = "Video"
        13 = "Document"
        14 = "IFrame"
        15 = "Image"
    }

    $type = $typeMap[$typeNum]
    if ([string]::IsNullOrWhiteSpace($type)) {
        $type = "Unknown ($typeNum)"
    }

    $wr = @{
        ChangeType = $changeType
        LogicalName = $logicalName
        DisplayName = $displayName
        Type = $type
        Description = ""
        IsManaged = ""
    }

    return $wr
}

# Extract Workflow/Power Automate Details (XML format)
function Extract-WorkflowProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.Workflow) {
        return $null
    }

    # Safely extract text values
    $name = if ($xml.Workflow.Name) {
        if ($xml.Workflow.Name.InnerText) { $xml.Workflow.Name.InnerText } else { $xml.Workflow.Name }
    } else { "" }

    $type = if ($xml.Workflow.Type) {
        if ($xml.Workflow.Type.InnerText) { $xml.Workflow.Type.InnerText } else { $xml.Workflow.Type }
    } else { "" }

    $trigger = if ($xml.Workflow.Trigger) {
        if ($xml.Workflow.Trigger.InnerText) { $xml.Workflow.Trigger.InnerText } else { $xml.Workflow.Trigger }
    } else { "" }

    $workflow = @{
        ChangeType = $changeType
        Name = $name
        Type = $type
        Trigger = $trigger
        FieldReferences = @()
    }

    # Extract field references from workflow XML
    if ($xml.OuterXml) {
        $xmlString = $xml.OuterXml
        $fieldMatches = [regex]::Matches($xmlString, 'field="([^"]+)"')
        foreach ($match in $fieldMatches) {
            $fieldName = $match.Groups[1].Value
            if ($fieldName -notin $workflow.FieldReferences) {
                $workflow.FieldReferences += $fieldName
            }
        }
    }

    return $workflow
}

# Extract Power Automate Cloud Flow Details (JSON format)
function Extract-PowerAutomateFlowProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    try {
        $rawContent = Get-FileContent -filePath $filePath -branch $branch
        if ($rawContent -is [array]) {
            $content = $rawContent -join "`n"
        } else {
            $content = $rawContent
        }

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "    WARNING: Workflow JSON file is empty: $filePath"
            return $null
        }

        $json = $null
        try {
            $json = ConvertFrom-Json -InputObject $content -ErrorAction Stop
        } catch {
            Write-Host "    WARNING: Failed to parse workflow JSON - $($_.Exception.Message): $filePath"
            return $null
        }

        if (-not $json) {
            return $null
        }

        # Safely navigate JSON structure
        if (-not $json.properties) {
            Write-Host "    WARNING: Workflow JSON missing 'properties' section: $filePath"
            return $null
        }

        if (-not $json.properties.definition) {
            Write-Host "    WARNING: Workflow JSON missing 'definition' section: $filePath"
            return $null
        }

        # Extract workflow name from filename (format: Name-GUID.json)
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
        $name = $fileName -replace '-[A-F0-9\-]+$', '' # Remove GUID suffix

        # Extract trigger information
        $triggers = $json.properties.definition.triggers
        $triggerName = if ($triggers) { @($triggers.PSObject.Properties)[0].Name } else { "Unknown" }

        # Extract trigger type and entity
        $triggerType = "Unknown"
        $triggerEntity = ""
        if ($triggers) {
            $trigger = @($triggers.PSObject.Properties)[0].Value
            # Check if this is a Dataverse webhook trigger
            if ($trigger -and $trigger.type -eq "OpenApiConnectionWebhook") {
                $triggerType = "Dataverse Record Create/Update"
                # Parameters with slashes need bracket notation: "subscriptionRequest/entityname"
                if ($trigger.inputs -and $trigger.inputs.parameters) {
                    $triggerEntity = $trigger.inputs.parameters."subscriptionRequest/entityname"
                }
            }
        }

        # Extract field references from the entire JSON content
        $fieldReferences = @()
        if ($content) {
            # Look for $select parameters and field references in actions
            $selectMatches = [regex]::Matches($content, '\$select"\s*:\s*"([^"]+)"')
            foreach ($match in $selectMatches) {
                $fields = $match.Groups[1].Value -split ',\s*'
                foreach ($field in $fields) {
                    $field = $field.Trim()
                    if ($field -and $field -notin $fieldReferences) {
                        $fieldReferences += $field
                    }
                }
            }
        }

        $flow = @{
            ChangeType = $changeType
            Name = $name
            Type = "Cloud Flow"
            Trigger = "$triggerType (Entity: $triggerEntity)"
            TriggerEntity = $triggerEntity
            FieldReferences = $fieldReferences
        }

        return $flow
    }
    catch {
        Write-Host "    WARNING: Unexpected error in workflow JSON parsing: $($_.Exception.Message)"
        return $null
    }
}

# Extract Plugin Step Details
function Extract-PluginStepProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.SdkMessageProcessingStep) {
        return $null
    }

    $stepElement = $xml.SdkMessageProcessingStep

    # Extract values safely from XML attributes and child elements
    $stepName = $stepElement.GetAttribute("Name")
    $stepId = $stepElement.GetAttribute("SdkMessageProcessingStepId")

    # Extract stage - codes: 10=Pre-Validation, 20=Pre-Operation, 40=Post-Operation
    $stageCode = if ($stepElement.Stage) {
        if ($stepElement.Stage.InnerText) { $stepElement.Stage.InnerText } else { $stepElement.Stage }
    } else { "" }

    $stageMap = @{
        "10" = "Pre-Validation"
        "20" = "Pre-Operation"
        "40" = "Post-Operation"
    }
    $stageName = if ($stageMap.ContainsKey($stageCode)) { $stageMap[$stageCode] } else { "Stage $stageCode" }

    # Extract mode - codes: 0=Synchronous, 1=Asynchronous
    $modeCode = if ($stepElement.Mode) {
        if ($stepElement.Mode.InnerText) { $stepElement.Mode.InnerText } else { $stepElement.Mode }
    } else { "0" }

    $modeMap = @{
        "0" = "Synchronous"
        "1" = "Asynchronous"
    }
    $modeName = if ($modeMap.ContainsKey($modeCode)) { $modeMap[$modeCode] } else { "Mode $modeCode" }

    # Extract other properties
    $primaryEntity = if ($stepElement.PrimaryEntity) {
        if ($stepElement.PrimaryEntity.InnerText) { $stepElement.PrimaryEntity.InnerText } else { $stepElement.PrimaryEntity }
    } else { "" }

    $description = if ($stepElement.Description) {
        if ($stepElement.Description.InnerText) { $stepElement.Description.InnerText } else { $stepElement.Description }
    } else { "" }

    $executionOrder = if ($stepElement.Rank) {
        if ($stepElement.Rank.InnerText) { $stepElement.Rank.InnerText } else { $stepElement.Rank }
    } else { "1" }

    $filteredAttributes = if ($stepElement.FilteringAttributes) {
        if ($stepElement.FilteringAttributes.InnerText) { $stepElement.FilteringAttributes.InnerText } else { $stepElement.FilteringAttributes }
    } else { "" }

    $step = @{
        ChangeType = $changeType
        StepId = $stepId
        Name = $stepName
        PrimaryEntity = $primaryEntity
        Stage = $stageName
        StageCode = $stageCode
        Mode = $modeName
        ModeCode = $modeCode
        ExecutionOrder = $executionOrder
        Description = $description
        FilteredAttributes = @()
    }

    # Split filtered attributes if present
    if (-not [string]::IsNullOrWhiteSpace($filteredAttributes)) {
        $step.FilteredAttributes = @($filteredAttributes -split ',' | ForEach-Object { $_.Trim() })
    }

    return $step
}

# Extract Entity View Details
function Extract-EntityViewProperties {
    param([string]$filePath, [string]$branch, [string]$changeType, [string]$entityName)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.savedqueries -or -not $xml.savedqueries.savedquery) {
        return $null
    }

    $savedQuery = $xml.savedqueries.savedquery

    # Extract view name from LocalizedNames
    $viewName = ""
    if ($savedQuery.LocalizedNames -and $savedQuery.LocalizedNames.LocalizedName) {
        $viewName = $savedQuery.LocalizedNames.LocalizedName.GetAttribute("description")
    }
    if ([string]::IsNullOrWhiteSpace($viewName)) {
        $viewName = "Unknown View"
    }

    # Extract view ID
    $viewId = if ($savedQuery.savedqueryid) { $savedQuery.savedqueryid.InnerText } else { "" }

    # Map view type codes to readable names
    $viewTypeMap = @{
        "0" = "Public"
        "1" = "Advanced Find"
        "2" = "Associated"
        "3" = "Quick Find"
        "4" = "Lookup"
        "5" = "Address Lookup"
    }
    $viewTypeCode = if ($savedQuery.querytype -and $savedQuery.querytype.InnerText) {
        $savedQuery.querytype.InnerText
    } else {
        "0"
    }

    # Safely check if viewTypeCode is in map
    if ($viewTypeCode -and $viewTypeMap.ContainsKey($viewTypeCode)) {
        $viewTypeName = $viewTypeMap[$viewTypeCode]
    } else {
        $viewTypeName = if ($viewTypeCode) { "Type $viewTypeCode" } else { "Unknown" }
    }

    $view = @{
        ChangeType = $changeType
        Name = $viewName
        ViewId = $viewId
        EntityName = $entityName
        ViewType = $viewTypeName
        ViewTypeCode = $viewTypeCode
        IsPublic = if ($savedQuery.isprivate -eq "0" -or [string]::IsNullOrWhiteSpace($savedQuery.isprivate)) { "Yes" } else { "No" }
        Columns = @()
        ColumnWidths = @{}
        SortOrder = @()
        FilterConditions = @()
    }

    # Extract column definitions with widths from layoutxml
    if ($savedQuery.layoutxml) {
        $layoutXml = $savedQuery.layoutxml.InnerXml
        # Extract cells with width information
        $cellMatches = [regex]::Matches($layoutXml, '<cell name="([^"]+)"(?:\s+width="(\d+)")?')
        foreach ($match in $cellMatches) {
            $columnName = $match.Groups[1].Value
            $width = if ($match.Groups[2].Success) { $match.Groups[2].Value } else { "auto" }

            if ($columnName -notin $view.Columns) {
                $view.Columns += $columnName
                $view.ColumnWidths[$columnName] = $width
            }
        }
    }

    # Extract sort order from fetchxml
    if ($savedQuery.fetchxml) {
        $fetchXml = $savedQuery.fetchxml.InnerXml
        $orderMatches = [regex]::Matches($fetchXml, '<order\s+attribute="([^"]+)"(?:\s+descending="([^"]+)")?')
        foreach ($match in $orderMatches) {
            $orderAttribute = $match.Groups[1].Value
            $descending = if ($match.Groups[2].Success) { $match.Groups[2].Value -eq "true" } else { $false }
            $orderDirection = if ($descending) { "Descending" } else { "Ascending" }
            $view.SortOrder += @{ Attribute = $orderAttribute; Direction = $orderDirection }
        }
    }

    # Extract filter conditions from fetchxml
    if ($savedQuery.fetchxml) {
        $fetchXml = $savedQuery.fetchxml.InnerXml
        $conditionMatches = [regex]::Matches($fetchXml, '<condition\s+attribute="([^"]+)"\s+operator="([^"]+)"\s+value="([^"]*)"')
        foreach ($match in $conditionMatches) {
            $attribute = $match.Groups[1].Value
            $operator = $match.Groups[2].Value
            $value = $match.Groups[3].Value
            $view.FilterConditions += @{ Attribute = $attribute; Operator = $operator; Value = $value }
        }
    }

    return $view
}

# Extract Canvas App Details
function Extract-CanvasAppProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.CanvasApp) {
        return $null
    }

    # Safely extract text values
    $name = if ($xml.CanvasApp.Name) {
        if ($xml.CanvasApp.Name.InnerText) { $xml.CanvasApp.Name.InnerText } else { $xml.CanvasApp.Name }
    } else { "" }

    $displayName = if ($xml.CanvasApp.DisplayName) {
        if ($xml.CanvasApp.DisplayName.InnerText) { $xml.CanvasApp.DisplayName.InnerText } else { $xml.CanvasApp.DisplayName }
    } else { $name }

    # Extract app type - Canvas App types: 0=Tablet, 1=Phone, 2=Web
    $appTypeCode = if ($xml.CanvasApp.CanvasAppType) {
        if ($xml.CanvasApp.CanvasAppType.InnerText) { $xml.CanvasApp.CanvasAppType.InnerText } else { $xml.CanvasApp.CanvasAppType }
    } else { "0" }

    $appTypeMap = @{
        "0" = "Tablet"
        "1" = "Phone"
        "2" = "Web"
    }
    $appType = if ($appTypeMap.ContainsKey($appTypeCode)) { $appTypeMap[$appTypeCode] } else { "Unknown ($appTypeCode)" }

    # Extract version/modification date
    $appVersion = if ($xml.CanvasApp.AppVersion) {
        if ($xml.CanvasApp.AppVersion.InnerText) { $xml.CanvasApp.AppVersion.InnerText } else { $xml.CanvasApp.AppVersion }
    } else { "" }

    $app = @{
        ChangeType = $changeType
        Name = $name
        DisplayName = $displayName
        AppType = $appType
        AppVersion = $appVersion
        DataSourceReferences = @()
    }

    # Extract entity/table references
    if ($xml.OuterXml) {
        $xmlString = $xml.OuterXml
        $entityMatches = [regex]::Matches($xmlString, '<Entity name="([^"]+)"')
        foreach ($match in $entityMatches) {
            $entityName = $match.Groups[1].Value
            if ($entityName -notin $app.DataSourceReferences) {
                $app.DataSourceReferences += $entityName
            }
        }
    }

    return $app
}

# Extract App Module (Sitemap) Details
function Extract-AppModuleProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.AppModule) {
        return $null
    }

    # Safely extract text values
    $uniqueName = if ($xml.AppModule.UniqueName) {
        if ($xml.AppModule.UniqueName.InnerText) { $xml.AppModule.UniqueName.InnerText } else { $xml.AppModule.UniqueName }
    } else { "" }

    # Extract display name from LocalizedNames
    $displayName = ""
    if ($xml.AppModule.LocalizedNames -and $xml.AppModule.LocalizedNames.LocalizedName) {
        $displayName = $xml.AppModule.LocalizedNames.LocalizedName.GetAttribute("description")
    }
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = $uniqueName
    }

    $appModule = @{
        ChangeType = $changeType
        UniqueName = $uniqueName
        DisplayName = $displayName
        Components = @()
        ComponentCount = 0
    }

    # Extract AppModuleComponents - these are the entities and components in the app module
    if ($xml.AppModule.AppModuleComponents) {
        $components = $xml.AppModule.AppModuleComponents.AppModuleComponent
        if ($components) {
            if ($components -isnot [array]) {
                $components = @($components)
            }

            foreach ($component in $components) {
                $compType = $component.GetAttribute("type")
                $schemaName = $component.GetAttribute("schemaName")
                $compId = $component.GetAttribute("id")

                if ($schemaName) {
                    $appModule.Components += @{
                        Type = $compType
                        Name = $schemaName
                    }
                } elseif ($compId) {
                    # Component referenced by ID (forms, views, etc.)
                    $appModule.Components += @{
                        Type = $compType
                        Id = $compId
                    }
                }
            }

            $appModule.ComponentCount = $appModule.Components.Count
        }
    }

    return $appModule
}

# Extract Entity/Table Properties from Entity.xml
function Extract-EntityProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.Entity) {
        return $null
    }

    # Extract entity name - handle different XML structures
    $entityName = ""
    $displayName = ""

    if ($xml.Entity.Name) {
        if ($xml.Entity.Name.InnerText) {
            $entityName = $xml.Entity.Name.InnerText
        } else {
            $entityName = $xml.Entity.Name
        }
        # Try to get LocalizedName attribute
        if ($xml.Entity.Name.LocalizedName) {
            $displayName = $xml.Entity.Name.LocalizedName
        }
    }

    # Alternative: Get from EntityInfo
    if ([string]::IsNullOrWhiteSpace($entityName) -and $xml.Entity.EntityInfo.entity) {
        $entityName = $xml.Entity.EntityInfo.entity.Name
    }

    # Get display name from LocalizedNames
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        if ($xml.Entity.EntityInfo.entity.LocalizedNames.LocalizedName) {
            $localizedNames = $xml.Entity.EntityInfo.entity.LocalizedNames.LocalizedName
            if ($localizedNames -is [array]) {
                $displayName = ($localizedNames | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
            } else {
                $displayName = $localizedNames.description
            }
        }
    }

    $entity = @{
        ChangeType = $changeType
        SchemaName = $entityName
        DisplayName = if ([string]::IsNullOrWhiteSpace($displayName)) { $entityName } else { $displayName }
        IsCustomEntity = $false
        IsOOBEntity = $false
        Attributes = @()
        NewAttributes = @()
        AttributeCount = 0
        CustomAttributeCount = 0
    }

    # Determine if custom entity (starts with publisher prefix like hso_)
    if ($entityName -match "^[a-z]+_") {
        $entity.IsCustomEntity = $true
    } else {
        $entity.IsOOBEntity = $true
    }

    # Extract attributes
    $attributes = $null
    if ($xml.Entity.EntityInfo.entity.attributes.attribute) {
        $attributes = $xml.Entity.EntityInfo.entity.attributes.attribute
    }

    if ($attributes) {
        if ($attributes -isnot [array]) {
            $attributes = @($attributes)
        }

        $entity.AttributeCount = $attributes.Count

        foreach ($attr in $attributes) {
            $attrName = ""
            $attrType = ""
            $isCustomField = $false
            $introducedVersion = ""

            if ($attr.Name) {
                $attrName = if ($attr.Name.InnerText) { $attr.Name.InnerText } else { $attr.Name }
            }
            if ($attr.LogicalName) {
                $attrName = if ($attr.LogicalName.InnerText) { $attr.LogicalName.InnerText } else { $attr.LogicalName }
            }
            if ($attr.Type) {
                $attrType = if ($attr.Type.InnerText) { $attr.Type.InnerText } else { $attr.Type }
            }
            if ($attr.IsCustomField -eq "1") {
                $isCustomField = $true
                $entity.CustomAttributeCount++
            }
            if ($attr.IntroducedVersion) {
                $introducedVersion = if ($attr.IntroducedVersion.InnerText) { $attr.IntroducedVersion.InnerText } else { $attr.IntroducedVersion }
            }

            # Get display name
            $attrDisplayName = ""
            if ($attr.displaynames.displayname) {
                $dispNames = $attr.displaynames.displayname
                if ($dispNames -is [array]) {
                    $attrDisplayName = ($dispNames | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
                } else {
                    $attrDisplayName = $dispNames.description
                }
            }

            $attrInfo = @{
                Name = $attrName
                DisplayName = if ([string]::IsNullOrWhiteSpace($attrDisplayName)) { $attrName } else { $attrDisplayName }
                Type = $attrType
                IsCustomField = $isCustomField
                IntroducedVersion = $introducedVersion
            }

            $entity.Attributes += $attrInfo

            # Track custom fields as potentially new
            if ($isCustomField) {
                $entity.NewAttributes += $attrInfo
            }
        }
    }

    return $entity
}

# Extract PCF Control Properties from ControlManifest.xml
function Extract-PCFControlProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml) {
        return $null
    }

    # PCF manifest can have different root elements
    $control = $null
    if ($xml.control) {
        $control = $xml.control
    } elseif ($xml.manifest.control) {
        $control = $xml.manifest.control
    }

    if (-not $control) {
        return $null
    }

    $pcfControl = @{
        ChangeType = $changeType
        Namespace = $control.GetAttribute("namespace")
        Constructor = $control.GetAttribute("constructor")
        Version = $control.GetAttribute("version")
        DisplayName = $control.GetAttribute("display-name-key")
        ControlType = $control.GetAttribute("control-type")
        Properties = @()
    }

    # Full control name
    $pcfControl.FullName = "$($pcfControl.Namespace).$($pcfControl.Constructor)"

    # Extract properties
    if ($control.property) {
        $properties = $control.property
        if ($properties -isnot [array]) {
            $properties = @($properties)
        }

        foreach ($prop in $properties) {
            $pcfControl.Properties += @{
                Name = $prop.GetAttribute("name")
                DisplayName = $prop.GetAttribute("display-name-key")
                Type = $prop.GetAttribute("of-type")
                Usage = $prop.GetAttribute("usage")
                Required = $prop.GetAttribute("required")
            }
        }
    }

    return $pcfControl
}

# Extract Global Option Set Properties
function Extract-OptionSetProperties {
    param([string]$filePath, [string]$branch, [string]$changeType)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.optionset) {
        return $null
    }

    $os = $xml.optionset

    # Get display name
    $displayName = ""
    if ($os.displaynames.displayname) {
        $dispNames = $os.displaynames.displayname
        if ($dispNames -is [array]) {
            $displayName = ($dispNames | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
        } else {
            $displayName = $dispNames.description
        }
    }

    $optionSet = @{
        ChangeType = $changeType
        Name = $os.Name
        DisplayName = if ([string]::IsNullOrWhiteSpace($displayName)) { $os.Name } else { $displayName }
        Type = if ($os.OptionSetType) { $os.OptionSetType } else { "Picklist" }
        IsGlobal = ($os.IsGlobal -eq "1")
        IsManaged = ($os.IsManaged -eq "1")
        IntroducedVersion = $os.IntroducedVersion
        Options = @()
    }

    # Extract options
    if ($os.options.option) {
        $options = $os.options.option
        if ($options -isnot [array]) {
            $options = @($options)
        }

        foreach ($opt in $options) {
            $optLabel = ""
            if ($opt.labels.label) {
                $labels = $opt.labels.label
                if ($labels -is [array]) {
                    $optLabel = ($labels | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
                } else {
                    $optLabel = $labels.description
                }
            }

            $optionSet.Options += @{
                Value = $opt.value
                Label = $optLabel
            }
        }
    }

    return $optionSet
}

# Extract Solution.xml Root Components for behavior analysis
function Extract-SolutionRootComponents {
    param([string]$filePath, [string]$branch)

    $content = Get-FileContent -filePath $filePath -branch $branch
    $xml = Parse-XML-Safe -content $content

    if (-not $xml -or -not $xml.ImportExportXml) {
        return $null
    }

    $solutionInfo = @{
        Version = ""
        UniqueName = ""
        RootComponents = @()
        EntityBehaviors = @()
        BestPracticeWarnings = @()
    }

    # Get solution metadata
    if ($xml.ImportExportXml.SolutionManifest) {
        $manifest = $xml.ImportExportXml.SolutionManifest
        if ($manifest.Version) {
            $solutionInfo.Version = if ($manifest.Version.InnerText) { $manifest.Version.InnerText } else { $manifest.Version }
        }
        if ($manifest.UniqueName) {
            $solutionInfo.UniqueName = if ($manifest.UniqueName.InnerText) { $manifest.UniqueName.InnerText } else { $manifest.UniqueName }
        }
    }

    # Extract RootComponents
    if ($xml.ImportExportXml.SolutionManifest.RootComponents.RootComponent) {
        $components = $xml.ImportExportXml.SolutionManifest.RootComponents.RootComponent
        if ($components -isnot [array]) {
            $components = @($components)
        }

        # Known OOB/System entities that should NOT have behavior="0"
        $oobEntities = @(
            "systemuser", "account", "contact", "opportunity", "lead", "task", "email",
            "appointment", "activitypointer", "phonecall", "letter", "fax", "annotation",
            "businessunit", "team", "queue", "queueitem", "salesorder", "invoice",
            "quote", "product", "productpricelevel", "pricelevel", "discount", "uom",
            "competitor", "campaign", "campaignactivity", "campaignresponse", "list",
            "incident", "contract", "entitlement", "knowledgearticle", "goal",
            "territory", "connection", "connectionrole", "subject", "transactioncurrency"
        )

        foreach ($comp in $components) {
            $compType = $comp.GetAttribute("type")
            $schemaName = $comp.GetAttribute("schemaName")
            $behavior = $comp.GetAttribute("behavior")

            $rootComp = @{
                Type = $compType
                SchemaName = $schemaName
                Behavior = $behavior
                BehaviorDescription = switch ($behavior) {
                    "0" { "Include Subcomponents (All Assets)" }
                    "1" { "Do Not Include Subcomponents" }
                    "2" { "Include As Shell Only" }
                    default { "Unknown" }
                }
            }

            $solutionInfo.RootComponents += $rootComp

            # Check for entity components (type=1) with improper behavior
            if ($compType -eq "1") {
                $entityBehavior = @{
                    SchemaName = $schemaName
                    Behavior = $behavior
                    IsOOB = $schemaName -in $oobEntities
                    IsCustom = $schemaName -match "^[a-z]+_"
                    HasWarning = $false
                    Warning = ""
                }

                # BEST PRACTICE CHECK: OOB entity with behavior="0" is a red flag
                if ($entityBehavior.IsOOB -and $behavior -eq "0") {
                    $entityBehavior.HasWarning = $true
                    $entityBehavior.Warning = "OOB entity '$schemaName' added with ALL ASSETS (behavior=0). This is against best practices and causes solution bloat."
                    $solutionInfo.BestPracticeWarnings += @{
                        Severity = "HIGH"
                        Entity = $schemaName
                        Issue = "OOB/Managed entity added with all assets"
                        Details = "Entity '$schemaName' has behavior='0' which includes ALL forms, views, and fields. This causes solution bloat and layering issues."
                        Recommendation = "Use behavior='1' (Do Not Include Subcomponents) or behavior='2' (Shell Only) for OOB entities. Only add specific components you've customized."
                    }
                }

                $solutionInfo.EntityBehaviors += $entityBehavior
            }
        }
    }

    return $solutionInfo
}

# ============================================================================
# ANALYZE CHANGED FILES
# ============================================================================

Write-Host "Analyzing changed solution components..."
Write-Host ""

$changedFiles = Get-GitChangedFiles -source $SourceBranch -target $TargetBranch

if ($changedFiles.Count -eq 0) {
    Write-Host "WARNING: No solution files found in diff"
}

# Initialize analysis structure
$analysis = @{
    PullRequestId = if ([string]::IsNullOrWhiteSpace($PullRequestId)) { $SourceBranch } else { "PR $PullRequestId" }
    SourceBranch = $SourceBranch
    TargetBranch = $TargetBranch
    # New component types for comprehensive analysis
    Entities = @()
    PCFControls = @()
    OptionSets = @()
    SolutionInfo = $null
    # Existing component types
    CustomAPIs = @()
    PluginSteps = @()
    Forms = @()
    EntityViews = @()
    WebResources = @()
    Workflows = @()
    CanvasApps = @()
    AppModules = @()
    DeletedComponents = @()
    BestPracticeWarnings = @()
    FilesSummary = @{
        Added = 0
        Modified = 0
        Deleted = 0
        Total = 0
    }
}

# First, analyze Solution.xml for root component behaviors (important for best practice checks)
$solutionXmlPath = $null
foreach ($diffLine in $changedFiles) {
    if ($diffLine -match "Other/Solution\.xml$") {
        $parts = $diffLine -split '\s+', 2
        if ($parts.Count -ge 2) {
            $solutionXmlPath = $parts[1]
        }
        break
    }
}

# If Solution.xml wasn't in the diff, try to find it in the source branch
if (-not $solutionXmlPath) {
    # Look for any solution folder in the diff and construct the path
    $solutionFolder = $null
    foreach ($diffLine in $changedFiles) {
        if ($diffLine -match "$SolutionPath/([^/]+)/") {
            $match = [regex]::Match($diffLine, "$SolutionPath/([^/]+)/")
            if ($match.Success) {
                $solutionFolder = $match.Groups[1].Value
                break
            }
        }
    }
    if ($solutionFolder) {
        $solutionXmlPath = "$SolutionPath/$solutionFolder/Other/Solution.xml"
    }
}

if ($solutionXmlPath) {
    Write-Host "  [SOLUTION] Analyzing $solutionXmlPath for component behaviors..."
    $analysis.SolutionInfo = Extract-SolutionRootComponents -filePath $solutionXmlPath -branch $SourceBranch
    if ($analysis.SolutionInfo -and $analysis.SolutionInfo.BestPracticeWarnings.Count -gt 0) {
        $analysis.BestPracticeWarnings += $analysis.SolutionInfo.BestPracticeWarnings
        Write-Host "    WARNING: Found $($analysis.SolutionInfo.BestPracticeWarnings.Count) best practice violation(s)!"
    }
}

Write-Host "Extracting component properties..."

foreach ($diffLine in $changedFiles) {
    if ([string]::IsNullOrWhiteSpace($diffLine)) { continue }

    $parts = $diffLine -split '\s+', 2
    if ($parts.Count -lt 2) { continue }

    $changeType = $parts[0]
    $filePath = $parts[1]

    # Track file statistics
    $analysis.FilesSummary.Total++
    if ($changeType -eq "A") { $analysis.FilesSummary.Added++ }
    elseif ($changeType -eq "M") { $analysis.FilesSummary.Modified++ }
    elseif ($changeType -eq "D") { $analysis.FilesSummary.Deleted++ }

    # Process Entity/Table metadata (Entity.xml files)
    if ($filePath -match "Entities/[^/]+/Entity\.xml$") {
        # Skip managed versions
        if ($filePath -match "_managed\.xml$") {
            continue
        }

        Write-Host "  [TABLE] $filePath"
        $entityMatch = [regex]::Match($filePath, "Entities/([^/]+)/Entity\.xml")
        $entitySchemaName = if ($entityMatch.Success) { $entityMatch.Groups[1].Value } else { "Unknown" }

        if ($changeType -ne "D") {
            $entityProps = Extract-EntityProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($entityProps) {
                # Look up behavior from SolutionInfo if available
                if ($analysis.SolutionInfo -and $analysis.SolutionInfo.EntityBehaviors) {
                    $behaviorInfo = $analysis.SolutionInfo.EntityBehaviors | Where-Object { $_.SchemaName -eq $entityProps.SchemaName }
                    if ($behaviorInfo) {
                        $entityProps.Behavior = $behaviorInfo.Behavior
                        $entityProps.HasWarning = $behaviorInfo.HasWarning
                        $entityProps.Warning = $behaviorInfo.Warning
                    }
                }
                $analysis.Entities += $entityProps
            }
        } else {
            $analysis.Entities += @{
                ChangeType = "D"
                SchemaName = $entitySchemaName
            }
        }
    }

    # Process PCF Controls (ControlManifest.xml files in Controls folder)
    elseif ($filePath -match "Controls/[^/]+/ControlManifest\.xml$") {
        # Skip data descriptor files
        if ($filePath -match "\.data\.xml$") {
            continue
        }

        Write-Host "  [PCF] $filePath"
        $controlMatch = [regex]::Match($filePath, "Controls/([^/]+)/")
        $controlFolderName = if ($controlMatch.Success) { $controlMatch.Groups[1].Value } else { "Unknown" }

        if ($changeType -ne "D") {
            $pcfProps = Extract-PCFControlProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($pcfProps) {
                $pcfProps.FolderName = $controlFolderName
                $analysis.PCFControls += $pcfProps
            }
        } else {
            $analysis.PCFControls += @{
                ChangeType = "D"
                FolderName = $controlFolderName
            }
        }
    }

    # Process Global Option Sets (OptionSets folder)
    elseif ($filePath -match "OptionSets/[^/]+\.xml$") {
        Write-Host "  [OPTIONSET] $filePath"
        $osMatch = [regex]::Match($filePath, "OptionSets/([^/]+)\.xml")
        $osName = if ($osMatch.Success) { $osMatch.Groups[1].Value } else { "Unknown" }

        if ($changeType -ne "D") {
            $osProps = Extract-OptionSetProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($osProps) {
                $analysis.OptionSets += $osProps
            }
        } else {
            $analysis.OptionSets += @{
                ChangeType = "D"
                Name = $osName
            }
        }
    }

    # Process Custom APIs
    elseif ($filePath -match "customapis/[^/]+/customapi\.xml$") {
        Write-Host "  [API] $filePath"
        $apiMatch = [regex]::Match($filePath, "customapis/([^/]+)/")
        $apiName = if ($apiMatch.Success) { $apiMatch.Groups[1].Value } else { "Unknown" }

        if ($changeType -ne "D") {
            $apiProps = Extract-CustomAPIProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($apiProps) {
                $apiProps.ApiName = $apiName
                $analysis.CustomAPIs += $apiProps
            }
        } else {
            $analysis.CustomAPIs += @{
                ChangeType = "D"
                UniqueName = $apiName
                ApiName = $apiName
            }
        }
    }

    # Process Plugin Steps (stored in SdkMessageProcessingSteps folder)
    elseif ($filePath -match "SdkMessageProcessingSteps/.*\.xml$") {
        Write-Host "  [PLUGIN] $filePath"

        if ($changeType -ne "D") {
            $stepProps = Extract-PluginStepProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($stepProps) {
                $analysis.PluginSteps += $stepProps
            }
        }
    }

    # Process Entity Views (SavedQueries)
    elseif ($filePath -match "SavedQueries/.*\.xml$") {
        Write-Host "  [VIEW] $filePath"
        $entityMatch = [regex]::Match($filePath, "Entities/([^/]+)/SavedQueries")
        $entityName = if ($entityMatch.Success) { $entityMatch.Groups[1].Value } else { "Unknown" }

        if ($changeType -ne "D") {
            $viewProps = Extract-EntityViewProperties -filePath $filePath -branch $SourceBranch -changeType $changeType -entityName $entityName
            if ($viewProps) {
                $analysis.EntityViews += $viewProps
            }
        }
    }

    # Process Forms
    elseif ($filePath -match "FormXml/.*\.xml$") {
        # Skip managed versions - they duplicate unmanaged forms (same GUID, just _managed suffix)
        if ($filePath -match "_managed\.xml$") {
            continue
        }

        Write-Host "  [FORM] $filePath"
        $entityMatch = [regex]::Match($filePath, "Entities/([^/]+)/FormXml")
        $entityName = if ($entityMatch.Success) { $entityMatch.Groups[1].Value } else { "Unknown" }

        if ($changeType -ne "D") {
            $formProps = Extract-FormProperties -filePath $filePath -branch $SourceBranch -changeType $changeType -entityName $entityName
            if ($formProps) {
                # For modified forms, perform BEFORE/AFTER comparison
                if ($changeType -eq "M") {
                    $comparison = Compare-FormVersions -filePath $filePath -targetBranch $TargetBranch -sourceBranch $SourceBranch -entityName $entityName
                    if ($comparison) {
                        $formProps.Comparison = $comparison
                    }
                }

                $analysis.Forms += $formProps
            }
        }
    }

    # Process Web Resources
    elseif ($filePath -match "WebResources/" -and ($filePath -match "\.(js|html|css|svg|png|jpg|gif|xml)$")) {
        # Skip data descriptor files
        if ($filePath -match "\.data\.xml$") {
            continue
        }

        Write-Host "  [WEBRESOURCE] $filePath"

        # For XML metadata files, extract full properties
        if ($filePath -match "\.xml$" -and $filePath -notmatch "\.data\.xml$") {
            if ($changeType -ne "D") {
                $wrProps = Extract-WebResourceProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
                if ($wrProps) {
                    $analysis.WebResources += $wrProps
                }
            }
        } else {
            # For binary/script files, create simple entry
            $fileName = [System.IO.Path]::GetFileName($filePath)
            $fileExt = [System.IO.Path]::GetExtension($filePath).TrimStart('.')

            $typeMap = @{
                'js' = 'JavaScript'
                'html' = 'HTML'
                'css' = 'CSS'
                'svg' = 'Image'
                'png' = 'PNG'
                'jpg' = 'JPG'
                'gif' = 'GIF'
            }

            $type = if ($typeMap.ContainsKey($fileExt)) { $typeMap[$fileExt] } else { "Unknown" }

            $analysis.WebResources += @{
                ChangeType = $changeType
                LogicalName = $fileName
                DisplayName = $fileName
                Type = $type
                Description = ""
                IsManaged = ""
            }
        }
    }

    # Process Workflows (both XML and JSON Power Automate cloud flows)
    elseif ($filePath -match "Workflows/.*\.(xml|json)$") {
        Write-Host "  [WORKFLOW] $filePath"

        if ($changeType -ne "D") {
            # JSON workflows are Power Automate cloud flows
            if ($filePath -match "\.json$") {
                $wfProps = Extract-PowerAutomateFlowProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            } else {
                # XML workflows (legacy)
                $wfProps = Extract-WorkflowProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            }

            if ($wfProps) {
                $analysis.Workflows += $wfProps
            }
        }
    }

    # Process Canvas Apps
    elseif ($filePath -match "CanvasApps/.*\.xml$") {
        Write-Host "  [CANVASAPP] $filePath"

        if ($changeType -ne "D") {
            $appProps = Extract-CanvasAppProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($appProps) {
                $analysis.CanvasApps += $appProps
            }
        }
    }

    # Process App Modules (Sitemaps)
    elseif ($filePath -match "AppModules/.*\.xml$") {
        Write-Host "  [APPMODULE] $filePath"

        if ($changeType -ne "D") {
            $moduleProps = Extract-AppModuleProperties -filePath $filePath -branch $SourceBranch -changeType $changeType
            if ($moduleProps) {
                $analysis.AppModules += $moduleProps
            }
        }
    }

    # Track any other deleted solution components (not previously matched)
    if ($changeType -eq "D" -and $filePath -match "^$SolutionPath/") {
        # Skip solution export metadata and managed files
        if ($filePath -notmatch "_managed\.xml$|Solution\.xml$") {
            # Categorize deleted component
            $componentType = "Other"
            $explanation = ""

            # Check for specific component types
            if ($filePath -match "WebResources/" -and $filePath -match "\.js$") {
                $componentType = "Web Resource (JavaScript)"
                $explanation = "JavaScript file was removed or replaced during refactoring."
            }
            elseif ($filePath -match "aiskillconfigs") {
                $componentType = "AI Skill Configuration"
                $explanation = "AI skill configuration was removed, possibly due to feature deprecation or consolidation."
            }
            elseif ($filePath -match "WebResources/" -and $filePath -match "\.(html|css|svg)$") {
                $componentType = "Web Resource"
                $explanation = "Web resource file was removed."
            }
            elseif ($filePath -match "Workflows/" -and $filePath -match "\.(json|xml)$") {
                $componentType = "Workflow"
                $explanation = "Workflow or Power Automate cloud flow was deleted."
            }

            # Add to tracking (use PSCustomObject for better object handling)
            $analysis.DeletedComponents += [PSCustomObject]@{
                Type = $componentType
                Path = $filePath
                Explanation = $explanation
            }
        }
    }
}

Write-Host ""

# ============================================================================
# NAMING CONVENTION VALIDATION
# ============================================================================

Write-Host "Validating naming conventions..."

# Define expected naming patterns based on HSO best practices
# Column suffixes by type
$columnSuffixMap = @{
    "string"   = "_text"
    "memo"     = "_memo"
    "integer"  = "_num"
    "decimal"  = "_dec"
    "money"    = "_amt"
    "boolean"  = "_yn"
    "datetime" = "_date"
    "picklist" = "_code"
    "multiselectpicklist" = "_codes"
    "lookup"   = "_id"
    "customer" = "_id"
    "owner"    = "_id"
}

# Get publisher prefix from SolutionInfo if available
$publisherPrefix = "hso"  # Default
if ($analysis.SolutionInfo -and $analysis.SolutionInfo.PublisherPrefix) {
    $publisherPrefix = $analysis.SolutionInfo.PublisherPrefix
}

# Validate custom entity naming
foreach ($entity in $analysis.Entities) {
    if ($entity.ChangeType -eq "D") { continue }
    if (-not $entity.IsCustomEntity) { continue }

    $schemaName = $entity.SchemaName

    # Check if custom table name follows pattern: prefix_tablename
    if ($schemaName -match "^([a-z]+)_(.+)$") {
        $prefix = $Matches[1]
        $tableName = $Matches[2]

        # Note: We don't flag different prefixes as that's solution-specific
        # But we do flag tables that don't follow lowercase naming
        if ($tableName -cmatch "[A-Z]") {
            $analysis.BestPracticeWarnings += @{
                Severity = "MEDIUM"
                Entity = $schemaName
                Issue = "Table name contains uppercase characters"
                Details = "Table '$schemaName' uses uppercase in the name. Dataverse convention is lowercase."
                Recommendation = "Use lowercase for table names (e.g., ${prefix}_${tableName.ToLower()})."
            }
        }
    }

    # Validate custom attribute naming conventions
    foreach ($attr in $entity.NewAttributes) {
        $attrName = $attr.Name
        $attrType = $attr.Type.ToLower()

        # Skip system fields
        if ($attrName -match "^(createdon|createdby|modifiedon|modifiedby|statecode|statuscode|ownerid|owninguser|owningteam|owningbusinessunit)$") {
            continue
        }

        # Check if attribute follows naming pattern
        if ($attrName -match "^([a-z]+)_(.+)$") {
            $attrSuffix = ""
            $expectedSuffix = ""

            # Determine expected suffix based on type
            if ($columnSuffixMap.ContainsKey($attrType)) {
                $expectedSuffix = $columnSuffixMap[$attrType]
            }

            # Check if name ends with any known suffix
            $hasSuffix = $false
            foreach ($suffix in $columnSuffixMap.Values) {
                if ($attrName.EndsWith($suffix)) {
                    $hasSuffix = $true
                    $attrSuffix = $suffix
                    break
                }
            }

            # Only flag if we know the expected suffix and it doesn't match
            if ($expectedSuffix -and -not $attrName.EndsWith($expectedSuffix)) {
                $analysis.BestPracticeWarnings += @{
                    Severity = "LOW"
                    Entity = $schemaName
                    Issue = "Field naming convention not followed"
                    Details = "Field '$attrName' (type: $attrType) does not follow naming convention. Expected suffix: '$expectedSuffix'."
                    Recommendation = "Use pattern: ${publisherPrefix}_fieldname${expectedSuffix} (e.g., ${attrName}${expectedSuffix} or rename appropriately)."
                }
            }
        }
    }
}

# Validate global option set naming
foreach ($optionSet in $analysis.OptionSets) {
    if ($optionSet.ChangeType -eq "D") { continue }

    $osName = $optionSet.Name

    # Check if custom option set (starts with publisher prefix)
    if ($osName -match "^([a-z]+)_(.+)$") {
        $prefix = $Matches[1]
        $choiceName = $Matches[2]

        # Flag if name contains uppercase
        if ($choiceName -cmatch "[A-Z]") {
            $analysis.BestPracticeWarnings += @{
                Severity = "LOW"
                Entity = "GlobalChoice"
                Issue = "Global choice name contains uppercase"
                Details = "Global choice '$osName' uses uppercase. Convention is lowercase."
                Recommendation = "Use lowercase for choice names (e.g., ${prefix}_${choiceName.ToLower()})."
            }
        }
    }
}

# Validate web resource naming (form scripts should follow hso_/scripts/{entity}/{entity}_form.js)
foreach ($webResource in $analysis.WebResources) {
    if ($webResource.ChangeType -eq "D") { continue }

    $wrName = $webResource.Name
    $wrType = $webResource.FileType

    # Check JavaScript form scripts
    if ($wrType -eq "js" -or $wrName -match "\.js$") {
        # Expected pattern: hso_/scripts/{entity}/{entity}_form.js
        if ($wrName -match "^([a-z]+)_/scripts/") {
            # Good - follows the scripts folder pattern
            if (-not ($wrName -match "_form\.js$")) {
                # It's in scripts folder but doesn't follow _form.js naming
                $analysis.BestPracticeWarnings += @{
                    Severity = "LOW"
                    Entity = "WebResource"
                    Issue = "Form script naming convention"
                    Details = "Web resource '$wrName' is in scripts folder but doesn't follow '{entity}_form.js' pattern."
                    Recommendation = "For form scripts, use pattern: ${publisherPrefix}_/scripts/{entity}/{entity}_form.js"
                }
            }
        }
    }
}

$namingWarnings = @($analysis.BestPracticeWarnings | Where-Object { $_.Issue -match "naming|uppercase" })
if ($namingWarnings.Count -gt 0) {
    Write-Host "  Found $($namingWarnings.Count) naming convention issue(s)"
} else {
    Write-Host "  No naming convention issues found"
}

# ============================================================================
# GENERATE COMPREHENSIVE MARKDOWN REPORT
# ============================================================================

Write-Host "Generating comprehensive analysis report..."

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$reportPath = Join-Path $OutputPath $reportFileName

# Start building the report
$report = @"
# PR Component Changes - Comprehensive Analysis

**PR Identifier:** $($analysis.PullRequestId)
**Source Branch:** $($analysis.SourceBranch)
**Target Branch:** $TargetBranch
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')

---

## Executive Summary

**Change Statistics:**
- **Total Files Changed:** $($analysis.FilesSummary.Total)
- **Files Added:** $($analysis.FilesSummary.Added)
- **Files Modified:** $($analysis.FilesSummary.Modified)
- **Files Deleted:** $($analysis.FilesSummary.Deleted)

**Component Summary:**
- **Tables/Entities:** $($analysis.Entities.Count)
- **PCF Controls:** $($analysis.PCFControls.Count)
- **Global Option Sets:** $($analysis.OptionSets.Count)
- **Custom APIs:** $($analysis.CustomAPIs.Count)
- **Plugin Steps:** $($analysis.PluginSteps.Count)
- **Entity Views:** $($analysis.EntityViews.Count)
- **Forms:** $($analysis.Forms.Count)
- **Web Resources:** $($analysis.WebResources.Count)
- **Workflows:** $($analysis.Workflows.Count)
- **Canvas Apps:** $($analysis.CanvasApps.Count)
- **App Modules:** $($analysis.AppModules.Count)

"@

# Add narrative context based on changes
$report += "`n**Change Overview:**`n`n"

# Build narrative based on what changed
$narrativeParts = @()

# Check for best practice warnings (most important - put first)
if ($analysis.BestPracticeWarnings.Count -gt 0) {
    $highSeverity = @($analysis.BestPracticeWarnings | Where-Object { $_.Severity -eq "HIGH" })
    if ($highSeverity.Count -gt 0) {
        $narrativeParts += "**⚠️ BEST PRACTICE VIOLATIONS DETECTED:** $($highSeverity.Count) high-severity issue(s) found. Review the Best Practice Warnings section below."
    }
}

# Check for table/entity changes
$newEntities = @($analysis.Entities | Where-Object { $_.ChangeType -eq "A" })
$modEntities = @($analysis.Entities | Where-Object { $_.ChangeType -eq "M" })
if ($newEntities.Count -gt 0 -or $modEntities.Count -gt 0) {
    if ($newEntities.Count -gt 0) {
        $customNew = @($newEntities | Where-Object { $_.IsCustomEntity })
        $oobNew = @($newEntities | Where-Object { $_.IsOOBEntity })
        if ($customNew.Count -gt 0) {
            $entityNames = ($customNew | ForEach-Object { $_.SchemaName }) -join ", "
            $narrativeParts += "**$($customNew.Count) new custom table(s)** added to the solution ($entityNames)."
        }
        if ($oobNew.Count -gt 0) {
            $oobNames = ($oobNew | ForEach-Object { $_.SchemaName }) -join ", "
            $narrativeParts += "**$($oobNew.Count) out-of-box/system table(s)** added with customizations ($oobNames)."
        }
    }
    if ($modEntities.Count -gt 0) {
        $totalNewFields = ($modEntities | ForEach-Object { $_.CustomAttributeCount } | Measure-Object -Sum).Sum
        if ($totalNewFields -gt 0) {
            $narrativeParts += "**$($modEntities.Count) table(s)** modified with approximately **$totalNewFields custom field(s)**."
        }
    }
}

# Check for PCF Control changes
$newPCF = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "A" })
$modPCF = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "M" })
if ($newPCF.Count -gt 0 -or $modPCF.Count -gt 0) {
    if ($newPCF.Count -gt 0) {
        $pcfNames = ($newPCF | ForEach-Object { $_.FullName }) -join ", "
        $narrativeParts += "**$($newPCF.Count) new PCF control(s)** added ($pcfNames)."
    }
    if ($modPCF.Count -gt 0) {
        $pcfNames = ($modPCF | ForEach-Object { "$($_.FullName) v$($_.Version)" }) -join ", "
        $narrativeParts += "**$($modPCF.Count) PCF control(s)** updated ($pcfNames)."
    }
}

# Check for Option Set changes
$newOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "A" })
$modOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "M" })
if ($newOS.Count -gt 0 -or $modOS.Count -gt 0) {
    if ($newOS.Count -gt 0) {
        $osNames = ($newOS | ForEach-Object { $_.DisplayName }) -join ", "
        $narrativeParts += "**$($newOS.Count) new global option set(s)** added ($osNames)."
    }
    if ($modOS.Count -gt 0) {
        $narrativeParts += "**$($modOS.Count) global option set(s)** modified."
    }
}

# Check for new features (Custom APIs)
$newAPIs = @($analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "A" })
if ($newAPIs.Count -gt 0) {
    $apiNames = ($newAPIs | ForEach-Object { $_.UniqueName }) -join ", "
    $narrativeParts += "This pull request introduces **$($newAPIs.Count) new Custom API(s)** ($apiNames), expanding the system's integration capabilities."
}

# Check for plugin changes
$newPlugins = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "A" })
$modPlugins = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "M" })
if ($newPlugins.Count -gt 0 -or $modPlugins.Count -gt 0) {
    if ($newPlugins.Count -gt 0 -and $modPlugins.Count -gt 0) {
        $narrativeParts += "The solution includes **$($newPlugins.Count) new plugin step(s)** and modifies **$($modPlugins.Count) existing step(s)**, affecting business logic execution."
    } elseif ($newPlugins.Count -gt 0) {
        $narrativeParts += "The solution adds **$($newPlugins.Count) new plugin step(s)**, introducing new automated business logic."
    } else {
        $narrativeParts += "The solution modifies **$($modPlugins.Count) existing plugin step(s)**, updating business logic behavior."
    }
}

# Check for workflow changes
$modWorkflows = @($analysis.Workflows | Where-Object { $_.ChangeType -eq "M" })
$newWorkflows = @($analysis.Workflows | Where-Object { $_.ChangeType -eq "A" })
if ($modWorkflows.Count -gt 0 -or $newWorkflows.Count -gt 0) {
    if ($newWorkflows.Count -gt 0) {
        $narrativeParts += "**$($newWorkflows.Count) new Power Automate cloud flow(s)** have been added to the solution."
    }
    if ($modWorkflows.Count -gt 0) {
        $workflowNames = ($modWorkflows | ForEach-Object { $_.Name }) -join ", "
        $narrativeParts += "Modifications to existing workflows ($workflowNames) update automated processes."
    }
}

# Check for UI changes
$totalUIChanges = $analysis.Forms.Count + $analysis.EntityViews.Count + $analysis.CanvasApps.Count
if ($totalUIChanges -gt 0) {
    $uiComponents = @()
    if ($analysis.Forms.Count -gt 0) { $uiComponents += "$($analysis.Forms.Count) form(s)" }
    if ($analysis.EntityViews.Count -gt 0) { $uiComponents += "$($analysis.EntityViews.Count) view(s)" }
    if ($analysis.CanvasApps.Count -gt 0) { $uiComponents += "$($analysis.CanvasApps.Count) canvas app(s)" }

    $narrativeParts += "User interface enhancements include changes to " + ($uiComponents -join ", ") + ", improving user experience and data presentation."
}

# Check for deletions
if ($analysis.DeletedComponents.Count -gt 0) {
    $deletedTypes = ($analysis.DeletedComponents | Group-Object -Property Type | ForEach-Object { $_.Name }) -join ", "
    $narrativeParts += "The solution removes **$($analysis.DeletedComponents.Count) component(s)** ($deletedTypes), streamlining the solution architecture."
}

# Output narrative
if ($narrativeParts.Count -gt 0) {
    foreach ($part in $narrativeParts) {
        $report += "$part`n`n"
    }
} else {
    $report += "This pull request contains maintenance updates to the solution.`n`n"
}

$report += "---`n`n"

# Best Practice Warnings Section (Most Critical - Show First)
if ($analysis.BestPracticeWarnings.Count -gt 0) {
    $report += "## ⚠️ Best Practice Warnings`n`n"
    $report += "**The following issues were detected that violate Dataverse solution best practices:**`n`n"

    foreach ($warning in $analysis.BestPracticeWarnings) {
        $report += "### [$($warning.Severity)] $($warning.Issue)`n`n"
        $report += "- **Entity:** $($warning.Entity)`n"
        $report += "- **Details:** $($warning.Details)`n"
        $report += "- **Recommendation:** $($warning.Recommendation)`n`n"
    }

    $report += @"

> **Why This Matters:**
> - Adding OOB/managed entities with all assets (behavior=0) causes **solution bloat**
> - This creates **unmanaged layers** on top of managed components
> - It **blocks Microsoft updates** to managed components
> - It creates **unnecessary dependencies** and can cause **import failures**
> - Proper approach: Use behavior='1' (selective) or behavior='2' (shell only) for OOB entities

"@
    $report += "---`n`n"
}

# Tables/Entities Section
if ($analysis.Entities.Count -gt 0) {
    $report += "## Table/Entity Changes`n`n"

    $newEntities = @($analysis.Entities | Where-Object { $_.ChangeType -eq "A" })
    $modEntities = @($analysis.Entities | Where-Object { $_.ChangeType -eq "M" })
    $delEntities = @($analysis.Entities | Where-Object { $_.ChangeType -eq "D" })

    if ($newEntities.Count -gt 0) {
        $report += "### New Tables`n`n"
        foreach ($entity in $newEntities) {
            $entityType = if ($entity.IsCustomEntity) { "Custom" } else { "OOB/System" }
            $report += "#### $($entity.DisplayName) ($($entity.SchemaName))`n`n"
            $report += "- **Type:** $entityType`n"
            $report += "- **Total Attributes:** $($entity.AttributeCount)`n"
            $report += "- **Custom Attributes:** $($entity.CustomAttributeCount)`n"

            if ($entity.HasWarning) {
                $report += "- **⚠️ WARNING:** $($entity.Warning)`n"
            }

            if ($entity.NewAttributes.Count -gt 0 -and $entity.NewAttributes.Count -le 20) {
                $report += "- **Custom Fields:**`n"
                foreach ($attr in $entity.NewAttributes) {
                    $report += "  - $($attr.DisplayName) ($($attr.Name)) - $($attr.Type)`n"
                }
            }

            $report += "`n"
        }
    }

    if ($modEntities.Count -gt 0) {
        $report += "### Modified Tables`n`n"
        foreach ($entity in $modEntities) {
            $entityType = if ($entity.IsCustomEntity) { "Custom" } else { "OOB/System" }
            $report += "#### $($entity.DisplayName) ($($entity.SchemaName))`n`n"
            $report += "- **Type:** $entityType`n"
            $report += "- **Custom Attributes in Solution:** $($entity.CustomAttributeCount)`n"

            if ($entity.HasWarning) {
                $report += "- **⚠️ WARNING:** $($entity.Warning)`n"
            }

            if ($entity.NewAttributes.Count -gt 0 -and $entity.NewAttributes.Count -le 15) {
                $report += "- **Custom Fields:**`n"
                foreach ($attr in $entity.NewAttributes) {
                    $report += "  - $($attr.DisplayName) ($($attr.Name)) - $($attr.Type)`n"
                }
            } elseif ($entity.NewAttributes.Count -gt 15) {
                $report += "- **Custom Fields:** $($entity.NewAttributes.Count) fields (too many to list)`n"
            }

            $report += "`n"
        }
    }

    if ($delEntities.Count -gt 0) {
        $report += "### Deleted Tables`n`n"
        foreach ($entity in $delEntities) {
            $report += "- $($entity.SchemaName)`n"
        }
        $report += "`n"
    }

    $report += "---`n`n"
}

# PCF Controls Section
if ($analysis.PCFControls.Count -gt 0) {
    $report += "## PCF Control Changes`n`n"

    $newPCF = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "A" })
    $modPCF = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "M" })
    $delPCF = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "D" })

    if ($newPCF.Count -gt 0) {
        $report += "### New PCF Controls`n`n"
        foreach ($pcf in $newPCF) {
            $report += "#### $($pcf.FullName)`n`n"
            $report += "- **Version:** $($pcf.Version)`n"
            $report += "- **Namespace:** $($pcf.Namespace)`n"
            $report += "- **Constructor:** $($pcf.Constructor)`n"
            $report += "- **Control Type:** $($pcf.ControlType)`n"
            $report += "- **Display Name:** $($pcf.DisplayName)`n"

            if ($pcf.Properties.Count -gt 0) {
                $report += "- **Properties:**`n"
                foreach ($prop in $pcf.Properties) {
                    $required = if ($prop.Required -eq "true") { "Required" } else { "Optional" }
                    $report += "  - **$($prop.Name)** ($($prop.Type)) - $($prop.Usage), $required`n"
                }
            }

            $report += "`n"
        }
    }

    if ($modPCF.Count -gt 0) {
        $report += "### Modified PCF Controls`n`n"
        foreach ($pcf in $modPCF) {
            $report += "#### $($pcf.FullName)`n`n"
            $report += "- **Version:** $($pcf.Version)`n"
            $report += "- **Control Type:** $($pcf.ControlType)`n"

            if ($pcf.Properties.Count -gt 0) {
                $report += "- **Properties:** $($pcf.Properties.Count) defined`n"
            }

            $report += "`n"
        }
    }

    if ($delPCF.Count -gt 0) {
        $report += "### Deleted PCF Controls`n`n"
        foreach ($pcf in $delPCF) {
            $report += "- $($pcf.FolderName)`n"
        }
        $report += "`n"
    }

    $report += "---`n`n"
}

# Global Option Sets Section
if ($analysis.OptionSets.Count -gt 0) {
    $report += "## Global Option Set Changes`n`n"

    $newOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "A" })
    $modOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "M" })
    $delOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "D" })

    if ($newOS.Count -gt 0) {
        $report += "### New Global Option Sets`n`n"
        foreach ($os in $newOS) {
            $report += "#### $($os.DisplayName) ($($os.Name))`n`n"
            $report += "- **Type:** $($os.Type)`n"
            $report += "- **Is Global:** $($os.IsGlobal)`n"

            if ($os.Options.Count -gt 0) {
                $report += "- **Options:**`n"
                foreach ($opt in $os.Options) {
                    $report += "  - $($opt.Value): $($opt.Label)`n"
                }
            }

            $report += "`n"
        }
    }

    if ($modOS.Count -gt 0) {
        $report += "### Modified Global Option Sets`n`n"
        foreach ($os in $modOS) {
            $report += "#### $($os.DisplayName) ($($os.Name))`n`n"
            $report += "- **Type:** $($os.Type)`n"

            if ($os.Options.Count -gt 0) {
                $report += "- **Options:**`n"
                foreach ($opt in $os.Options) {
                    $report += "  - $($opt.Value): $($opt.Label)`n"
                }
            }

            $report += "`n"
        }
    }

    if ($delOS.Count -gt 0) {
        $report += "### Deleted Global Option Sets`n`n"
        foreach ($os in $delOS) {
            $report += "- $($os.Name)`n"
        }
        $report += "`n"
    }

    $report += "---`n`n"
}

# Custom APIs Section
if ($analysis.CustomAPIs.Count -gt 0) {
    $report += "## Custom API Changes`n`n"

    $newAPIs = @($analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "A" })
    $modAPIs = @($analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "M" })
    $delAPIs = @($analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "D" })

    if ($newAPIs.Count -gt 0) {
        $report += "### New Custom APIs`n`n"
        foreach ($api in $newAPIs) {
            $report += "#### $($api.UniqueName)`n`n"
            $report += "- **Display Name:** $($api.DisplayName)`n"
            $report += "- **Description:** $($api.Description)`n"
            $report += "- **Type:** $($api.IsFunction)`n"
            $report += "- **Binding:** $($api.BindingType)`n"
            $report += "- **Private:** $($api.IsPrivate)`n"

            if ($api.Parameters.Count -gt 0) {
                $report += "- **Request Parameters:**`n"
                foreach ($param in $api.Parameters) {
                    $report += "  - **$($param.Name)** (Type: $($param.Type), Required: $($param.Required))`n"
                    if ($param.Description) {
                        $report += "    - $($param.Description)`n"
                    }
                }
            }

            if ($api.ResponseProperties.Count -gt 0) {
                $report += "- **Response Properties:**`n"
                foreach ($prop in $api.ResponseProperties) {
                    $report += "  - **$($prop.Name)** (Type: $($prop.Type))`n"
                    if ($prop.Description) {
                        $report += "    - $($prop.Description)`n"
                    }
                }
            }

            $report += "`n"
        }
    }

    if ($modAPIs.Count -gt 0) {
        $report += "### Modified Custom APIs`n`n"
        foreach ($api in $modAPIs) {
            $report += "- $($api.UniqueName)`n"
        }
        $report += "`n"
    }

    if ($delAPIs.Count -gt 0) {
        $report += "### Deleted Custom APIs`n`n"
        foreach ($api in $delAPIs) {
            $report += "- $($api.UniqueName)`n"
        }
        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Plugin Steps Section
if ($analysis.PluginSteps.Count -gt 0) {
    $report += "## Plugin Step Changes`n`n"

    $newSteps = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "A" })
    $modSteps = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "M" })
    $delSteps = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "D" })

    if ($newSteps.Count -gt 0) {
        $report += "### New Plugin Steps`n`n"
        foreach ($step in $newSteps) {
            $report += "#### $($step.Name)`n`n"
            $report += "- **Step ID:** $($step.StepId)`n"
            $report += "- **Primary Entity:** $($step.PrimaryEntity)`n"
            $report += "- **Stage:** $($step.Stage) ($($step.StageCode))`n"
            $report += "- **Mode:** $($step.Mode)`n"
            $report += "- **Execution Order:** $($step.ExecutionOrder)`n"

            if ($step.Description) {
                $report += "- **Description:** $($step.Description)`n"
            }

            if ($step.FilteredAttributes.Count -gt 0) {
                $report += "- **Filtered Attributes:** $($step.FilteredAttributes -join ', ')`n"
            }

            $report += "`n"
        }
    }

    if ($modSteps.Count -gt 0) {
        $report += "### Modified Plugin Steps`n`n"
        foreach ($step in $modSteps) {
            $report += "#### $($step.Name)`n`n"
            $report += "- **Step ID:** $($step.StepId)`n"
            $report += "- **Primary Entity:** $($step.PrimaryEntity)`n"
            $report += "- **Stage:** $($step.Stage) ($($step.StageCode))`n"
            $report += "- **Mode:** $($step.Mode)`n"
            $report += "- **Execution Order:** $($step.ExecutionOrder)`n"

            if ($step.Description) {
                $report += "- **Description:** $($step.Description)`n"
            }

            if ($step.FilteredAttributes.Count -gt 0) {
                $report += "- **Filtered Attributes:** $($step.FilteredAttributes -join ', ')`n"
            }

            $report += "`n"
        }
    }

    if ($delSteps.Count -gt 0) {
        $report += "### Deleted Plugin Steps`n`n"
        foreach ($step in $delSteps) {
            $report += "- $($step.Name) (ID: $($step.StepId))`n"
        }
        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Forms Section
if ($analysis.Forms.Count -gt 0) {
    $report += "## Form Changes`n`n"

    foreach ($form in $analysis.Forms) {
        $badge = switch ($form.ChangeType) {
            "A" { "[NEW]" }
            "M" { "[MODIFIED]" }
            "D" { "[DELETED]" }
            default { "[CHANGED]" }
        }

        $report += "### $badge $($form.FormName)`n`n"
        $report += "- **Entity:** $($form.EntityName)`n"
        $report += "- **Form ID:** $($form.FormId)`n"
        $report += "- **Form Type:** $($form.FormType)`n"

        if ($form.Subgrids -is [System.Collections.ICollection] -and $form.Subgrids.Count -gt 0) {
            $report += "- **Subgrids:** $($form.Subgrids.Count)`n"
        } elseif ($form.Subgrids -is [int] -and $form.Subgrids -gt 0) {
            $report += "- **Subgrids:** $($form.Subgrids)`n"
        }

        if ($form.Controls -is [System.Collections.ICollection] -and $form.Controls.Count -gt 0) {
            $report += "- **Controls:** $($form.Controls.Count)`n"
        } elseif ($form.Controls -is [int] -and $form.Controls -gt 0) {
            $report += "- **Controls:** $($form.Controls)`n"
        }

        # Add BEFORE/AFTER comparison for modified forms
        if ($form.ChangeType -eq "M" -and $form.Comparison -and $form.Comparison.HasChanges) {
            $comp = $form.Comparison

            $report += "`n**BEFORE/AFTER Comparison:**`n`n"

            # Subgrids comparison
            if ($comp.AddedSubgrids.Count -gt 0 -or $comp.RemovedSubgrids.Count -gt 0) {
                $report += "**Subgrids:**`n"
                $report += "- BEFORE: $($comp.OldSubgridCount) subgrid(s)`n"
                $report += "- AFTER: $($comp.NewSubgridCount) subgrid(s)`n"

                if ($comp.AddedSubgrids.Count -gt 0) {
                    $report += "- **Added:** $($comp.AddedSubgrids -join ', ')`n"
                }
                if ($comp.RemovedSubgrids.Count -gt 0) {
                    $report += "- **Removed:** $($comp.RemovedSubgrids -join ', ')`n"
                }
                $report += "`n"
            }

            # Controls comparison
            if ($comp.AddedControls.Count -gt 0 -or $comp.RemovedControls.Count -gt 0) {
                $report += "**Controls:**`n"
                $report += "- BEFORE: $($comp.OldControlCount) control(s)`n"
                $report += "- AFTER: $($comp.NewControlCount) control(s)`n"

                if ($comp.AddedControls.Count -gt 0) {
                    $addedList = $comp.AddedControls | Select-Object -First 10
                    $moreCount = $comp.AddedControls.Count - $addedList.Count
                    $report += "- **Added:** $($addedList -join ', ')"
                    if ($moreCount -gt 0) {
                        $report += " (and $moreCount more)`n"
                    } else {
                        $report += "`n"
                    }
                }
                if ($comp.RemovedControls.Count -gt 0) {
                    $removedList = $comp.RemovedControls | Select-Object -First 10
                    $moreCount = $comp.RemovedControls.Count - $removedList.Count
                    $report += "- **Removed:** $($removedList -join ', ')"
                    if ($moreCount -gt 0) {
                        $report += " (and $moreCount more)`n"
                    } else {
                        $report += "`n"
                    }
                }
                $report += "`n"
            }

            # Tabs comparison
            if ($comp.AddedTabs.Count -gt 0 -or $comp.RemovedTabs.Count -gt 0) {
                $report += "**Tabs:**`n"
                $report += "- BEFORE: $($comp.OldTabCount) tab(s)`n"
                $report += "- AFTER: $($comp.NewTabCount) tab(s)`n"

                if ($comp.AddedTabs.Count -gt 0) {
                    $report += "- **Added:** $($comp.AddedTabs -join ', ')`n"
                }
                if ($comp.RemovedTabs.Count -gt 0) {
                    $report += "- **Removed:** $($comp.RemovedTabs -join ', ')`n"
                }
                $report += "`n"
            }
        }

        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Web Resources Section
if ($analysis.WebResources.Count -gt 0) {
    $report += "## Web Resource Changes`n`n"

    $newWR = @($analysis.WebResources | Where-Object { $_.ChangeType -eq "A" })
    $modWR = @($analysis.WebResources | Where-Object { $_.ChangeType -eq "M" })
    $delWR = @($analysis.WebResources | Where-Object { $_.ChangeType -eq "D" })

    if ($newWR.Count -gt 0) {
        $report += "### New Web Resources`n`n"
        foreach ($wr in $newWR) {
            $report += "- **$($wr.LogicalName)** (Type: $($wr.Type))`n"
        }
        $report += "`n"
    }

    if ($modWR.Count -gt 0) {
        $report += "### Modified Web Resources`n`n"
        foreach ($wr in $modWR) {
            $report += "- **$($wr.LogicalName)** (Type: $($wr.Type))`n"
        }
        $report += "`n"
    }

    if ($delWR.Count -gt 0) {
        $report += "### Deleted Web Resources`n`n"
        foreach ($wr in $delWR) {
            $report += "- **$($wr.LogicalName)**`n"
        }
        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Workflows Section
if ($analysis.Workflows.Count -gt 0) {
    $report += "## Power Automate Workflow Changes`n`n"

    foreach ($wf in $analysis.Workflows) {
        $badge = switch ($wf.ChangeType) {
            "A" { "[NEW]" }
            "M" { "[MODIFIED]" }
            "D" { "[DELETED]" }
            default { "[CHANGED]" }
        }

        $report += "### $badge $($wf.Name)`n`n"
        $report += "- **Type:** $($wf.Type)`n"
        if ($wf.Trigger) {
            $report += "- **Trigger:** $($wf.Trigger)`n"
        }

        if ($wf.FieldReferences.Count -gt 0) {
            $report += "- **Field References:** $($wf.FieldReferences -join ', ')`n"
        }

        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Deleted Components Section
if ($analysis.DeletedComponents.Count -gt 0) {
    $report += "## Deleted Components`n`n"

    # Group deleted components by type
    $deletedByType = $analysis.DeletedComponents | Group-Object -Property Type

    foreach ($group in $deletedByType) {
        $report += "### $($group.Name)`n`n"

        foreach ($component in $group.Group) {
            $report += "- **$($component.Path)**`n"
            if ($component.Explanation) {
                $report += "  - *$($component.Explanation)*`n"
            }
        }

        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Entity Views Section
if ($analysis.EntityViews.Count -gt 0) {
    $report += "## Entity View Changes`n`n"

    foreach ($view in $analysis.EntityViews) {
        $badge = switch ($view.ChangeType) {
            "A" { "[NEW]" }
            "M" { "[MODIFIED]" }
            "D" { "[DELETED]" }
            default { "[CHANGED]" }
        }

        $report += "### $badge $($view.EntityName) - $($view.Name)`n`n"
        $report += "- **View ID:** $($view.ViewId)`n"
        $report += "- **Type:** $($view.ViewType)`n"
        $report += "- **Public:** $($view.IsPublic)`n"

        # Display view configuration
        if ($view.SortOrder.Count -gt 0) {
            $report += "`n**View Configuration:**`n"
            $report += "- **Sort Order:**`n"
            foreach ($sort in $view.SortOrder) {
                $report += "  - $($sort.Attribute) - $($sort.Direction)`n"
            }
        }

        if ($view.FilterConditions.Count -gt 0) {
            if ($view.SortOrder.Count -eq 0) {
                $report += "`n**View Configuration:**`n"
            }
            $report += "- **Filters:**`n"
            foreach ($condition in $view.FilterConditions) {
                $report += "  - $($condition.Attribute) $($condition.Operator) '$($condition.Value)'`n"
            }
        }

        # Display columns with widths
        if ($view.Columns.Count -gt 0) {
            $report += "`n- **Columns:**`n"
            foreach ($column in $view.Columns) {
                $width = if ($view.ColumnWidths -and $view.ColumnWidths.ContainsKey($column)) {
                    "$($view.ColumnWidths[$column])px"
                } else {
                    "auto"
                }
                $report += "  - $column ($width)`n"
            }
        }

        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Canvas Apps Section
if ($analysis.CanvasApps.Count -gt 0) {
    $report += "## Canvas App Changes`n`n"

    foreach ($app in $analysis.CanvasApps) {
        $badge = switch ($app.ChangeType) {
            "A" { "[NEW]" }
            "M" { "[MODIFIED]" }
            "D" { "[DELETED]" }
            default { "[CHANGED]" }
        }

        $report += "### $badge $($app.DisplayName)`n`n"
        if ($app.Name) {
            $report += "- **Technical Name:** $($app.Name)`n"
        }
        $report += "- **App Type:** $($app.AppType)`n"
        if ($app.AppVersion) {
            $report += "- **Version:** $($app.AppVersion)`n"
        }

        if ($app.DataSourceReferences -and $app.DataSourceReferences.Count -gt 0) {
            $report += "- **Entity Dependencies:** $($app.DataSourceReferences -join ', ')`n"
        }

        $report += "`n"
    }

    $report += "`n---`n`n"
}

# App Modules Section
if ($analysis.AppModules.Count -gt 0) {
    $report += "## App Module Changes`n`n"

    foreach ($module in $analysis.AppModules) {
        $badge = switch ($module.ChangeType) {
            "A" { "[NEW]" }
            "M" { "[MODIFIED]" }
            "D" { "[DELETED]" }
            default { "[CHANGED]" }
        }

        $report += "### $badge $($module.DisplayName)`n`n"
        if ($module.UniqueName) {
            $report += "- **Unique Name:** $($module.UniqueName)`n"
        }

        if ($module.ComponentCount -gt 0) {
            $report += "- **Components:** $($module.ComponentCount)`n"
            if ($module.Components -and $module.Components.Count -gt 0) {
                foreach ($comp in $module.Components) {
                    if ($comp -is [hashtable]) {
                        $compTypeMap = @{
                            "1" = "Entity"
                            "60" = "Form"
                            "62" = "Canvas App"
                            "59" = "View"
                        }
                        $compTypeDisplay = if ($compTypeMap.ContainsKey($comp.Type)) { $compTypeMap[$comp.Type] } else { "Component($($comp.Type))" }

                        if ($comp.Name) {
                            $report += "  - $($comp.Name) ($compTypeDisplay)`n"
                        } elseif ($comp.Id) {
                            $report += "  - $($comp.Id) ($compTypeDisplay)`n"
                        }
                    }
                }
            }
        }

        $report += "`n"
    }

    $report += "`n---`n`n"
}

# Risk Assessment Section
$report += @"
## Risk Assessment

"@

# Analyze risks based on components
$risks = @{
    Critical = @()
    HighRisk = @()
    MediumRisk = @()
    LowRisk = @()
}

# CRITICAL: Best Practice Violations
if ($analysis.BestPracticeWarnings.Count -gt 0) {
    foreach ($warning in $analysis.BestPracticeWarnings) {
        if ($warning.Severity -eq "HIGH") {
            $risks.Critical += "SOLUTION BEST PRACTICE VIOLATION: $($warning.Issue) - Entity '$($warning.Entity)'"
        }
    }
}

# HIGH RISK: OOB entities added with all assets
$oobEntitiesWithAllAssets = @($analysis.Entities | Where-Object { $_.IsOOBEntity -and $_.Behavior -eq "0" })
if ($oobEntitiesWithAllAssets.Count -gt 0) {
    foreach ($entity in $oobEntitiesWithAllAssets) {
        $risks.HighRisk += "OOB Entity with All Assets: '$($entity.SchemaName)' - causes solution bloat and layering issues"
    }
}

# Check for high-risk changes
foreach ($step in $analysis.PluginSteps | Where-Object { $_.ChangeType -eq "M" }) {
    if ($step.ModeCode -ne "0") {
        $risks.HighRisk += "Plugin Step Mode Change: '$($step.Name)' changed from Synchronous to Asynchronous - could cause timing issues"
    }
}

# Check for new tables
$newTables = @($analysis.Entities | Where-Object { $_.ChangeType -eq "A" })
if ($newTables.Count -gt 0) {
    $customTables = @($newTables | Where-Object { $_.IsCustomEntity })
    if ($customTables.Count -gt 0) {
        $risks.MediumRisk += "New Custom Tables: $($customTables.Count) new table(s) with custom fields - require comprehensive testing"
    }
}

# Check for new Complex APIs
if ($analysis.CustomAPIs.Count -gt 0) {
    $newAPIs = @($analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "A" })
    if ($newAPIs.Count -gt 0) {
        $risks.MediumRisk += "New Custom API: $($newAPIs.Count) new API(s) requiring thorough testing of complex logic"
    }
}

# Check for plugin step additions
$newSteps = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "A" })
if ($newSteps.Count -gt 0) {
    $risks.MediumRisk += "New Plugin Steps: $($newSteps.Count) new plugin step(s) with potential side effects"
}

# Check for PCF Control changes
$newPCFControls = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "A" })
$modPCFControls = @($analysis.PCFControls | Where-Object { $_.ChangeType -eq "M" })
if ($newPCFControls.Count -gt 0) {
    $risks.MediumRisk += "New PCF Controls: $($newPCFControls.Count) new control(s) - require UI/UX testing"
}
if ($modPCFControls.Count -gt 0) {
    $risks.MediumRisk += "Modified PCF Controls: $($modPCFControls.Count) updated control(s) - verify UI behavior"
}

# Check for form changes
$modifiedForms = @($analysis.Forms | Where-Object { $_.ChangeType -eq "M" })
if ($modifiedForms.Count -gt 0) {
    $risks.MediumRisk += "Form Changes: $($modifiedForms.Count) modified form(s) affecting UI/UX"
}

# Check for Option Set changes
$newOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "A" })
$modOS = @($analysis.OptionSets | Where-Object { $_.ChangeType -eq "M" })
if ($newOS.Count -gt 0) {
    $risks.LowRisk += "New Option Sets: $($newOS.Count) new choice field(s)"
}
if ($modOS.Count -gt 0) {
    $risks.LowRisk += "Modified Option Sets: $($modOS.Count) updated choice field(s) - verify existing data compatibility"
}

# Check for web resource changes
$modifiedWR = @($analysis.WebResources | Where-Object { $_.ChangeType -eq "M" })
if ($modifiedWR.Count -gt 0) {
    $risks.LowRisk += "Web Resource Updates: $($modifiedWR.Count) updated resource(s) - review logic changes"
}

# Check for canvas app changes
$newApps = @($analysis.CanvasApps | Where-Object { $_.ChangeType -eq "A" })
if ($newApps.Count -gt 0) {
    $risks.LowRisk += "Canvas App Addition: New app(s) - isolated impact"
}

# Generate risk assessment report
if ($risks.Critical.Count -gt 0) {
    $report += "### [CRITICAL] CRITICAL ISSUES - DO NOT DEPLOY`n`n"
    foreach ($risk in $risks.Critical) {
        $report += "- **$risk**`n"
    }
    $report += "  - **Recommendation:** STOP - Fix these issues before proceeding with deployment`n"
    $report += "  - **Mitigation:** Remove OOB entities and re-add only specific customized components`n"
    $report += "`n"
}

if ($risks.HighRisk.Count -gt 0) {
    $report += "### [HIGH RISK] HIGH RISK CHANGES`n`n"
    foreach ($risk in $risks.HighRisk) {
        $report += "- **$risk**`n"
    }
    $report += "  - **Recommendation:** Comprehensive testing required before production deployment`n"
    $report += "  - **Mitigation:** Review change logic, test with representative data, monitor post-deployment`n"
    $report += "`n"
}

if ($risks.MediumRisk.Count -gt 0) {
    $report += "### [MEDIUM RISK] MEDIUM RISK CHANGES`n`n"
    foreach ($risk in $risks.MediumRisk) {
        $report += "- **$risk**`n"
    }
    $report += "  - **Recommendation:** Thorough testing in UAT environment`n"
    $report += "  - **Mitigation:** Execute test plan covering all affected scenarios`n"
    $report += "`n"
}

if ($risks.LowRisk.Count -gt 0) {
    $report += "### [LOW RISK] LOW RISK CHANGES`n`n"
    foreach ($risk in $risks.LowRisk) {
        $report += "- **$risk**`n"
    }
    $report += "  - **Recommendation:** Standard testing procedures`n"
    $report += "`n"
}

if ($risks.Critical.Count -eq 0 -and $risks.HighRisk.Count -eq 0 -and $risks.MediumRisk.Count -eq 0 -and $risks.LowRisk.Count -eq 0) {
    $report += "No significant changes detected. Standard testing recommended.`n`n"
}

$report += "---`n`n"

# Testing Recommendations Section
$report += "## Testing Recommendations`n`n"

$componentsToTest = @()

# Build list of components that need testing

# Best practice warnings are critical
if ($analysis.BestPracticeWarnings.Count -gt 0) {
    $componentsToTest += "⚠️ CRITICAL: Review and resolve $($analysis.BestPracticeWarnings.Count) best practice violation(s) before deployment"
}

# New tables need comprehensive testing
if (@($analysis.Entities | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    foreach ($entity in $analysis.Entities | Where-Object { $_.ChangeType -eq "A" }) {
        $componentsToTest += "Table (New): $($entity.SchemaName) - $($entity.CustomAttributeCount) custom field(s)"
    }
}

# Modified tables need field validation
if (@($analysis.Entities | Where-Object { $_.ChangeType -eq "M" }).Count -gt 0) {
    foreach ($entity in $analysis.Entities | Where-Object { $_.ChangeType -eq "M" }) {
        $componentsToTest += "Table (Modified): $($entity.SchemaName) - verify field changes"
    }
}

# PCF Controls need UI testing
if (@($analysis.PCFControls | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    foreach ($pcf in $analysis.PCFControls | Where-Object { $_.ChangeType -eq "A" }) {
        $componentsToTest += "PCF Control (New): $($pcf.FullName) v$($pcf.Version)"
    }
}

if (@($analysis.PCFControls | Where-Object { $_.ChangeType -eq "M" }).Count -gt 0) {
    foreach ($pcf in $analysis.PCFControls | Where-Object { $_.ChangeType -eq "M" }) {
        $componentsToTest += "PCF Control (Modified): $($pcf.FullName) v$($pcf.Version)"
    }
}

# Option Sets need validation in forms
if (@($analysis.OptionSets | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    $componentsToTest += "Option Sets (New): $(@($analysis.OptionSets | Where-Object { $_.ChangeType -eq "A" }).Count) - verify in forms using them"
}

if (@($analysis.OptionSets | Where-Object { $_.ChangeType -eq "M" }).Count -gt 0) {
    $componentsToTest += "Option Sets (Modified): $(@($analysis.OptionSets | Where-Object { $_.ChangeType -eq "M" }).Count) - verify option values still valid"
}

# Custom APIs
if (@($analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    foreach ($api in $analysis.CustomAPIs | Where-Object { $_.ChangeType -eq "A" }) {
        $componentsToTest += "Custom API (New): $($api.UniqueName)"
    }
}

# Plugin Steps
if (@($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    foreach ($step in $analysis.PluginSteps | Where-Object { $_.ChangeType -eq "A" }) {
        $componentsToTest += "Plugin Step (New): $($step.Name)"
    }
}

if (@($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "M" }).Count -gt 0) {
    foreach ($step in $analysis.PluginSteps | Where-Object { $_.ChangeType -eq "M" }) {
        $componentsToTest += "Plugin Step (Modified): $($step.Name)"
    }
}

if (@($analysis.Forms | Where-Object { $_.ChangeType -eq "M" }).Count -gt 0) {
    $componentsToTest += "Forms: $(@($analysis.Forms | Where-Object { $_.ChangeType -eq "M" }).Count) modified form(s)"
}

if (@($analysis.Forms | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    $componentsToTest += "Forms: $(@($analysis.Forms | Where-Object { $_.ChangeType -eq "A" }).Count) new form(s)"
}

if (@($analysis.CanvasApps | Where-Object { $_.ChangeType -eq "A" }).Count -gt 0) {
    $componentsToTest += "Canvas Apps: $(@($analysis.CanvasApps | Where-Object { $_.ChangeType -eq "A" }).Count) new app(s)"
}

if (@($analysis.WebResources | Where-Object { $_.ChangeType -eq "M" }).Count -gt 0) {
    $componentsToTest += "Web Resources: $(@($analysis.WebResources | Where-Object { $_.ChangeType -eq "M" }).Count) modified resource(s)"
}

if ($analysis.EntityViews.Count -gt 0) {
    $componentsToTest += "Entity Views: $($analysis.EntityViews.Count) view(s)"
}

if ($componentsToTest.Count -gt 0) {
    $report += "**Components requiring testing:**`n`n"
    foreach ($component in $componentsToTest) {
        $report += "- $component`n"
    }
} else {
    $report += "No significant component changes detected.`n"
}

$report += "`n---`n`n"

# Deployment Recommendations Section
$report += "## Deployment Recommendations`n`n"

# Pre-deployment steps
$report += "### Pre-Deployment`n`n"
$report += "1. **Backup current environment** before applying changes`n"
$report += "2. **Review all component changes** in this report`n"

# Check if there are high-risk changes
$hasHighRisk = $false
$pluginModeChanges = @($analysis.PluginSteps | Where-Object { $_.ChangeType -eq "M" -and $_.ModeCode })
foreach ($step in $pluginModeChanges) {
    # This is a simplified check - in reality we'd need to compare old vs new
    if ($step.Mode -eq "Asynchronous") {
        $hasHighRisk = $true
        break
    }
}

if ($hasHighRisk -or $analysis.CustomAPIs.Count -gt 0) {
    $report += "3. **Schedule deployment during low-usage period** due to high-risk changes`n"
}

$report += "`n"

# Deployment order
$report += "### Deployment Order`n`n"
$deploymentSteps = @()

if ($analysis.CustomAPIs.Count -gt 0) {
    $deploymentSteps += "1. **Custom APIs** - Deploy API definitions first as they may be dependencies"
}

if ($analysis.PluginSteps.Count -gt 0) {
    $stepNum = $deploymentSteps.Count + 1
    $deploymentSteps += "$stepNum. **Plugin Steps** - Ensure plugin assemblies are deployed before activating steps"
}

if ($analysis.Forms.Count -gt 0 -or $analysis.EntityViews.Count -gt 0) {
    $stepNum = $deploymentSteps.Count + 1
    $deploymentSteps += "$stepNum. **Forms and Views** - Deploy UI components"
}

if ($analysis.WebResources.Count -gt 0) {
    $stepNum = $deploymentSteps.Count + 1
    $deploymentSteps += "$stepNum. **Web Resources** - Deploy JavaScript/HTML/CSS files"
}

if ($analysis.Workflows.Count -gt 0) {
    $stepNum = $deploymentSteps.Count + 1
    $deploymentSteps += "$stepNum. **Workflows/Cloud Flows** - Activate flows after all dependencies are in place"
}

if ($analysis.CanvasApps.Count -gt 0 -or $analysis.AppModules.Count -gt 0) {
    $stepNum = $deploymentSteps.Count + 1
    $deploymentSteps += "$stepNum. **Apps and Modules** - Deploy navigation and canvas apps last"
}

if ($deploymentSteps.Count -gt 0) {
    foreach ($step in $deploymentSteps) {
        $report += "$step`n"
    }
} else {
    $report += "Standard solution import process - no special ordering required.`n"
}

$report += "`n"

# Post-deployment validation
$report += "### Post-Deployment Validation`n`n"

$validationSteps = @()

if ($analysis.CustomAPIs.Count -gt 0) {
    $validationSteps += "- **Test Custom API endpoints** with sample requests"
}

if ($analysis.PluginSteps.Count -gt 0) {
    $validationSteps += "- **Verify plugin execution** by triggering affected record operations"
}

if ($analysis.Forms.Count -gt 0) {
    $validationSteps += "- **Open and test modified forms** to ensure UI renders correctly"
}

if ($analysis.Workflows.Count -gt 0) {
    $validationSteps += "- **Trigger workflow conditions** to verify cloud flows execute as expected"
}

if ($analysis.EntityViews.Count -gt 0) {
    $validationSteps += "- **Check entity views** for correct sorting, filtering, and column display"
}

if ($hasHighRisk) {
    $validationSteps += "- **Monitor system for 24-48 hours** post-deployment due to high-risk changes"
}

if ($validationSteps.Count -gt 0) {
    foreach ($step in $validationSteps) {
        $report += "$step`n"
    }
} else {
    $report += "- Perform standard smoke testing`n"
}

$report += "`n"

# Rollback considerations
if ($hasHighRisk -or $analysis.PluginSteps.Count -gt 0 -or $analysis.CustomAPIs.Count -gt 0) {
    $report += "### Rollback Plan`n`n"
    $report += "**If issues arise:**`n"
    $report += "1. Deactivate new/modified plugin steps immediately`n"

    if ($analysis.Workflows.Count -gt 0) {
        $report += "2. Turn off modified cloud flows`n"
    }

    $report += "3. Restore previous solution version from backup`n"
    $report += "4. Document and investigate issues before retry`n"
    $report += "`n"
}

$report += "---`n`n"

$report += @"
## Analysis Notes

This report provides a structured summary of changes extracted from the solution files.
Use this data along with business context and system architecture knowledge to generate
a comprehensive analysis of the pull request impact.

**For detailed review:**
- Examine Custom API changes for new integration points or parameter modifications
- Review Plugin Step changes for execution timing and filter attribute changes
- Check Entity View columns to understand UI changes
- Verify Canvas App and App Module changes for navigation and UX impacts
- Validate Web Resource changes for JavaScript/CSS logic modifications

Generated by PR Component Extractor - Enhanced Version
"@

# Save report
$report | Out-File -FilePath $reportPath -Encoding UTF8 -Force

Write-Host "[OK] Analysis complete!"
Write-Host "[OK] Report saved to: $reportPath"
Write-Host "[OK] Report size: $((Get-Item $reportPath).Length) bytes"
Write-Host ""
Write-Host "=================================================="
Write-Host "Report generated successfully!"
Write-Host "Location: $reportFileName"
Write-Host "=================================================="
Write-Host ""
