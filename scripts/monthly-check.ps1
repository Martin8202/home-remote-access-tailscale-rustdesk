# Monthly check for the home remote-access setup (Tailscale + RustDesk).
# Run in an ADMINISTRATOR PowerShell on each remote-controlled PC (ctl-pc, laptop, pc-home):
#   powershell -ExecutionPolicy Bypass -File "<path>\monthly-check.ps1"
# Scheduled mode (Task Scheduler): add -Scheduled to write the result to logs\<PC>-<yyyy-MM>.txt next to
# this script and pop up a message only when something is wrong; add -NoPopup to only write the log.
# Read-only: it changes nothing. Output is English on purpose (PowerShell 5.1 mis-reads non-ASCII .ps1 files).
param([switch]$Scheduled, [switch]$NoPopup)

if ($Scheduled) {
    $logFolder = Join-Path $PSScriptRoot 'logs'
    New-Item -ItemType Directory -Force $logFolder | Out-Null
    $logFile = Join-Path $logFolder ("{0}-{1}.txt" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyy-MM'))
    Start-Transcript -Path $logFile -Append | Out-Null
    Write-Host "Run at $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

# Your own devices (controllers). Edit when you add or replace a device.
$Allowed = @{
    '100.64.0.11' = 'ctl-iphone'
    '100.64.0.12'   = 'ctl-ipad'
    '100.64.0.13'  = 'ctl-laptop'
    '100.64.0.10' = 'ctl-pc'
}
$Expected = @('ctl-pc','ctl-iphone','ctl-ipad','ctl-laptop','pc-home','family-phone')

$problems = New-Object System.Collections.Generic.List[string]
function Bad($msg)  { Write-Host "  [!!] $msg" -ForegroundColor Red; $problems.Add($msg) }
function Good($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Bad "Not running as administrator (RustDesk log cannot be read)." }

Write-Host "`n=== 1. Tailscale machines (seen from $env:COMPUTERNAME) ==="
try {
    # tailscale.exe prints UTF-8; PowerShell 5.1 would decode it with the OEM code page and break non-ASCII names
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $st = (& "C:\Program Files\Tailscale\tailscale.exe" status --json) -join "`n" | ConvertFrom-Json
    $names = @(($st.Self.DNSName -split '\.')[0]) + @($st.Peer.PSObject.Properties.Value | ForEach-Object { ($_.DNSName -split '\.')[0] })
    foreach ($n in $names) { if ($Expected -contains $n) { Good $n } else { Bad "Unknown device: $n  -> check Tailscale admin > Machines" } }
    foreach ($p in $st.Peer.PSObject.Properties.Value) {
        if ($p.KeyExpiry) { Bad "$(($p.DNSName -split '\.')[0]) key expires $($p.KeyExpiry) -> Disable key expiry" }
    }
} catch {
    # keep the message short: the raw JSON contains public IPs, keys and the account e-mail
    $m = $_.Exception.Message; if ($m.Length -gt 80) { $m = $m.Substring(0, 80) + '...' }
    Bad "Cannot read Tailscale status: $m"
}

Write-Host "`n=== 2. RustDesk firewall rules ==="
$rules = Get-NetFirewallRule -DisplayName 'RustDesk*' -ErrorAction SilentlyContinue
if (-not ($rules | Where-Object Direction -eq 'Inbound')) { Bad "No INBOUND RustDesk rule" }
foreach ($r in $rules) {
    $remote = @(($r | Get-NetFirewallAddressFilter).RemoteAddress)
    $label = "$($r.DisplayName) [$($r.Direction)] -> $($remote -join ', ')"
    $unknown = $remote | Where-Object { -not $Allowed.ContainsKey($_) }
    if ($unknown) { Bad "$label  (not only your devices)" } else { Good $label }
}
$ts = Get-NetFirewallRule -DisplayName 'Tailscale-In' -ErrorAction SilentlyContinue
if ($ts) { Write-Host "  [i] 'Tailscale-In' exists: traffic over Tailscale is filtered by the Tailscale ACL, not by the rules above." }

Write-Host "`n=== 3. RustDesk incoming connections (last 20) ==="
$logDir = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\log\server'
$hits = @()
if (-not (Test-Path $logDir)) { Bad "RustDesk log folder not readable: $logDir" }
else {
    $hits = Select-String -Path "$logDir\*.log" -Pattern 'Connection opened from ([0-9.]+)' | Select-Object -Last 20
    if (-not $hits) { Write-Host "  (no incoming connections in the log)" }
}
foreach ($h in $hits) {
    $ip = $h.Matches[0].Groups[1].Value
    $when = $h.Line.Substring(1, 19)
    if ($Allowed.ContainsKey($ip)) { Good "$when  $ip ($($Allowed[$ip]))" } else { Bad "$when  $ip  UNKNOWN source" }
}

Write-Host "`n=== Result ==="
if ($problems.Count -eq 0) { Write-Host "All checks passed. Also check Tailscale admin > Logs in the browser." -ForegroundColor Green }
else { Write-Host "$($problems.Count) problem(s) found. Send this output to Claude." -ForegroundColor Red }

if ($Scheduled) {
    Stop-Transcript | Out-Null
    if ($problems.Count -gt 0 -and -not $NoPopup) {
        # Chinese text written as \u escapes so this file stays pure ASCII
        $title = [regex]::Unescape('\u6bcf\u6708\u9060\u7aef\u9023\u7dda\u6aa2\u67e5')
        $body = [regex]::Unescape('\u767c\u73fe ') + $problems.Count + [regex]::Unescape(' \u500b\u554f\u984c\uff1a') + "`n`n" +
                ($problems -join "`n") + "`n`n" + [regex]::Unescape('\u8a18\u9304\u6a94\uff1a') + "`n$logFile"
        (New-Object -ComObject WScript.Shell).Popup($body, 0, $title, 48) | Out-Null
    }
}
