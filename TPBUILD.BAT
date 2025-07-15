REM Assumes you have a Turbo Pascal 7.x at C:\TP7 and your source tree is at C:\

PUSHD SRC
C:\TP7\TPC.EXE /M /L /IC:\RES\PAL\PAS\ /IC:\RES\SPR\PAS\ /IC:\RES\BGR\PAS\ /IC:\TP7\ /OC:\RES\OBJ\ /EC:\OUT\ MARIO.PAS
POPD

ECHO If your build succeeded, the executable is available at C:\OUT\MARIO.EXE.
