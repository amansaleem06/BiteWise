@echo off
REM Check Firestore DB location; move to asia-south1 if it landed in the US default
set LOG=%~dp0setup_log.txt
echo === STEP 12: DB LOCATION === > "%LOG%"
call firebase firestore:databases:get "(default)" --project=bitewise-1d266 >> "%LOG%" 2>&1
echo === END === >> "%LOG%"
echo Done!
timeout /t 3 >nul
