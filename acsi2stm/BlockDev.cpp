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

#include <Arduino.h>
#include "BlockDev.h"
#include "SdFat.h"
#include "Acsi.h"

static const uint32_t sdRates[] = {
  SD_SCK_MHZ(ACSI_SD_MAX_SPEED),
#if ACSI_SD_MAX_SPEED > 36
  SD_SCK_MHZ(36),
#endif
#if ACSI_SD_MAX_SPEED > 25
  SD_SCK_MHZ(25),
#endif
#if ACSI_SD_MAX_SPEED > 16
  SD_SCK_MHZ(16),
#endif
#if ACSI_SD_MAX_SPEED > 12
  SD_SCK_MHZ(12),
#endif
  SD_SCK_MHZ(1) // Fallback to a horribly slow speed
};

void BlockDev::modeSense0(uint8_t *outBuf) {
  for(uint8_t b = 0; b < 16; ++b) {
    outBuf[b] = 0;
  }
  // Values got from the Hatari emulator
  outBuf[1] = 14;
  outBuf[3] = 8;
  // Send the number of blocks of the SD card
  outBuf[5] = (blocks >> 16) & 0xFF;
  outBuf[6] = (blocks >> 8) & 0xFF;
  outBuf[7] = (blocks) & 0xFF;
  // Sector size middle byte
  outBuf[10] = 2;
}

void BlockDev::modeSense4(uint8_t *outBuf) {
  for(uint8_t b = 0; b < 24; ++b) {
    outBuf[b] = 0;
  }
  // Values got from the Hatari emulator
  outBuf[0] = 4;
  outBuf[1] = 22;
  // Send the number of blocks in CHS format
  outBuf[2] = (blocks >> 23) & 0xFF;
  outBuf[3] = (blocks >> 15) & 0xFF;
  outBuf[4] = (blocks >> 7) & 0xFF;
  // Hardcode 128 heads
  outBuf[5] = 128;
}

void BlockDev::updateBootable() {
  bootable = false;

  if(!readStart(0) || !readData(Acsi::buf, 1) || !readStop())
    return;

  bootable = (Acsi::computeChecksum(Acsi::buf) == 0x1234);
}

bool SdDev::reset() {
  BlockDev::reset();

  // Set wp pin as input pullup to read write lock later
  pinMode(wpPin, INPUT_PULLUP);

  int rate;

  for(rate = 0; rate < sizeof(sdRates)/sizeof(sdRates[0]); ++rate) {
    Watchdog::feed();

    if(!card.begin(SdSpiConfig(csPin, SHARED_SPI, sdRates[rate], &SPI)))
      // Don't retry at slower speed because begin()
      // already works at low speed.
      break;

    // Give some time to the internal SD electronics to initialize properly
    // Not sure if this is required. Pretty sure it's not.
    delay(100);

    // Get SD card identification to test communication
    cid_t cid;
    if(!card.readCID(&cid)) {
      Acsi::verbose("CID error (", sdRates[rate] / 1000000, "MHz) ");
      continue;
    }

    // Get SD card size
    blocks = card.sectorCount();

    // If blocks is non-null, assume that the SD card is working well
    if(blocks)
      break;
  }

#if ACSI_MAX_BLOCKS
  if(blocks > ACSI_MAX_BLOCKS)
    blocks = ACSI_MAX_BLOCKS;
#endif

  if(blocks) {
    // Open the file system
    fsOpen = fs.begin(&card);
    if(fsOpen)
      Acsi::verbose("(fs ok) ");

    // Get writable pin status
#if !ACSI_SD_WRITE_LOCK
    writable = true;
#elif ACSI_SD_WRITE_LOCK == 1
    writable = digitalRead(wpPin);
#elif ACSI_SD_WRITE_LOCK == 2
    writable = !digitalRead(wpPin);
#endif
    Acsi::verbose(writable ? "(rw) ": "(ro) ");

    // Check if bootable
    updateBootable();
    if(bootable)
      Acsi::verbose("(boot) ");

    Acsi::dbg('(', sdRates[rate] / 1000000, "MHz ", blocks, " blocks) ");
  } else {
    Acsi::verbose("(0 block) ");
  }

  return blocks;
}

bool SdDev::readStart(uint32_t block) {
  return card.readStart(block);
}

bool SdDev::readData(uint8_t *data, int count) {
  while(count-- > 0) {
    if(!card.readData(data))
      return false;
    data += ACSI_BLOCKSIZE;
  }

  return true;
}

bool SdDev::readStop() {
  return card.readStop();
}

bool SdDev::writeStart(uint32_t block) {
#if ACSI_READONLY
#if ACSI_READONLY == 2
  return true;
#else
  return false;
#endif
#else
  if(!writable)
    return false;
  return card.writeStart(block);
#endif
}

bool SdDev::writeData(const uint8_t *data, int count) {
#if ACSI_READONLY
#if ACSI_READONLY == 2
  return true;
#else
  return false;
#endif
#else
  if(!writable)
    return false;
  while(count-- > 0) {
    if(!card.writeData(data))
      return false;
    data += ACSI_BLOCKSIZE;
  }

  return true;
#endif
}

bool SdDev::writeStop() {
#if ACSI_READONLY
#if ACSI_READONLY == 2
  return true;
#else
  return false;
#endif
#else
  if(!writable)
    return false;
  return card.writeStop();
#endif
}

void SdDev::getDeviceString(char *target) {
  // Characters:  0         1         2
  //              012345678901234567890123
  memcpy(target, "ACSI2STM SD? RAW ???M   " ACSI2STM_VERSION, 29);

  // Update sd card number
  target[11] = '0' + deviceId;

  if(!blocks) {
    memcpy(&target[13], "NO SD CARD", 10);
    return;
  }

  if(fsOpen) {
    if(fs.fatType() == FAT_TYPE_FAT16)
      memcpy(&target[13], "F16", 3);
    else if(fs.fatType() == FAT_TYPE_FAT32)
      memcpy(&target[13], "F32", 3);
    else if(fs.fatType() == FAT_TYPE_EXFAT)
      memcpy(&target[13], "EXF", 3);
  }
 
  // Write SD card size
  Acsi::blocksToString(blocks, &target[17]);
 
  // Add a + symbol if capacity is artificially capped
  if(card.sectorCount() > blocks)
    target[21] = '+';

  // Add 'R' if read-only
  if(!writable)
      target[22] = 'R';

  // Add 'B' if the device is bootable
  if(bootable)
    target[23] = 'B';
}

bool SdDev::isWritable() {
  return writable;
}

uint32_t SdDev::mediaId() {
  if(!blocks)
    return 0;

  cid_t cid;
  if(!card.readCID(&cid))
    return 0;

  uint32_t id = 0;
  for(int i = 0; i < sizeof(cid) / 4; ++i)
    id ^= ((const uint32_t*)&cid)[i];

  return id;
}

bool ImageDev::begin(SdDev *sdDev, const char *path, int imageLun) {
  if(!sdDev->fsOpen) {
    blocks = 0;
    sd = nullptr;
    return false;
  }
  sd = sdDev;
  Acsi::verbose("Searching image ", path, " ... ");
#if ! ACSI_READONLY
  if(sd->isWritable() && image.open(&sd->fs, path, O_RDWR)) {
    blocks = image.fileSize() / ACSI_BLOCKSIZE;
    lun = imageLun;
    updateBootable();
    Acsi::verbose("opened\n");
    return true;
  }
#endif
  if(image.open(&sd->fs, path, O_RDONLY)) {
    blocks = image.fileSize() / ACSI_BLOCKSIZE;
    lun = imageLun;
    updateBootable();
    Acsi::verbose("opened read-only\n");
    return true;
  }

  sd = nullptr;
  blocks = 0;
  Acsi::verbose("not found\n");
  return false;
}

void ImageDev::end() {
  sd = nullptr;
  image.close();
}

bool ImageDev::readStart(uint32_t block) {
  return image.seekSet((uint64_t)block * ACSI_BLOCKSIZE);
}

bool ImageDev::readData(uint8_t *data, int count) {
  return image.read(data, ACSI_BLOCKSIZE * count);
}

bool ImageDev::readStop() {
  return true;
}

bool ImageDev::writeStart(uint32_t block) {
#if ACSI_READONLY
#if ACSI_READONLY == 2
  return true;
#else
  return false;
#endif
#else
  if(image.isWritable())
    return image.seekSet((uint64_t)block * ACSI_BLOCKSIZE);
  else
    return false;
#endif
}

bool ImageDev::writeData(const uint8_t *data, int count) {
#if ACSI_READONLY
#if ACSI_READONLY == 2
  return true;
#else
  return false;
#endif
#else
  if(image.isWritable())
    return image.write(data, ACSI_BLOCKSIZE * count);
  else
    return false;
#endif
}

bool ImageDev::writeStop() {
#if ACSI_READONLY
#if ACSI_READONLY == 2
  return true;
#else
  return false;
#endif
#else
  image.flush();
  return true;
#endif
}

void ImageDev::getDeviceString(char *target) {
  if(!sd) {
    // Characters:  0         1         2
    //              012345678901234567890123
    memcpy(target, "ACSI2STM *INVALID IMAGE*" ACSI2STM_VERSION, 29);
  }

  sd->getDeviceString(target);

  // Clear overflow, read-only and bootable flag
  memcpy(&target[21], "   ", 3);

  // Set image type
  memcpy(&target[13], "IM", 2);

  // Set image index
  target[15] = '0' + lun;
 
  // Write image size
  Acsi::blocksToString(blocks, &target[17]);

  // Add 'R' if read-only
  if(!image.isWritable())
    target[22] = 'R';

  // Add 'B' if the device is bootable
  if(bootable)
    target[23] = 'B';
}

bool ImageDev::isWritable() {
  if(!sd)
    return false;

  return image.isWritable();
}

uint32_t ImageDev::mediaId() {
  if(!sd)
    return 0;

  // For now, images cannot be switched on the fly so they cannot change
  // unless the SD card is physically swapped.
  return sd->mediaId();
}

