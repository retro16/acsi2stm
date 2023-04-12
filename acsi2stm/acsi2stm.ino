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
#include "Monitor.h"
#include "Devices.h"
#include "GemDrive.h"
#include <libmaple/gpio.h>

#if ACSI_STRICT && ACSI_GEMDOS_SNIFFER
#error ACSI_GEMDOS_SNIFFER and ACSI_STRICT are mutually exclusive.
#endif

// Main setup function
void setup() {
#if ACSI_ID_OFFSET_PINS
  // Disable JTAG to allow using PB3, PB4, PA13, PA14 and PA15
  // Remap TIM2 on PA15 to sense RST asynchronously
  AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_NO_SW | AFIO_MAPR_TIM2_REMAP_FULL;
#else
  // Disable JTAG to allow using PB3, PB4 and PA15
  // Remap TIM2 on PA15 to sense RST asynchronously
  AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_SW | AFIO_MAPR_TIM2_REMAP_FULL;
#endif

  Monitor::ledOn(); // Enable activity LED on power up to signal init activity.

#if ACSI_DEBUG
  Monitor::beginDbg();

  // Send a few characters to synchronize autoconfigured USB-serial dongles.
  Monitor::dbg("\n\n");
  delay(150);
  Monitor::dbg("\n\n");
  delay(50);

  Monitor::dbg("ACSI2STM SD bridge v" ACSI2STM_VERSION "\n\n");
  delay(20);
#endif

}

#if ACSI_STACK_CANARY
#if ! ACSI_DEBUG
#warning Stack canary is probably useless without ACSI_DEBUG
#endif
void __attribute__ ((noinline)) checkCanary() {
  volatile uint32_t canary[ACSI_STACK_CANARY / 4];
  for(int i = 1; i < ACSI_STACK_CANARY / 16; i *= 2) {
    if(canary[i - 1] != 0xdeadbeef) {
      canary[i - 1] = 0xdeadbeef;
      Monitor::dbg("Stack canary ", i, " died. Reviving.\n");
    }
  }
}
#endif

// Main loop
void loop() {
  setjmp(DmaPort::resetJump);
  Devices::sense();
  DmaPort::waitBusReady();

  for(;;) {
#if ACSI_DEBUG && ACSI_STACK_CANARY
    checkCanary();
#endif

    Monitor::ledOff();
    uint8_t cmd = DmaPort::waitCommand();
    Monitor::ledOn();

    // Parse command and device
    int deviceId = DmaPort::cmdDeviceId(cmd);
    int deviceIndex = deviceId - Devices::acsiFirstId;
    int mask = 1 << deviceIndex;
    cmd = DmaPort::cmdCommand(cmd);

    // Dispatch command byte
#if ! ACSI_STRICT
    if(mask & SdDev::gemDriveMask) {
#if ! ACSI_VERBOSE
      Monitor::dbgHex("GDRV", deviceId, ':', cmd, ' ');
#endif
      if(cmd == 0x08 && deviceIndex != SdDev::gemBootDrive)
        Monitor::dbg("not the boot device\n");
      else
        GemDrive::process(cmd);
    } else
#endif
    if(mask & SdDev::acsiDeviceMask) {
#if ! ACSI_VERBOSE
      Monitor::dbg("ACSI", deviceId, ':');
#endif
      Devices::acsi[deviceIndex].process(cmd);
    } else {
#if ! ACSI_VERBOSE
      Monitor::dbg("ACSI", deviceId, ':');
      Monitor::dbgHex(cmd);
#endif
      Monitor::dbg(" - Not for us\n");
    }
  }
}

// vim: ts=2 sw=2 sts=2 et
