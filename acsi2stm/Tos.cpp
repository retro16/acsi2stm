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
#include "Tos.h"

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

Long Tos::Pexec_4(ToLong basepage) {
  Pexec_4_p p;
  p.mode = 4;
  p.z1 = 0;
  p.basepage = basepage;
  p.z2 = 0;
  verbose("Pexec(4)\n");
  return gemdos(Pexec_op, p);
}

Long Tos::Pexec_5(ToLong cmdline, ToLong env) {
  Pexec_5_p p;
  p.mode = 5;
  p.z1 = 0;
  p.cmdline = cmdline;
  p.env = env;
  verbose("Pexec(5)\n");
  return gemdos(Pexec_op, p);
}

Long Tos::Pexec_6(ToLong basepage) {
  Pexec_6_p p;
  p.mode = 6;
  p.z1 = 0;
  p.basepage = basepage;
  p.z2 = 0;
  verbose("Pexec(6)\n");
  return gemdos(Pexec_op, p);
}

Long Tos::Pexec_7(ToLong prgflags, ToLong cmdline, ToLong env) {
  Pexec_7_p p;
  p.mode = 7;
  p.prgflags = prgflags;
  p.cmdline = cmdline;
  p.env = env;
  verbose("Pexec(7)\n");
  return gemdos(Pexec_op, p);
}

Long Tos::Physbase() {
  verboseHex("Physbase()\n");
  return xbios(Physbase_op);
}

Long Tos::Logbase() {
  verboseHex("Logbase()\n");
  return xbios(Logbase_op);
}

Long Tos::Getrez() {
  verboseHex("Getrez()\n");
  return xbios(Getrez_op);
}

Long Tos::Setscreen(ToLong laddr, ToLong paddr, ToWord rez) {
  Setscreen_p p;
  p.laddr = laddr;
  p.paddr = paddr;
  p.rez = rez;
  return xbios(Setscreen_op, p);
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
  DmaPort::sendDma(paramBytes, paramSize);
  if((paramSize + 2) & 0xf) {
    uint8_t padding[0xf];
    DmaPort::sendDma(padding, 16 - ((paramSize + 2) & 0xf));
  }

  trap();

  Long retVal;
  DmaPort::readDma((uint8_t *)&retVal, 4);
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
  len = (len + 0xf) & 0xfff0;
  Long textBuf = stackAlloc(len);
  DmaPort::sendDma((const uint8_t *)text, len);
  Cconws(textBuf, len);
}

// vim: ts=2 sw=2 sts=2 et
