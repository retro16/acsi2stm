#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    gcc

srcdir="$(dirname "$0")/tools"
bindir="$PWD"
exedir="$PWD"
VERSION=`cat "$srcdir/../VERSION"`

if [ "$1" = "--windows" ]; then
  unset NATIVE
else
  NATIVE=1
fi

echo "Patch the tools source to set VERSION to $VERSION"

sed -i 's/^\(#define ACSI2STM_VERSION\).*/\1 "'$VERSION'"/' "$srcdir/acsi2stm.h"

if [ "$NATIVE" ]; then
  echo "Searching for a valid C compiler"
  if [ "$CC" ] && which "$CC" &>/dev/null; then
    echo "Using environment-defined CC ('$CC')"
  elif which "gcc" &>/dev/null; then
    CC=gcc
    CFLAGS="-I '$srcdir' -Os -g0 -Wl,-s"
  elif which "clang" &>/dev/null; then
    CC=clang
    CFLAGS="-I '$srcdir' -Os -g0 -Wl,-s"
  elif which "cc" &>/dev/null; then
    CC=cc
  else
    echo "Could not find a native C compiler."
    exit 1
  fi
else
  unset CC
  unset CFLAGS
fi

echo "Searching for a valid Windows C compiler"
if which "$WINCC" &>/dev/null; then
  echo "Using environment-defined WINCC ($WINCC)"
elif which "i686-w64-mingw32-cc" &>/dev/null; then
  WINCC=i686-w64-mingw32-cc
  WINCFLAGS="-I '$srcdir' -Os -g0 -Wl,-s"
elif which "x86_64-w64-mingw32-cc" &>/dev/null; then
  WINCC=x86_64-w64-mingw32-cc
  WINCFLAGS="-I '$srcdir' -Os -g0 -Wl,-s"
elif which "i686-w64-mingw32-gcc" &>/dev/null; then
  WINCC=i686-w64-mingw32-gcc
  WINCFLAGS="-I '$srcdir' -Os -g0 -Wl,-s"
elif which "x86_64-w64-mingw32-gcc" &>/dev/null; then
  WINCC=x86_64-w64-mingw32-gcc
  WINCFLAGS="-I '$srcdir' -Os -g0 -Wl,-s"
else
  echo "Could not find a Windows C compiler."
  echo "Install mingw-w64 to cross-compile for Windows"
  WINCC=""
fi

export CC
export CFLAGS
export WINCC
export WINCFLAGS

buildtool() {
  if [ "$WINCC" ]; then
    echo "Compile $1 to windows EXE in $exedir"
    "$WINCC" $WINCFLAGS -o "$exedir/$1.exe" "$srcdir/$1.c" || exit $?
  fi
  if [ "$CC" ]; then
    echo "Compile $1 to native executable in $bindir"
    "$CC" $CFLAGS -o "$bindir/$1" "$srcdir/$1.c" || exit $?
  fi
}

for d in "$srcdir"/*.c; do buildtool "$(basename "$d" .c)"; done

