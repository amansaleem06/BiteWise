@echo off
REM BiteWise setup step 9: create Firebase project + flutterfire + Firestore + rules
setlocal enabledelayedexpansion
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set DART=C:\Users\Lenovo\source\flutter\bin\dart.bat
set FLUTTERFIRE=%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat
set LOG=%~dp0setup_log.txt
cd /d "%~dp0.."

REM Globally-unique project id
set PROJECT_ID=bitewise-app-%RANDOM%%RANDOM%

echo === BITEWISE SETUP STEP 9 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"
echo PROJECT_ID=%PROJECT_ID% >> "%LOG%"

echo. >> "%LOG%"
echo === CREATING FIREBASE PROJECT === >> "%LOG%"
call firebase projects:create %PROJECT_ID% --display-name "BiteWise" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === SETTING ACTIVE PROJECT === >> "%LOG%"
call firebase use %PROJECT_ID% >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === INSTALLING FLUTTERFIRE CLI === >> "%LOG%"
call "%DART%" pub global activate flutterfire_cli >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTERFIRE CONFIGURE === >> "%LOG%"
call "%FLUTTERFIRE%" configure --project=%PROJECT_ID% --platforms=android,ios --yes >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === CREATING FIRESTORE DATABASE (asia-south1) === >> "%LOG%"
call firebase firestore:databases:create "(default)" --location=asia-south1 --project=%PROJECT_ID% >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === DEPLOYING FIRESTORE RULES === >> "%LOG%"
call firebase deploy --only firestore:rules --project=%PROJECT_ID% >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 9 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
