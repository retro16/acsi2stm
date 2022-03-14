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

#include "acsi2stm.h"
#include "Debug.h"
#include "Ahdi.h"
#include "SdFat.h"
#include "Acsi.h"

bool Ahdi::begin(int acsiId_, int csPin_, uint32_t maxBlocks_) {
  acsiId = acsiId_;
  csPin = csPin_;
  maxBlocks = maxBlocks_;

  resetState();
  return initSd();
}

bool Ahdi::initSd() {
  if(image)
    image.close();

#if AHDI_FAST_SD
  if(!card.begin(SdSpiConfig(csPin, SHARED_SPI))) {
#else
  if(!card.begin(SdSpiConfig(csPin, SHARED_SPI, SD_SCK_MHZ(18), &SPI))) {
#endif
    resetState();
    return false;
  }

  // Give some time to the internal SD electronics to initialize properly
  delay(250);

  blocks = card.sectorCount();
  if(blocks > maxBlocks)
    blocks = maxBlocks;

  lastErr = LASTERR_OK;

  format = RAW;
  bootable = false;

  // Detect partition type
  if(fs.begin(&card)) {
    switch(fs.fatType()) {
      case FAT_TYPE_FAT16: format = FAT; break;
      case FAT_TYPE_FAT32: format = FAT; break;
      case FAT_TYPE_EXFAT: format = EXFAT; break;
    }

    if(image.open(&fs, IMAGE_FILE_NAME, O_RDWR) && (image.fileSize() % (ACSI_BLOCKSIZE)) == 0 && image.fileSize() >= ACSI_BLOCKSIZE) {
      format = IMAGE;
      blocks = image.fileSize() / ACSI_BLOCKSIZE;
      // No size cap for image files
    }
  }

  // Test if the card has a valid Atari boot sector

  readStart(0);
  readData(dataBuf);
  readStop();

  bootable = (computeChecksum() == 0x1234);

  return true;
}

void Ahdi::processCmd(uint8_t cmd) {
  if(!readCmdBuf(cmd)) {
    acsiDbgln("Unknown command");
    lastSeek = false;
    commandError(LASTERR_OPCODE);
    return;
  }

#if ACSI_VERBOSE
  acsiDbgDumpln(cmdBuf, cmdLen, 0);
#else
  acsiDbgDumpln(cmdBuf, cmdLen, cmdLen);
#endif

  // Command preprocessing
  switch(cmdBuf[0]) {
  case 0x00:
    commandSuccess();
    return;
  default:
    if(getLun() > 0) {
      commandError(LASTERR_INVLUN);
      return;
    }
    if(format == NONE) {
      // SD card not initialized
      commandError(LASTERR_NOMEDIUM);
      return;
    }
    break;
  case 0x12: // Inquiry
    initSd();
    break;
  case 0x03: // Request sense
    break;
  }

  // Execute the command
  switch(cmdBuf[0]) {
  default: // Unknown command
    acsiDbgln("Unknown command");
    lastSeek = false;
    commandError(LASTERR_OPCODE);
    return;
  case 0x0d: // Correction
  case 0x15: // Mode select
  case 0x1B: // Ship
    // Always succeed
    lastSeek = false;
    commandSuccess();
    return;
  case 0x03: // Request Sense
    if(getLun() > 0) {
      acsiDbg("Invalid LUN sense ... ");
      lastErr = LASTERR_INVLUN;
    }

    for(int b = 0; b < cmdBuf[4]; ++b)
      dataBuf[b] = 0;

    if(cmdBuf[4] <= 4) {
      dataBuf[0] = lastErr & 0xFF;
      if(lastSeek) {
        dataBuf[0] |= 0x80;
        dataBuf[1] = (lastBlock >> 16) & 0xFF;
        dataBuf[2] = (lastBlock >> 8) & 0xFF;
        dataBuf[3] = (lastBlock) & 0xFF;
      }
    } else {
      // Build long response in dataBuf
      dataBuf[0] = 0x70;
      if(lastSeek) {
        dataBuf[0] |= 0x80;
        dataBuf[4] = (lastBlock >> 16) & 0xFF;
        dataBuf[5] = (lastBlock >> 8) & 0xFF;
        dataBuf[6] = (lastBlock) & 0xFF;
      }
      dataBuf[2] = (lastErr >> 8) & 0xFF;
      dataBuf[7] = 14;
      dataBuf[12] = (lastErr) & 0xFF;
      dataBuf[19] = (lastBlock >> 16) & 0xFF;
      dataBuf[20] = (lastBlock >> 8) & 0xFF;
      dataBuf[21] = (lastBlock) & 0xFF;
    }
    // Send the response
    Acsi::sendDma(dataBuf, cmdBuf[4]);
    
    commandSuccess();
    return;
  case 0x08: // Read block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    // Initialize the SD card if reading the boot sector
    if(lastBlock == 0 && !initSd()) {
      // SD card not initialized
      sdError();
      commandError(LASTERR_NOMEDIUM);
      return;
    }

    // Do the actual read operation
    if(processBlockRead(lastBlock, cmdBuf[4]))
      commandSuccess();
    else
      commandError(LASTERR_READERR);
    return;
  case 0x0a: // Write block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    if(lastBlock == 0)
      acsiDbgln("WARNING: Write to boot sector");

    // Do the actual write operation
    if(processBlockWrite(lastBlock, cmdBuf[4]))
      commandSuccess();
    else
      commandError(LASTERR_WRITEERR);
    return;
  case 0x0b: // Seek
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;
    if(lastBlock >= blocks)
      commandError(LASTERR_INVADDR);
    else
      commandSuccess();
    return;
  case 0x12: // Inquiry
    // Fill the response with zero bytes
    for(uint8_t b = 0; b <= cmdBuf[4]; ++b)
      dataBuf[b] = 0;

    if(getLun() > 0)
      dataBuf[0] = 0x7F; // Unsupported LUN
    dataBuf[1] = 0x80; // Removable flag
    dataBuf[2] = 1; // ACSI version
    dataBuf[4] = 31; // Data length
    
    // Build the product string with the SD card size
    getDeviceString((char *)dataBuf + 8);
   
    Acsi::sendDma(dataBuf, cmdBuf[4] + 1);

    lastSeek = false;
    commandSuccess();
    return;
  case 0x1a: // Mode sense
    {
      lastSeek = false;
      switch(cmdBuf[2]) { // Sub-command
      case 0x00:
        modeSense0(dataBuf);
        Acsi::sendDma(dataBuf, 16);
        break;
      case 0x04:
        modeSense4(dataBuf);
        Acsi::sendDma(dataBuf, 24);
        break;
      case 0x3f:
        dataBuf[0] = 44;
        dataBuf[1] = 0;
        dataBuf[2] = 0;
        dataBuf[3] = 0;
        modeSense4(dataBuf + 4);
        modeSense0(dataBuf + 28);
        Acsi::sendDma(dataBuf, 44);
        break;
      default:
        acsiDbg("Error: unsupported mode sense ");
        acsiDbgln((int)cmdBuf[3], HEX);
        commandError(LASTERR_INVARG);
        return;
      }
      commandSuccess();
      return;
    }
  case 0x25: // Read capacity
    // Send the number of blocks of the SD card
    dataBuf[0] = (blocks >> 24) & 0xFF;
    dataBuf[1] = (blocks >> 16) & 0xFF;
    dataBuf[2] = (blocks >> 8) & 0xFF;
    dataBuf[3] = (blocks) & 0xFF;
    // Send the block size (which is always 512)
    dataBuf[4] = 0x00;
    dataBuf[5] = 0x00;
    dataBuf[6] = 0x02;
    dataBuf[7] = 0x00;

    Acsi::sendDma(dataBuf, 8);

    commandSuccess();
    return;
  case 0x28: // Read blocks
    {
      // Compute the block number
      int block = (((int)cmdBuf[2]) << 24) | (((int)cmdBuf[3]) << 16) | (((int)cmdBuf[4]) << 8) | (cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual read operation
      if(processBlockRead(block, count))
        commandSuccess();
      else
        commandError(LASTERR_READERR);
    }
    return;
  case 0x2a: // Write blocks
    {
      // Compute the block number
      int block = (((int)cmdBuf[2]) << 24) | (((int)cmdBuf[3]) << 16) | (((int)cmdBuf[4]) << 8) | (cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual write operation
      if(processBlockWrite(block, count))
        commandSuccess();
      else
        commandError(LASTERR_WRITEERR);
    }
    return;
  }
}

bool Ahdi::readCmdBuf(uint8_t cmd) {
  if(cmd == 0x1f)
    // ICD extended command marker
    Acsi::readIrq(cmdBuf, 1);

  if(cmdBuf[0] > 0x60) {
    // Unsupported command
    return false;
  } else if(cmdBuf[0] > 0x20) {
    // 10 bytes command
    Acsi::readIrq(&cmdBuf[1], 9);
    cmdLen = 10;
  } else {
    // 6 bytes command
    cmdBuf[0] = cmd;
    Acsi::readIrq(&cmdBuf[1], 5);
    cmdLen = 6;
  }

  return true;
}

void Ahdi::modeSense0(uint8_t *buf) {
  for(uint8_t b = 0; b < 16; ++b) {
    buf[b] = 0;
  }
  // Values got from the Hatari emulator
  buf[1] = 14;
  buf[3] = 8;
  // Send the number of blocks of the SD card
  buf[5] = (blocks >> 16) & 0xFF;
  buf[6] = (blocks >> 8) & 0xFF;
  buf[7] = (blocks) & 0xFF;
  // Sector size middle byte
  buf[10] = 2;
}

void Ahdi::modeSense4(uint8_t *buf) {
  for(uint8_t b = 0; b < 24; ++b) {
    buf[b] = 0;
  }
  // Values got from the Hatari emulator
  buf[0] = 4;
  buf[1] = 22;
  // Send the number of blocks in CHS format
  buf[2] = (blocks >> 23) & 0xFF;
  buf[3] = (blocks >> 15) & 0xFF;
  buf[4] = (blocks >> 7) & 0xFF;
  // Hardcode 128 heads
  buf[5] = 128;
}

bool Ahdi::processBlockRead(uint32_t block, int count) {
  acsiDbg("Read ");
  acsiDbg(count);
  acsiDbg(" blocks from ");
  acsiDbgln(block);

  if(block + count - 1 >= blocks) {
    acsiDbgln("Out of range");
    lastErr = LASTERR_INVADDR;
    return false; // Block out of range
  }

  if(!readStart(block)) {
    if(!initSd() || !readStart(block)) {
      sdError();
      return false;
    }
  }

  for(int s = 0; s < count;) {
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    if(!readData(dataBuf, burst)) {
      acsiDbg("SD read error");
      lastErr = LASTERR_READERR;
      readStop();
      return false;
    }
    Acsi::sendDma(dataBuf, ACSI_BLOCKSIZE * burst);

    s += burst;
  }

  readStop();

  return true;
}

bool Ahdi::processBlockWrite(uint32_t block, int count) {
  acsiDbg("Write ");
  acsiDbg(count);
  acsiDbg(" blocks from ");
  acsiDbgln(block);

  if(block + count - 1 >= blocks) {
    acsiDbgln("Out of range");
    lastErr = LASTERR_INVADDR;
    return false; // Block out of range
  }

#if AHDI_READONLY == 2
  for(int s = 0; s < count; ++s)
    Acsi::readDma(dataBuf, ACSI_BLOCKSIZE);
  return true;
#elif AHDI_READONLY == 1
  lastErr = LASTERR_WRITEPROT;
  return false;
#else

  if(!writeStart(block)) {
    if(!initSd() || !writeStart(block)) {
      sdError();
      return false;
    }
  }

  for(int s = 0; s < count; ++s) {
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    Acsi::readDma(dataBuf, ACSI_BLOCKSIZE * burst);
    if(!writeData(dataBuf, burst)) {
      acsiDbg("SD write error");
      lastErr = LASTERR_WRITEERR;
      writeStop();
      return false;
    }

    s += burst;
  }

  writeStop();

  return true;
#endif
}

void Ahdi::commandSuccess() {
  lastErr = LASTERR_OK;
  acsiDbgln("Success");
  Acsi::sendIrq(0);
}

void Ahdi::commandError(int err) {
  lastErr = err;
  acsiDbg("Error ");
  acsiDbgln(lastErr, HEX);
  Acsi::sendIrq(2);
}

int Ahdi::getLun() {
  return cmdBuf[1] >> 5;
}

void Ahdi::getDeviceString(char *target) {
  sprintf(target, "ACSI2STM SD%1d ", acsiId);
  target += 13;

  if(format == NONE) {
    sprintf(target, "NO SD CARD v" ACSI2STM_VERSION);
    return;
  }

  uint32_t sz = (blocks + 1024) / 2048;
  char unit = 'M';
  char capped = ' ';

  // Write SD card size
  if((blocks + 1024*1024) >= 2048*10240) { // Size in GB if size >= 10G
    sz = (blocks + 1024*1024) / (2048*1024);
    unit = 'G';
  }

  // Add a + symbol if capacity is artificially capped
  if(format != IMAGE && card.sectorCount() > maxBlocks)
    capped = '+';

  // Add format at the end
  const char *formatString = "   ";
  if(format == FAT) {
    formatString = "FAT";
  } else if(format == EXFAT) {
    formatString = "EXF";
  } else if(format == IMAGE) {
    formatString = "IMG";
  }

  sprintf(target, "%4d%c%cB %sv" ACSI2STM_VERSION, sz, capped, unit, formatString);

  // Add the Atari logo if bootable
  if(bootable) {
    target[9] = 0x0E;
    target[10] = 0x0F;
  }
}

void Ahdi::sdError() {
  acsiDbg("SD");
  acsiDbg(acsiId);
  acsiDbgln(" error");
}

uint16_t Ahdi::computeChecksum() {
  uint16_t checksum = 0;
  for(int i = 0; i < ACSI_BLOCKSIZE; i += 2) {
    checksum += ((int)dataBuf[i] << 8) + (dataBuf[i+1]);
  }
  return checksum;
}

bool Ahdi::readStart(uint32_t block) {
  if(image)
    return image.seekSet((uint64_t)block * ACSI_BLOCKSIZE);
  return card.readStart(block);
}

bool Ahdi::readData(uint8_t *data, int count) {
  if(image)
    return image.read(data, ACSI_BLOCKSIZE * count);

  while(count-- > 0) {
    if(!card.readData(data))
      return false;
    data += ACSI_BLOCKSIZE;
  }

  return true;
}

bool Ahdi::readStop() {
  if(image)
    return true;
  return card.readStop();
}

bool Ahdi::writeStart(uint32_t block) {
  if(image)
    if(image.isWritable())
      return image.seekSet((uint64_t)block * ACSI_BLOCKSIZE);
    else
      return false;
  return card.writeStart(block);
}

bool Ahdi::writeData(const uint8_t *data, int count) {
  if(image)
    if(image.isWritable())
      return image.write(data, ACSI_BLOCKSIZE * count);
    else
      return false;

  while(count-- > 0) {
    if(!card.writeData(data))
      return false;
    data += ACSI_BLOCKSIZE;
  }

  return true;
}

bool Ahdi::writeStop() {
  if(image) {
    image.flush();
    return true;
  }
  return card.writeStop();
}

void Ahdi::resetState() {
  format = NONE;
  blocks = 0;
  lastErr = LASTERR_INVARG;
  lastBlock = 0;
  lastSeek = false;
  bootable = false;
}

uint8_t Ahdi::dataBuf[ACSI_BLOCKSIZE * ACSI_BLOCKS];
uint8_t Ahdi::cmdBuf[10];
int Ahdi::cmdLen;

// vim: ts=2 sw=2 sts=2 et
