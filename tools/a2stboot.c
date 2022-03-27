/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2022 by Jean-Matthieu Coulon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Utility to patch the driver boot sector into a MBR partitioned image.

#include <stdio.h>
#include <stdint.h>
#include "acsi2stm.h"
#include "drvboot.h"

int badImage() {
  printf(
      "Bad image file.\n"
      "It must be a valid MBR partitioned image less than 2GB\n"
      "with enough space before the first partition.\n"
  );
  return 3;
}

int main(int argc, char **argv) {
  printf(ACSI2STM_HEADER "\n");

  if(argc != 2) {
    printf("usage: a2stboot HDIMAGE\n");
    printf("Patches an Atari ST hard disk partition (HDIMAGE) with the ACSI2STM driver.\n");
    return 1;
  }

  FILE *f = fopen(argv[1], "r+b");
  if(!f) {
    printf("Error: Cannot open file\n");
    return 2;
  }

  // Sanity checks

  // Read image size
  long imgSize;
  fseek(f, 0, SEEK_END);
  imgSize = ftell(f);

  // Check partition size
  if(imgSize < (drvboot_tools_bin_len+511)/512) {
    // The file is too small to contain the driver !
    return badImage();
  }

  // Check MBR signature
  if(fseek(f, 510, SEEK_SET))
    return badImage();
  if(fgetc(f) != 0x55)
    return badImage();
  if(fgetc(f) != 0xaa)
    return badImage();

  // Check starting sector of all 4 partitions
  for(int i = 454; i < 454+4*16; i += 16) {
    fseek(f, i, SEEK_SET);
    uint32_t sector = 0;
    sector |= fgetc(f);
    sector |= fgetc(f) << 8;
    sector |= fgetc(f) << 16;
    sector |= fgetc(f) << 24;
    if(sector >= imgSize / 512) {
      // Starts outside the image !
      return badImage();
    }
    if(sector && sector < (drvboot_tools_bin_len+511)/512) {
      // Starts before the space we need !
      return badImage();
    }
  }

  // Patch the partition table into the drvboot payload
  fseek(f, 440, SEEK_SET);
  fread(&drvboot_tools_bin[440], 512-440, 1, f);

  // Patch the checksum to make it bootable
  drvboot_tools_bin[438] = 0;
  drvboot_tools_bin[439] = 0;
  uint16_t sum = 0;
  for(int i = 0; i < 512; i += 2) {
    sum += ((uint16_t)drvboot_tools_bin[i] << 8) | drvboot_tools_bin[i+1];
  }
  sum = 0x1234 - sum;
  drvboot_tools_bin[438] = (uint8_t)(sum >> 8);
  drvboot_tools_bin[439] = (uint8_t)sum;

  fseek(f, 0, SEEK_SET);
  fwrite(drvboot_tools_bin, drvboot_tools_bin_len, 1, f);

  fclose(f);

  return 0;
}

// vim: ts=2 sw=2 sts=2 et
