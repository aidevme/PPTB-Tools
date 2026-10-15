# Sample Output and Troubleshooting

## Report Structure

The script generates a comprehensive markdown report at:
```
Solutions/PR_Analysis/PR_[id]_[branch]_Comprehensive_Analysis.md
```

The report includes:
- **Executive Summary** - Change statistics and component counts
- **Change Overview** - Narrative description of what changed
- **Best Practice Warnings** - Critical violations that need attention
- **Component Details** - Detailed breakdown by component type
- **Risk Assessment** - Critical/High/Medium/Low risk categorization
- **Testing Recommendations** - Components requiring testing
- **Deployment Recommendations** - Pre/post deployment steps

## Sample Report Output

```markdown
# Solution Component Changes - Comprehensive Analysis

**Identifier:** 13
**Source Branch:** origin/solution-export/168
**Target Branch:** origin/main
**Generated:** 2025-11-06 09:00:45 UTC

## Executive Summary

**Change Statistics:**
- **Total Files Changed:** 44
- **Files Added:** 20
- **Files Modified:** 22
- **Files Deleted:** 2

**Component Summary:**
- **Tables/Entities:** 4
- **PCF Controls:** 2
- **Global Option Sets:** 1
- **Custom APIs:** 1
- **Plugin Steps:** 3
- **Entity Views:** 10
- **Forms:** 6
- **Web Resources:** 6
- **Workflows:** 1
- **Canvas Apps:** 1
- **App Modules:** 2

## Best Practice Warnings

**The following issues were detected that violate Dataverse solution best practices:**

### [HIGH] OOB/Managed entity added with all assets

- **Entity:** systemuser
- **Details:** Entity 'systemuser' has behavior='0' which includes ALL forms, views, and fields.
- **Recommendation:** Use behavior='1' (Do Not Include Subcomponents) for OOB entities.

## Table/Entity Changes

### New Tables

#### Approval (hso_approval)

- **Type:** Custom
- **Total Attributes:** 25
- **Custom Attributes:** 15
- **Custom Fields:**
  - Approval Status (hso_approvalstatus_code) - Picklist
  - Submitted By (hso_submittedby_id) - Lookup
  ...

## PCF Control Changes

### Modified PCF Controls

#### HSO.Dynamics.PCF.EstimateRoleControl

- **Version:** 1.5.0
- **Control Type:** standard
- **Properties:** 3 defined

## Risk Assessment

### [CRITICAL] CRITICAL ISSUES - DO NOT DEPLOY

- **SOLUTION BEST PRACTICE VIOLATION: OOB/Managed entity added with all assets - Entity 'systemuser'**
  - **Recommendation:** STOP - Fix these issues before proceeding with deployment

### [MEDIUM RISK] MEDIUM RISK CHANGES

- **New Custom Tables: 4 new table(s) with custom fields - require comprehensive testing**
- **New Custom API: 1 new API(s) requiring thorough testing of complex logic**
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Branch not found" | Run `git fetch origin` to fetch remote branches |
| "No solution files found" | Verify the branch contains changes in the Solutions/ directory |
| "Git diff failed" | Ensure both source and target branches exist and are accessible |
| Script hangs | Check for large binary files; consider excluding WebResources data files |

## Prerequisites

1. **Git** must be installed and available in PATH
2. **PowerShell** (Windows PowerShell or PowerShell Core)
3. **Repository must have the branch** you want to analyze (fetch if needed)