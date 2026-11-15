# Runs on ctl-pc on the 2nd of each month (Task Scheduler: HomeRemote\MonthlySummary).
# Confirms that every PC wrote this month's monthly-check log and that its latest run passed.
# Pops up a message only when something is missing or failed; always appends a line to logs\summary-<yyyy-MM>.txt.
# Pure ASCII on purpose: Chinese text is stored as \u escapes (PowerShell 5.1 mis-reads non-ASCII .ps1 files).

$month = Get-Date -Format 'yyyy-MM'
$projLogs = Join-Path $PSScriptRoot 'logs'
# the family PC's copy lives in a shared OneDrive folder; find the sub-folder that holds monthly-check.ps1
$shareRoot = Join-Path $env:OneDrive 'share_folder'
$shareDir = Get-ChildItem $shareRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'monthly-check.ps1') } | Select-Object -First 1
$shareLogs = if ($shareDir) { Join-Path $shareDir.FullName 'logs' } else { $null }

# computer name -> (display name, log folder). Edit when a PC is added or replaced.
$pcs = [ordered]@{
    'DESKTOP-YYYYYYY' = @('ctl-pc', $projLogs)
    'DESKTOP-ZZZZZZZ' = @('ctl-laptop', $projLogs)
    'DESKTOP-XXXXXXX' = @('pc-home', $shareLogs)
}

$issues = New-Object System.Collections.Generic.List[string]
$okList = New-Object System.Collections.Generic.List[string]
foreach ($pc in $pcs.Keys) {
    $name = $pcs[$pc][0]; $dir = $pcs[$pc][1]
    $file = if ($dir) { Join-Path $dir "$pc-$month.txt" } else { $null }
    if (-not $file -or -not (Test-Path $file)) {
        $issues.Add($name + [regex]::Unescape('\uff1a\u672c\u6708\u6c92\u6709\u6aa2\u67e5\u8a18\u9304\uff08\u53ef\u80fd\u6c92\u958b\u6a5f\u3001\u6392\u7a0b\u6c92\u8dd1\u6216 OneDrive \u9084\u6c92\u540c\u6b65\uff09'))
        continue
    }
    $lines = Get-Content $file -Encoding UTF8
    $start = ($lines | Select-String -Pattern '^Run at' | Select-Object -Last 1).LineNumber
    $last = if ($start) { $lines[($start - 1)..($lines.Count - 1)] } else { $lines }
    if ($last -match 'All checks passed') { $okList.Add($name) }
    else { $issues.Add($name + [regex]::Unescape('\uff1a\u6aa2\u67e5\u767c\u73fe\u554f\u984c\uff0c\u8acb\u770b ') + $file) }
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$summary = "$stamp  OK: $($okList -join ', ')  |  issues: $($issues.Count)"
New-Item -ItemType Directory -Force $projLogs | Out-Null
Add-Content -Path (Join-Path $projLogs "summary-$month.txt") -Value $summary -Encoding UTF8
foreach ($i in $issues) { Add-Content -Path (Join-Path $projLogs "summary-$month.txt") -Value "  - $i" -Encoding UTF8 }

if ($issues.Count -gt 0) {
    $title = [regex]::Unescape('\u6bcf\u6708\u9060\u7aef\u9023\u7dda\u6aa2\u67e5\uff1a\u7e3d\u7d50')
    $body = ($issues -join "`n`n") + "`n`n" + [regex]::Unescape('\u6b63\u5e38\uff1a') + ($okList -join ', ')
    (New-Object -ComObject WScript.Shell).Popup($body, 0, $title, 48) | Out-Null
}
