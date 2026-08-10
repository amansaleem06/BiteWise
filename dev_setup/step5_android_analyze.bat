@echo off
REM BiteWise setup step 5: Android cmdline-tools + licenses + flutter analyze
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set SDK=%LOCALAPPDATA%\Android\Sdk
set LOG=%~dp0setup_log.txt

echo === BITEWISE SETUP STEP 5 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === INSTALLING ANDROID CMDLINE-TOOLS === >> "%LOG%"
if exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" (
  echo cmdline-tools already present >> "%LOG%"
) else (
  powershell -NoProfile -Command "$z=$env:TEMP+'\cmdtools.zip'; Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $z; Expand-Archive -Path $z -DestinationPath ($env:TEMP+'\cmdtools') -Force; New-Item -ItemType Directory -Force -Path ($env:LOCALAPPDATA+'\Android\Sdk\cmdline-tools') | Out-Null; Move-Item -Force ($env:TEMP+'\cmdtools\cmdline-tools') ($env:LOCALAPPDATA+'\Android\Sdk\cmdline-tools\latest')" >> "%LOG%" 2>&1
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
echo === FLUTTER ANALYZE (static check of the app) === >> "%LOG%"
cd /d "%~dp0.."
call "%FLUTTER%" analyze >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER DOCTOR === >> "%LOG%"
call "%FLUTTER%" doctor >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 5 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
