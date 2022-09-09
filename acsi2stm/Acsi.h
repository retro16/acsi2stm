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

#ifndef ACSI_H
#define ACSI_H

#include <Arduino.h>
#include <SdFat.h>
#include "acsi2stm.h"
#include "AcsiDebug.h"
#include "BlockDev.h"
#if ACSI_RTC
#include <RTClock.h>
#endif

// ACSI protocol block size
#define ACSI_BLOCKSIZE 512

class Acsi: public AcsiDebug {
public:
  // SCSI error code in ASCQ_ASC_KEY format (see SCSI KCQ)
  enum ScsiErr {
    ERR_OK = 0x000000,
    ERR_READERR = 0x001103,
    ERR_WRITEERR = 0x020303,
    ERR_WRITEPROT = 0x002707,
    ERR_OPCODE = 0x002005,
    ERR_INVADDR = 0x002105,
    ERR_INVARG = 0x002405,
    ERR_INVLUN = 0x002505,
    ERR_MEDIUMCHANGE = 0x002806,
    ERR_NOMEDIUM = 0x003a06,
  };

  Acsi(int csPin, int wpPin);
  Acsi(Acsi&&);

  // Initialize the ACSI bridge
  bool begin(int slotId, int deviceId);

  // Reset error status
  void reset();

  // Mount all LUNs on the SD card.
  void mountLuns();

  // Command processing. Pass the first command byte (without the device id).
  // This function will read all subsequent bytes as needed.
  void process(uint8_t cmd);

  // Read command bytes and updates cmdBuf and cmdLen.
  bool readCmdBuf(uint8_t cmd);

  // Return true if the current LUN is valid (mounted)
  bool validLun();

  // Return true if the given LUN is valid (mounted)
  bool validLun(int lun);

  // Return the LUN for the current command.
  int getLun();

  // Send a status and get ready for the next command.
  // Also updates lastErr with the error passed in parameter.
  void commandStatus(ScsiErr err);

  // Reopen the SD card and remount LUNs
  // Updates lastErr:
  //   ERR_MEDIUMCHANGE if the card was swapped
  //   ERR_NOMEDIUM if the card was removed
  void refresh(int lun);
  void refresh() {
    return refresh(getLun());
  }

  // Process block I/O requests
  ScsiErr processBlockRead(uint32_t block, int count, BlockDev *dev);
  ScsiErr processBlockWrite(uint32_t block, int count, BlockDev *dev);

  // Check if the SD card was potentially changed since last access
  bool hasMediaChanged();

  // Update media check time
  void mediaChecked();

  // Output a human-readable string of a block count.
  // Updates the 4 first bytes of target.
  static void blocksToString(uint32_t blocks, char *target);

  // Compute the 16 bits checksum of a block.
  static int computeChecksum(uint8_t *block);

  // Reboot the STM32
  static void reboot();

#if ACSI_DUMMY_BOOT_SECTOR && !ACSI_STRICT
  // Send the dummy boot sector to the Atari.
  ScsiErr processDummyBootSector();
#endif

#if !ACSI_STRICT && (ACSI_DUMMY_BOOT_SECTOR || ACSI_BOOT_OVERLAY)
  // Patch the sector in the buffer so it is bootable.
  // You can specify the offset to patch.
  static void patchBootSector(uint8_t *data, int offset = 438);
#endif

#if (ACSI_DUMMY_BOOT_SECTOR || ACSI_BOOT_OVERLAY) && !ACSI_STRICT
  // SD card slot number
  int slot;
#endif

#if ACSI_BOOT_OVERLAY && !ACSI_STRICT
  // Overlay the device's boot sector with a small boot program.
  ScsiErr processBootOverlay(BlockDev *dev);

  // Check if the overlay is going to be written.
  // If that's the case: fix that by restoring the old code in the boot sector
  void fixOverlayWrite(BlockDev *dev);

  // ORG of acsi2stm_boot_bin relative to the buffer
  const int bootOrg = 0x60;
#endif

  // Maximum number of LUNs
  static const int maxLun = ACSI_MAX_LUNS;

#if !ACSI_STRICT
  // Strict mode flag
  // In strict mode, boot overlays and custom commands are disabled
  static bool strict;
#endif

  // LUN array.
  BlockDev *luns[maxLun];

  // Disk image devices
  ImageDev images[maxLun];

  // SD card device
  SdDev card;
  uint32_t mediaId;
  uint32_t mediaCheckTime;
  static const uint32_t mediaCheckPeriod = 200;

#if ACSI_RTC
  static RTClock rtc;
#endif

  // SCSI status variables
  ScsiErr lastErr;
  bool lastSeek;
  uint32_t lastBlock;

  // Command buffer
  static int cmdLen;
  static uint8_t cmdBuf[16];

  // Common data buffer
  static const int bufSize = ACSI_BLOCKSIZE * ACSI_BLOCKS;
  static uint8_t buf[bufSize];
};

#endif
// vim: ts=2 sw=2 sts=2 et
