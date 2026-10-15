@echo off
setlocal
title DenOS VirtualBox launcher
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-DenOS.ps1" %*
set "DENOS_EXIT=%ERRORLEVEL%"
if not "%DENOS_EXIT%"=="0" (
  echo.
  echo Review the error above and WINDOWS-LAUNCHER.txt.
  pause
)
exit /b %DENOS_EXIT%
