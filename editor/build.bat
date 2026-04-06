@echo off
REM Build Mario & Luigi Level Editor (64-bit)
REM Requires: FPC x86_64 cross-compiler (ppcrossx64)
REM           + ImGui-Pascal in editor\ImGui-Pascal\

set FPC_DIR=C:\FPC\3.2.2\bin\i386-Win32
set FPC=%FPC_DIR%\ppcrossx64.exe
if not exist "%FPC%" (
    set FPC=ppcrossx64
    echo Using ppcrossx64 from PATH...
) else (
    echo Using %FPC%
)

set FPC_OPTS=-MDelphi -Sg -Si -O2 -dDYNAMIC_LINK -dSDL2
set IMGUI=ImGui-Pascal

REM Check for ImGui-Pascal dependency
if not exist "%IMGUI%\src\PasImGui.pas" (
    echo.
    echo ERROR: ImGui-Pascal not found!
    echo Run setup first:  powershell -ExecutionPolicy Bypass -File setup_imgui.ps1
    echo.
    pause
    exit /b 1
)

REM Unit search paths:
REM   OUT first so fresh editor PPU/O files take priority over stale game builds in ..\OUT
REM   ImGui-Pascal src, impl, OpenGL3, SDL2 bindings
REM   Parent dir (..) for game units: VGA256, Buffers, Figures, BackGr, Worlds, Palettes, etc.
set UNIT_PATH=-FuOUT -Fu%IMGUI%\src -Fu%IMGUI%\impl -Fu%IMGUI%\OpenGL3 -Fu%IMGUI%\SDL2-for-Pascal\units -Fu.. -Fu..\shared
set INC_PATH=-Fi%IMGUI%\src -Fi%IMGUI%\SDL2-for-Pascal\units -Fi..

REM Library search path (for dynamic linking)
set LIB_PATH=-Fl%IMGUI%\libs\dynamic\windows\64bit

REM Output directory
if not exist OUT mkdir OUT
set OUTPUT=-FEOUT

REM Remove stale game PPU/O files from parent OUT directory.
REM FPC's -Fu.. also searches ..\OUT for object files; stale .o files there
REM can shadow freshly compiled ones and cause linker errors.
del /Q "..\OUT\*.ppu" "..\OUT\*.o" 2>nul

REM Compile icon resource (editor.res is also committed to the repo
REM as a fallback in case windres is not available)
set WINDRES=%FPC_DIR%\x86_64-win64-windres.exe
if not exist "%WINDRES%" set WINDRES=%FPC_DIR%\windres.exe
if exist icon.ico if exist editor.rc (
    echo Compiling icon resource...
    "%WINDRES%" --preprocessor=cat -i editor.rc -o editor.res 2>nul
    if exist editor.res (
        echo Icon resource OK.
    ) else (
        echo WARNING: windres not found, using pre-built editor.res if available.
    )
)

echo.
echo Compiling Mario ^& Luigi Level Editor (64-bit)...
echo.
"%FPC%" %FPC_OPTS% %UNIT_PATH% %INC_PATH% %LIB_PATH% %OUTPUT% EDITOR.PAS
if errorlevel 1 (
    echo.
    echo Compilation FAILED!
    pause
    exit /b 1
)
echo.
echo Compilation successful!
echo.

REM Clean up intermediate files
del /Q OUT\*.o OUT\*.or OUT\*.obj OUT\*.a OUT\*.ppu OUT\*.rst OUT\*.res 2>nul

REM Copy required DLLs
copy /Y "%IMGUI%\libs\dynamic\windows\64bit\cimgui.dll" OUT\ >nul 2>&1
copy /Y "%IMGUI%\libs\dynamic\windows\64bit\SDL2.dll" OUT\ >nul 2>&1

REM Copy assets folder
if exist "..\assets" (
    echo Copying assets...
    robocopy "..\assets" "OUT\assets" /E /NFL /NDL /NJH /NJS /NP >nul 2>&1
)

echo Build complete! Output is in the OUT\ folder.
echo Run OUT\EDITOR.exe to launch the editor!
pause
