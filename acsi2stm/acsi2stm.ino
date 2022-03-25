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

DmaPort dma;
Watchdog watchdog;

// ACSI device table
// Change this table to remap ACSI device IDs, SD CS pin and SD lock pin.
// Important: device IDs must be consecutive.
Acsi acsi[] = {
  Acsi(ACSI_FIRST_ID + 0, PA4, PB0, dma),
#if ACSI_SD_CARDS >= 2
  Acsi(ACSI_FIRST_ID + 1, PA3, PB1, dma),
#endif
#if ACSI_SD_CARDS >= 3
  Acsi(ACSI_FIRST_ID + 2, PA2, PB3, dma),
#endif
#if ACSI_SD_CARDS >= 4
  Acsi(ACSI_FIRST_ID + 3, PA1, PB4, dma),
#endif
#if ACSI_SD_CARDS >= 5
  Acsi(ACSI_FIRST_ID + 4, PA0, PB5, dma),
#endif
};
static const int sdCount = sizeof(acsi) / sizeof(acsi[0]);

// Main setup function
void setup() {
  Acsi::ledOn(); // Enable activity LED on power up to signal init activity.

#if ACSI_DEBUG
  Acsi::beginDbg(ACSI_SERIAL_SPEED);

  // Send a few characters to synchronize autoconfigured USB-serial dongles.
  Acsi::dbg("\n");
  delay(10);
  Acsi::dbg("\n");
  delay(10);

  Acsi::dbg("ACSI2STM SD bridge v" ACSI2STM_VERSION "\n\n");
  Acsi::flushDbg();
  delay(200);
#endif

  // Disable JTAG to allow using PB3, PB4 and PA15
  afio_cfg_debug_ports(AFIO_DEBUG_SW_ONLY);

  dma.begin();
  watchdog.begin();

  // Initialize the ACSI bridges
  for(int c = 0; c < sdCount; ++c)
    acsi[c].begin();

  Acsi::dbg("Waiting for the ACSI bus ...\n");
  dma.waitBusReady();

  Acsi::dbg("--- Ready to go ---\n");
}

// Main loop
void loop() {
  Acsi::ledOff();
  uint8_t cmd = dma.waitCommand();
  Acsi::ledOn();
  int deviceId = dma.cmdDeviceId(cmd);
#if ! ACSI_VERBOSE
  Acsi::dbg("ACSI", deviceId, ':');
#endif

  int deviceIndex = deviceId - ACSI_FIRST_ID;

  watchdog.resume();
  acsi[deviceIndex].process(dma.cmdCommand(cmd));
  watchdog.pause();
}

// vim: ts=2 sw=2 sts=2 et
