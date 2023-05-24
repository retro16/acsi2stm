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

#include "TinyFile.h"

uint32_t TinyFile::lastMediaId = 0;
TinyFile TinyFile::lastTinyFile;
FsFile TinyFile::lastFile;
FsFile TinyFile::lastParent;

TinyFile::TinyFile() : index(0) {
}

TinyFile::TinyFile(FsFile &file): index(file.dirIndex()), dirCluster(getCluster(file)) {}

void TinyFile::set(FsFile &parent, FsFile &file) {
  index = file.dirIndex() + 1;
  dirCluster = getCluster(parent);
};

void TinyFile::set(FsFile &parent) {
  index = 0;
  dirCluster = getCluster(parent);
};

//TMPJM
#include "Monitor.h"
FsFile & TinyFile::open(FsVolume &volume, oflag_t oflag, uint32_t mediaId) const {
  // Easy case
  if(!index) {
    lastParent.close();
    lastFile.close();
    lastTinyFile.index = 0;
    return lastFile;
  }

/* TMPJM FIXME
  // Check cache
  if(mediaId
      && lastTinyFile
      && lastTinyFile == *this
      && lastFile
      && (mediaId == lastMediaId || !lastMediaId)
      && lastParent
      && (oflag & O_RDWR) ?
        // Read-write check
        lastFile.isWritable() :
        // Read-only check
        (lastFile.isDir() || !lastFile.isWritable())
      ) {
    // Optimized !
Monitor::dbg("TMPJM optim\n");
    lastMediaId = mediaId;
    return lastFile;
  }
*/

  // Open the parent directory
  openParent(volume);

  // Find the file with the correct index
  if(!lastParent) {
    lastTinyFile.index = 0;
    return lastFile;
  }

  lastFile.open(&lastParent, index - 1, oflag);

  // Update cache
  lastMediaId = mediaId;
  lastTinyFile = *this;

  return lastFile;
}

FsFile & TinyFile::openNext(FsVolume &volume, oflag_t oflag) {
  openParent(volume);

  if(!lastParent)
    return lastFile;

  if(index) {
    lastFile.open(&lastParent, index - 1);
    if(lastFile) {
      lastFile.openNext(&lastParent);
    } else {
      // File deleted, or something like that: restart
      lastParent.rewind();
      for(;;) {
        lastFile.openNext(&lastParent);
        if(!lastFile || (int)(lastFile.dirIndex()) >= (int)(index - 1))
          break;
      }
    }
  } else {
    lastParent.rewind();
    lastFile.openNext(&lastParent);
  }

  if(lastFile) {
    index = lastFile.dirIndex() + 1;
    if(oflag != O_RDONLY) {
      lastFile.close();
      lastFile.open(&lastParent, (index - 1), oflag);
    }
  } else {
    index = 0;
  }

  return lastFile;
}

FsFile & TinyFile::openParent(FsVolume &volume) const {
  lastTinyFile.index = 0; // Clear cache

  if(!dirCluster) {
    // File is in the root directory
    lastParent.openRoot(&volume);
  } else {
    // Find any directory to inject data into the structure (evil grin)
    lastFile.openRoot(&volume);
    while(lastParent.openNext(&lastFile, O_RDONLY) && !lastParent.isDir());
    if(lastParent)
      // Found a directory handle to inject the cluster in it
      setCluster(lastParent, dirCluster);
  }

  lastFile.close();

  return lastParent;
}

void TinyFile::close() {
  index = 0;
  if(lastTinyFile == *this) {
    lastFile.close();
    lastParent.close();
  }
}

uint32_t TinyFile::getCluster(FsFile &file) {
  if(!file.isSubDir() && file.isDir())
    // Root directory
    return 0;

  uint32_t cluster;
  uint64_t position = file.curPosition();
  file.rewind();
  if(file.m_fFile)
    cluster = file.m_fFile->m_firstCluster;
  else
    cluster = file.m_xFile->m_firstCluster;
  file.seekSet(position);
  return cluster;
}

void TinyFile::setCluster(FsFile &file, uint32_t cluster) {
  file.rewind();
  if(file.m_fFile)
    file.m_fFile->m_firstCluster = cluster;
  else
    file.m_xFile->m_firstCluster = cluster;
}

void TinyFile::clearCache() {
  lastFile.close();
  lastTinyFile.index = 0;
}
