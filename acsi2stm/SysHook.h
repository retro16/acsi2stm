/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2023 by Jean-Matthieu Coulon
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

#include "Monitor.h"
#include "DmaPort.h"

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
  // Offsets in the "programs" assembly file
  // This must match offsets in asm/programs/boot.s
  enum Program {
    PGM_NOP,
    PGM_TRAP,
    PGM_PUSHSP,
    PGM_ADDSP,
    PGM_READSPB,
    PGM_READSPW,
    PGM_READSPL,
    PGM_WRITESPB,
    PGM_WRITESPW,
    PGM_WRITESPL,
  };

  static Long getProgram(Program p);

#if ACSI_VERBOSE
  // Debug function
  static void pstack();
#else
  static void pstack() {}
#endif

  // High level helper methods

  // Shift the stack pointer and set DMA to read onto the stack
  static void shiftStack(ToWord offset);

  // Push an object onto the stack, with a 16 bytes aligned padding below
  template<typename T>
  static void push(const T& t) {
    push((uint8_t *)&t, sizeof(t));
  }

  // Push data onto the stack, with 16 bytes aligned padding below
  static void push(uint8_t *bytes, int count);

  // Unwind stack for an object of the given size, with 16 bytes padding
  template<typename T>
  static void pop(const T& t) {
    (void)t;
    int sz = sizeof(t);
    if(sz & 0xf)
      sz += 16 - (sz & 0xf);
    shiftStack(sz);
  }

  // Allocate bytes on the stack, set DMA to write onto the stack and return
  // the actual stack pointer after the shift
  static Long stackAlloc(int16_t bytes);

  // Call a trap and return D0
  static void trap(int number);


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

  // Send an object using DMA
  template<typename T>
  static void send(const T& value) {
    DmaPort::sendDma((uint8_t *)&value, sizeof(value));
  }

  // Send an object using DMA and flush the DMA buffer with padding if needed
  template<typename T>
  static void sendPadded(const T& value) {
    DmaPort::sendDma((uint8_t *)&value, sizeof(value));
    if(sizeof(value) & 0xf) {
      uint8_t padding[0xf];
      DmaPort::sendDma(padding, 16 - (sizeof(value) & 0xf));
    }
  }

  // Read a data structure from the current DMA source address
  template<typename T>
  static void read(T& value) {
    DmaPort::readDma((uint8_t *)&value, sizeof(value));
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
  static uint8_t readByteAtIndirect(ToLong source);
  static Word readWordAtIndirect(ToLong source);
  static Long readLongAtIndirect(ToLong source);

  // Hook commands

  // Return a 1 byte value
  static void rte(int8_t value = 0);

  // Command : Forward the call to the next handler
  static void forward();

  // Command : Return a 32-bit value
  static void rte(ToLong value);

  // Command : Pexec4 then rte
  static void pexec4ThenRte(ToLong pd);

  // Command : Pexec6 then rte
  static void pexec6ThenRte(ToLong pd);

  // Command : Setup DMA read
  static void setDmaRead(ToLong address);

  // Command : Setup DMA write
  static void setDmaWrite(ToLong address);

  // Command : Execute 4 bytes as machine code, then setup DMA read on stack
  static void execThenDmaRead(ToLong code);

  // Command : Execute 4 bytes as machine code, then setup DMA write on stack
  static void execThenDmaWrite(ToLong code);

  // Command : Copy a sized buffer from the stack to an address
  static void copyFromStack(ToLong address);

  // Command : Copy a sized buffer from an address to the stack
  static void copyToStack(ToLong address);

  // Wait for a dummy command byte that indicates command completion
  static void waitCommand();

  // Send a command and wait for completion
  static void sendCommand(int command, ToLong param);

  // Test for DMA-compatible memory
  static bool isDma(uint32_t address);
  static const uint32_t phystop = 0xe00000; // DMA-compatible range
};

// vim: ts=2 sw=2 sts=2 et
#endif
