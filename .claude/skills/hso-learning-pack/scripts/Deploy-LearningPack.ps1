# Deploy-LearningPack.ps1
# Deploys a learning pack as a static site to Azure.
#
# Two supported targets:
#   - StaticWebApp  (default; SSL + custom domain + optional Entra auth)
#   - BlobStatic    (cheapest; public static website on a storage account)
#
# What gets deployed (auto-discovered from the pack root):
#   - All *.html (landing, audience decks, feature/screen/hub pages)
#   - All *.pptx, *.docx, *.pdf at the root (downloadable artifacts)
#   - Any folder at the pack root containing images (e.g. screens/,
#     screens-prod/, diagrams/) -- discovered, not hardcoded
#   - staticwebapp.config.json (auth + routing rules; SWA target only)
#
# What gets EXCLUDED:
#   - *.md (Marp source files -- not consumed by deployed pages)
#   - scripts/ (PowerShell/Node helpers -- not for end users)
#   - _pdf-stage/, _narrate-stage/, _qa/ (intermediate PDF / narration / QA artifacts, regeneratable)
#   - state.json, .deploy-config.json (local-only)
#   - source-docs/ (raw research/dossier sources; keep these local)
#
# Usage:
#   # First-time deploy: one command does provisioning + content + auth
#   .\Deploy-LearningPack.ps1 -Name <swa-name> -ResourceGroup <rg>
#
#   # Re-publish (idempotent -- reads cached params, redeploys, reconciles auth)
#   .\Deploy-LearningPack.ps1
#
#   # Deploy to a Blob Storage static website (public, cheapest)
#   .\Deploy-LearningPack.ps1 -Target BlobStatic -Name <storage-acct> -ResourceGroup <rg>
#
# Prereqs:
#   - Az CLI logged in:  az login
#   - For SWA:           npm install -g @azure/static-web-apps-cli (auto-installed on first run)
#requires -Version 5.1

param(
    [ValidateSet('StaticWebApp', 'BlobStatic')]
    [string]$Target = 'StaticWebApp',

    # First run: pass -Name and -ResourceGroup explicitly. They're cached in
    # .deploy-config.json next to this script, so subsequent runs can omit them.
    [string]$Name,

    [string]$ResourceGroup,

    # Default location: eastus2. Static Web Apps are only available in 5 regions:
    #   centralus, eastus2, westus2, westeurope, eastasia
    # BlobStatic accepts any region; the SWA-only constraint is enforced below.
    [string]$Location = 'eastus2',

    # AuthMode options:
    #   Custom (default, recommended) -- Custom Entra app registration with tenant
    #                  restriction. Standard SKU (~$9/mo). The only mode known to
    #                  work reliably end-to-end after the auth fixes (Graph perms,
    #                  static-asset whitelist, cache-control:no-store,
    #                  post_login_redirect_uri). Use this unless you have a
    #                  specific reason not to.
    #   EasyAuth     -- SWA's built-in pre-configured Entra provider on Free SKU.
    #                  Multi-tenant; any Microsoft account. Often loops on tenants
    #                  that require admin consent for first-party Microsoft apps.
    #                  NOT recommended.
    #   None         -- Public. No auth at all. Use only if the pack is genuinely
    #                  public-facing.
    #   Entra        -- backwards-compat alias for Custom.
    [ValidateSet('Custom', 'EasyAuth', 'Entra', 'None')]
    [string]$AuthMode = 'Custom',

    # Banner label for this pack, e.g. 'Forge USA' or 'ERP Unite'. Cosmetic only -
    # it names the pack in the console header. Cached like the other params, so each
    # pack keeps its own label without forking the script.
    [string]$PackTitle,

    [string]$EntraTenantId,

    [switch]$SkipProvision,

    # SWA named environment. Default 'production'. Use any other name
    # (e.g. 'staging', 'preview', 'qa') to deploy a preview environment
    # on the same SWA -- production stays untouched. Preview envs get a
    # URL like <swa-base>-<env>.<region>.azurestaticapps.net.
    [string]$Environment = 'production',

    # Clear the cached defaults and force re-prompt
    [switch]$ResetConfig
)

$ErrorActionPreference = 'Stop'

$packRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
# Stage dir name derives from the pack folder so multiple projects on one
# machine don't collide. No hardcoded project name.
$packFolderName = (Split-Path $packRoot -Leaf).ToLower() -replace '[^a-z0-9-]', '-'
$stageDir = Join-Path $env:TEMP "$packFolderName-stage-$(Get-Date -Format yyyyMMddHHmmss)"
$configPath = Join-Path $PSScriptRoot '.deploy-config.json'

# --- Load / merge / persist cached config ---
if ($ResetConfig -and (Test-Path $configPath)) {
    Remove-Item $configPath -Force
    Write-Host "Cleared cached config." -ForegroundColor Yellow
}

if (Test-Path $configPath) {
    $cached = Get-Content $configPath -Raw | ConvertFrom-Json
    if (-not $Name -and $cached.Name)                   { $Name = $cached.Name }
    if (-not $ResourceGroup -and $cached.ResourceGroup) { $ResourceGroup = $cached.ResourceGroup }
    # Only fill optional defaults from cache when caller didn't override
    if (-not $PSBoundParameters.ContainsKey('Target')   -and $cached.Target)   { $Target   = $cached.Target }
    if (-not $PSBoundParameters.ContainsKey('Location') -and $cached.Location) { $Location = $cached.Location }
    if (-not $PSBoundParameters.ContainsKey('AuthMode') -and $cached.AuthMode) { $AuthMode = $cached.AuthMode }
    if (-not $EntraTenantId -and $cached.EntraTenantId) { $EntraTenantId = $cached.EntraTenantId }
    if (-not $PackTitle -and $cached.PackTitle) { $PackTitle = $cached.PackTitle }
    Write-Host "Using cached config from $configPath" -ForegroundColor DarkGray
}

if (-not $Name -or -not $ResourceGroup) {
    throw "First run: pass -Name and -ResourceGroup. They'll be cached for next time. Example:`n    .\Deploy-LearningPack.ps1 -Name <your-swa-name> -ResourceGroup <your-rg-name>"
}

Write-Host ""
if (-not $PackTitle) { $PackTitle = 'Learning Pack' }
Write-Host "=== $PackTitle -- Deploy ===" -ForegroundColor Cyan
Write-Host "Target       : $Target" -ForegroundColor Gray
Write-Host "Name         : $Name" -ForegroundColor Gray
Write-Host "RG           : $ResourceGroup" -ForegroundColor Gray
Write-Host "Auth         : $AuthMode" -ForegroundColor Gray
Write-Host "Pack source  : $packRoot" -ForegroundColor Gray
Write-Host "Stage        : $stageDir" -ForegroundColor Gray
Write-Host ""

# Verify Az CLI is logged in
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Az CLI is not logged in. Run 'az login' first."
}
Write-Host "Az signed in : $($account.user.name)  (sub: $($account.name))" -ForegroundColor Green
Write-Host ""

# Stage only the files we want to publish
Write-Host "==> Staging publishable files..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

# Root-level files: every HTML page, downloadable PPTX/DOCX/PDF
$rootGlobs = @('*.html', '*.pptx', '*.docx', '*.pdf', '*.mp4', '*.webm')
foreach ($glob in $rootGlobs) {
    $found = Get-ChildItem -Path (Join-Path $packRoot $glob) -File -ErrorAction SilentlyContinue
    if ($found) {
        Copy-Item -Path $found.FullName -Destination $stageDir
        Write-Host ("  copied {0,3} files matching {1}" -f $found.Count, $glob) -ForegroundColor DarkGray
    }
}

# Asset folders: auto-discover any directory at the pack root that contains
# image / web-asset files. Handles screens/, screens-<env>/, diagrams/,
# anything similar -- no hardcoded folder names.
$assetExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.ico', '.css', '.js', '.woff', '.woff2', '.ttf', '.otf')
$excludeDirs = @('scripts', '_pdf-stage', '_narrate-stage', '_qa', 'node_modules', '.git', '.swa', 'source-docs', 'templates', 'themes', 'transcripts')

Get-ChildItem -Path $packRoot -Directory | Where-Object {
    $excludeDirs -notcontains $_.Name -and `
    ($null -ne (Get-ChildItem -Path $_.FullName -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $assetExtensions -contains $_.Extension.ToLower() } | Select-Object -First 1))
} | ForEach-Object {
    $sourceDir = $_.FullName
    $destDir = Join-Path $stageDir $_.Name
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceDir '*') -Destination $destDir -Recurse -Force
    $fileCount = (Get-ChildItem -Path $sourceDir -File -Recurse).Count
    Write-Host ("  copied {0,3} files from {1}/" -f $fileCount, $_.Name) -ForegroundColor DarkGray
}

# SWA routing config -- pick the right one based on AuthMode
if ($Target -eq 'StaticWebApp') {
    # Normalize legacy 'Entra' alias to 'Custom'
    $effectiveMode = if ($AuthMode -eq 'Entra') { 'Custom' } else { $AuthMode }

    if ($effectiveMode -eq 'EasyAuth') {
        Write-Host "Auth mode: EasyAuth (Free SKU, built-in Microsoft Entra provider, any Entra account)" -ForegroundColor Cyan
        Copy-Item -Path (Join-Path $packRoot 'staticwebapp.config.easy-auth.json') -Destination (Join-Path $stageDir 'staticwebapp.config.json')
    }
    elseif ($effectiveMode -eq 'Custom') {
        if (-not $EntraTenantId) {
            $detectedTenant = $account.tenantId
            Write-Host "Auth mode: Custom (Standard SKU, custom Entra app reg, tenant restricted)" -ForegroundColor Cyan
            Write-Host "Using your current tenant: $detectedTenant   (override with -EntraTenantId)" -ForegroundColor Yellow
            $EntraTenantId = $detectedTenant
        }
        $cfg = Get-Content (Join-Path $packRoot 'staticwebapp.config.entra-gated.json') -Raw
        $cfg = $cfg.Replace('<HSO_TENANT_ID>', $EntraTenantId)
        Set-Content -Path (Join-Path $stageDir 'staticwebapp.config.json') -Value $cfg
    }
    else {
        Write-Host "Auth mode: None (public, no auth gate)" -ForegroundColor Cyan
        Copy-Item -Path (Join-Path $packRoot 'staticwebapp.config.json') -Destination $stageDir
    }
}

# Stamp the real publish date into any staged page carrying a "Last published <date>"
# label, so the footer always reflects when the site was actually deployed - no manual
# date edits, no drift. Operates on the staged copies only; source files are untouched.
$pubDate = Get-Date -Format 'MMMM d, yyyy'
$pubPattern = 'Last published [A-Za-z]+ \d{1,2}, \d{4}'
$pubStamped = 0
Get-ChildItem -Path $stageDir -Filter *.html -File | ForEach-Object {
    $html = [System.IO.File]::ReadAllText($_.FullName)
    if ($html -match $pubPattern) {
        $html = [regex]::Replace($html, $pubPattern, "Last published $pubDate")
        [System.IO.File]::WriteAllText($_.FullName, $html, (New-Object System.Text.UTF8Encoding($false)))
        $pubStamped++
    }
}
Write-Host "  stamped publish date ($pubDate) into $pubStamped page(s)" -ForegroundColor DarkGray

$stagedSize = (Get-ChildItem $stageDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host ("  staged {0:N1} MB" -f $stagedSize) -ForegroundColor Green
Write-Host ""

# Provision target if needed
if (-not $SkipProvision) {
    Write-Host "==> Ensuring resource group $ResourceGroup exists..." -ForegroundColor Cyan
    az group create --name $ResourceGroup --location $Location --output none

    if ($Target -eq 'StaticWebApp') {
        # SWA is only available in 5 regions; fail fast if user picked something else
        $swaRegions = @('centralus', 'eastus2', 'westus2', 'westeurope', 'eastasia')
        if ($swaRegions -notcontains $Location.ToLower()) {
            throw "Static Web Apps are not available in '$Location'. Pick one of: $($swaRegions -join ', ')."
        }

        $existing = az staticwebapp show --name $Name --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        # SKU choice: Custom mode REQUIRES Standard (Free ignores custom AAD config and creates a loopback).
        # EasyAuth and None work on Free.
        $sku = if ($effectiveMode -eq 'Custom') { 'Standard' } else { 'Free' }
        if (-not $existing) {
            Write-Host "==> Creating Azure Static Web App '$Name' in $Location (SKU: $sku)..." -ForegroundColor Cyan
            if ($sku -eq 'Standard') {
                Write-Host "    Standard tier (~`$9/mo) is required for custom Entra auth -- Free tier ignores AAD_CLIENT_ID." -ForegroundColor Yellow
            }
            az staticwebapp create `
                --name $Name `
                --resource-group $ResourceGroup `
                --location $Location `
                --sku $sku `
                --output none
            if ($LASTEXITCODE -ne 0) {
                throw "Static Web App creation failed (exit $LASTEXITCODE). See the error above. Common causes: name already in use, region capacity, RBAC permissions."
            }
            # Verify it really exists before proceeding (some failure modes don't bubble up to exit code)
            $created = az staticwebapp show --name $Name --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
            if (-not $created) {
                throw "Static Web App '$Name' was not created -- see Azure CLI output above. Aborting before deploy."
            }
        } else {
            $existingSku = $existing.sku.name
            Write-Host "==> Static Web App '$Name' exists in $($existing.location) (SKU: $existingSku)" -ForegroundColor Green
            # Idempotent SKU upgrade: Custom mode REQUIRES Standard; Free silently
            # ignores AAD_CLIENT_ID/SECRET and the deploy looks fine but auth loops.
            if ($sku -eq 'Standard' -and $existingSku -ne 'Standard') {
                Write-Host "    Upgrading SKU to Standard (required for custom Entra auth)..." -ForegroundColor Yellow
                az staticwebapp update --name $Name --resource-group $ResourceGroup --sku Standard --output none
                if ($LASTEXITCODE -ne 0) {
                    throw "SKU upgrade to Standard failed. Cannot proceed with Custom auth on Free SKU."
                }
                Write-Host "    ok Upgraded to Standard" -ForegroundColor Green
            }
            Write-Host "    Will redeploy content + reconcile auth config." -ForegroundColor Green
        }
    } elseif ($Target -eq 'BlobStatic') {
        $existing = az storage account show --name $Name --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        if (-not $existing) {
            Write-Host "==> Creating Storage Account '$Name'..." -ForegroundColor Cyan
            az storage account create `
                --name $Name `
                --resource-group $ResourceGroup `
                --location $Location `
                --sku Standard_LRS `
                --kind StorageV2 `
                --allow-blob-public-access true `
                --output none
        } else {
            Write-Host "==> Storage account '$Name' exists" -ForegroundColor Green
        }
        Write-Host "==> Enabling static website on storage account..." -ForegroundColor Cyan
        az storage blob service-properties update `
            --account-name $Name `
            --static-website `
            --index-document index.html `
            --404-document index.html `
            --output none
    }
}

# Deploy content
if ($Target -eq 'StaticWebApp') {
    Write-Host "==> Getting SWA deployment token..." -ForegroundColor Cyan
    $token = az staticwebapp secrets list --name $Name --resource-group $ResourceGroup --query "properties.apiKey" -o tsv
    if (-not $token) { throw "Could not retrieve SWA deployment token." }

    # Ensure SWA CLI is installed
    $swaInstalled = (npm list -g --depth=0 2>$null | Select-String '@azure/static-web-apps-cli')
    if (-not $swaInstalled) {
        Write-Host "==> Installing @azure/static-web-apps-cli (one-time)..." -ForegroundColor Yellow
        npm install -g @azure/static-web-apps-cli
    }

    # Count files going up so we can flag silent failures
    $fileCount = (Get-ChildItem -Path $stageDir -Recurse -File).Count
    Write-Host "==> Deploying $fileCount files to Static Web App..." -ForegroundColor Cyan

    # SWA CLI emits progress to stderr in non-interactive mode; capture full output for diagnostics.
    #
    # ADR 0017 (target Windows PowerShell 5.1): under 5.1 with $ErrorActionPreference='Stop',
    # ANY stderr line from a native command is promoted to a terminating NativeCommandError --
    # so the CLI's ordinary "Preparing deployment..." progress killed the run before it uploaded.
    # PowerShell 7 does not do this, which is why the failure only showed up on 5.1. Drop to
    # 'Continue' for the duration of the native call and rely on $LASTEXITCODE (checked below)
    # for real failure detection, then restore the caller's preference.
    Write-Host "    Target environment: $Environment" -ForegroundColor DarkGray
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $deployOutput = swa deploy $stageDir --deployment-token $token --env $Environment --verbose silly 2>&1
        $deployExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }

    # Echo what SWA CLI said
    $deployOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    if ($deployExit -ne 0) {
        throw "swa deploy exited $deployExit. See output above for details."
    }

    # Hard failure detection: StaticSitesClient reports content-server rejections
    # (e.g. the 500MB app-size limit) as INFO lines while STILL exiting 0 -- so the
    # script must scan for them, or it will falsely report success on a dead deploy.
    if ($deployOutput | Select-String -Pattern 'rejected the request|content was too large|BadRequest' -Quiet) {
        throw "Upload was REJECTED by the content server (see output above) -- commonly the 500MB app-size limit. Remove scratch/large dirs (e.g. _narrate-stage, _pdf-stage) or trim artifacts, then re-run."
    }

    # Verify the deployment actually landed: the environment must leave
    # 'WaitingForDeployment' and reach 'Ready'. Polls up to 4 minutes.
    Write-Host "==> Verifying deployment reached 'Ready'..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddMinutes(4); $envStatus = ''
    do {
        Start-Sleep -Seconds 10
        $envStatus = az staticwebapp environment list --name $Name --resource-group $ResourceGroup --query "[0].status" -o tsv 2>$null
    } while ($envStatus -ne 'Ready' -and (Get-Date) -lt $deadline)
    if ($envStatus -ne 'Ready') {
        throw "Deployment did not reach 'Ready' (status: '$envStatus') within 4 min -- the upload likely failed silently. Check content size and re-run."
    }
    Write-Host "    ok - environment status: Ready" -ForegroundColor Green

    # Sanity: SWA CLI prints 'Project deployed successfully' or similar on real success.
    # Treat absence of any 'success/deployed/uploaded' line as suspicious.
    $successMarker = $deployOutput | Select-String -Pattern 'deployed|uploaded|success' -Quiet
    if (-not $successMarker) {
        Write-Host "WARNING: swa deploy returned exit 0 but no success marker found in output." -ForegroundColor Yellow
        Write-Host "         The deploy may have silently failed. Verify via the Azure Portal Deployments tab." -ForegroundColor Yellow
    }

    # For non-production envs, look up the env-specific hostname; production
    # uses the SWA's defaultHostname.
    if ($Environment -ne 'production') {
        $envHostname = az staticwebapp environment show `
            --name $Name `
            --resource-group $ResourceGroup `
            --environment-name $Environment `
            --query "hostname" -o tsv 2>$null
        if (-not [string]::IsNullOrWhiteSpace($envHostname)) {
            $hostname = $envHostname
        } else {
            $hostname = az staticwebapp show --name $Name --resource-group $ResourceGroup --query "defaultHostname" -o tsv
            Write-Host "WARNING: could not resolve environment '$Environment' hostname; falling back to production hostname." -ForegroundColor Yellow
        }
    } else {
        $hostname = az staticwebapp show --name $Name --resource-group $ResourceGroup --query "defaultHostname" -o tsv
    }
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host " Deployed!  (environment: $Environment)" -ForegroundColor Green
    Write-Host " URL: https://$hostname" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green

    if ($effectiveMode -eq 'Custom') {
        Write-Host ""
        Write-Host "==> Setting up custom Entra auth (app reg + Graph perms + admin consent)..." -ForegroundColor Cyan
        Write-Host ""
        & (Join-Path $PSScriptRoot 'Setup-EntraAuth.ps1') `
            -StaticWebAppName $Name `
            -ResourceGroup    $ResourceGroup
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "Setup-EntraAuth.ps1 failed. The site is deployed but auth is not configured." -ForegroundColor Red
            Write-Host "Re-run manually:" -ForegroundColor Yellow
            Write-Host "  .\Setup-EntraAuth.ps1 -StaticWebAppName $Name -ResourceGroup $ResourceGroup" -ForegroundColor Cyan
        } else {
            Write-Host ""
            Write-Host "ok Auth configured. Sign in at: https://$hostname" -ForegroundColor Green
        }

        # Non-production SWA environments get a distinct hostname
        # (<swa-base>-<env>.<region>.azurestaticapps.net). The Entra app
        # registration's redirect URIs only include the production hostname
        # by default. Register the env-specific callback so sign-in works
        # for staging/preview without manual portal clicks.
        if ($Environment -ne 'production' -and -not [string]::IsNullOrWhiteSpace($hostname)) {
            $envCallback = "https://$hostname/.auth/login/aad/callback"
            $clientId = az staticwebapp appsettings list `
                --name $Name --resource-group $ResourceGroup `
                --query "properties.AAD_CLIENT_ID" -o tsv 2>$null
            if (-not [string]::IsNullOrWhiteSpace($clientId)) {
                $appObjectId = az ad app show --id $clientId --query id -o tsv 2>$null
                if (-not [string]::IsNullOrWhiteSpace($appObjectId)) {
                    $existing = az ad app show --id $clientId --query "web.redirectUris" -o json 2>$null | ConvertFrom-Json
                    if (-not ($existing -contains $envCallback)) {
                        $merged = @($existing) + @($envCallback) | Sort-Object -Unique
                        Write-Host "==> Adding env redirect URI to Entra app: $envCallback" -ForegroundColor Cyan
                        $patch = @{ web = @{ redirectUris = $merged } } | ConvertTo-Json -Compress -Depth 5
                        $patchFile = New-TemporaryFile
                        $patch | Out-File -FilePath $patchFile -Encoding utf8
                        az rest --method PATCH `
                            --url "https://graph.microsoft.com/v1.0/applications/$appObjectId" `
                            --body "@$patchFile" `
                            --headers "Content-Type=application/json" | Out-Null
                        Remove-Item $patchFile -Force
                    }
                }
            }
        }
    }
    elseif ($effectiveMode -eq 'EasyAuth') {
        Write-Host ""
        Write-Host "EasyAuth is wired by the SWA platform -- no extra setup needed." -ForegroundColor Green
        Write-Host "  * Sign-in URL : https://$hostname/.auth/login/aad" -ForegroundColor Gray
        Write-Host "  * Login flow  : built-in Microsoft Entra provider (Microsoft-managed app reg)" -ForegroundColor Gray
        Write-Host "  * Restriction : any Entra account can sign in (no tenant gate on Free tier)" -ForegroundColor Gray
        Write-Host "" -ForegroundColor Gray
        Write-Host "  Note: if you previously deployed with custom Entra auth, the leftover" -ForegroundColor Gray
        Write-Host "  AAD_CLIENT_ID and AAD_CLIENT_SECRET app settings are now ignored. You can" -ForegroundColor Gray
        Write-Host "  remove them with:" -ForegroundColor Gray
        Write-Host "    az staticwebapp appsettings delete --name $Name --resource-group $ResourceGroup ``" -ForegroundColor DarkGray
        Write-Host "      --setting-names AAD_CLIENT_ID AAD_CLIENT_SECRET" -ForegroundColor DarkGray
    }
} elseif ($Target -eq 'BlobStatic') {
    Write-Host "==> Uploading files to `$web container..." -ForegroundColor Cyan
    az storage blob upload-batch `
        --account-name $Name `
        --source $stageDir `
        --destination '$web' `
        --overwrite true `
        --output none

    $endpoint = az storage account show `
        --name $Name `
        --resource-group $ResourceGroup `
        --query "primaryEndpoints.web" -o tsv
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host " Deployed!" -ForegroundColor Green
    Write-Host " URL: $endpoint" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: BlobStatic is public. For Entra gating, use -Target StaticWebApp." -ForegroundColor Yellow
}

# Persist config so subsequent runs don't need any parameters
$cfgToSave = [ordered]@{
    Target        = $Target
    Name          = $Name
    ResourceGroup = $ResourceGroup
    Location      = $Location
    AuthMode      = $AuthMode
    PackTitle     = $PackTitle
    EntraTenantId = $EntraTenantId
    SavedAt       = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
}
$cfgToSave | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath -Encoding UTF8
Write-Host "Saved deploy config -> $configPath" -ForegroundColor DarkGray
Write-Host "Next run: just '.\Deploy-LearningPack.ps1' -- params are cached and the script is idempotent." -ForegroundColor DarkGray
Write-Host "         Use '-SkipProvision' to skip the existence/SKU checks (slightly faster, optional)." -ForegroundColor DarkGray

# Clean up stage dir
Remove-Item -Path $stageDir -Recurse -Force
Write-Host ""
Write-Host "Stage cleaned up. Done." -ForegroundColor Green
