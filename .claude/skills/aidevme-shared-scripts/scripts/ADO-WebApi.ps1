# ============================================================================
# ADO-WebApi.ps1 - the shared Azure DevOps REST invoker
#
# Invoke-AdoRestMethod was written inside hso-ado-work-items and proved there.
# It is promoted here unchanged in behaviour, because it had already been
# copy-pasted once: Get-AdoProcessProfile.ps1 carried a second, reduced copy
# (GET-only, no -Method, no -Body). Two copies in one skill, already drifting -
# which is the argument for a shared module rather than a third one.
#
# What it defends against, and why Invoke-RestMethod is not enough:
#
#   An unauthenticated ADO request does not return 401. It returns 302 to a
#   sign-in page. Invoke-RestMethod follows the redirect, parses the HTML, and
#   hands back an object whose .value is empty - no error, no warning. A query
#   that should read "you are not authenticated" instead reads "there is
#   nothing there". Same false-all-clear class as the 404-vs-403 asymmetry in
#   ADO_CONVENTIONS.md, and worse, because a 404 at least stops you.
#
# It uses System.Net.HttpWebRequest with AllowAutoRedirect disabled, so the
# redirect is refused and reported rather than followed. It also validates that
# the body is JSON before parsing, and falls back to JavaScriptSerializer for
# payloads past Windows PowerShell 5.1's ConvertFrom-Json limit - which a
# thinner Invoke-WebRequest wrapper does not survive.
#
# Callers that may receive a large payload should check for the fallback shape:
#   if ($result -is [System.Collections.Generic.Dictionary[string,object]])
#
# No Set-StrictMode here, deliberately. This file is dot-sourced, so it runs in
# the CALLER's scope; a Set-StrictMode would impose strict semantics on every
# adopting script. No sibling library (Dataverse-WebApi.ps1, ADO-Auth.ps1,
# Dataverse-Auth.ps1) sets it either.
# ============================================================================

function Invoke-AdoRestMethod {
    <#
    .SYNOPSIS
    Makes an Azure DevOps REST API call with proper header preservation across redirects.

    .DESCRIPTION
    Uses System.Net.HttpWebRequest instead of Invoke-RestMethod to prevent PowerShell 5.1
    from silently dropping the Authorization header when ADO issues a redirect (302).
    For large JSON responses that exceed PS 5.1's ConvertFrom-Json limit, falls back to
    .NET's JavaScriptSerializer.
    Callers should check: if ($result -is [System.Collections.Generic.Dictionary[string,object]])
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Headers,
        [string]$Method = "Get",
        [byte[]]$Body = $null
    )

    Write-Host "  [API] $Method $Uri" -ForegroundColor Gray

    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.Method = $Method.ToUpper()
    $request.AllowAutoRedirect = $false

    # Apply headers — restricted headers must use their dedicated properties
    $restrictedProps = @{
        'Content-Type' = 'ContentType'
        'Accept'       = 'Accept'
        'User-Agent'   = 'UserAgent'
    }
    foreach ($key in $Headers.Keys) {
        if ($restrictedProps.ContainsKey($key)) {
            $request.($restrictedProps[$key]) = $Headers[$key]
        } else {
            $request.Headers.Add($key, $Headers[$key])
        }
    }

    # Write body if present
    if ($Body -and $Body.Length -gt 0) {
        $request.ContentLength = $Body.Length
        $reqStream = $request.GetRequestStream()
        $reqStream.Write($Body, 0, $Body.Length)
        $reqStream.Close()
    }

    # Execute request and read response
    $webResponse = $null
    $responseBody = $null
    try {
        $webResponse = $request.GetResponse()
    }
    catch [System.Net.WebException] {
        $webResponse = $_.Exception.Response
        if (-not $webResponse) { throw }
    }

    $statusCode = [int]$webResponse.StatusCode

    # Capture Location BEFORE closing the response. Under .NET Framework (Windows
    # PowerShell 5.1) the headers survive Close(); under .NET (PowerShell 7) they do
    # not, and reading them afterwards yields null - so the redirect branch below
    # threw "Cannot index into a null array" instead of its actionable message, on
    # PowerShell 7, on the one path that matters most. Caught by the test suite added
    # when this function was promoted; it had never been exercised under 7.
    $location = $webResponse.Headers["Location"]

    $stream = $webResponse.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $responseBody = $reader.ReadToEnd()
    $reader.Close()
    $stream.Close()
    $webResponse.Close()

    # Handle redirects (ADO returns 302 when auth header is dropped by PS 5.1)
    if ($statusCode -ge 300 -and $statusCode -lt 400) {
        # Show scheme+host+path only. A sign-in Location carries a long nonce query that buries
        # the guidance below it, and the host and path are the whole diagnostic: /_signin means
        # auth, a blob-storage host means the endpoint legitimately redirects.
        $locShort = $location
        if ($location) {
            try {
                $parsed = [System.Uri]$location
                $locShort = "$($parsed.Scheme)://$($parsed.Host)$($parsed.AbsolutePath)"
            } catch { }
            if ($locShort.Length -gt 160) { $locShort = $locShort.Substring(0, 160) + '...' }
        }
        throw ("ADO API returned a redirect ($statusCode) to: $locShort. " +
               "This usually means the Authorization header was not accepted - clear the token " +
               "cache (delete %TEMP%\AdoAuthCache_*.json) and re-authenticate. " +
               "If that Location is NOT a sign-in URL, the endpoint legitimately redirects " +
               "(attachment and artifact downloads do) and should not be called through this " +
               "function - it refuses every 3xx by design.")
    }

    # Handle HTTP errors
    if ($statusCode -ge 400) {
        $preview = if ($responseBody.Length -gt 500) { $responseBody.Substring(0, 500) + "..." } else { $responseBody }
        throw "ADO API returned HTTP $statusCode. Response: $preview"
    }

    # Validate response is JSON
    $trimmed = $responseBody.Trim()
    if (-not ($trimmed.StartsWith('{') -or $trimmed.StartsWith('['))) {
        $preview = if ($trimmed.Length -gt 200) { $trimmed.Substring(0, 200) + "..." } else { $trimmed }
        throw "ADO API returned a non-JSON response. This usually means the project name or URL is incorrect. Response preview: $preview"
    }

    # Parse JSON — try ConvertFrom-Json first, fall back to JavaScriptSerializer for large payloads
    try {
        return ($responseBody | ConvertFrom-Json)
    }
    catch {
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
        $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $serializer.MaxJsonLength = 50MB
        return $serializer.DeserializeObject($responseBody)
    }
}
