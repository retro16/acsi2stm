#!/bin/bash
# This script is a "Works on my computer" script.
# You may have to study and adapt it to run on your computer.
#
#  Commands needed in your path
#
#    sed
#    arduino-cli
#    zip

builddir="$PWD/build.arduino~"
srcdir="$(dirname "$0")"
VERSION=`cat "$srcdir/VERSION"`

echo "Patch the arduino source to set ACSI2STM_VERSION to $VERSION"

sed -i 's/^\(#define ACSI2STM_VERSION\).*/\1 "'$VERSION'"/' "$srcdir/acsi2stm/acsi2stm.h"

echo "Create a clean build directory"

rm -rf "$builddir"
mkdir "$builddir"

set -e

(

compile_arduino() {

local name="$1"; shift
local device=STM32F103C8
local optim=s

arduino-cli compile --build-path "$builddir/Arduino-$name/build" --fqbn "Arduino_STM32:STM32F1:genericSTM32F103C:device_variant=$device,upload_method=serialMethod,cpu_speed=speed_72mhz,opt=o${optim}std" --output-dir "$builddir/Arduino-$name" "$srcdir/acsi2stm/acsi2stm.ino"

[ -e "$builddir/Arduino-$name/acsi2stm.ino.bin" ]

}

if [ "$1" = all ]; then
  # Backup original header
  cp "$srcdir/acsi2stm/acsi2stm.h" "$builddir/acsi2stm.h"
  trap "mv '$builddir/acsi2stm.h' '$srcdir/acsi2stm/acsi2stm.h'" EXIT

  echo
  echo "Compile verbose binary"
  sed -i 's/^#define ACSI_VERBOSE .$/#define ACSI_VERBOSE 1/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_DEBUG .$/#define ACSI_DEBUG 1/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino verbose
  mv "$builddir/Arduino-verbose/acsi2stm.ino.bin" ./acsi2stm-$VERSION-verbose.ino.bin

  echo
  echo "Compile strict verbose binary"
  sed -i 's/^#define ACSI_STRICT .$/#define ACSI_STRICT 1/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino strictverbose
  cp "$builddir/Arduino-strictverbose/acsi2stm.ino.bin" ./acsi2stm-$VERSION-strictverbose.ino.bin

  echo
  echo "Compile pio verbose binary"
  sed -i 's/^#define ACSI_STRICT .$/#define ACSI_STRICT 0/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_PIO .$/#define ACSI_PIO 1/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino pioverbose
  cp "$builddir/Arduino-pioverbose/acsi2stm.ino.bin" ./acsi2stm-$VERSION-pioverbose.ino.bin

  echo
  echo "Compile pio debug binary"
  sed -i 's/^#define ACSI_VERBOSE .$/#define ACSI_VERBOSE 0/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino piodebug
  mv "$builddir/Arduino-piodebug/acsi2stm.ino.bin" ./acsi2stm-$VERSION-piodebug.ino.bin

  echo
  echo "Compile debug binary"
  sed -i 's/^#define ACSI_PIO .$/#define ACSI_PIO 0/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_VERBOSE .$/#define ACSI_VERBOSE 0/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino debug
  mv "$builddir/Arduino-debug/acsi2stm.ino.bin" ./acsi2stm-$VERSION-debug.ino.bin

  echo
  echo "Compile release binary"
  sed -i 's/^#define ACSI_DEBUG .$/#define ACSI_DEBUG 0/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino release
  cp "$builddir/Arduino-release/acsi2stm.ino.bin" ./acsi2stm-$VERSION.ino.bin

  echo
  echo "Compile pio release binary"
  sed -i 's/^#define ACSI_PIO .$/#define ACSI_PIO 1/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_DEBUG .$/#define ACSI_DEBUG 0/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino pio
  cp "$builddir/Arduino-pio/acsi2stm.ino.bin" ./acsi2stm-$VERSION-pio.ino.bin

  echo
  echo "Compile strict mode binary"
  sed -i 's/^#define ACSI_PIO .$/#define ACSI_PIO 0/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_STRICT .$/#define ACSI_STRICT 1/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino strict
  cp "$builddir/Arduino-strict/acsi2stm.ino.bin" ./acsi2stm-$VERSION-strict.ino.bin

  echo
  echo "Compile binary for legacy hardware"
  sed -i 's/^#define ACSI_STRICT .$/#define ACSI_STRICT 0/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_HAS_RESET .$/#define ACSI_HAS_RESET 0/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_SD_WRITE_LOCK .$/#define ACSI_SD_WRITE_LOCK 0/' "$srcdir/acsi2stm/acsi2stm.h"
  sed -i 's/^#define ACSI_FAST_DMA .$/#define ACSI_FAST_DMA 1/' "$srcdir/acsi2stm/acsi2stm.h"
  compile_arduino legacy
  cp "$builddir/Arduino-legacy/acsi2stm.ino.bin" ./acsi2stm-$VERSION-legacy.ino.bin

  # Restore original header
  mv "$builddir/acsi2stm.h" "$srcdir/acsi2stm/acsi2stm.h"
  trap "" EXIT
else
  echo "Compile binary with current settings"
  compile_arduino current "$@"
  cp "$builddir/Arduino-current/acsi2stm.ino.bin" ./acsi2stm-$VERSION.ino.bin
fi

)

# Clean up build

if ! [ "$KEEP_BUILD" ]; then
  echo
  echo "Cleaning up build directory"
  rm -r "$builddir"
fi
