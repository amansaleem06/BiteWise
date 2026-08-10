@echo off
REM ============================================================
REM  BiteWise: one-click build + emulator + install + launch
REM  Safe to re-run any time. After the first successful build,
REM  this takes under a minute.
REM ============================================================
set SDK=%LOCALAPPDATA%\Android\Sdk
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set ADB=%SDK%\platform-tools\adb.exe
set LOG=%~dp0run_log.txt
cd /d "%~dp0.."

echo === RUN_BITEWISE === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo [1/4] Building BiteWise (skipped if already built)...
call "%FLUTTER%" build apk --debug >> "%LOG%" 2>&1
if not exist "build\app\outputs\flutter-apk\app-debug.apk" (
  echo BUILD FAILED >> "%LOG%"
  echo.
  echo  BUILD FAILED - tell Claude, the details are in dev_setup\run_log.txt
  pause
  exit /b
)
echo        Build OK!

echo [2/4] Starting emulator (skipped if already running)...
"%ADB%" devices | findstr /C:"emulator" >nul
if errorlevel 1 (
  start "BiteWise Emulator" "%SDK%\emulator\emulator.exe" -avd Medium_Phone_API_36.1
)

echo [3/4] Waiting for the emulator to boot...
call "%ADB%" wait-for-device
:bootwait
for /f "delims=" %%i in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do set BOOTED=%%i
if not "%BOOTED%"=="1" (
  timeout /t 5 >nul
  goto :bootwait
)
echo        Emulator ready!

echo [4/4] Installing and launching BiteWise...
call "%ADB%" install -r "build\app\outputs\flutter-apk\app-debug.apk" >> "%LOG%" 2>&1
call "%ADB%" shell monkey -p com.bitewise.bitewise -c android.intent.category.LAUNCHER 1 >> "%LOG%" 2>&1

echo === RUN_BITEWISE FINISHED: %date% %time% === >> "%LOG%"
echo.
echo  Done! BiteWise is opening in the emulator.
timeout /t 8 >nul
