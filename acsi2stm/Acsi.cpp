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

#include "Acsi.h"

Acsi::Acsi(int deviceId_, int sdCs_, int sdWp_, DmaPort &dma_, Watchdog &watchdog_):
  deviceId(deviceId_),
  sdCs(sdCs_),
  sdWp(sdWp_),
  dma(dma_),
  watchdog(watchdog_) {}

Acsi::Acsi(Acsi &&other):
  deviceId(other.deviceId),
  sdCs(other.sdCs),
  sdWp(other.sdWp),
  dma(other.dma),
  watchdog(other.watchdog) {}

void Acsi::begin() {
  dbg("Initializing SD", deviceId, " ... ");

  dma.addDevice(deviceId);

  // Initialize the SD card
  pinMode(sdWp, INPUT_PULLUP);
  delay(5);
  if(card.begin(deviceId, sdCs, digitalRead(sdWp))) {
    dbg("success\n");
  } else {
    dbg("failed\n\n");
    return;
  }

  // Detach all LUNs
  for(int l = 0; l < maxLun; ++l)
    luns[l] = nullptr;

  // Mount images from SD cards
  mountImages();

  // Mount raw SD card on LUN0
  if(!luns[0] && card)
    luns[0] = &card;

#if ACSI_DEBUG
  for(int l = 0; l < maxLun; ++l) {
    if(luns[l]) {
      luns[l]->getDeviceString((char *)buf);
      buf[24] = 0;
      dbg("  LUN", l, ": ", (const char *)buf, '\n');
    }
  }
#endif

  dbg('\n');
}

void Acsi::mountImages() {
  int prefixLen = strlen(ACSI_IMAGE_FOLDER ACSI_LUN_IMAGE_PREFIX);
  
  for(int l = 0; l < maxLun; ++l) {
    // Skip populated LUNs
    if(luns[l])
      continue;

    // Build the image file name
    strcpy((char *)buf, ACSI_IMAGE_FOLDER ACSI_LUN_IMAGE_PREFIX);
    buf[prefixLen] = '0' + l;
    strcpy((char *)&buf[prefixLen + 1], ACSI_LUN_IMAGE_EXT);

    // Try to open the image file
    if(images[l].begin(&card, (const char *)buf, l))
      // Success: associate the image to its LUN
      luns[l] = &images[l];
  }
}

void Acsi::process(uint8_t cmd) {
  if(cmd == 0x1f) {
    // Read extended command
    cmd = dma.readIrq();
  }

  if(!readCmdBuf(cmd)) {
    dbg("Unknown command\n");
    lastSeek = false;
    commandError(ERR_OPCODE);
    return;
  }

  processCmdBuf();
}

void Acsi::processCmdBuf() {
#if ACSI_VERBOSE
  dumpln(cmdBuf, cmdLen, 0);
#else
  dumpln(cmdBuf, cmdLen, cmdLen);
#endif

  BlockDev *dev = nullptr;
  if(validLun())
    dev = luns[getLun()];

  // Command preprocessing
  switch(cmdBuf[0]) {
  case 0x00:
    commandSuccess();
    return;
  default:
    if(!dev) {
      commandError(ERR_INVLUN);
      return;
    }
    break;
  case 0x12: // Inquiry
  case 0x03: // Request sense
    // TODO: sense media
    break;
  }

  // Execute the command
  switch(cmdBuf[0]) {
  default: // Unknown command
    dbg("Unknown command\n");
    lastSeek = false;
    commandError(ERR_OPCODE);
    return;
  case 0x0d: // Correction
  case 0x15: // Mode select
  case 0x1b: // Ship
    // Always succeed
    lastSeek = false;
    commandSuccess();
    return;
  case 0x03: // Request Sense
    if(!dev) {
      dbg("Invalid LUN sense ...\n");
      lastErr = ERR_INVLUN;
    }

    for(int b = 0; b < cmdBuf[4]; ++b)
      buf[b] = 0;

    if(cmdBuf[4] <= 4) {
      buf[0] = lastErr & 0xFF;
      if(lastSeek) {
        buf[0] |= 0x80;
        buf[1] = (lastBlock >> 16) & 0xFF;
        buf[2] = (lastBlock >> 8) & 0xFF;
        buf[3] = (lastBlock) & 0xFF;
      }
    } else {
      // Build long response in buf
      buf[0] = 0x70;
      if(lastSeek) {
        buf[0] |= 0x80;
        buf[4] = (lastBlock >> 16) & 0xFF;
        buf[5] = (lastBlock >> 8) & 0xFF;
        buf[6] = (lastBlock) & 0xFF;
      }
      buf[2] = (lastErr >> 8) & 0xFF;
      buf[7] = 14;
      buf[12] = (lastErr) & 0xFF;
      buf[19] = (lastBlock >> 16) & 0xFF;
      buf[20] = (lastBlock >> 8) & 0xFF;
      buf[21] = (lastBlock) & 0xFF;
    }
    // Send the response
    dma.sendDma(buf, cmdBuf[4]);
    
    commandSuccess();
    return;
  case 0x08: // Read block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    if(lastBlock == 0) {
      // TODO: refresh medium
    }

    // Do the actual read operation
    if(processBlockRead(lastBlock, cmdBuf[4], dev))
      commandSuccess();
    else
      commandError(ERR_READERR);
    return;
  case 0x0a: // Write block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    if(lastBlock == 0)
      dbg("WARNING: Write to boot sector\n");

    // Do the actual write operation
    if(processBlockWrite(lastBlock, cmdBuf[4], dev))
      commandSuccess();
    else
      commandError(ERR_WRITEERR);
    return;
  case 0x0b: // Seek
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;
    if(lastBlock >= dev->blocks)
      commandError(ERR_INVADDR);
    else
      commandSuccess();
    return;
  case 0x12: // Inquiry
    // Adjust size to 4 if 0
    if(!cmdBuf[4])
      cmdBuf[4] = 4;

    // Fill the response with zero bytes
    for(uint8_t b = 0; b <= cmdBuf[4]; ++b)
      buf[b] = 0;

    if(!dev) {
      buf[0] = 0x7F; // Unsupported LUN
    } else {
      // Build the product string with the SD card size
      dev->getDeviceString((char *)buf + 8);
    }

    // buf[1] = 0x80; // Removable flag (TODO)
    buf[2] = 1; // ACSI version
    buf[4] = 31; // Data length

    dma.sendDma(buf, cmdBuf[4]);

    lastSeek = false;
    commandSuccess();
    return;
  case 0x1a: // Mode sense
    {
      lastSeek = false;
      switch(cmdBuf[2]) { // Sub-command
      case 0x00:
        dev->modeSense0(buf);
        dma.sendDma(buf, 16);
        break;
      case 0x04:
        dev->modeSense4(buf);
        dma.sendDma(buf, 24);
        break;
      case 0x3f:
        buf[0] = 44;
        buf[1] = 0;
        buf[2] = 0;
        buf[3] = 0;
        dev->modeSense4(buf + 4);
        dev->modeSense0(buf + 28);
        dma.sendDma(buf, 44);
        break;
      default:
        dbgHex("Error: unsupported mode sense ", (int)cmdBuf[3], '\n');
        commandError(ERR_INVARG);
        return;
      }
      commandSuccess();
      return;
    }
  case 0x25: // Read capacity
    // Send the number of blocks of the SD card
    buf[0] = (dev->blocks >> 24) & 0xFF;
    buf[1] = (dev->blocks >> 16) & 0xFF;
    buf[2] = (dev->blocks >> 8) & 0xFF;
    buf[3] = (dev->blocks) & 0xFF;
    // Send the block size (which is always 512)
    buf[4] = 0x00;
    buf[5] = 0x00;
    buf[6] = 0x02;
    buf[7] = 0x00;

    dma.sendDma(buf, 8);

    commandSuccess();
    return;
  case 0x28: // Read blocks
    {
      // Compute the block number
      uint32_t block = (((uint32_t)cmdBuf[2]) << 24) | (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual read operation
      if(processBlockRead(block, count, dev))
        commandSuccess();
      else
        commandError(ERR_READERR);
    }
    return;
  case 0x2a: // Write blocks
    {
      // Compute the block number
      uint32_t block = (((uint32_t)cmdBuf[2]) << 24) | (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual write operation
      if(processBlockWrite(block, count, dev))
        commandSuccess();
      else
        commandError(ERR_WRITEERR);
    }
    return;
  }
}

bool Acsi::readCmdBuf(uint8_t cmd) {
  if(cmd == 0x1f)
    // ICD extended command marker
    dma.readIrq(cmdBuf, 1);
  else
    // The first byte was the command
    cmdBuf[0] = cmd;

  if(cmdBuf[0] >= 0xa0) {
    // 12 bytes command
    dma.readIrq(&cmdBuf[1], 11);
    cmdLen = 12;
  } else if(cmdBuf[0] >= 0x80) {
    // 16 bytes command
    dma.readIrq(&cmdBuf[1], 15);
    cmdLen = 16;
  } else if(cmdBuf[0] >= 0x20) {
    // 10 bytes command
    dma.readIrq(&cmdBuf[1], 9);
    cmdLen = 10;
  } else {
    // 6 bytes command
    cmdBuf[0] = cmd;
    dma.readIrq(&cmdBuf[1], 5);
    cmdLen = 6;
  }

  return true;
}

bool Acsi::validLun() {
  return validLun(getLun());
}

bool Acsi::validLun(int lun) {
  if(lun < 0 || lun >= maxLun)
    return false;
  return luns[lun];
}

int Acsi::getLun() {
  return cmdBuf[1] >> 5;
}

void Acsi::commandSuccess() {
  lastErr = ERR_OK;
  dbg("Success\n");
  dma.sendIrq(0);
  dma.endTransaction();
}

void Acsi::commandError(ScsiErr err) {
  lastErr = err;
  dbgHex("Error ", lastErr, '\n');
  dma.sendIrq(2);
  dma.endTransaction();
}

bool Acsi::processBlockRead(uint32_t block, int count, BlockDev *dev) {
  dbg("Read ", count, " blocks from ", block, " on LUN ", getLun(), '\n');

  if(!dev->readStart(block)) {
    begin();
    dev = luns[getLun()];
    if(!dev || !dev->readStart(block))
      return false;
  }

  if(block + count - 1 >= dev->blocks) {
    dbg("Out of range\n");
    dev->readStop();
    lastErr = ERR_INVADDR;
    return false; // Block out of range
  }

  for(int s = 0; s < count;) {
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    if(!dev->readData(buf, burst)) {
      dbg("Read error\n");
      lastErr = ERR_READERR;
      dev->readStop();
      return false;
    }
    dma.sendDma(buf, ACSI_BLOCKSIZE * burst);

    s += burst;
  }

  dev->readStop();

  return true;
}

bool Acsi::processBlockWrite(uint32_t block, int count, BlockDev *dev) {
  dbg("Write ", count, " blocks from ", block, " on LUN ", getLun(), '\n');

#if AHDI_READONLY
#if AHDI_READONLY == 2
  for(int s = 0; s < count; ++s)
    dma.readDma(dataBuf, ACSI_BLOCKSIZE);
  return true;
#else
  lastErr = ERR_WRITEPROT;
  return false;
#endif
#else

  if(!dev->writeStart(block)) {
    begin();
    dev = luns[getLun()];
    if(!dev || !dev->writeStart(block))
      return false;
  }

  if(block + count - 1 >= dev->blocks) {
    dbg("Out of range\n");
    dev->writeStop();
    lastErr = ERR_INVADDR;
    return false; // Block out of range
  }

  for(int s = 0; s < count;) {
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    dma.readDma(buf, ACSI_BLOCKSIZE * burst);
    if(!dev->writeData(buf, burst)) {
      dbg("Write error\n");
      lastErr = ERR_WRITEERR;
      dev->writeStop();
      return false;
    }

    s += burst;
  }

  dev->writeStop();

  return true;
#endif
}

void Acsi::blocksToString(uint32_t blocks, char *target) {
  // Characters: 0123
  //            "213G"

  target[3] = 'K';

  uint32_t sz = (blocks + 1) / 2;
  if(sz > 999) {
    sz = (sz + 1023) / 1024;
    target[3] = 'M';
  }
  if(sz > 999) {
    sz = (sz + 1023) / 1024;
    target[3] = 'G';
  }
  if(sz > 999) {
    sz = (sz + 1023) / 1024;
    target[3] = 'T';
  }

  // Roll our own int->string conversion.
  // Libraries that do this are surprisingly large.
  for(int i = 2; i >= 0; --i) {
    if(sz || i == 2)
      target[i] = '0' + sz % 10;
    else
      target[i] = ' ';
    sz /= 10;
  }
}

// Static variables
int Acsi::cmdLen;
uint8_t Acsi::cmdBuf[16];
uint8_t Acsi::buf[Acsi::bufSize];

// vim: ts=2 sw=2 sts=2 et
