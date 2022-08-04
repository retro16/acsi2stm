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

// We are going to torture low-level data structures
// If the library changes too much, it's not guaranteed to work anymore.
#define private public
#include <SdFat.h>
#undef private

#include "TinyFs.h"

#if !ACSI_STRICT

bool TinyPath::operator==(const TinyPath &other) {
  for(int i = 0; i < maxDepth; ++i) {
    if(indexes[i] != other.indexes[i])
      return false;
    if(!indexes[i])
      return true;
  }
  return true;
}

void TinyPath::open(FsVolume &volume, FsFile *target, oflag_t oflag, FsFile *parent) {
  FsFile f[2];
  f[0].openRoot(&volume);
  f[1].openRoot(&volume);
  int i = 0;
  for(i = 0; i < maxDepth && f[i & 1] && indexes[i]; ++i) {
    FsFile &from = f[i & 1];
    FsFile &to = f[~i & 1];
    from.seekSet(((uint32_t)indexes[i] - 1) * 32);
    if(i == maxDepth - 1 || indexes[i + 1] == 0)
      to.openNext(&from, oflag);
    else
      // Directory must be opened in read-only mode
      to.openNext(&from, O_RDONLY);

    if(!to) {
      target->close();
      if(parent)
        parent->close();
      return;
    }
  }
  *target = f[i & 1];
  if(parent)
    *parent = f[~i & 1];
}

bool TinyPath::getAbsolute(FsVolume &volume, char *target, int bufSize) {
  FsFile f[2];
  f[0].openRoot(&volume);
  if(!f[0]) {
    // Can't even open root: return empty string
    *target = 0;
    return false;
  }
  *target = '\\';
  ++target;
  --bufSize;
  int i = 0;
  for(i = 0; i < maxDepth && f[i & 1] && indexes[i] && bufSize > 0; ++i) {
    FsFile &from = f[i & 1];
    FsFile &to = f[~i & 1];
    from.seekSet(((uint32_t)indexes[i] - 1) * 32);
    to.openNext(&from, O_RDONLY);
    if(to) {
      char unicodeName[256];
      to.getName(unicodeName, 256);
      parseUnicodeName(unicodeName);
      int written = nameToAtari(target, bufSize);
      bufSize -= written;
      target += bufSize;
      if(to.isDir() && bufSize) {
        *target = '\\';
        ++target;
        --bufSize;
      }
    }
  }

  // Terminate the string
  if(bufSize > 0)
    *target = 0;
  else
    target[-1] = 0;

  return bufSize > 0;
}

void TinyPath::setParent() {
  if(!indexes[0])
    // Already at root level
    return;

  int i;
  for(i = 1; i < maxDepth && indexes[i]; ++i);
  indexes[i - 1] = 0;
}

int TinyPath::set(FsVolume &volume, const char *path, int create, uint8_t attr) {
  char unicodeName[52];

  // Remove drive letter if any
  if(path[0] && path[1] == ':')
    path += 2;

  int i; // Index in the indexes table;

  if(path[0] == '\\') {
    // Absolute path: reset to root directory
    clear();
    i = 0;
    ++path;
  } else {
    // Point at the end of the current directory
    for(i = 0; i < maxDepth && indexes[i]; ++i);
  }

  // 2 files to alternate between the two
  FsFile f[2];

  // Start with the current path
  open(volume, &f[i & 1], O_RDONLY);

  if(!f[i & 1]) {
    clear();
    return 2;
  }

  verbose("Parse path '", path, "'\n");

  // Parse path and append to the index list
  bool lastPath = !path[0];
  while(i < maxDepth - 1 && path[0] && f[i & 1]) {
    FsFile &parent = f[i & 1];
    FsFile &child = f[~i & 1];

    path = parseAtariPattern(path);
    lastPath = !path[0];

    if(pattern[0] == '.') {
      if(pattern[1] == '.') {
        // "..": Parent directory
        if(i > 0) {
          --i;
          indexes[i] = 0;
          // Need to compute the whole path again to get the parent
          open(volume, &child, O_RDONLY);
          if(!child) {
            clear();
            return 2;
          }
        }
      }
      continue;
    }

    // Try to find a matching file

    parent.rewind();
    child.openNext(&parent, O_RDONLY);
    while(child) {
      child.getName(unicodeName, 52);
      parseUnicodeName(unicodeName);
      if(matches(pattern)) {
        if(child.isDirectory() || lastPath)
          break;
      }
      child.openNext(&parent, O_RDONLY);
    }

    if(!lastPath && (!child || !child.isDirectory())) {
      clear();
      return 2;
    }

#if ACSI_VERBOSE
    verbose(pattern, "->" , name);
    if(child) {
      child.getName(unicodeName, 52);
      verbose(" = ", unicodeName);
    } else if(create) {
      verbose(" create=", create);
    }
    verbose('\n');
#endif

    if(!child && create) {
      // Check that the name is not a pattern
      for(int i = 0; i < 11; ++i)
        if(pattern[i] == '?') {
          // Error: trying to create a file with a wildcard in its name !
          clear();
          return 3;
        }

      // Convert file name to unicode
      char unicodeName[52];
      patternToUnicode(unicodeName, 52);

      if(create == 1) {
        verbose("Create file ", unicodeName, '\n');
        if(!child.open(&parent, unicodeName, O_RDWR | O_CREAT)) {
          clear();
          return 1;
        }
        child.attrib(attr & FS_ATTRIB_USER_SETTABLE);
      } else if(create == 2) {
        // Create a directory
        verbose("Create dir ", unicodeName, '\n');
        if(!child.mkdir(&parent, unicodeName)) {
          clear();
          return 1;
        }
        if(!child.open(&parent, unicodeName)) {
          clear();
          return 1;
        }
        if(!child.isDirectory()) {
          clear();
          return 1;
        }
      }
    }

    if(!child) {
      verbose(lastPath ? " not found\n" : " no parent\n");
      // Something went wrong, return an error.
      clear();
      return lastPath ? 1 : 2;
    }

    indexes[i] = child.dirIndex() + 1;
    ++i;
  }

  if(!lastPath) {
    // Path too long
    clear();
    return 3;
  }

  verbose(" all good\n");

  // Terminate the path
  indexes[i] = 0;
  return 0;
}

int TinyPath::getNextUnicode(const char *source, char *target) {
  // Forbidden characters
  if(*source && (*source <= ' ' || strchr("*,.:?\\", *source))) {
    *target = '_';
    return 1;
  }

  // Simple 1 byte case
  if(*source < 128) {
    if(*source >= 'a' && *source <= 'z')
      // Convert to upper case
      *target = *source - 'a' + 'A';
    else
      *target = *source;
    return 1;
  }

  // XXX TODO: parse extended unicode and convert it to Atari
  *target = '_';

  // Compute the character length
  int l;
  for(int l = 1; (source[l] & 0b11000000) == 0b1000000; ++l);
  return l;
}

int TinyPath::appendUnicode(char atariChar, char *target, int bufSize) {
  if(bufSize) {
    if(atariChar < 128) {
      *target = atariChar;
      return 1;
    } else {
      // XXX TODO
      *target = '_';
      return 1;
    }
  }
  return 0;
}

int TinyPath::patternToUnicode(char *target, int bufSize) {
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

int TinyPath::nameToAtari(char *target, int bufSize) {
  int chars = 0;

  // Expand name
  for(int i = 0; i < 8 && chars < bufSize && name[i] != ' '; ++i) {
    target[chars] = name[i];
    ++chars;
  }

  // Append extension dot if needed
  if(name[8] != ' ' && chars < bufSize) {
    target[chars] = '.';
    ++chars;
  }

  // Expand extension
  for(int i = 8; i < 11 && chars < bufSize && name[i] != ' '; ++i) {
    target[chars] = name[i];
    ++chars;
  }

  target[chars] = 0;
  return chars;
}

int TinyPath::nameToAtari(FsFile *file, char *target, int bufSize) {
  char unicodeName[256];
  file->getName(unicodeName, 256);
  parseUnicodeName(unicodeName);
  return nameToAtari(target, bufSize);
}

bool TinyPath::matches(const char pattern[11]) {
  for(int i = 0; i < 11; ++i) {
    if(pattern[i] != '?' && pattern[i] != name[i])
      return false;
  }

  return true;
}

const char * TinyPath::parseAtariPattern(const char *path) {
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
    }
  }

  // Fill the extension with spaces
  for(; j < 11; ++j)
    pattern[j] = ' ';

  if(path[i] == '\\')
    ++i;

  return &path[i];
}

const char * TinyPath::parseUnicodeName(const char *path) {
  int i = 0; // Index in the source string
  int j = 0; // Index in name

  int nameEnd;
  int ext;

  // Find the end of the current name
  for(nameEnd = 0; path[nameEnd] && path[nameEnd] != '/'; ++nameEnd);

  // Find the extension
  for(ext = nameEnd - 1; ext > 0 && path[ext] != '.'; --ext);

  if(path[ext] != '.')
    // No extension, put the extension pointer just before the end
    ext = nameEnd;

  // Parse name
  for(i = 0, j = 0; i < ext && j < 8; ++j) {
    if(path[i] == '*') {
      // Fill with '?' until the end
      for(; j < 8; ++j)
        name[j] = '?';
      ++i;
      break;
    }
    i += getNextUnicode(&path[i], &name[j]);
  }

  // Fill the name with spaces
  for(; j < 8; ++j)
    name[j] = ' ';

  // Parse extension
  if(path[ext] == '.') {
    for(i = ext + 1; i < nameEnd && j < 11; ++j) {
      if(path[i] == '*') {
        // Fill with '?' until the end
        for(; j < 11; ++j)
          name[j] = '?';
        ++i;
        break;
      }
      i += getNextUnicode(&path[i], &name[j]);
    }
  }

  // Fill the extension with spaces
  for(; j < 11; ++j)
    name[j] = ' ';

  if(path[nameEnd] == '/')
    ++nameEnd;

  return &path[nameEnd];
}

char TinyPath::name[11];
char TinyPath::pattern[11];

FsFile * TinyFile::open(FsVolume &volume, TinyPath & path, oflag_t oflag) {
  close();

  path.open(volume, &g.f, oflag, &g.dir);

  if(g.f) {
    index = g.f.dirIndex() + 1;
    if(g.dir.isSubDir())
      dirCluster = getCluster(g.dir);
    else
      dirCluster = 0;
    g.dir.seekSet(((uint32_t)index - 1) * 32);
  } else {
    index = 0;
  }

  return &g.f;
}

FsFile * TinyFile::acquire(FsVolume &volume, oflag_t oflag) {
  if(index
     && g.lastAcquiredCluster == dirCluster
     && g.lastAcquiredIndex == index
     && g.f
     && g.dir
     && ((oflag & O_RDWR) ? g.f.isWritable() : true)
  ) {
    // Optimized !
    return &g.f;
  }

  g.f.close();

  if(!index) {
    // File closed
    g.lastAcquiredIndex = 0;
    return &g.f;
  }

  // Open the parent directory in g.dir
  if(!dirCluster) {
    // File is in the root directory
    g.dir.openRoot(&volume);
  } else {
    // Find any directory to inject data into the structure (evil grin)
    g.f.openRoot(&volume);
    while(g.dir.openNext(&g.f, O_RDONLY) && !g.dir.isDirectory());
    if(g.dir) {
      // Found a directory handle to inject the cluster in it
      setCluster(g.dir, dirCluster);
    } else {
      // Should never happen
      close();
    }
  }

  // Find the file with the correct index
  g.f.open(&g.dir, index - 1, oflag);

  if(g.f) {
    g.lastAcquiredCluster = dirCluster;
    g.lastAcquiredIndex = index;
  } else {
    g.lastAcquiredIndex = 0;
  }

  return &g.f;
}

void TinyFile::close() {
  g.f.close();
  index = 0;
  g.lastAcquiredIndex = 0;
}

FsFile * TinyFile::openNext(FsVolume &volume, oflag_t oflag, const char pattern[11]) {
  int curIndex = index;

  acquire(volume, O_RDONLY);

  if(g.dir) {
    if(!g.f) {
      // The file might have been deleted. Search from the beginning.
      g.dir.rewind();
      do {
        findNextMatching(pattern, oflag);
      } while(g.f && g.f.dirIndex() + 1 <= curIndex);
    } else {
      findNextMatching(pattern, oflag);
    }

    // Update the index
    if(g.f)
      index = g.f.dirIndex() + 1;
    else
      close();
  } else {
    close();
  }

  return &g.f;
}

void TinyFile::findNextMatching(const char pattern[11], oflag_t oflag) {
  g.f.openNext(&g.dir, oflag);
  while(g.f) {
    char name[256];
    g.f.getName(name, 256);
    TinyPath::parseUnicodeName(name);
    if(TinyPath::matches(pattern))
      break;
    g.f.openNext(&g.dir, oflag);
  }
}

uint32_t TinyFile::getCluster(FsFile &f) {
  uint32_t cluster;
  uint64_t position = f.curPosition();
  f.rewind();
  if(f.m_fFile)
    cluster = f.m_fFile->m_firstCluster;
  else
    cluster = f.m_xFile->m_firstCluster;
  f.seekSet(position);
  return cluster;
}

void TinyFile::setCluster(FsFile &f, uint32_t cluster) {
  f.rewind();
  if(f.m_fFile)
    f.m_fFile->m_firstCluster = cluster;
  else
    f.m_xFile->m_firstCluster = cluster;
}

// Global variables for TinyFile
TinyFile::Global TinyFile::g;

int TinyFD::read(FsVolume &volume, uint8_t *data, int bytes) {
  FsFile *f = acquire(volume);
  if(!f)
    return -1;
  if(!f->seekSet(position))
    return -1;

  int r = f->read(data, bytes);
  if(r > 0)
    position += r;

  return r;
}

int TinyFD::write(FsVolume &volume, uint8_t *data, int bytes) {
  FsFile *f = acquire(volume, O_RDWR);
  if(!f)
    return -1;
  if(!f->seekSet(position))
    return -1;

  int r = f->write(data, bytes);
  if(r > 0)
    position += r;

  return r;
}

int32_t TinyFD::seek(FsVolume &volume, int32_t offset, int whence) {
  FsFile *f = acquire(volume, O_RDWR);
  if(!f)
    return -1;

  switch(whence) {
    case 0:
      if(!f->seekSet(offset))
        return -1;
      position = offset;
      break;
    case 1:
      if(!f->seekSet(f->fileSize() + offset))
        return -1;
      position = f->fileSize() + offset;
      break;
    case 2:
      if(!f->seekSet(position + offset))
        return -1;
      position = position + offset;
      break;
    default:
      return -1;
  }

  return position;
}

#endif
