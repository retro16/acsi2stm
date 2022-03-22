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

#ifndef BLOCKDEV_H
#define BLOCKDEV_H

#include "SdFat.h"

// Block device generic interface
class BlockDev {
public:
  operator bool() {
    return blocks;
  }

  // Read/write functions
  virtual bool readStart(uint32_t block) = 0;
  virtual bool readData(uint8_t *data, int count = 1) = 0;
  virtual bool readStop() = 0;
  virtual bool writeStart(uint32_t block) = 0;
  virtual bool writeData(const uint8_t *data, int count = 1) = 0;
  virtual bool writeStop() = 0;

  // Device description
  virtual void getDeviceString(char *target) = 0;
  virtual bool isWritable() = 0;

  // Return a (hopefully) unique id for this media
  virtual uint32_t mediaId() = 0;

  // SCSI commands
  void modeSense0(uint8_t *outBuf);
  void modeSense4(uint8_t *outBuf);

  // Flags and state

  // Size in 512 bytes blocks
  uint32_t blocks;

  // Set to true if the block device is bootable by the ST
  bool bootable;

protected:
  void reset() {
    blocks = 0;
    bootable = false;
  }

  // Update the bootable flag
  void updateBootable();
};

class SdDev: public BlockDev {
public:
  SdDev(int deviceId_, int csPin_, int wpPin_):
    deviceId(deviceId_),
    csPin(csPin_),
    wpPin(wpPin_) {}
  bool begin() {
    return reset();
  }
  bool reset();

  // BlockDev interface
  virtual bool readStart(uint32_t block);
  virtual bool readData(uint8_t *data, int count = 1);
  virtual bool readStop();
  virtual bool writeStart(uint32_t block);
  virtual bool writeData(const uint8_t *data, int count = 1);
  virtual bool writeStop();
  virtual void getDeviceString(char *target);
  virtual bool isWritable();
  virtual uint32_t mediaId();

  SdSpiCard card;
  FsVolume fs;
  bool fsOpen;

  int deviceId;
  int csPin;
  int wpPin;
  bool writable;
};

class ImageDev: public BlockDev {
public:
  bool begin(SdDev *sdDev, const char *path, int lun);
  void end();

  // BlockDev interface
  virtual bool readStart(uint32_t block);
  virtual bool readData(uint8_t *data, int count = 1);
  virtual bool readStop();
  virtual bool writeStart(uint32_t block);
  virtual bool writeData(const uint8_t *data, int count = 1);
  virtual bool writeStop();
  virtual void getDeviceString(char *target);
  virtual bool isWritable();
  virtual uint32_t mediaId();

  SdDev *sd;
  FsBaseFile image;
  int lun;
};

#endif
