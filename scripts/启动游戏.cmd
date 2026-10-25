@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Bootstrap.ps1" -Action Launch
if errorlevel 1 (
 echo.
 echo Launch failed. Please copy the error above.
 pause
 exit /b 1
)
exit /b 0
