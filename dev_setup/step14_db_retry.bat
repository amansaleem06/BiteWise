@echo off
REM Retry Firestore DB creation in asia-south1 (waits out the deletion cooldown)
set LOG=%~dp0setup_log.txt
echo === STEP 14: CREATE DB IN asia-south1 (with retries) === > "%LOG%"

set /a tries=0
:retry
set /a tries+=1
echo --- attempt %tries% --- >> "%LOG%"
call firebase firestore:databases:create "(default)" --location=asia-south1 --project=bitewise-1d266 >> "%LOG%" 2>&1
findstr /C:"Successfully created" "%LOG%" >nul
if %errorlevel%==0 goto :created
if %tries% geq 8 goto :failed
echo Waiting 60s before retry %tries%... (cooldown after deletion)
timeout /t 60 >nul
goto :retry

:created
echo --- deploying rules --- >> "%LOG%"
call firebase deploy --only firestore:rules --project=bitewise-1d266 >> "%LOG%" 2>&1
echo --- verify --- >> "%LOG%"
call firebase firestore:databases:get "(default)" --project=bitewise-1d266 >> "%LOG%" 2>&1
echo === STEP 14 FINISHED OK === >> "%LOG%"
echo All done! You can close this window.
timeout /t 5 >nul
exit /b

:failed
echo === STEP 14 FAILED after %tries% attempts === >> "%LOG%"
echo Failed - see log.
pause
