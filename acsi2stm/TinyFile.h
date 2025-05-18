/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2025 by Jean-Matthieu Coulon
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

#ifndef TINY_FS_H
#define TINY_FS_H

#include "acsi2stm.h"

#include <SdFat.h>

struct __attribute__((__packed__)) TinyFile {
  TinyFile();
  TinyFile(FsFile &file);

  // Returns true if linked to a FsFile. Does not tell if the FsFile is opened
  // or not, though.
  operator bool() const {
    return index;
  }

  // Returns true if the file is in the root directory
  bool isInRoot() const {
    return !dirCluster;
  }

  // Point this TinyFile at a file
  void set(uint32_t mediaId, FsFile &parent, FsFile &file);

  // Point this TinyFile at the beginning of a folder
  void set(uint32_t mediaId, FsFile &parent);

  // Acquires the file.
  // If mediaId is set, enables the acquire cache, speeding up things a lot.
  // WARNING: returns a reference to a static variable.
  FsFile & open(FsVolume &volume, oflag_t oflag = O_RDONLY) const;

  // If the file is null, open the first file in directory
  // If the file is not null, open the next file in directory
  FsFile & openNext(FsVolume &volume, oflag_t = O_RDONLY);

  // WARNING: returns a reference to a static variable.
  FsFile & openParent(FsVolume &volume) const;

  void close();

  // These methods do very dirty shenaningans
  // If the SdFat library changes, some fields will need to be adjusted.
  static uint32_t getCluster(FsFile &file);
  static void setCluster(FsFile &file, uint32_t cluster);

  uint32_t mediaId;
  uint32_t dirCluster;
  uint16_t index;

  // Special values for index
  static const uint16_t CURRENT = 0xffff;
  static const uint16_t PARENT = 0xfffe;
  static const uint16_t VOLUME = 0xfffd;

  static void closeLast();
  static void ejected(uint32_t mediaId);

  static FsFile lastFile;
  static FsFile lastParent;
  static uint32_t lastMediaId;
};

#endif
