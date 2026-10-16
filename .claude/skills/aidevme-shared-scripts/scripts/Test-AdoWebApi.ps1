<#
.SYNOPSIS
    Offline tests for Invoke-AdoRestMethod - no Azure DevOps, no network, no credentials.

.DESCRIPTION
    The function was proved in production inside hso-ado-work-items but never had tests.
    Promoting it to the shared library is the moment to add them: it is now dot-sourced
    by more than one skill, so a regression here is no longer contained to one caller.

    The behaviour that matters most is reproducible against a local socket. An
    unauthenticated ADO request answers 302 to a sign-in page, and a plain
    Invoke-RestMethod would follow it, parse the HTML and return an object whose
    .value is empty - no error. These tests pin the refusal.

    A raw TcpListener is used rather than HttpListener on purpose: HttpListener needs a
    URL ACL reservation and fails with "access is denied" for a non-admin user, which
    would look like a broken test when it is only an unprivileged one.

    Run under BOTH hosts - the redirect and large-payload paths differ:
        pwsh        -File Test-AdoWebApi.ps1
        powershell  -File Test-AdoWebApi.ps1

.OUTPUTS
    One line per case. Exit code 0 = all passed, 1 = at least one failed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ADO-WebApi.ps1"

$script:Passed = 0
$script:Failed = 0

function Start-StubServer {
    <#
      Serves exactly one request with a canned raw HTTP response, then closes.

      A RUNSPACE, not Start-Job. Start-Job serialises its arguments, so a live
      TcpListener arrives in the job as an inert husk that never accepts the
      connection - the request then blocks until timeout.
    #>
    param([Parameter(Mandatory)][string]$RawResponse)

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port

    $ps = [PowerShell]::Create()
    $null = $ps.AddScript({
        param($listenerObj, $raw)
        try {
            $client = $listenerObj.AcceptTcpClient()
            $stream = $client.GetStream()
            $buffer = New-Object byte[] 8192
            $null = $stream.Read($buffer, 0, $buffer.Length)
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($raw)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
            Start-Sleep -Milliseconds 50
            $client.Close()
        } catch { }
        finally { try { $listenerObj.Stop() } catch { } }
    }).AddArgument($listener).AddArgument($RawResponse)

    $handle = $ps.BeginInvoke()
    return @{ Port = $port; Shell = $ps; Handle = $handle; Listener = $listener }
}

function Invoke-Case {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$RawResponse,
        [switch]$ExpectThrow,
        [string]$ExpectMessageMatch,
        [scriptblock]$AssertResult
    )

    $server = Start-StubServer -RawResponse $RawResponse
    $uri = "http://127.0.0.1:$($server.Port)/_apis/projects?api-version=7.1"
    $headers = @{ Authorization = 'Bearer test-token'; 'Content-Type' = 'application/json' }

    $threw = $false; $message = ''; $result = $null
    try {
        $result = Invoke-AdoRestMethod -Uri $uri -Headers $headers
    }
    catch {
        $threw = $true
        $message = $_.Exception.Message
    }
    finally {
        try { $server.Listener.Stop() } catch { }
        try { $null = $server.Shell.EndInvoke($server.Handle) } catch { }
        try { $server.Shell.Dispose() } catch { }
    }

    $ok = $true; $why = ''

    if ($ExpectThrow -and -not $threw) {
        $ok = $false; $why = 'expected a throw, got a result - this is the false-success case'
    }
    elseif (-not $ExpectThrow -and $threw) {
        $ok = $false; $why = "unexpected throw: $message"
    }
    elseif ($ExpectThrow -and $ExpectMessageMatch -and $message -notmatch $ExpectMessageMatch) {
        $ok = $false; $why = "threw, but message did not match '$ExpectMessageMatch': $message"
    }
    elseif (-not $ExpectThrow -and $AssertResult) {
        try {
            if (-not (& $AssertResult $result)) { $ok = $false; $why = 'result assertion returned false' }
        } catch { $ok = $false; $why = "result assertion errored: $($_.Exception.Message)" }
    }

    if ($ok) { $script:Passed++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else     { $script:Failed++; Write-Host "  [FAIL] $Name - $why" -ForegroundColor Red }
}

Write-Host "Invoke-AdoRestMethod - offline behaviour tests (host: PowerShell $($PSVersionTable.PSVersion))" -ForegroundColor Cyan

# 1. The behaviour that matters: a 302 to sign-in must be refused, not followed.
Invoke-Case -Name '302 to sign-in is refused, not followed' `
    -RawResponse "HTTP/1.1 302 Found`r`nLocation: https://spsprodeus.vssps.visualstudio.com/_signin`r`nContent-Length: 0`r`n`r`n" `
    -ExpectThrow -ExpectMessageMatch 'returned a redirect'

# 2. A sign-in page served as HTTP 200 is still a sign-in page.
$html = '<html><head><title>Sign In</title></head><body>Sign in to continue</body></html>'
Invoke-Case -Name 'HTML body with HTTP 200 is rejected before parsing' `
    -RawResponse "HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($html.Length)`r`n`r`n$html" `
    -ExpectThrow -ExpectMessageMatch 'non-JSON response'

# 3. A real error status surfaces with its code, not as an empty result.
$err = '{"message":"TF400813: The user is not authorized to access this resource."}'
Invoke-Case -Name 'HTTP 403 throws with the status code' `
    -RawResponse "HTTP/1.1 403 Forbidden`r`nContent-Type: application/json`r`nContent-Length: $($err.Length)`r`n`r`n$err" `
    -ExpectThrow -ExpectMessageMatch 'HTTP 403'

# 4. The happy path still parses.
$json = '{"count":2,"value":[{"name":"Forge USA"},{"name":"Forge CLI"}]}'
Invoke-Case -Name 'HTTP 200 JSON parses and returns .value' `
    -RawResponse "HTTP/1.1 200 OK`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($json.Length)`r`n`r`n$json" `
    -AssertResult { param($r) $r.count -eq 2 -and $r.value.Count -eq 2 -and $r.value[0].name -eq 'Forge USA' }

Write-Host ""
Write-Host "Passed: $script:Passed   Failed: $script:Failed" -ForegroundColor $(if ($script:Failed) { 'Red' } else { 'Green' })
if ($script:Failed -gt 0) { exit 1 }
exit 0
