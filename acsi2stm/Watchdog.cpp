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

#include "Watchdog.h"
#include <libmaple/iwdg.h>

void Watchdog::begin(int millis) {
  WATCHDOG_TIMER.pause();
  WATCHDOG_TIMER.setMode(TIMER_CH1, TIMER_OUTPUTCOMPARE);
  WATCHDOG_TIMER.setPrescaleFactor(36000);
  WATCHDOG_TIMER.setOverflow(65535);
  WATCHDOG_TIMER.setCompare(TIMER_CH1, millis * 2);
  WATCHDOG_TIMER.attachInterrupt(TIMER_CH1, Watchdog::reboot);
  WATCHDOG_TIMER.setCount(0);
  WATCHDOG_TIMER.refresh();
}

void Watchdog::reboot() {
  WATCHDOG_TIMER.pause();

  // Reset the whole STM32
  iwdg_init(IWDG_PRE_4, 1);
  iwdg_feed();
  for(;;);
}

// vim: ts=2 sw=2 sts=2 et
