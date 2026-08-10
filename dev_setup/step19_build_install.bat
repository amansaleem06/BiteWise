@echo off
REM Build debug APK, install on the running emulator, launch — fully logged
set SDK=%LOCALAPPDATA%\Android\Sdk
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set ADB=%SDK%\platform-tools\adb.exe
set LOG=%~dp0run_log.txt
cd /d "%~dp0.."

echo === STEP 19: BUILD + INSTALL + LAUNCH === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo --- devices --- >> "%LOG%"
call "%ADB%" devices >> "%LOG%" 2>&1

echo --- building debug APK (first build takes several minutes) --- >> "%LOG%"
echo  Building BiteWise APK... watch this window, takes a few minutes.
call "%FLUTTER%" build apk --debug >> "%LOG%" 2>&1

if not exist "build\app\outputs\flutter-apk\app-debug.apk" (
  echo BUILD FAILED - no APK produced >> "%LOG%"
  echo Build failed! See log.
  pause
  exit /b
)

echo --- installing --- >> "%LOG%"
call "%ADB%" install -r "build\app\outputs\flutter-apk\app-debug.apk" >> "%LOG%" 2>&1

echo --- launching --- >> "%LOG%"
call "%ADB%" shell monkey -p com.bitewise.bitewise -c android.intent.category.LAUNCHER 1 >> "%LOG%" 2>&1

echo === STEP 19 FINISHED: %date% %time% === >> "%LOG%"
echo Done! BiteWise should now open in the emulator.
timeout /t 5 >nul
