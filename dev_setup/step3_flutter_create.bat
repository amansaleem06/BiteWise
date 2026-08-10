@echo off
REM BiteWise setup step 3: PATH fix + flutter create + pub get + doctor
set FLUTTER=C:\Users\Lenovo\source\flutter\bin\flutter.bat
set LOG=%~dp0setup_log.txt
cd /d "%~dp0.."

echo === BITEWISE SETUP STEP 3 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === ADDING FLUTTER TO USER PATH === >> "%LOG%"
powershell -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -notlike '*source\flutter\bin*'){[Environment]::SetEnvironmentVariable('Path', $p + ';C:\Users\Lenovo\source\flutter\bin', 'User'); Write-Output 'PATH updated'} else {Write-Output 'PATH already contains flutter'}" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER VERSION === >> "%LOG%"
call "%FLUTTER%" --version >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER CREATE (platform folders) === >> "%LOG%"
call "%FLUTTER%" create . --org com.bitewise --project-name bitewise --platforms android,ios >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER PUB GET === >> "%LOG%"
call "%FLUTTER%" pub get >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER DOCTOR === >> "%LOG%"
call "%FLUTTER%" doctor >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 3 FINISHED: %date% %time% === >> "%LOG%"
echo Done! You can close this window.
timeout /t 5 >nul
