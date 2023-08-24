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

#include "acsi2stm.h"
#include "SysHook.h"
#include "DmaPort.h"

const
#include "PROGRAMS.boot.h"

Long SysHook::getProgram(SysHook::Program p) {
  Long l;
  int pi = (int)p * 4;
  l.bytes[0] = PROGRAMS_boot_bin[pi++];
  l.bytes[1] = PROGRAMS_boot_bin[pi++];
  l.bytes[2] = PROGRAMS_boot_bin[pi++];
  l.bytes[3] = PROGRAMS_boot_bin[pi];

  return l;
}

#if ACSI_VERBOSE
void SysHook::pstack() {
  execThenDmaWrite(getProgram(PGM_PUSHSP));
  uint8_t v[4];
  DmaPort::readDma(v, 4);
  shiftStack(4);
}
#endif

void SysHook::shiftStack(ToWord offset)
{
  Long addSp = getProgram(PGM_ADDSP);
  addSp.bytes[2] = offset.bytes[0];
  addSp.bytes[3] = offset.bytes[1];
  execThenDmaRead(addSp);
}

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

Long SysHook::stackAlloc(int16_t bytes)
{
  // Read the stack pointer address
  execThenDmaWrite(getProgram(PGM_PUSHSP));
  Long sp = readLong();

  // Allocate on the stack, compensating for the 4 bytes of PGM_PUSHSP
  shiftStack(4 - bytes);

  // Return
  return ToLong(sp - bytes);
}

void SysHook::trap(int number) {
  Long trapProgram = getProgram(PGM_TRAP);
  trapProgram.bytes[1] |= number; // Inject trap vector

  execThenDmaWrite(trapProgram);
}

void SysHook::sendAt(uint32_t address, const uint8_t *bytes, int count)
{
  if(count <= 0)
    return;

  if(count < 16) {
    // Indirect copy

    shiftStack(-32);

    uint8_t data[32];
    Word dCount = ToWord(count - 1);
    data[0] = dCount.bytes[0];
    data[1] = dCount.bytes[1];
    memcpy(&data[2], bytes, count);
    DmaPort::sendDma(data, 32);

    copyFromStack(address);

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

  if(count >= 16) {
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

  if(!isDma(source)) {
    // Read from outside DMA RAM: use slow indirect copy
    readAtIndirect(bytes, source, count);
    return;
  }

  if(source & 1) {
    // Unaligned access: read first byte in indirect mode
    *bytes = readByteAtIndirect(source);
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
  if(!isDma(address))
    return readByteAtIndirect(address);

  if(address & 1) {
    Word data;
    setDmaWrite(address - 1);
    DmaPort::readDma((uint8_t *)&data, sizeof(data));
    return data.bytes[1];
  }

  uint8_t data;
  setDmaWrite(address);
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  return data;
}

Word SysHook::readWordAt(ToLong address)
{
  if(!isDma(address))
    return readWordAtIndirect(address);

  Word data;
  setDmaWrite(address);
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
  return data;
}

Long SysHook::readLongAt(ToLong address)
{
  if(!isDma(address))
    return readLongAtIndirect(address);

  Long data;
  setDmaWrite(address);
  DmaPort::readDma((uint8_t *)&data, sizeof(data));
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
  if(!isDma(address))
    return;

  uint8_t blank[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

  if(address & 1) {
    --bytes;
    sendAt(address, blank, 1);
    ++address;
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
  shiftStack(-34);
  while(count) {
    int l = count > 32 ? 32 : count;

    // Write byte count on the stack
    shiftStack(0);
    sendPadded(ToWord(l - 1));

    // Do the copy on the ST side
    copyToStack(source);

    // Fetch data
    DmaPort::readDma(bytes, l);

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
  shiftStack(14);
}

void SysHook::readStringAtIndirect(char *bytes, ToLong source, int count) {
  // Make room for a 32 bytes buffer on the ST stack, plus a byte count word
  shiftStack(-34);
  while(count) {
    int l = count > 32 ? 32 : count;

    // Write byte count on the stack
    shiftStack(0);
    sendPadded(ToWord(l - 1));

    // Do the copy on the ST side
    copyToStack(source);

    // Fetch data in a temporary buffer and do string copy from there
    {
      uint8_t lbuf[32];
      DmaPort::readDma(lbuf, l);
      for(int i = 0; i < l; ++i) {
        bytes[i] = (char)lbuf[i];
        if(!lbuf[i])
          goto end_of_string;
      }
    }

    count -= l;
    bytes += l;
    source += l;
  }
end_of_string:
  shiftStack(34);
}

uint8_t SysHook::readByteAtIndirect(ToLong source) {
  Word result;
  push(source);
  execThenDmaWrite(getProgram(PGM_READSPB));
  read(result);
  shiftStack(16 - sizeof(source) + sizeof(result));
  return result.bytes[0];
}

Word SysHook::readWordAtIndirect(ToLong source) {
  Word result;
  push(source);
  execThenDmaWrite(getProgram(PGM_READSPW));
  read(result);
  shiftStack(16 - sizeof(source) + sizeof(result));
  return result;
}

Long SysHook::readLongAtIndirect(ToLong source) {
  Long result;
  push(source);
  execThenDmaWrite(getProgram(PGM_READSPL));
  read(result);
  shiftStack(16 - sizeof(source) + sizeof(result));
  return result;
}

void SysHook::rte(int8_t value) {
  if(value <= (int8_t)0x8b)
    rte(ToLong(value));
  dbgHex("rte(", (uint32_t)(uint8_t)value, ") ");
  DmaPort::sendIrq(value);
}

void SysHook::forward() {
  dbg("forward ");
  DmaPort::sendIrq(0x8b);
}

void SysHook::rte(ToLong value) {
  dbgHex("rte(", (uint32_t)value, ") ");
  uint8_t bytes[5];
  bytes[0] = 0x8a;
  bytes[1] = value.bytes[0];
  bytes[2] = value.bytes[1];
  bytes[3] = value.bytes[2];
  bytes[4] = value.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
}

void SysHook::pexec4ThenRte(ToLong pd) {
  dbg("pexec4 ");
  uint8_t bytes[5];
  bytes[0] = 0x88;
  bytes[1] = pd.bytes[0];
  bytes[2] = pd.bytes[1];
  bytes[3] = pd.bytes[2];
  bytes[4] = pd.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
}

void SysHook::pexec6ThenRte(ToLong pd) {
  dbg("pexec6 ");
  uint8_t bytes[5];
  bytes[0] = 0x86;
  bytes[1] = pd.bytes[0];
  bytes[2] = pd.bytes[1];
  bytes[3] = pd.bytes[2];
  bytes[4] = pd.bytes[3];
  DmaPort::sendIrqFast(bytes, 5);
}

void SysHook::execThenDmaRead(ToLong code)
{
  verbose("\nexec&read:");
  sendCommand(0x85, code);
}

void SysHook::execThenDmaWrite(ToLong code)
{
  verbose("\nexec&write:");
  sendCommand(0x84, code);
}

void SysHook::setDmaRead(ToLong address)
{
  verbose("\nsetDmaRead:");
  sendCommand(0x83, address);
}

void SysHook::setDmaWrite(ToLong address)
{
  verbose("\nsetDmaWrite:");
  sendCommand(0x82, address);
}

void SysHook::copyFromStack(ToLong address)
{
  verbose("\ncopyFromStack:");
  sendCommand(0x81, address);
}

void SysHook::copyToStack(ToLong address)
{
  verbose("\ncopyToStack:");
  sendCommand(0x80, address);
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

bool SysHook::isDma(uint32_t address) {
  return address < phystop;
}

// vim: ts=2 sw=2 sts=2 et
