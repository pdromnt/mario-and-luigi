@echo off
REM Build the asset exporter tool
REM Uses FPC (32-bit is fine, no SDL2 dependency)

set FPC=C:\FPC\3.2.2\bin\i386-Win32\fpc.exe

if not exist "%FPC%" (
    echo FPC not found at %FPC%
    echo Trying ppcrossx64...
    set FPC=C:\FPC\3.2.2\bin\i386-Win32\ppcrossx64.exe
)

if not exist OUT mkdir OUT

echo Building export_assets...
%FPC% -MDelphi -O2 -FuOUT -FiOUT -Fi.. -Fi..\data -Fi..\sprites -FEOUT export_assets.pas

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED
    exit /b 1
)

echo.
echo Build successful! Run OUT\export_assets.exe to export all assets.
echo.
