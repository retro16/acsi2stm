#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    stm32flash
#    stty
#    tee

builddir="$PWD/build.arduino~"
srcdir="$(dirname "$0")"
VERSION=`cat "$srcdir/VERSION"`

if [ "$1" ]; then
  uart=("$@")
else
  uart=(`ls /dev/ttyUSB* 2>/dev/null | head -n 1`)
  if [ ${#uart[@]} -eq 0 ]; then
    uart=`ls /dev/ttyACM* 2>/dev/null | head -n 1`
  fi
fi

"$srcdir/build_asm.sh" || exit $?
"$srcdir/build_arduino.sh" 128 || exit $?

for u in "${uart[@]}"; do
  stm32flash -g 0x08000000 -w "$srcdir/acsi2stm-$VERSION.ino.bin" "$u" || exit $?
done

sleep 0.1
stty -F "${uart[0]}" 1000000 cs8 -cstopb -parenb || exit $?
tee acsi2stm.log < "${uart[0]}"
