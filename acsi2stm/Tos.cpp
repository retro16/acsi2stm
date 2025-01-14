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

#include "Tos.h"

#include "Devices.h"

Long Tos::Cconout(char c) {
  Cconout_p p;
  p.c.bytes[0] = 0;
  p.c.bytes[1] = (uint8_t)c;
  verboseHex("Cconout(", (uint8_t)c, ")\n");
  return gemdos(Cconout_op, p);
}

Long Tos::Cconws(ToLong buf, int len) {
  Cconws_p p;
  p.buf = buf;
  verboseHex("Cconws(", (uint32_t)buf, ")\n");
  return gemdos(Cconws_op, p, len);
}

Long Tos::Dsetdrv(ToWord drv) {
  Dsetdrv_p p;
  p.drv = drv;
  verboseHex("Dsetdrv(", (uint16_t)drv, ")\n");
  return gemdos(Dsetdrv_op, p);
}

Long Tos::Cconos() {
  verboseHex("Cconos()\n");
  return gemdos(Cconos_op);
}

Long Tos::Dgetdrv() {
  verboseHex("Dgetdrv()\n");
  return gemdos(Dgetdrv_op);
}

Long Tos::Tgetdate() {
  verboseHex("Tgetdate()\n");
  return gemdos(Tgetdate_op);
}

Long Tos::Tsetdate(ToWord date) {
  Tsetdate_p p;
  p.date = date;
  verboseHex("Tsetdate(", (uint16_t)date, ")\n");
  return gemdos(Tsetdate_op, p);
}

Long Tos::Tgettime() {
  verboseHex("Tgettime()\n");
  return gemdos(Tgettime_op);
}

Long Tos::Tsettime(ToWord time) {
  Tsettime_p p;
  p.time = time;
  verboseHex("Tsettime(", (uint16_t)time, ")\n");
  return gemdos(Tsettime_op, p);
}

Long Tos::Fgetdta() {
  verboseHex("Fgetdta()\n");
  return gemdos(Fgetdta_op);
}

Long Tos::Malloc(ToLong number) {
  Malloc_p p;
  p.number = number;
  verboseHex("Malloc(", (uint32_t)number, ")\n");
  return gemdos(Malloc_op, p);
}

Long Tos::Mfree(ToLong block) {
  Mfree_p p;
  p.block = block;
  verboseHex("Mfree(", (uint32_t)block, ")\n");
  return gemdos(Mfree_op, p);
}

Long Tos::Pexec(ToWord mode, ToLong l1, ToLong l2, ToLong l3) {
  Pexec_p p;
  p.mode = mode;
  p.l1 = l1;
  p.l2 = l2;
  p.l3 = l3;
  verbose("Pexec\n");
  return gemdos(Pexec_op, p);
}

Long Tos::Pexec_4(ToLong basepage) {
  return Pexec(4, 0, basepage, 0);
}

Long Tos::Pexec_5(ToLong cmdline, ToLong env) {
  return Pexec(5, 0, cmdline, env);
}

Long Tos::Pexec_6(ToLong basepage) {
  return Pexec(6, 0, basepage, 0);
}

Long Tos::Pexec_7(ToLong prgflags, ToLong cmdline, ToLong env) {
  return Pexec(7, prgflags, cmdline, env);
}

Long Tos::sysCall(void (*trap)(), Word opCode, uint8_t *paramBytes, int paramSize, int extraData)
{
  verboseHex(opCode.bytes[0], opCode.bytes[1], " (", paramSize, ")\n");
  // Push opcode and param bytes
  int sz = paramSize + 2;
  if(sz & 0xf)
    sz += 16 - (sz & 0xf);
  shiftStack(-sz);
  send(opCode);
  sendDma(paramBytes, paramSize);
  if((paramSize + 2) & 0xf) {
    uint8_t padding[0xf];
    sendDma(padding, 16 - ((paramSize + 2) & 0xf));
  }

  trap();

  Long retVal;
  readDma((uint8_t *)&retVal, 4);
  shiftStack(sz + extraData + 4);
  verboseHex(" ->", (uint32_t)retVal, "\n");
  return retVal;
}

void Tos::tosPrint(const char c) {
  Cconout(c);
}

void Tos::tosPrint(const char *text) {
  if(!text || !*text)
    return;
  int len = strlen(text) + 1;
  memcpy(Devices::buf, text, len);
  len = (len + 0xf) & 0xfff0;
  Long textBuf = stackAlloc(len);
  sendDma(Devices::buf, len);
  Cconws(textBuf, len);
}

// vim: ts=2 sw=2 sts=2 et
