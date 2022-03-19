/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
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
#ifndef ACSI_DEBUG_H
#define ACSI_DEBUG_H

#include <Arduino.h>
#include "acsi2stm.h"

// Activity LED control functions

class AcsiDebug {
public:

#ifdef ACSI_ACTIVITY_LED
  static void ledSet(int l) {
    digitalWrite(ACSI_ACTIVITY_LED, !l);
    pinMode(ACSI_ACTIVITY_LED, OUTPUT);
  }
  static void ledOn() {
    ledSet(1);
  }
  static void ledOff() {
    ledSet(0);
  }
#else
  static void ledOn() {
  }
  static void ledOff() {
  }
  static void ledSet(int l) {
  }
#endif

// Debug output functions

  static void beginDbg(int speed) {
#if ACSI_DEBUG
    ACSI_SERIAL.begin(speed);
#endif
  }

  static void flushDbg() {
#if ACSI_DEBUG
    ACSI_SERIAL.flush();
#endif
  }

  template<typename T>
  static void dbg(T txt) {
#if ACSI_DEBUG
    ACSI_SERIAL.print(txt);
    ACSI_SERIAL.flush();
#endif
  }

  template<typename T, typename... More>
  static void dbg(T txt, More... more) {
    dbg(txt);
    dbg(more...);
  }

  template<typename... T>
  static void verbose(T... txt) {
#if ACSI_VERBOSE
    dbg(txt...);
#endif
  }

  template<typename T>
  static void dbgHex(T txt) {
#if ACSI_DEBUG
    ACSI_SERIAL.print(txt, HEX);
    ACSI_SERIAL.flush();
#endif
  }

  static void dbgHex(char txt) {
    dbg(txt);
  }

  static void dbgHex(const char *txt) {
    dbg(txt);
  }

  template<typename T, typename... More>
  static void dbgHex(T txt, More... more) {
    dbgHex(txt);
    dbgHex(more...);
  }

  template<typename... T>
  static void verboseHex(T... txt) {
#if ACSI_VERBOSE
    dbgHex(txt...);
#endif
  }

  static void dump(const void *data_, int size, int maxSize = ACSI_DUMP_LEN) {
#if ACSI_DEBUG
    const uint8_t *data = (const uint8_t *)data_;
    dbg("(", size, " bytes)");

    if(maxSize) {
      int dumpSize = size;
      if(maxSize > 0 && maxSize < size)
        dumpSize = maxSize;

      dbg(':');
      for(int i = 0; i < dumpSize; ++i)
        dbgHex(' ', data[i]);

      if(size > maxSize)
        dbg(" [...]");
    }
#endif
  }

  static void verboseDump(const void *data_, int size, int maxSize = ACSI_DUMP_LEN) {
#if ACSI_VERBOSE
    dump(data_, size, maxSize);
#endif
  }

  static void dumpln(const void *data_, int size, int maxSize = ACSI_DUMP_LEN) {
#if ACSI_DEBUG
    dump(data_, size, maxSize);
    dbg('\n');
#endif
  }

  static void verboseDumpln(const void *data_, int size, int maxSize = ACSI_DUMP_LEN) {
#if ACSI_VERBOSE
    dumpln(data_, size, maxSize);
#endif
  }
};

#endif
