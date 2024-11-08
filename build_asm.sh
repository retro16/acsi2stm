#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    vasmm68k_mot
#    xxd
#    arduino
#    zip

srcdir="$(dirname "$0")/asm"
builddir="$PWD/build.asm~"
tosdir="$PWD"
VERSION=`cat "$srcdir/../VERSION"`
VASMFLAGS="-maxerrors=20 -devpac -ldots"
VASMFLAGS="$VASMFLAGS -showopt"

# Remove previous build artifacts and create a build directory
rm -rf "$builddir"
mkdir -p "$builddir"

buildasm() {
  if [ -e "$1/boot.s" ]; then
    name="$(basename "$1")"
    echo "Compile $name boot program"
    [ -d "$builddir/$name" ] || mkdir -p "$builddir/$name" || exit $?
    vasmm68k_mot $VASMFLAGS -Fbin -I"$builddir" -L "$builddir/$name.boot.lst" -o "$builddir/$name.boot.bin" "$srcdir/$name/boot.s" || exit $?
    [ -e "$builddir/$name.boot.bin" ] || exit $?

    echo "Generate Arduino source code from the binary blob"

    (
      cd "$builddir"
      xxd -i "$name.boot.bin" > "$name.boot.h"
    )
    cp "$builddir/$name.boot.h" "$srcdir/../acsi2stm/"
    echo
  fi

  if [ -e "$1/tos.s" ]; then
    name="$(basename "$1")"
    echo "Compile $name.TOS"
    [ -d "$builddir/$name" ] || mkdir -p "$builddir/$name" || exit $?
    [ -e "$tosdir" ] || mkdir "$tosdir"
    vasmm68k_mot $VASMFLAGS -monst -Ftos -I"$builddir/$name" -L "$builddir/$name.lst" -o "$tosdir/$name.TOS" "$srcdir/$name/tos.s" || exit $?
    [ -e "$tosdir/$name.TOS" ] || exit $?
    echo
  fi

  if [ -e "$1/prg.s" ]; then
    name="$(basename "$1")"
    echo "Compile $name.PRG"
    [ -d "$builddir/$name" ] || mkdir -p "$builddir/$name" || exit $?
    [ -e "$tosdir" ] || mkdir "$tosdir"
    vasmm68k_mot $VASMFLAGS -monst -Ftos -I"$builddir/$name" -L "$builddir/$name.lst" -o "$tosdir/$name.PRG" "$srcdir/$name/prg.s" || exit $?
    [ -e "$tosdir/$name.PRG" ] || exit $?
    echo
  fi
}

for d in "$srcdir"/*; do buildasm "$d"; done

# Clean up

if ! [ "$KEEP_BUILD" ]; then
  rm -r "$builddir"
fi
