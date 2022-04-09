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

#ifndef DMA_PORT_H
#define DMA_PORT_H

struct DmaPort {
  static const int A1 = PB6; // Must be on port B
  static const int CS = PB7; // Must be on port B
  static const int IRQ = PA8;
  static const int DRQ = PA11; // Must be on Timer1 channel output
  static const int ACK = PA12; // Must be on Timer1 external clock
  // Data pins are on PB8-PB15

  // Pin masks for direct port access
  static const int A1_MASK  = 0b0000000001000000;
  static const int CS_MASK  = 0b0000000010000000;
  static const int IRQ_MASK = 0b0000000100000000;
  static const int DRQ_MASK = 0b0000100000000000;
  static const int ACK_MASK = 0b0001000000000000;

  void begin();

  // Add a device to the list of allowed devices
  void addDevice(int id);

  // Remove a device from the list of allowed devices
  void removeDevice(int id);

  // Return true if the ACSI bus is idle:
  // IRQ, DRQ and ACK are high.
  static bool idle();

  // Wait until the bus is ready.
  // Uses input pull-down to detect that the ST is actually powered on.
  static void waitBusReady();

  // Return true if a new command is available
  bool checkCommand();

  // Read the buffered command.
  // Returns -1 if the command was not for us
  int readCommand();

  // Wait for a new command and return its first byte
  uint8_t waitCommand();

  // Returns the device id for a given command byte
  static uint8_t cmdDeviceId(uint8_t cmd) {
    return cmd >> 5;
  }

  // Returns the actual command for a given command byte.
  // Filter out device id.
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
  static void readDma(uint8_t *bytes, int count);

  // Send bytes using the DRQ/ACK method.
  static void sendDma(const uint8_t *bytes, int count);

  // Send the status byte and start listening for A1.
  static void endTransaction(uint8_t statusByte);

  // Start listening for the next A1 pulse.
  static void endTransaction();

protected:
  // Low level pin manipulation methods
  static void releaseRq();
  static void releaseDataBus();
  static void releaseBus();
  static void acquireDrq();
  static void acquireDataBus();
  static uint8_t waitCs();
  static bool readAck();
  static void pullIrq();
  static bool pullDrqUntilAck();
  static void writeData(uint8_t byte);
  static void disableAckFilter();
  static void enableAckFilter();

  // Device initialization
  static void setupDrqTimer();
  static void setupCsTimer();
  static void setupAckDmaTransfer();
  static void setupGpio();

  int deviceMask;
};

// vim: ts=2 sw=2 sts=2 et
#endif
