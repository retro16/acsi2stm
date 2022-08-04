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
#include "Devices.h"
#include "BlockDev.h"

class Acsi: public Monitor, public Devices {
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

  Acsi(SdDev &card_): card(card_) {}

  // Reset error status
  void reset();

  // Mount the SD card as a block device.
  void mountBlockDev();

  // Command processing. Pass the first command byte (without the device id).
  // This function will read all subsequent bytes as needed.
  void process(uint8_t cmd);

  // Read command bytes and updates cmdBuf and cmdLen.
  bool readCmdBuf(uint8_t cmd);

  // Return true if the LUN field is valid.
  bool validLun();

  // Return the LUN for the current command.
  int getLun();

  // Send a status and get ready for the next command.
  // Also updates lastErr with the error passed in parameter.
  void commandStatus(ScsiErr err);

  // Reopen the SD card and remount LUNs
  // Updates lastErr:
  //   ERR_MEDIUMCHANGE if the card was swapped
  //   ERR_NOMEDIUM if the card was removed
  void refresh();

  // Process block I/O requests
  ScsiErr processBlockRead(uint32_t block, int count);
  ScsiErr processBlockWrite(uint32_t block, int count);

  // Check if the SD card was potentially changed since last access
  bool hasMediaChanged();

  // Reboot the STM32
  static void reboot();

  // SCSI commands
  void modeSense0(uint8_t *outBuf);
  void modeSense4(uint8_t *outBuf);

  // Block device definition
  BlockDev *blockDev = nullptr;
  // Last media ID
  uint32_t mediaId = 0;
  // Present the device as removable
  bool removable = true;

  ImageDev image;
  SdDev &card;

  // SCSI status variables
  ScsiErr lastErr;
  bool lastSeek;
  uint32_t lastBlock;

  // Command buffer
  static int cmdLen;
  static uint8_t cmdBuf[16];
};

#endif
// vim: ts=2 sw=2 sts=2 et
