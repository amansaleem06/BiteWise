@echo off
set SDK=%LOCALAPPDATA%\Android\Sdk
set LOG=%~dp0probe_log.txt
echo === EMULATOR PROBE 2 === > "%LOG%"

echo --- existing AVDs --- >> "%LOG%"
call "%SDK%\emulator\emulator.exe" -list-avds >> "%LOG%" 2>&1

echo --- system-images tree --- >> "%LOG%"
if exist "%SDK%\system-images" (
  for /d %%a in ("%SDK%\system-images\*") do (
    for /d %%b in ("%%a\*") do (
      for /d %%c in ("%%b\*") do echo IMAGE: %%c >> "%LOG%"
    )
  )
) else (
  echo no system-images folder >> "%LOG%"
)

echo --- avd home --- >> "%LOG%"
if exist "%USERPROFILE%\.android\avd" (
  dir /b "%USERPROFILE%\.android\avd" >> "%LOG%" 2>&1
) else (
  echo no avd folder >> "%LOG%"
)

echo === PROBE 2 DONE === >> "%LOG%"
echo Done!
timeout /t 3 >nul
