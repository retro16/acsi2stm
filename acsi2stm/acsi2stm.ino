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
#endif

  // Delay to stabilize SD cards power
  delay(100);
}

#if ACSI_DEBUG && ACSI_STACK_CANARY
void __attribute__ ((noinline)) checkCanary() {
  // Total 32-bit words to allocate on the stack
  static const uint32_t stackWords = ACSI_STACK_CANARY / 4;

  // Number of words that must not be clobbered
  static const int canaryWords = stackWords / 4;

  // Allocate canaries on the stack
  volatile uint32_t canary[stackWords];

  // Check canaries.
  // Canaries are more packed on top of the stack than at the bottom.
  for(int i = 1; i <= canaryWords; i *= 2) {
    if(canary[canaryWords - i - 1] != 0xdeadbeef) {
      canary[canaryWords - i - 1] = 0xdeadbeef;
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
        Monitor::dbg("Ignore non-boot");
      else if(cmd == 0x1f)
        // Extended commands allow accessing the device in ACSI mode while
        // keeping it reasonably hidden from other tools.
        // Can be used for example to probe the device using INQUIRY, testing
        // with READ BUFFER or flashing firmware with WRITE BUFFER.
        // Warning: don't alter the SD card while it is mounted !
        Devices::acsi[deviceIndex].process(cmd);
      else
        // Handles GEMDOS trap as well as boot sector loader
        GemDrive::process(cmd);
      Monitor::dbg('\n');
    } else
#endif
    if(mask & SdDev::acsiDeviceMask) {
#if ! ACSI_VERBOSE
      Monitor::dbg("ACSI", deviceId, ':');
#endif
      Devices::acsi[deviceIndex].process(cmd);
      Monitor::dbg('\n');
    } else {
#if ! ACSI_VERBOSE
      Monitor::dbg("ACSI", deviceId, ':');
      Monitor::dbgHex(cmd);
#endif
      Monitor::dbg(" Not for us\n");
    }
  }
}

// vim: ts=2 sw=2 sts=2 et
