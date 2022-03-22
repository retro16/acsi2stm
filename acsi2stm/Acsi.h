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
#include "Watchdog.h"
#include "DmaPort.h"
#include "BlockDev.h"
#if ACSI_RTC
#include <RTClock.h>
#endif

// ACSI protocol block size
#define ACSI_BLOCKSIZE 512

class Acsi: public AcsiDebug {
public:
  // SCSI error code in KEY_ASCQ_ASC format (see SCSI KCQ)
  enum ScsiErr {
    ERR_OK = 0x000000,
    ERR_READERR = 0x030011,
    ERR_WRITEERR = 0x030203,
    ERR_WRITEPROT = 0x070027,
    ERR_OPCODE = 0x050020,
    ERR_INVADDR = 0x050021,
    ERR_INVARG = 0x050024,
    ERR_INVLUN = 0x050025,
    ERR_MEDIUMCHANGE = 0x060028,
    ERR_NOMEDIUM = 0x06003a,
  };

  Acsi(int deviceId, int csPin, int wpPin, DmaPort&);
  Acsi(Acsi&&);

  // Initialize the ACSI bridge
  void begin();

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
  // Returns:
  //   ERR_OK if the device is operational
  //   ERR_MEDIUMCHANGE if the card was swapped
  //   ERR_NOMEDIUM if the card was removed
  ScsiErr refresh();

  // Process block I/O requests
  ScsiErr processBlockRead(uint32_t block, int count, BlockDev *dev);
  ScsiErr processBlockWrite(uint32_t block, int count, BlockDev *dev);

  // Check if the SD card was changed since last access
  bool hasMediaChanged();

  // Update media check time
  void mediaChecked();

  // Output a human-readable string of a block count.
  // Updates the 4 first bytes of target.
  static void blocksToString(uint32_t blocks, char *target);

  // Compute the 16 bits checksum of a block.
  static int computeChecksum(uint8_t *block);

#if ACSI_DUMMY_BOOT_SECTOR
  // Send the dummy boot sector to the Atari.
  ScsiErr processDummyBootSector();

  // Patch the sector in the buffer so it is bootable.
  // You can specify the offset to patch.
  static void patchBootSector(uint8_t *data, int offset = 438);
#endif

#if ACSI_BOOT_OVERLAY
  // Overlay the device's boot sector with a small boot program.
  ScsiErr processBootOverlay(BlockDev *dev);
#endif

  // Maximum number of LUNs
  static const int maxLun = ACSI_MAX_LUNS;

  // Strict mode flag
  // In strict mode, boot overlays and custom commands are disabled
  static bool strict;

  // Dependent devices
  DmaPort &dma;

  // LUN array.
  BlockDev *luns[maxLun];

  // Disk image devices
  ImageDev images[maxLun];

  // SD card device
  SdDev card;
  uint32_t mediaId;
  uint32_t mediaCheckTime;
  static const uint32_t mediaCheckPeriod = 2000;

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
