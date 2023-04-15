#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    arduino
#    zip

srcdir="$(readlink -fs "$(dirname "$0")")"
VERSION=`cat "$srcdir/VERSION"`

# Sanity checks for release package !
if ! [ "$FORCE" ]; then
  if ! grep 'ACSI_DEBUG 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_VERBOSE 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_SD_CARDS 5' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_STRICT 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_READONLY 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_SD_WRITE_LOCK 2' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_HAS_RESET 1' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_GEMDOS_SNIFFER 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_STACK_CANARY 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || grep -ri 'deadbeef' "$srcdir/asm" >/dev/null \
  || grep -ri 'cafe' "$srcdir/asm" >/dev/null \
  || grep -ri 'badc0de' "$srcdir/asm" >/dev/null \
  ; then
    echo "Sanity checks failed"
    echo "Please revert back to release configuration"
    exit 1
  fi
fi

rm -f acsi2stm-$VERSION.zip
outdir="$(readlink -fs "$PWD")"

export KEEP_BUILD
builddir="$outdir/build.release~"
zipfile="$outdir/acsi2stm-$VERSION-release.zip"

rm -rf "$builddir"
mkdir "$builddir"

(
cd "$builddir"

"$srcdir/build_asm.sh" || exit $?
"$srcdir/build_arduino.sh" all || exit $?

echo "Copy all the stuff in the packaging directory"

mkdir "acsi2stm-$VERSION"
cp -r acsi2stm-$VERSION*.ino.bin *.tos "$srcdir"/*.md "$srcdir"/doc "$srcdir"/pcb "$srcdir"/LICENSE "$srcdir"/VERSION "acsi2stm-$VERSION"

echo "... and the legal stuff"

cat > "acsi2stm-$VERSION/README.txt" << EOF
ACSI2STM Atari hard drive emulator
Copyright (C) 2019-2023 by Jean-Matthieu Coulon

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

zip -r "$zipfile" "acsi2stm-$VERSION"
)

if ! [ "$KEEP_BUILD" ]; then
  echo "Clean up build directories ..."
  rm -r "$builddir"
fi
