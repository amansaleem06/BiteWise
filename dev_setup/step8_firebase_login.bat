@echo off
REM BiteWise setup step 8: Firebase login (requires YOUR Google sign-in)
set LOG=%~dp0setup_log.txt
echo.
echo  ============================================================
echo   FIREBASE LOGIN
echo   A browser window will open. Sign in with the Google
echo   account you want to own the BiteWise Firebase project.
echo   If asked about usage data collection below, type Y or n
echo   and press Enter.
echo  ============================================================
echo.
call firebase login
echo === FIREBASE LOGIN RESULT === > "%LOG%"
call firebase login:list >> "%LOG%" 2>&1
call firebase projects:list >> "%LOG%" 2>&1
echo.
echo Done! You can close this window.
pause
