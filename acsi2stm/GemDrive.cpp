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

#include "GemDrive.h"

#include "DmaPort.h"
#include "SysHook.h"
#if ACSI_PIO
#include "FlashFirmware.h"
#endif

#include <cstddef>

#if ! ACSI_STRICT

#if ACSI_PIO
#define INIT_CMD 0x10
#else
#define INIT_CMD 0x11
#endif

const
#include "GEMDRIVE.boot.h"

// Character tables

// For all unicode codepoints, 0x1fxxx will be represented as 0xfxxx
static const uint16_t lowChars[] = {
  // 0x
  0x2400, 0x21e7, 0x21e9, 0x21e8, 0x21e6, 0xfbbd, 0xfbbe, 0xfbbf,
  0x2713, 0xf552, 0xf514, 0x266a, 0x240c, 0x240d, 0xfb4b, 0xfb40,
  // Map "Fuji" logo characters as 2 triangles so they assemble cleanly.

  // 1x
  0xfbf0, 0xfbf1, 0xfbf2, 0xfbf3, 0xfbf4, 0xfbf5, 0xfbf6, 0xfbf7,
  0xfbf8, 0xfbf9, 0x259, 0x241b, 0x259b, 0x259c, 0x2599, 0x259f
  // Map "Bob Dobbs" as 4 corner block characters, so it stays coherent when
  // properly assembled.
};

// Characters 127 and above
static const uint16_t highChars[] = {
  // 7f
  0x2302,

  // 8x
  0xc7, 0xfc, 0xe9, 0xe2, 0xe4, 0xe0, 0xe5, 0xe7,
  0xea, 0xeb, 0xe8, 0xef, 0xee, 0xec, 0xc4, 0xc5,

  // 9x
  0xc9, 0xe6, 0xc6, 0xf4, 0xf6, 0xf2, 0xfb, 0xf9,
  0xff, 0xd6, 0xdc, 0xa2, 0xa3, 0xa5, 0xdf, 0x192,

  // ax
  0xe1, 0xed, 0xf3, 0xfa, 0xf1, 0xd1, 0xaa, 0xba,
  0xbf, 0x2310, 0xac, 0xbd, 0xbc, 0xa1, 0xab, 0xbb,

  // bx
  0xe3, 0xf5, 0xd8, 0xf8, 0x153, 0x152, 0xc0, 0xc3,
  0xd5, 0xa8, 0xb4, 0x2020, 0xb6, 0xa9, 0xae, 0x2122,

  // cx
  0x133, 0x132, 0x5d0, 0x5d1, 0x5d2, 0x5d3, 0x5d4, 0x5d5,
  0x5d6, 0x5d7, 0x5d8, 0x5d9, 0x5db, 0x5dc, 0x5de, 0x5e0,

  // dx
  0x5e1, 0x5e2, 0x5e4, 0x5e6, 0x5e7, 0x5e8, 0x5e9, 0x5ea,
  0x5df, 0x5da, 0x5dd, 0x5e3, 0x5e5, 0xa7, 0x2227, 0x221e,

  // ex
  0x3b1, 0x3b2, 0x393, 0x3c0, 0x3a3, 0x3c3, 0xb5, 0x3c4,
  0x3a6, 0x398, 0x3a9, 0x3b4, 0x222e, 0x3d5, 0x2208, 0x2229,

  // fx
  0x2261, 0xb1, 0x2265, 0x2264, 0x2320, 0x2321, 0xf7, 0x2248,
  0xb0, 0x2022, 0xb7, 0x221a, 0x207f, 0xb2, 0xb3, 0xaf,
};

// Approximate transliterations for "common" characters
static const uint16_t translitChars[][2] = {
  {0x00a0,0x0020}, // Non breaking space -> space
  {0x220f,0x00e3}, // ∏ -> π (Math n-ary product)
  {0x2211,0x00e4}, // ∑ -> Σ (Math sommation)
  {0x2126,0x00ea}, // Ω -> Ω (Ohm sign)
  {0x00f0,0x00eb}, // ð -> δ (Icelandic eth)
  {0x2202,0x00eb}, // ∂ -> δ (Math partial derivative)
  {0x2205,0x00ed}, // ∅ -> ϕ (Math empty set)
  {0x2300,0x00ed}, // ⌀ -> ϕ (Math diameter sign)
  {0x20ac,0x00ee}, // € -> ∈ (Euro sign)
  {0x03b5,0x00ee}, // ε -> ∈ (Epsilon)
};

// Offsets for variables to patch in the GEMDRIVE payload
static const int GEMDRIVE_boot_acsiid = 23;
static const int GEMDRIVE_boot_prmoff = 4;

GemPattern::GemPattern() {
  clear();
}

GemPattern::GemPattern(const char *pattern_) {
  memcpy(pattern, pattern_, sizeof(pattern));
}

bool GemPattern::operator==(const GemPattern &file) const {
  if(file.isCurDir()) {
    if(pattern[0] != '?' && pattern[0] != '.')
      return false;
    for(int i = 1; i < 11; ++i)
      if(pattern[i] != '?' && pattern[i] != ' ')
        return false;
    return true;
  }

  if(file.isParentDir()) {
    if(pattern[0] != '?' && pattern[0] != '.')
      return false;
    if(pattern[1] != '?' && pattern[1] != '.')
      return false;
    for(int i = 2; i < 11; ++i)
      if(pattern[i] != '?' && pattern[i] != ' ')
        return false;
    return true;
  }

  for(int i = 0; i < 11; ++i) {
    char c = pattern[i];
    char other = file.pattern[i];
#if ! ACSI_GEMDRIVE_UPPER_CASE
    // Case insensitive compare
    if(c >= 'a' && c <= 'z')
      c = c - 'a' + 'A';
    if(other >= 'a' && other <= 'z')
      other = other - 'a' + 'A';
#endif
    if(c != '?' && c != other)
      return false;
  }

  return true;
}

bool GemPattern::operator==(const char *unicodeName) const {
  GemPattern namePattern;
  if(!namePattern.parseUnicode(unicodeName))
    return false;
  return *this == namePattern;
}

bool GemPattern::operator==(FsFile &file) const {
  GemPattern namePattern;
  if(!namePattern.parseFileName(file))
    return false;
  return *this == namePattern;
}

bool GemPattern::parseUnicode(const char *name) {
  int i = 0; // Index in the source string
  int j = 0; // Index in name

  int nameEnd;
  int ext;

  // Find the end of the current name
  for(nameEnd = 0; name[nameEnd] && name[nameEnd] != '/'; ++nameEnd);

  // Find the extension
  for(ext = nameEnd - 1; ext > 0 && name[ext] != '.'; --ext);

  if(name[ext] != '.')
    // No extension, put the extension pointer just before the end
    ext = nameEnd;

#if ACSI_GEMDRIVE_HIDE_DOT_FILES
  // Hide dot files
  if(name[0] == '.' && name[1] != '.')
    return false;
#endif

  // Parse name
  for(i = 0, j = 0; i < ext && j < 8; ++j) {
#if ACSI_GEMDRIVE_HIDE_NON_8_3
    if(name[i] == '.')
      // Multiple dots in the file name (e.g. "FILE.TAR.GZ")
      return false;
#endif

    if(name[i] == '*') {
      // Fill with '?' until the end
      for(; j < 8; ++j)
        pattern[j] = '?';
      ++i;
      break;
    }

    int clen = getNextUnicode(&name[i], &pattern[j]);
    if(clen > 0) {
      i += clen;
    } else {
      i += -clen;
#if ACSI_GEMDRIVE_FALLBACK_CHAR
      pattern[j] = ACSI_GEMDRIVE_FALLBACK_CHAR;
#else
      return false;
#endif
    }
  }

#if ACSI_GEMDRIVE_HIDE_NON_8_3
  // Check that we have an expected end of file name
  if(name[i] && name[i] != '.' && name[i] != '/')
    return false;
#endif

  // Fill the name with spaces
  for(; j < 8; ++j)
    pattern[j] = ' ';

  // Parse extension
  if(name[ext] == '.') {
    for(i = ext + 1; i < nameEnd && j < 11; ++j) {
      if(name[i] == '*') {
        // Fill with '?' until the end
        for(; j < 11; ++j)
          pattern[j] = '?';
        ++i;
        break;
      }
      int clen = getNextUnicode(&name[i], &pattern[j]);
      if(clen > 0) {
        i += clen;
      } else {
        i += -clen;
#if ACSI_GEMDRIVE_FALLBACK_CHAR
        pattern[j] = ACSI_GEMDRIVE_FALLBACK_CHAR;
#else
        return false;
#endif
      }
    }
  }

#if ACSI_GEMDRIVE_HIDE_NON_8_3
  // Check that we have an expected end of extension
  if(name[i] && name[i] != '/')
    return false;
#endif

  // Fill the extension with spaces
  for(; j < 11; ++j)
    pattern[j] = ' ';

  return true;
}

bool GemPattern::parseFileName(FsFile &file) {
  char unicodeName[256];
  file.getName(unicodeName, sizeof(unicodeName));
  return parseUnicode(unicodeName);
}

const char * GemPattern::parseAtari(const char *path) {
  int i = 0; // Index in the source string
  int j = 0; // Index in name

  if(path[0] == '.' && (!path[1] || path[1] == '\\')) {
    i = 1;
    pattern[0] = '.';
    j = 1;
  } else if(path[0] == '.' && path[1] == '.' && (!path[2] || path[2] == '\\')) {
    i = 2;
    pattern[0] = '.';
    pattern[1] = '.';
    j = 2;
  } else {
    // Parse name
    for(i = 0, j = 0; j < 8 && path[i] && path[i] != '\\' && path[i] != '.'; ++i, ++j) {
      if(path[i] == '*') {
        // Fill with '?' until the end
        for(; j < 8; ++j)
          pattern[j] = '?';
        ++i;
        break;
      }
      pattern[j] = path[i];
#if ACSI_GEMDRIVE_UPPER_CASE
      if(pattern[j] >= 'a' && pattern[j] <= 'z')
        pattern[j] += 'A' - 'a';
#endif
    }

    // Fill the name with spaces
    for(; j < 8; ++j)
      pattern[j] = ' ';

    // Point at the first letter of the extension
    while(path[i] && path[i] != '\\' && path[i] != '.')
      ++i;
    if(path[i] == '.')
      ++i;

    // Parse extension
    for(; j < 11 && path[i] && path[i] != '\\'; ++i, ++j) {
      if(path[i] == '*') {
        // Fill with '?' until the end
        for(; j < 11; ++j)
          pattern[j] = '?';
        ++i;
        break;
      }
      pattern[j] = path[i];
#if ACSI_GEMDRIVE_UPPER_CASE
      if(pattern[j] >= 'a' && pattern[j] <= 'z')
        pattern[j] += 'A' - 'a';
#endif
    }
  }

  // Fill the extension with spaces
  for(; j < 11; ++j)
    pattern[j] = ' ';

  // Go to the path separator
  while(path[i] && path[i] != '\\')
    ++i;

  return &path[i];
}

int GemPattern::getNextUnicode(const char *sourceStr, char *target) {
  const uint8_t *source = (const uint8_t *)sourceStr;
  uint8_t c = *source;

  // Forbidden characters and control characters
  if(c <= ' ' || strchr("*.:?\\", c))
    return -1;

  // Simple 1 byte case
  if(c < 127) {
#if ACSI_GEMDRIVE_UPPER_CASE
    if(c >= 'a' && c <= 'z')
      // Convert to upper case
      *target = c - 'a' + 'A';
    else
#endif
    *target = c;
    return 1;
  }

  // Compute the character length
  int l;
  for(l = 1; (source[l] & 0xc0) == 0x80; ++l);

  uint32_t codepoint;
  if((c & 0xe0) == 0xc0) {
    if(l != 2)
      return -l;
    codepoint = ((uint32_t)source[0] & 0x1f) << 6 | ((uint32_t)source[1] & 0x3f);
  } else if((source[0] & 0xf0) == 0xe0) {
    if(l != 3)
      return -l;
    codepoint = (((uint32_t)source[0] & 0x0f) << 12)
              | (((uint32_t)source[1] & 0x3f) << 6)
              | ((uint32_t)source[2] & 0x3f);
  } else if((source[0] & 0xf8) == 0xf0) {
    if(l != 4)
      return -l;
    codepoint = (((uint32_t)source[0] & 0x07) << 18)
              | (((uint32_t)source[1] & 0x3f) << 12)
              | (((uint32_t)source[2] & 0x3f) << 6)
              | ((uint32_t)source[3] & 0x3f);
  } else {
    return -l;
  }

  // Char tables map 0x1fxxx as 0x0fxxx, so do the conversion
  if((codepoint & 0x1f000) == 0x0f000)
    return -l;
  if((codepoint & 0x1f000) == 0x1f000)
    codepoint &= 0xfffeffff;

  for(uint32_t i = 0; i < sizeof(translitChars) / sizeof(translitChars[0]); ++i) {
    if(translitChars[i][0] == codepoint) {
      *target = (uint8_t)translitChars[i][1];
      return l;
    }
  }

  for(c = 0; c < sizeof(highChars) / sizeof(highChars[0]); ++c) {
    if(highChars[c] == codepoint) {
      *target = c + 0x7f;
      return l;
    }
  }
  for(c = 0; c < sizeof(lowChars) / sizeof(lowChars[0]); ++c) {
    if(lowChars[c] == codepoint) {
      *target = c;
      return l;
    }
  }

  return -l;
}

int GemPattern::toUnicode(char *target, int bufSize) const {
  int chars = 0;

  // Expand name
  for(int i = 0; i < 8 && chars < bufSize && pattern[i] != ' '; ++i)
    chars += appendUnicode(pattern[i], &target[chars], bufSize - chars);

  if(pattern[8] != ' ' && chars < bufSize) {
    target[chars] = '.';
    ++chars;
  }

  // Expand extension
  for(int i = 8; i < 11 && chars < bufSize && pattern[i] != ' '; ++i)
    chars += appendUnicode(pattern[i], &target[chars], bufSize - chars);

  // Terminate target string
  if(chars < bufSize) {
    target[chars] = '\0';
    ++chars;
  }

  return chars;
}

int GemPattern::appendUnicode(char atariChar, char *target, int bufSize) {
  uint16_t c;

  // Get unicode codepoint for this atari character
  if(atariChar < 0x20) {
    c = lowChars[(uint8_t)atariChar];
  } else if(atariChar >= 0x7f) {
    c = highChars[(uint8_t)atariChar - 0x7f];
  } else {
    c = atariChar;
  }

  // Output codepoint as UTF-8

  if(c < 0x80) {
    if(bufSize < 1)
      return 0;
    target[0] = c;
    return 1;
  }

  if(c < 0x800) {
    if(bufSize < 2)
      return 0;
    target[0] = 0xc0 | ((c >> 6) & 0x1f);
    target[1] = 0x80 | (c & 0x3f);
    return 2;
  }

  if(c < 0xf000) {
    if(bufSize < 3)
      return 0;
    target[0] = 0xe0 | ((c >> 12) & 0x0f);
    target[1] = 0x80 | ((c >> 6) & 0x3f);
    target[2] = 0x80 | (c & 0x3f);
    return 3;
  }

  // Map fxxx as 1fxxx
  if(bufSize < 4)
    return 0;
  target[0] = 0xf0;
  target[1] = 0x90 | ((c >> 12) & 0x3f);
  target[2] = 0x80 | ((c >> 6) & 0x3f);
  target[3] = 0x80 | (c & 0x3f);
  return 4;
}

int GemPattern::toAtari(char *target) const {
  int chars = 0;

  // Expand name
  for(int i = 0; i < 8 && pattern[i] != ' '; ++i) {
    target[chars] = pattern[i];
    ++chars;
  }

  // Append extension dot if needed
  if(pattern[8] != ' ') {
    target[chars] = '.';
    ++chars;
  }

  // Expand extension
  for(int i = 8; i < 11 && pattern[i] != ' '; ++i) {
    target[chars] = pattern[i];
    ++chars;
  }

  target[chars] = 0;
  return chars;
}

bool GemPattern::isFileName() const {
  return !isEmpty() && !isCurDir() && !isParentDir() && !hasWildcards();
}

bool GemPattern::hasWildcards() const {
  for(int i = 0; i < 11; ++i)
    if(pattern[i] == '?')
      return true;

  return false;
}

bool GemPattern::isWildcard() const {
  for(int i = 0; i < 11; ++i)
    if(pattern[i] != '?')
      return false;

  return true;
}

bool GemPattern::isEmpty() const {
  return pattern[0] == ' ' && pattern[8] == ' ';
}

bool GemPattern::isCurDir() const {
  return pattern[0] == '.' && pattern[1] == ' ' && pattern[8] == ' ';
}

bool GemPattern::isParentDir() const {
  return pattern[0] == '.' && pattern[1] == '.' && pattern[2] == ' ' && pattern[8] == ' ';
}

void GemPattern::clear() {
  for(int i = 0; i < 11; ++i)
    pattern[i] = ' ';
}

void GemPattern::setCurDir() {
  clear();
  pattern[0] = '.';
}

void GemPattern::setParentDir() {
  setCurDir();
  pattern[1] = '.';
}

bool GemPattern::attribMatching(uint8_t attrib, uint8_t fileAttrib) {
  if(attrib & 0x08)
    // Special case for volume
    return fileAttrib & 0x08;

  attrib |= 0x21; // Ignore read-only and archive
  return !fileAttrib || (attrib & fileAttrib);
}

GemPath::GemPath(SdDev &sd_): sd(sd_), mediaId(0) {
  indexes[0] = 0;
}

GemPath & GemPath::operator=(const GemPath &other) {
  close();
  int i;
  for(i = 0; i < maxDepth && other.indexes[i]; ++i)
    indexes[i] = other.indexes[i];
  if(i < maxDepth)
    indexes[i] = 0;

  mediaId = other.mediaId;

  *(FsFile*)this = other;

  return *this;
}

bool GemPath::operator==(GemPath &other) {
  if(sd.mediaId() != mediaId)
    return false;
  return mediaId == other.mediaId && TinyFile::getCluster(*this) == TinyFile::getCluster(other);
}

bool GemPath::operator!=(GemPath &other) {
  return !(*this == other);
}

bool GemPath::append(FsFile &f) {
  for(int i = 0; i < maxDepth; ++i) {
    if(indexes[i] == 0) {
      // Append file's dirIndex
      indexes[i] = f.dirIndex() + 1;

      // Terminate the index list
      if(i < maxDepth - 1)
        indexes[i + 1] = 0;

      *(FsFile*)this = f;
      return true;
    }
  }

  // Path full
  return false;
}

bool GemPath::parent() {
  if(isRoot())
    return false;

  int i;
  for(i = 1; i < maxDepth && indexes[i]; ++i);
  indexes[i - 1] = 0;

  // Traverse from root to open the parent
  close();
  FsFile f[2];
  f[0].openRoot(&sd.fs);
  f[1].openRoot(&sd.fs);
  for(i = 0; i < maxDepth && f[i & 1] && indexes[i]; ++i) {
    FsFile &from = f[i & 1];
    FsFile &to = f[~i & 1];
    to.open(&from, (uint32_t)indexes[i] - 1, O_RDONLY);

    if(!to || !to.isDir()) {
      // Don't keep an invalid path
      clear();
      return false;
    }
  }
  *(FsFile*)this = f[i & 1];

  return true;
}

void GemPath::clear() {
  indexes[0] = 0;
  close();
  mediaId = sd.mediaId();
  if(sd.mountable)
    openRoot(&sd.fs);
}

void GemPath::close() {
  FsFile resetFile;
  memcpy((FsFile *)this, &resetFile, sizeof(resetFile));
}

bool GemPath::openPath(const char *path, GemPattern &last, bool parseLastName) {
  if(*path == '\\') {
    ++path;
    clear();
  } else if(mediaId != sd.mediaId()) {
    // Disk swapped

    mediaId = 0; // Invalidate path

    if(!isRoot())
      // The only guaranteed valid path is the root path
      return false;

    clear();
  }

  for(;;) {
    path = last.parseAtari(path);
    if(!parseLastName && !*path)
      return true;

    if(*path)
      ++path; // Skip separator

    // Traverse path element
    if(last.hasWildcards()) {
      // Wildcards are forbidden in path elements
      return false;
    } else if(last.isCurDir() || last.isEmpty()) {
      // Do nothing
    } else if(last.isParentDir()) {
      if(!parent())
        return false;
    } else {
      FsFile child;
      if(!openFile(last, child))
        return false;
      if(!child || !child.isDir())
        // Invalid entry, just stop there
        return false;

      // Descend into the directory
      append(child);
    }

    if(parseLastName && !*path)
      return true;
  }
}

bool GemPath::openFile(const GemPattern &name, FsFile &file, oflag_t oflag) {
  if(mediaId != sd.mediaId())
    // Disk swapped
    return false;

  rewind();
  for(;;) {
    file.openNext(this, O_RDONLY);
    if(!file)
      return false;

    if(name == file) {
      if(oflag == O_RDONLY)
        return true;

      // Reopen with the correct flags
      auto index = file.dirIndex();
      return file.open(this, index, oflag);
    }
  }
}

int GemPath::toAtari(char *out, int bufSize) const {
  if(isRoot()) {
    out[0] = '\\';
    out[1] = 0;
    return 1;
  }

  if(mediaId != sd.mediaId()) {
    // Disk swapped
    *out = 0;
    return -1;
  }

  FsFile f[2];
  f[0].openRoot(&sd.fs);
  f[1].openRoot(&sd.fs);
  int len = 0;
  int i = 0;

  for(i = 0; i < maxDepth && f[i & 1] && indexes[i] && bufSize - len > 14; ++i) {
    // Append a separator
    out[len++] = '\\';

    // Point at next file
    FsFile &from = f[i & 1];
    FsFile &to = f[~i & 1];
    to.open(&from, (uint32_t)indexes[i] - 1, O_RDONLY);

    if(!to || !to.isDir()) {
      // Invalid path
      *out = 0;
      return -1;
    }

    // Get file name
    if((int)to.getName(&out[len], bufSize - len) >= bufSize - len - 1) {
      // Buffer too small
      *out = 0;
      return -1;
    }
    GemPattern name;
    if(!name.parseUnicode(&out[len])) {
      // Invalid path
      *out = 0;
      return -1;
    }

    // Append Atari name
    int nameLen = name.toAtari(&out[len]);
    len += nameLen;
  }

  out[len] = 0;
  return len;
}

int GemPath::toUnicode(char *out, int bufSize) const {
  if(mediaId != sd.mediaId()) {
    // Disk swapped
    *out = 0;
    return -1;
  }

  int len = 0;

  out[len++] = '/';
  --bufSize;

  if(isRoot()) {
    out[len] = 0;
    return len;
  }

  FsFile f[2];
  f[0].openRoot(&sd.fs);
  f[1].openRoot(&sd.fs);
  int i = 0;

  for(i = 0; i < maxDepth && f[i & 1] && indexes[i] && bufSize > 15; ++i) {
    // Point at next file
    FsFile &from = f[i & 1];
    FsFile &to = f[~i & 1];
    to.open(&from, (uint32_t)indexes[i] - 1, O_RDONLY);

    if(!to || !to.isDir()) {
      // Invalid path
      *out = 0;
      return -1;
    }

    // Get file name
    int nameLen = to.getName(&out[len], bufSize);

    if(nameLen >= bufSize - 2) {
      // Buffer too small
      *out = 0;
      return -1;
    }

    len += nameLen;
    bufSize -= nameLen;

    // Append separator
    out[len++] = '/';
    --bufSize;
  }

  out[len] = 0;
  return len;
}

bool GemPath::isContainedBy(FsFile &file) const {
  if(file.isDir() && !file.isSubDir())
    return true;

  uint32_t fileCluster = TinyFile::getCluster(file);

  FsFile f[2];
  f[0].openRoot(&sd.fs);
  f[1].openRoot(&sd.fs);
  for(int i = 0; i < maxDepth && f[i & 1] && indexes[i]; ++i) {
    // Point at next file
    FsFile &from = f[i & 1];
    FsFile &to = f[~i & 1];
    to.open(&from, (uint32_t)indexes[i] - 1, O_RDONLY);

    if(!to || !to.isDir()) {
      // Invalid path
      return false;
    }

    if(TinyFile::getCluster(to) == fileCluster)
      return true;
  }

  return false;
}

void GemFile::set(GemPath &parent, FsFile &file, oflag_t oflag_, Long basePage_) {
  TinyFile::set(parent.mediaId, parent, file);
  position = 0;
  basePage = basePage_;
  oflag = oflag_;
}

FsFile & GemFile::reopen() {
  auto *drive = GemDrive::getDrive(mediaId);
  if(!drive) {
    closeLast();
    return lastFile;
  }
  open(drive->sd.fs, oflag);
  if(!lastFile)
    return lastFile;
  if(!lastFile.seek(position))
    close();
  return lastFile;
}

int32_t GemFile::read(uint8_t *data, int32_t size) {
  FsFile &file = reopen();
  if(!file)
    return -1;

  int r = file.read(data, size);
  position = file.curPosition();

  return r;
}

int32_t GemFile::write(uint8_t *data, int32_t size) {
  FsFile &file = reopen();
  if(!file)
    return -1;

  int w = file.write(data, size);
  position = file.curPosition();

  return w;
}

int32_t GemFile::seek(int32_t offset, int whence) {
  FsFile &file = reopen();
  if(!file)
    return -1;

  switch(whence) {
    case 0:
      if(!file.seek(offset))
        return -1;
      break;
    case 1:
      if(!file.seek(position + offset))
        return -1;
      break;
    case 2:
      if(!file.seek(file.fileSize() + offset))
        return -1;
      break;
    default:
      return -1;
  }

  position = file.curPosition();
  return position;
}

bool GemFile::checkMedium() const {
  return GemDrive::getDrive(mediaId);
}

bool GemFile::isWritable() const {
  return oflag & O_RDWR;
}

GemDrive::GemDrive(SdDev &sd_): sd(sd_), curPath(sd_) {}

void GemDrive::process(uint8_t cmd) {
  switch(cmd) {
#if ! ACSI_PIO
    case 0x08:
      {
        // Read command: inject syshook driver into a boot sector

        // Read subsequent command bytes
        for(int b = 0; b < 5; ++b)
          buf[b] = DmaPort::readIrq();

        if(buf[0] != 0x00 || buf[1] != 0x00 || buf[2] != 0x00 || buf[3] != 0x01 || buf[4] != 0x00) {
          // Not a boot query: send the 'no operation' SCSI status
          DmaPort::sendIrq(0x08);
        }

        // Build a boot sector
        memcpy(buf, GEMDRIVE_boot_bin, GEMDRIVE_boot_bin_len);

        // Patch ACSI id
        buf[GEMDRIVE_boot_acsiid] = (Devices::gemBootDrive + Devices::acsiFirstId) << 5;

        // Patch checksum
        buf[ACSI_BLOCKSIZE - 2] = 0;
        buf[ACSI_BLOCKSIZE - 1] = 0;
        int value = 0x1234 - computeChecksum(buf);
        buf[ACSI_BLOCKSIZE - 2] = (uint8_t)(value >> 8);
        buf[ACSI_BLOCKSIZE - 1] = (uint8_t)(value);

        // Send the boot sector
        DmaPort::sendDma(buf, ACSI_BLOCKSIZE);

        // Acknowledge the ACSI read command
        DmaPort::sendIrq(0);
      }
      break;

    case 0x09:
      {
        // Acknowledge the GemDrive boot command
        DmaPort::sendIrq(0);

        // Wait for the command byte telling that the ST is ready
        DmaPort::waitCommand();
        // The ST is now waiting for commands

        // Process initialization
        dbg("boot ");
        onBoot();
      }
      break;
#endif

    case 0x0e:
      // GEMDOS system call hook
      dbg("GEMDOS ");
      onGemdos();
      break;

    case INIT_CMD:
      // ACSI2STM direct initialization command

      // Read subsequent command bytes
      for(int b = 0; b < 5; ++b)
        buf[b] = DmaPort::readIrq();

      if(buf[0] != 0x00 || buf[1] != 'G' || buf[2] != 'D' || buf[3] != 'R' || buf[4] != 'V') {
        // Incorrect query: send the 'no operation' SCSI status
        DmaPort::sendIrq(0x08);
        break;
      }

      // Acknowledge the ACSI command
      DmaPort::sendIrq(0);

      // Wait for the command byte telling that the ST is ready
      DmaPort::waitCommand();
      // The ST is now waiting for commands

      // Do initialization process
      dbg(" Init ");
      onInit();
      break;

#if ACSI_PIO
    case 0x0f: {
      // PIO firmware upload

      // Read subsequent command bytes
      for(int b = 0; b < 5; ++b)
        buf[b] = DmaPort::readIrq();

      int fwSize = ((int)(uint8_t)buf[3]) << 8 | (int)(uint8_t)buf[4];

      if(buf[0] == 0 && buf[1] == 'P' && buf[2] == 'I' && buf[3] == 'O' && buf[4] == '?' ) {
        // PIO firmware query
        dbg(" PIO query ");
        DmaPort::sendIrq(0);
        break;
      }

      if(buf[0] != 0 || buf[1] != 'F' || buf[2] != 'W' || fwSize <= 32000) {
        // Incorrect query: send the 'no operation' SCSI status
        dbg(" Wrong PIO query ");
        DmaPort::sendIrq(0x08);
        break;
      }

      // Acknowledge the ACSI command
      DmaPort::sendIrq(0);

      // Start flashing procedure
      flashFirmware(fwSize);
      break;
    }
#endif

    default:
      // For unknown commands, play dead to avoid confusing other drivers
      dbg(" Ignore ");
      break;
  }
}

void GemDrive::onBoot() {
#ifdef ACSI_GEMDRIVE_LOAD_EMUTOS
  // Check for EmuTOS
  auto &fs = Devices::sdSlots[Devices::gemBootDrive].fs;
  if(fs.exists(ACSI_GEMDRIVE_LOAD_EMUTOS)) {
    // EmuTOS found. Load and run it.
    FsFile emutos = fs.open(ACSI_GEMDRIVE_LOAD_EMUTOS);
    uint32_t basepage;
    uint32_t result = loadPrg(emutos, ToLong(0), ToLong(0), basepage);
    if(result == E_OK) {
      dbg("Run EmuTOS\n");
      Pexec_4(ToLong(basepage));
      return;
    }
  }
#endif

  // Prepare the driver binary
  memcpy(buf, GEMDRIVE_boot_bin, GEMDRIVE_boot_bin_len);

  // Patch ACSI id
  buf[GEMDRIVE_boot_acsiid] |= (Devices::gemBootDrive + Devices::acsiFirstId) << 5;

  // Patch parameter offset
  buf[GEMDRIVE_boot_prmoff + 1] = _longframe() ? 8 : 6;

  // Upload the driver to resident memory

  uint32_t driverSize = (GEMDRIVE_boot_bin_len + 0xf) & 0xfffffff0;
  ToLong driverMem = Malloc(driverSize);

  sendAt(driverMem, buf, GEMDRIVE_boot_bin_len);

  // Install system call hooks
  // Warning: installed system calls must be the same as in asm/GEMDRIVE/gem.s
  installHook(driverMem, 0x84); // GEMDOS

  onInit(true);
}

void GemDrive::onInit(bool setBootDrive) {
  int d;

  // Driver splash screen
  tosPrint("\eE", "ACSI2STM " ACSI2STM_VERSION " by Jean-Matthieu Coulon", "\r\n",
           "GPLv3 license. Source & doc at", "\r\n",
           " https://github.com/retro16/acsi2stm", "\r\n\n");

#if ACSI_DEBUG
#if ACSI_VERBOSE
  tosPrint("Verbose log\r\n\n");
#else
  tosPrint("Debug log\r\n\n");
#endif
#endif

#if ACSI_PIO
  tosPrint("Running in PIO mode\r\n\n");
#endif

  // Set dmatop to phystop
  dmatop = phystop();

  // Cache OSHEADER values
  os_beg = _sysbase();
  os_beg = readLongAt(os_beg + offsetof(OSHEADER, os_beg));

  // Check TOS version
  os_version = readWordAt(os_beg + offsetof(OSHEADER, os_version));
  dbgHex("TOS ", os_version, ' ');
  if(os_version < 0x104)
    tosPrint("\x07TOS < 1.04 has issues with GemDrive\r\n\n");

  // Get basepage pointer
  os_conf = readWordAt(os_beg + offsetof(OSHEADER, os_conf));
  if(os_version < 0x102) {
    if(os_conf >> 1 == 4)
      p_run = 0x873c; // Spanish TOS 1.00 basePage pointer
    else
      p_run = 0x602c; // TOS 1.00 basePage pointer
  } else {
    p_run = readLongAt(os_beg + offsetof(OSHEADER, p_run));
  }

  // Unmount all drives and initialize SD cards
  for(d = 0; d < driveCount; ++d) {
    Devices::drives[d].id = -1;
    if(Devices::sdSlots[d].mode == SdDev::GEMDRIVE)
      Devices::sdSlots[d].init();
  }

  // Mount drives
  setCurDrive(Dgetdrv());

  // Compute first drive letter
#if ACSI_GEMDRIVE_FIRST_LETTER
  static const int firstDriveLetter = ACSI_GEMDRIVE_FIRST_LETTER;
#else
#if ACSI_GEMDRIVE_LETTER_ID_OFFSET
  int firstDriveLetter = 'C' + Devices::acsiFirstId;
#else
  int firstDriveLetter = 'C';
#endif
#if ! ACSI_PIO
  for(d = 0; d < driveCount; ++d)
    if(Devices::sdSlots[d].mode == SdDev::ACSI)
      // Avoid conflicts with legacy drivers that don't respect _drvbits.
      firstDriveLetter = 'L';
#endif
#endif
  uint32_t drvbits = _drvbits();

  for(d = 0; d < driveCount; ++d) {
    if(Devices::sdSlots[d].mode != SdDev::GEMDRIVE)
      continue;

    // Reset current path to root
    Devices::drives[d].curPath.clear();

    buf[1] = ':';
    buf[2] = ' ';
    for(int i = (d + firstDriveLetter - 'A'); i < 26; ++i) {
      if(!(drvbits & (1 << i))) {
        Devices::drives[d].id = i;
        drvbits |= (1 << i);

        buf[0] = 'A' + i;
        Devices::sdSlots[d].getDeviceString((char *)&buf[3]);
#if ACSI_DEBUG
        buf[27] = 0;
        dbg("\n        ", (const char *)buf, " ");
#endif
        buf[27] = '\r';
        buf[28] = '\n';
        buf[29] = 0;
        tosPrint((const char *)buf);

        break;
      }
    }
  }
  _drvbits(drvbits);

  // Set boot drive on the ST
  if(setBootDrive) {
    for(d = 0; d < driveCount; ++d) {
      if(Devices::sdSlots[d].mode == SdDev::GEMDRIVE && Devices::sdSlots[d].mountable) {
        dbg("\n        ", "Boot on ");
        setCurDrive(Devices::drives[d].id);
        _bootdev(Devices::drives[d].id);
        Dsetdrv(Devices::drives[d].id);
        memcpy(buf, "\r\nBoot on ?:\r\n\n", 17);
        buf[10] = Devices::drives[d].letter();
        tosPrint((const char *)buf);
        break;
      }
    }
  }

#if ACSI_RTC
  if(!Devices::isDateTimeSet())
#endif
  // Get time from the ST, in case it has an internal clock. Set unconditionally
  // if ACSI_RTC is disabled to keep file dates in sync with the ST clock.
  Devices::setDateTime(Tgetdate(), Tgettime());

#if ACSI_RTC
  else {
    // Sync internal ST clock with ours
    uint16_t date;
    uint16_t time;
    Devices::getDateTime(&date, &time);
    Tsetdate(date);
    Tsettime(time);
  }
#endif

#if ACSI_DEBUG
  // With a debug build, just leave a small delay to make onscreen messages
  // easily readable.
  delay(400);
#endif

  // Continue boot sequence
  forward();
}

void GemDrive::onGemdos() {
  Word op = readWord();
  switch(op) {
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: { name ## _p p; \
    dbg(#name "("); \
    readParams(&p, sizeof(p)); \
    dbg("):"); \
    on ## name(p); \
  } return

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
  DECLARE_CALLBACK(Fsnext);
  DECLARE_CALLBACK(Fsfirst);
  DECLARE_CALLBACK(Frename);
  DECLARE_CALLBACK(Fdatime);

  // Just log these callbacks
#if ACSI_DEBUG
#undef DECLARE_CALLBACK
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: { name ## _p p; \
    dbg(#name "("); \
    readParams(&p, sizeof(p)); \
    dbg("):"); \
  } break
#else
#undef DECLARE_CALLBACK
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: break
#endif

  DECLARE_CALLBACK(Cconin);
  DECLARE_CALLBACK(Cconout);
  DECLARE_CALLBACK(Cauxin);
  DECLARE_CALLBACK(Cauxout);
  DECLARE_CALLBACK(Cprnout);
  DECLARE_CALLBACK(Crawio);
  DECLARE_CALLBACK(Crawcin);
  DECLARE_CALLBACK(Cnecin);
  DECLARE_CALLBACK(Cconrs);
  DECLARE_CALLBACK(Cconis);
  DECLARE_CALLBACK(Cconos);
  DECLARE_CALLBACK(Cprnos);
  DECLARE_CALLBACK(Cauxis);
  DECLARE_CALLBACK(Cauxos);
  DECLARE_CALLBACK(Dgetdrv);
  DECLARE_CALLBACK(Fsetdta);
  DECLARE_CALLBACK(Super);
  DECLARE_CALLBACK(Malloc);
  DECLARE_CALLBACK(Mfree);
  DECLARE_CALLBACK(Mshrink);
  DECLARE_CALLBACK(Ptermres);

#undef DECLARE_CALLBACK

  default:
    dbgHex((uint32_t)op, ' ');
    break;
  }
  forward();
}

bool GemDrive::onPterm0(const Tos::Pterm0_p &) {
  closeProcessFiles();
  return forward();
}

bool GemDrive::onCconws(const Tos::Cconws_p &p) {
#if ACSI_DEBUG
  readStringAt((char *)buf, p.buf, sizeof(buf));
  dbg("buf='", (const char *)buf, "' ");
#else
  (void)p;
#endif
  return forward();
}

bool GemDrive::onDsetdrv(const Tos::Dsetdrv_p &p) {
  // Track current drive
  setCurDrive(p.drv);
  return forward();
}

bool GemDrive::onTsetdate(const Tos::Tsetdate_p &p) {
  // Set even if ACSI_RTC is disabled to keep file dates in sync with the ST
  // clock.
  uint16_t date;
  uint16_t time;
  getDateTime(&date, &time);
  date = p.date;
  setDateTime(date, time);

  return forward();
}

bool GemDrive::onTsettime(const Tos::Tsettime_p &p) {
  // Set even if ACSI_RTC is disabled to keep file dates in sync with the ST
  // clock.
  uint16_t date;
  uint16_t time;
  getDateTime(&date, &time);
  time = p.time;
  setDateTime(date, time);

  return forward();
}

bool GemDrive::onDfree(const Tos::Dfree_p &p) {
  uint8_t driveId = p.driveno.bytes[1];
  GemDrive *drive = driveId ? getDrive(uint8_t(driveId - 1)) : curDrive;

  if(!drive)
    return forward(); // Unknown device: forward

  if(!drive->sd.mountable)
    return rte(EACCDN);

  auto &sd = drive->sd;
  auto &volume = sd.fs;

  uint32_t clsiz = volume.sectorsPerCluster();
  uint32_t total = volume.clusterCount();
  uint32_t free = volume.freeClusterCount();

  // Unsurprisingly, the ST can't really handle gigabytes, so we have to cap
  // these values. As long as there is more free space than what a ST operating
  // system could imagine, we should be fine
  uint64_t realSize = (uint64_t)total * clsiz * 512;
  uint64_t realFree = (uint64_t)free * clsiz * 512;
  uint64_t realUsed = realSize - realFree;

  // Cap to 9 digits
  const uint64_t sizeCap = 999999999;
  const int clCap = 32; // Cap clusters to 16384 bytes

  if(realSize > sizeCap || clsiz > clCap) {
    realSize = sizeCap;

    // Any used space below half cap is shown, any free space lacking below half
    // cap is shown too
    if(realFree < sizeCap / 2)
      realUsed = realSize - realFree;
    else if(realUsed > sizeCap / 2)
      realUsed = sizeCap / 2;
    realFree = realSize - realUsed;

    if(clsiz > clCap)
      clsiz = clCap;

    total = realSize / clsiz / 512;
    free = realFree / clsiz / 512;
  }

  DISKINFO di;
  di.b_free = free;
  di.b_total = total;
  di.b_secsiz = 512;
  di.b_clsiz = clsiz;

  sendAt(di, p.buf);

  return rte(E_OK);
}

bool GemDrive::onDcreate(const Tos::Dcreate_p &p) {
  char *path;
  GemDrive *drive = getDrive(p.path, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath parent = drive->curPath;
  GemPattern name;
  if(!parent.openPath(path, name))
    return rte(EPTHNF);

  const char *unicodeName = toUnicode(parent, name);
  if(!unicodeName)
    return rte(EPTHNF);

  dbg("-> ", unicodeName, ' ');

  if(!name || name.isCurDir() || name.isParentDir())
    return rte(EPTHNF);

  if(!drive->sd.fs.mkdir(unicodeName, false))
    return rte(EACCDN);

  return rte(E_OK);
}

bool GemDrive::onDdelete(const Tos::Ddelete_p &p) {
  char *path;
  GemDrive *drive = getDrive(p.path, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath dir = drive->curPath;
  GemPattern name;
  if(!dir.openPath(path, name, true))
    return rte(EPTHNF);

  if(!dir.isDir())
    return rte(EPTHNF);

  if(!dir.isSubDir())
    return rte(EACCDN);

  const char *unicodeName = toUnicode(dir);
  if(!unicodeName)
    return rte(EPTHNF);

  dbg("-> ", unicodeName, ' ');
  if(!drive->sd.fs.rmdir(unicodeName))
    return rte(EACCDN);

  return rte(E_OK);
}

bool GemDrive::onDsetpath(const Tos::Dsetpath_p &p) {
  if(!curDrive)
    // Current drive is not mounted
    return forward();

  if(!curDrive->sd.mountable)
    // Current drive has no medium
    return rte(EACCDN);

  char *path = (char *)buf;
  readStringAt(path, p.path, sizeof(buf));
  dbg("path='", path, "' ");

  if(path[0] && path[1] == ':')
    path += 2;

  GemPath newPath = curDrive->curPath;

  GemPattern name;
  if(!newPath.openPath(path, name, true))
    return rte(EPTHNF);

  if(!newPath.isDir())
    return rte(EPTHNF);

#if ACSI_DEBUG
  const char *unicodeName = toUnicode(newPath);
  dbg("-> ", unicodeName ? unicodeName : "(null)", ' ');
#endif

  curDrive->curPath = newPath;

  return rte(E_OK);
}

bool GemDrive::onFcreate(const Tos::Fcreate_p &p) {
  char *path;
  auto drive = getDrive(p.fname, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath parent = drive->curPath;
  GemPattern name;
  if(!parent.openPath(path, name))
    return rte(EPTHNF);

  if(!name || name.isCurDir() || name.isParentDir())
    return rte(EPTHNF);

  uint8_t attrib = p.attr.bytes[1] | 0x20;

  if(attrib & 0x18)
    // Nonsensical attributes
    return rte(EACCDN);

  FsFile newFile;
  if(!parent.openFile(name, newFile, O_TRUNC | O_RDWR)) {
    const char *unicodeName = toUnicode(parent, name);
    if(!unicodeName)
      // Incompatible character
      return rte(EPTHNF);

    dbg("-> ", unicodeName, ' ');
    newFile = drive->sd.fs.open(unicodeName, O_CREAT | O_TRUNC | O_RDWR);
    if(!newFile || newFile.isDir())
      return rte(EACCDN);
  }

  newFile.attrib(attrib);

  Word fd = drive->createFd(parent, newFile, attribToSdFat(attrib));
  if(!fd)
    return rte(ENHNDL);

  return rte(ToLong(0, 0, fd.bytes[0], fd.bytes[1]));
}

bool GemDrive::onFopen(const Tos::Fopen_p &p) {
  char *path;
  auto drive = getDrive(p.fname, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath parent = drive->curPath;
  GemPattern name;
  if(!parent.openPath(path, name))
    return rte(EFILNF);

  oflag_t oflag = p.mode.bytes[1] & 0x03 ? O_RDWR : O_RDONLY;

  FsFile file;
  parent.openFile(name, file, oflag);

  if(!file) {
    if(parent.openFile(name, file)) {
      bool isDir = file.isDir();
      file.close();
      return isDir ? rte(EFILNF) : rte(EACCDN);
    }
    return rte(EFILNF);
  }

  if(file.isDir())
    return rte(EFILNF);

  if(oflag & O_RDWR)
    // Set the archive flag
    file.attrib(file.attrib() | 0x20);

  Word fd = drive->createFd(parent, file, oflag);
  if(!fd)
    return rte(ENHNDL);

  return rte(ToLong(0, 0, fd.bytes[0], fd.bytes[1]));
}

bool GemDrive::onFclose(const Tos::Fclose_p &p) {
  if(!ownFd(p.handle))
    return forward();

  GemFile &file = files[p.handle.bytes[1]];

  // Don't check medium, close inconditionally

  if(!file)
    return rte(EIHNDL);

  file.close();
  return rte(E_OK);
}

bool GemDrive::onFread(const Tos::Fread_p &p) {
  if(!ownFd(p.handle))
    return forward();

  GemFile &file = files[p.handle.bytes[1]];
  if(!file)
    return rte(EIHNDL);

  if(!file.checkMedium())
    return rte(EACCDN);

  int done = 0;
  int bufSize;
  uint32_t ptr = p.buf;
  int size = p.count;

  if(size < 0)
    return rte(ERANGE);

  while(size > 0) {
    if(size > (int)sizeof(buf))
      bufSize = sizeof(buf);
    else
      bufSize = size;

    // Read data from SD
    int readBytes = file.read(buf, bufSize);

    if(readBytes < 0) {
      // Return error
      return rte(EREADF);
    } else if(readBytes == 0) {
      break;
    } else if(readBytes > 0) {
      // Send data to Atari
      sendAt(ptr, buf, readBytes);
      done += readBytes;
      ptr += readBytes;
      size -= readBytes;
    }
  }

  return rte(ToLong(done));
}

bool GemDrive::onFwrite(const Tos::Fwrite_p &p) {
  if(!ownFd(p.handle))
    return forward();

  GemFile &file = files[p.handle.bytes[1]];
  if(!file)
    return rte(EIHNDL);

  if(!file.isWritable() || !file.checkMedium())
    return rte(EACCDN);

  int done = 0;
  int bufSize;
  uint32_t ptr = p.buf;
  int size = p.count;

  if(size < 0)
    return rte(ERANGE);

  while(size > 0) {
    if(size > (int)sizeof(buf))
      bufSize = sizeof(buf);
    else
      bufSize = size;

    // Read data from Atari
    readAt(buf, ptr, bufSize);

    // Write data onto SD
    int writtenBytes = file.write(buf, bufSize);

    if(writtenBytes < 0) {
      return rte(EWRITF);
    } else {
      done += writtenBytes;
      ptr += writtenBytes;
      size -= writtenBytes;
    }
  }

  // Return read bytes
  return rte(ToLong(done));
}

bool GemDrive::onFdelete(const Tos::Fdelete_p &p) {
  char *path;
  GemDrive *drive = getDrive(p.fname, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath parent = drive->curPath;
  GemPattern name;
  if(!parent.openPath(path, name))
    return rte(EFILNF);

  FsFile file;
  if(!parent.openFile(name, file))
    return rte(EFILNF);

  if(file.isDir())
    return rte(EFILNF);

  const char *unicodeName = toUnicode(parent, file);
  if(!unicodeName)
    // Incompatible character
    return rte(EACCDN);

  dbg("-> ", unicodeName, ' ');
  if(!drive->sd.fs.exists(unicodeName))
    return rte(EFILNF);

  if(!drive->sd.fs.remove(unicodeName))
    return rte(EACCDN);

  return rte(E_OK);
}

bool GemDrive::onFseek(const Tos::Fseek_p &p) {
  if(!ownFd(p.handle))
    return forward();

  GemFile &file = files[p.handle.bytes[1]];
  if(!file)
    return rte(EIHNDL);

  if(!file.checkMedium())
    return rte(EACCDN);

  int32_t r = file.seek(p.offset, p.seekmode.bytes[1]);

  if(r < 0)
    return rte(ERANGE);

  return rte(ToLong(r));
}

bool GemDrive::onFattrib(const Tos::Fattrib_p &p) {
  char *path;
  GemDrive *drive = getDrive(p.fname, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath parent = drive->curPath;
  GemPattern name;
  if(!parent.openPath(path, name))
    return rte(EFILNF);

  FsFile file;
  if(!parent.openFile(name, file))
    return rte(EFILNF);

  if(!file || file.isDir())
    return rte(EFILNF);

  if(p.wflag.bytes[1])
    if(!file.attrib(p.attrib.bytes[1]))
      return rte(EACCDN);

  return rte(ToLong(0, 0, 0, file.attrib()));
}

bool GemDrive::onDgetpath(const Tos::Dgetpath_p &p) {
  uint8_t driveId = p.driveno;
  GemDrive *drive = driveId ? getDrive(uint8_t(driveId - 1)) : curDrive;

  if(!drive)
    return forward(); // Unknown device: forward

  if(!drive->sd.mountable)
    return rte(EACCDN);

  int len = drive->curPath.toAtari((char *)buf, sizeof(buf));

  if(len < 0)
    return rte(ERROR);

  dbg("-> ", (const char *)buf, ' ');
  sendAt(p.path, buf, len + 1);

  return rte(E_OK);
}

bool GemDrive::onPexec(const Tos::Pexec_p &p) {
  if(p.mode != 0 && p.mode != 3)
    return forward();

  // Interpret parameters as Pexec0 / Pexec3 (same structure)
  Pexec_0_p &p0 = *(Pexec_0_p *)&p;

  char *path;
  GemDrive *drive = getDrive(p0.name, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EACCDN);

  GemPath parent = drive->curPath;
  GemPattern name;
  if(!parent.openPath(path, name))
    return rte(EFILNF);

  FsFile prgFile;
  if(!parent.openFile(name, prgFile))
    return rte(EFILNF);

  if(!prgFile || prgFile.isDir())
    return rte(EFILNF);

  uint32_t basepage;
  uint32_t result = loadPrg(prgFile, p0.cmdline, p0.env, basepage);
  if(result != E_OK)
    return rte(result);

  // Finished: run the program or RTE depending on the mode
  if(p.mode == 3)
    rte(ToLong(basepage));
  else if(os_version < 0x104)
    pexec4ThenRte(ToLong(basepage));
  else
    pexec6ThenRte(ToLong(basepage));

  return true;
}

bool GemDrive::onPterm(const Tos::Pterm_p &) {
  closeProcessFiles();
  return forward();
}

bool GemDrive::onFsfirst(const Tos::Fsfirst_p &p) {
  char *path;
  auto drive = getDrive(p.filename, &path);
  if(!drive)
    return forward();
  if(!path)
    return rte(EPTHNF);

  // Initialize a new DTA to scan the directory
  GemDriveDTA dta;

  GemPath parent = drive->curPath;
  if(!parent.openPath(path, dta.pattern))
    return rte(EPTHNF);

  if(dta.pattern.isEmpty() || dta.pattern.isCurDir() || dta.pattern.isParentDir())
    return rte(EFILNF);
  dta.file.set(parent.mediaId, parent);
  dta.attribMask = p.attr;

  // Scan the first file
  return drive->scanDTA(dta, EFILNF);
}

bool GemDrive::onFsnext(const Tos::Fsnext_p &) {
  GemDriveDTA dta;
  readAt(dta, Fgetdta());

  GemDrive *drive = getDrive(dta.file.mediaId, BlockDev::CACHED);
  if(!drive)
    return forward();

  return drive->scanDTA(dta);
}

bool GemDrive::onFrename(const Tos::Frename_p &p) {
  dbg("from ");
  char *fromPath;
  auto fromDrive = getDrive(p.oldname, &fromPath);
  if(!fromDrive)
    return forward();
  if(!fromPath)
    return rte(EACCDN);

  GemPath fromParent = fromDrive->curPath;
  GemPattern fromName;
  if(!fromParent.openPath(fromPath, fromName))
    return rte(EPTHNF);

  if(!fromName)
    return rte(EFILNF);

  dbg("to ");
  char *toPath;
  auto toDrive = getDrive(p.newname, &toPath);
  if(fromDrive != toDrive)
    return rte(ENSAME);
  if(!toPath)
    return rte(EACCDN);

  GemPath toParent = toDrive->curPath;
  GemPattern toName;
  if(!toParent.openPath(toPath, toName))
    return rte(EPTHNF);

  FsFile from;
  fromParent.openFile(fromName, from);

  if(!from)
    return rte(EFILNF);

  if(from.isDir()) {
    // Directories cannot be moved !
    if(fromParent != toParent)
      return rte(EACCDN);
  } else {
    from.close();
    // Open files read-write because read-only files cannot be renamed
    fromParent.openFile(fromName, from, O_RDWR);
    if(!from)
      return rte(EACCDN);
  }

  if(toParent.isContainedBy(from))
    return rte(EACCDN);

  if(toName.isEmpty() || toName.isCurDir() || toName.isParentDir()) {
    if(from.isDir())
      return rte(EFILNF);
    else
      return rte(EBADRQ);
  }

  const char *unicodeName = toUnicode(toParent, toName);
  if(!unicodeName)
    // Incompatible character
    return rte(EACCDN);

  dbg(" to -> ", unicodeName, ' ');
  if(toDrive->sd.fs.exists(unicodeName))
    return rte(EACCDN);
  if(!from.rename(unicodeName))
    return rte(EACCDN);

  return rte(E_OK);
}

bool GemDrive::onFdatime(const Tos::Fdatime_p &p) {
  if(!ownFd(p.handle))
    return forward();

  FsFile &file = files[p.handle.bytes[1]].reopen();
  if(!file)
    return rte(EIHNDL);

  if(p.wflag) {
    // Set time
    DOSTIME dt;
    readAt(dt, p.timeptr);

    dbg("<- ");
    notVerboseDump(&dt, sizeof(dt));
    dbg(' ');

    // SdFat provides a way to get DOS time, but not set it. Too bad, we need
    // to parse the time value even if it will be reprocessed to the exact same
    // value in the library.
    uint16_t time = dt.time;
    uint16_t date = dt.date;
    file.timestamp(T_WRITE,
        FS_YEAR(date),
        FS_MONTH(date),
        FS_DAY(date),
        FS_HOUR(time),
        FS_MINUTE(time),
        FS_SECOND(time));
  } else {
    // Get time
    uint16_t time;
    uint16_t date;
    file.getModifyDateTime(&date, &time);
    DOSTIME dt;
    dt.time = time;
    dt.date = date;
    sendAt(dt, p.timeptr);

    dbg("-> ");
    notVerboseDump(&dt, sizeof(dt));
    dbg(' ');
  }

  return rte(E_OK);
}

void GemDrive::closeAll() {
  for(int i = 0; i < filesMax; ++i) {
    GemFile &file = files[i];
    if(file)
      file.close();
  }
}

void GemDrive::installHook(uint32_t driverMem, ToLong vector) {
  static const Long xbra = ToLong('X', 'B', 'R', 'A');
  static const Long a2st = ToLong('A', '2', 'S', 'T');

  for(unsigned int i = 0; i < GEMDRIVE_boot_bin_len - 14; i += 2) {
    // Scan XBRA/A2ST marker
    if(GEMDRIVE_boot_bin[i] == 'X') {
      Long *lbin = (Long *)(&GEMDRIVE_boot_bin[i]);
      if(lbin[0] == xbra && lbin[1] == a2st && lbin[2] == vector) {
        // Marker found: install the hook to ST RAM
        Long oldVector = readLongAt(vector);
        Long oldVectorAddr = ToLong(driverMem + i + 8);
        Long newVector = ToLong(driverMem + i + 12);
        sendAt(oldVector, oldVectorAddr);
        sendAt(newVector, vector);
        return;
      }
    }
  }
}

void GemDrive::setCurDrive(uint8_t driveId) {
  curDrive = getDrive(driveId);
  if(curDrive)
    dbg(curDrive->letter(), ": (SD", curDrive->sd.slot, ") ");
}

Long GemDrive::getBasePage() {
  return readLongAt(p_run);
}

GemDrive * GemDrive::getDrive(const char *path, const char **outPath) {
  if(path[0] && path[1] == ':') {
    // Absolute path: check drive letter
    char letter = path[0];
    if(letter < 'A')
      return nullptr;
    if(letter > 'Z')
      letter -= 'a' - 'A';
    if(letter > 'Z')
      return nullptr;
    if(outPath)
      *outPath = &path[2];
    for(int i = 0; i < driveCount; ++i) {
      auto &drive = Devices::drives[i];
      if(drive.letter() == letter) {
        if(outPath && (drive.sd.mode != SdDev::GEMDRIVE || !drive.sd.mediaId()))
          *outPath = nullptr;
        return &drive;
      }
    }
    return nullptr;
  }

  // Device name
  if(path[0] && path[1] && path[2] && path[3] == ':')
    return nullptr;

  // Relative path: return current drive

  if(curDrive && curDrive->sd.mode == SdDev::GEMDRIVE)
    *outPath = path;
  else
    *outPath = nullptr;

  return curDrive;
}

GemDrive * GemDrive::getDrive(char *path, char **outPath) {
  return getDrive((const char *)path, (const char **)outPath);
}

GemDrive * GemDrive::getDrive(Long pathAddr, char **outPath) {
  char *path = (char *)buf;

  readStringAt(path, pathAddr, sizeof(buf));
  dbg("path='", path, "' ");

  return getDrive(path, outPath);
}

GemDrive * GemDrive::getDrive(uint8_t id) {
  for(int i = 0; i < driveCount; ++i) {
    auto &drive = Devices::drives[i];
    if(drive.id == id)
      return &drive;
  }
  return nullptr;
}

GemDrive * GemDrive::getDrive(uint32_t mediaId, BlockDev::MediaIdMode mode) {
  if(!mediaId)
    return nullptr;

  for(int i = 0; i < driveCount; ++i) {
    auto &drive = Devices::drives[i];
    if(drive.sd.mediaId(mode) == mediaId && drive.sd.mountable)
      return &drive;
  }

  return nullptr;
}

void GemDrive::closeProcessFiles() {
  Long basePage = getBasePage();
#if ACSI_DEBUG
  int total = 0;
#endif
  for(int fi = 0; fi < filesMax; ++fi) {
    GemFile &file = files[fi];
    if(file && file.basePage == basePage) {
      file.close();
#if ACSI_DEBUG
      ++total;
#endif
    }
  }
#if ACSI_DEBUG
  if(total)
    dbg("Leaked ", total, " fd ");
#endif
}

oflag_t GemDrive::attribToSdFat(uint8_t attrib) {
  // Directories and read-only files require O_RDONLY
  return attrib & 11 ? O_RDONLY : O_RDWR;
}

bool GemDrive::ownFd(Word fd) {
  return fd.bytes[0] == 0x32 + Devices::acsiFirstId && fd.bytes[1] < filesMax;
}

const char * GemDrive::toUnicode(const GemPath &path) {
  char *unicode = (char *)buf;
  int len = path.toUnicode(unicode, sizeof(buf));
  if(len < 0)
    return nullptr;

  return unicode;
}

const char * GemDrive::toUnicode(const GemPath &path, FsFile &file) {
  char *unicode = (char *)buf;
  int len = path.toUnicode(unicode, sizeof(buf));
  if(len < 0)
    return nullptr;

  if(file)
    file.getName(&unicode[len], sizeof(buf) - len);

  return unicode;
}

const char * GemDrive::toUnicode(const GemPath &path, GemPattern &name) {
  char *unicode = (char *)buf;
  int len = path.toUnicode(unicode, sizeof(buf));
  if(len < 0)
    return nullptr;

  if(name.toUnicode(&unicode[len], sizeof(buf) - len) < 0)
    return nullptr;

  return unicode;
}

void GemDrive::readParams(void *data, uint32_t size) {
  if(size > 1) {
    readDma((uint8_t *)data, size);
    notVerboseDump((uint8_t *)data, size);
  }
}

uint32_t GemDrive::loadPrg(FsFile &prgFile, Long cmdline, Long env, uint32_t &basepage) {
#if ACSI_DEBUG
  char *name = (char *)buf;
  prgFile.getName(name, sizeof(buf));
  dbg("Loading ", name, ' ');
#endif

  // Read program header
  PH ph;
  if(prgFile.read(&ph, sizeof(ph)) != sizeof(ph))
    return EPLFMT;

  // Check program format and file size
  if(ph.ph_branch != ToWord(0x60, 0x1a)
     || ph.ph_tlen.bytes[0]
     || ph.ph_dlen.bytes[0]
     || ph.ph_slen.bytes[0])
    return EPLFMT;

  if(prgFile.fileSize() < sizeof(ph) + ph.ph_tlen + ph.ph_dlen + ph.ph_slen + (ph.ph_absflag ? 0 : 4))
    return EPLFMT;

  // Check free memory
  if(Malloc(ToLong(0xff, 0xff, 0xff, 0xff)) < sizeof(PD) + ph.ph_tlen + ph.ph_dlen + ph.ph_blen)
    return ENSMEM;

  // Create base page
  if(os_version < 0x200)
    basepage = Pexec_5(cmdline, env);
  else
    basepage = Pexec_7(ph.ph_prgflags, cmdline, env);

  // Setup basepage
  PD pd;
  readAt(pd, basepage);
  pd.p_tbase = basepage + sizeof(PD);
  pd.p_tlen = ph.ph_tlen;
  pd.p_dbase = basepage + sizeof(PD) + ph.ph_tlen;
  pd.p_dlen = ph.ph_dlen;
  pd.p_bbase = basepage + sizeof(PD) + ph.ph_tlen + ph.ph_dlen;
  pd.p_blen = ph.ph_blen;
  sendAt(pd, basepage);

  if(ph.ph_prgflags.bytes[3] & 1)
    // FASTLOAD set: clear BSS only
    clearAt(ph.ph_blen, pd.p_bbase);
  else
    // FASTLOAD not set: clear the whole program space
    clearAt(pd.p_hitpa - pd.p_bbase, pd.p_bbase);

  // The relocation table itself starts with a 32-bit value which marks the
  // offset of the first value to be relocated relative to the start of the
  // TEXT segment.
  // Single bytes are then used for all following offsets. To be able to handle
  // offsets greater than 255 correctly, one proceeds as follows:
  // If a 1 is found as an offset then the value 254 is added automatically to
  // the offset.
  // For very large offsets this procedure can of course be repeated.
  // Incidentally, an empty relocation table is flagged with a LONG value of 0.

  // Load the binary
  uint32_t prgStart = basepage + sizeof(PD);
  uint32_t prgPtr = prgStart;
  uint32_t prgSize = ph.ph_tlen + ph.ph_dlen;
  uint32_t prgOffset = 0;
  int block;
  FsFile relFile = prgFile;
  int relTableIndex = 0;
  int relTableSize = 0;
  int relOffset = -1; // means "no relocation"

  if(!ph.ph_absflag) {
    // Load reloction offset
    Long ro;
    relFile.seek(sizeof(ph) + ph.ph_tlen + ph.ph_dlen + ph.ph_slen);
    if(relFile.read(&ro, sizeof(ro)) != sizeof(ro))
      goto relocationFailed;
    relOffset = ro;
    if(!relOffset)
      relOffset = -1;
  }

  if(relOffset >= 0)
    verbose("Relocations:\n");

  do {
    // Read program block
    block = (prgSize - prgOffset > sizeof(buf)) ? sizeof(buf) : prgSize - prgOffset;
    block = prgFile.read(buf, block);
    if(block < 0)
      goto relocationFailed;
    if(!block)
      break;

    if(relOffset >= 0) {
      // Relocate block
      while(relOffset < block) {
        // Relocation offset is inside the currrent block

        if(relOffset + 4 > block) {
          // No luck: the address is in the middle of the loading block.
          // Just shift block size and resume relocation at next iteration.
          int shift = block - relOffset;
          if(!prgFile.seekCur(-shift))
            goto relocationFailed;
          block = relOffset;
          break;
        }

        // Apply current relocation vector
        ToLong value(&buf[relOffset]);
        verboseHex("Patch ", relOffset + prgOffset, ": ", (uint32_t)value);
        value += prgStart;
        verboseHex(" -> ", (uint32_t)value, '\n');
        value.set(&buf[relOffset]);

        // Load more relocation info if needed
loadRelocationInfo:
        if(relTableIndex == relTableSize) {
          // Need to load more relocation info
          relTableSize = relFile.read(relTableCache, sizeof(relTableCache));
          relTableIndex = 0;
          verbose("Loaded ", relTableSize, " bytes\n");
          if(relTableSize < 0)
            goto relocationFailed;
          else if(!relTableSize) {
            // End of relocation info
            relOffset = -1;
            break;
          }
        }

        // Point at next relocation address

        if(relTableCache[relTableIndex] == 0) {
          // End of relocation info
          relOffset = -1;
          break;
        } else if(relTableCache[relTableIndex] == 1) {
          // Skip forward
          relOffset += 254;
          ++relTableIndex;
          goto loadRelocationInfo;
        }

        relOffset += relTableCache[relTableIndex];
        ++relTableIndex;
      }
      relOffset -= block;
    }

    sendAt(prgPtr, buf, block);

    prgPtr += block;
    prgOffset += block;
  } while(block > 0);

  return E_OK;

relocationFailed:
  verbose("Reloc failed\n");
  Mfree(basepage);
  return EPLFMT;
}

bool GemDrive::scanDTA(GemDriveDTA &dta, uint32_t noFileErr) {
  GemPattern fileName;

  do {
    // Inject '.' and '..' in subfolders
    if((dta.attribMask & 0x10) && !dta.file.isInRoot()) {
      if(!dta.file) {
        dta.file.index = TinyFile::CURRENT;
        dta.d_attrib = 0x10;
        dta.d_time = 0;
        dta.d_date = 0;
        dta.d_length = 0;
        fileName.setCurDir();
        continue;
      }

      if(dta.file.index == TinyFile::CURRENT) {
        dta.file.index = TinyFile::PARENT;
        fileName.setParentDir();
        continue;
      }

      if(dta.file.index == TinyFile::PARENT) {
        dta.file.index = 0;
      }
    }

    // Scan normal files
scanFile:
    FsFile &file = dta.file.openNext(sd.fs);
    if(file) {
      if(!fileName.parseFileName(file))
        // Incompatible file name: skip
        goto scanFile;
      dta.d_attrib = file.isDir() ? 0x10 : file.attrib();
      uint16_t time;
      uint16_t date;
      file.getModifyDateTime(&date, &time);
      dta.d_time = ToWord(time);
      dta.d_date = ToWord(date);
      dta.d_length = ToLong((uint32_t)file.fileSize());
    } else {
      fileName.clear();
    }
  } while(fileName && (dta.pattern != fileName || !GemPattern::attribMatching(dta.attribMask, dta.d_attrib)));

  if(!fileName)
    return rte(noFileErr);

  fileName.toAtari(dta.d_fname);

  // Success: upload DTA and return from system call
  sendAt(dta, Fgetdta());
  dbg("-> ", dta.d_fname, ' ');
  return rte(E_OK);
}

char GemDrive::letter() const {
  return 'A' + id;
}

Word GemDrive::createFd(GemPath &parent, FsFile &file, oflag_t oflag) {
  for(int i = 0; i < filesMax; ++i) {
    if(!files[i]) {
      // Found a free FD
      files[i].set(parent, file, oflag, getBasePage());
      return ToWord(0x32 + Devices::acsiFirstId, i);
    }
  }

  return ToWord(0);
}

GemFile GemDrive::files[GemDrive::filesMax]; // File descriptors
uint8_t GemDrive::relTableCache[ACSI_GEMDRIVE_RELTABLE_CACHE_SIZE];
GemDrive * GemDrive::curDrive = nullptr; // Drive index. nullptr if unknown.
Long GemDrive::os_beg;
Word GemDrive::os_version;
Word GemDrive::os_conf;
Long GemDrive::p_run;

#endif

// vim: ts=2 sw=2 sts=2 et
