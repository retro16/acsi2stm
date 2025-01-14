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

#ifndef DEVICES_H
#define DEVICES_H

#include "acsi2stm.h"

#include <RTClock.h>

// ACSI protocol block size
#define ACSI_BLOCKSIZE 512

struct SdDev;
struct Acsi;
#if ! ACSI_STRICT
struct GemDrive;
#endif

// Globals associated to devices and configuration
struct Devices {
  static SdDev sdSlots[];
  static Acsi acsi[];
#if ! ACSI_STRICT
  static GemDrive drives[];
#endif

  // Sense jumper settings
  static void sense();

  static const int sdCount = ACSI_SD_CARDS;
  static int acsiDeviceMask;
#if ! ACSI_STRICT
  static int gemDriveMask;
  static int gemBootDrive; // Set to 8 if no boot drive
  static void updateGemBootDrive();
  static void attachGemDrive(int slot);
#endif

  static void attachAcsi(int slot);
  static void detach(int slot);

  // Realtime clock
  static RTClock rtc;
  static void getDateTime(uint16_t *date, uint16_t *time);
  static void setDateTime(uint16_t date, uint16_t time);
  static bool isDateTimeSet();

#if ACSI_STRICT
  static const bool strict = true;
#else
  // When true, all SD cards behave like ACSI hard drives
  static bool strict;
#endif

#if ACSI_ID_OFFSET_PINS

#if ACSI_FIRST_ID
#error ACSI_FIRST_ID must be 0 to use ACSI_ID_OFFSET_PINS
#endif
  static int acsiFirstId;

#else

#if ACSI_FIRST_ID + ACSI_SD_CARDS > 7
#error ACSI_FIRST_ID is too high, the last SD card would be unreachable
#endif
  static const int acsiFirstId = ACSI_FIRST_ID;

#endif

  // Common data buffer
  static const int bufSize = ACSI_BLOCKSIZE * ACSI_BLOCKS;
  static uint8_t buf[bufSize];

  // Compute the 16 bits checksum of a block.
  static int computeChecksum(uint8_t *block);

  // Output a human-readable string of a block count.
  // Updates the 4 first bytes of target.
  static void blocksToString(uint32_t blocks, char *target);
};

// vim: ts=2 sw=2 sts=2 et
#endif
