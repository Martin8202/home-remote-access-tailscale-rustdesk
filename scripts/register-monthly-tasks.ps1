# Register the monthly self-checks in Windows Task Scheduler (run once per PC).
#
#   -Mode User    your own PC: runs monthly-check.ps1 on day 1 as you (elevated) and pops up only on problems.
#                 Requires an ADMINISTRATOR PowerShell. Runs only while you are logged on; missed runs start at next logon.
#   -Mode System  a family PC: runs monthly-check.ps1 on day 1 as SYSTEM, writes the log only (no popup),
#                 works even when nobody is logged on. Requires an ADMINISTRATOR PowerShell.
#   -Mode Summary the always-on PC: runs monthly-summary.ps1 on day 2 as you (no elevation needed) and pops up
#                 if any PC is missing this month's log or its last run failed.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\register-monthly-tasks.ps1 -Mode User
# Keep this file pure ASCII + CRLF (Windows PowerShell 5.1 mis-reads non-ASCII .ps1 files).
param(
    [Parameter(Mandatory)][ValidateSet('User', 'System', 'Summary')][string]$Mode,
    [string]$Start = (Get-Date -Day 1).AddMonths(1).ToString('yyyy-MM-dd')
)

$dir = $PSScriptRoot
switch ($Mode) {
    'User'    { $ps1 = Join-Path $dir 'monthly-check.ps1';   $day = 1; $extra = '-Scheduled';          $name = 'MonthlyCheck' }
    'System'  { $ps1 = Join-Path $dir 'monthly-check.ps1';   $day = 1; $extra = '-Scheduled -NoPopup'; $name = 'MonthlyCheck' }
    'Summary' { $ps1 = Join-Path $dir 'monthly-summary.ps1'; $day = 2; $extra = '';                    $name = 'MonthlySummary' }
}
if (-not (Test-Path $ps1)) { Write-Host "Not found: $ps1" -ForegroundColor Red; exit 1 }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Mode -ne 'Summary' -and -not $isAdmin) { Write-Host 'Please run in an ADMINISTRATOR PowerShell.' -ForegroundColor Red; exit 1 }

if ($Mode -eq 'System') {
    # keep the files physically on disk so SYSTEM can read them even if OneDrive is not running
    attrib +P "$dir" /S /D | Out-Null
    $principal = '<UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel>'
} else {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $level = if ($Mode -eq 'User') { 'HighestAvailable' } else { 'LeastPrivilege' }
    $principal = "<UserId>$user</UserId><LogonType>InteractiveToken</LogonType><RunLevel>$level</RunLevel>"
}

$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$($Start)T10:00:00</StartBoundary>
      <ScheduleByMonth>
        <DaysOfMonth><Day>$day</Day></DaysOfMonth>
        <Months><January/><February/><March/><April/><May/><June/><July/><August/><September/><October/><November/><December/></Months>
      </ScheduleByMonth>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">$principal</Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$ps1" $extra</Arguments>
    </Exec>
  </Actions>
</Task>
"@
$x = Join-Path $env:TEMP "$name.xml"
$xml | Out-File $x -Encoding Unicode
schtasks /Create /TN "HomeRemote\$name" /XML $x /F
Write-Host "Registered HomeRemote\$name ($Mode). Test it now with:  schtasks /Run /TN `"HomeRemote\$name`""
