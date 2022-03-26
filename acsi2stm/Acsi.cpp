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

#include "Acsi.h"

#if ACSI_BOOT_OVERLAY && !ACSI_DUMMY_BOOT_SECTOR
#error ACSI_BOOT_OVERLAY requires ACSI_DUMMY_BOOT_SECTOR
#endif

#if ACSI_DUMMY_BOOT_SECTOR
const
#include "nosdcard.boot.h"
#endif

#if ACSI_BOOT_OVERLAY
const
#include "bootoverlay.boot.h"
#endif

// CRC function taken from SdFat's SdSpiCard.cpp
static uint16_t crc16(const uint8_t* data, size_t n) {
  uint16_t crc = 0;
  for (size_t i = 0; i < n; i++) {
    crc = (uint8_t)(crc >> 8) | (crc << 8);
    crc ^= data[i];
    crc ^= (uint8_t)(crc & 0xff) >> 4;
    crc ^= crc << 12;
    crc ^= (crc & 0xff) << 5;
  }
  return crc;
}

Acsi::Acsi(int deviceId_, int sdCs_, int sdWp_, DmaPort &dma_):
  dma(dma_),
  card(deviceId_, sdCs_, sdWp_) {}

Acsi::Acsi(Acsi &&other):
  dma(other.dma),
  card(other.card.deviceId, other.card.csPin, other.card.wpPin) {}

#if ACSI_RTC
void rtcInit() {}
#endif

void Acsi::begin() {
  // Read strict mode from the on-board BOOT1 jumper
  strict = digitalRead(PB2);

  // Check if the device is disabled (wpPin pin to VCC)
  pinMode(card.wpPin, INPUT_PULLDOWN);
  delay(1);
  if(digitalRead(card.wpPin)) {
    // wpPin pin to VCC: unit disabled
    pinMode(card.wpPin, INPUT);
    verbose("SD", card.deviceId, " disabled\n");
    card.deviceId = -1;
    return;
  }

  dbg("Initializing SD", card.deviceId, " ... ");
  dma.addDevice(card.deviceId);

#if ACSI_RTC
  // For whatever reason, this fixed my clock drift.
  rtc.attachSecondsInterrupt(rtcInit);
  rtc.detachSecondsInterrupt();
#endif

  // Initialize the SD card
  if(card.begin()) {
    dbg("success\n");
  } else {
    dbg("failed\n\n");
    return;
  }

  // Read media ID to check for media change
  mediaId = card.mediaId();
  mediaChecked();

  // Mount all LUNs
  mountLuns();

#if ACSI_DEBUG
  for(int l = 0; l < maxLun; ++l) {
    if(luns[l]) {
      luns[l]->getDeviceString((char *)buf);
      buf[24] = 0;
      dbg("  ", card.deviceId, ',', l, ": ", (const char *)buf, '\n');
    }
  }
#endif

  dbg('\n');
}

void Acsi::mountLuns() {
  int prefixLen = strlen(ACSI_IMAGE_FOLDER ACSI_LUN_IMAGE_PREFIX);

  // Detach all LUNs
  for(int l = 0; l < maxLun; ++l)
    luns[l] = nullptr;
  
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

  // Mount raw SD card on LUN0 if no image was found for that slot
  if(!luns[0] && card)
    luns[0] = &card;
}

void Acsi::process(uint8_t cmd) {
  if(cmd == 0x1f) {
    // Read extended command
    cmd = dma.readIrq();
  }

  if(!readCmdBuf(cmd)) {
    dbgHex("Unknown command\n");
    lastSeek = false;
    commandStatus(ERR_OPCODE);
    return;
  }

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
  default:
    if(!validLun()) {
      dbg("Invalid LUN\n");
      commandStatus(ERR_INVLUN);
      return;
    }

    // Handle media change
    if(!dev || hasMediaChanged()) {
      refresh();
      dev = luns[getLun()];
      if(dev) {
        // Recovered
        commandStatus(ERR_MEDIUMCHANGE);
        return;
      }
#if ACSI_DUMMY_BOOT_SECTOR
      else if(!strict
       && cmdBuf[0] == 0x08
       && cmdBuf[1] == 0x00
       && cmdBuf[2] == 0x00
       && cmdBuf[3] == 0x00
       && cmdBuf[4] == 0x01
       && cmdBuf[5] == 0x00
      ) {
        // Boot sector query: inject the dummy payload
        commandStatus(processDummyBootSector());
        return;
#endif
      }
      commandStatus(ERR_NOMEDIUM);
      return;
    }
    break;

  // Commands that need to be executed even if the card is not available
  case 0x00: // Test unit ready
  case 0x03: // Request sense
  case 0x12: // Inquiry
    {
      if(validLun()) {
        // Request sense does not always refresh, other commands do
        if(cmdBuf[0] != 0x03 || !dev || hasMediaChanged()) {
          if(refresh() == ERR_MEDIUMCHANGE) {
            commandStatus(ERR_MEDIUMCHANGE);
            return;
          }
          dev = luns[getLun()];
        }
      }
    }
    break;
#if ACSI_RTC
  case 0x20:
    // UltraSatan RTC has no LUN nor device access.
    break;
#endif
  case 0x3b: // Write buffer
  case 0x3c: // Read buffer
    break;
  }

  // Execute the command
  switch(cmdBuf[0]) {
  default: // Unknown command
    dbg("Unknown command\n");
    lastSeek = false;
    commandStatus(ERR_OPCODE);
    return;
  case 0x00: // Test unit ready
    commandStatus(!validLun() ? ERR_INVLUN : dev ? ERR_OK : ERR_NOMEDIUM);
    return;
  case 0x03: // Request Sense
    if(!validLun())
      lastErr = ERR_INVLUN;

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
      buf[2] = (lastErr >> 16) & 0xFF;
      buf[3] = (lastErr >> 8) & 0xFF;
      buf[7] = 14;
      buf[12] = (lastErr) & 0xFF;
      buf[19] = (lastBlock >> 16) & 0xFF;
      buf[20] = (lastBlock >> 8) & 0xFF;
      buf[21] = (lastBlock) & 0xFF;
    }
    // Send the response
    dma.sendDma(buf, cmdBuf[4]);
    
    commandStatus(ERR_OK);
    return;
  case 0x08: // Read block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

#if ACSI_BOOT_OVERLAY
    if(!strict && lastBlock == 0 && cmdBuf[4] == 1 && !dev->bootable) {
      commandStatus(processBootOverlay(dev));
      return;
    }
#endif

    // Do the actual read operation
    commandStatus(processBlockRead(lastBlock, cmdBuf[4], dev));
    break;
  case 0x0a: // Write block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    if(lastBlock == 0)
      dbg("WARNING: Write to boot sector\n");

    // Do the actual write operation
    commandStatus(processBlockWrite(lastBlock, cmdBuf[4], dev));
    break;
  case 0x0b: // Seek
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;
    if(lastBlock >= dev->blocks)
      commandStatus(ERR_INVADDR);
    else
      commandStatus(ERR_OK);
    break;
  case 0x12: // Inquiry
    // Adjust size to 4 if 0
    if(!cmdBuf[4])
      cmdBuf[4] = 4;

    // Fill the response with zero bytes
    for(uint8_t b = 0; b <= cmdBuf[4]; ++b)
      buf[b] = 0;

    if(!validLun()) {
      buf[0] = 0x7F; // Unsupported LUN
    } else {
      // Build the product string
      if(dev)
        dev->getDeviceString((char *)buf + 8);
      else
        card.getDeviceString((char *)buf + 8);
    }

    buf[1] = 0x80; // Removable flag
    buf[2] = 1; // ACSI version
    buf[4] = 31; // Data length

    dma.sendDma(buf, cmdBuf[4]);

    lastSeek = false;
    commandStatus(ERR_OK);
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
        commandStatus(ERR_INVARG);
        return;
      }
      commandStatus(ERR_OK);
      break;
    }
  case 0x20: // Vendor-specific commands
    // Used by:
    //  * UltraSatan protocol (used for RTC)
    //  * ACSI2STM command loopback test
#if ACSI_RTC
    if(memcmp(&cmdBuf[1], "USCurntFW", 9) == 0) {
      dbg("UltraSatan:");
      dbg("firmware version query\n");
      // Fake the firmware
      dma.sendDma((const uint8_t *)("ACSI2STM " ACSI2STM_VERSION "\r\n"), 16);
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "USRdClRTC", 9) == 0) {
      dbg("UltraSatan:");
      dbg("clock read\n");
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

      dma.sendDma(buf, 16);
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "USWrClRTC", 9) == 0) {
      dbg("UltraSatan:");
      dbg("clock set\n");

      dma.readDma(buf, 9);

      if(buf[0] != 'R' || buf[1] != 'T' || buf[2] != 'C') {
        dbg("Invalid date format\n");
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
    if(memcmp(&cmdBuf[1], "A2STCmdTs", 9) == 0) {
      dbg("ACSI2STM command test\n");
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "\0\0\0\0\0\0\0\0\0", 9) == 0) {
      dbg("ACSI2STM zero command test\n");
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "\xff\xff\xff\xff\xff\xff\xff\xff\xff", 9) == 0) {
      dbg("ACSI2STM 0xff command test\n");
      commandStatus(ERR_OK);
      return;
    }
    dbg("Unknown extended command\n");
    commandStatus(ERR_OPCODE);
    return;
  case 0x25: // Read capacity
    lastErr = refresh();
    if(lastErr != ERR_OK) {
      commandStatus(lastErr);
      return;
    }

    // Send the number of blocks of the SD card
    {
      uint32_t last = dev->blocks - 1;
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

    dma.sendDma(buf, 8);

    commandStatus(ERR_OK);
    break;
  case 0x28: // Read blocks
    {
      // Compute the block number
      uint32_t block = (((uint32_t)cmdBuf[2]) << 24) | (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual read operation
      commandStatus(processBlockRead(block, count, dev));
    }
    break;
  case 0x2a: // Write blocks
    {
      // Compute the block number
      uint32_t block = (((uint32_t)cmdBuf[2]) << 24) | (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      int count = (((int)cmdBuf[7]) << 8) | (cmdBuf[8]);

      // Do the actual write operation
      commandStatus(processBlockWrite(block, count, dev));
    }
    break;
  case 0x3b: // Write buffer
    {
      uint32_t offset = (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      uint32_t length = (((uint32_t)cmdBuf[6]) << 16) | (((uint32_t)cmdBuf[7]) << 8) | (uint32_t)(cmdBuf[8]);
      switch(cmdBuf[1]) {
      case 0x02: // Data buffer write
        if(!strict && cmdBuf[2] == 1) {
          if((offset & 0b11) || (length & 0b11)) {
            dbg("Invalid buffer length\n");
            commandStatus(ERR_INVARG);
            return;
          }
        } else if(cmdBuf[2] != 0) {
          dbg("Invalid buffer id\n");
          commandStatus(ERR_INVARG);
          return;
        }

        dbg("Write buffer: offset=", offset, " length=", length, '\n');

        if(offset >= bufSize || offset + length > bufSize) {
          dbg("Out of range\n");
          commandStatus(ERR_INVARG);
          return;
        }

        dma.readDma(buf + offset, length);

        if(cmdBuf[2]) {
          // Check that the write pattern matches
          bool error = false;
          for(int i = 0; i < 512; i += 4) {
            if(buf[offset + i] != 0xf0 || buf[offset + i + 1] != 0x0f || buf[offset + i + 2] != 0x55 || buf[offset + i + 3] != 0xaa) {
              verbose("Error at ", i, '\n');
              verboseDumpln(&buf[i],4);
              error = true;
            }
          }
          if(error) {
            commandStatus(ERR_WRITEERR);
            return;
          }
          verbose("Pattern matches\n");
        }
        commandStatus(ERR_OK);
        return;
      case 0x04: // Code execution
        dbg("Execute buffer\n");
        if(strict) {
          dbg("Disabled in strict mode\n");
          commandStatus(ERR_INVARG);
          return;
        }
        if(length > bufSize) {
          dbg("Out of range\n");
          commandStatus(ERR_INVADDR);
          return;
        }

        dma.readDma(buf, length);

        // Check CRC
        uint16_t crc = (((uint16_t)cmdBuf[4]) << 8) | (uint16_t)(cmdBuf[5]);
        if(crc == crc16(buf, length)) {
          // Acknowledge the exec before starting execution:
          // if the code crashes, at least the ACSI bus will be released.
          commandStatus(ERR_OK);

          dbg("Executing remote buffer:\n");

          // Execute the buffer
          ((void (*)())buf)();

          // Too dangerous to go on: simply reboot
          Watchdog::reboot();
        }

        dbgHex("Exec buffer CRC error\n");
        commandStatus(ERR_WRITEERR);
        return;
      }
      dbgHex("Invalid write buffer mode ", cmdBuf[1], '\n');
      commandStatus(ERR_INVARG);
      return;
    }
  case 0x3c: // Read buffer
    {
      uint32_t offset = (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      uint32_t length = (((uint32_t)cmdBuf[6]) << 16) | (((uint32_t)cmdBuf[7]) << 8) | (uint32_t)(cmdBuf[8]);
      switch(cmdBuf[1]) {
      case 0x02: // Data buffer read
        if(!strict && cmdBuf[2] == 1) {
          if((offset & 0b11) || (length & 0b11)) {
            dbg("Invalid buffer length\n");
            commandStatus(ERR_INVARG);
            return;
          }
        } else if(cmdBuf[2] != 0) {
          dbg("Invalid buffer id\n");
          commandStatus(ERR_INVARG);
          return;
        }

        dbg("Read buffer: offset=", offset, " length=", length, '\n');

        if(offset >= bufSize || offset + length > bufSize) {
          dbg("Out of range\n");
          commandStatus(ERR_INVARG);
          return;
        }

        dma.sendDma(buf + offset, length);
        commandStatus(ERR_OK);
        return;
      case 0x03: // Data buffer descriptor read
        if(cmdBuf[2])
          // Pattern match buffer has 4 bytes boundary
          buf[0] = 2;
        else
          buf[0] = 0;

        buf[1] = (uint8_t)(bufSize >> 16);
        buf[2] = (uint8_t)(bufSize >> 8);
        buf[3] = (uint8_t)(bufSize);

        dma.sendDma(buf, 4);
        commandStatus(ERR_OK);
        return;
      }
      dbgHex("Invalid read buffer mode ", cmdBuf[1], '\n');
      commandStatus(ERR_INVARG);
      return;
    }
  }

  if(lastErr == ERR_OK)
    mediaChecked();
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
  return lun >= 0 && lun < maxLun;
}

int Acsi::getLun() {
  return cmdBuf[1] >> 5;
}

void Acsi::commandStatus(ScsiErr err) {
  lastErr = err;
  if(lastErr == ERR_OK) {
    dbg("Success\n");
    dma.endTransaction(0);
  } else {
    dbgHex("Error ", lastErr, '\n');
    dma.endTransaction(2);
  }
}

Acsi::ScsiErr Acsi::refresh() {
  int lun = getLun();
  dbg("Refreshing ", card.deviceId, ',', lun, ":");
  mediaChecked();

  if(card.reset()) {
    uint32_t realId = card.mediaId();
    mountLuns();
    Watchdog::feed();
    if(realId != mediaId) {
      mediaId = realId;
      if(luns[lun]) {
        dbg("New SD card\n");
        return ERR_MEDIUMCHANGE;
      } else {
        dbg("New SD with no image\n");
        return ERR_NOMEDIUM;
      }
    }

    dbg("Device ready\n");
    return ERR_OK;
  }
  Watchdog::feed();

  dbg("No SD card\n");
  mediaId = 0;

  // Unmount all LUNs
  for(int l = 0; l < maxLun; ++l)
    luns[l] = nullptr;

  return ERR_NOMEDIUM;
}

Acsi::ScsiErr Acsi::processBlockRead(uint32_t block, int count, BlockDev *dev) {
  dbg("Read ", count, " blocks from ", block, " on ", card.deviceId, ',', getLun(), '\n');

  if(block >= dev->blocks || block + count - 1 >= dev->blocks) {
    dbg("Out of range\n");
    return ERR_INVADDR;
  }

  if(!dev->readStart(block)) {
    dbg("Read start error\n");
    return ERR_READERR;
  }

  for(int s = 0; s < count;) {
    Watchdog::feed();
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    if(!dev->readData(buf, burst)) {
      dbg("Read error\n");
      dev->readStop();
      return ERR_READERR;
    }
    dma.sendDma(buf, ACSI_BLOCKSIZE * burst);

    s += burst;
  }

  dev->readStop();

  return ERR_OK;
}

Acsi::ScsiErr Acsi::processBlockWrite(uint32_t block, int count, BlockDev *dev) {
  dbg("Write ", count, " blocks from ", block, " on ", card.deviceId, ',', getLun(), '\n');

#if ACSI_READONLY
#if ACSI_READONLY == 2
  for(int s = 0; s < count; ++s)
    dma.readDma(buf, ACSI_BLOCKSIZE);
  return ERR_OK;
#else
  return ERR_WRITEPROT;
#endif
#else

  if(block >= dev->blocks || block + count - 1 >= dev->blocks) {
    dbg("Out of range\n");
    return ERR_INVADDR;
  }

#if ACSI_BOOT_OVERLAY
  if(!strict && block == 0 && !dev->bootable) {
    // Check that we don't make the drive bootable by accident !
    if(memcmp(&buf[8], "ACSI2STM OVERLAY", 16) == 0) {
      // Erase the marker, making the checksum invalid
      bzero(&buf[8],16);
    }
  }
#endif

  if(!dev->writeStart(block)) {
    dbg("Write start error\n");
    return ERR_WRITEERR;
  }

  for(int s = 0; s < count;) {
    Watchdog::feed();
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    dma.readDma(buf, ACSI_BLOCKSIZE * burst);
    if(!dev->writeData(buf, burst)) {
      dbg("Write error\n");
      dev->writeStop();
      return ERR_WRITEERR;
    }

    s += burst;
  }

  dev->writeStop();

  return ERR_OK;
#endif
}

bool Acsi::hasMediaChanged() {
  if(millis() - mediaCheckTime < mediaCheckPeriod)
    return false;

  uint32_t cachedId = mediaId;
  uint32_t realId = card.mediaId();
  verboseHex("Check media: cached id=", cachedId, " real id=", realId, '\n');

  return cachedId != realId;
}

void Acsi::mediaChecked() {
  mediaCheckTime = millis();
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

int Acsi::computeChecksum(uint8_t *block) {
  int checksum = 0;
  for(int i = 0; i < ACSI_BLOCKSIZE; i += 2) {
    checksum += ((int)Acsi::buf[i] << 8) + (Acsi::buf[i+1]);
  }

  return checksum & 0xffff;
}

#if ACSI_DUMMY_BOOT_SECTOR
Acsi::ScsiErr Acsi::processDummyBootSector() {
  dbg("Sending test boot sector\n");
  memcpy(buf, nosdcard_boot_bin, nosdcard_boot_bin_len);
  patchBootSector(buf, nosdcard_boot_bin_len);
  dma.sendDma(buf, ACSI_BLOCKSIZE);
  return ERR_OK;
}

void Acsi::patchBootSector(uint8_t *data, int offset) {
  data[offset] = data[offset + 1] = 0;
  int checksum = 0x1234 - computeChecksum(data);
  data[offset] = (checksum >> 8) & 0xff;
  data[offset + 1] = checksum & 0xff;
}
#endif

#if ACSI_BOOT_OVERLAY
Acsi::ScsiErr Acsi::processBootOverlay(BlockDev *dev) {
  dbg("Overlay boot sector on ", card.deviceId, ',', getLun(), '\n');

  if(!dev->readStart(0)) {
    dbg("Read start error\n");
    return ERR_READERR;
  }

  Watchdog::feed();

  if(!dev->readData(buf, 1)) {
    dbg("Read error\n");
    dev->readStop();
    return ERR_READERR;
  }

  memcpy(buf, bootoverlay_boot_bin, bootoverlay_boot_bin_len);
  patchBootSector(buf, bootoverlay_boot_bin_len);

  dma.sendDma(buf, ACSI_BLOCKSIZE);

  dev->readStop();

  return ERR_OK;
}
#endif

// Static variables
bool Acsi::strict;
RTClock Acsi::rtc(RTCSEL_LSE);
int Acsi::cmdLen;
uint8_t Acsi::cmdBuf[16];
uint8_t Acsi::buf[Acsi::bufSize];

// vim: ts=2 sw=2 sts=2 et
