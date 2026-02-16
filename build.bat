@echo off
REM Build Mario & Luigi SDL2 port with Free Pascal
REM -Mtp: Turbo Pascal mode (Integer = 16-bit)
REM -Ci-: No IO checking
REM -Cr-: No range checking
REM -Sg: Allow goto statements
REM -Si: Allow inline
REM -O2: Optimization level 2

set FPC_DIR=C:\FPC\3.2.2\bin\i386-Win32
set FPC=%FPC_DIR%\ppc386.exe
if not exist "%FPC%" (
    set FPC=fpc
    set WINDRES=windres
    echo Using fpc from PATH...
) else (
    set WINDRES=%FPC_DIR%\windres.exe
    echo Using %FPC%
)

set FPC_OPTS=-Mtp -Ci- -Cr- -Sg -Si -O2
set UNIT_PATH=-FuSDL2-for-Pascal -Fu.
set OUTPUT=-FE.

REM Compile icon resource (mario.res is also committed to the repo
REM as a fallback in case windres is not available)
if exist icon.ico if exist mario.rc (
    echo Compiling icon resource...
    "%WINDRES%" --preprocessor=cat -i mario.rc -o mario.res 2>nul
    if exist mario.res (
        echo Icon resource OK.
    ) else (
        echo WARNING: windres not found, using pre-built mario.res if available.
    )
)

echo.
echo Compiling Mario SDL2 port...
echo.
"%FPC%" %FPC_OPTS% %UNIT_PATH% %OUTPUT% mario.pas
if errorlevel 1 (
    echo.
    echo Compilation FAILED!
    pause
    exit /b 1
)
echo.
echo Compilation successful!
echo.

REM Copy SDL2.dll if not present
if not exist SDL2.dll (
    if exist ..\SDL2.dll (
        copy ..\SDL2.dll . >nul 2>&1
        echo Copied SDL2.dll
    ) else (
        echo WARNING: SDL2.dll not found! Game will not run without it.
    )
)

echo Run mario.exe to play!
pause
