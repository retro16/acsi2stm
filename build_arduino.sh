#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    arduino
#    zip

builddir="$PWD/build.arduino~"
srcdir="$(dirname "$0")"
VERSION=`cat "$srcdir/VERSION"`

echo "Patch the arduino source to set VERSION to $VERSION"

sed -i 's/^\(#define ACSI2STM_VERSION\).*/\1 "'$VERSION'"/' "$srcdir/acsi2stm/acsi2stm.h"

echo "Create a clean build directory"

rm -rf "$builddir"
mkdir "$builddir"

echo "Compile the arduino binary"

arduino --pref build.path="$builddir" --board "Arduino_STM32-master:STM32F1:genericSTM32F103C:device_variant=STM32F103C8,upload_method=serialMethod,cpu_speed=speed_72mhz,opt=o2std" --preserve-temp-files --verify "$srcdir/acsi2stm/acsi2stm.ino"

[ -e "$builddir/acsi2stm.ino.bin" ] || exit $?

cp "$builddir/acsi2stm.ino.bin" ./acsi2stm-$VERSION.ino.bin

# Clean up build

cd ..
if ! [ "$KEEP_BUILD" ]; then
  rm -r "$builddir"
fi
