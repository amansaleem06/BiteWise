@echo off
REM BiteWise setup step 2: locate Flutter SDK + install Firebase CLI
set LOG=%~dp0setup_log.txt

echo === BITEWISE SETUP STEP 2 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === SEARCHING FOR FLUTTER SDK === >> "%LOG%"
for %%P in (
  "C:\flutter\bin\flutter.bat"
  "C:\src\flutter\bin\flutter.bat"
  "C:\dev\flutter\bin\flutter.bat"
  "C:\tools\flutter\bin\flutter.bat"
  "%USERPROFILE%\flutter\bin\flutter.bat"
  "%USERPROFILE%\dev\flutter\bin\flutter.bat"
  "%USERPROFILE%\Documents\flutter\bin\flutter.bat"
  "%USERPROFILE%\Downloads\flutter\bin\flutter.bat"
  "%LOCALAPPDATA%\flutter\bin\flutter.bat"
) do (
  if exist %%P echo FOUND: %%P >> "%LOG%"
)

echo --- deep search of user profile (flutter.bat) --- >> "%LOG%"
where /R "%USERPROFILE%" flutter.bat >> "%LOG%" 2>&1
echo --- deep search done --- >> "%LOG%"

echo. >> "%LOG%"
echo === INSTALLING FIREBASE CLI (npm) === >> "%LOG%"
call npm install -g firebase-tools >> "%LOG%" 2>&1
call firebase --version >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 2 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
