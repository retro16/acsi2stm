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

#ifndef SYSHOOK_H
#define SYSHOOK_H

#include "acsi2stm.h"

#include "DmaPort.h"
#include "Monitor.h"

// Atari structures

typedef uint8_t Byte;
typedef uint8_t ToByte;

struct Word {
  uint8_t bytes[2];
  Word() = default;
  Word(const Word& other) = default;
  Word& operator=(uint16_t value) {
    bytes[0] = (uint8_t)(value >> 8);
    bytes[1] = (uint8_t)(value);
    return *this;
  }
  Word& operator=(const Word& other) = default;
  Word& operator+=(uint16_t value) {
    *this = *this + value;
    return *this;
  }
  Word& operator-=(uint16_t value) {
    *this = *this - value;
    return *this;
  }
  Word& operator|=(uint16_t value) {
    *this = *this | value;
    return *this;
  }
  Word& operator&=(uint16_t value) {
    *this = *this & value;
    return *this;
  }
  Word& operator*=(uint16_t value) {
    *this = *this * value;
    return *this;
  }
  Word& operator/=(uint16_t value) {
    *this = *this / value;
    return *this;
  }
  Word& operator<<=(uint16_t value) {
    *this = *this << value;
    return *this;
  }
  Word& operator>>=(uint16_t value) {
    *this = *this >> value;
    return *this;
  }
  Word& operator++() {
    *this = *this + 1;
    return *this;
  }
  Word& operator--() {
    *this = *this - 1;
    return *this;
  }
  operator uint16_t() const {
    uint16_t value = ((uint16_t)bytes[0]) << 8
                   | ((uint16_t)bytes[1]);
    return value;
  }
};

struct ToWord: public Word {
  ToWord(const Word &value) {
    *(Word*)this = value;
  }
  ToWord(const ToWord &value) = default;
  ToWord(uint16_t value) {
    bytes[0] = (uint8_t)(value >> 8);
    bytes[1] = (uint8_t)(value);
  }
  ToWord(uint8_t b0, uint8_t b1) {
    bytes[0] = b0;
    bytes[1] = b1;
  }
  ToWord(int16_t value) : ToWord((uint16_t)value) {}
  ToWord(int8_t value) : ToWord((int16_t)value) {}
  ToWord(int value) : ToWord((uint16_t)value) {}
  ToWord(unsigned int value) : ToWord((uint16_t)value) {}
  ToWord(const uint8_t *bytes) : ToWord(bytes[0], bytes[1]) {}

  operator Word() {
    return *this;
  }
  operator uint16_t() const {
    uint16_t value = ((uint16_t)bytes[0]) << 8
                   | ((uint16_t)bytes[1]);
    return value;
  }
  void set(uint8_t *target) {
    target[0] = bytes[0];
    target[1] = bytes[1];
  }
};

struct Long {
  uint8_t bytes[4];
  Long() = default;
  Long(const Long& other) = default;
  Long& operator=(uint32_t value) {
    bytes[0] = (uint8_t)(value >> 24);
    bytes[1] = (uint8_t)(value >> 16);
    bytes[2] = (uint8_t)(value >> 8);
    bytes[3] = (uint8_t)(value);
    return *this;
  }
  Long& operator=(const Long& other) = default;
  Long& operator+=(uint32_t value) {
    *this = *this + value;
    return *this;
  }
  Long& operator-=(uint32_t value) {
    *this = *this - value;
    return *this;
  }
  Long& operator|=(uint32_t value) {
    *this = *this | value;
    return *this;
  }
  Long& operator|=(const Word &value) {
    bytes[2] = value.bytes[0];
    bytes[3] = value.bytes[1];
    return *this;
  }
  Long& operator&=(uint32_t value) {
    *this = *this & value;
    return *this;
  }
  Long& operator*=(uint32_t value) {
    *this = *this * value;
    return *this;
  }
  Long& operator/=(uint32_t value) {
    *this = *this / value;
    return *this;
  }
  Long& operator<<=(uint32_t value) {
    *this = *this << value;
    return *this;
  }
  Long& operator>>=(uint32_t value) {
    *this = *this >> value;
    return *this;
  }
  Long& operator++() {
    *this = *this + 1;
    return *this;
  }
  Long& operator--() {
    *this = *this - 1;
    return *this;
  }
  operator uint32_t() const {
    uint32_t value = ((uint32_t)bytes[0]) << 24
                   | ((uint32_t)bytes[1]) << 16
                   | ((uint32_t)bytes[2]) << 8
                   | ((uint32_t)bytes[3]);
    return value;
  }
  void set(uint8_t *target) {
    target[0] = bytes[0];
    target[1] = bytes[1];
    target[2] = bytes[2];
    target[3] = bytes[3];
  }
};

struct ToLong: public Long {
  ToLong(const Long &value) {
    *(Long*)this = value;
  }
  ToLong(const ToLong &value) = default;
  ToLong(uint32_t value) {
    bytes[0] = (uint8_t)(value >> 24);
    bytes[1] = (uint8_t)(value >> 16);
    bytes[2] = (uint8_t)(value >> 8);
    bytes[3] = (uint8_t)(value);
  }
  ToLong(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3) {
    bytes[0] = b0;
    bytes[1] = b1;
    bytes[2] = b2;
    bytes[3] = b3;
  }
  ToLong(int32_t value) : ToLong((uint32_t)value) {}
  ToLong(int16_t value): ToLong((int32_t)value) {}
  ToLong(int value) : ToLong((uint32_t)value) {}
  ToLong(unsigned int value) : ToLong((uint32_t)value) {}
  ToLong(const uint8_t *bytes) : ToLong(bytes[0], bytes[1], bytes[2], bytes[3]) {}

  operator Long() {
    return *this;
  }
  operator uint32_t() const {
    uint32_t value = ((uint32_t)bytes[0]) << 24
                   | ((uint32_t)bytes[1]) << 16
                   | ((uint32_t)bytes[2]) << 8
                   | ((uint32_t)bytes[3]);
    return value;
  }
};

// System hook protocol handlers
struct SysHook: public Monitor {
  // High level helper methods

  // Allocate bytes on the stack, set DMA to write onto the stack and return
  // the actual stack pointer after the shift
  static Long stackAlloc(int bytes);

  // Fixed address copy operations

  // Copy data to a target address
  static void sendAt(uint32_t address, const uint8_t *bytes, int count);

  template<typename T>
  static void sendAt(const T& value, uint32_t target) {
    sendAt(target, (const uint8_t *)&value, sizeof(T));
  }

  // Read bytes from a source address
  static void readAt(uint8_t *bytes, uint32_t source, int count);

  // Read a data structure at address
  template<typename T>
  static void readAt(T& value, uint32_t address) {
    readAt((uint8_t *)&value, address, sizeof(value));
  }

  // Read one byte at address
  static uint8_t readByteAt(ToLong address);

  // Read one byte at address
  static char readCharAt(ToLong address) {
    return (char)readByteAt(address);
  }

  // Read one word at address
  static Word readWordAt(ToLong address);

  // Read one long at address
  static Long readLongAt(ToLong address);

  // Read a zero-terminated string from a source address
  static void readStringAt(char *bytes, ToLong source, int count);

  // Clear memory
  static void clearAt(uint32_t bytes, uint32_t address);


  // DMA streaming helpers

  static void readDma(uint8_t *bytes, int count);
  static void readDmaString(char *bytes, int count);
  static void sendDma(const uint8_t *bytes, int count);

  // Send an object using DMA
  template<typename T>
  static void send(const T& value) {
    sendDma((uint8_t *)&value, sizeof(value));
  }

  // Read a data structure from the current DMA source address
  template<typename T>
  static void read(T& value) {
    readDma((uint8_t *)&value, sizeof(value));
  }

  // Read one byte from DMA
  static uint8_t readByte();

  // Read one byte from DMA
  static char readChar() {
    return (char)readByte();
  }

  // Read one word from DMA
  static Word readWord();

  // Read one long from DMA
  static Long readLong();

  // Indirect copy functions

  static void readAtIndirect(uint8_t *bytes, ToLong source, int count);
  static void readAtIndirectShort(uint8_t *bytes, ToLong source, int count);
  static void readStringAtIndirect(char *bytes, ToLong source, int count);

  // Hook commands

  // Return a 1 byte value
  static void rte(int8_t value = 0);

  // Forward the call to the next handler
  static void forward();

  // Execute Trap #1
  static void trap1();

  // Push SP on the stack.
  // Set DMA to read on the stack.
  static void pushSp();

  // Push word on the stack
  static void push(ToWord value);

  // Shift the stack pointer.
  // Set DMA to write on the stack.
  static void shiftStack(ToLong offset);

  // Read byte at address and push it on the stack.
  // Set DMA to read on the stack.
  static void readByteToStack(ToLong address);

  // Read word at address and push it on the stack.
  // Set DMA to read on the stack.
  static void readWordToStack(ToLong address);

  // Read long at address and push it on the stack
  // Set DMA to read on the stack.
  static void readLongToStack(ToLong address);

  // Pexec4 then rte
  static void pexec4ThenRte(ToLong pd);

  // Pexec6 then rte
  static void pexec6ThenRte(ToLong pd);

  // Setup DMA read
  static void setDmaRead(ToLong address);

  // Setup DMA write
  static void setDmaWrite(ToLong address);

  // Copy a sized buffer from the stack to an address
  static void copyFromStack(ToLong address);

  // Copy a sized buffer from an address to the stack
  static void copyToStack(ToLong address);

  // Return a 32-bit value
  static void rte(ToLong value);

  // Wait for a dummy command byte that indicates command completion
  static void waitCommand();

  // Send a command and wait for completion
  static void sendCommand(int command, ToLong param);

  // Send a command without waiting for completion
  static void sendCommandNoWait(int command, ToLong param);

  // Test for DMA-compatible memory
  static bool isDma(uint32_t address) {
#if ACSI_PIO
    return true;
#elif ACSI_GEMDRIVE_NO_DIRECT_DMA
    return false;
#else
    return address < dmatop;
#endif
  }

  // DMA-compatible range
  // This should be detected on real hardware because some Alt-RAM expansions
  // will break if they are in this range.
  static uint32_t dmatop;
};

// vim: ts=2 sw=2 sts=2 et
#endif
