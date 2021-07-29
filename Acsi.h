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

#ifndef ACSI_H
#define ACSI_H

#include "Watchdog.h"

// SD card block size
#define ACSI_BLOCKSIZE 512

struct Acsi {
  static void init();
  void begin(uint8_t deviceMask = 0);

  // Add a device ID to the mask
  void addDevice(int id) {
    deviceMask |= 1<<id;
  }

  // Remove a device ID from the mask
  void removeDevice(int id) {
    deviceMask &=~ (1<<id);
  }

  // Return true if the ACSI bus is idle:
  // IRQ, DRQ and ACK are high.
  static bool idle();

  // Wait until the bus is ready.
  // Uses input pull-down to detect that the ST is actually powered on.
  static void waitBusReady();

  // Wait for a command on the bus.
  //
  // The mask is the device bit mask. Set bits 0 to 7 to receive commands for the corresponding device id.
  // Bits set to 0 will ignore commands for the corresponding devices.
  //
  // This function never times out and never fails.
  // Returns the command byte. You can use cmdDeviceId and cmdCommand to parse it.
  static uint8_t waitCommand(uint8_t mask);
  uint8_t waitCommand() {
    return waitCommand(deviceMask);
  }

  // Returns the device ID for a given command byte.
  static uint8_t cmdDeviceId(uint8_t cmd) {
    return cmd >> 5;
  }

  // Returns the actual command for a given command byte.
  static uint8_t cmdCommand(uint8_t cmd) {
    return cmd & 0b00011111;
  }

  // Read bytes using the IRQ/CS method.
  static void readIrq(uint8_t *bytes, int count);

  // Read one byte using the IRQ/CS method.
  static uint8_t readIrq();

  // Send one byte using the IRQ/CS method.
  // This is normally used for the status byte.
  static void sendIrq(uint8_t byte);

  // Read bytes using the DRQ/ACK method.
  // count must be a multiple of 16.
  static void readDma(uint8_t *bytes, int count);

  // Send bytes using the DRQ/ACK method.
  // count must be a multiple of 16.
  static void sendDma(const uint8_t *bytes, int count);

protected:
  // Low level pin manipulation methods
  static void releaseRq();
  static void releaseDataBus();
  static void releaseBus();
  static void acquireDrq();
  static void acquireDataBus();
  static uint8_t waitCs();
  static uint8_t waitA1();
  static bool readAck();
  static void pullIrq();
  static bool pullDrqUntilAck();
  static void writeData(uint8_t byte);

  // Device initialization
  static void setupDrqTimer();
  static void setupCsTimer();
  static void setupAckDmaTransfer();
  static void setupGpio();

  uint8_t deviceMask;
};

// vim: ts=2 sw=2 sts=2 et
#endif
