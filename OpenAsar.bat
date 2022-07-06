@echo off
setlocal
if "%selfWrapped%"=="" (
  REM this is necessary so that we can use "exit" to terminate the batch file,
  REM and all subroutines, but not the original cmd.exe
  set selfWrapped=true
  %ComSpec% /s /c ""%~0" %*"
  if /i not "%cmdcmdline:"=%" == "%ComSpec%" pause
  goto :eof
)

set "arg=%1"
if "%arg%" == "-h"     goto :help
if "%arg%" == "--help" goto :help
if "%arg%" == "/h"     goto :help
if "%arg%" == "/?"     goto :help

for /f "tokens=* usebackq" %%f in (`powershell -noprofile -c "[Console]::Title.Replace(' - %0','') -replace '(.+) - .+'"`) do set "initialTitle=%%f"
set "title=OpenAsar Installer - %initialTitle%"
title %title%

set initialDirectory=%cd%

call :discord-release & echo.
if not "%errorlevel%"=="0" goto :end
call :install & echo.
if not "%errorlevel%"=="0" goto :end
goto :end

:install
tasklist | find /i "discord%discord%" >nul && (
  echo Killing Discord %discord%
  taskkill /f /im Discord%discord%.exe
  echo.
  set "wasOpen=true"
  echo Discord will launch again when finished.
)
cd /D %localappdata%\Discord%discord%\app*\resources
if exist app.asar (
  rename app.asar app.asar.bak
  curl -L -o app.asar https://github.com/GooseMod/OpenAsar/releases/download/nightly/app.asar
) else if exist app-original.asar (
  rename app-original.asar app-original.asar.bak
  curl -L -o app-original.asar https://github.com/GooseMod/OpenAsar/releases/download/nightly/app.asar
) else (
  echo app.asar not found.
  set errorlevel=1
  goto :eof
)
cd ..
if "%wasOpen%"=="true" (
  echo Starting Discord %discord%
  call %localappdata%\Discord%discord%\Update.exe --processStart Discord%discord%.exe
)
goto :eof

:discord-release
if not [%arg%]==[] (set "discord=%arg%") else (
  echo S = Stable
  echo P = PTB
  echo C = Canary
  echo D = Development
  set /p discord="Discord Release: "
)
       if /i %discord%==S (      set "discord="
) else if /i %discord%==Stable ( set "discord="
) else if /i %discord%==P (      set "discord=PTB"
) else if /i %discord%==C (      set "discord=Canary"
) else if /i %discord%==D (      set "discord=Development"
) else if /i %discord%==Dev (    set "discord=Development"
) else (
  echo Invalid release channel.
  set errorlevel=1
  goto :eof
)
goto :eof

:help
echo You can set a singular argument to select a release channel.
echo "%cd:"=%\%~0" Stable
echo.
endlocal
exit /b

:end
echo Finished. Err: %errorlevel%
cd /D %initialDirectory%
title %initialTitle%
endlocal
exit /b %errorlevel%
