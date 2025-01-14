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

#ifndef DMA_PORT_H
#define DMA_PORT_H

#include "acsi2stm.h"

#include <setjmp.h>

struct DmaPort {
  friend struct SysHook;
  friend void flashFirmware(uint32_t);

  static const unsigned int PORT_TIMEOUT = 100*2; // Timeout in half ms
  static const int A1 = PB6; // Must be on port B
  static const int CS = PB7; // Must be on port B

  // Pin masks for direct port access
  static const int A1_MASK  = 0b0000000001000000;
  static const int CS_MASK  = 0b0000000010000000;
  static const int IRQ_MASK = 0b0000000100000000;
  static const int DRQ_MASK = 0b0000100000000000;
  static const int ACK_MASK = 0b0001000000000000;
  static const int RST_MASK = 0b1000000000000000;

  // Setup the bus and wait until the bus is ready.
  // Uses input pull-down to detect that the ST is actually powered on.
  // WARNING: this function is longjmp'ed to when RST is detected.
  // Call it only directly in the loop() function and nowhere else.
  static void waitBusReady();

  // Return true if a new command is available
  static bool checkCommand();

  // Read the buffered command.
  // Retriggers timers to read a new value on A1 or CS.
  static uint8_t readCommand();

  // Wait for a new command and return its first byte
  // Equivalent to calling checkReset and checkCommand in a loop,
  // then calling readCommand.
  static uint8_t waitCommand();

  // Read bytes using the IRQ/CS method.
  static void readIrq(uint8_t *bytes, int count);

  // Read one byte using the IRQ/CS method.
  static uint8_t readIrq();

  // Send one byte using the IRQ/CS method.
  // This is normally used for the status byte.
  static void sendIrq(uint8_t byte);

  // Send many bytes using the fast IRQ/CS method.
  // This is used for the GEMDOS protocol.
  static void sendIrqFast(const uint8_t *bytes, int count);

  // Repeat a byte using the fast IRQ/CS method.
  // This is used for the GEMDOS protocol.
  static void repeatIrqFast(uint8_t byte, int count);

  // Read many bytes using the fast IRQ/CS method.
  static void readIrqFast(uint8_t *bytes, int count);

  // Read bytes using the DRQ/ACK method.
  static void readDma(uint8_t *bytes, int count);

  // Read a zero-terminated string using the DRQ/ACK method.
  static void readDmaString(char *bytes, int count);

  // Send bytes using the DRQ/ACK method.
  // WARNING: data must be in RAM, flash is not fast enough.
  static void sendDma(const uint8_t *bytes, int count);

  // Fill memory with a byte value.
  static void fillDma(uint8_t byte, int count);

  // Returns the device id for a given command byte.
  static uint8_t cmdDeviceId(uint8_t cmd) {
    return cmd >> 5;
  }

  // Returns the actual command for a given command byte.
  // Filter out device id.
  static uint8_t cmdCommand(uint8_t cmd) {
    return cmd & 0b00011111;
  }

  // longjmp to this target if reset is detected
  static jmp_buf resetJump;

  // Delay between receiving a command and switching to DMA.
  // Can be tuned with ACSI_DMA_START_DELAY in acsi2stm.h
  static void dmaStartDelay() {
#if ACSI_DMA_START_DELAY
    delay_us(ACSI_DMA_START_DELAY);
#endif
  }


protected:
  // Reset timeout timer
  static void resetTimeout();

  // Check if the RST line was pulled or if there is a timeout.
  // Long jumps to waitBusReady if RST was pulled.
  // Call this in all active wait loops.
  static void checkReset();

  // Setup GPIO pins in a neutral state
  static void setupGpio();

  // Setup the reset detecting and timeout timers
  static void setupResetTimer();

  // Setup CS_TIMER and its DMA channels
  // Handles CS and CS+A1 cycles
  static void setupCsTimer();

  // Setup DMA_TIMER and its DMA channel
  // Handles DRQ/ACK cycles
  static void setupDrqTimer();

  // Setup GPIO copy on DMA cycle
  static void enableDmaRead();
  static void disableDmaRead();

  // Quick reset: reset GPIO and jump to the waitBusReady call
  static void quickReset();

  // Return true if the bus is completely idle
  static bool idle();

  // Setup the hardware to read incoming data on the next A1 pulse
  static void armA1();

  // Setup the hardware to read incoming data on the next CS pulse
  static void armCs();

  // Pulls the IRQ line low
  static void pullIrq();

  // Release the IRQ and DRQ lines and wait until the bus is idle
  static void releaseRq();

  // Returns true if the IRQ signal is up
  static bool irqUp();

  // Wait until IRQ goes back up. Short timeout.
  static void waitIrqUp();

  // Returns true if the CS and A1 signals are high (inactive)
  static bool csUp();

  // Wait until CS and A1 are high (inactive)
  static void waitCsUp();

  // Returns true if a CS transfer cycle has finished
  static bool checkCs();

  // Wait until a CS transfer has happened
  static void waitCs();

  // Return the byte read during a CS cycle
  static uint8_t csData();

  // Reset DMA transfer flag pulled by a DRQ/ACK cycle
  static void armDma();

  // Setup DRQ as output and enable automatic handling of DRQ/ACK and DMA
  static void acquireDrq();

  // Pull DRQ low. It will go back high as soon as ACK goes low.
  static void triggerDrq();
  
  // Returns true if data is available following a DRQ/ACK cycle
  static bool checkDma();

  // Return the byte read during the DRQ/ACK cycle
  static uint8_t dmaData();

  // Return true if a DRQ/ACK cycle was completed
  static bool ackReceived();

  // Disable ACK filter
  static void disableAckFilter();

  // Enable ACK filter
  // Sets the filter value at ACSI_ACK_FILTER
  static void enableAckFilter();

  // Set DATA pins as output
  static void acquireDataBus();

  // Write a byte on the DATA pins
  static void writeData(uint8_t byte);

  // Release DATA pins output and switch them back to input mode
  static void releaseDataBus();
};

// vim: ts=2 sw=2 sts=2 et
#endif
