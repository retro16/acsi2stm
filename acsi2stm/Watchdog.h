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

#ifndef WATCHDOG_H
#define WATCHDOG_H

#include <Arduino.h>

#define WATCHDOG_TIMER Timer2

// Timer-based watchdog
struct Watchdog {
  static void begin(int millis = 2500);
  static void feed() {
    WATCHDOG_TIMER.setCount(0);
  }
  static void pause() {
    WATCHDOG_TIMER.pause();
  }
  static void resume() {
    feed();
    WATCHDOG_TIMER.resume();
  }

  static void reboot();
};

// vim: ts=2 sw=2 sts=2 et
#endif
