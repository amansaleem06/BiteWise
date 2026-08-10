@echo off
REM Rebuild with reduced Gradle memory, install, launch
set SDK=%LOCALAPPDATA%\Android\Sdk
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set ADB=%SDK%\platform-tools\adb.exe
set LOG=%~dp0run_log.txt
cd /d "%~dp0.."

echo === STEP 21: REBUILD (2G daemon) === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo --- stopping old gradle daemons --- >> "%LOG%"
if exist "android\gradlew.bat" (
  pushd android
  call gradlew.bat --stop >> "%LOG%" 2>&1
  popd
)

echo --- building debug APK --- >> "%LOG%"
echo  Building BiteWise... a few minutes, leave this window open.
call "%FLUTTER%" build apk --debug >> "%LOG%" 2>&1

if not exist "build\app\outputs\flutter-apk\app-debug.apk" (
  echo BUILD FAILED - no APK produced >> "%LOG%"
  echo Build failed! See log.
  pause
  exit /b
)

echo --- installing on emulator --- >> "%LOG%"
call "%ADB%" install -r "build\app\outputs\flutter-apk\app-debug.apk" >> "%LOG%" 2>&1

echo --- launching --- >> "%LOG%"
call "%ADB%" shell monkey -p com.bitewise.bitewise -c android.intent.category.LAUNCHER 1 >> "%LOG%" 2>&1

echo === STEP 21 FINISHED: %date% %time% === >> "%LOG%"
echo Done! BiteWise should now open in the emulator.
timeout /t 5 >nul
