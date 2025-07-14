#!/usr/bin/env bash

if [ "${FPC_LARGE}" == "" ]; then
  echo "\$FPC_LARGE env variable not defined!"
  echo "Point it to the directory with your"
  echo "FPC cross compiler for i8086/msdos"
  echo "built with large memory model (-WmLarge)."
  echo ""
  echo "Proper build script coming soon."
  exit 1
fi

mkdir -p OUT/
rm OUT/*.o OUT/*.a OUT/*.ppu OUT/*.s OUT/*.exe 2>/dev/null
${FPC_LARGE}/bin/x86_64-linux/ppcross8086 \
  -XX \
  -Tmsdos \
  -Mtp \
  -WmLarge \
  -Fu${FPC_LARGE}'/units/i8086-msdos/*' \
  -Fu${FPC_LARGE}'/units/msdos/*' \
  -Fi./RES/PAL/PAS/ \
  -Fi./RES/SPR/PAS/ \
  -Fi./RES/BGR/PAS/ \
  -FuRES/OBJ \
  -oOUT/MARIO.exe \
  SRC/MARIO.PAS 

if [ "$?" == "0" ]; then
  echo "Build OK, your executable is in OUT/MARIO.EXE."
else
  echo "Build failed, see compiler messages."
fi
