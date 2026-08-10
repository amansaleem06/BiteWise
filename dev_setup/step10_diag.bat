@echo off
REM Diagnose project creation failure
set LOG=%~dp0setup_log.txt
echo === STEP 10 DIAG === > "%LOG%"
call firebase projects:create bitewise-app-71042 --display-name "BiteWise" --debug >> "%LOG%" 2>&1
echo === END DIAG === >> "%LOG%"
echo Done!
timeout /t 3 >nul
