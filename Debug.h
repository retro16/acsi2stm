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
#ifndef DEBUG_H
#define DEBUG_H

#include "acsi2stm.h"

// Debug output functions

#if ACSI_DEBUG
template<typename T>
inline void acsiDbg(T txt) {
  ACSI_SERIAL.print(txt);
  ACSI_SERIAL.flush();
}

template<typename T, typename F>
inline void acsiDbg(T txt, F fmt) {
  ACSI_SERIAL.print(txt, fmt);
  ACSI_SERIAL.flush();
}

template<typename T>
inline void acsiDbgln(T txt) {
  ACSI_SERIAL.println(txt);
  ACSI_SERIAL.flush();
}

template<typename T, typename F>
inline void acsiDbgln(T txt, F fmt) {
  ACSI_SERIAL.println(txt, fmt);
  ACSI_SERIAL.flush();
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
}

static void acsiDbgDumpln(const uint8_t *data, int size, int maxSize = ACSI_DUMP_LEN) {
  acsiDbgDump(data, size, maxSize);
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

static void acsiDbgDumpln(const uint8_t *, int) {
}

static void acsiDbgDumpln(const uint8_t *, int, int) {
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

static void acsiVerboseDumpln(const uint8_t *data, int size, int maxSize = ACSI_DUMP_LEN) {
  acsiDbgDumpln(data, size, maxSize);
}
#else
template<typename ...T>
inline void acsiVerbose(T... txt) {
}

template<typename ...T>
inline void acsiVerboseln(T... txt) {
}

static void acsiVerboseDump(const uint8_t *data, int size, int maxSize = ACSI_DUMP_LEN) {
}

static void acsiVerboseDumpln(const uint8_t *data, int size, int maxSize = ACSI_DUMP_LEN) {
}
#endif

#endif
