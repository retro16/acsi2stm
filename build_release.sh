#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    arduino
#    zip

srcdir="$(dirname "$0")"
VERSION=`cat "$srcdir/VERSION"`

# Sanity checks for release package !
if ! grep 'ACSI_DEBUG 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep 'ACSI_VERBOSE 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep 'ACSI_SD_CARDS 5' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep 'ACSI_STRICT 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep 'ACSI_READONLY 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep 'ACSI_SD_WRITE_LOCK 2' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep 'ACSI_HAS_RESET 1' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
|| ! grep -E 'maxsecsize.*16384' "$srcdir/asm/acsi2stm.i" >/dev/null \
|| ! grep -E 'enablesetup.*1' "$srcdir/asm/acsi2stm.i" >/dev/null \
|| ! grep -E 'enableserial.*1' "$srcdir/asm/acsi2stm.i" >/dev/null \
|| grep -ri 'deadbeef' "$srcdir/asm" >/dev/null \
|| grep -ri 'cafe' "$srcdir/asm" >/dev/null \
|| grep -ri 'badc0de' "$srcdir/asm" >/dev/null \
; then
  echo "Sanity checks failed"
  echo "Please revert back to release configuration"
  exit 1
fi

rm -f acsi2stm-*.zip acsi2stm-*.ino.bin *.tos *.exe

export KEEP_BUILD
"$srcdir/build_asm.sh" || exit $?
"$srcdir/build_arduino.sh" || exit $?
"$srcdir/build_tools.sh" --windows || exit $?

if [ "$(find -size +64k -name 'acsi2stm-*.ino.bin')" ]; then
  echo "acsi2stm firmware is too big for release"
  exit 1
fi

if ! [ -e a2stboot.exe ]; then
  echo "Missing Windows executable"
  exit 1
fi

builddir="$PWD/build.release~"
zipfile="$PWD/acsi2stm-$VERSION.zip"

rm -rf "$builddir"
mkdir "$builddir"

echo "Copy all the stuff in the release directory"

cp -r "acsi2stm-$VERSION.ino.bin" *.tos *.exe "$srcdir"/README.md "$srcdir"/doc "$srcdir"/pcb "$srcdir"/LICENSE "$builddir"

echo "... and the legal stuff"

cat > "$builddir/README.txt" << EOF
ACSI2STM Atari hard drive emulator
Copyright (C) 2019-2022 by Jean-Matthieu Coulon

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

For source code, documentation and more information about this
software, see its GitHub page:

    https://github.com/retro16/acsi2stm

You can open README.md as well as other files in "doc" as text files.
EOF

echo "Create release zip package"

cd "$builddir"
zip -r "$zipfile" *

echo "Clean up build directories ..."

cd ..
if ! [ "$KEEP_BUILD" ]; then
  rm -f acsi2stm-*.ino.bin *.tos *.exe
  rm -r "$builddir"
fi
