#!/bin/bash

# Run by build_release.sh, not meant to be run by itself

srcdir="$(readlink -fs "$(dirname "$0")")"
VERSION=`cat "$srcdir/VERSION"`
size=8 # hd0 image size

injectfiles() {
  # Format the image
  mformat -i "$img" ::

  # Create the AUTO directory structure
  mmd -i "$img" ::/AUTO
  mcopy -i "$img" tools/GEMDRIVE.PRG ::/AUTO/GEMDRIVE.PRG
  mcopy -i "$img" tools/GEMDRPIO.PRG ::/AUTO/GEMDRPIO.PRG

  # Copy tools
  mcopy -i "$img" "$srcdir/VERSION" ::
  mcopy -i "$img" README.TXT COPYRGHT.TXT tools/*.PRG tools/*.TOS ::
  mmd -i "$img" ::FIRMWARE
  mmove -i "$img" ::HDDFLASH.TOS ::FIRMWARE/HDDFLASH.TOS
  mmove -i "$img" ::PIOFLASH.TOS ::FIRMWARE/PIOFLASH.TOS

  # Copy firmware images
  mcopy -i "$img" firmware/acsi2stm-$VERSION.ino.bin ::FIRMWARE/HDDFLASH.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION.ino.bin ::FIRMWARE/ACSI2STM.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-debug.ino.bin ::FIRMWARE/DEBUG.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-verbose.ino.bin ::FIRMWARE/VERBOSE.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-strict.ino.bin ::FIRMWARE/STRICT.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-strictverbose.ino.bin ::FIRMWARE/STRICTVB.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-pio.ino.bin ::FIRMWARE/PIO.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-pio.ino.bin ::FIRMWARE/PIOFLASH.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-piodebug.ino.bin ::FIRMWARE/PIODEBUG.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-pioverbose.ino.bin ::FIRMWARE/PIOVERBO.BIN
  mcopy -i "$img" firmware/acsi2stm-$VERSION-legacy.ino.bin ::FIRMWARE/LEGACY.BIN
}

# Legal stuff
unix2dos > "COPYRGHT.TXT" << EOF
ACSI2STM v$VERSION Atari hard drive emulator
Copyright (C) 2019-2024
by Jean-Matthieu Coulon

This program is free software: you can
redistribute it and/or modify it under
the terms of the GNU General Public
License as published by the Free
Software Foundation, either version 3 of
the License, or (at your option) any
later version.

This program is distributed in the hope
that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the
GNU General Public License along with
this program.  If not, see
<https://www.gnu.org/licenses/>.

For source code, documentation and more
information about this software, see its
GitHub page:

    https://github.com/retro16/acsi2stm
EOF

echo "Build Atari floppy image"

img="images/acsi2stm-$VERSION-floppy.st"

# Create the floppy README.TXT
unix2dos > "README.TXT" << EOF
ACSI2STM v$VERSION Atari hard drive emulator
https://github.com/retro16/acsi2stm

This floppy disk image contains all
tools for ACSI2STM ready to use on an
Atari ST.

It is shipped in *.ST format, so you can
transfer it to a standard 720k DD floppy
formatted for Atari, using any disk
image tool.

It can also be used as-is with a floppy
drive emulator.
EOF

# Create a blank floppy disk image
dd if=/dev/zero of="$img" bs=1k count=720

# Add release files to the floppy image
injectfiles

echo "Build Atari hard disk image"

img="images/acsi2stm-$VERSION-hd0.img"

# Create the hard drive image README.TXT
unix2dos > "README.TXT" << EOF
ACSI2STM v$VERSION Atari hard drive emulator
https://github.com/retro16/acsi2stm

This hard drive image is meant to be
used as a boot disk for EmuTOS.

Rename this image "hd0.img" and put it
into a folder named "acsi2stm" into a
normally formatted SD card.

Boot EmuTOS with this image on a SD card
and it will load GemDrive automatically
at boot.
EOF

# Create a blank image
dd if=/dev/zero of="$img" bs=1M count=$size

# Add release files to the hard drive image
injectfiles
