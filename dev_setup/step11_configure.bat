@echo off
REM BiteWise setup step 11: detect project + flutterfire + Firestore + rules
setlocal enabledelayedexpansion
set DART=C:\Users\Lenovo\source\flutter\bin\dart.bat
set FLUTTERFIRE=%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat
set LOG=%~dp0setup_log.txt
cd /d "%~dp0.."

echo === BITEWISE SETUP STEP 11 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === DETECTING FIREBASE PROJECT === >> "%LOG%"
for /f "delims=" %%i in ('powershell -NoProfile -Command "(firebase projects:list --json | ConvertFrom-Json).result[0].projectId"') do set PROJECT_ID=%%i
echo PROJECT_ID=!PROJECT_ID! >> "%LOG%"

if "!PROJECT_ID!"=="" (
  echo ERROR: no project found >> "%LOG%"
  goto :done
)

echo. >> "%LOG%"
echo === SETTING ACTIVE PROJECT === >> "%LOG%"
call firebase use !PROJECT_ID! >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTERFIRE CONFIGURE === >> "%LOG%"
call "%FLUTTERFIRE%" configure --project=!PROJECT_ID! --platforms=android,ios --yes >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === CREATING FIRESTORE DATABASE (asia-south1) === >> "%LOG%"
call firebase firestore:databases:create "(default)" --location=asia-south1 --project=!PROJECT_ID! >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === DEPLOYING FIRESTORE RULES === >> "%LOG%"
call firebase deploy --only firestore:rules --project=!PROJECT_ID! >> "%LOG%" 2>&1

:done
echo. >> "%LOG%"
echo === STEP 11 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
