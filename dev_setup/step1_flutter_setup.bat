@echo off
REM BiteWise setup step 1: environment check + flutter create + pub get
cd /d "%~dp0.."
set LOG=%~dp0setup_log.txt

echo === BITEWISE SETUP STEP 1 === > "%LOG%"
echo Started: %date% %time% >> "%LOG%"

echo. >> "%LOG%"
echo === ENVIRONMENT CHECK === >> "%LOG%"
where flutter >> "%LOG%" 2>&1
call flutter --version >> "%LOG%" 2>&1
where dart >> "%LOG%" 2>&1
where node >> "%LOG%" 2>&1
call node --version >> "%LOG%" 2>&1
where npm >> "%LOG%" 2>&1
call npm --version >> "%LOG%" 2>&1
where firebase >> "%LOG%" 2>&1
call firebase --version >> "%LOG%" 2>&1
where git >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER CREATE (platform folders) === >> "%LOG%"
call flutter create . --org com.bitewise --project-name bitewise --platforms android,ios >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === FLUTTER PUB GET === >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo === STEP 1 FINISHED: %date% %time% === >> "%LOG%"
echo.
echo Done! You can close this window.
timeout /t 5 >nul
