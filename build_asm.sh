#!/bin/sh
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

if ! [ -e acsi2stm/acsi2stm.ino ]; then
  echo "Please run this script from the root directory of the project"
  exit 1
fi

srcdir="$PWD/asm"
builddir="$PWD/build.asm~"
tosdir="$PWD"
VERSION=`cat VERSION`

echo "Patch the source to set VERSION to $VERSION"

sed -i '/; ACSI2STM VERSION NUMBER/s/dc\.b.'\''.*'\''/dc.b\t'\'"$VERSION"\'/ asm/acsi2stm.i

# Remove previous build artifacts and create a build directory
rm -rf "$builddir"
mkdir -p "$builddir"

buildbin() {
  if [ -e "$srcdir/$1/bin.s" ]; then
    echo "Compile $1 BIN program"
    vasmm68k_mot -devpac -ldots -showopt -Fbin -L "$builddir/$1.bin.lst" -o "$srcdir/$1/$1.bin" "$srcdir/$1/bin.s" || exit $?
    [ -e "$srcdir/$1/$1.bin" ] || exit $?
  fi
}

buildasm() {
  if [ -e "$srcdir/$1/boot.s" ]; then
    echo "Compile $1 boot program"
    vasmm68k_mot -devpac -ldots -showopt -Fbin -L "$builddir/$1.boot.lst" -o "$builddir/$1.boot.bin" "$srcdir/$1/boot.s" || exit $?
    [ -e "$builddir/$1.boot.bin" ] || exit $?

    echo "Generate Arduino source code from the binary blob"

    cd "$builddir"
    xxd -i "$1.boot.bin" > "../acsi2stm/$1.boot.h"
  fi

  if [ -e "$srcdir/$1/tools.s" ]; then
    echo "Compile $1 tools payload"
    vasmm68k_mot -devpac -ldots -showopt -Fbin -L "$builddir/$1.tools.lst" -o "$builddir/$1.tools.bin" "$srcdir/$1/tools.s" || exit $?
    [ -e "$builddir/$1.tools.bin" ] || exit $?

    echo "Generate source code from the binary blob"

    cd "$builddir"
    xxd -i "$1.tools.bin" > "../tools/$1.h"
  fi

  if [ -e "$srcdir/$1/tos.s" ]; then
    echo "Compile $1 TOS program"
    [ -e "$tosdir" ] || mkdir "$tosdir"
    vasmm68k_mot -devpac -ldots -showopt -Ftos -L "$builddir/$1.lst" -o "$tosdir/$1.tos" "$srcdir/$1/tos.s" || exit $?
    [ -e "$tosdir/$1.tos" ] || exit $?
  fi
}

cd "$srcdir"; for d in *; do buildbin "$d"; done
cd "$srcdir"; for d in *; do buildasm "$d"; done
cd "$srcdir"
for d in *; do
  if [ -e "$d/$d.bin" ]; then
    rm "$d/$d.bin"
  fi
done


# Clean up

cd ..
rm -r "$builddir"
