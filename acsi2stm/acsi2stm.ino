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

#include "acsi2stm.h"
#include "DmaPort.h"
#include "Watchdog.h"
#include "Acsi.h"
#include <libmaple/gpio.h>

// ACSI device table
// Change this table to remap ACSI device IDs, SD CS pin and SD lock pin.
// Important: device IDs must be consecutive.
Acsi acsi[] = {
  Acsi(ACSI_FIRST_ID + 0, PA4, PB0),
#if ACSI_SD_CARDS >= 2
  Acsi(ACSI_FIRST_ID + 1, PA3, PB1),
#endif
#if ACSI_SD_CARDS >= 3
  Acsi(ACSI_FIRST_ID + 2, PA2, PB3),
#endif
#if ACSI_SD_CARDS >= 4
  Acsi(ACSI_FIRST_ID + 3, PA1, PB4),
#endif
#if ACSI_SD_CARDS >= 5
  Acsi(ACSI_FIRST_ID + 4, PA0, PB5),
#endif
};
static const int sdCount = sizeof(acsi) / sizeof(acsi[0]);

static int deviceMask = 0;

// Main setup function
void setup() {
  // Disable JTAG to allow using PB3, PB4 and PA15
  // Remap TIM2 on PA15 to sense RST asynchronously
  AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_SW | AFIO_MAPR_TIM2_REMAP_FULL;

  Acsi::ledOn(); // Enable activity LED on power up to signal init activity.

#if ACSI_DEBUG
  Acsi::beginDbg();

  // Send a few characters to synchronize autoconfigured USB-serial dongles.
  Acsi::dbg("\n");
  delay(10);
  Acsi::dbg("\n");
  delay(100);

  Acsi::dbg("ACSI2STM SD bridge v" ACSI2STM_VERSION "\n\n");
  delay(200);
#endif

  Watchdog::begin();

  // Initialize the ACSI bridges
  for(int c = 0; c < sdCount; ++c)
    if(acsi[c].begin())
      deviceMask |= 1 << c;
}

// Main loop
void loop() {
  setjmp(DmaPort::resetJump);
  DmaPort::waitBusReady();

  for(;;) {
    Watchdog::pause();
    Acsi::ledOff();
    uint8_t cmd = DmaPort::waitCommand();
    Acsi::ledOn();
    Watchdog::resume();
    int deviceId = DmaPort::cmdDeviceId(cmd);

#if ! ACSI_VERBOSE
    Acsi::dbg("ACSI", deviceId, ':');
#endif

    int deviceIndex = deviceId - ACSI_FIRST_ID;
    if(deviceMask & (1 << deviceIndex)) {
      acsi[deviceIndex].process(DmaPort::cmdCommand(cmd));
    } else {
#if ! ACSI_VERBOSE
      Acsi::dbgHex(DmaPort::cmdCommand(cmd));
#endif
      Acsi::dbg(" - Not for us\n");
    }
  }
}

// vim: ts=2 sw=2 sts=2 et
