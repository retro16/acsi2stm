#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    arduino
#    zip
#    mtools

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
  || ! grep 'ACSI_A1_WORKAROUND 1' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_FAST_DMA 5' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_GEMDRIVE_NO_DIRECT_DMA 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || ! grep 'ACSI_PIO 0' "$srcdir/acsi2stm/acsi2stm.h" >/dev/null \
  || grep -ri 'deadbeef' "$srcdir/asm" >/dev/null \
  || grep -ri 'cafe' "$srcdir/asm" >/dev/null \
  || grep -ri 'badc0de' "$srcdir/asm" >/dev/null \
  || grep -ri 'illegal' "$srcdir/asm" >/dev/null \
  ; then
    echo "Sanity checks failed"
    echo "Please revert back to release configuration"
    exit 1
  fi
fi

outdir="$(readlink -fs "$PWD")"

export KEEP_BUILD
builddir="$outdir/build.release~"
zipdir="acsi2stm-$VERSION-release"
zipfile="$outdir/$zipdir.zip"
rm -f "$zipfile"

rm -rf "$builddir"
mkdir "$builddir"

(
cd "$builddir"

(
mkdir tools
cd tools
"$srcdir/build_asm.sh" || exit $?
)

(
mkdir firmware
cd firmware
"$srcdir/build_arduino.sh" all || exit $?
)

(
mkdir images
"$srcdir/build_atari_img.sh" || exit $?
)

echo "Copy all the stuff in the packaging directory"

mkdir "$zipdir"
cp -r firmware tools images "$srcdir"/*.md "$srcdir"/doc "$srcdir"/pcb "$srcdir"/LICENSE "$srcdir"/VERSION "$zipdir"

echo "... and the legal stuff"

cat > "$zipdir/README.txt" << EOF
ACSI2STM Atari hard drive emulator
Copyright (C) 2019-2025 by Jean-Matthieu Coulon

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

See README.md for more information.

You can open README.md as well as other files in "doc" as text files.
EOF

echo "Create release zip package"

zip -r "$zipfile" "$zipdir"
)

if ! [ "$KEEP_BUILD" ]; then
  echo "Clean up build directories ..."
  rm -r "$builddir"
fi
