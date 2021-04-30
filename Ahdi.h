/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
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

#ifndef AHDI_H
#define AHDI_H

#include "Acsi.h"
#include "SdFat.h"

// LASTERR in KEY_ASC format (see SCSI KCQ)
#define LASTERR_OK 0x0000
#define LASTERR_NOMEDIUM 0x023A
#define LASTERR_READERR 0x0311
#define LASTERR_WRITEERR 0x0303
#define LASTERR_NOSECTOR 0x0401
#define LASTERR_OPCODE 0x0520
#define LASTERR_INVADDR 0x0521
#define LASTERR_INVARG 0x0524
#define LASTERR_INVLUN 0x0525

// AHDI implementation using SD card
struct Ahdi {
  bool begin(int id, int csPin, uint32_t maxBlocks = ~0);

  // Initialize the SD card
  bool initSd();

  void processCmd(uint8_t cmd);

  enum SdFormat {
    NONE,
    RAW,
    IMAGE,
    FAT,
    EXFAT
  };

  SdFormat getSdFormat() {
    return format;
  }

  void getDeviceString(char *target);
protected:

  // Compute the checksum inside dataBuf
  int computeChecksum();

  bool readStart(uint32_t block);
  bool readData(uint8_t *data);
  bool readStop();
  bool writeStart(uint32_t block);
  bool writeData(const uint8_t *data);
  bool writeStop();

  // Read AHDI command parameters to cmdBuf
  void readCmdBuf(uint8_t cmd);

  bool processBlockRead(uint32_t block, int count);
  bool processBlockWrite(uint32_t block, int count);

  void commandSuccess();
  void commandError(int err);
  void commandError();

  // Read LUN from cmdBuf
  static int getLun();

  // Reset all state variables to default values
  // (no SD card present)
  void resetState();

  SdFormat format;
  int acsiId; // ACSI device id
  int csPin; // SD card CS pin
  int ledPin; // Activity LED pin
  uint32_t maxBlocks; // SD card size cap in raw mode
  uint32_t blocks;
  int lastErr;
  uint32_t lastBlock;
  bool lastSeek;
  bool bootable;
  SdSpiCard card;
  FsVolume fs;
  FsBaseFile image;
  static uint8_t dataBuf[ACSI_BLOCKSIZE];
  static uint8_t cmdBuf[32];
  static int cmdLen;
};

// vim: ts=2 sw=2 sts=2 et
#endif
