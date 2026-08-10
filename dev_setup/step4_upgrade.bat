@echo off
REM BiteWise setup step 4: flutter upgrade + Android SDK probe
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set LOG=%~dp0setup_log.txt

echo === BITEWISE SETUP STEP 4 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === ANDROID SDK LAYOUT === >> "%LOG%"
if exist "%LOCALAPPDATA%\Android\Sdk" (
  echo SDK at %LOCALAPPDATA%\Android\Sdk >> "%LOG%"
  dir /b "%LOCALAPPDATA%\Android\Sdk" >> "%LOG%" 2>&1
  if exist "%LOCALAPPDATA%\Android\Sdk\cmdline-tools" (
    echo --- cmdline-tools contents: --- >> "%LOG%"
    dir /b "%LOCALAPPDATA%\Android\Sdk\cmdline-tools" >> "%LOG%" 2>&1
  )
) else (
  echo No SDK at %LOCALAPPDATA%\Android\Sdk >> "%LOG%"
)

echo. >> "%LOG%"
echo === FLUTTER UPGRADE (this takes a few minutes) === >> "%LOG%"
call "%FLUTTER%" upgrade >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === PUB GET AFTER UPGRADE === >> "%LOG%"
cd /d "%~dp0.."
call "%FLUTTER%" pub get >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 4 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
