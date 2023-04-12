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

# Remove previous build artifacts and create a build directory
rm -rf "$builddir"
mkdir -p "$builddir"

buildbin() {
  export builddir
  (
    cd "$1"
    if [ -e "bin.s" ]; then
      name="$(basename "$1")"
      [ -d "$builddir/$name" ] || mkdir -p "$builddir/$name" || exit $?
      echo "Compile $name BIN program"
      vasmm68k_mot -maxerrors=20 -devpac -ldots -showopt -Fbin -L "$builddir/$name.bin.lst" -o "$builddir/$name/$name.bin" "$srcdir/$name/bin.s" || exit $?
      [ -e "$builddir/$name/$name.bin" ] || exit $?
    fi
  )
}

buildasm() {
  if [ -e "$1/boot.s" ]; then
    name="$(basename "$1")"
    echo "Compile $name boot program"
    [ -d "$builddir/$name" ] || mkdir -p "$builddir/$name" || exit $?
    vasmm68k_mot -maxerrors=20 -devpac -ldots -showopt -Fbin -I"$builddir" -L "$builddir/$name.boot.lst" -o "$builddir/$name.boot.bin" "$srcdir/$name/boot.s" || exit $?
    [ -e "$builddir/$name.boot.bin" ] || exit $?

    echo "Generate Arduino source code from the binary blob"

    (
      cd "$builddir"
      xxd -i "$name.boot.bin" > "$name.boot.h"
    )
    cp "$builddir/$name.boot.h" "$srcdir/../acsi2stm/"
  fi

  if [ -e "$1/tos.s" ]; then
    name="$(basename "$1")"
    echo "Compile $name TOS program"
    [ -d "$builddir/$name" ] || mkdir -p "$builddir/$name" || exit $?
    [ -e "$tosdir" ] || mkdir "$tosdir"
    vasmm68k_mot -maxerrors=20 -devpac -monst -ldots -showopt -Ftos -I"$builddir/$name" -L "$builddir/$name.lst" -o "$tosdir/$name.tos" "$srcdir/$name/tos.s" || exit $?
    [ -e "$tosdir/$name.tos" ] || exit $?
  fi
}

for d in "$srcdir"/*; do buildbin "$d"; done
for d in "$srcdir"/*; do buildasm "$d"; done

# Clean up

if ! [ "$KEEP_BUILD" ]; then
  rm -r "$builddir"
fi
