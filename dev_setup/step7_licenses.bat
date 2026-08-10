@echo off
REM BiteWise setup step 7: accept licenses via sdkmanager + install build-tools
set SDKMGR=%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set LOG=%~dp0setup_log.txt
set YES=%~dp0yes.txt

echo === BITEWISE SETUP STEP 7 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

REM Build a file of 50 'y' lines to feed every license prompt.
(for /l %%i in (1,1,50) do @echo y) > "%YES%"

echo. >> "%LOG%"
echo === ACCEPTING LICENSES (sdkmanager) === >> "%LOG%"
call "%SDKMGR%" --licenses < "%YES%" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === INSTALLING PLATFORM/BUILD TOOLS === >> "%LOG%"
call "%SDKMGR%" "platform-tools" "platforms;android-36" "build-tools;36.0.0" < "%YES%" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER DOCTOR (final) === >> "%LOG%"
call "%FLUTTER%" doctor >> "%LOG%" 2>&1

del "%YES%" >nul 2>&1
echo. >> "%LOG%"
echo === STEP 7 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
