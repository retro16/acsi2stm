/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2025 by Jean-Matthieu Coulon
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

#include "Monitor.h"

#include <libmaple/gpio.h>

#if ACSI_PIO && ACSI_STRICT
#error Cannot implement ACSI protocol in PIO mode
#endif

// Use a class to run initialization before constructing other globals
struct PreBoot {
  PreBoot() {
    Monitor::ledOn(); // Enable activity LED on power up to signal init activity.
#if ACSI_ID_OFFSET_PINS
    // Disable JTAG to allow using PB3, PB4, PA13, PA14 and PA15
    // Remap TIM2 on PA15 to sense RST asynchronously
    AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_NO_SW | AFIO_MAPR_TIM2_REMAP_FULL;
#else
    // Disable JTAG to allow using PB3, PB4 and PA15
    // Remap TIM2 on PA15 to sense RST asynchronously
    AFIO_BASE->MAPR = AFIO_MAPR_SWJ_CFG_NO_JTAG_SW | AFIO_MAPR_TIM2_REMAP_FULL;
#endif
  }
};
PreBoot preBoot;

#include "Acsi.h"
#include "Devices.h"
#include "DmaPort.h"
#include "GemDrive.h"

void setup() {
    // Delay to let signals stabilize
    delay(5);

#if ACSI_DEBUG
    Monitor::beginDbg();

    // Delay for connecting serial monitor
    delay(50);

    Monitor::dbg("\n\n",
      "ACSI2STM " ACSI2STM_VERSION " by Jean-Matthieu Coulon", "\n",
      "GPLv3 license. Source & doc at", "\n",
      " https://github.com/retro16/acsi2stm", "\n");

#endif
}

#if ACSI_DEBUG && ACSI_STACK_CANARY
void __attribute__ ((noinline)) checkCanary() {
  // Total 32-bit words to allocate on the stack
  static const uint32_t stackWords = ACSI_STACK_CANARY / 4;

  // Number of words that must not be clobbered
  static const int canaryWords = stackWords / 4;

  // Allocate canaries on the stack
  volatile uint32_t canary[stackWords];

  int revived = 0;

  // Check canaries.
  // Canaries are more packed on top of the stack than at the bottom.
  for(int i = canaryWords; i > 1; i /= 2) {
    if(canary[i - 2] != 0xdeadbeef) {
      canary[i - 2] = 0xdeadbeef;
      revived = i - 2;
    }
  }

  if(revived)
    Monitor::dbgHex("Canary @", (uint32_t)(&canary[0]), " revived ", revived, "/", canaryWords - 1, " revived\n");
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
    if(deviceIndex == SdDev::gemBootDrive) {
#if ! ACSI_VERBOSE
      Monitor::dbgHex("GDRV", deviceId, ':', cmd, ' ');
#endif
#if ! ACSI_PIO
      if(cmd == 0x1f)
        // Extended commands allow accessing the device in ACSI mode while
        // keeping it reasonably hidden from other tools.
        // Can be used for example to probe the device using INQUIRY, testing
        // with READ BUFFER or flashing firmware with WRITE BUFFER.
        // Warning: don't alter the SD card while it is mounted !
        Devices::acsi[deviceIndex].process(cmd);
      else
#endif
      // Handles GEMDOS trap as well as boot sector loader
      GemDrive::process(cmd);
      Monitor::dbg('\n');
    } else
#endif
#if ! ACSI_PIO
    if(mask & SdDev::acsiDeviceMask) {
#if ! ACSI_VERBOSE
      Monitor::dbg("ACSI", deviceId, ':');
#endif
      Devices::acsi[deviceIndex].process(cmd);
      Monitor::dbg('\n');
    } else {
#if ! ACSI_VERBOSE
      Monitor::dbg("UNKN", deviceId, ':');
      Monitor::dbgHex(cmd);
#endif
      Monitor::dbg(" Not for us\n");
    }
#else
    {} // PIO can't handle ACSI
#endif
  }
}

// vim: ts=2 sw=2 sts=2 et
