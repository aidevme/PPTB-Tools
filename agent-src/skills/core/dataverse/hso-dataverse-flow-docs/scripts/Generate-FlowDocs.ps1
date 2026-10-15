# Generate-FlowDocs.ps1
# Generates comprehensive markdown documentation for Power Automate cloud flows
# from unpacked Dataverse solution Workflows folders.

param(
    [Parameter(Mandatory = $true)]
    [string]$SolutionsRoot,

    [Parameter(Mandatory = $true)]
    [string]$SolutionName,

    [string]$OutputRoot,

    [string]$FlowName
)

# Derive paths
$SourcePath = Join-Path $SolutionsRoot "$SolutionName\Workflows"
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $SolutionsRoot ".docs"
}
$OutputPath = Join-Path $OutputRoot "$SolutionName\Workflows"

# Validate source
if (-not (Test-Path $SourcePath)) {
    Write-Host "ERROR: Workflows folder not found at $SourcePath" -ForegroundColor Red
    exit 1
}

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# ── Helper Functions ──────────────────────────────────────────────────────────

function Get-ActionType {
    param($Action)
    if ($null -eq $Action) { return "Unknown" }
    $type = $Action.type
    switch ($type) {
        "OpenApiConnection" {
            $operationId = $Action.inputs.host.operationId
            switch ($operationId) {
                "CreateRecord" { return "Create Record" }
                "UpdateRecord" { return "Update Record" }
                "DeleteRecord" { return "Delete Record" }
                "GetItem"      { return "Get Record" }
                "ListRecords"  { return "List Records" }
                default        { return $operationId }
            }
        }
        "InitializeVariable" { return "Initialize Variable" }
        "SetVariable"        { return "Set Variable" }
        "IncrementVariable"  { return "Increment Variable" }
        "AppendToArrayVariable" { return "Append to Array" }
        "AppendToStringVariable" { return "Append to String" }
        "Compose"            { return "Compose" }
        "If"                 { return "Condition" }
        "Switch"             { return "Switch" }
        "Foreach"            { return "Apply to Each" }
        "Until"              { return "Do Until" }
        "Response"           { return "Response" }
        "Scope"              { return "Scope" }
        "Terminate"          { return "Terminate" }
        "Wait"               { return "Delay" }
        "ParseJson"          { return "Parse JSON" }
        "Select"             { return "Select" }
        "Filter"             { return "Filter Array" }
        "Join"               { return "Join" }
        "Table"              { return "Create HTML/CSV Table" }
        "Http"               { return "HTTP Request" }
        default              { return $type }
    }
}

function Get-TriggerDetails {
    param($Trigger)
    $details = @()
    $triggerType = $Trigger.type

    if ($triggerType -eq "OpenApiConnectionWebhook") {
        $details += "**Type:** Dataverse Trigger (When a row is added, modified or deleted)"
        $params = $Trigger.inputs.parameters
        $message = $params.'subscriptionRequest/message'
        $entityName = $params.'subscriptionRequest/entityname'
        $scope = $params.'subscriptionRequest/scope'
        $filteringAttributes = $params.'subscriptionRequest/filteringattributes'
        $filterExpression = $params.'subscriptionRequest/filterexpression'

        $messageType = switch ($message) {
            1 { "Create" }
            2 { "Delete" }
            3 { "Update" }
            4 { "Create or Update" }
            default { $message }
        }
        $scopeText = switch ($scope) {
            1 { "User" }
            2 { "Business Unit" }
            3 { "Parent: Child Business Units" }
            4 { "Organization" }
            default { $scope }
        }

        $triggerName = $Trigger.description
        if ($triggerName) { $triggerName = $triggerName -replace '_', ' ' }

        if ($triggerName) { $details += "**Trigger Name:** $triggerName" }
        $details += ""
        $details += "**Table Name:** ``$entityName``"
        $details += "**Change Type:** $messageType"
        $details += "**Scope:** $scopeText"

        if ($filteringAttributes) {
            $details += ""
            $details += "**Select Columns (Filtering Attributes):**"
            $details += '```'
            $details += $filteringAttributes
            $details += '```'
            $details += ""
            $details += "*Note: The flow only runs when these specific columns are modified.*"
        }
        if ($filterExpression) {
            $details += ""
            $details += "**Filter Rows (Row Filter Condition):**"
            $details += '```'
            $details += $filterExpression
            $details += '```'
            $details += ""
            $details += "*Note: The flow only runs when rows meet this filter condition.*"
        }
    }
    elseif ($triggerType -eq "OpenApiConnection") {
        $operationId = $Trigger.inputs.host.operationId
        $details += "**Type:** Dataverse Trigger ($operationId)"
        $entityName = $Trigger.inputs.parameters.entityName
        if ($entityName) { $details += "**Table Name:** ``$entityName``" }
    }
    elseif ($triggerType -eq "Request") {
        $details += "**Type:** Manual HTTP Request (Instant flow / Button flow)"
        if ($Trigger.inputs.schema) {
            $details += ""
            $details += "**Input Schema:**"
            $details += '```json'
            $details += ($Trigger.inputs.schema | ConvertTo-Json -Depth 10)
            $details += '```'
        }
    }
    elseif ($triggerType -eq "Recurrence") {
        $frequency = $Trigger.recurrence.frequency
        $interval = $Trigger.recurrence.interval
        $details += "**Type:** Scheduled (Recurrence)"
        $details += "**Frequency:** Every $interval $frequency"
        if ($Trigger.recurrence.startTime) {
            $details += "**Start Time:** $($Trigger.recurrence.startTime)"
        }
        if ($Trigger.recurrence.timeZone) {
            $details += "**Time Zone:** $($Trigger.recurrence.timeZone)"
        }
    }
    else {
        $details += "**Type:** $triggerType"
    }

    return ($details -join "`n")
}

function Build-FlowDiagram {
    param(
        $Actions,
        [int]$IndentLevel = 0
    )
    $diagram = @()
    $indent = "  " * $IndentLevel
    $boxWidth = 45

    if ($null -eq $Actions) { return @() }

    foreach ($actionProp in $Actions.PSObject.Properties) {
        $actionName = $actionProp.Name
        $action = $actionProp.Value
        $actionType = Get-ActionType -Action $action

        $line1 = "$indent" + [char]0x250C + (([char]0x2500).ToString() * $boxWidth) + [char]0x2510
        $actionText = "$actionName"
        $typeText = "($actionType)"

        if ($actionText.Length -gt ($boxWidth - 2)) {
            $actionText = $actionText.Substring(0, $boxWidth - 5) + "..."
        }
        if ($typeText.Length -gt ($boxWidth - 2)) {
            $typeText = $typeText.Substring(0, $boxWidth - 5) + "..."
        }

        $paddingLength2 = [Math]::Max(0, $boxWidth - $actionText.Length - 1)
        $line2 = "$indent" + [char]0x2502 + " $actionText" + (" " * $paddingLength2) + [char]0x2502

        $paddingLength3 = [Math]::Max(0, $boxWidth - $typeText.Length - 1)
        $line3 = "$indent" + [char]0x2502 + " $typeText" + (" " * $paddingLength3) + [char]0x2502

        $diagram += $line1
        $diagram += $line2
        $diagram += $line3

        # Entity detail for Dataverse operations
        if ($action.type -eq "OpenApiConnection") {
            $entityName = $action.inputs.parameters.entityName
            if ($entityName) {
                $entityText = "Entity: $entityName"
                if ($entityText.Length -gt ($boxWidth - 2)) {
                    $entityText = $entityText.Substring(0, $boxWidth - 5) + "..."
                }
                $paddingLength4 = [Math]::Max(0, $boxWidth - $entityText.Length - 1)
                $line4 = "$indent" + [char]0x2502 + " $entityText" + (" " * $paddingLength4) + [char]0x2502
                $diagram += $line4
            }
        }
        # Variable detail
        elseif ($action.type -eq "InitializeVariable" -or $action.type -eq "SetVariable") {
            if ($action.inputs.variables -and $action.inputs.variables[0]) {
                $varName = $action.inputs.variables[0].name
                $varType = $action.inputs.variables[0].type
                if ($varName) {
                    $varText = "Variable: $varName ($varType)"
                    if ($varText.Length -gt ($boxWidth - 2)) {
                        $varText = $varText.Substring(0, $boxWidth - 5) + "..."
                    }
                    $paddingLength4 = [Math]::Max(0, $boxWidth - $varText.Length - 1)
                    $line4 = "$indent" + [char]0x2502 + " $varText" + (" " * $paddingLength4) + [char]0x2502
                    $diagram += $line4
                }
            }
        }

        $lineBottom = "$indent" + [char]0x2514 + (([char]0x2500).ToString() * $boxWidth) + [char]0x2518
        $diagram += $lineBottom

        # Nested actions for conditions
        if ($action.type -eq "If") {
            $conditionExpr = ""
            if ($action.expression) {
                try {
                    $exprObj = $action.expression
                    if ($exprObj.or) { $conditionExpr = "OR condition with $($exprObj.or.Count) clauses" }
                    elseif ($exprObj.and) { $conditionExpr = "AND condition with $($exprObj.and.Count) clauses" }
                    elseif ($exprObj.equals) { $conditionExpr = "Equals check" }
                    elseif ($exprObj.greater) { $conditionExpr = "Greater than check" }
                    elseif ($exprObj.not) { $conditionExpr = "NOT condition" }
                    else { $conditionExpr = "See detailed steps" }
                } catch { $conditionExpr = "See detailed steps" }
            }

            $diagram += "$indent     " + [char]0x2502
            $diagram += "$indent     " + [char]0x25BC + " IF $conditionExpr"
            $diagram += "$indent"
            $diagram += "$indent  " + [char]0x251C + ([char]0x2500).ToString() + " TRUE BRANCH " + (([char]0x2500).ToString() * 28)

            if ($action.actions) {
                $diagram += Build-FlowDiagram -Actions $action.actions -IndentLevel ($IndentLevel + 1)
            }
            if ($action.else -and $action.else.actions) {
                $diagram += "$indent"
                $diagram += "$indent  " + [char]0x2514 + ([char]0x2500).ToString() + " FALSE BRANCH " + (([char]0x2500).ToString() * 27)
                $diagram += Build-FlowDiagram -Actions $action.else.actions -IndentLevel ($IndentLevel + 1)
            }
        }
        elseif ($action.type -eq "Foreach") {
            $diagram += "$indent     " + [char]0x2502
            $diagram += "$indent     " + [char]0x25BC + " FOR EACH ITERATION"
            if ($action.actions) {
                $diagram += Build-FlowDiagram -Actions $action.actions -IndentLevel ($IndentLevel + 1)
            }
        }
        elseif ($action.type -eq "Scope") {
            $diagram += "$indent     " + [char]0x2502
            $diagram += "$indent     " + [char]0x25BC + " SCOPE ACTIONS"
            if ($action.actions) {
                $diagram += Build-FlowDiagram -Actions $action.actions -IndentLevel ($IndentLevel + 1)
            }
        }
        elseif ($action.type -eq "Until") {
            $diagram += "$indent     " + [char]0x2502
            $diagram += "$indent     " + [char]0x25BC + " DO UNTIL LOOP"
            if ($action.actions) {
                $diagram += Build-FlowDiagram -Actions $action.actions -IndentLevel ($IndentLevel + 1)
            }
        }
        elseif ($action.type -eq "Switch") {
            $diagram += "$indent     " + [char]0x2502
            $diagram += "$indent     " + [char]0x25BC + " SWITCH"
            if ($action.cases) {
                foreach ($caseProp in $action.cases.PSObject.Properties) {
                    $diagram += "$indent"
                    $diagram += "$indent  " + [char]0x251C + ([char]0x2500).ToString() + " CASE: $($caseProp.Name) " + (([char]0x2500).ToString() * 20)
                    if ($caseProp.Value.actions) {
                        $diagram += Build-FlowDiagram -Actions $caseProp.Value.actions -IndentLevel ($IndentLevel + 1)
                    }
                }
            }
            if ($action.default -and $action.default.actions) {
                $diagram += "$indent"
                $diagram += "$indent  " + [char]0x2514 + ([char]0x2500).ToString() + " DEFAULT " + (([char]0x2500).ToString() * 30)
                $diagram += Build-FlowDiagram -Actions $action.default.actions -IndentLevel ($IndentLevel + 1)
            }
        }

        # Connector to next action
        if ($actionProp -ne ($Actions.PSObject.Properties | Select-Object -Last 1)) {
            $diagram += "$indent     " + [char]0x2502
            $diagram += "$indent     " + [char]0x25BC
        }
    }

    return $diagram
}

function Get-DetailedActionDescription {
    param(
        $ActionName,
        $Action,
        [int]$Level = 3
    )
    $markdown = @()
    $heading = "#" * $Level
    $actionType = Get-ActionType -Action $Action

    $markdown += "$heading $ActionName"
    $markdown += ""
    $markdown += "**Action Type:** $actionType"

    if ($Action.type -eq "OpenApiConnection") {
        $operationId = $Action.inputs.host.operationId
        $entityName = $Action.inputs.parameters.entityName
        if ($entityName) { $markdown += "**Entity:** ``$entityName``" }

        if ($operationId -eq "ListRecords") {
            $filter = $Action.inputs.parameters.'$filter'
            $top = $Action.inputs.parameters.'$top'
            $orderby = $Action.inputs.parameters.'$orderby'
            $fetchXml = $Action.inputs.parameters.fetchXml
            if ($filter) { $markdown += "**Filter:** ``$filter``" }
            if ($top) { $markdown += "**Top:** $top" }
            if ($orderby) { $markdown += "**Order By:** ``$orderby``" }
            if ($fetchXml) {
                $markdown += ""
                $markdown += "**FetchXML Query:**"
                $markdown += '```xml'
                $markdown += $fetchXml
                $markdown += '```'
            }
        }
    }
    elseif ($Action.type -eq "If") {
        $markdown += ""
        $markdown += "**Condition Logic:**"
        $markdown += ""
        $expr = $Action.expression
        if ($expr) {
            if ($expr.or) {
                $markdown += "**Type:** OR (Any of the following must be true)"
                $markdown += ""
                $clauseNum = 1
                foreach ($clause in $expr.or) {
                    $markdown += "**Clause $($clauseNum):**"
                    $markdown += (Format-ConditionClause $clause)
                    $clauseNum++
                }
            }
            elseif ($expr.and) {
                $markdown += "**Type:** AND (All of the following must be true)"
                $markdown += ""
                $clauseNum = 1
                foreach ($clause in $expr.and) {
                    $markdown += "**Clause $($clauseNum):**"
                    $markdown += (Format-ConditionClause $clause)
                    $clauseNum++
                }
            }
            else {
                $markdown += (Format-ConditionClause $expr)
            }

            $markdown += ""
            $markdown += "**Full Condition Expression (JSON):**"
            $markdown += '```json'
            $markdown += ($Action.expression | ConvertTo-Json -Depth 10)
            $markdown += '```'
        }

        if ($Action.actions) {
            $markdown += ""
            $markdown += "**TRUE Branch Actions:**"
            foreach ($nestedProp in $Action.actions.PSObject.Properties) {
                $markdown += "- $($nestedProp.Name) ($(Get-ActionType -Action $nestedProp.Value))"
            }
        }
        if ($Action.else -and $Action.else.actions) {
            $markdown += ""
            $markdown += "**FALSE Branch Actions:**"
            foreach ($nestedProp in $Action.else.actions.PSObject.Properties) {
                $markdown += "- $($nestedProp.Name) ($(Get-ActionType -Action $nestedProp.Value))"
            }
        }
    }
    elseif ($Action.type -eq "InitializeVariable") {
        if ($Action.inputs.variables -and $Action.inputs.variables[0]) {
            $v = $Action.inputs.variables[0]
            $markdown += "**Variable Name:** ``$($v.name)``"
            $markdown += "**Variable Type:** $($v.type)"
            if ($null -ne $v.value) {
                $valStr = if ($v.value -is [string]) { $v.value } else { ($v.value | ConvertTo-Json -Depth 5 -Compress) }
                $markdown += "**Initial Value:** ``$valStr``"
            }
        }
    }
    elseif ($Action.type -eq "Scope") {
        if ($Action.actions) {
            $markdown += ""
            $markdown += "**Scope Actions:**"
            foreach ($nestedProp in $Action.actions.PSObject.Properties) {
                $markdown += "- $($nestedProp.Name) ($(Get-ActionType -Action $nestedProp.Value))"
            }
        }
    }
    elseif ($Action.type -eq "Foreach") {
        if ($Action.foreach) {
            $markdown += "**Iterates Over:** ``$($Action.foreach)``"
        }
        if ($Action.actions) {
            $markdown += ""
            $markdown += "**Loop Actions:**"
            foreach ($nestedProp in $Action.actions.PSObject.Properties) {
                $markdown += "- $($nestedProp.Name) ($(Get-ActionType -Action $nestedProp.Value))"
            }
        }
    }

    # RunAfter dependencies
    if ($Action.runAfter -and $Action.runAfter.PSObject.Properties.Count -gt 0) {
        $markdown += ""
        $markdown += "**Runs After:**"
        foreach ($runAfterProp in $Action.runAfter.PSObject.Properties) {
            $conditions = $runAfterProp.Value -join ", "
            $markdown += "- $($runAfterProp.Name) [$conditions]"
        }
    }

    $markdown += ""
    $markdown += "---"
    $markdown += ""

    return ($markdown -join "`n")
}

function Format-FlowExpression {
    param([string]$Expr)
    if ($null -eq $Expr -or $Expr -eq '') { return $Expr }

    # @null → null
    if ($Expr -eq '@null') { return 'null' }

    # @outputs('ActionName')?['body/fieldname'] → ActionName.fieldname
    if ($Expr -match "^@outputs\('([^']+)'\)\?\['body/([^']+)'\]$") {
        return "$($Matches[1]).$($Matches[2])"
    }

    # @triggerOutputs()?['body/fieldname'] → trigger.fieldname
    if ($Expr -match "^@triggerOutputs\(\)\?\['body/([^']+)'\]$") {
        return "trigger.$($Matches[1])"
    }

    # @variables('varname') → variables.varname
    if ($Expr -match "^@variables\('([^']+)'\)$") {
        return "variables.$($Matches[1])"
    }

    return $Expr
}

function Format-ConditionClause {
    param(
        $Clause,
        [bool]$Negate = $false
    )
    # Use PSObject.Properties to check for JSON properties explicitly,
    # avoiding collision with .NET methods (e.g. Object.Equals)
    $props = $Clause.PSObject.Properties

    # Handle NOT wrapper — toggle negate flag and recurse into inner expression
    if ($props['not']) {
        return Format-ConditionClause -Clause $Clause.not -Negate (-not $Negate)
    }

    if ($props['equals']) {
        $left = Format-FlowExpression $Clause.equals[0]
        $right = Format-FlowExpression $Clause.equals[1]
        if ($Negate) {
            return "- Is Not Equal: ``$left`` is not equal to ``$right``"
        } else {
            return "- Equals: ``$left`` equals ``$right``"
        }
    }
    elseif ($props['greater']) {
        $left = Format-FlowExpression $Clause.greater[0]
        $right = Format-FlowExpression $Clause.greater[1]
        if ($Negate) {
            return "- Not Greater Than: ``$left`` is not greater than ``$right``"
        } else {
            return "- Greater Than: ``$left`` is greater than ``$right``"
        }
    }
    elseif ($props['greaterOrEquals']) {
        $left = Format-FlowExpression $Clause.greaterOrEquals[0]
        $right = Format-FlowExpression $Clause.greaterOrEquals[1]
        if ($Negate) {
            return "- Not Greater Or Equal: ``$left`` is not >= ``$right``"
        } else {
            return "- Greater Or Equal: ``$left`` is >= ``$right``"
        }
    }
    elseif ($props['less']) {
        $left = Format-FlowExpression $Clause.less[0]
        $right = Format-FlowExpression $Clause.less[1]
        if ($Negate) {
            return "- Not Less Than: ``$left`` is not less than ``$right``"
        } else {
            return "- Less Than: ``$left`` is less than ``$right``"
        }
    }
    elseif ($props['lessOrEquals']) {
        $left = Format-FlowExpression $Clause.lessOrEquals[0]
        $right = Format-FlowExpression $Clause.lessOrEquals[1]
        if ($Negate) {
            return "- Not Less Or Equal: ``$left`` is not <= ``$right``"
        } else {
            return "- Less Or Equal: ``$left`` is <= ``$right``"
        }
    }
    elseif ($props['contains']) {
        $left = Format-FlowExpression $Clause.contains[0]
        $right = Format-FlowExpression $Clause.contains[1]
        if ($Negate) {
            return "- Does Not Contain: ``$left`` does not contain ``$right``"
        } else {
            return "- Contains: ``$left`` contains ``$right``"
        }
    }
    elseif ($props['startsWith']) {
        $left = Format-FlowExpression $Clause.startsWith[0]
        $right = Format-FlowExpression $Clause.startsWith[1]
        if ($Negate) {
            return "- Does Not Start With: ``$left`` does not start with ``$right``"
        } else {
            return "- Starts With: ``$left`` starts with ``$right``"
        }
    }
    elseif ($props['endsWith']) {
        $left = Format-FlowExpression $Clause.endsWith[0]
        $right = Format-FlowExpression $Clause.endsWith[1]
        if ($Negate) {
            return "- Does Not End With: ``$left`` does not end with ``$right``"
        } else {
            return "- Ends With: ``$left`` ends with ``$right``"
        }
    }
    else {
        return "- Complex expression (see JSON)"
    }
}

function Get-DataModelRelationships {
    param($Actions)

    $entities = @{}
    if ($null -eq $Actions) { return "" }

    function Extract-Entities {
        param($ActionSet)
        foreach ($actionProp in $ActionSet.PSObject.Properties) {
            $action = $actionProp.Value
            if ($action.type -eq "OpenApiConnection") {
                $entityName = $action.inputs.parameters.entityName
                if ($entityName) {
                    if (-not $entities.ContainsKey($entityName)) {
                        $entities[$entityName] = @{ Operations = @() }
                    }
                    $operationId = $action.inputs.host.operationId
                    if ($entities[$entityName].Operations -notcontains $operationId) {
                        $entities[$entityName].Operations += $operationId
                    }
                }
            }
            if ($action.actions) { Extract-Entities -ActionSet $action.actions }
            if ($action.else -and $action.else.actions) { Extract-Entities -ActionSet $action.else.actions }
            if ($action.type -eq "Foreach" -and $action.actions) { Extract-Entities -ActionSet $action.actions }
            if ($action.type -eq "Scope" -and $action.actions) { Extract-Entities -ActionSet $action.actions }
            if ($action.type -eq "Switch" -and $action.cases) {
                foreach ($caseProp in $action.cases.PSObject.Properties) {
                    if ($caseProp.Value.actions) { Extract-Entities -ActionSet $caseProp.Value.actions }
                }
                if ($action.default -and $action.default.actions) { Extract-Entities -ActionSet $action.default.actions }
            }
        }
    }

    Extract-Entities -ActionSet $Actions

    if ($entities.Count -eq 0) { return "" }

    $markdown = @()
    $markdown += '```'
    foreach ($entity in ($entities.Keys | Sort-Object)) {
        $operations = $entities[$entity].Operations -join ", "
        $markdown += "$entity"
        $markdown += "  Operations: $operations"
        $markdown += "  " + [char]0x2502
    }
    $markdown += '```'

    return ($markdown -join "`n")
}

function Get-ConnectionReferences {
    param($ConnectionRefs)
    $markdown = @()
    if ($null -eq $ConnectionRefs) { return "" }

    foreach ($connProp in $ConnectionRefs.PSObject.Properties) {
        $connName = $connProp.Name
        $connDetails = $connProp.Value
        $apiName = if ($connDetails.api -and $connDetails.api.name) { $connDetails.api.name } else { "Unknown" }

        $markdown += "**${apiName}:**"
        $markdown += "- API: ``${apiName}``"
        if ($connDetails.runtimeSource) {
            $markdown += "- Runtime Source: $($connDetails.runtimeSource)"
        }
        $markdown += "- Connection Reference: ``$connName``"
        $markdown += ""
    }

    return ($markdown -join "`n")
}

# ── Main Flow Documentation Generator ────────────────────────────────────────

function Generate-FlowDocumentation {
    param(
        [string]$JsonPath,
        [string]$XmlPath,
        [string]$DocOutputPath,
        [string]$SolName
    )

    try {
        $flowJson = Get-Content -Path $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        [xml]$flowXml = Get-Content -Path $XmlPath -Raw -Encoding UTF8

        # Extract metadata from XML
        $flowName = $flowXml.Workflow.LocalizedNames.LocalizedName.description
        # Escape pipe characters that break markdown tables
        $flowNameSafe = $flowName -replace '\|', '-'
        $flowId = $flowXml.Workflow.WorkflowId
        $statecode = $flowXml.Workflow.StateCode
        $introducedVersion = $flowXml.Workflow.IntroducedVersion
        $flowDescription = $flowXml.Workflow.Descriptions.Description |
            Where-Object { $_.languagecode -eq "1033" } |
            Select-Object -ExpandProperty description -ErrorAction SilentlyContinue

        $state = if ($statecode -eq "1") { "Active" } else { "Inactive" }

        # Parse flow definition
        $properties = $flowJson.'properties'
        $definition = $properties.definition
        $connectionRefs = $properties.connectionReferences

        $triggers = $definition.triggers
        $actions = $definition.actions

        # Trigger info
        $triggerProp = $triggers.PSObject.Properties | Select-Object -First 1
        $trigger = $triggerProp.Value
        $triggerDetails = Get-TriggerDetails -Trigger $trigger

        # Derive primary entity from trigger parameters (XML PrimaryEntity is always empty for cloud flows)
        $primaryEntity = $null
        if ($trigger.inputs -and $trigger.inputs.parameters) {
            $primaryEntity = $trigger.inputs.parameters.'subscriptionRequest/entityname'
            if (-not $primaryEntity) {
                $primaryEntity = $trigger.inputs.parameters.entityName
            }
        }
        if (-not $primaryEntity) { $primaryEntity = "N/A" }

        # Determine flow type from trigger
        $flowType = switch ($trigger.type) {
            "OpenApiConnectionWebhook" { "Cloud Flow (Automated)" }
            "Request"    { "Cloud Flow (Instant)" }
            "Recurrence" { "Cloud Flow (Scheduled)" }
            default      { "Cloud Flow" }
        }

        # Build markdown
        $md = @()
        $md += "# $flowNameSafe"
        $md += ""

        # Overview
        $md += "## Overview"
        $md += ""
        $md += "| Property | Value |"
        $md += "|----------|-------|"
        $md += "| **Flow Name** | $flowNameSafe |"
        $md += "| **Flow ID** | ``$flowId`` |"
        $md += "| **Type** | $flowType |"
        $md += "| **State** | $state |"
        $md += "| **Primary Entity** | ``$primaryEntity`` |"
        $md += "| **Version** | $introducedVersion |"
        $md += "| **Solution** | $SolName |"
        if ($flowDescription) {
            # Escape pipe characters that break markdown tables
            $flowDescSafe = $flowDescription -replace '\|', '-'
            $md += "| **Description** | $flowDescSafe |"
        }
        $md += ""

        # Trigger
        $md += "## Trigger"
        $md += ""
        $md += $triggerDetails
        $md += ""

        # Flow Architecture
        $md += "## Flow Architecture"
        $md += ""
        $md += "### High-Level Process Flow"
        $md += ""
        $md += '```'
        if ($actions) {
            $diagram = Build-FlowDiagram -Actions $actions
            $md += $diagram
        } else {
            $md += "No actions defined in this flow."
        }
        $md += '```'
        $md += ""

        # Detailed Flow Steps
        $md += "## Detailed Flow Steps"
        $md += ""
        if ($actions) {
            $stepNumber = 1
            foreach ($actionProp in $actions.PSObject.Properties) {
                $md += "### $stepNumber. $($actionProp.Name)"
                $md += ""
                $md += (Get-DetailedActionDescription -ActionName $actionProp.Name -Action $actionProp.Value -Level 4)
                $stepNumber++
            }
        } else {
            $md += "No steps defined."
            $md += ""
        }

        # Data Model Relationships
        $md += "## Data Model Relationships"
        $md += ""
        $dataModel = Get-DataModelRelationships -Actions $actions
        if ($dataModel) {
            $md += "Dataverse entities used by this flow:"
            $md += ""
            $md += $dataModel
        } else {
            $md += "No Dataverse entity operations detected."
        }
        $md += ""

        # Connection References
        $md += "## Connection References"
        $md += ""
        $connRefs = Get-ConnectionReferences -ConnectionRefs $connectionRefs
        if ($connRefs) {
            $md += $connRefs
        } else {
            $md += "No connection references defined."
        }
        $md += ""

        # Dependencies
        $md += "## Dependencies"
        $md += ""

        $depEntities = @{}
        if ($actions) {
            function Get-DepEntities {
                param($ActionSet)
                foreach ($ap in $ActionSet.PSObject.Properties) {
                    $a = $ap.Value
                    if ($a.type -eq "OpenApiConnection" -and $a.inputs.parameters.entityName) {
                        $depEntities[$a.inputs.parameters.entityName] = $true
                    }
                    if ($a.actions) { Get-DepEntities -ActionSet $a.actions }
                    if ($a.else -and $a.else.actions) { Get-DepEntities -ActionSet $a.else.actions }
                    if ($a.type -eq "Foreach" -and $a.actions) { Get-DepEntities -ActionSet $a.actions }
                    if ($a.type -eq "Scope" -and $a.actions) { Get-DepEntities -ActionSet $a.actions }
                }
            }
            Get-DepEntities -ActionSet $actions
        }

        if ($depEntities.Count -gt 0) {
            $md += "**Dataverse Tables:**"
            foreach ($entity in ($depEntities.Keys | Sort-Object)) {
                $md += "- ``$entity``"
            }
            $md += ""
        }

        if ($connectionRefs) {
            $md += "**Connections:**"
            foreach ($connProp in $connectionRefs.PSObject.Properties) {
                $apiName = if ($connProp.Value.api -and $connProp.Value.api.name) { $connProp.Value.api.name } else { $connProp.Name }
                $md += "- $apiName"
            }
            $md += ""
        }

        # Related Documentation
        $md += "## Related Documentation"
        $md += ""
        $md += "- [$SolName Solution Overview](../$SolName.md)"
        $md += "- [Workflow Index](./README.md)"
        $md += ""
        $md += "---"
        $md += ""
        $md += "*Generated from flow definition on $(Get-Date -Format 'MMMM yyyy')*"
        $md += ""

        # Write file
        $content = $md -join "`n"
        [System.IO.File]::WriteAllText($DocOutputPath, $content, [System.Text.UTF8Encoding]::new($false))

        return @{
            Success  = $true
            FlowName = $flowNameSafe
            State    = $state
            Trigger  = $trigger.type
        }
    }
    catch {
        Write-Host "  ERROR processing $($JsonPath): $_" -ForegroundColor Red
        return @{ Success = $false }
    }
}

# ── Main Execution ────────────────────────────────────────────────────────────

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Power Automate Flow Documentation Generator" -ForegroundColor Cyan
Write-Host "Solution: $SolutionName" -ForegroundColor Cyan
Write-Host "Source:   $SourcePath" -ForegroundColor Cyan
Write-Host "Output:   $OutputPath" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get flow files
$flowFiles = Get-ChildItem -Path $SourcePath -Filter "*.json" | Where-Object { $_.Name -notlike "*.data.xml" }

# Filter to a single flow if specified
if ($FlowName) {
    $flowFiles = $flowFiles | Where-Object { $_.BaseName -like "*$FlowName*" }
    if ($flowFiles.Count -eq 0) {
        Write-Host "ERROR: No flow files matching '$FlowName' found in $SourcePath" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Found $($flowFiles.Count) flow(s) to process." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$errorCount = 0
$total = $flowFiles.Count
$current = 0
$flowIndex = @()

foreach ($flowFile in $flowFiles) {
    $current++
    $percentComplete = [math]::Round(($current / $total) * 100)
    Write-Host "[$percentComplete%] Processing: $($flowFile.Name)" -ForegroundColor Cyan

    $xmlFile = "$($flowFile.FullName).data.xml"
    if (-not (Test-Path $xmlFile)) {
        Write-Host "  WARNING: XML metadata file not found, skipping." -ForegroundColor Yellow
        $errorCount++
        continue
    }

    # Generate clean output filename
    $baseName = $flowFile.BaseName
    $cleanName = $baseName -replace '-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$', ''
    $readableName = $cleanName -creplace '([a-z])([A-Z])', '$1-$2'
    $outputFileName = "$readableName.md"
    $outputFile = Join-Path -Path $OutputPath -ChildPath $outputFileName

    $result = Generate-FlowDocumentation -JsonPath $flowFile.FullName -XmlPath $xmlFile -DocOutputPath $outputFile -SolName $SolutionName

    if ($result.Success) {
        Write-Host "  SUCCESS: $outputFileName" -ForegroundColor Green
        $successCount++
        $flowIndex += @{
            FileName = $outputFileName
            FlowName = $result.FlowName
            State    = $result.State
            Trigger  = $result.Trigger
        }
    } else {
        $errorCount++
    }
}

# Generate README.md index
$readmePath = Join-Path $OutputPath "README.md"
$readme = @()
$readme += "# $SolutionName - Workflow Documentation"
$readme += ""
$readme += "Documentation for Power Automate cloud flows in the **$SolutionName** solution."
$readme += ""
$readme += "## Flows"
$readme += ""
$readme += "| Flow | State | Trigger Type | Documentation |"
$readme += "|------|-------|-------------|---------------|"

foreach ($entry in ($flowIndex | Sort-Object { $_.FlowName })) {
    $triggerLabel = switch ($entry.Trigger) {
        "OpenApiConnectionWebhook" { "Dataverse Trigger" }
        "Request"    { "HTTP / Instant" }
        "Recurrence" { "Scheduled" }
        default      { $entry.Trigger }
    }
    $readme += "| $($entry.FlowName) | $($entry.State) | $triggerLabel | [$($entry.FileName)](./$($entry.FileName)) |"
}

$readme += ""
$readme += "---"
$readme += ""
$readme += "*Generated on $(Get-Date -Format 'MMMM yyyy')*"
$readme += ""

$readmeContent = $readme -join "`n"
[System.IO.File]::WriteAllText($readmePath, $readmeContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete! $successCount/$total flows documented." -ForegroundColor $(if ($errorCount -gt 0) { "Yellow" } else { "Green" })
if ($errorCount -gt 0) {
    Write-Host "Errors: $errorCount" -ForegroundColor Red
}
Write-Host "Output:  $OutputPath" -ForegroundColor White
Write-Host "Index:   $readmePath" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
