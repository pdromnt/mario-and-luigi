@echo off
REM Build Mario & Luigi SDL2 port with Free Pascal (64-bit)
REM Output goes into OUT\ folder — ready to distribute or run.

set FPC_DIR=C:\FPC\3.2.2\bin\i386-Win32
set FPC=%FPC_DIR%\ppcrossx64.exe
if not exist "%FPC%" (
    set FPC=ppcrossx64
    set WINDRES=windres
    echo Using ppcrossx64 from PATH...
) else (
    set WINDRES=%FPC_DIR%\windres.exe
    echo Using %FPC%
)

set FPC_OPTS=-Mtp -Ci- -Cr- -Sg -Si -O2
set UNIT_PATH=-FuSDL2-for-Pascal -Fu. -Fushared -Fusrc

REM Prepare output directory
if not exist OUT mkdir OUT

set OUTPUT=-FEOUT

REM Compile icon resource (game.res is also committed to the repo
REM as a fallback in case windres is not available)
if exist resources\icon.ico if exist resources\game.rc (
    echo Compiling icon resource...
    "%WINDRES%" --preprocessor=cat -i resources\game.rc -o resources\game.res 2>nul
    if exist resources\game.res (
        echo Icon resource OK.
    ) else (
        echo WARNING: windres not found, using pre-built resources\game.res if available.
    )
)

echo.
echo Compiling game...
echo.
"%FPC%" %FPC_OPTS% %UNIT_PATH% %OUTPUT% GAME.PAS
if errorlevel 1 (
    echo.
    echo Compilation FAILED!
    pause
    exit /b 1
)
echo.
echo Compilation successful!
echo.

REM Clean up intermediate files from OUT (FPC's -FE puts everything there)
del /Q OUT\*.o OUT\*.or OUT\*.obj OUT\*.a OUT\*.ppu OUT\*.rst OUT\*.res 2>nul

REM Copy SDL2 DLLs into OUT
if exist SDL2.dll copy /Y SDL2.dll OUT\ >nul 2>&1
if exist SDL2_mixer.dll copy /Y SDL2_mixer.dll OUT\ >nul 2>&1

REM Copy music folder into OUT
if not exist OUT\music mkdir OUT\music
if exist music\*.ogg copy /Y music\*.ogg OUT\music\ >nul 2>&1

REM Copy assets folder into OUT
if exist assets (
    echo Copying assets...
    robocopy assets OUT\assets /E /NFL /NDL /NJH /NJS /NP >nul 2>&1
    if errorlevel 8 echo WARNING: Failed to copy assets!
)

echo Build complete! Output is in the OUT\ folder.
echo Run OUT\GAME.exe to play!
pause
