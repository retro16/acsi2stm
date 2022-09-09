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
#include "Acsi.h"
#include <libmaple/gpio.h>

// ACSI device table
// Change this table to remap ACSI device IDs, SD CS pin and SD lock pin.
// Important: device IDs must be consecutive.
Acsi acsi[] = {
  Acsi(PA4, PB0),
#if ACSI_SD_CARDS >= 2
  Acsi(PA3, PB1),
#endif
#if ACSI_SD_CARDS >= 3
  Acsi(PA2, PB3),
#endif
#if ACSI_SD_CARDS >= 4
  Acsi(PA1, PB4),
#endif
#if ACSI_SD_CARDS >= 5
  Acsi(PA0, PB5),
#endif
};
static const int sdCount = sizeof(acsi) / sizeof(acsi[0]);

static int deviceMask = 0;

#if ACSI_ID_OFFSET_PINS
static int idOffset = 0;

void senseIdOffset() {
  // Check if PA13 is set to VCC
  pinMode(PA13, INPUT_PULLDOWN);
  pinMode(PA14, INPUT);
  delay(1);
  if(digitalRead(PA13)) {
    idOffset = 1;
    goto end;
  }
  pinMode(PA13, INPUT);
  pinMode(PA14, INPUT_PULLUP);
  delay(1);
  if(!digitalRead(PA14)) {
    idOffset = 3;
    goto end;
  }
  pinMode(PA13, OUTPUT);
  digitalWrite(PA13, 0);
  if(!digitalRead(PA14)) {
    idOffset = 2;
  }
end:
  pinMode(PA13, INPUT_PULLUP);
  pinMode(PA14, INPUT_PULLUP);
}
#endif

// Main setup function
void setup() {
#if ACSI_ID_OFFSET_PINS

#if ACSI_FIRST_ID
#error ACSI_FIRST_ID must be 0 to use ACSI_ID_OFFSET_PINS
#endif
  // Disable JTAG to allow using PB3, PB4, PA13, PA14 and PA15
  // Remap TIM2 on PA15 to sense RST asynchronously
  AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_NO_SW | AFIO_MAPR_TIM2_REMAP_FULL;
  senseIdOffset();
#else
  // Disable JTAG to allow using PB3, PB4 and PA15
  // Remap TIM2 on PA15 to sense RST asynchronously
  AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_SW | AFIO_MAPR_TIM2_REMAP_FULL;
#endif

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

  // Initialize the ACSI bridges
  for(int c = 0; c < sdCount; ++c)
    if(acsi[c].begin(
      c,
      ACSI_FIRST_ID + c
#if ACSI_ID_OFFSET_PINS
      + idOffset
#endif
    ))
      deviceMask |= 1 << c;
}

// Main loop
void loop() {
  setjmp(DmaPort::resetJump);
  DmaPort::waitBusReady();
  for(int c = 0; c < sdCount; ++c)
    acsi[c].reset();

  for(;;) {
    Acsi::ledOff();
    uint8_t cmd = DmaPort::waitCommand();
    Acsi::ledOn();
    int deviceId = DmaPort::cmdDeviceId(cmd);

#if ! ACSI_VERBOSE
    Acsi::dbg("ACSI", deviceId, ':');
#endif

    int deviceIndex = deviceId - ACSI_FIRST_ID
#if ACSI_ID_OFFSET_PINS
                               - idOffset
#endif
    ;
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
