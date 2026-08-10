@echo off
REM Regenerate android/ios with current Flutter (fixes Gradle 8.3 vs 8.7),
REM reapply Firebase config, build, install, launch.
set SDK=%LOCALAPPDATA%\Android\Sdk
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set FLUTTERFIRE=%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat
set ADB=%SDK%\platform-tools\adb.exe
set LOG=%~dp0run_log.txt
cd /d "%~dp0.."

echo === STEP 20: REGENERATE PLATFORMS + BUILD === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo --- removing outdated platform folders --- >> "%LOG%"
rmdir /s /q android >> "%LOG%" 2>&1
rmdir /s /q ios >> "%LOG%" 2>&1

echo --- regenerating with Flutter 3.44 --- >> "%LOG%"
call "%FLUTTER%" create . --org com.bitewise --project-name bitewise --platforms android,ios >> "%LOG%" 2>&1

echo --- reapplying Firebase config --- >> "%LOG%"
call "%FLUTTERFIRE%" configure --project=bitewise-1d266 --platforms=android,ios,web --yes >> "%LOG%" 2>&1

echo --- building debug APK --- >> "%LOG%"
echo  Building BiteWise... this takes a few minutes, leave the window open.
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

echo === STEP 20 FINISHED: %date% %time% === >> "%LOG%"
echo Done! BiteWise should now open in the emulator.
timeout /t 5 >nul
