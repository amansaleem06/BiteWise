@echo off
REM Run this AFTER reproducing the auth error in the app.
REM Dumps the device log so Claude can read the exact Firebase error.
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set LOG=%~dp0auth_log.txt
"%ADB%" logcat -d -t 800 > "%LOG%" 2>&1
echo Captured. Tell Claude it's ready.
timeout /t 3 >nul
