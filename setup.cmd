@echo off
REM ===================================================================
REM  BBHub-lite: double-click this file to set everything up.
REM  It runs setup.ps1 with PowerShell (execution policy bypassed for
REM  this run only). Extra arguments are passed through, e.g.
REM      setup.cmd -From 4
REM ===================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
echo.
pause
