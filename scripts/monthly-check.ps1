# Monthly check for the home remote-access setup (Tailscale + RustDesk).
# Run in an ADMINISTRATOR PowerShell on each remote-controlled PC (ctl-pc, laptop, pc-home):
#   powershell -ExecutionPolicy Bypass -File "<path>\monthly-check.ps1"
# Read-only: it changes nothing. Output is English on purpose (PowerShell 5.1 mis-reads non-ASCII .ps1 files).

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
if (-not $isAdmin) { Write-Host "Please run this in an ADMINISTRATOR PowerShell." -ForegroundColor Red; exit 1 }

Write-Host "`n=== 1. Tailscale machines (seen from $env:COMPUTERNAME) ==="
try {
    $st = & "C:\Program Files\Tailscale\tailscale.exe" status --json | ConvertFrom-Json
    $names = @(($st.Self.DNSName -split '\.')[0]) + @($st.Peer.PSObject.Properties.Value | ForEach-Object { ($_.DNSName -split '\.')[0] })
    foreach ($n in $names) { if ($Expected -contains $n) { Good $n } else { Bad "Unknown device: $n  -> check Tailscale admin > Machines" } }
    foreach ($p in $st.Peer.PSObject.Properties.Value) {
        if ($p.KeyExpiry) { Bad "$(($p.DNSName -split '\.')[0]) key expires $($p.KeyExpiry) -> Disable key expiry" }
    }
} catch { Bad "Cannot read Tailscale status: $($_.Exception.Message)" }

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
