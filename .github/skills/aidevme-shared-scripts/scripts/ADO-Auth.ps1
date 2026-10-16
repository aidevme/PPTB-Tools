<#
.SYNOPSIS
Shared Azure DevOps authentication functions for all skills and scripts.

.DESCRIPTION
Centralized authentication module providing:
- Settings-driven auth resolver (auto-selects the right flow)
- Interactive authentication via MSAL.PS with file + in-memory token caching
- Device Code flow for headless/SSH scenarios (MFA-compatible)
- Managed Identity for Azure-hosted agents
- PAT (Personal Access Token) fallback for orgs that restrict OAuth consent
- Unified Get-AdoToken entry point

Dot-source this file at the top of any ADO skill script:
    $sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
    . "$sharedDir\ADO-Auth.ps1"

ADO-Auth.ps1 is self-contained — Dataverse-Auth.ps1 is NOT required.
If both are dot-sourced in the same session, the shared Install-MsalModuleIfMissing
definition is harmlessly overwritten (identical implementation).

Auth mode is determined by (in priority order):
1. Explicit parameters passed to Get-AdoToken (-Interactive, -Pat)
2. Environment variable: ADO_AUTH_MODE
3. Settings file: <repo-root>/auth-settings.json (`.claude/auth-settings.json` in a consuming repo —
   gitignored, holding that repo's own creds; never inside the synced skill tree)
4. Default: Interactive

.NOTES
Client ID: 04b07795-8ddb-461a-bbee-02f9e1bf7b46 (Azure CLI public client)
Resource:  499b84ac-1321-427f-aa17-267ca6975798 (Azure DevOps)
Token cache: %TEMP%\AdoAuthCache_<SHA256hash>.json (per org URL)
#>

# ============================================================================
# Script-scoped state (shared across all callers in the same session)
# ============================================================================

if (-not (Get-Variable -Name 'AdoAuth_Token'    -Scope Script -ErrorAction SilentlyContinue)) { $script:AdoAuth_Token    = $null }
if (-not (Get-Variable -Name 'AdoAuth_Expiry'   -Scope Script -ErrorAction SilentlyContinue)) { $script:AdoAuth_Expiry   = $null }
if (-not (Get-Variable -Name 'AdoAuth_OrgUrl'   -Scope Script -ErrorAction SilentlyContinue)) { $script:AdoAuth_OrgUrl   = $null }
if (-not (Get-Variable -Name 'AdoAuth_Username' -Scope Script -ErrorAction SilentlyContinue)) { $script:AdoAuth_Username = $null }
if (-not (Get-Variable -Name 'AdoAuth_AuthType' -Scope Script -ErrorAction SilentlyContinue)) { $script:AdoAuth_AuthType = $null }
if (-not (Get-Variable -Name 'AdoAuth_Log'      -Scope Script -ErrorAction SilentlyContinue)) { $script:AdoAuth_Log      = [System.Collections.Generic.List[object]]::new() }

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
# Auth Logging
# ============================================================================

function Write-AdoAuthLog {
    <#
    .SYNOPSIS
    Records a structured ADO auth event to the in-memory log and PowerShell streams.

    .DESCRIPTION
    Three outputs:
      1. $script:AdoAuth_Log — queryable in-memory list (use Get-AdoAuthLog)
      2. Write-Verbose       — shown when the caller uses -Verbose
      3. Write-Information   — capturable via -InformationVariable or -InformationAction
                               in hosted scenarios (tag: 'AdoAuth')

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
        Source    = 'ADO'
        Event     = $Event
        Mode      = if ($Mode)     { $Mode }     else { '' }
        Identity  = if ($Identity) { $Identity } else { '' }
        Message   = $Message
        Details   = if ($Details)  { $Details }  else { @{} }
    }

    $script:AdoAuth_Log.Add($entry)

    Write-Verbose "[AdoAuth][$Level][$Event] $Message"
    Write-Information -MessageData $entry -Tags 'AdoAuth'

    if ($Level -eq 'WARN')  { Write-Warning "[AdoAuth] $Message" }
    if ($Level -eq 'ERROR') { Write-Warning "[AdoAuth][ERROR] $Message" }
}

function Get-AdoAuthLog {
    <#
    .SYNOPSIS
    Returns the structured ADO auth log for the current session.

    .DESCRIPTION
    Returns all auth events recorded since the module was loaded or since
    Clear-AdoAuthLog was last called. Each entry is a PSCustomObject with:
      Timestamp, Level (DEBUG/INFO/WARN/ERROR), Source, Event, Mode, Identity, Message, Details

    .PARAMETER Level
    Optional minimum level filter. Order: DEBUG < INFO < WARN < ERROR.

    .EXAMPLE
    # Show the full ADO auth trace
    Get-AdoAuthLog | Format-Table Timestamp, Level, Event, Message -AutoSize

    .EXAMPLE
    # Show only warnings and errors
    Get-AdoAuthLog -Level WARN

    .EXAMPLE
    # Capture ADO auth events in a hosted agent
    $auth = Get-AdoToken -OrgUrl $url -InformationVariable authEvents -InformationAction SilentlyContinue
    $authEvents | Where-Object Tags -contains 'AdoAuth' | Select-Object -Expand MessageData
    #>
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level
    )

    $log = $script:AdoAuth_Log

    if ($Level) {
        $order = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }
        $min   = $order[$Level]
        $log   = $log | Where-Object { $order[$_.Level] -ge $min }
    }

    return $log
}

function Clear-AdoAuthLog {
    <#
    .SYNOPSIS
    Clears the in-memory ADO auth log.
    #>
    $script:AdoAuth_Log = [System.Collections.Generic.List[object]]::new()
}

# ============================================================================
# Token File Cache (persists across script executions)
# ============================================================================

function Get-AdoTokenCachePath {
    <#
    .SYNOPSIS
    Returns the file path for a per-org ADO token cache file.
    #>
    param([Parameter(Mandatory)][string]$OrgUrl)

    $urlHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($OrgUrl.ToLower())
        )
    ).Replace("-", "").Substring(0, 16)
    return Join-Path $env:TEMP "AdoAuthCache_$urlHash.json"
}

function Save-AdoTokenToCache {
    <#
    .SYNOPSIS
    Persists an ADO access token to disk for cross-execution reuse.
    #>
    param(
        [Parameter(Mandatory)][string]$OrgUrl,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][datetime]$Expiry,
        [string]$Username
    )

    $cachePath = Get-AdoTokenCachePath -OrgUrl $OrgUrl
    @{
        OrgUrl   = $OrgUrl
        Token    = $Token
        Expiry   = $Expiry.ToString("o")
        Username = $Username
        CachedAt = (Get-Date).ToString("o")
    } | ConvertTo-Json | Set-Content -Path $cachePath -Force
}

function Get-AdoTokenFromCache {
    <#
    .SYNOPSIS
    Retrieves a cached ADO token from disk if still valid (5-minute buffer).
    Returns $null if no valid cache exists.
    #>
    param([Parameter(Mandatory)][string]$OrgUrl)

    $cachePath = Get-AdoTokenCachePath -OrgUrl $OrgUrl
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
# Tenant Discovery
# ============================================================================

function Get-AdoOrgTenantId {
    <#
    .SYNOPSIS
    Auto-discovers the Azure AD tenant ID for an Azure DevOps organization.

    .DESCRIPTION
    Makes an unauthenticated request to the ADO org. ADO responds with a 302 redirect
    to the sign-in page, which includes an 'lltid' query parameter containing the
    tenant ID. This is necessary for guest accounts whose home tenant differs from
    the ADO org's tenant.

    .PARAMETER OrgUrl
    The Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg)

    .OUTPUTS
    Tenant ID string, or $null if discovery fails (falls back to 'organizations').
    #>
    param([Parameter(Mandatory)][string]$OrgUrl)

    try {
        # Hit the org root URL without auth — ADO returns a 302 with the
        # X-VSS-ResourceTenant header containing the org's Azure AD tenant ID.
        # This is reliable across all ADO orgs (unlike the lltid query parameter
        # in the redirect URL, which is a session-specific value).
        $request = [System.Net.HttpWebRequest]::Create($OrgUrl)
        $request.Method = "GET"
        $request.AllowAutoRedirect = $false

        $response = $null
        try { $response = $request.GetResponse() }
        catch [System.Net.WebException] { $response = $_.Exception.Response }

        if (-not $response) { return $null }

        $tenantId = $response.Headers["X-VSS-ResourceTenant"]
        $response.Close()

        if ($tenantId -and $tenantId -match '^[0-9a-f-]+$') {
            Write-AdoAuthLog -Level DEBUG -Event TenantDiscovered -Message "Discovered ADO org tenant: $tenantId" -Details @{ TenantId = $tenantId; OrgUrl = $OrgUrl }
            return $tenantId
        }
    }
    catch {
        Write-AdoAuthLog -Level WARN -Event TenantDiscoveryFailed -Message "Tenant discovery failed for ${OrgUrl}: $($_.Exception.Message)" -Details @{ OrgUrl = $OrgUrl; Error = $_.Exception.Message }
    }
    return $null
}

# ============================================================================
# Interactive Authentication (MSAL.PS)
# ============================================================================

function Get-AdoTokenInteractive {
    <#
    .SYNOPSIS
    Acquires an Azure DevOps access token via interactive browser login.

    .DESCRIPTION
    Uses a four-tier token resolution strategy:
    1. In-memory cache (fastest, same session)
    2. File-based cache (cross-session, %TEMP%)
    3. Tenant auto-discovery (required for guest accounts in cross-tenant orgs)
    4. Interactive browser login (fallback)

    .PARAMETER OrgUrl
    The Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg)

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param([Parameter(Mandatory)][string]$OrgUrl)

    $url = $OrgUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # 1. In-memory cache
    if ($script:AdoAuth_Token -and $script:AdoAuth_Expiry -gt (Get-Date) -and $script:AdoAuth_OrgUrl -eq $url -and $script:AdoAuth_AuthType -eq 'Interactive') {
        Write-AdoAuthLog -Level DEBUG -Event CacheHit -Message "Serving ADO token from in-memory cache for $script:AdoAuth_Username (expires $($script:AdoAuth_Expiry.ToString('HH:mm:ss')))" -Mode Interactive -Identity $script:AdoAuth_Username
        return $script:AdoAuth_Token
    }

    # 2. File-based cache
    $cachedToken = Get-AdoTokenFromCache -OrgUrl $url
    if ($cachedToken) {
        $script:AdoAuth_Token    = $cachedToken.Token
        $script:AdoAuth_Expiry   = $cachedToken.Expiry
        $script:AdoAuth_OrgUrl   = $url
        $script:AdoAuth_Username = $cachedToken.Username
        $script:AdoAuth_AuthType = 'Interactive'
        Write-AdoAuthLog -Level INFO -Event CacheHit -Message "Using file-cached ADO token for $($cachedToken.Username) (valid until $($cachedToken.Expiry.ToString('HH:mm:ss')))" -Mode Interactive -Identity $cachedToken.Username -Details @{ Expiry = $cachedToken.Expiry }
        return $script:AdoAuth_Token
    }

    # 3. Interactive login with tenant auto-discovery
    try {
        Write-Host "Initiating interactive Azure DevOps login..." -ForegroundColor Cyan
        Write-AdoAuthLog -Level INFO -Event TokenAcquireStart -Message "Initiating interactive browser authentication for ADO" -Mode Interactive

        Install-MsalModuleIfMissing

        # Auto-discover the org's tenant ID (critical for guest accounts)
        $tenantId = Get-AdoOrgTenantId -OrgUrl $url
        if ($tenantId) {
            $authority = "https://login.microsoftonline.com/$tenantId"
        } else {
            $authority = "https://login.microsoftonline.com/organizations"
            Write-AdoAuthLog -Level WARN -Event TenantDiscoveryFailed -Message "Tenant discovery unavailable, using default 'organizations' authority" -Mode Interactive
        }

        $clientId    = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"   # Azure CLI public client
        $redirectUri = "http://localhost"
        $scopes      = @("499b84ac-1321-427f-aa17-267ca6975798/.default")  # Azure DevOps resource

        Write-Host "A browser window will open for authentication." -ForegroundColor Gray

        # Force the system browser instead of MSAL's embedded WebView. The embedded
        # WebView is .NET Framework-only, so under PowerShell 7 (.NET Core / pwsh) it
        # silently fails to render and the call hangs forever with no dialog. The system
        # browser uses a localhost loopback listener that works on BOTH Windows PowerShell
        # 5.1 and PowerShell 7, so the sign-in dialog appears regardless of host.
        $msalToken = Get-MsalToken -ClientId $clientId -Authority $authority `
            -RedirectUri $redirectUri -Scopes $scopes -Interactive -UseEmbeddedWebView:$false -ErrorAction Stop

        $script:AdoAuth_Token    = $msalToken.AccessToken
        $script:AdoAuth_Expiry   = $msalToken.ExpiresOn.LocalDateTime
        $script:AdoAuth_OrgUrl   = $url
        $script:AdoAuth_Username = $msalToken.Account.Username
        $script:AdoAuth_AuthType = 'Interactive'

        Save-AdoTokenToCache -OrgUrl $url `
            -Token $msalToken.AccessToken `
            -Expiry $msalToken.ExpiresOn.LocalDateTime `
            -Username $msalToken.Account.Username

        Write-Host "[OK] Authenticated as $($msalToken.Account.Username)" -ForegroundColor Green
        Write-AdoAuthLog -Level INFO -Event TokenAcquired -Message "ADO interactive authentication succeeded for $($msalToken.Account.Username) (expires $($msalToken.ExpiresOn.LocalDateTime.ToString('HH:mm:ss')))" -Mode Interactive -Identity $msalToken.Account.Username -Details @{ Expiry = $msalToken.ExpiresOn.LocalDateTime }
        return $script:AdoAuth_Token
    }
    catch {
        Write-AdoAuthLog -Level ERROR -Event TokenFailed -Message "ADO interactive authentication failed: $($_.Exception.Message)" -Mode Interactive -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# ADO Settings Loader
# ============================================================================

function Get-AdoAuthSettings {
    <#
    .SYNOPSIS
    Loads ADO-specific auth settings from file with env var overrides.
    Leverages Get-AuthSettings from Dataverse-Auth.ps1 for the file loader,
    then applies ADO-specific env var overrides.
    #>
    $settings = @{
        AdoAuthMode     = 'Interactive'
        AdoOrgUrl       = ''
        AdoPat          = ''
        AdoClientId     = ''
        AdoClientSecret = ''
        AdoTenantId     = ''
    }

    # Resolve auth-settings.json across layouts (ADR 0019 - shared scripts as a sibling
    # library skill; this is the SAME file as the Dataverse settings). The module lives at
    # <root>/skills/aidevme-shared-scripts/scripts; the settings file lives at <root>/auth-settings.json
    # (<root> = .claude | .github, each consuming repo's OWN creds). Probe an ordered candidate
    # list and take the first that exists. Climb scripts -> aidevme-shared-scripts -> skills -> <root>.
    $skillsRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $settingsPath = @(
        $env:DATAVERSE_AUTH_SETTINGS_PATH                                  # explicit override (shared settings file)
        (Join-Path $skillsRoot 'auth-settings.json')                       # <root>/auth-settings.json (relative to module)
        (Join-Path (Get-Location) '.claude\auth-settings.json')            # CWD = consuming repo root
        (Join-Path (Get-Location) 'auth-settings.json')                    # CWD = a *-root dir itself
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if ($settingsPath) {
        try {
            $fileSettings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            if ($fileSettings.AdoAuthMode)     { $settings.AdoAuthMode     = $fileSettings.AdoAuthMode }
            if ($fileSettings.AdoOrgUrl)       { $settings.AdoOrgUrl       = $fileSettings.AdoOrgUrl }
            if ($fileSettings.AdoPat)          { $settings.AdoPat          = $fileSettings.AdoPat }
            if ($fileSettings.AdoClientId)     { $settings.AdoClientId     = $fileSettings.AdoClientId }
            if ($fileSettings.AdoClientSecret) { $settings.AdoClientSecret = $fileSettings.AdoClientSecret }
            if ($fileSettings.AdoTenantId)     { $settings.AdoTenantId     = $fileSettings.AdoTenantId }
        }
        catch { }
    }

    # Environment variables override file settings
    if ($env:ADO_AUTH_MODE)     { $settings.AdoAuthMode     = $env:ADO_AUTH_MODE }
    if ($env:ADO_ORG_URL)      { $settings.AdoOrgUrl       = $env:ADO_ORG_URL }
    if ($env:ADO_PAT)          { $settings.AdoPat          = $env:ADO_PAT }
    if ($env:ADO_CLIENT_ID)    { $settings.AdoClientId     = $env:ADO_CLIENT_ID }
    if ($env:ADO_CLIENT_SECRET){ $settings.AdoClientSecret = $env:ADO_CLIENT_SECRET }
    if ($env:ADO_TENANT_ID)    { $settings.AdoTenantId     = $env:ADO_TENANT_ID }

    Write-AdoAuthLog -Level DEBUG -Event SettingsResolved -Message "ADO auth settings resolved. Mode: $($settings.AdoAuthMode)" -Mode $settings.AdoAuthMode

    return $settings
}

# ============================================================================
# Device Code Flow Authentication (OAuth2 REST — no MSAL.PS dependency) — ADO
# ============================================================================

function Get-AdoTokenDeviceCode {
    <#
    .SYNOPSIS
    Acquires an Azure DevOps access token via device code flow.

    .DESCRIPTION
    MFA-compatible flow that works without a browser on the local machine.
    Displays a URL and code for the user to authenticate on any device.
    Implemented directly via OAuth2 REST endpoints (no MSAL.PS -DeviceCode dependency).

    .PARAMETER OrgUrl
    The Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg)

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param([Parameter(Mandatory)][string]$OrgUrl)

    $url = $OrgUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # 1. In-memory cache
    if ($script:AdoAuth_Token -and $script:AdoAuth_Expiry -gt (Get-Date) -and $script:AdoAuth_OrgUrl -eq $url -and $script:AdoAuth_AuthType -eq 'DeviceCode') {
        Write-AdoAuthLog -Level DEBUG -Event CacheHit -Message "Serving ADO device code token from in-memory cache for $script:AdoAuth_Username (expires $($script:AdoAuth_Expiry.ToString('HH:mm:ss')))" -Mode DeviceCode -Identity $script:AdoAuth_Username
        return $script:AdoAuth_Token
    }

    # 2. File-based cache
    $cachedToken = Get-AdoTokenFromCache -OrgUrl $url
    if ($cachedToken) {
        $script:AdoAuth_Token    = $cachedToken.Token
        $script:AdoAuth_Expiry   = $cachedToken.Expiry
        $script:AdoAuth_OrgUrl   = $url
        $script:AdoAuth_Username = $cachedToken.Username
        $script:AdoAuth_AuthType = 'DeviceCode'
        Write-AdoAuthLog -Level INFO -Event CacheHit -Message "Using file-cached ADO token for $($cachedToken.Username) (valid until $($cachedToken.Expiry.ToString('HH:mm:ss')))" -Mode DeviceCode -Identity $cachedToken.Username -Details @{ Expiry = $cachedToken.Expiry }
        return $script:AdoAuth_Token
    }

    # 3. Device code flow via OAuth2 REST
    try {
        Write-AdoAuthLog -Level INFO -Event TokenAcquireStart -Message "Initiating device code authentication for ADO" -Mode DeviceCode

        $clientId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"   # Azure CLI public client
        $adoScope = "499b84ac-1321-427f-aa17-267ca6975798/.default"

        # Use tenant-specific authority if discoverable (required for guest accounts)
        $tenantId  = Get-AdoOrgTenantId -OrgUrl $url
        $authority = if ($tenantId) { "https://login.microsoftonline.com/$tenantId" } `
                     else           { "https://login.microsoftonline.com/organizations" }

        # Step 1 — Request a device code
        $dcResponse = Invoke-RestMethod -Uri "$authority/oauth2/v2.0/devicecode" -Method Post `
            -ContentType "application/x-www-form-urlencoded" `
            -Body @{ client_id = $clientId; scope = $adoScope } -ErrorAction Stop

        Write-Host ""
        Write-Host "  To sign in, open a browser and go to:" -ForegroundColor Cyan
        Write-Host "  $($dcResponse.verification_uri)" -ForegroundColor Yellow
        Write-Host "  Enter code: $($dcResponse.user_code)" -ForegroundColor Yellow
        Write-Host ""

        # Step 2 — Poll until token is issued or code expires
        $interval  = [int]$dcResponse.interval
        $deadline  = (Get-Date).AddSeconds([int]$dcResponse.expires_in)
        $tokenResponse = $null

        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $interval
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

        $expiry = (Get-Date).AddSeconds([int]$tokenResponse.expires_in - 300)

        # Best-effort username extraction from JWT claims
        $username = ''
        try {
            $payload = $tokenResponse.access_token.Split('.')[1]
            $pad = 4 - ($payload.Length % 4); if ($pad -ne 4) { $payload += '=' * $pad }
            $claims  = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
            $username = if ($claims.upn) { $claims.upn } elseif ($claims.preferred_username) { $claims.preferred_username } else { $claims.sub }
        } catch { }

        $script:AdoAuth_Token    = $tokenResponse.access_token
        $script:AdoAuth_Expiry   = $expiry
        $script:AdoAuth_OrgUrl   = $url
        $script:AdoAuth_Username = $username
        $script:AdoAuth_AuthType = 'DeviceCode'

        Save-AdoTokenToCache -OrgUrl $url -Token $tokenResponse.access_token -Expiry $expiry -Username $username

        Write-Host "[OK] Authenticated to ADO via device code$(if ($username) { " as $username" })" -ForegroundColor Green
        Write-AdoAuthLog -Level INFO -Event TokenAcquired -Message "ADO device code authentication succeeded$(if ($username) { " for $username" }) (expires $($expiry.ToString('HH:mm:ss')))" -Mode DeviceCode -Identity $username -Details @{ Expiry = $expiry }
        return $script:AdoAuth_Token
    }
    catch {
        Write-AdoAuthLog -Level ERROR -Event TokenFailed -Message "ADO device code authentication failed: $($_.Exception.Message)" -Mode DeviceCode -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# Managed Identity Authentication (Azure IMDS) — ADO
# ============================================================================

function Get-AdoTokenManagedIdentity {
    <#
    .SYNOPSIS
    Acquires an Azure DevOps access token via Azure Managed Identity (IMDS).

    .DESCRIPTION
    Used for Azure-hosted agents. Requests a token for the Azure DevOps resource
    (499b84ac-1321-427f-aa17-267ca6975798) via the Instance Metadata Service.

    .PARAMETER OrgUrl
    The Azure DevOps organization URL (used for cache keying).

    .PARAMETER ClientId
    Optional. The client ID of a user-assigned managed identity.

    .OUTPUTS
    Access token string, or $null on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$OrgUrl,
        [string]$ClientId
    )

    $url = $OrgUrl.TrimEnd('/')
    if (-not $url.StartsWith('https://')) { $url = "https://$url" }

    # In-memory cache check
    if ($script:AdoAuth_Token -and $script:AdoAuth_Expiry -gt (Get-Date) -and $script:AdoAuth_OrgUrl -eq $url -and $script:AdoAuth_AuthType -eq 'ManagedIdentity') {
        Write-AdoAuthLog -Level DEBUG -Event CacheHit -Message "Serving ADO MI token from in-memory cache (expires $($script:AdoAuth_Expiry.ToString('HH:mm:ss')))" -Mode ManagedIdentity -Identity 'ManagedIdentity'
        return $script:AdoAuth_Token
    }

    try {
        Write-AdoAuthLog -Level INFO -Event TokenAcquireStart -Message "Acquiring ADO token via Managed Identity (IMDS)$(if ($ClientId) { " [UserAssigned: $ClientId]" })" -Mode ManagedIdentity

        $adoResource = "499b84ac-1321-427f-aa17-267ca6975798"
        $imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=$adoResource"
        if ($ClientId) {
            $imdsUrl += "&client_id=$ClientId"
        }

        $tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Method Get `
            -Headers @{ "Metadata" = "true" } -ErrorAction Stop

        $script:AdoAuth_Token    = $tokenResponse.access_token
        $script:AdoAuth_Expiry   = (Get-Date).AddSeconds([int]$tokenResponse.expires_in - 300)
        $script:AdoAuth_OrgUrl   = $url
        $script:AdoAuth_Username = "ManagedIdentity"
        $script:AdoAuth_AuthType = 'ManagedIdentity'

        Write-AdoAuthLog -Level INFO -Event TokenAcquired -Message "ADO Managed Identity authentication succeeded (expires $($script:AdoAuth_Expiry.ToString('HH:mm:ss')))" -Mode ManagedIdentity -Identity 'ManagedIdentity' -Details @{ Expiry = $script:AdoAuth_Expiry; UserAssignedClientId = $ClientId }
        return $script:AdoAuth_Token
    }
    catch {
        Write-AdoAuthLog -Level ERROR -Event TokenFailed -Message "ADO Managed Identity authentication failed: $($_.Exception.Message). Ensure a managed identity is assigned and has ADO org access." -Mode ManagedIdentity -Details @{ Error = $_.Exception.Message }
        return $null
    }
}

# ============================================================================
# Header Construction
# ============================================================================

function Get-AdoHeaders {
    <#
    .SYNOPSIS
    Builds HTTP headers for Azure DevOps REST API calls.

    .DESCRIPTION
    Returns headers with either Bearer token (MSAL) or Basic auth (PAT).

    .PARAMETER Token
    Bearer access token (from MSAL interactive auth).

    .PARAMETER Pat
    Personal Access Token (for PAT-based auth).

    .PARAMETER ContentType
    Content-Type header value. Defaults to "application/json".

    .OUTPUTS
    Hashtable of HTTP headers.
    #>
    param(
        [string]$Token,
        [string]$Pat,
        [string]$ContentType = "application/json"
    )

    $headers = @{
        "Content-Type" = $ContentType
        "Accept"       = "application/json"
    }

    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }
    elseif ($Pat) {
        $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
        $headers["Authorization"] = "Basic $base64Auth"
    }
    else {
        throw "Either -Token or -Pat is required for ADO headers."
    }

    return $headers
}

# ============================================================================
# Unified Entry Point
# ============================================================================

function Get-AdoToken {
    <#
    .SYNOPSIS
    Unified ADO authentication entry point — auto-resolves the best auth method.

    .DESCRIPTION
    Always routes through the settings-driven resolver regardless of parameters.
    The -Interactive switch is accepted for backward compatibility with existing
    skill scripts but does NOT force interactive mode — settings determine the flow.

    Resolution order:
    1. Environment variables (ADO_AUTH_MODE, ADO_PAT, etc.)
    2. Settings file (auth-settings.json)
    3. Default: Interactive

    Note: -Pat parameter, if provided explicitly, DOES override settings (it's a
    concrete credential being passed in, not a mode hint).

    .PARAMETER OrgUrl
    The Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg)

    .PARAMETER Interactive
    Accepted for backward compatibility. Does not override settings-driven resolution.

    .PARAMETER Pat
    If explicitly provided, overrides settings and uses this PAT directly.

    .OUTPUTS
    Hashtable with AuthType ('Bearer' or 'Basic') and Token/Pat value.

    .EXAMPLE
    # Auto-resolve (reads settings/env vars)
    $auth = Get-AdoToken -OrgUrl "https://dev.azure.com/MyOrg"
    $headers = Get-AdoHeaders -Token $auth.Token

    .EXAMPLE
    # Called from existing skills with -Interactive — still auto-resolves from settings
    $auth = Get-AdoToken -OrgUrl "https://dev.azure.com/MyOrg" -Interactive
    $headers = Get-AdoHeaders -Token $auth.Token

    .EXAMPLE
    # Explicit PAT override (bypasses settings)
    $auth = Get-AdoToken -OrgUrl "https://dev.azure.com/MyOrg" -Pat "mypatvalue"
    $headers = Get-AdoHeaders -Pat $auth.Pat
    #>
    param(
        [Parameter(Mandatory)]
        [string]$OrgUrl,

        [switch]$Interactive,

        [string]$Pat
    )

    # --- Explicit PAT override (a concrete credential, not just a mode hint) ---
    if ($Pat) {
        Write-AdoAuthLog -Level INFO -Event TokenAcquired -Message "Using explicitly provided PAT (bypasses resolver)" -Mode 'Pat'
        return @{ AuthType = 'Basic'; Pat = $Pat }
    }

    # --- Settings-driven auto-resolution (same path whether -Interactive is passed or not) ---
    $settings = Get-AdoAuthSettings
    $mode = $settings.AdoAuthMode

    # If settings specify an org URL and caller didn't provide a meaningful one, use it
    if ($settings.AdoOrgUrl -and -not $OrgUrl) {
        $OrgUrl = $settings.AdoOrgUrl
    }

    Write-AdoAuthLog -Level INFO -Event ModeResolved -Message "ADO auth mode resolved: $mode" -Mode $mode

    switch ($mode) {
        'ManagedIdentity' {
            $token = Get-AdoTokenManagedIdentity -OrgUrl $OrgUrl -ClientId $settings.AdoClientId
            if (-not $token) { return $null }
            return @{ AuthType = 'Bearer'; Token = $token }
        }
        'ServicePrincipal' {
            if (-not $settings.AdoClientId -or -not $settings.AdoClientSecret) {
                Write-AdoAuthLog -Level ERROR -Event SettingsError -Message "ServicePrincipal mode requires AdoClientId and AdoClientSecret in settings." -Mode ServicePrincipal
                return $null
            }
            try {
                $tenantId = if ($settings.AdoTenantId) { $settings.AdoTenantId } else { "common" }
                $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
                $body = @{
                    grant_type    = "client_credentials"
                    client_id     = $settings.AdoClientId
                    client_secret = $settings.AdoClientSecret
                    resource      = "499b84ac-1321-427f-aa17-267ca6975798"
                }
                Write-AdoAuthLog -Level INFO -Event TokenAcquireStart -Message "Acquiring ADO token via service principal (ClientId: $($settings.AdoClientId))" -Mode ServicePrincipal -Identity $settings.AdoClientId
                $tokenResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
                Write-AdoAuthLog -Level INFO -Event TokenAcquired -Message "ADO service principal authentication succeeded (ClientId: $($settings.AdoClientId))" -Mode ServicePrincipal -Identity $settings.AdoClientId
                return @{ AuthType = 'Bearer'; Token = $tokenResponse.access_token }
            }
            catch {
                Write-AdoAuthLog -Level ERROR -Event TokenFailed -Message "ADO service principal authentication failed: $($_.Exception.Message)" -Mode ServicePrincipal -Details @{ Error = $_.Exception.Message }
                return $null
            }
        }
        'Pat' {
            if (-not $settings.AdoPat) {
                Write-AdoAuthLog -Level ERROR -Event SettingsError -Message "Pat mode requires AdoPat in settings or ADO_PAT environment variable." -Mode 'Pat'
                return $null
            }
            Write-AdoAuthLog -Level INFO -Event TokenAcquired -Message "Using PAT from settings" -Mode 'Pat'
            return @{ AuthType = 'Basic'; Pat = $settings.AdoPat }
        }
        'DeviceCode' {
            $token = Get-AdoTokenDeviceCode -OrgUrl $OrgUrl
            if (-not $token) { return $null }
            return @{ AuthType = 'Bearer'; Token = $token }
        }
        'Interactive' {
            $token = Get-AdoTokenInteractive -OrgUrl $OrgUrl
            if (-not $token) { return $null }
            return @{ AuthType = 'Bearer'; Token = $token }
        }
        default {
            Write-AdoAuthLog -Level ERROR -Event ModeResolved -Message "Unknown AdoAuthMode '$mode'. Valid modes: Interactive, DeviceCode, Pat, ServicePrincipal, ManagedIdentity" -Mode $mode
            return $null
        }
    }
}
