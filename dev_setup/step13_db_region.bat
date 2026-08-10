@echo off
REM Recreate the empty (default) Firestore DB in asia-south1 + redeploy rules
set LOG=%~dp0setup_log.txt
echo === STEP 13: MOVE DB TO asia-south1 === > "%LOG%"

echo --- deleting nam5 database --- >> "%LOG%"
call firebase firestore:databases:delete "(default)" --project=bitewise-1d266 --force >> "%LOG%" 2>&1

echo --- creating asia-south1 database --- >> "%LOG%"
call firebase firestore:databases:create "(default)" --location=asia-south1 --project=bitewise-1d266 >> "%LOG%" 2>&1

echo --- redeploying rules --- >> "%LOG%"
call firebase deploy --only firestore:rules --project=bitewise-1d266 >> "%LOG%" 2>&1

echo --- verify --- >> "%LOG%"
call firebase firestore:databases:get "(default)" --project=bitewise-1d266 >> "%LOG%" 2>&1

echo === STEP 13 FINISHED === >> "%LOG%"
echo Done!
timeout /t 3 >nul
