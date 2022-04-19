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
#include "DmaPort.h"

#if !ACSI_STRICT

#if ACSI_DUMMY_BOOT_SECTOR
const
#include "nosdcard.boot.h"
#endif

#if ACSI_BOOT_OVERLAY
const
#include "overlay.boot.h"
const
#include "a2stdrv.boot.h"
#endif

const
#include "a2setup.boot.h"

#else

#if ACSI_DUMMY_BOOT_SECTOR
#warning ACSI_DUMMY_BOOT_SECTOR is disabled in strict mode
#endif
#if ACSI_BOOT_OVERLAY
#warning ACSI_BOOT_OVERLAY is disabled in strict mode
#endif

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

Acsi::Acsi(int sdCs_, int sdWp_):
  card(sdCs_, sdWp_) {}

Acsi::Acsi(Acsi &&other):
  card(other.card.csPin, other.card.wpPin) {}

#if ACSI_RTC
void rtcInit() {}
#endif

bool Acsi::begin(int deviceId) {
#if !ACSI_STRICT
  // Read strict mode from the on-board BOOT1 jumper
  strict = digitalRead(PB2);
#endif

  // Check if the device is disabled (wpPin pin to VCC)
  pinMode(card.wpPin, INPUT_PULLDOWN);
  delay(1);
  if(digitalRead(card.wpPin)) {
    // wpPin pin to VCC: unit disabled
    pinMode(card.wpPin, INPUT);
    verbose("SD", card.deviceId, " disabled\n");
    card.deviceId = -1;
    return false;
  }

  dbg("Initializing SD", card.deviceId, " ... ");

#if ACSI_RTC
  // For whatever reason, this fixed my clock drift.
  rtc.attachSecondsInterrupt(rtcInit);
  rtc.detachSecondsInterrupt();
#endif

  // Initialize the SD card
  if(card.begin(deviceId)) {
    dbg("success\n");
  } else {
    dbg("failed\n\n");
    return true;
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

  return true;
}

void Acsi::reset() {
  if(card.deviceId < 0)
    return;

  mediaCheckTime = millis();
  refresh(0);
  lastErr = ERR_OK;
}

void Acsi::mountLuns() {
  int prefixLen = strlen(ACSI_IMAGE_FOLDER "/" ACSI_LUN_IMAGE_PREFIX);

  // Detach all LUNs
  for(int l = 0; l < maxLun; ++l)
    luns[l] = nullptr;
  
  for(int l = 0; l < maxLun; ++l) {
    // Skip populated LUNs
    if(luns[l])
      continue;

    // Build the image file name
    strcpy((char *)buf, ACSI_IMAGE_FOLDER "/" ACSI_LUN_IMAGE_PREFIX);
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
    cmd = DmaPort::readIrq();
  }

  if(!readCmdBuf(cmd)) {
    dbg("Unknown command\n");
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
    refresh();
    if(validLun())
      dev = luns[getLun()];

#if ACSI_DUMMY_BOOT_SECTOR && !ACSI_STRICT
    if(!strict && mediaId == 0
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
    }
#endif
    if(lastErr) {
      commandStatus(lastErr);
      return;
    }
    if(!validLun()) {
      dbg("Invalid LUN\n");
      commandStatus(ERR_INVLUN);
      return;
    }
    break;

  // Commands that need to be executed even if the card is not available
  case 0x12: // Inquiry
    // Always refresh
    refresh();
    if(validLun())
      dev = luns[getLun()];

    break;
  case 0x03: // Request sense
  case 0x0c: // Single byte commands
  case 0x0d:
  case 0x0e:
  case 0x0f:
  case 0x20: // UltraSatan / ACSI2STM commands have no LUN
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
      buf[0] = (lastErr >> 8) & 0xFF;
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
      buf[2] = (lastErr) & 0xFF;
      buf[3] = (lastErr >> 16) & 0xFF;
      buf[7] = 14;
      buf[12] = (lastErr >> 8) & 0xFF;
      buf[19] = (lastBlock >> 16) & 0xFF;
      buf[20] = (lastBlock >> 8) & 0xFF;
      buf[21] = (lastBlock) & 0xFF;
    }
    // Send the response
    DmaPort::sendDma(buf, cmdBuf[4] < 4 ? 4 : cmdBuf[4]);
    
    commandStatus(ERR_OK);
    return;
  case 0x08: // Read block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

#if ACSI_BOOT_OVERLAY && !ACSI_STRICT
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

    DmaPort::sendDma(buf, cmdBuf[4]);

    lastSeek = false;

    // Do not overwrite lastErr
    dbg("Success\n");
    DmaPort::sendIrq(0);
    return;
  case 0x1a: // Mode sense
    {
      lastSeek = false;
      switch(cmdBuf[2]) { // Sub-command
      case 0x00:
        dev->modeSense0(buf);
        DmaPort::sendDma(buf, 16);
        break;
      case 0x04:
        dev->modeSense4(buf);
        DmaPort::sendDma(buf, 24);
        break;
      case 0x3f:
        buf[0] = 44;
        buf[1] = 0;
        buf[2] = 0;
        buf[3] = 0;
        dev->modeSense4(buf + 4);
        dev->modeSense0(buf + 28);
        DmaPort::sendDma(buf, 44);
        break;
      default:
        verboseHex("Error: unsupported mode sense ", (int)cmdBuf[3], '\n');
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
      verbose("UltraSatan:");
      verbose("firmware query\n");
      // Fake the firmware
      DmaPort::sendDma((const uint8_t *)("ACSI2STM " ACSI2STM_VERSION "\r\n"), 16);
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "USRdClRTC", 9) == 0) {
      verbose("UltraSatan:");
      verbose("clock read\n");
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
      verbose("UltraSatan:");
      verbose("clock set\n");

      DmaPort::readDma(buf, 9);

      if(buf[0] != 'R' || buf[1] != 'T' || buf[2] != 'C') {
        verbose("Invalid date\n");
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
    if(memcmp(&cmdBuf[1], "A2STFmtSd", 9) == 0) {
#if ACSI_READONLY
#if ACSI_READONLY == 2
      if(strict)
        commandStatus(ERR_WRITEPROT);
      else
        commandStatus(ERR_OK);
#else
      commandStatus(ERR_WRITEPROT);
#endif
#else
      if(!card.writable) {
        commandStatus(ERR_WRITEPROT);
        return;
      }

      verbose("ACSI2STM format SD\n");
      ExFatFormatter exFatFormatter;
      FatFormatter fatFormatter;
      verbose("Format started\n");

      // Start formatting
      // Return now so the ST can poll with inquiry
      commandStatus(ERR_OK);

      Watchdog::pause();
      card.blocks > 67108864 ?
        exFatFormatter.format(&card.card, buf):
        fatFormatter.format(&card.card, buf);
      Watchdog::resume();

      verbose("Format finished\n");
      mediaId = 0;
#endif
      return;
    }
    if(memcmp(&cmdBuf[1], "A2STCIm", 7) == 0) {
#if ACSI_READONLY
#if ACSI_READONLY == 2
      if(strict)
        commandStatus(ERR_WRITEPROT);
      else
        commandStatus(ERR_OK);
#else
      commandStatus(ERR_WRITEPROT);
#endif
#else
      if(!card.writable) {
        commandStatus(ERR_WRITEPROT);
        return;
      }

      verbose("ACSI2STM create image\n");

      if(!card.fsOpen) {
        verbose("No filesystem\n");
        commandStatus(ERR_WRITEERR);
        return;
      }

      auto &fs = card.fs;
      FsFile dir = fs.open(ACSI_IMAGE_FOLDER);
      if(!dir.isDirectory()) {
        if(!dir) {
          fs.mkdir(ACSI_IMAGE_FOLDER);
          dir = fs.open(ACSI_IMAGE_FOLDER);
          if(!dir) {
            verbose("Cannot create directory\n");
            commandStatus(ERR_WRITEERR);
            return;
          }
        } else {
          verbose(ACSI_IMAGE_FOLDER " is not a directory\n");
          commandStatus(ERR_WRITEERR);
          return;
        }
      }

      if(fs.exists(ACSI_IMAGE_FOLDER "/" ACSI_LUN_IMAGE_PREFIX "0" ACSI_LUN_IMAGE_EXT))
        fs.remove(ACSI_IMAGE_FOLDER "/" ACSI_LUN_IMAGE_PREFIX "0" ACSI_LUN_IMAGE_EXT);

      // Read image size in multiples of 64k
      uint32_t imgSize = (uint32_t)cmdBuf[8] << 24 | (uint32_t)cmdBuf[9] << 16;

      if(!imgSize) {
        // If size is 0, delete the file
        commandStatus(ERR_OK);
        return;
      }

      FsFile f = fs.open(ACSI_IMAGE_FOLDER "/" ACSI_LUN_IMAGE_PREFIX "0" ACSI_LUN_IMAGE_EXT, O_CREAT|O_RDWR);
      if(!f) {
        verbose("Cannot create image\n");
        commandStatus(ERR_WRITEERR);
        return;
      }

      // Image created.
      // Return now so the ST can poll with inquiry
      commandStatus(ERR_OK);

      uint32_t fsize = (uint32_t)f.fileSize();
      f.seekEnd();
      bzero(buf, bufSize);
      while(fsize < imgSize - bufSize) {
        Watchdog::feed();
        if(f.write(buf, bufSize)) {
          fsize += bufSize;
        } else {
          verbose("Cannot write image\n");
          return;
        }
      }
      if(fsize < imgSize) {
        Watchdog::feed();
        if(!f.write(buf, imgSize - fsize)) {
          verbose("Cannot write image\n");
          return;
        }
      }

      f.close();

      mediaId = 0;
#endif
      return;
    }
    if(memcmp(&cmdBuf[1], "A2STCmdTs", 9) == 0) {
      verbose("ACSI2STM command test\n");
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "\0\0\0\0\0\0\0\0\0", 9) == 0) {
      verbose("ACSI2STM zero command test\n");
      commandStatus(ERR_OK);
      return;
    }
    if(memcmp(&cmdBuf[1], "\xff\xff\xff\xff\xff\xff\xff\xff\xff", 9) == 0) {
      verbose("ACSI2STM 0xff command test\n");
      commandStatus(ERR_OK);
      return;
    }
    dbg("Unknown command\n");
    commandStatus(ERR_OPCODE);
    return;
  case 0x25: // Read capacity
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

    DmaPort::sendDma(buf, 8);

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
#if !ACSI_STRICT
        if(!strict && cmdBuf[2] == 1) {
          if((offset & 0b11) || (length & 0b11)) {
            verbose("Invalid buffer length\n");
            commandStatus(ERR_INVARG);
            return;
          }
        }
        else
#endif
        if(cmdBuf[2] != 0) {
          verbose("Invalid buffer id\n");
          commandStatus(ERR_INVARG);
          return;
        }

        dbg("Write buffer: offset=", offset, " length=", length, '\n');

        if(offset >= bufSize || offset + length > bufSize) {
          dbg("Out of range\n");
          commandStatus(ERR_INVARG);
          return;
        }

        DmaPort::readDma(buf + offset, length);

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
#if !ACSI_STRICT
      case 0x04: // Code execution
        dbg("Execute buffer\n");
        if(strict) {
          verbose("Disabled in strict mode\n");
          commandStatus(ERR_INVARG);
          return;
        }
        if(length > bufSize) {
          dbg("Out of range\n");
          commandStatus(ERR_INVADDR);
          return;
        }

        DmaPort::readDma(buf, length);

        // Check CRC
        uint16_t crc = (((uint16_t)cmdBuf[4]) << 8) | (uint16_t)(cmdBuf[5]);
        if(crc == crc16(buf, length)) {
          // Acknowledge the exec before starting execution:
          // if the code crashes, at least the ACSI bus will be released.
          commandStatus(ERR_OK);

          // Execute the buffer
          ((void (*)())buf)();

          // Too dangerous to go on: simply reboot
          Watchdog::reboot();
        }

        verbose("Exec buffer CRC error\n");
        commandStatus(ERR_WRITEERR);
        return;
#endif
      }
      verboseHex("Invalid buffer mode ", cmdBuf[1], '\n');
      commandStatus(ERR_INVARG);
      return;
    }
  case 0x3c: // Read buffer
    {
      uint32_t offset = (((uint32_t)cmdBuf[3]) << 16) | (((uint32_t)cmdBuf[4]) << 8) | (uint32_t)(cmdBuf[5]);
      uint32_t length = (((uint32_t)cmdBuf[6]) << 16) | (((uint32_t)cmdBuf[7]) << 8) | (uint32_t)(cmdBuf[8]);
      switch(cmdBuf[1]) {
      case 0x02: // Data buffer read
#if !ACSI_STRICT
        if(!strict && cmdBuf[2] == 1) {
          if((offset & 0b11) || (length & 0b11)) {
            verbose("Invalid buffer length\n");
            commandStatus(ERR_INVARG);
            return;
          }
        }
        else
#endif
        if(cmdBuf[2] != 0) {
          verbose("Invalid buffer id\n");
          commandStatus(ERR_INVARG);
          return;
        }

        dbg("Read buffer: offset=", offset, " length=", length, '\n');

        if(offset >= bufSize || offset + length > bufSize) {
          dbg("Out of range\n");
          commandStatus(ERR_INVARG);
          return;
        }

        DmaPort::sendDma(buf + offset, length);
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

        DmaPort::sendDma(buf, 4);
        commandStatus(ERR_OK);
        return;
      }
      verboseHex("Invalid read buffer mode ", cmdBuf[1], '\n');
      commandStatus(ERR_INVARG);
      return;
    }
#if !ACSI_STRICT && ACSI_BOOT_OVERLAY
  case 0x0c:
    DmaPort::sendDma(a2setup_boot_bin, a2setup_boot_bin_len);
    commandStatus(ERR_OK);
    return;
  case 0x0d:
    DmaPort::sendDma(a2stdrv_boot_bin, a2stdrv_boot_bin_len);
    commandStatus(ERR_OK);
    return;
#endif
  }

  if(lastErr == ERR_OK)
    mediaChecked();
}

bool Acsi::readCmdBuf(uint8_t cmd) {
  if(cmd == 0x1f)
    // ICD extended command marker
    DmaPort::readIrq(cmdBuf, 1);
  else
    // The first byte was the command
    cmdBuf[0] = cmd;

#if !ACSI_STRICT
  // Single byte commands specific to ACSI2STM
  if(!strict && cmdBuf[0] >= 0x0c && cmdBuf[0] <= 0x0f) {
    cmdLen = 1;
    return true;
  }
#endif

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
    cmdBuf[0] = cmd;
    DmaPort::readIrq(&cmdBuf[1], 5);
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
    DmaPort::sendIrq(0);
  } else {
    dbgHex("Error ", lastErr, '\n');
    DmaPort::sendIrq(2);
  }
}

void Acsi::refresh(int lun) {
  if(!hasMediaChanged())
    return;

  dbg("Refreshing ", card.deviceId, ',', lun, ':');
  mediaChecked();

  if(card.reset()) {
    uint32_t realId = card.mediaId();
    mountLuns();
    Watchdog::feed();
    mediaId = realId;
    if(luns[lun]) {
      dbg("New SD card\n");
      lastErr = ERR_MEDIUMCHANGE;
    } else {
      dbg("New SD with no image\n");
      lastErr = ERR_NOMEDIUM;
    }

    dbg("Device ready\n");
    return;
  }
  Watchdog::feed();

  dbg("No SD card\n");
  mediaId = 0;

  // Unmount all LUNs
  for(int l = 0; l < maxLun; ++l)
    luns[l] = nullptr;

  lastErr = ERR_NOMEDIUM;
}

Acsi::ScsiErr Acsi::processBlockRead(uint32_t block, int count, BlockDev *dev) {
  dbg("Read ", count, " blocks from ", block, " on ", card.deviceId, ',', getLun(), '\n');

  if(block >= dev->blocks || block + count - 1 >= dev->blocks) {
    dbg("Out of range\n");
    return ERR_INVADDR;
  }

  if(!dev->readStart(block)) {
    dbg("Read error\n");
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
    DmaPort::sendDma(buf, ACSI_BLOCKSIZE * burst);

    s += burst;
  }

  dev->readStop();

  return ERR_OK;
}

Acsi::ScsiErr Acsi::processBlockWrite(uint32_t block, int count, BlockDev *dev) {
  dbg("Write ", count, " blocks from ", block, " on ", card.deviceId, ',', getLun(), '\n');

#if ACSI_READONLY
#if ACSI_READONLY == 2 && !ACSI_STRICT
  if(strict)
    return ERR_WRITEPROT;
  for(int s = 0; s < count; ++s)
    DmaPort::readDma(buf, ACSI_BLOCKSIZE);
  return ERR_OK;
#else

#if ACSI_READONLY == 2
#warning ACSI_READONLY falls back to mode 1 if strict mode is enabled
#endif

  return ERR_WRITEPROT;
#endif
#else

  if(block >= dev->blocks || block + count - 1 >= dev->blocks) {
    dbg("Out of range\n");
    return ERR_INVADDR;
  }

  if(!dev->writeStart(block)) {
    dbg("Write error\n");
    return ERR_WRITEERR;
  }

  if(!block)
    // Refresh media if altering the boot sector
    mediaId = 0;

  for(int s = 0; s < count;) {
    Watchdog::feed();
    int burst = ACSI_BLOCKS;
    if(burst > count - s)
      burst = count - s;

    DmaPort::readDma(buf, ACSI_BLOCKSIZE * burst);

#if !ACSI_STRICT && ACSI_BOOT_OVERLAY
    if(!strict && block == 0 && s == 0)
      fixOverlayWrite(dev);
#endif

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
  if(millis() < mediaCheckTime)
    return false;

  uint32_t cachedId = mediaId;
  uint32_t realId = card.mediaId();
  verboseHex("Check media: cached id=", cachedId, " real id=", realId, '\n');

  mediaChecked();

  return cachedId != realId || !realId;
}

void Acsi::mediaChecked() {
  mediaCheckTime = millis() + mediaCheckPeriod;
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

#if ACSI_DUMMY_BOOT_SECTOR && !ACSI_STRICT
Acsi::ScsiErr Acsi::processDummyBootSector() {
  verbose("Sending nosdcard boot sector\n");
  memcpy(buf, nosdcard_boot_bin, nosdcard_boot_bin_len);
  patchBootSector(buf, nosdcard_boot_bin_len);
  DmaPort::sendDma(buf, ACSI_BLOCKSIZE);
  return ERR_OK;
}
#endif

#if !ACSI_STRICT && (ACSI_DUMMY_BOOT_SECTOR || ACSI_BOOT_OVERLAY)
void Acsi::patchBootSector(uint8_t *data, int offset) {
  data[offset] = data[offset + 1] = 0;
  int checksum = 0x1234 - computeChecksum(data);
  data[offset] = (checksum >> 8) & 0xff;
  data[offset + 1] = checksum & 0xff;
}
#endif

#if ACSI_BOOT_OVERLAY && !ACSI_STRICT
Acsi::ScsiErr Acsi::processBootOverlay(BlockDev *dev) {
  dbg("Overlay boot sector on ", card.deviceId, ',', getLun(), '\n');

  if(!dev->readStart(0)) {
    dbg("Read error\n");
    return ERR_READERR;
  }

  Watchdog::feed();

  if(!dev->readData(buf, 1)) {
    dbg("Read error\n");
    dev->readStop();
    return ERR_READERR;
  }

  // Overlay bra.b instruction to boot org
  buf[0x00] = 0x60;
  buf[0x01] = bootOrg - 2;

  // Overlay alloc sizes
  memcpy(&buf[bootOrg - 4], &a2stdrv_boot_bin[4], 4);

  // Overlay boot loader
  memcpy(&buf[bootOrg], overlay_boot_bin, overlay_boot_bin_len);

  // Make it bootable
  patchBootSector(buf, bootOrg - 6);

  DmaPort::sendDma(buf, ACSI_BLOCKSIZE);

  dev->readStop();

  return ERR_OK;
}

void Acsi::fixOverlayWrite(BlockDev *dev) {
  // Check that we don't rewrite the overlay by accident !
  if(memcmp(&buf[bootOrg], overlay_boot_bin, overlay_boot_bin_len) == 0) {
    if(dev->readStart(0)) {
      verbose("Merging FAT and MBR\n");

      // Save the new FAT header and partition table
      uint8_t fatHeader[0x58];
      uint8_t partTable[ACSI_BLOCKSIZE - 440];
      memcpy(fatHeader, &buf[2], sizeof(fatHeader));
      memcpy(partTable, &buf[440], sizeof(partTable));

      // Read the old boot sector
      if(dev->readData(buf, 1)) {
        // Patch in the new FAT header and partition table to the old boot sector
        memcpy(&buf[2], fatHeader, sizeof(fatHeader));
        memcpy(&buf[440], partTable, sizeof(partTable));
        if(dev->bootable) {
          if(computeChecksum(buf) != 0x1234) {
            if(buf[510] == 0x55 && buf[511] == 0xaa) {
              // Try to patch in the checksum at offset 438 (risky, but whatever ...)
              dbg("Patching MS-DOS boot sector\n");
              patchBootSector(buf, 438);
            } else {
              patchBootSector(buf, 510);
            }
          }
        }
      }

      dev->readStop();
    }
  }
}
#endif

// Static variables

#if ACSI_RTC
RTClock Acsi::rtc(RTCSEL_LSE);
#endif
#if !ACSI_STRICT
bool Acsi::strict;
#endif
int Acsi::cmdLen;
uint8_t Acsi::cmdBuf[16];
uint8_t Acsi::buf[Acsi::bufSize];

// vim: ts=2 sw=2 sts=2 et
