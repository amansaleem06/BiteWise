@echo off
REM Boot the Android emulator and run BiteWise on it
set SDK=%LOCALAPPDATA%\Android\Sdk
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set ADB=%SDK%\platform-tools\adb.exe
set LOG=%~dp0run_log.txt
cd /d "%~dp0.."

echo === STEP 18: BOOT EMULATOR + RUN === > "%LOG%"

echo.
echo  Starting Android emulator (Medium_Phone_API_36.1)...
start "BiteWise Emulator" "%SDK%\emulator\emulator.exe" -avd Medium_Phone_API_36.1

echo  Waiting for the emulator to boot (this can take 1-3 minutes)...
call "%ADB%" wait-for-device >> "%LOG%" 2>&1

:bootwait
for /f "delims=" %%i in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do set BOOTED=%%i
if not "%BOOTED%"=="1" (
  timeout /t 5 >nul
  goto :bootwait
)
echo Emulator booted. >> "%LOG%"
echo  Emulator booted!

echo.
echo  Building and installing BiteWise (first build takes a few minutes)...
echo  Leave this window open. Press r here for hot reload, q to quit.
echo.
call "%FLUTTER%" run
