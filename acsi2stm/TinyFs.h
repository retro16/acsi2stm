/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
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
#include "Monitor.h"
#include <SdFat.h>


// Stores a path to a directory or a file in the most efficient way possible
struct __attribute__((__packed__)) TinyPath : public Monitor {
  TinyPath() {
    clear();
  }

  bool operator==(const TinyPath &other);

  void open(FsVolume &volume, FsFile *target, oflag_t oflag = O_RDONLY, FsFile *parent = nullptr);

  // Get the absolute path as a string in Atari format.
  bool getAbsolute(FsVolume &volume, char *target, int bufSize);

  // Get the absolute path as a string in native unicode format.
  bool getAbsoluteUnicode(FsVolume &volume, char *target, int bufSize);

  void setParent();

  // Set from an absolute or a relative path
  // create can be
  //   0 to create nothing,
  //   1 to create a file,
  //   2 to create a directory,
  // returns
  //   0 in case of success
  //   1 if the file was not found (or access denied in create mode)
  //   2 if the parent directory was not found
  //   3 if the path is invalid
  // In case of error, the path will be reset to the root directory
  int set(FsVolume &volume, const char *path, int create = 0, uint8_t attrib = 0);

  // Create a file
  void create(FsVolume &volume, const char *path) {
    set(volume, path, 1);
  }

  // Create a directory
  // Creates its parents on the way
  void mkdir(FsVolume &volume, const char *path) {
    set(volume, path, 2);
  }

  // Set to root directory
  void clear() {
    indexes[0] = 0;
  }

  bool isRoot() {
    return indexes[0];
  }

  // Read the next unicode character and convert it to Atari
  // Converts everything to upper case.
  // Returns the number of consumed bytes.
  // Character 0 is considered as a valid character and will be converted.
  static int getNextUnicode(const char *source, char *target);

  // Convert an atari character to Unicode and write it to the target buffer.
  // Returns the number of bytes written.
  static int appendUnicode(char atariChar, char *target, int bufSize);

  // Convert the last processed pattern to unicode.
  // Returns the number of bytes written.
  // Warning: does not zero-terminate the string.
  static int patternToUnicode(char *target, int bufSize);

  // Convert the last processed file name to Atari encoding.
  // Returns the number of bytes written.
  // Warning: does not zero-terminate the string.
  static int nameToAtari(char *target, int bufSize);

  // Convert the file's name to Atari encoding.
  // Returns the number of bytes written.
  // Warning: does not zero-terminate the string.
  static int nameToAtari(FsFile *file, char *target, int bufSize);

  // Returns true if the name matches pattern.
  static bool matches(const char pattern[11]);

  // Parse an Atari path element and store it to the current pattern.
  // Returns a pointer to the next element in the path.
  static const char * parseAtariPattern(const char *path);

  // Parse a unicode name to an atari name. Use lastName to get the result.
  // Returns a pointer to the next element in the path.
  static const char * parseUnicodeName(const char *path, bool *compatible = nullptr);

  static const char * lastName() {
    return name;
  }
  static const char * lastPattern() {
    return pattern;
  }

protected:
  static const int maxDepth = ACSI_GEMDRIVE_MAX_PATH;
  uint16_t indexes[maxDepth];
  static char name[11];
  static char pattern[11];
};

// A 6-byte file descriptor.
// Because that's all GEMDOS lets us to store data ...
// The FsFile object is valid until another function returning an FsFile
// pointer is called.
struct __attribute__((__packed__)) TinyFile : public Monitor {
  // Open a file from a path
  FsFile * open(FsVolume &volume, TinyPath &path, oflag_t oflag = O_RDONLY);

  // Re-open a file
  FsFile * acquire(FsVolume &volume, oflag_t oflag = O_RDONLY);

  // Open the next file in the parent directory
  FsFile * openNext(FsVolume &volume, oflag_t oflag = O_RDONLY, const char pattern[11] = "???????????");

  // Returns true if the file descriptor is valid
  operator bool() const {
    return index;
  }

  bool operator==(const TinyFile &other) const {
    return dirCluster == other.dirCluster && index == other.index;
  }

  // Returns the last opened/acquired file descriptor
  // Be very careful when handling multiple TinyFile at the same time !
  FsFile * lastAcquired() {
    return &g.f;
  }

  // Returns the directory containing the last opened/acquired file
  // Be very careful when handling multiple TinyFile at the same time !
  static FsFile * lastDir() {
    return &g.dir;
  }

  // Close the file descriptor
  void close();

// XXX protected:
  struct Global {
    FsFile dir;
    FsFile f;
    uint32_t lastAcquiredCluster;
    uint16_t lastAcquiredIndex;
  };
  static Global g;

  static void findNextMatching(const char pattern[11], oflag_t oflag);

  // These methods do very dirty shenaningans
  // If the SdFat library changes, some offsets will need to be adjusted.
  static uint32_t getCluster(FsFile &f);
  static void setCluster(FsFile &f, uint32_t cluster);

  uint32_t dirCluster;
  uint16_t index; // Index in the containing directory + 1. 0 means file closed.
};

struct TinyFD: public TinyFile {
  int read(FsVolume &volume, uint8_t *data, int bytes);
  int write(FsVolume &volume, uint8_t *data, int bytes);
  int32_t seek(FsVolume &volume, int32_t offset, int whence);

  FsFile * open(FsVolume &volume, TinyPath &path, oflag_t oflag = O_RDONLY) {
    position = 0;
    return TinyFile::open(volume, path, oflag);
  }

protected:
  uint32_t position;
};

#endif
