/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2022 by Jean-Matthieu Coulon
 *
 * This Library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This Library is distributed in the hope that it will be useful,
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
#include "acsi2stm.h"
#include "AcsiDebug.h"
#include "Watchdog.h"
#include "DmaPort.h"
#include "SdFat.h"
#include "BlockDev.h"

class Acsi: public AcsiDebug {
public:
  // SCSI error code in KEY_ASC format (see SCSI KCQ)
  enum ScsiErr {
    ERR_OK = 0x0000,
    ERR_NOMEDIUM = 0x023A,
    ERR_READERR = 0x0311,
    ERR_WRITEERR = 0x0303,
    ERR_WRITEPROT = 0x0727,
    ERR_NOSECTOR = 0x0401,
    ERR_OPCODE = 0x0520,
    ERR_INVADDR = 0x0521,
    ERR_INVARG = 0x0524,
    ERR_INVLUN = 0x0525,
    ERR_MEDIACHANGE = 0x0600,
  };

  Acsi(int deviceId, int csPin, int wpPin, DmaPort&, Watchdog&);
  Acsi(Acsi&&);

  // Initialize the ACSI bridge
  void begin();

  // Mount all LUN images on the SD card.
  void mountImages();

  // Command processing. Pass the first command byte (without the device id).
  // This function will read all subsequent bytes as needed.
  // Returns true if any command was processed.
  void process(uint8_t cmd);

  // Process the command in the command buffer.
  void processCmdBuf();

  // Read command bytes and updates cmdBuf and cmdLen.
  bool readCmdBuf(uint8_t cmd);

  // Return true if the current LUN is valid (mounted)
  bool validLun();

  // Return true if the given LUN is valid (mounted)
  bool validLun(int lun);

  // Return the LUN for the current command.
  int getLun();

  // Send a success status and get ready for the next command.
  // Also updates lastErr.
  void commandSuccess();

  // Send an error status and get ready for the next command.
  // Also updates lastErr with the error passed in parameter.
  void commandError(ScsiErr err);

  // Process block I/O requests
  bool processBlockRead(uint32_t block, int count, BlockDev *dev);
  bool processBlockWrite(uint32_t block, int count, BlockDev *dev);

  // Output a human-readable string of a block count.
  // Updates the 4 first bytes of target.
  static void blocksToString(uint32_t blocks, char *target);

  // Maximum number of LUNs
  static const int maxLun = ACSI_MAX_LUNS;

  // Dependent devices
  DmaPort &dma;
  Watchdog &watchdog;

  // Device ID on the ACSI bus
  int deviceId;

  // LUN array.
  BlockDev *luns[maxLun];

  // Disk image devices
  ImageDev images[maxLun];

  // SD card device
  int sdCs;
  int sdWp;
  SdDev card;

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
