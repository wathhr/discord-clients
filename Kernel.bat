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

for /f "tokens=* usebackq" %%F in (`powershell -noprofile -c "[Console]::Title.Replace(' - %0','') -replace '(.+) - .+'"`) do set "initialTitle=%%F"
set "title=Kernel Installer - %initialTitle%"
title %title%

set initialDirectory=%cd%
set kernelasarDirectory=%~dp0Kernel
cd %kernelasarDirectory%

call :discord-release & echo.
if not "%errorlevel%"=="0" goto :end
if not exist git\ mkdir git\
cd git\
call :browser & echo.
if not "%errorlevel%"=="0" goto :end
call :electron & echo.
if not "%errorlevel%"=="0" goto :end
call :installer & echo.
if not "%errorlevel%"=="0" goto :end
cd ..
call :install & echo.
if not "%errorlevel%"=="0" goto :end
call :optional-packages & echo.
if not "%errorlevel%"=="0" goto :end
goto :end

:browser
echo Updating the browser repository...
if exist browser\.git\ (
  cd browser
  call git reset --hard
  call git pull --force
  cd ..
) else (
  rmdir /s /q browser >nul 2>&1
  call git clone https://github.com/kernel-mod/browser.git browser
)
cd browser
call pnpm i
cd ..
goto :eof

:electron
echo Updating the electron repository...
if exist electron\.git\ (
  cd electron
  call git reset --hard
  call git pull --force
  cd ..
) else (
  rmdir /s /q electron >nul 2>&1
  call git clone https://github.com/kernel-mod/electron.git electron
)
cd electron
call pnpm i
echo.
echo Building Kernel...
call pnpm run build
cd ..
goto :eof

:installer
echo Updating installer...
if exist kernel-installer.exe (
  del kernel-installer.exe
)
curl -L -o kernel-installer.exe https://github.com/kernel-mod/installer-cli/releases/download/refs/heads/master/kernel-installer-x86_64-windows.exe
goto :eof

:install
tasklist | find /i "discord%discord%" && (
  echo Killing Discord %discord%
  taskkill /f /im Discord%discord%.exe
  echo.
  set "wasOpen=true"
  echo Discord will launch again when finished.
)
cd /D %localappdata%\Discord%discord%\app*
timeout 2>nul & REM very good solution
if exist resources\app\ (
  cd resources
  rmdir /s /q app\
  rename app-original.asar app.asar
  cd ..
)
call %kernelasarDirectory%\git\kernel-installer.exe -i . -k %kernelasarDirectory%
move %kernelasarDirectory%\git\electron\dist\kernel.asar %kernelasarDirectory%
if not exist %kernelasarDirectory%\Packages mkdir %kernelasarDirectory%\Packages
if "%wasOpen%"=="true" (
  echo Starting Discord %discord%
  call %localappdata%\Discord%discord%\Update.exe --processStart Discord%discord%.exe
)
cd /D %kernelasarDirectory%
goto :eof

:optional-packages
choice /C YN /T 10 /D N /N /M "Would you like to install some optional packages? (y/N)"
if %errorlevel% equ 1 (
  set "user=strencher-kernel" & set "package=bd-compat" & call :kernel-package
  set "user=strencher-kernel" & set "package=pc-compat" & call :kernel-package
  set "user=strencher-kernel" & set "package=settings" & call :kernel-package
  set "user=discord-modifications" & set "package=discord-utilities" & call :kernel-package
  echo Finishing up
  forfiles /c "cmd /c if @isdir==TRUE (if exist @file\package.json (if not exist @file\node_modules\ (cd @file && echo @path & pnpm i & cd ..)))"
  echo Discord needs to be relaunched/reloaded for these changes to take effect.
)
set errorlevel=0
goto :eof

:kernel-package
echo Installing %package%
pushd
cd %kernelasarDirectory%\Packages
if not exist %package% (
  call git clone https://github.com/%user%/%package%.git
) else (
  cd %package%
  call git reset --hard
  call git pull --force
  cd ..
)
popd
echo.
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
