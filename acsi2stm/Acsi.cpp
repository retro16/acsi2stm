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

#include "Acsi.h"

#include "DmaPort.h"
#include "FlashFirmware.h"

#if ACSI_STRICT && ACSI_READONLY > 1
#error ACSI_READONLY == 2 and strict mode are incompatible
#endif

static void __attribute__ ((noinline)) write24(uint8_t *target, uint32_t value) {
  target[0] = (value >> 16) & 0xFF;
  target[1] = (value >> 8) & 0xFF;
  target[2] = (value) & 0xFF;
}

void Acsi::onReset() {
  mediaId = blockDev.mediaId();
  lastErr = ERR_OK;
  lastSeek = false;
  lastBlock = 0;
}

void Acsi::refresh() {
  uint32_t realId = blockDev.mediaId();
  if(realId == mediaId)
    return;

  mediaId = realId;

  dbg("Refresh SD", blockDev.slot, ':');

  if(mediaId) {
    dbg("New SD ");
    lastMediumState = MEDIUM_CHANGED;
    return;
  }

  dbg("No SD ");
  lastMediumState = MEDIUM_REMOVED;
}

void Acsi::process(uint8_t cmd) {
  if(blockDev.slot < 0)
    // Slot disabled: unplug the device completely
    return;

  readCmdBuf(cmd);

#if ACSI_VERBOSE
  dumpln(cmdBuf, cmdLen, 0);
#else
  dump(cmdBuf, cmdLen, cmdLen);
  dbg(" ");
#endif

  // Command preprocessing
  switch(cmdBuf[0]) {
  case 0x08: // Read block
  case 0x0a: // Write block
  case 0x0b: // Seek
  case 0x1a: // Mode sense
  case 0x25: // Read capacity
  case 0x28: // Read blocks
  case 0x2a: // Write blocks
    if(!validLun()) {
      dbg("Invalid LUN ");
      commandStatus(ERR_INVLUN);
      return;
    }
    // Fall through next case

  // Commands with no LUN but medium dependent
  case 0x00: // Test unit ready
    refresh();
    if(blockDev.slot < 0)
      // Slot has been disabled by refresh()
      return;

    if(lastMediumState == MEDIUM_REMOVED) {
      commandStatus(ERR_NOMEDIUM);
      return;
    } else if(lastMediumState == MEDIUM_CHANGED) {
      lastMediumState = MEDIUM_OK;
      commandStatus(ERR_MEDIUMCHANGE);
      return;
    }
    // Fall through next case

  // Unconditional commands
  case 0x03: // Request sense
  case 0x12: // Inquiry
  case 0x20: // UltraSatan commands
  case 0x3b: // Write buffer
  case 0x3c: // Read buffer
    break;

  default: // Unknown command
    dbg("Unknown command ");
    commandStatus(ERR_OPCODE);
    return;
  }

  uint32_t block = lastBlock;

  // Execute the command
  switch(cmdBuf[0]) {
  case 0x00: // Test unit ready
    if(cmdBuf[1] || cmdBuf[2] || cmdBuf[3] || cmdBuf[4] || cmdBuf[5])
      // Normally ERR_OK should always be returned, but this helps ACSITEST
      // command load testing
      commandStatus(ERR_INVARG);
    else
      commandStatus(ERR_OK);
    return;
  case 0x03: // Request Sense
    if(cmdBuf[4] < 4)
      cmdBuf[4] = 4;

    for(int b = 0; b < cmdBuf[4]; ++b)
      buf[b] = 0;

    if(cmdBuf[4] <= 4) {
      buf[0] = (lastErr >> 8) & 0xFF;
      if(lastSeek) {
        buf[0] |= 0x80;
        write24(&buf[1], lastBlock);
      }
    } else {
      // Build long response in buf
      buf[0] = 0x70;
      if(lastSeek) {
        buf[0] |= 0x80;
        write24(&buf[4], lastBlock);
      }
      buf[2] = (lastErr) & 0xFF;
      buf[7] = 14;
      buf[12] = (lastErr >> 8) & 0xFF;
      buf[13] = (lastErr >> 16) & 0xFF;
      write24(&buf[19], lastBlock);
    }

    // Send the response
    DmaPort::dmaStartDelay();
    DmaPort::sendDma(buf, cmdBuf[4]);

    commandStatus(ERR_OK);
    return;
  case 0x08: // Read block
    // Compute the block number
    block = (((int)cmdBuf[1] & 0x1f) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);

    // Do the actual read operation
    commandStatus(processBlockRead(block, cmdBuf[4]), block);
    break;
  case 0x0a: // Write block
    // Compute the block number
    block = (((int)cmdBuf[1] & 0x1f) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);

    // Do the actual write operation
    DmaPort::dmaStartDelay();
    commandStatus(processBlockWrite(block, cmdBuf[4]), block);
    break;
  case 0x0b: // Seek
    block = (((int)cmdBuf[1] & 0x1f) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    if(block >= blockDev->blocks)
      commandStatus(ERR_INVADDR, block);
    else
      commandStatus(ERR_OK, block);
    break;
  case 0x12: // Inquiry
    // Adjust size to 4 if 0
    if(!cmdBuf[4])
      cmdBuf[4] = 4;

    // Fill the response with zero bytes
    for(uint8_t b = 0; b < cmdBuf[4]; ++b)
      buf[b] = 0;

    if(!validLun()) {
      buf[0] = 0x7F; // Unsupported LUN
    } else {
      // Build the product string
      blockDev.getDeviceString((char *)buf + 8);
    }

    buf[1] = 0x80; // Removable flag
    buf[2] = 1; // ACSI version
    buf[4] = 31; // Data length

    DmaPort::dmaStartDelay();
    DmaPort::sendDma(buf, cmdBuf[4]);

    // Do not overwrite lastErr
    dbg("Success");
    DmaPort::sendIrq(0);
    return;
  case 0x1a: // Mode sense
    {
      DmaPort::dmaStartDelay();
      switch(cmdBuf[2]) { // Sub-command
      case 0x00:
        modeSense0(buf);
        DmaPort::sendDma(buf, 16);
        break;
      case 0x04:
        modeSense4(buf);
        DmaPort::sendDma(buf, 24);
        break;
      case 0x3f:
        buf[0] = 43;
        buf[1] = 0;
        buf[2] = blockDev->isWritable() ? 0x00 : 0x80;
        buf[3] = 0;
        modeSense4(buf + 4);
        modeSense0(buf + 28);
        DmaPort::sendDma(buf, 44);
        break;
      default:
        verboseHex("Invalid sense ", (int)cmdBuf[3], ' ');
        commandStatus(ERR_INVARG);
        return;
      }
      commandStatus(ERR_OK);
      break;
    }
  case 0x20: // Vendor-specific commands
    // Used by UltraSatan protocol emulation (used for RTC)
#if ACSI_RTC
    if(memcmp(&cmdBuf[1], "USCurntFW", 9) == 0) {
      verbose("USatan ");
      // Fake the firmware
      memcpy(buf, "ACSI2STM " ACSI2STM_VERSION "\r\n", 16);
      DmaPort::sendDma(buf, 16);
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "USRdClRTC", 9) == 0) {
      verbose("RTC read ");
      tm_t now;
      rtc.getTime(now);

      buf[0] = 'R';
      buf[1] = 'T';
      buf[2] = 'C';
      buf[3] = now.year - 30;
      buf[4] = now.month;
      buf[5] = now.day;
      buf[6] = now.hour;
      buf[7] = now.minute;
      buf[8] = now.second;

      DmaPort::sendDma(buf, 16);
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "USWrClRTC", 9) == 0) {
      verbose("RTC set ");

      DmaPort::readDma(buf, 9);

      if(buf[0] != 'R' || buf[1] != 'T' || buf[2] != 'C') {
        verbose("Wrong date ");
        commandStatus(ERR_INVARG);
        return;
      }

      tm_t now;
      now.year = buf[3] + 30;
      now.month = buf[4];
      now.day = buf[5];
      now.hour = buf[6];
      now.minute = buf[7];
      now.second = buf[8];

      rtc.setTime(now);
      commandStatus(ERR_OK);
      return;
    }
#endif

    dbg("Unknown command ");
    commandStatus(ERR_OPCODE);
    return;
  case 0x25: // Read capacity
    // Send the number of blocks of the SD card
    {
      uint32_t last = blockDev->blocks - 1;
      buf[0] = (last >> 24) & 0xFF;
      buf[1] = (last >> 16) & 0xFF;
      buf[2] = (last >> 8) & 0xFF;
      buf[3] = (last) & 0xFF;
      // Send the block size (which is always 512)
      buf[4] = 0x00;
      buf[5] = 0x00;
      buf[6] = 0x02;
      buf[7] = 0x00;
    }

    DmaPort::dmaStartDelay();
    DmaPort::sendDma(buf, 8);

    commandStatus(ERR_OK);
    break;
  case 0x28: // Read blocks
    {
      // Compute the block number
      uint32_t block = (((uint32_t)cmdBuf[2]) << 24) | (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual read operation
      commandStatus(processBlockRead(block, count), block);
    }
    break;
  case 0x2a: // Write blocks
    {
      // Compute the block number
      uint32_t block = (((uint32_t)cmdBuf[2]) << 24) | (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual write operation
      DmaPort::dmaStartDelay();
      commandStatus(processBlockWrite(block, count), block);
    }
    break;
  case 0x3b: // Write buffer
    {
      uint32_t offset = (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      uint32_t length = (((uint32_t)cmdBuf[6]) << 16) | (((uint32_t)cmdBuf[7]) << 8) | (uint32_t)(cmdBuf[8]);
      DmaPort::dmaStartDelay();
      if(cmdBuf[2] != 0) {
        verbose("Invalid buffer ", "id ");
        commandStatus(ERR_INVARG);
        return;
      }
      switch(cmdBuf[1]) {
      case 0x02: // Data buffer write
        dbg("Write buffer: offset=", offset, " length=", length, ' ');

        if(offset >= bufSize || offset + length > bufSize) {
          verbose("Out of range ");
          commandStatus(ERR_INVARG);
          return;
        }

        DmaPort::readDma(buf + offset, length);

        commandStatus(ERR_OK);
        return;
      case 0x05: // Firmware write (YAY !)
        if(offset || length > FLASH_SIZE) {
          verbose("Firmware too big ");
          commandStatus(ERR_INVARG);
          return;
        }

        dbg("Write firmware: length=", length, ' ');

        flashFirmware(length);
        // This function never returns !
      }
      verboseHex("Invalid mode ", cmdBuf[1], ' ');
      commandStatus(ERR_INVARG);
      return;
    }
  case 0x3c: // Read buffer
    {
      uint32_t offset = (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      uint32_t length = (((uint32_t)cmdBuf[6]) << 16) | (((uint32_t)cmdBuf[7]) << 8) | (uint32_t)(cmdBuf[8]);
      DmaPort::dmaStartDelay();
      switch(cmdBuf[1]) {
      case 0x00: // Descriptor + data read
        if(offset >= bufSize || offset + length > bufSize || length < 4) {
          dbg("Out of range ");
          commandStatus(ERR_INVARG);
          return;
        }

        // This is not 100% correct as it overwrites data instead of shifting it
        buf[offset] = 0;
        write24(&buf[offset + 1], bufSize);

      case 0x02: // Data buffer read
        if(cmdBuf[2] != 0) {
          verbose("Invalid buffer ");
          commandStatus(ERR_INVARG);
          return;
        }

        dbg("Read buffer: offset=", offset, " length=", length, ' ');

        if(offset >= bufSize || offset + length > bufSize) {
          dbg("Out of range ");
          commandStatus(ERR_INVARG);
          return;
        }

        DmaPort::sendDma(buf + offset, length);
        commandStatus(ERR_OK);
        return;
      case 0x03: // Data buffer descriptor read
        buf[0] = 0;

        write24(&buf[1], bufSize);

        DmaPort::sendDma(buf, 4);
        commandStatus(ERR_OK);
        return;
      }
      verboseHex("Invalid buffer ", "read ", cmdBuf[1], ' ');
      commandStatus(ERR_INVARG);
      return;
    }
  }
}

void Acsi::readCmdBuf(uint8_t cmd) {
  if(cmd == 0x1f)
    // ICD extended command marker
    DmaPort::readIrq(&cmdBuf[0], 1);
  else
    // The first byte was the command
    cmdBuf[0] = cmd;

  if(cmdBuf[0] >= 0xa0) {
    // 12 bytes command
    DmaPort::readIrq(&cmdBuf[1], 11);
    cmdLen = 12;
  } else if(cmdBuf[0] >= 0x80) {
    // 16 bytes command
    DmaPort::readIrq(&cmdBuf[1], 15);
    cmdLen = 16;
  } else if(cmdBuf[0] >= 0x20) {
    // 10 bytes command
    DmaPort::readIrq(&cmdBuf[1], 9);
    cmdLen = 10;
  } else {
    // 6 bytes command
    DmaPort::readIrq(&cmdBuf[1], 5);
    cmdLen = 6;
  }
}

bool Acsi::validLun() {
  return getLun() == 0;
}

int Acsi::getLun() {
  return cmdBuf[1] >> 5;
}

void Acsi::commandStatus(ScsiErr err, uint32_t block) {
  lastErr = err;
  lastBlock = block;
  lastSeek = true;
  sendCommandStatus();
}

void Acsi::commandStatus(ScsiErr err) {
  lastErr = err;
  lastSeek = false;
  sendCommandStatus();
}

void Acsi::sendCommandStatus() {
  if(lastErr == ERR_OK) {
    dbg("Success");
    DmaPort::sendIrq(0);
  } else {
    dbgHex("Error ", lastErr);
    DmaPort::sendIrq(2);
  }
}

Acsi::ScsiErr Acsi::processBlockRead(uint32_t block, int count) {
  dbg("Read ", count, " blocks from ", block, " on SD", blockDev.slot, ' ');

  if(block >= blockDev->blocks || block + count - 1 >= blockDev->blocks) {
    dbg("Out of range ");
    return ERR_INVADDR;
  }

  if(!blockDev->readStart(block)) {
    dbg("Read error ");
    return ERR_READERR;
  }

  for(int s = 0; s < count;) {
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    if(!blockDev->readData(buf, burst)) {
      dbg("Read error ");
      blockDev->readStop();
      return ERR_READERR;
    }
    DmaPort::sendDma(buf, ACSI_BLOCKSIZE * burst);

    s += burst;
  }

  blockDev->readStop();

  return ERR_OK;
}

Acsi::ScsiErr Acsi::processBlockWrite(uint32_t block, int count) {
  dbg("Write ", count, " blocks from ", block, " on SD", blockDev.slot, ' ');

#if ACSI_READONLY == 2
  for(int s = 0; s < count; ++s)
    DmaPort::readDma(buf, ACSI_BLOCKSIZE);
  return ERR_OK;
#else
  if(block >= blockDev->blocks || block + count - 1 >= blockDev->blocks) {
    dbg("Out of range ");
    return ERR_INVADDR;
  }

  if(!blockDev->isWritable())
    return ERR_WRITEPROT;

  if(!blockDev->writeStart(block)) {
    dbg("Write error ");
    return ERR_WRITEERR;
  }

  for(int s = 0; s < count;) {
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    DmaPort::readDma(buf, ACSI_BLOCKSIZE * burst);

    if(!blockDev->writeData(buf, burst)) {
      dbg("Write error ");
      blockDev->writeStop();
      return ERR_WRITEERR;
    }

    s += burst;
  }

  blockDev->writeStop();

  return ERR_OK;
#endif
}

void Acsi::modeSense0(uint8_t *outBuf) {
  // Returns a legacy mode page, following Hatari's behavior
  // No idea what kind of hard disk returned that.

  uint32_t blocks = blockDev->blocks;
  if(blocks > 0xffffff) {
    dbg("(truncated) ");
    blocks = 0xffffff;
  }
  for(uint8_t b = 0; b < 16; ++b)
    outBuf[b] = 0;

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

void Acsi::modeSense4(uint8_t *outBuf) {
  // Mode page 4, returning disk geometry

  uint32_t blocks = blockDev->blocks;
  int heads;
  int cylinders;
  for(heads = 255; heads >= 1; --heads) {
    cylinders = blocks / heads;
    if(cylinders > 0xffffff || (blocks % heads) == 0)
      break;
  }

  for(uint8_t b = 0; b < 24; ++b)
    outBuf[b] = 0;

  // Rigid drive geometry
  outBuf[0] = 4; // Page code
  outBuf[1] = 22; // Page length

  // Send the number of blocks in CHS format
  outBuf[2] = (cylinders >> 16) & 0xFF;
  outBuf[3] = (cylinders >> 8) & 0xFF;
  outBuf[4] = (cylinders) & 0xFF;
  outBuf[5] = heads;
}

// Static variables

int Acsi::cmdLen;
uint8_t Acsi::cmdBuf[16];

// vim: ts=2 sw=2 sts=2 et
