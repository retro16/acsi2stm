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

#include "Devices.h"

#include "Acsi.h"
#include "BlockDev.h"
#include "GemDrive.h"

#include <libmaple/iwdg.h>

// SD slots table, with physical slot ID, SD CS pin and SD write protect pin
SdDev Devices::sdSlots[] = {
  SdDev(0, PA4, PB0),
#if ACSI_SD_CARDS >= 2
  SdDev(1, PA3, PB1),
#endif
#if ACSI_SD_CARDS >= 3
  SdDev(2, PA2, PB3),
#endif
#if ACSI_SD_CARDS >= 4
  SdDev(3, PA1, PB4),
#endif
#if ACSI_SD_CARDS >= 5
  SdDev(4, PA0, PB5),
#endif
};

// ACSI device table
Acsi Devices::acsi[] = {
  Acsi(sdSlots[0]),
#if ACSI_SD_CARDS >= 2
  Acsi(sdSlots[1]),
#endif
#if ACSI_SD_CARDS >= 3
  Acsi(sdSlots[2]),
#endif
#if ACSI_SD_CARDS >= 4
  Acsi(sdSlots[3]),
#endif
#if ACSI_SD_CARDS >= 5
  Acsi(sdSlots[4]),
#endif
};

#if ! ACSI_STRICT
// GemDrive device table
GemDrive Devices::drives[] = {
  GemDrive(sdSlots[0]),
#if ACSI_SD_CARDS >= 2
  GemDrive(sdSlots[1]),
#endif
#if ACSI_SD_CARDS >= 3
  GemDrive(sdSlots[2]),
#endif
#if ACSI_SD_CARDS >= 4
  GemDrive(sdSlots[3]),
#endif
#if ACSI_SD_CARDS >= 5
  GemDrive(sdSlots[4]),
#endif
};
#endif

void Devices::sense() {
#if ACSI_RTC
  FsDateTime::setCallback(getDateTime);
#endif
#if ! ACSI_STRICT && ! ACSI_PIO
  strict = digitalRead(PB2);
#endif

#if ACSI_ID_OFFSET_PINS && ! ACSI_FIRST_ID
  // Check if PA13 is set to VCC
  pinMode(PA13, INPUT_PULLDOWN);
  pinMode(PA14, INPUT);
  delay(1);
  if(digitalRead(PA13)) {
    acsiFirstId = 3;
    goto end;
  }
  pinMode(PA13, INPUT);
  pinMode(PA14, INPUT_PULLUP);
  delay(1);
  if(!digitalRead(PA14)) {
    acsiFirstId = 1;
    goto end;
  }
  pinMode(PA13, OUTPUT);
  digitalWrite(PA13, 0);
  if(!digitalRead(PA14)) {
    acsiFirstId = 2;
  }
end:
  pinMode(PA13, INPUT_PULLUP);
  pinMode(PA14, INPUT_PULLUP);
#endif

#if ! ACSI_STRICT
  GemDrive::closeAll();
#endif
  for(int c = 0; c < sdCount; ++c) {
    sdSlots[c].onReset();
#if ! ACSI_PIO
    acsi[c].onReset();
#endif
  }
}

int Devices::acsiDeviceMask = 0;
#if ! ACSI_STRICT
int Devices::gemDriveMask = 0;
int Devices::gemBootDrive = 8;

void Devices::updateGemBootDrive() {
  for(gemBootDrive = 0; gemBootDrive < 8; ++gemBootDrive)
    if(gemDriveMask & 1 << gemBootDrive)
      return;
}

void Devices::attachGemDrive(int slot) {
  gemDriveMask |= (1 << slot);
  updateGemBootDrive();
}
#endif

void Devices::attachAcsi(int slot) {
  acsiDeviceMask |= (1 << slot);
}

void Devices::detach(int slot) {
  acsiDeviceMask &= ~(1 << slot);
#if ! ACSI_STRICT
  gemDriveMask &= ~(1 << slot);
  updateGemBootDrive();
#endif
}

void Devices::getDateTime(uint16_t *date, uint16_t *time) {
  tm_t now;
  rtc.getTime(now);
  Monitor::verbose(now.year + 1970, '-', now.month, '-', now.day, ' ', now.hour, ':', now.minute, ':', now.second, ' ');
  *date = FS_DATE(now.year + 1970, now.month, now.day);
  *time = FS_TIME(now.hour, now.minute, now.second);
}

void Devices::setDateTime(uint16_t date, uint16_t time) {
  tm_t newDateTime;
  newDateTime.year = FS_YEAR(date) - 1970;
  newDateTime.month = FS_MONTH(date);
  newDateTime.day = FS_DAY(date);
  newDateTime.hour = FS_HOUR(time);
  newDateTime.minute = FS_MINUTE(time);
  newDateTime.second = FS_SECOND(time);

  Monitor::verbose("Setting date to ");
  rtc.setTime(newDateTime);
  Monitor::verbose(newDateTime.year + 1970, '-', newDateTime.month, '-', newDateTime.day, ' ', newDateTime.hour, ':', newDateTime.minute, ':', newDateTime.second, ' ');
}

bool Devices::isDateTimeSet() {
  tm_t now;
  rtc.getTime(now);
  return now.year > 1980 - 1970 && now.year < 2107 - 1970;
}

#if ! ACSI_STRICT
bool Devices::strict = false;
#endif
#if ACSI_ID_OFFSET_PINS
int Devices::acsiFirstId = ACSI_FIRST_ID;
#endif

uint8_t Devices::buf[ACSI_BLOCKSIZE * ACSI_BLOCKS];
RTClock Devices::rtc(RTCSEL_LSE);

int Devices::computeChecksum(uint8_t *block) {
  int checksum = 0;
  for(int i = 0; i < ACSI_BLOCKSIZE; i += 2)
    checksum += ((int)block[i] << 8) + (block[i+1]);

  return checksum & 0xffff;
}

void Devices::blocksToString(uint32_t blocks, char *target) {
  // Characters: 0123
  //            "213G"

  uint32_t sz = (blocks + 1) / 2;
  target[3] = 'K';
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

// vim: ts=2 sw=2 sts=2 et
