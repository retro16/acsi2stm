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
#include <string.h>
#include "acsi2stm.h"
#include "drvboot.h"
#include "a2stdrv.h"

int badImage() {
  printf(
      "Bad image file.\n"
      "It must be a valid MBR or TOS partitioned image less than 2GB\n"
      "with enough space before the first partition.\n"
  );
  return 3;
}

// Test if the file is a valid FAT image with enough reserved sectors.
// If it is valid, relocate and patch the driver with the filesystem
// structures.
int patchFat(FILE *f, long imgSize) {
  fseek(f, 0x0b, SEEK_SET);

  int v;

  // Check bytes per sector
  v = fgetc(f) | fgetc(f) << 8;
  if(v < 0x200 || v > 0x2000)
    return 0;
  if(v & (v - 1))
    // Not a power of 2
    return 0;

  // Sectors per cluster
  v = fgetc(f);
  if(v < 1 || v > 16)
    return 0;

  v = fgetc(f) | fgetc(f) << 8;

  if(v < (drvboot_tools_bin_len+511)/512)
    // Not enough reserved sectors
    return 0;

  // Check FAT count
  v = fgetc(f);
  if(v < 1 || v > 4)
    return 0;

  // Looks roughly like a FAT. Let's patch it.
  printf("Patching FAT filesystem\n");

  // Relocate boot code
  memmove(&drvboot_tools_bin[0x3e], drvboot_tools_bin, 438);
  
  // Patch in BRA.B to the shifted boot code
  drvboot_tools_bin[0] = 0x60;
  drvboot_tools_bin[1] = 0x3c;

  // Patch in FAT header
  fseek(f, 2, SEEK_SET);
  fread(&drvboot_tools_bin[2], 0x3e - 0x02, 1, f);

  return 1;
}

// Test if the file is a valid MBR image.
// If it is valid, patch the driver with the partition table.
// Returns 0 if failed, 1 if successful.
int patchMbr(FILE *f, long imgSize) {
  // Check MBR signature
  if(fseek(f, 510, SEEK_SET))
    return 0;
  if(fgetc(f) != 0x55)
    return 0;
  if(fgetc(f) != 0xaa)
    return 0;

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
      return 0;
    }
    if(sector && sector < (drvboot_tools_bin_len+511)/512) {
      // Starts before the space we need !
      return 0;
    }
  }

  // Patch the partition table into the drvboot payload
  printf("Patching MBR partition table\n");
  fseek(f, 440, SEEK_SET);
  fread(&drvboot_tools_bin[440], 512-440, 1, f);
  return 1;
}

// Test if the file is a valid TOS image.
// If it is valid, patch the driver with the partition table.
// Returns 0 if failed, 1 if successful.
int patchTos(FILE *f, long imgSize) {
  // Compute the checksum
  fseek(f, 0, SEEK_SET);

  // Check starting sector of all 4 partitions
  for(int i = 454; i < 454+4*12; i += 12) {
    fseek(f, i, SEEK_SET);
    if(!(fgetc(f) & 1))
      continue;
    fseek(f, i+4, SEEK_SET);
    uint32_t sector = 0;
    sector |= fgetc(f) << 24;
    sector |= fgetc(f) << 16;
    sector |= fgetc(f) << 8;
    sector |= fgetc(f);
    if(sector >= imgSize / 512) {
      // Starts outside the image !
      return 0;
    }
    if(sector && sector < (drvboot_tools_bin_len+511)/512) {
      // Starts before the space we need !
      return 0;
    }
  }

  // Patch the partition table into the drvboot payload
  printf("Patching TOS partition table\n");
  fseek(f, 440, SEEK_SET);
  fread(&drvboot_tools_bin[440], 512-440, 1, f);
  return 1;
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
  if(imgSize < (drvboot_tools_bin_len + a2stdrv_tools_bin_len + 511) / 512) {
    // The file is too small to contain the driver !
    return badImage();
  }

  int allocszOffset = 0;
  int checksumOffset = 0;

  // Try patching all possible formats
  if(patchFat(f, imgSize)) {
    allocszOffset = 434+0x3e;
    checksumOffset = 438+0x3e;
  } else if(patchMbr(f, imgSize)) {
    allocszOffset = 434;
    checksumOffset = 438;
  } else if(patchTos(f, imgSize)) {
    allocszOffset = 434;
    checksumOffset = 510;
  } else
    return badImage();

  // Patch malloc size and sector count
  drvboot_tools_bin[allocszOffset] = a2stdrv_tools_bin[4];
  drvboot_tools_bin[allocszOffset+1] = a2stdrv_tools_bin[5];
  drvboot_tools_bin[allocszOffset+2] = a2stdrv_tools_bin[6];
  drvboot_tools_bin[allocszOffset+3] = a2stdrv_tools_bin[7];

  // Patch the checksum to make the drive bootable
  drvboot_tools_bin[checksumOffset] = 0;
  drvboot_tools_bin[checksumOffset + 1] = 0;
  uint16_t sum = 0;
  for(int i = 0; i < 512; i += 2) {
    sum += ((uint16_t)drvboot_tools_bin[i] << 8) | drvboot_tools_bin[i+1];
  }
  sum = 0x1234 - sum;
  drvboot_tools_bin[checksumOffset] = (uint8_t)(sum >> 8);
  drvboot_tools_bin[checksumOffset + 1] = (uint8_t)sum;

  // Write the boot sector
 
  fseek(f, 0, SEEK_SET);
  if(!fwrite(drvboot_tools_bin, 1, drvboot_tools_bin_len, f)) {
    printf("Write error !\n");
    fclose(f);
    return 1;
  }

  // Write the driver
  fwrite(a2stdrv_tools_bin, 1, a2stdrv_tools_bin_len, f);

  fclose(f);

  return 0;
}

// vim: ts=2 sw=2 sts=2 et
