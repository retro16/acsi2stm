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

#ifndef GEM_DRIVE_H
#define GEM_DRIVE_H

#include "acsi2stm.h"

#include "BlockDev.h"
#include "Devices.h"
#include "SdFat.h"
#include "TinyFile.h"
#include "Tos.h"

struct TOS_PACKED GemPattern {
  GemPattern();
  GemPattern(const char *pattern);

  // Pattern matching
  bool operator==(const GemPattern &file) const;
  bool operator==(const char *unicodeName) const;
  bool operator==(FsFile &file) const;

  template<typename T>
  bool operator!=(T t) const {
    return !(*this == t);
  }

  operator bool() const {
    return !isEmpty();
  }

  bool parseUnicode(const char *name);
  bool parseFileName(FsFile &file);
  const char * parseAtari(const char *path);
  char * parseAtari(char *path) {
    return (char *)parseAtari(path);
  }

  // Parses a UTF-8 character
  // Returns the length of the character, or negative if impossible to convert
  static int getNextUnicode(const char *source, char *target);

  // Converts the pattern to an unicode name
  // bufSize is the size of the target buffer
  // Returns the number of bytes written
  int toUnicode(char *target, int bufSize) const;

  // Append one atari character in unicode format
  // Returns the number of bytes written
  static int appendUnicode(char atariChar, char *target, int bufSize);

  // Converts the pattern to an Atari name
  // bufSize is the size of the target buffer
  // Returns the number of bytes written
  int toAtari(char *target) const;

  // Return true if it is a normal file name:
  //   no wildcard
  //   not empty
  //   not '.'
  //   not '..'
  bool isFileName() const;
  bool hasWildcards() const; // true if it contains * or ?
  bool isWildcard() const; // true if it matches anything (*.*)
  bool isEmpty() const; // true if it is empty
  bool isCurDir() const; // true if '.'
  bool isParentDir() const; // true if '..'

  void clear(); // Fill with spaces
  void setCurDir(); // Set to '.'
  void setParentDir(); // Set to '..'

  static bool attribMatching(uint8_t attrib, uint8_t fileAttrib);

  char pattern[11];
};

// GemDrive DTA, compatible with TOS DTA
struct TOS_PACKED GemDriveDTA {
  TinyFile file;
  GemPattern pattern;
  uint8_t d_attrib;
  Word d_time;
  Word d_date;
  Long d_length;
  char d_fname[13];
  uint8_t attribMask;
};

struct GemPath: public FsFile {
  GemPath(SdDev &sd);
  GemPath & operator=(const GemPath &other);

  bool operator==(GemPath &other);
  bool operator!=(GemPath &other);

  // Append a file to the path
  // Assumes that file is a child of the current path
  // Assumes that the current path is not a file
  bool append(FsFile &file);

  // Set to parent
  bool parent();

  // Set to root directory
  void clear();

  // Overload close() to avoid flushing caches
  void close();

  // Returns true if the path points at the root directory
  bool isRoot() const {
    return indexes[0] == 0;
  }

  bool openPath(const char *pathStr, GemPattern &last, bool parseLastName = false);
  bool openFile(const GemPattern &name, FsFile &file, oflag_t oflag = O_RDONLY);

  int toAtari(char *out, int bufSize) const;
  int toUnicode(char *out, int bufSize) const;

  bool isContainedBy(FsFile &file) const;

protected:
  static const int maxDepth = ACSI_GEMDRIVE_MAX_PATH;
  uint16_t indexes[maxDepth];
  SdDev &sd;
public:
  uint32_t mediaId;
};

struct GemFile: public TinyFile {
  void set(GemPath &parent, FsFile &file, oflag_t oflag, Long basePage);

  FsFile & reopen();
  int32_t read(uint8_t *data, int32_t size);
  int32_t write(uint8_t *data, int32_t size);
  int32_t seek(int32_t offset, int whence);

  bool checkMedium() const;
  bool isWritable() const;

  uint32_t position; // Current seek position
  Long basePage;
  oflag_t oflag;
};

struct GemDrive: public Devices, public Tos {
  GemDrive(SdDev &sd_);

  // Process a command
  static void process(uint8_t cmd);

  // External events
  static void onBoot();
  static void onInit(bool setBootDrive = false);
  static void onGemdos();

  // GEMDOS processing
#define DECLARE_CALLBACK(name) \
  static bool on ## name(const Tos::name ## _p &); \

  DECLARE_CALLBACK(Pterm0);
  DECLARE_CALLBACK(Cconws);
  DECLARE_CALLBACK(Dsetdrv);
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

  // Extra methods
  static void closeAll();
  static void installHook(uint32_t driverMem, ToLong vector);
  static void setCurDrive(uint8_t driveId);
  static Long getBasePage();
  static GemDrive * getDrive(const char *path, const char **outPath = nullptr);
  static GemDrive * getDrive(char *path, char **outPath = nullptr);
  static GemDrive * getDrive(Long pathAddr, char **outPath = nullptr);
  static GemDrive * getDrive(uint8_t driveId);
  static GemDrive * getDrive(uint32_t mediaId, BlockDev::MediaIdMode mode = BlockDev::NORMAL);
  static void closeProcessFiles();
  static oflag_t attribToSdFat(uint8_t attrib);
  static bool ownFd(Word fd);
  static const char * toUnicode(const GemPath &path);
  static const char * toUnicode(const GemPath &path, FsFile &file);
  static const char * toUnicode(const GemPath &path, GemPattern &name);
  static void readParams(void *data, uint32_t size);

  // Load a program from file into memory.
  // Returns a TOS error code or E_OK if successful.
  // Sets the basepage address on the ST RAM.
  static uint32_t loadPrg(FsFile &prgFile, Long cmdline, Long env, uint32_t &basepage);

  // Make rte return true and forward return false for code clearness
  static bool rte(int8_t value = 0) {
    SysHook::rte(value);
    return true;
  }
  static bool rte(ToLong value) {
    SysHook::rte(value);
    return true;
  }
  static bool forward() {
    SysHook::forward();
    return false;
  }

  // Non-static methods

  // Advance DTA to the next matching file
  bool scanDTA(GemDriveDTA &dta, uint32_t noFileErr = ENMFIL);

  // Return the drive letter on the ST
  char letter() const;

  // Create a file descriptor for a file
  // Returns 0 if not possible
  Word createFd(GemPath &parent, FsFile &file, oflag_t oflag);

  // Static variables
  static const int driveCount = Devices::sdCount;
  static const int filesMax = ACSI_GEMDRIVE_MAX_FILES;
  static GemFile files[filesMax]; // File descriptors

  static uint8_t relTableCache[ACSI_GEMDRIVE_RELTABLE_CACHE_SIZE];
  static GemDrive * curDrive; // Current drive
  // Cache of stable OSHEADER values
  static Long os_beg;
  static Word os_version;
  static Word os_conf;
  static Long p_run;
  static Long bootBasePage;

  // Mounted drive variables
  SdDev &sd; // Pointer to the low-level SD card descriptor
  GemPath curPath;
  uint8_t id; // Drive id on the ST
};

// vim: ts=2 sw=2 sts=2 et
#endif
