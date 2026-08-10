@echo off
REM BiteWise setup step 6: cmdline-tools retry + licenses + dart fix + analyze
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set DART=C:\Users\Lenovo\source\flutter\bin\dart.bat
set SDK=%LOCALAPPDATA%\Android\Sdk
set LOG=%~dp0setup_log.txt

echo === BITEWISE SETUP STEP 6 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === CMDLINE-TOOLS (curl with retries) === >> "%LOG%"
if exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" (
  echo cmdline-tools already present >> "%LOG%"
) else (
  curl.exe -L --retry 5 --retry-delay 3 -C - -o "%TEMP%\cmdtools.zip" "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" >> "%LOG%" 2>&1
  powershell -NoProfile -Command "Expand-Archive -Path ($env:TEMP+'\cmdtools.zip') -DestinationPath ($env:TEMP+'\cmdtools') -Force; New-Item -ItemType Directory -Force -Path ($env:LOCALAPPDATA+'\Android\Sdk\cmdline-tools') | Out-Null; Move-Item -Force ($env:TEMP+'\cmdtools\cmdline-tools') ($env:LOCALAPPDATA+'\Android\Sdk\cmdline-tools\latest')" >> "%LOG%" 2>&1
  if exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo cmdline-tools installed OK >> "%LOG%"
  ) else (
    echo cmdline-tools install FAILED >> "%LOG%"
  )
)

echo. >> "%LOG%"
echo === ACCEPTING ANDROID LICENSES === >> "%LOG%"
(for /l %%i in (1,1,30) do @echo y) | call "%FLUTTER%" doctor --android-licenses >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === DART FIX (auto-apply lint fixes) === >> "%LOG%"
cd /d "%~dp0.."
call "%DART%" fix --apply >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER ANALYZE (round 2) === >> "%LOG%"
call "%FLUTTER%" analyze >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER DOCTOR (final) === >> "%LOG%"
call "%FLUTTER%" doctor >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 6 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
