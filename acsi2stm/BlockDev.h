/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2025 by Jean-Matthieu Coulon
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

#include "acsi2stm.h"

#include "SdFat.h"
#include "Monitor.h"
#include "Devices.h"

// Block device generic interface
class BlockDev: public Monitor, public Devices {
public:
  enum MediaIdMode {
    NORMAL, // Refresh cache after some time has passed
    FORCE, // Don't use cache, don't reinit a failed drive
    CACHED, // Return the value in cache
  };

  // Read/write functions
  virtual bool readStart(uint32_t block) = 0;
  virtual bool readData(uint8_t *data, int count = 1) = 0;
  virtual bool readStop() = 0;
  virtual bool writeStart(uint32_t block) = 0;
  virtual bool writeData(const uint8_t *data, int count = 1) = 0;
  virtual bool writeStop() = 0;
  virtual bool isWritable() = 0;

  // Return a (hopefully) unique id for this media
  // Returns 0 if no device is present
  // Also serves as a device state detection and refresh
  virtual uint32_t mediaId(MediaIdMode mode = NORMAL) = 0;

  // Size in 512 bytes blocks
  uint32_t blocks;

  // Set to true if the block device is bootable by the ST
  bool bootable;

  // Update the bootable flag
  bool updateBootable();
};

// Image file on a SD card
class ImageDev: public BlockDev {
public:
  ImageDev(SdDev &sdDev);
  bool open(const char *path);
  void close();

  operator bool() const {
    return sdMediaId && image;
  }

  // BlockDev interface
  virtual bool readStart(uint32_t block);
  virtual bool readData(uint8_t *data, int count = 1);
  virtual bool readStop();
  virtual bool writeStart(uint32_t block);
  virtual bool writeData(const uint8_t *data, int count = 1);
  virtual bool writeStop();
  virtual bool isWritable();
  virtual uint32_t mediaId(MediaIdMode mode = NORMAL);

  SdDev &sd;
  FsBaseFile image;

protected:
  uint32_t sdMediaId; // SD card owning the current image
};

// Actual SD card slot
// Also stores globals about SD slots and GemDrive
class SdDev: public BlockDev {
public:
  enum Mode {
    ACSI = 0,
    GEMDRIVE,
    DISABLED
  };

  SdDev(int slot_, int csPin_, int wpPin_):
    image(*this),
    mode(ACSI),
    writable(false),
    slot(slot_),
    csPin(csPin_),
    wpPin(wpPin_) {}
  SdDev(SdDev&&);

  void init(); // Initialize

  void onReset(); // Called at Atari reset

  void getDeviceString(char *target);

  // Return the actual block device (SD card or image)
  BlockDev * operator->();
  const BlockDev * operator->() const;

  // BlockDev interface
  virtual bool readStart(uint32_t block);
  virtual bool readData(uint8_t *data, int count = 1);
  virtual bool readStop();
  virtual bool writeStart(uint32_t block);
  virtual bool writeData(const uint8_t *data, int count = 1);
  virtual bool writeStop();
  virtual bool isWritable();
  virtual uint32_t mediaId(MediaIdMode = NORMAL);

  // Permanently disable the slot
  void disable();

  // Get the actual mode
  Mode computeMode();

  SdSpiCard card;
  FsVolume fs;
  ImageDev image;

  Mode mode;

  bool writable;
#if ! ACSI_STRICT
  bool mountable;
#else
  static const bool mountable = false;
#endif
  int slot;
  int csPin;
  int wpPin;

  friend class ImageDev;
protected:
  static const uint32_t mediaCheckPeriod = 500;
  uint32_t lastMediaId;
  uint32_t lastMediaCheckTime;
  void reset();
};

#endif
