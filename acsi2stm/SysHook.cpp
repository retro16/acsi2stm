/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2024 by Jean-Matthieu Coulon
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

#include "SysHook.h"

void SysHook::push(uint8_t *bytes, int count)
{
  int sz = count;
  if(sz & 0xf)
    sz += 16 - (sz & 0xf);
  shiftStack(-sz);
  DmaPort::sendDma(bytes, count);
  if(count & 0xf) {
    uint8_t padding[0xf];
    DmaPort::sendDma(padding, 16 - (count & 0xf));
  }
}

Long SysHook::stackAlloc(int bytes)
{
  // Read the stack pointer address
  pushSp();
  Long sp;
  DmaPort::readDma((uint8_t *)&sp, sizeof(sp));

  // Allocate on the stack, compensating for the 4 bytes of pushSp
  shiftStack(4 - bytes);

  // Return
  return ToLong(sp - bytes);
}

void SysHook::sendAt(uint32_t address, const uint8_t *bytes, int count)
{
  if(count <= 0)
    return;

  if(count < 16 || !isDma(address + count - 1)) {
    // Indirect copy

    shiftStack(-32);

    uint8_t data[32];

    while(count > 0) {
      int c = count > 30 ? 30 : count;
      Word dCount = ToWord(c - 1);
      data[0] = dCount.bytes[0];
      data[1] = dCount.bytes[1];
      memcpy(&data[2], bytes, c);
      shiftStack(0);
      DmaPort::sendDma(data, 32);
      copyFromStack(address);

      address += c;
      bytes += c;
      count -= c;
    }

    shiftStack(32);
    return;
  }

  if(address & 1) {
    // Unaligned access: write the first byte indirectly
    sendAt(address, bytes, 1);
    ++address;
    ++bytes;
    --count;
  }

  while(count >= 16) {
    int blockSize = count & 0x1fff0;

    setDmaRead(address);
    DmaPort::sendDma(bytes, blockSize);

    address += blockSize;
    bytes += blockSize;
    count -= blockSize;
  }

  if(count > 0)
    sendAt(address, bytes, count);
}

void SysHook::readAt(uint8_t *bytes, uint32_t source, int count)
{
  if(count <= 0)
    return;

  if(!isDma(source + count - 1)) {
    // Read from outside DMA RAM: use slow indirect copy
    readAtIndirect(bytes, source, count);
    return;
  }

  if(source & 1) {
    // Unaligned access: read first byte in indirect mode
    *bytes = readByteAt(source);
    ++bytes;
    ++source;
    --count;
  }

  if(count > 0) {
    setDmaWrite(source);
    DmaPort::readDma(bytes, count);
  }
}

uint8_t SysHook::readByteAt(ToLong address)
{
  readByteToStack(address);
  uint8_t data;
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  shiftStack(2);
  return data;
}

Word SysHook::readWordAt(ToLong address)
{
  readWordToStack(address);
  Word data;
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  shiftStack(2);
  return data;
}

Long SysHook::readLongAt(ToLong address)
{
  readLongToStack(address);
  Long data;
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  shiftStack(4);
  return data;
}

void SysHook::readStringAt(char *bytes, ToLong address, int count)
{
  if(!isDma(address))
    return readStringAtIndirect(bytes, address, count);

  if(!count)
    return;
  if(address.bytes[3] & 1) {
    // Unaligned access
    *bytes = readByteAt(address);
    if(!*bytes)
      return;

    --count;
    if(!count)
      return;

    ++address;
    ++bytes;
  }
  setDmaWrite(address);
  DmaPort::readDmaString(bytes, count);
}

void SysHook::clearAt(uint32_t bytes, uint32_t address) {
  uint8_t blank[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                       0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

  if(!isDma(address + bytes - 1)) {
    // Upload some blank bytes on the stack
    shiftStack(-32);
    DmaPort::sendDma(blank, 32);

    while(bytes > 0) {
      int c = bytes > 32 ? 32 : bytes;

      push(ToWord(c));
      copyFromStack(address);
      shiftStack(2);

      address += c;
      bytes -= c;
    }

    // Free data from stack
    shiftStack(32);

    return;
  }

  if(address & 1) {
    sendAt(address, blank, 1);
    ++address;
    --bytes;
  }

  if(bytes >= 16) {
    setDmaRead(address);
    DmaPort::fillDma(0, bytes & 0xfffffff0);
    address += bytes & 0xfffffff0;
    bytes -= bytes & 0xfffffff0;
  }

  if(bytes)
    sendAt(address, blank, bytes);
}

uint8_t SysHook::readByte()
{
  uint8_t data;
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  return data;
}

Word SysHook::readWord()
{
  Word data;
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  return data;
}

Long SysHook::readLong()
{
  Long data;
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  return data;
}

void SysHook::readAtIndirect(uint8_t *bytes, ToLong source, int count) {
  if(count <= 14) {
    readAtIndirectShort(bytes, source, count);
    return;
  }

  // Make room for a 32 bytes buffer on the ST stack
  shiftStack(-32);
  while(count) {
    int l = count > 32 ? 32 : count;

    // Write byte count on the stack
    push(ToWord(l - 1));

    // Do the copy on the ST side
    copyToStack(source);

    // Fetch data
    DmaPort::readDma(bytes, l);

    // Pop byte count
    shiftStack(2);

    count -= l;
    bytes += l;
    source += l;
  }
  shiftStack(32);
}

void SysHook::readAtIndirectShort(uint8_t *bytes, ToLong source, int count) {
  shiftStack(-16);

  ToLong cmd[4] = {0, 0, 0, 0};
  cmd[0].bytes[1] = count - 1; // Adjust for dbra
  send(cmd);

  // Do the actual read on the ST
  copyToStack(source);

  // Fetch result
  DmaPort::readDma(bytes, count);

  // Free stack buffer
  shiftStack(16);
}

void SysHook::readStringAtIndirect(char *bytes, ToLong source, int count) {
  // Make room for a 32 bytes buffer on the ST stack, plus a byte count word
  shiftStack(-32);
  while(count) {
    int l = count > 32 ? 32 : count;

    // Write byte count on the stack
    push(ToWord(l - 1));

    // Do the copy on the ST side
    copyToStack(source);

    // Fetch data in a temporary buffer and do string copy from there
    {
      uint8_t lbuf[32];
      DmaPort::readDma(lbuf, l);
      for(int i = 0; i < l; ++i) {
        bytes[i] = (char)lbuf[i];
        if(!lbuf[i]) {
          shiftStack(2);
          goto end_of_string;
        }
      }
    }

    shiftStack(2);

    count -= l;
    bytes += l;
    source += l;
  }
end_of_string:
  shiftStack(32);
}

// Low level hook commands implementation

void SysHook::rte(int8_t value) {
  if(value <= (int8_t)0xa6)
    rte(ToLong(value));
  dbgHex("rte(", (uint32_t)(uint8_t)value, ") ");
  DmaPort::sendIrq(value);
}

void SysHook::forward() {
  dbg("forward ");
  DmaPort::sendIrq(0xa6);
}

void SysHook::trap1() {
  verbose("trap #1 ");
  sendCommand(0xa4, 0);
}

void SysHook::trap13() {
  verbose("trap #13 ");
  sendCommand(0xa2, 0);
}

void SysHook::trap14() {
  verbose("trap #14 ");
  sendCommand(0xa0, 0);
}

void SysHook::pushSp() {
  verbose("pushSp ");
  sendCommand(0x9e, 0);
}

void SysHook::push(uint8_t value) {
  verbose("pushByte ");
  sendCommand(0x9c, ToLong(value));
}

void SysHook::push(ToWord value) {
  verbose("pushWord ");
  sendCommand(0x9a, ToLong(value));
}

void SysHook::push(ToLong value) {
  verbose("pushLong ");
  sendCommand(0x98, value);
}

void SysHook::shiftStack(ToLong offset) {
  verbose("shiftStack ");
  sendCommand(0x97, offset);
}

void SysHook::shiftStackRead(ToLong offset) {
  verbose("shiftStackRead ");
  sendCommand(0x96, offset);
}

void SysHook::readByteToStack(ToLong address) {
  verbose("readByteToStack ");
  sendCommand(0x94, address);
}

void SysHook::readWordToStack(ToLong address) {
  verbose("readWordToStack ");
  sendCommand(0x92, address);
}

void SysHook::readLongToStack(ToLong address) {
  verbose("readLongToStack ");
  sendCommand(0x90, address);
}

void SysHook::writeByteFromStack(ToLong address) {
  verbose("writeByteFromStack ");
  sendCommand(0x8e, address);
}

void SysHook::writeWordFromStack(ToLong address) {
  verbose("writeWordFromStack ");
  sendCommand(0x8c, address);
}

void SysHook::writeLongFromStack(ToLong address) {
  verbose("writeLongFromStack ");
  sendCommand(0x8a, address);
}

void SysHook::pexec4ThenRte(ToLong pd) {
  verbose("pexec4 ");
  uint8_t bytes[5];
  bytes[0] = 0x88;
  bytes[1] = pd.bytes[0];
  bytes[2] = pd.bytes[1];
  bytes[3] = pd.bytes[2];
  bytes[4] = pd.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
}

void SysHook::pexec6ThenRte(ToLong pd) {
  verbose("pexec6 ");
  uint8_t bytes[5];
  bytes[0] = 0x86;
  bytes[1] = pd.bytes[0];
  bytes[2] = pd.bytes[1];
  bytes[3] = pd.bytes[2];
  bytes[4] = pd.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
}

void SysHook::setDmaRead(ToLong address)
{
  verbose("\nsetDmaRead:");
  sendCommand(0x85, address);
}

void SysHook::setDmaWrite(ToLong address)
{
  verbose("\nsetDmaWrite:");
  sendCommand(0x84, address);
}

void SysHook::copyFromStack(ToLong address)
{
  verbose("\ncopyFromStack:");
  sendCommand(0x83, address);
}

void SysHook::copyToStack(ToLong address)
{
  verbose("\ncopyToStack:");
  sendCommand(0x82, address);
}

void SysHook::rte(ToLong value) {
  dbgHex("rte(", (uint32_t)value, ") ");
  uint8_t bytes[5];
  bytes[0] = 0x80;
  bytes[1] = value.bytes[0];
  bytes[2] = value.bytes[1];
  bytes[3] = value.bytes[2];
  bytes[4] = value.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
}

void SysHook::waitCommand() {
  DmaPort::waitCs();
  DmaPort::armCs();
  verbose("[{]");
}

void SysHook::sendCommand(int command, ToLong param)
{
  uint8_t bytes[5];
  bytes[0] = command;
  bytes[1] = param.bytes[0];
  bytes[2] = param.bytes[1];
  bytes[3] = param.bytes[2];
  bytes[4] = param.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
  waitCommand();
}

// vim: ts=2 sw=2 sts=2 et
