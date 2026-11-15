@echo off
rem Open a controllable window for an Android TV via ADB + scrcpy.
rem Usage: copy this file once per TV, change TV and TITLE below. Keep this file CRLF + ASCII only.
rem Prerequisite: TV has a DHCP reservation, USB/network debugging on, and this PC was allowed once on the TV.
set TV=192.168.1.50:5555
set TITLE=TV 1
rem find scrcpy installed by winget (any version, any Windows user)
set "SC="
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\Genymobile.scrcpy_*") do for /d %%E in ("%%D\scrcpy-win64-*") do set "SC=%%E"
if not defined SC (
  echo scrcpy not found. Install it with: winget install --id Genymobile.scrcpy -e
  pause
  exit /b 1
)
set "PATH=%SC%;%PATH%"
adb connect %TV%
scrcpy -s %TV% --window-title "%TITLE%"
if errorlevel 1 (
  echo.
  echo Cannot reach TV. Check: home Wi-Fi, TV is on, no other window for this TV, network debugging still on, this PC allowed on the TV.
  pause
)
