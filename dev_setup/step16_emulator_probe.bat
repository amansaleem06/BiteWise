@echo off
REM Probe emulator + AVD + system image situation
set SDK=%LOCALAPPDATA%\Android\Sdk
set LOG=%~dp0setup_log.txt
echo === STEP 16: EMULATOR PROBE === > "%LOG%"

echo --- emulator version --- >> "%LOG%"
"%SDK%\emulator\emulator.exe" -version 2>>"%LOG%" | findstr /C:"Android emulator version" >> "%LOG%"

echo --- existing AVDs --- >> "%LOG%"
"%SDK%\emulator\emulator.exe" -list-avds >> "%LOG%" 2>&1

echo --- installed system images --- >> "%LOG%"
if exist "%SDK%\system-images" (
  dir /s /b "%SDK%\system-images\*.ini" >> "%LOG%" 2>&1
  dir /b "%SDK%\system-images" >> "%LOG%" 2>&1
  for /d %%a in ("%SDK%\system-images\*") do (
    for /d %%b in ("%%a\*") do (
      for /d %%c in ("%%b\*") do echo IMAGE: %%c >> "%LOG%"
    )
  )
) else (
  echo no system-images folder >> "%LOG%"
)

echo --- avd home --- >> "%LOG%"
if exist "%USERPROFILE%\.android\avd" dir /b "%USERPROFILE%\.android\avd" >> "%LOG%" 2>&1

echo === STEP 16 DONE === >> "%LOG%"
echo Done!
timeout /t 3 >nul
