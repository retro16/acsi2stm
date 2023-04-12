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

bool BlockDev::updateBootable() {
  bootable = false;

  // Read the boot sector
  if(!readStart(0) || !readData(buf, 1) || !readStop())
    return false;

  bootable = (computeChecksum(buf) == 0x1234);

  return true;
}

BlockDev * SdDev::operator->() {
  if(image)
    return &image;
  return this;
}

const BlockDev * SdDev::operator->() const {
  if(image)
    return &image;
  return this;
}

void SdDev::reset() {
  // Reset internal state
  lastMediaId = 0;
  lastMediaCheckTime = millis() - mediaCheckPeriod;
  image.close();
  fs.end();
  blocks = 0;
  writable = false;
  bootable = false;

  acsiDeviceMask &= ~(1 << slot);
#if ! ACSI_STRICT
  gemDriveMask &= ~(1 << slot);
  updateGemBootDrive();
#endif
}

void SdDev::onReset() {
  // Check if the device is disabled (wpPin pin to VCC)
  pinMode(wpPin, INPUT_PULLDOWN);
  delayMicroseconds(10);
  if(digitalRead(wpPin)) {
    // wpPin pin to VCC: unit disabled
    pinMode(wpPin, INPUT_PULLUP);
    disable();
  }

  init();

#if ! ACSI_STRICT
  if(image)
    mode = ACSI; // Images are ACSI
  else if(bootable)
    mode = ACSI; // Anything bootable by the Atari is ACSI
  else if(fs.fatType())
    mode = GEMDRIVE; // Non-bootable, mountable filesystem: use GemDrive
  else if(!lastMediaId)
    mode = GEMDRIVE; // 
  else
    mode = ACSI;

  if(mode == ACSI)
    acsiDeviceMask |= (1 << slot);
#if ! ACSI_STRICT
  if(mode == GEMDRIVE) {
    gemDriveMask |= (1 << slot);
    updateGemBootDrive();
  }
#endif
#else
  mode = ACSI;
#endif
}

void SdDev::init() {
  reset();

  // Set wp pin as input pullup to read write lock later
  pinMode(wpPin, INPUT_PULLUP);

  unsigned int rate;
  for(rate = 0; rate < sizeof(sdRates)/sizeof(sdRates[0]); ++rate) {
    if(!card.begin(SdSpiConfig(csPin, SHARED_SPI, sdRates[rate], &SPI)))
      // Don't retry at slower speed because begin()
      // already works at low speed.
      break;

    // Give some time to the internal SD electronics to initialize properly
    // Not sure if this is required. Pretty sure it's not.
    delay(10);

    // Get SD card identification to test communication
    cid_t cid;
    if(!card.readCID(&cid)) {
      verbose("CID error (", sdRates[rate] / SD_SCK_MHZ(1), "MHz) ");
      continue;
    }

    // Get SD card size
    blocks = card.sectorCount();

#if ACSI_MAX_BLOCKS
    if(blocks > ACSI_MAX_BLOCKS)
      blocks = ACSI_MAX_BLOCKS;
#endif

    if(blocks) {
      // Open the file system
      if(fs.begin(&card))
        image.open(ACSI_IMAGE_FILE);

      // Get writable pin status
#if !ACSI_SD_WRITE_LOCK
      writable = true;
#elif ACSI_SD_WRITE_LOCK == 1
      writable = digitalRead(wpPin);
#elif ACSI_SD_WRITE_LOCK == 2
      writable = !digitalRead(wpPin);
#endif

      // Check if bootable
      if(!updateBootable()) {
        verbose("Read error (", sdRates[rate] / SD_SCK_MHZ(1), "MHz) ");
        continue;
      }

      dbg('(', sdRates[rate] / 1000000, "MHz ", blocks, " blocks ", writable ? "rw":"ro");
      if(bootable)
        dbg(" boot");
      else if(fs.fatType())
        dbg(" mountable");
      dbg(')');

      mediaId(true);

      break;
    }
  }

  if(!lastMediaId) {
    reset();
    verbose("no sd card\n");
  }
}


bool SdDev::readStart(uint32_t block) {
  if(!mediaId())
    return false;
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
  //              012345678901234567890123  4567
  memcpy(target, "ACSI2STM SD0 RAW ???M   " ACSI2STM_VERSION, 29);

  // Update sd card number
  target[11] += slot;

  if(!mediaId(true)) {
    memcpy(&target[13], "NO SD CARD", 10);
    return;
  }

#if ! ACSI_STRICT
  if(mode == GEMDRIVE) {
    if(fs.fatType() == FAT_TYPE_FAT16)
      memcpy(&target[13], "F16", 3);
    else if(fs.fatType() == FAT_TYPE_FAT32)
      memcpy(&target[13], "F32", 3);
    else if(fs.fatType() == FAT_TYPE_EXFAT)
      memcpy(&target[13], "EXF", 3);
  } else
#endif
  if(image) {
    memcpy(&target[13], "IMG", 3);
  }
 
  // Write SD card size
  blocksToString((*this)->blocks, &target[17]);
 
  // Add a + symbol if capacity is artificially capped
  if(!image && card.sectorCount() > blocks)
    target[21] = '+';

  // Add 'R' if read-only
  if(!(*this)->isWritable())
      target[22] = 'R';

  // Add 'B' if the device is bootable
  if((*this)->bootable)
    target[23] = 'B';
}

bool SdDev::isWritable() {
  return writable;
}

uint32_t SdDev::mediaId(bool force) {
  if(mode == DISABLED)
    return 0;

  uint32_t now = millis();
  if(!force) {
    if(now < lastMediaCheckTime + mediaCheckPeriod)
      return lastMediaId;
  }

  lastMediaCheckTime = now;
  lastMediaId = 0;

  cid_t cid;
  if(!card.readCID(&cid))
    init();

  if(!blocks)
    return 0;

  uint32_t id = 0;
  for(unsigned int i = 0; i < sizeof(cid) / 4; ++i)
    id ^= ((const uint32_t*)&cid)[i];

  // Make sure the same card transfered to another slot won't give the same value
  id += slot;

  // Make sure that the id is never 0
  if(!id)
    ++id;

  lastMediaId = id;

  return id;
}

void SdDev::disable() {
  verbose("SD", slot, " disabled\n");
  reset();
  mode = DISABLED;
}

int SdDev::acsiDeviceMask = 0;
int SdDev::gemDriveMask = 0;
int SdDev::gemBootDrive = 0;

#if ! ACSI_STRICT
void SdDev::updateGemBootDrive() {
  for(gemBootDrive = 0; gemBootDrive < 8; ++gemBootDrive)
    if(gemDriveMask & 1 << gemBootDrive)
      return;
}
#endif

ImageDev::ImageDev(SdDev &sd_): sd(sd_), sdMediaId(0) {}

bool ImageDev::open(const char *path) {
  if(!sd.mediaId())
    return false;

  if(!sd.fs.fatType())
    return false;

  verbose("Searching image ", path, " ... ");

  oflag_t oflag = O_RDONLY;
#if ! ACSI_READONLY
  if(sd.isWritable())
    oflag = O_RDWR;
#endif
  if(!image.open(&sd.fs, path, oflag)) {
    blocks = 0;
    verbose("not found\n");
    return false;
  }

  blocks = image.fileSize() / ACSI_BLOCKSIZE;
  updateBootable();
  verbose("opened\n");
  return true;
}

void ImageDev::close() {
  image.close();
  blocks = 0;
  bootable = false;
  sdMediaId = 0;
}

bool ImageDev::readStart(uint32_t block) {
  return image.seekSet((uint64_t)block * ACSI_BLOCKSIZE);
}

bool ImageDev::readData(uint8_t *data, int count) {
  return image.read(data, ACSI_BLOCKSIZE * count) == ACSI_BLOCKSIZE * count;
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
  if(!isWritable())
    return false;
  return image.seekSet((uint64_t)block * ACSI_BLOCKSIZE);
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
  if(!image.isWritable())
    return false;
  return image.write(data, ACSI_BLOCKSIZE * count);
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

bool ImageDev::isWritable() {
  return image.isWritable();
}

uint32_t ImageDev::mediaId(bool force) {
  // For now, images cannot be switched on the fly so they cannot change
  // unless the SD card is physically swapped. Derive mediaId from the SD
  // card itself
  uint32_t id = sd.mediaId(force);
  if(!id || id != sdMediaId) {
    // No medium or SD card swapped: abort ASAP
    close();
    return 0;
  }

  // Swap a few bits to distinguish from the actual SD card
  id ^= 0x00000f00;

  // Make sure that the id is never 0
  if(!id)
    ++id;

  return id;
}
