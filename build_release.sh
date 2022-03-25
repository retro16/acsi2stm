#!/bin/sh
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

./build_asm.sh || exit $?

echo "Patch the source to set VERSION to $VERSION"

sed -i 's/^\(#define ACSI2STM_VERSION\).*/\1 "'$VERSION'"/' acsi2stm/acsi2stm.h

echo "Create a clean build directory"

rm -rf build acsi2stm-*
mkdir build
mkdir "acsi2stm-$VERSION"

cd build

echo "Compile the arduino binary"

arduino --pref build.path=./ --preserve-temp-files --verify ../acsi2stm/acsi2stm.ino

[ -e acsi2stm.ino.bin ] || exit $?

echo "Copy the binary in the release directory"

cp acsi2stm.ino.bin "../acsi2stm-$VERSION"

echo "Copy TOS programs in the release directory"

cp -r ../tos "../acsi2stm-$VERSION"

echo "Generate empty images"

dd if=/dev/zero of=hd0_30m.img bs=1M count=30
dd if=/dev/zero of=hd0_500m.img bs=1M count=500

zip "../acsi2stm-$VERSION/empty_images.zip" hd0_30m.img hd0_500m.img

echo "Copy documentation"

cat ../README.md >> "../acsi2stm-$VERSION/README.md"
cp -r ../doc "../acsi2stm-$VERSION"

echo "... and the legal stuff"

cat > "../acsi2stm-$VERSION/README.txt" << EOF
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

cp ../LICENSE "../acsi2stm-$VERSION"

echo "Create release zip package"

cd ..
zip -r "acsi2stm-$VERSION.zip" "acsi2stm-$VERSION"

echo "Clean up build directories ..."

rm -rf build "acsi2stm-$VERSION"
