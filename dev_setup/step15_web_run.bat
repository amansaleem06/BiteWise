@echo off
REM Add web platform to Firebase config, then run BiteWise in Chrome
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set FLUTTERFIRE=%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat
set LOG=%~dp0setup_log.txt
cd /d "%~dp0.."

echo === STEP 15: ADD WEB PLATFORM === > "%LOG%"
call "%FLUTTERFIRE%" configure --project=bitewise-1d266 --platforms=android,ios,web --yes >> "%LOG%" 2>&1
echo === CONFIGURE DONE, LAUNCHING APP === >> "%LOG%"

echo.
echo  Launching BiteWise in Chrome... first build takes a minute or two.
echo  Leave this window open while using the app. Press q here to quit.
echo.
call "%FLUTTER%" run -d chrome
