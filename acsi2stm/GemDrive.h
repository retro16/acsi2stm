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

#ifndef GEM_DRIVE_H
#define GEM_DRIVE_H

#include "acsi2stm.h"
#include "Devices.h"
#include "Tos.h"

struct TinyPath;
struct GemFile;
struct PrivDTA;

struct GemDrive: public Devices, public Tos {
  // Process a command
  static void process(uint8_t cmd);

  // GEMDOS processing
#define DECLARE_CALLBACK(name) \
  static bool on ## name(const Tos::name ## _p &); \
  static void sniff ## name(const Tos::name ## _p &)

  DECLARE_CALLBACK(Pterm0);
  DECLARE_CALLBACK(Cconws);
  DECLARE_CALLBACK(Dsetdrv);
  DECLARE_CALLBACK(Fsetdta);
  DECLARE_CALLBACK(Tsetdate);
  DECLARE_CALLBACK(Tsettime);
  DECLARE_CALLBACK(Dfree);
  DECLARE_CALLBACK(Dcreate);
  DECLARE_CALLBACK(Ddelete);
  DECLARE_CALLBACK(Dsetpath);
  DECLARE_CALLBACK(Fcreate);
  DECLARE_CALLBACK(Fopen);
  DECLARE_CALLBACK(Fclose);
  DECLARE_CALLBACK(Fread);
  DECLARE_CALLBACK(Fwrite);
  DECLARE_CALLBACK(Fdelete);
  DECLARE_CALLBACK(Fseek);
  DECLARE_CALLBACK(Fattrib);
  DECLARE_CALLBACK(Dgetpath);
  DECLARE_CALLBACK(Pexec);
  DECLARE_CALLBACK(Pterm);
  DECLARE_CALLBACK(Fsfirst);
  DECLARE_CALLBACK(Fsnext);
  DECLARE_CALLBACK(Frename);
  DECLARE_CALLBACK(Fdatime);

#undef DECLARE_CALLBACK

  // External events
  static void onBoot();
  static void onGemdos();
  static void onBios();
  static void onXbios();
  static void onExtCmd();

  // Extra methods
  static bool openPath(int create, ToLong fname, uint8_t attr, int &driveIndex, TinyPath &path, int8_t pathErr = EFILNF);
  static bool onFcreateopen(int create, ToLong fname, oflag_t oflag, uint8_t attr);
  static void installHook(uint32_t driverMem, ToLong vector);
  static Long getBasePage();
  static bool checkMedium(int driveIndex);
  static int findDriveByMediaId(uint32_t mediaId);
  static void closeProcessFiles();
  static void setCurDrive(int drive);
  static GemFile * getFile(ToWord fd);
  static int getDrive(const char *path, const char **outPath = nullptr);
  static int getDrive(ToWord driveId);
  static int getFdIndex(ToWord stfd);
  static int createFd(Word &stfd);
  static GemFile * createFd(uint32_t &stfd, int driveIndex, Long basePage);
  static bool closeFd(ToWord stfd);
  static void setDta(FsFile *file, const PrivDTA &priv, DTA &dta);
};

// vim: ts=2 sw=2 sts=2 et
#endif
