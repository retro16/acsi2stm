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

#include "BlockDev.h"

#include "SdFat.h"
#if ! ACSI_STRICT
#include "TinyFile.h"
#endif

static const uint32_t sdRates[] = {
  SD_SCK_MHZ(ACSI_SD_MAX_SPEED),
#if ACSI_SD_MAX_SPEED > 50
  SD_SCK_MHZ(50),
#endif
#if ACSI_SD_MAX_SPEED > 25
  SD_SCK_MHZ(25),
#endif
  SD_SCK_MHZ(1) // Fallback to a horribly slow speed (should never happen)
};

bool BlockDev::updateBootable() {
  bootable = false;

  uint8_t bootSector[ACSI_BLOCKSIZE];

  // Read the boot sector
  if(!readStart(0))
    goto readFail;
  if(!readData(bootSector, 1))
    goto readFail;
  if(!readStop())
    goto readFail;

  bootable = (computeChecksum(bootSector) == 0x1234);

  return true;

readFail:
  verbose("read error ");
  return false;
}

ImageDev::ImageDev(SdDev &sd_): sd(sd_), sdMediaId(0) {}

bool ImageDev::open(const char *path) {
  close();

  sdMediaId = sd.mediaId();

  if(!sdMediaId)
    return false;

  if(!sd.fs.fatType())
    return false;

  verbose("image ", path);

  oflag_t oflag = O_RDONLY;
#if ! ACSI_READONLY
  if(sd.isWritable())
    oflag = O_RDWR;
#endif
  if(!image.open(&sd.fs, path, oflag)) {
    close();
#if ! ACSI_READONLY
    if(image.open(&sd.fs, path, O_RDONLY)) {
      verbose(" read-only\n");
    } else {
      close();
      verbose(" not found\n");
      return false;
    }
#else
    verbose(" not found\n");
    return false;
#endif
  }

  blocks = image.fileSize() / ACSI_BLOCKSIZE;
  verbose(" opened\n");

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
  (void)block;
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
  (void)data;
  (void)count;
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

uint32_t ImageDev::mediaId(BlockDev::MediaIdMode mode) {
  // For now, images cannot be switched on the fly so they cannot change
  // unless the SD card is physically swapped. Derive mediaId from the SD
  // card itself
  uint32_t id = sd.mediaId(mode);
  if(!id || id != sdMediaId) {
    // No medium or SD card swapped: abort ASAP
    close();
    verbose("no medium ");
    return 0;
  }

  // Swap a few bits to distinguish from the actual SD card
  id ^= 0x00000f00;

  // Make sure that the id is never 0
  if(!id)
    ++id;

  return id;
}

void SdDev::init() {
  // Set wp pin as input pullup to read write lock later
  pinMode(wpPin, INPUT_PULLUP);

  dbg("\n        SD", slot, ' ');

  unsigned int rate;
  for(rate = 0; rate < sizeof(sdRates)/sizeof(sdRates[0]); ++rate) {
    for(int i = 0; i < 2; ++i)
      if(card.begin(SdSpiConfig(csPin, SHARED_SPI, sdRates[rate], &SPI)))
        goto beginOk;
      else
        delay(10);

    verbose("error ");
    reset();
    continue;

beginOk:
    dbg(sdRates[rate] / SD_SCK_MHZ(1), "MHz ");

    // Get SD card identification to test communication
    cid_t cid;
    if(!card.readCID(&cid)) {
      verbose("CID error ");
      continue;
    }

    // Get SD card size
    blocks = card.sectorCount();

#if ACSI_MAX_BLOCKS
    if(blocks > ACSI_MAX_BLOCKS)
      blocks = ACSI_MAX_BLOCKS;
#endif

    dbg(blocks, " blocks ", writable ? "rw ":"ro ");

    if(!blocks)
      continue;

    // Get writable pin status
#if !ACSI_SD_WRITE_LOCK
    writable = true;
#elif ACSI_SD_WRITE_LOCK == 1
    writable = digitalRead(wpPin);
#elif ACSI_SD_WRITE_LOCK == 2
    writable = !digitalRead(wpPin);
#endif

    uint32_t id = mediaId(FORCE);

    // Open the file system
    image.close();
    if(fs.begin(&card))
#if ACSI_PIO
      {}
#else
      image.open(ACSI_IMAGE_FILE);

    // Check if bootable
    if(!(*this)->updateBootable())
      continue;
#endif


#if ! ACSI_STRICT
    if(fs.fatType() && !image && !bootable)
      mountable = true;
#endif

    if(image)
      dbg("image ");
    if(mountable)
      dbg("mountable ");
    if(bootable)
      dbg("boot ");

    break;
  }

  if(!lastMediaId) {
    dbg("no SD ");
    reset();
  }
}

void SdDev::onReset() {
  // Detach from ACSI bus
  Devices::detach(slot);

  // Check if the device is disabled (wpPin pin to VCC)
  pinMode(wpPin, INPUT_PULLDOWN);
  delayMicroseconds(10);
  if(digitalRead(wpPin)) {
    // wpPin pin to VCC: unit disabled
    pinMode(wpPin, INPUT_PULLUP);
    disable();
    return;
  }

  // Try to initialize the SD card
  mode = ACSI; // Enable the slot
  init();

  mode = computeMode();

  // Attach to the ACSI bus if not disabled
#if ! ACSI_STRICT
  if(mode == GEMDRIVE)
    attachGemDrive(slot);
  else
#endif
#if ! ACSI_PIO
  if(mode == ACSI)
    attachAcsi(slot);
#else
    {}
#endif
}

void SdDev::getDeviceString(char *target) {
  // Characters:  0         1         2
  //              012345678901234567890123  4567
  memcpy(target, "ACSI2STM SD0 RAW ???M   " ACSI2STM_VERSION, 29);

  // Update sd card number
  target[11] += slot;

  if(!mediaId(FORCE)) {
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
  (void)block;
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
  (void)data;
  (void)count;
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

bool SdDev::isWritable() {
  return writable;
}

uint32_t SdDev::mediaId(BlockDev::MediaIdMode mediaIdMode) {
  if(mode == DISABLED)
    return 0;

  verbose("id", slot, " ", mediaIdMode ," ");

  uint32_t now = millis();
  if(mediaIdMode != BlockDev::FORCE) {
    if(mediaIdMode == BlockDev::CACHED || now - lastMediaCheckTime <= mediaCheckPeriod) {
      verbose("cached ");
      return lastMediaId;
    }
  }

  lastMediaCheckTime = now;

  cid_t cid;
  if(!card.readCID(&cid)) {
    // SD has an issue
    verbose("CID error ");

#if ! ACSI_STRICT
    TinyFile::ejected(lastMediaId);
#endif
    lastMediaId = 0;

    if(mediaIdMode == FORCE)
      // The caller wants the truth: don't lie
      return 0;

    // Try to recover
    init();

    if(!lastMediaId)
      // Recover failed
      return 0;
  } else {
    lastMediaId = 0;
  }

#if ! ACSI_STRICT
  if(mediaIdMode != FORCE && mode != computeMode()) {
    // Switched mode: just disable the slot temporarily
    verbose("switched mode ");
    lastMediaId = 0;
    return 0;
  }
#endif

  if(lastMediaId)
    // init() called us again, just return the updated value
    return lastMediaId;

  uint32_t id = 0;
  for(unsigned int i = 0; i < sizeof(cid) / 4; ++i)
    id ^= ((const uint32_t*)&cid)[i];

  // Make sure the same card transfered to another slot won't give the same value
  id += slot * 2;

  // Make sure that the id is never 0
  if(!id)
    ++id;

  lastMediaId = id;

  verboseHex(id, " ");

  return id;
}

void SdDev::disable() {
  reset();
  mode = DISABLED;
}

SdDev::Mode SdDev::computeMode() {
  if(mode == DISABLED)
    // Once disabled, it stays disabled
    return DISABLED;

  if(Devices::strict)
    return ACSI;

  // Sense mode based on the current state
  if(image)
    return ACSI; // Images are ACSI
  else if(bootable)
    return ACSI; // Anything bootable by the Atari is ACSI
  else if(mountable)
    return GEMDRIVE; // Non-bootable, mountable filesystem: use GemDrive
  else if(!lastMediaId)
    return GEMDRIVE; // No SD card: use GemDrive
  else
    return ACSI; // Unrecognized SD format: pass through as ACSI
}

void SdDev::reset() {
  // Reset internal state
  image.close();
  fs.end();
  card.end();
  blocks = 0;
  writable = false;
  bootable = false;
#if ! ACSI_STRICT
  mountable = false;
#endif
  lastMediaCheckTime = millis();
  lastMediaId = 0;
}

