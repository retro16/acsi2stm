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

#ifndef ACSI2STM_H
#define ACSI2STM_H

#include <Arduino.h>

// acsi2stm global configuration

#define ACSI2STM_VERSION "2.0"

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// Number of bytes per DMA transfer to dump in verbose mode
// Set to 0 to disable data dump
#define ACSI_DUMP_LEN 16

// Set to 1 to make all SD cards readonly (returns an error if writing)
// Set to 2 to ignore writes silently (returns OK but does not actually write)
#define AHDI_READONLY 0

// Set this to limit SD capacity artificially.
// Set to ~0 if you don't want any limit
#define AHDI_MAX_BLOCKS ~0 // No limit
//#define AHDI_MAX_BLOCKS 0x0FFFFF // 512MB limit

// Activity LED pin. Leave undefined to remove activity LED.
#define ACTIVITY_LED LED_BUILTIN

// Hard disk image file name. It can be placed in a subfolder.
#define IMAGE_FILE_NAME "/acsi2stm.img"

// Debug output functions

#if ACSI_DEBUG
template<typename T>
inline void acsiDbg(T txt) {
  Serial.print(txt);
  Serial.flush();
}
template<typename T, typename F>
inline void acsiDbg(T txt, F fmt) {
  Serial.print(txt, fmt);
  Serial.flush();
}
template<typename T>
inline void acsiDbgln(T txt) {
  Serial.println(txt);
  Serial.flush();
}
template<typename T, typename F>
inline void acsiDbgln(T txt, F fmt) {
  Serial.println(txt, fmt);
  Serial.flush();
}
static void acsiDbgDump(const uint8_t *data, int size, int maxSize = ACSI_DUMP_LEN) {
  acsiDbg('(');
  acsiDbg(size);
  acsiDbg(" bytes)");

  if(maxSize) {
    int dumpSize = size;
    if(maxSize > 0 && maxSize < size)
      dumpSize = maxSize;

    acsiDbg(':');
    for(int i = 0; i < dumpSize; ++i) {
      acsiDbg(' ');
      acsiDbg(data[i], HEX);
    }

    if(size > maxSize)
      acsiDbg(" [...]");
  }
  acsiDbgln("");
}
#else
template<typename T>
inline void acsiDbg(T txt) {
}
template<typename T, typename F>
inline void acsiDbg(T txt, F fmt) {
}
template<typename T>
inline void acsiDbgln(T txt) {
}
template<typename T, typename F>
inline void acsiDbgln(T txt, F fmt) {
}
static void acsiDbgDump(const uint8_t *, int) {
}
static void acsiDbgDump(const uint8_t *, int, int) {
}
#endif

// Verbose output
#if ACSI_VERBOSE
template<typename ...T>
inline void acsiVerbose(T... txt) {
  acsiDbg(txt...);
}
template<typename ...T>
inline void acsiVerboseln(T... txt) {
  acsiDbgln(txt...);
}
static void acsiVerboseDump(const uint8_t *data, int size, int maxSize = ACSI_DUMP_LEN) {
  acsiDbgDump(data, size, maxSize);
}
#else
template<typename ...T>
inline void acsiVerbose(T... txt) {
}
template<typename ...T>
inline void acsiVerboseln(T... txt) {
}
static void acsiVerboseDump(const uint8_t *, int) {
}
#endif

// vim: ts=2 sw=2 sts=2 et
#endif
