<#
.SYNOPSIS
Shared Dataverse authentication functions for all skills and scripts.

.DESCRIPTION
Centralized authentication module providing:
- Settings-driven auth resolver (auto-selects the right flow)
- Interactive authentication via MSAL.PS with file + in-memory token caching
- Device Code flow for headless/SSH scenarios (MFA-compatible)
- Managed Identity (IMDS) for Azure-hosted agents
- Service principal (client credentials) for automated pipelines
- Unified Get-DataverseToken entry point

Dot-source this file at the top of any skill script (it lives in the sibling
aidevme-shared-scripts library skill):
    $sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
    . "$sharedDir\Dataverse-Auth.ps1"

Auth mode is determined by (in priority order):
1. Explicit parameters passed to Get-DataverseToken (-Interactive, -ClientId/-ClientSecret)
2. Environment variable: DATAVERSE_AUTH_MODE
3. Settings file: <repo-root>/auth-settings.json (`.claude/auth-settings.json` in a consuming repo —
   gitignored, holding that repo's own creds; never inside the synced skill tree)
4. Default: Interactive

.NOTES
Client ID: 51f81489-12ee-4a9e-aaae-a2591f45987d (Microsoft Common Data Service Client)
Token cache: %TEMP%\DataverseAuthCache_<SHA256hash>.json (per environment)
#>

# ============================================================================
# Script-scoped state (shared across all callers in the same session)
# ============================================================================

if (-not (Get-Variable -Name 'DvAuth_Token'     -Scope Script -ErrorAction SilentlyContinue)) { $script:DvAuth_Token     = $null }
if (-not (Get-Variable -Name 'DvAuth_Expiry'    -Scope Script -ErrorAction SilentlyContinue)) { $script:DvAuth_Expiry    = $null }
if (-not (Get-Variable -Name 'DvAuth_EnvUrl'    -Scope Script -ErrorAction SilentlyContinue)) { $script:DvAuth_EnvUrl    = $null }
if (-not (Get-Variable -Name 'DvAuth_Username'  -Scope Script -ErrorAction SilentlyContinue)) { $script:DvAuth_Username  = $null }
if (-not (Get-Variable -Name 'DvAuth_Settings'  -Scope Script -ErrorAction SilentlyContinue)) { $script:DvAuth_Settings  = $null }
if (-not (Get-Variable -Name 'DvAuth_Log'       -Scope Script -ErrorAction SilentlyContinue)) { $script:DvAuth_Log       = [System.Collections.Generic.List[object]]::new() }

# ============================================================================
# Auth Logging
# ============================================================================

function Write-AuthLog {
    <#
    .SYNOPSIS
    Records a structured Dataverse auth event to the in-memory log and PowerShell streams.

    .DESCRIPTION
    Three outputs:
      1. $script:DvAuth_Log  — queryable in-memory list (use Get-DataverseAuthLog)
      2. Write-Verbose       — shown when the caller uses -Verbose
      3. Write-Information   — capturable via -InformationVariable or -InformationAction
                               in hosted scenarios (tag: 'DataverseAuth')

    WARN and ERROR also emit to Write-Warning so they are visible without -Verbose.
    #>
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory)]
        [string]$Event,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Mode,
        [string]$Identity,
        [hashtable]$Details
    )

    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date)
        Level     = $Level
        Source    = 'Dataverse'
        Event     = $Event
        Mode      = if ($Mode)     { $Mode }     else { '' }
        Identity  = if ($Identity) { $Identity } else { '' }
        Message   = $Message
        Details   = if ($Details)  { $Details }  else { @{} }
    }

    $script:DvAuth_Log.Add($entry)

    Write-Verbose "[DataverseAuth][$Level][$Event] $Message"
    Write-Information -MessageData $entry -Tags 'DataverseAuth'

    if ($Level -eq 'WARN')  { Write-Warning "[DataverseAuth] $Message" }
    if ($Level -eq 'ERROR') { Write-Warning "[DataverseAuth][ERROR] $Message" }
}

function Get-DataverseAuthLog {
    <#
    .SYNOPSIS
    Returns the structured Dataverse auth log for the current session.

    .DESCRIPTION
    Returns all auth events recorded since the module was loaded or since
    Clear-DataverseAuthLog was last called. Each entry is a PSCustomObject with:
      Timestamp, Level (DEBUG/INFO/WARN/ERROR), Source, Event, Mode, Identity, Message, Details

    .PARAMETER Level
    Optional minimum level filter. Order: DEBUG < INFO < WARN < ERROR.

    .EXAMPLE
    # Show the full auth trace after a run
    Get-DataverseAuthLog | Format-Table Timestamp, Level, Event, Message -AutoSize

    .EXAMPLE
    # Show only warnings and errors
    Get-DataverseAuthLog -Level WARN

    .EXAMPLE
    # Capture auth events in a hosted agent via the Information stream
    $token = Get-DataverseToken -EnvironmentUrl $url -InformationVariable authEvents -InformationAction SilentlyContinue
    $authEvents | Where-Object Tags -contains 'DataverseAuth' | Select-Object -Expand MessageData
    #>
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level
    )

    $log = $script:DvAuth_Log

    if ($Level) {
        $order = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }
        $min   = $order[$Level]
        $log   = $log | Where-Object { $order[$_.Level] -ge $min }
    }

    return $log
}

function Clear-DataverseAuthLog {
    <#
    .SYNOPSIS
    Clears the in-memory Dataverse auth log.
    #>
    $script:DvAuth_Log = [System.Collections.Generic.List[object]]::new()
}

# ============================================================================
# MSAL.PS Bootstrap
# ============================================================================

function Install-MsalModuleIfMissing {
    <#
    .SYNOPSIS
    Ensures the MSAL.PS module is installed and imported.
    #>
    if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
        Write-Host "Installing MSAL.PS module (first-time setup)..." -ForegroundColor Yellow
        Install-Module -Name MSAL.PS -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module MSAL.PS -ErrorAction Stop
}

# ============================================================================
# Settings Loader
# ============================================================================

function Get-AuthSettings {
    <#
    .SYNOPSIS
    Loads auth settings from file (cached per session) with env var overrides.

    .DESCRIPTION
    Resolution order:
    1. Environment variables (DATAVERSE_AUTH_MODE, DATAVERSE_CLIENT_ID, etc.)
    2. auth-settings.json in the claude-code directory
    3. Defaults (Interactive mode)

    Settings are cached in script scope after first load.
    #>
    if ($script:DvAuth_Settings) { return $script:DvAuth_Settings }

    $settings = @{
        DataverseAuthMode      = 'Interactive'
        DataverseEnvironmentUrl = ''
        DataverseClientId      = ''
        DataverseClientSecret  = ''
        DataverseTenantId      = ''
    }

    # Resolve auth-settings.json across layouts (ADR 0019 - shared scripts as a sibling
    # library skill). This module lives at <root>/skills/aidevme-shared-scripts/scripts, where
    # <root> is .claude or .github (consuming repos) — the settings file lives at
    # <root>/auth-settings.json (each repo's OWN creds, locked to its env). Probe an ordered
    # candidate list and take the first that exists. Climb scripts -> aidevme-shared-scripts -> skills -> <root>.
    $skillsRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $settingsPath = @(
        $env:DATAVERSE_AUTH_SETTINGS_PATH                                  # explicit override
        (Join-Path $skillsRoot 'auth-settings.json')                       # <root>/auth-settings.json (relative to module)
        (Join-Path (Get-Location) '.claude\auth-settings.json')            # CWD = consuming repo root
        (Join-Path (Get-Location) 'auth-settings.json')                    # CWD = a *-root dir itself
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if ($settingsPath) {
        try {
            $fileSettings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            if ($fileSettings.DataverseAuthMode)      { $settings.DataverseAuthMode      = $fileSettings.DataverseAuthMode }
            if ($fileSettings.DataverseEnvironmentUrl) { $settings.DataverseEnvironmentUrl = $fileSettings.DataverseEnvironmentUrl }
            if ($fileSettings.DataverseClientId)       { $settings.DataverseClientId      = $fileSettings.DataverseClientId }
            if ($fileSettings.DataverseClientSecret)   { $settings.DataverseClientSecret  = $fileSettings.DataverseClientSecret }
            if ($fileSettings.DataverseTenantId)       { $settings.DataverseTenantId      = $fileSettings.DataverseTenantId }
            Write-AuthLog -Level DEBUG -Event SettingsLoaded -Message "Loaded auth settings from $(Resolve-Path $settingsPath)" -Mode $settings.DataverseAuthMode -Details @{ Source = 'File'; Path = $settingsPath }
        }
        catch {
            Write-AuthLog -Level WARN -Event SettingsError -Message "Could not parse auth-settings.json: $($_.Exception.Message)" -Details @{ Path = $settingsPath; Error = $_.Exception.Message }
        }
    }

    # Environment variables override file settings
    if ($env:DATAVERSE_AUTH_MODE)       { $settings.DataverseAuthMode      = $env:DATAVERSE_AUTH_MODE }
    if ($env:DATAVERSE_ENVIRONMENT_URL) { $settings.DataverseEnvironmentUrl = $env:DATAVERSE_ENVIRONMENT_URL }
    if ($env:DATAVERSE_CLIENT_ID)       { $settings.DataverseClientId      = $env:DATAVERSE_CLIENT_ID }
    if ($env:DATAVERSE_CLIENT_SECRET)   { $settings.DataverseClientSecret  = $env:DATAVERSE_CLIENT_SECRET }
    if ($env:DATAVERSE_TENANT_ID)       { $settings.DataverseTenantId      = $env:DATAVERSE_TENANT_ID }

    Write-AuthLog -Level DEBUG -Event SettingsResolved -Message "Auth settings resolved. Mode: $($settings.DataverseAuthMode)" -Mode $settings.DataverseAuthMode

    $script:DvAuth_Settings = $settings
    return $settings
}

# ============================================================================
# Environment Guard
# ============================================================================

function Assert-DataverseEnvironment {
    <#
    .SYNOPSIS
    Validates that the requested environment URL matches the configured one (if set).

    .DESCRIPTION
    Prevents accidental calls to the wrong Dataverse environment when a locked
    environment URL is configured in settings. Only enforced when settings specify
    a DataverseEnvironmentUrl.

    .PARAMETER RequestedUrl
    The environment URL being requested by the caller.
    #>
    param([Parameter(Mandatory)][string]$RequestedUrl)

    $settings = Get-AuthSettings
    $configuredUrl = $settings.DataverseEnvironmentUrl

    if (-not $configuredUrl) { return }  # No lock configured

    $requested = $RequestedUrl.TrimEnd('/').ToLower()
    $configured = $configuredUrl.TrimEnd('/').ToLower()

    if (-not $requested.StartsWith('https://')) { $requested = "https://$requested" }
    if (-not $configured.StartsWith('https://')) { $configured = "https://$configured" }

    if ($requested -ne $configured) {
        Write-AuthLog -Level ERROR -Event EnvGuardFail -Message "Environment guard: requested '$RequestedUrl' does not match configured '$configuredUrl'" -Details @{ Requested = $RequestedUrl; Configured = $configuredUrl }
        throw "[AUTH GUARD] Environment mismatch! Requested '$RequestedUrl' but agent is configured for '$configuredUrl'. Update auth-settings.json or DATAVERSE_ENVIRONMENT_URL to change the target environment."
    }

    Write-AuthLog -Level DEBUG -Event EnvGuardPass -Message "Environment guard passed for $RequestedUrl"
}

# ============================================================================
# Token File Cache (persists across script executions)
# ============================================================================

function Get-TokenCachePath {
    <#
    .SYNOPSIS
    Returns the file path for a per-environment token cache file.
    Uses a SHA256 hash of the environment URL as the filename suffix.
    #>
    param([Parameter(Mandatory)][string]$EnvironmentUrl)

    $urlHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($EnvironmentUrl.ToLower())
        )
    ).Replace("-", "").Substring(0, 16)
    return Join-Path $env:TEMP "DataverseAuthCache_$urlHash.json"
}

function Save-TokenToCache {
    <#
    .SYNOPSIS
    Persists an access token to disk for cross-execution reuse.
    #>
    param(
        [Parameter(Mandatory)][string]$EnvironmentUrl,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][datetime]$Expiry,
        [string]$Username
    )

    $cachePath = Get-TokenCachePath -EnvironmentUrl $EnvironmentUrl
    @{
        EnvironmentUrl = $EnvironmentUrl
        Token          = $Token
        Expiry         = $Expiry.ToString("o")
        Username       = $Username
        CachedAt       = (Get-Date).ToString("o")
    } | ConvertTo-Json | Set-Content -Path $cachePath -Force
}

function Get-TokenFromCache {
    <#
    .SYNOPSIS
    Retrieves a cached token from disk if still valid (5-minute buffer).
    Returns $null if no valid cache exists.
    #>
    param([Parameter(Mandatory)][string]$EnvironmentUrl)

    $cachePath = Get-TokenCachePath -EnvironmentUrl $EnvironmentUrl
    if (-not (Test-Path $cachePath)) { return $null }

    try {
        $cacheData = Get-Content -Path $cachePath -Raw | ConvertFrom-Json
        $expiry = [datetime]::Parse($cacheData.Expiry)

        # Require at least 5 minutes remaining
        if ($expiry -gt (Get-Date).AddMinutes(5)) {
            return @{
                Token    = $cacheData.Token
                Expiry   = $expiry
                Username = $cacheData.Username
            }
        }

        # Expired — clean up
        Remove-Item $cachePath -Force -ErrorAction SilentlyContinue
        return $null
    }
    catch {
        Remove-Item $cachePath -Force -ErrorAction SilentlyContinue
        return $null
    }
}

# ============================================================================
# Interactive Authentication (MSAL.PS)
# ============================================================================

function Get-DataverseTokenInteractive {
    <#
    .SYNOPSIS
    Acquires a Dataverse access token via interactive Office 365 login.

    .DESCRIPTION
    Uses a three-tier token resolution strategy:
    1. In-memory cache (fastest, same session)
    2. File-based cache (cross-session, %TEMP%)
    3. Interactive browser login (fallback)

    .PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param([Parameter(Mandatory)][string]$EnvironmentUrl)

    $url = $EnvironmentUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # 1. In-memory cache
    if ($script:DvAuth_Token -and $script:DvAuth_Expiry -gt (Get-Date) -and $script:DvAuth_EnvUrl -eq $url) {
        Write-AuthLog -Level DEBUG -Event CacheHit -Message "Serving token from in-memory cache for $script:DvAuth_Username (expires $($script:DvAuth_Expiry.ToString('HH:mm:ss')))" -Mode Interactive -Identity $script:DvAuth_Username
        return $script:DvAuth_Token
    }

    # 2. File-based cache
    $cachedToken = Get-TokenFromCache -EnvironmentUrl $url
    if ($cachedToken) {
        $script:DvAuth_Token    = $cachedToken.Token
        $script:DvAuth_Expiry   = $cachedToken.Expiry
        $script:DvAuth_EnvUrl   = $url
        $script:DvAuth_Username = $cachedToken.Username
        Write-AuthLog -Level INFO -Event CacheHit -Message "Using file-cached token for $($cachedToken.Username) (valid until $($cachedToken.Expiry.ToString('HH:mm:ss')))" -Mode Interactive -Identity $cachedToken.Username -Details @{ Expiry = $cachedToken.Expiry }
        return $script:DvAuth_Token
    }

    # 3. Interactive login
    try {
        Write-Host "Initiating interactive Office 365 login..." -ForegroundColor Cyan
        Write-Host "A browser window will open for authentication." -ForegroundColor Gray
        Write-AuthLog -Level INFO -Event TokenAcquireStart -Message "Initiating interactive browser authentication" -Mode Interactive

        Install-MsalModuleIfMissing

        $clientId    = "51f81489-12ee-4a9e-aaae-a2591f45987d"
        $authority   = "https://login.microsoftonline.com/organizations"
        $redirectUri = "http://localhost"
        $scopes      = @("$url/.default")

        # Force the system browser instead of MSAL's embedded WebView. The embedded
        # WebView is .NET Framework-only, so under PowerShell 7 (.NET Core / pwsh) it
        # silently fails to render and the call hangs forever with no dialog. The system
        # browser uses a localhost loopback listener that works on BOTH Windows PowerShell
        # 5.1 and PowerShell 7, so the sign-in dialog appears regardless of host.
        # Mirrors the same fix in the sibling ADO-Auth.ps1 (2026-06-10).
        $msalToken = Get-MsalToken -ClientId $clientId -Authority $authority `
            -RedirectUri $redirectUri -Scopes $scopes -Interactive -UseEmbeddedWebView:$false -ErrorAction Stop

        $script:DvAuth_Token    = $msalToken.AccessToken
        $script:DvAuth_Expiry   = $msalToken.ExpiresOn.LocalDateTime
        $script:DvAuth_EnvUrl   = $url
        $script:DvAuth_Username = $msalToken.Account.Username

        Save-TokenToCache -EnvironmentUrl $url `
            -Token $msalToken.AccessToken `
            -Expiry $msalToken.ExpiresOn.LocalDateTime `
            -Username $msalToken.Account.Username

        Write-Host "[OK] Authenticated as $($msalToken.Account.Username)" -ForegroundColor Green
        Write-AuthLog -Level INFO -Event TokenAcquired -Message "Interactive authentication succeeded for $($msalToken.Account.Username) (expires $($msalToken.ExpiresOn.LocalDateTime.ToString('HH:mm:ss')))" -Mode Interactive -Identity $msalToken.Account.Username -Details @{ Expiry = $msalToken.ExpiresOn.LocalDateTime }
        return $script:DvAuth_Token
    }
    catch {
        Write-AuthLog -Level ERROR -Event TokenFailed -Message "Interactive authentication failed: $($_.Exception.Message)" -Mode Interactive -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# Tenant Discovery
# ============================================================================

function Get-DataverseTenantId {
    <#
    .SYNOPSIS
    Auto-discovers the Azure AD tenant ID for a Dataverse environment.

    .DESCRIPTION
    Makes an unauthenticated request to the Dataverse API root. The 401 response
    includes a WWW-Authenticate header with the tenant-specific authorization URI,
    from which the tenant ID is extracted. Required for service principal auth
    because the /common endpoint rejects client_credentials grant type.

    .PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

    .OUTPUTS
    Tenant ID string, or $null if discovery fails.
    #>
    param([Parameter(Mandatory)][string]$EnvironmentUrl)

    $url = $EnvironmentUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    try {
        $request = [System.Net.HttpWebRequest]::Create("$url/api/data/")
        $request.Method = "GET"
        $request.AllowAutoRedirect = $false

        $response = $null
        try { $response = $request.GetResponse() }
        catch [System.Net.WebException] { $response = $_.Exception.Response }

        if (-not $response) { return $null }

        $wwwAuth = $response.Headers["WWW-Authenticate"]
        $response.Close()

        # Header format: Bearer authorization_uri=https://login.microsoftonline.com/<tenantId>/oauth2/authorize, ...
        if ($wwwAuth -match 'authorization_uri=https://login\.microsoftonline\.com/([0-9a-f-]+)/') {
            $tenantId = $Matches[1]
            Write-AuthLog -Level DEBUG -Event TenantDiscovered -Message "Discovered Dataverse tenant: $tenantId" -Details @{ TenantId = $tenantId; EnvironmentUrl = $EnvironmentUrl }
            return $tenantId
        }
    }
    catch {
        Write-AuthLog -Level WARN -Event TenantDiscoveryFailed -Message "Tenant discovery failed for ${EnvironmentUrl}: $($_.Exception.Message)" -Details @{ EnvironmentUrl = $EnvironmentUrl; Error = $_.Exception.Message }
    }
    return $null
}

# ============================================================================
# Service Principal Authentication (Client Credentials)
# ============================================================================

function Get-DataverseTokenAppCredentials {
    <#
    .SYNOPSIS
    Acquires a Dataverse access token using client credentials (service principal).

    .DESCRIPTION
    Used for automated pipelines and non-interactive scenarios.
    Token is cached in-memory with a 5-minute buffer before expiry.
    Requires a tenant-specific token endpoint — auto-discovers tenant from the
    environment's WWW-Authenticate header if TenantId is not provided.

    .PARAMETER EnvironmentUrl
    The Dataverse environment URL.

    .PARAMETER ClientId
    The Azure AD Application (client) ID.

    .PARAMETER ClientSecret
    The client secret for the application.

    .PARAMETER TenantId
    Optional. The Azure AD tenant ID. If omitted, auto-discovered from the environment.

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$EnvironmentUrl,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret,
        [string]$TenantId
    )

    $url = $EnvironmentUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # In-memory cache check
    if ($script:DvAuth_Token -and $script:DvAuth_Expiry -gt (Get-Date) -and $script:DvAuth_EnvUrl -eq $url) {
        Write-AuthLog -Level DEBUG -Event CacheHit -Message "Serving SP token from in-memory cache (expires $($script:DvAuth_Expiry.ToString('HH:mm:ss')))" -Mode ServicePrincipal -Identity $ClientId
        return $script:DvAuth_Token
    }

    try {
        # Resolve tenant ID — required for client_credentials (common/organizations endpoints reject it)
        if (-not $TenantId) {
            $TenantId = Get-DataverseTenantId -EnvironmentUrl $url
        }
        if (-not $TenantId) {
            Write-AuthLog -Level ERROR -Event SettingsError -Message "ServicePrincipal mode requires a tenant ID. Set DataverseTenantId in auth-settings.json or DATAVERSE_TENANT_ID env var." -Mode ServicePrincipal
            return $null
        }

        $authUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"

        $body = @{
            grant_type    = "client_credentials"
            client_id     = $ClientId
            client_secret = $ClientSecret
            resource      = $url
        }

        Write-AuthLog -Level INFO -Event TokenAcquireStart -Message "Acquiring Dataverse token via service principal (ClientId: $ClientId, Tenant: $TenantId)" -Mode ServicePrincipal -Identity $ClientId
        $tokenResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"

        $script:DvAuth_Token  = $tokenResponse.access_token
        $script:DvAuth_Expiry = (Get-Date).AddSeconds($tokenResponse.expires_in - 300)
        $script:DvAuth_EnvUrl = $url

        Write-AuthLog -Level INFO -Event TokenAcquired -Message "Service principal authentication succeeded (ClientId: $ClientId)" -Mode ServicePrincipal -Identity $ClientId -Details @{ Expiry = $script:DvAuth_Expiry }
        return $script:DvAuth_Token
    }
    catch {
        Write-AuthLog -Level ERROR -Event TokenFailed -Message "Service principal authentication failed: $($_.Exception.Message)" -Mode ServicePrincipal -Identity $ClientId -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# Managed Identity Authentication (Azure IMDS)
# ============================================================================

function Get-DataverseTokenManagedIdentity {
    <#
    .SYNOPSIS
    Acquires a Dataverse access token via Azure Managed Identity (IMDS).

    .DESCRIPTION
    Used for Azure-hosted agents (VMs, App Services, Container Instances) where
    a system-assigned or user-assigned managed identity is configured.
    Calls the Azure Instance Metadata Service (IMDS) endpoint.
    Token is cached in-memory with a 5-minute buffer before expiry.

    .PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

    .PARAMETER ClientId
    Optional. The client ID of a user-assigned managed identity.
    Omit to use the system-assigned identity.

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$EnvironmentUrl,
        [string]$ClientId
    )

    $url = $EnvironmentUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # In-memory cache check
    if ($script:DvAuth_Token -and $script:DvAuth_Expiry -gt (Get-Date) -and $script:DvAuth_EnvUrl -eq $url) {
        Write-AuthLog -Level DEBUG -Event CacheHit -Message "Serving MI token from in-memory cache (expires $($script:DvAuth_Expiry.ToString('HH:mm:ss')))" -Mode ManagedIdentity -Identity 'ManagedIdentity'
        return $script:DvAuth_Token
    }

    try {
        Write-AuthLog -Level INFO -Event TokenAcquireStart -Message "Acquiring Dataverse token via Managed Identity (IMDS)$(if ($ClientId) { " [UserAssigned: $ClientId]" })" -Mode ManagedIdentity

        $imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=$url"
        if ($ClientId) {
            $imdsUrl += "&client_id=$ClientId"
        }

        $tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Method Get `
            -Headers @{ "Metadata" = "true" } -ErrorAction Stop

        $script:DvAuth_Token  = $tokenResponse.access_token
        $script:DvAuth_Expiry = (Get-Date).AddSeconds([int]$tokenResponse.expires_in - 300)
        $script:DvAuth_EnvUrl = $url
        $script:DvAuth_Username = "ManagedIdentity"

        Write-AuthLog -Level INFO -Event TokenAcquired -Message "Managed Identity authentication succeeded (expires $($script:DvAuth_Expiry.ToString('HH:mm:ss')))" -Mode ManagedIdentity -Identity 'ManagedIdentity' -Details @{ Expiry = $script:DvAuth_Expiry; UserAssignedClientId = $ClientId }
        return $script:DvAuth_Token
    }
    catch {
        Write-AuthLog -Level ERROR -Event TokenFailed -Message "Managed Identity authentication failed: $($_.Exception.Message). Ensure a managed identity is assigned and has Dataverse Application User access." -Mode ManagedIdentity -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# Device Code Flow Authentication (OAuth2 REST — no MSAL.PS dependency)
# ============================================================================

function Get-DataverseTokenDeviceCode {
    <#
    .SYNOPSIS
    Acquires a Dataverse access token via device code flow.

    .DESCRIPTION
    MFA-compatible flow that works without a browser on the local machine.
    Displays a URL and code for the user to authenticate on any device.
    Ideal for headless/SSH scenarios or when the coding agent can't pop a browser.
    Implemented directly via OAuth2 REST endpoints (no MSAL.PS -DeviceCode dependency).

    Uses the same three-tier caching strategy as interactive:
    1. In-memory cache (fastest, same session)
    2. File-based cache (cross-session, %TEMP%)
    3. Device code flow (fallback)

    .PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param([Parameter(Mandatory)][string]$EnvironmentUrl)

    $url = $EnvironmentUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # 1. In-memory cache
    if ($script:DvAuth_Token -and $script:DvAuth_Expiry -gt (Get-Date) -and $script:DvAuth_EnvUrl -eq $url) {
        Write-AuthLog -Level DEBUG -Event CacheHit -Message "Serving device code token from in-memory cache for $script:DvAuth_Username (expires $($script:DvAuth_Expiry.ToString('HH:mm:ss')))" -Mode DeviceCode -Identity $script:DvAuth_Username
        return $script:DvAuth_Token
    }

    # 2. File-based cache
    $cachedToken = Get-TokenFromCache -EnvironmentUrl $url
    if ($cachedToken) {
        $script:DvAuth_Token    = $cachedToken.Token
        $script:DvAuth_Expiry   = $cachedToken.Expiry
        $script:DvAuth_EnvUrl   = $url
        $script:DvAuth_Username = $cachedToken.Username
        Write-AuthLog -Level INFO -Event CacheHit -Message "Using file-cached token for $($cachedToken.Username) (valid until $($cachedToken.Expiry.ToString('HH:mm:ss')))" -Mode DeviceCode -Identity $cachedToken.Username -Details @{ Expiry = $cachedToken.Expiry }
        return $script:DvAuth_Token
    }

    # 3. Device code flow via OAuth2 REST
    try {
        Write-AuthLog -Level INFO -Event TokenAcquireStart -Message "Initiating device code authentication" -Mode DeviceCode

        $clientId  = "51f81489-12ee-4a9e-aaae-a2591f45987d"
        $authority = "https://login.microsoftonline.com/organizations"
        $scope     = "$url/.default"

        # Step 1 — Request a device code
        $dcResponse = Invoke-RestMethod -Uri "$authority/oauth2/v2.0/devicecode" -Method Post `
            -ContentType "application/x-www-form-urlencoded" `
            -Body @{ client_id = $clientId; scope = $scope } -ErrorAction Stop

        Write-Host ""
        Write-Host "  To sign in, open a browser and go to:" -ForegroundColor Cyan
        Write-Host "  $($dcResponse.verification_uri)" -ForegroundColor Yellow
        Write-Host "  Enter code: $($dcResponse.user_code)" -ForegroundColor Yellow
        Write-Host ""

        # Step 2 — Poll until token is issued or code expires
        $interval  = [int]$dcResponse.interval
        $deadline  = (Get-Date).AddSeconds([int]$dcResponse.expires_in)
        $tokenResponse = $null
        $pollCount = 0

        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $interval
            $pollCount++
            $remaining = [int]($deadline - (Get-Date)).TotalSeconds
            Write-Host "  Waiting for authentication... ($remaining s remaining)   " -NoNewline -ForegroundColor DarkGray
            Write-Host "`r" -NoNewline
            try {
                $tokenResponse = Invoke-RestMethod -Uri "$authority/oauth2/v2.0/token" -Method Post `
                    -ContentType "application/x-www-form-urlencoded" `
                    -Body @{
                        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                        client_id   = $clientId
                        device_code = $dcResponse.device_code
                    } -ErrorAction Stop
                Write-Host "  Authentication confirmed.                              " -ForegroundColor DarkGray
                break
            }
            catch {
                $errBody = $null
                try { $errBody = $_.ErrorDetails.Message | ConvertFrom-Json } catch { }
                $errCode = if ($errBody) { $errBody.error } else { '' }
                if ($errCode -eq 'authorization_pending') { continue }
                elseif ($errCode -eq 'slow_down') { $interval += 5; continue }
                else { throw }
            }
        }

        if (-not $tokenResponse) {
            throw "Device code flow timed out — code expired before authentication completed."
        }

        $expiry   = (Get-Date).AddSeconds([int]$tokenResponse.expires_in - 300)

        # Best-effort username extraction from JWT claims
        $username = ''
        try {
            $payload = $tokenResponse.access_token.Split('.')[1]
            $pad = 4 - ($payload.Length % 4); if ($pad -ne 4) { $payload += '=' * $pad }
            $claims  = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
            $username = if ($claims.upn) { $claims.upn } elseif ($claims.preferred_username) { $claims.preferred_username } else { $claims.sub }
        } catch { }

        $script:DvAuth_Token    = $tokenResponse.access_token
        $script:DvAuth_Expiry   = $expiry
        $script:DvAuth_EnvUrl   = $url
        $script:DvAuth_Username = $username

        Save-TokenToCache -EnvironmentUrl $url -Token $tokenResponse.access_token -Expiry $expiry -Username $username

        Write-Host "[OK] Authenticated via device code$(if ($username) { " as $username" })" -ForegroundColor Green
        Write-AuthLog -Level INFO -Event TokenAcquired -Message "Device code authentication succeeded$(if ($username) { " for $username" }) (expires $($expiry.ToString('HH:mm:ss')))" -Mode DeviceCode -Identity $username -Details @{ Expiry = $expiry }
        return $script:DvAuth_Token
    }
    catch {
        Write-AuthLog -Level ERROR -Event TokenFailed -Message "Device code authentication failed: $($_.Exception.Message)" -Mode DeviceCode -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# Unified Entry Point
# ============================================================================

function Get-DataverseToken {
    <#
    .SYNOPSIS
    Unified authentication entry point — auto-resolves the best auth method.

    .DESCRIPTION
    Always routes through the settings-driven resolver regardless of parameters.
    The -Interactive switch is accepted for backward compatibility with existing
    skill scripts but does NOT force interactive mode — settings determine the flow.

    Resolution order:
    1. Environment variables (DATAVERSE_AUTH_MODE, etc.)
    2. Settings file (auth-settings.json)
    3. Default: Interactive

    Supported modes (set via settings or env var):
    - ManagedIdentity: Azure IMDS (for hosted agents on Azure)
    - ServicePrincipal: Client credentials (for automated pipelines)
    - DeviceCode: MSAL device code flow (for headless/SSH local dev)
    - Interactive: Browser-based MSAL login (default for local dev)

    .PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

    .PARAMETER Interactive
    Accepted for backward compatibility. Does not override settings-driven resolution.

    .PARAMETER ClientId
    Azure AD Application ID. If provided with ClientSecret, overrides settings
    and forces service principal auth (for explicit pipeline use).

    .PARAMETER ClientSecret
    Client secret. If provided with ClientId, overrides settings.

    .OUTPUTS
    Access token string, or $null on failure.

    .EXAMPLE
    # Auto-resolve (reads settings/env vars to pick the right flow)
    $token = Get-DataverseToken -EnvironmentUrl "https://myorg.crm.dynamics.com"

    .EXAMPLE
    # Called from existing skills with -Interactive — still auto-resolves from settings
    $token = Get-DataverseToken -EnvironmentUrl "https://myorg.crm.dynamics.com" -Interactive

    .EXAMPLE
    # Explicit service principal override (bypasses settings)
    $token = Get-DataverseToken -EnvironmentUrl $url -ClientId $id -ClientSecret $secret
    #>
    param(
        # Not mandatory: falls back to settings' DataverseEnvironmentUrl below, then Assert validates.
        [string]$EnvironmentUrl,

        [switch]$Interactive,

        [string]$ClientId,
        [string]$ClientSecret
    )

    # --- Explicit ClientId/Secret override (pipeline scenarios passing creds directly) ---
    if ($ClientId -and $ClientSecret) {
        Assert-DataverseEnvironment -RequestedUrl $EnvironmentUrl
        $settings = Get-AuthSettings
        return Get-DataverseTokenAppCredentials -EnvironmentUrl $EnvironmentUrl `
            -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $settings.DataverseTenantId
    }

    # --- Settings-driven auto-resolution (same path whether -Interactive is passed or not) ---
    $settings = Get-AuthSettings
    $mode = $settings.DataverseAuthMode

    # If settings specify an environment URL and caller didn't, use it
    if (-not $EnvironmentUrl -and $settings.DataverseEnvironmentUrl) {
        $EnvironmentUrl = $settings.DataverseEnvironmentUrl
    }

    Assert-DataverseEnvironment -RequestedUrl $EnvironmentUrl

    Write-AuthLog -Level INFO -Event ModeResolved -Message "Auth mode resolved: $mode" -Mode $mode

    switch ($mode) {
        'ManagedIdentity' {
            return Get-DataverseTokenManagedIdentity -EnvironmentUrl $EnvironmentUrl `
                -ClientId $settings.DataverseClientId
        }
        'ServicePrincipal' {
            if (-not $settings.DataverseClientId -or -not $settings.DataverseClientSecret) {
                Write-AuthLog -Level ERROR -Event SettingsError -Message "ServicePrincipal mode requires DataverseClientId and DataverseClientSecret in settings." -Mode ServicePrincipal
                return $null
            }
            return Get-DataverseTokenAppCredentials -EnvironmentUrl $EnvironmentUrl `
                -ClientId $settings.DataverseClientId -ClientSecret $settings.DataverseClientSecret `
                -TenantId $settings.DataverseTenantId
        }
        'DeviceCode' {
            return Get-DataverseTokenDeviceCode -EnvironmentUrl $EnvironmentUrl
        }
        'Interactive' {
            return Get-DataverseTokenInteractive -EnvironmentUrl $EnvironmentUrl
        }
        default {
            Write-AuthLog -Level ERROR -Event ModeResolved -Message "Unknown DataverseAuthMode '$mode'. Valid modes: Interactive, DeviceCode, ServicePrincipal, ManagedIdentity" -Mode $mode
            return $null
        }
    }
}

# ============================================================================
# Convenience: Get the current environment URL after authentication
# ============================================================================

function Get-DataverseEnvironmentUrl {
    <#
    .SYNOPSIS
    Returns the environment URL that was used for the last successful authentication.
    #>
    return $script:DvAuth_EnvUrl
}

# ============================================================================
# Convenience: auto-load the Web API helpers
# ============================================================================
# Dot-sourcing Dataverse-Auth.ps1 alone, then calling Invoke-DataverseApi, was a recurring footgun
# ('Invoke-DataverseApi is not recognized') — the Web API helpers live in the sibling Dataverse-WebApi.ps1
# and callers routinely forgot the second dot-source. Auth always precedes Web API use, so loading the
# Web API helpers here makes sourcing Auth sufficient. Idempotent: scripts that still source both just
# redefine the functions (harmless). Dataverse-WebApi.ps1 does NOT source Auth, so there is no cycle.
$dvWebApiPath = Join-Path $PSScriptRoot 'Dataverse-WebApi.ps1'
if (Test-Path -LiteralPath $dvWebApiPath) { . $dvWebApiPath }
