#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    arduino
#    zip

if ! [ -e acsi2stm/acsi2stm.ino ]; then
  echo "Please run this script from the root directory of the project"
  exit 1
fi

VERSION=`cat VERSION`
builddir="$PWD/build.arduino~"

echo "Patch the arduino source to set VERSION to $VERSION"

sed -i 's/^\(#define ACSI2STM_VERSION\).*/\1 "'$VERSION'"/' acsi2stm/acsi2stm.h

echo "Create a clean build directory"

rm -rf "$builddir"
mkdir "$builddir"
cd "$builddir"

echo "Compile the arduino binary"

arduino --pref build.path=./ --preserve-temp-files --verify ../acsi2stm/acsi2stm.ino

[ -e acsi2stm.ino.bin ] || exit $?

cp acsi2stm.ino.bin ../acsi2stm-$VERSION.ino.bin

# Clean up build

cd ..
if ! [ "$KEEP_BUILD" ]; then
  rm -r "$builddir"
fi
