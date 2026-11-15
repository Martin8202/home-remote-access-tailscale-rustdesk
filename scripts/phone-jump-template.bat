@echo off
rem Jump host helper: run on the always-on PC to open a RustDesk session to a family Android phone.
rem Why: when you control this PC from an iPhone via RustDesk, the RustDesk main window shows up blank
rem and cannot be clicked, so start the outgoing session from the command line instead.
rem Change the IP to the phone's Tailscale IP.
start "" "C:\Program Files\RustDesk\RustDesk.exe" --connect 100.64.0.22
