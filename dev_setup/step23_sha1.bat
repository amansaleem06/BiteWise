@echo off
REM Extract the debug keystore SHA-1 (needed for Google Sign-In on Android)
set LOG=%~dp0sha1.txt
set KEYTOOL=C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot\bin\keytool.exe
echo === DEBUG KEYSTORE FINGERPRINTS === > "%LOG%"
"%KEYTOOL%" -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android >> "%LOG%" 2>&1
echo Done!
timeout /t 3 >nul
