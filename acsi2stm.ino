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

// Requires the SdFat library by Bill Greiman

// Edit acsi2stm.h to change global values
#include "acsi2stm.h"

// SD card CS pin definitions
const int sdCs[] = {
  // List of SD card CS pins. CS pins must be on PA0 to PA4.
  // Use -1 to ignore an ID
  PA4, // ACSI ID 0
  PA3, // ACSI ID 1
  PA2, // ACSI ID 2
  PA1, // ACSI ID 3
  PA0, // ACSI ID 4
  -1,  // ACSI ID 5
  -1,  // ACSI ID 6
  -1,  // ACSI ID 7
};

// Includes
#include "Watchdog.h"
#include "Acsi.h"
#include "Ahdi.h"

// Globals

const int maxSd = sizeof(sdCs) / sizeof(sdCs[0]);
Watchdog watchdog;
Acsi acsi;
Ahdi ahdi[maxSd];

// Activity LED control functions

#ifdef ACTIVITY_LED
static inline void ledSet(int l) {
  digitalWrite(ACTIVITY_LED, !l);
  pinMode(ACTIVITY_LED, OUTPUT);
}
static inline void ledOn() {
  ledSet(1);
}
static inline void ledOff() {
  ledSet(0);
}
#else
static inline void ledOn() {
}
static inline void ledOff() {
}
static inline void ledSet(int l) {
}
#endif


// Main setup function
void setup() {
#if ACSI_DEBUG
  Serial.begin(115200); // Init the serial port only if needed

  // Send a few characters to synchronize autoconfigured USB-serial dongles.
  acsiDbgln("");
  delay(50);
  acsiDbgln("");
  delay(100);
#endif

  ledOn(); // Enable activity LED on power up to signal init activity.

  // Initialize the watchdog timer
  watchdog.begin();

  acsiDbgln("-----------------------");
  acsiDbgln("ACSI2STM SD bridge v" ACSI2STM_VERSION);
  acsiDbgln("-----------------------");
  acsiDbgln("");

  // Initialize the ACSI port
  acsi.begin();

  // Initialize AHDI bridges
  int sdCount = 0;
  for(int i = 0; i < maxSd; ++i) {
    watchdog.feed();
    if(sdCs[i] == -1)
      continue;
    acsi.addDevice(i);
    acsiDbg("Device ");
    acsiDbg(i);
    acsiDbg(':');
    if(ahdi[i].begin(i, sdCs[i], AHDI_MAX_BLOCKS)) {
      char str[64];
      ahdi[i].getDeviceString(str);
      // Replace atari logo
      if(str[22] == 0x0e) {
        sprintf(str+21, "ATARI BOOT");
      } else {
        str[24] = 0;
      }
      acsiDbg(str);
      acsiDbgln("");
      sdCount++;
    } else {
      acsiDbgln("unavailable");
    }
  }

  acsiDbg(sdCount);
  acsiDbgln(" SD cards found");

  acsiDbgln("Waiting for the ACSI bus");
  watchdog.pause();
  acsi.waitBusReady();
  delay(100); // Wait for the bus to stabilize
  watchdog.resume();

  acsiDbgln("");
  acsiDbgln("--- Ready to go ---");
  acsiDbgln("");
}

// Main loop
void loop() {
  watchdog.pause();
  ledOff();
  uint8_t cmd = acsi.waitCommand(); // Wait for the next command arriving in cmdBuf
  ledOn();
  watchdog.resume();
  uint8_t deviceId = acsi.cmdDeviceId(cmd); // Parse device id
  cmd = acsi.cmdCommand(cmd); // Parse command id
  acsiDbg("Device ");
  acsiDbg(deviceId);
  acsiDbg(" command ");
  acsiDbg(cmd, HEX);
  acsiDbg(" ");
  ahdi[deviceId].processCmd(cmd); // Process the command
}

// vim: ts=2 sw=2 sts=2 et
