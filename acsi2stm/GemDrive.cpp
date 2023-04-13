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

#include <cstddef>
#include "acsi2stm.h"
#include "SysHook.h"
#include "Tos.h"
#include "TinyFs.h"
#include "GemDrive.h"
#include "DmaPort.h"
#include "Devices.h"
#include "BlockDev.h"

const
#include "syshook.boot.h"

struct GemFile: public TinyFD {
  uint32_t mediaId;
  Long basePage;
  int drive;
};

struct Drive {
  // Mounted drive structure
  bool mch; // Media change flag
  Word id; // Drive id on the ST
  TinyPath curPath; // Current path

  char letter() const; // Return the drive letter
};

struct TOS_PACKED PrivDTA {
  Word index; // Use big endian index so that the 1st byte of the DTA has a
              // high probability of being 0: TOS skips any DTA starting with
              // a nul byte so it will avoid crashes if heuristics fail.
  uint32_t dirCluster;
  uint32_t mediaId; // Serves as ownership marker as mediaId is supposed to be quasi-unique
  char pattern[11]; // If any invalid character is detected (<0x20), skip DTA

  const PrivDTA & operator<<(const TinyFile &tf) {
    index = ToWord(tf.index);
    dirCluster = tf.dirCluster;
    return *this;
  }

  operator TinyFile() const {
    TinyFile tf;
    tf.index = index;
    tf.dirCluster = dirCluster;
    return tf;
  }

  // Store a history of valid media IDs.
  // Of course this can't work 100%, but swapping many SD cards during
  // the lifespan of a DTA is very unlikely.
  static const int mediaIdHistoryLen = 10;
  static uint32_t validMediaIds[mediaIdHistoryLen];
  static bool isMediaIdValid(uint32_t id);
  static void insertMediaId(uint32_t id);
  bool isValid() const;
  int drive() const;
};

// Store mediaIds of the last emitted DTAs
// Helps working around SD card hotswapping
uint32_t PrivDTA::validMediaIds[PrivDTA::mediaIdHistoryLen];

bool PrivDTA::isMediaIdValid(uint32_t id) {
  for(int i = 0; i < mediaIdHistoryLen; ++i)
    if(validMediaIds[i] == id)
      return true;
  return false;
}

void PrivDTA::insertMediaId(uint32_t id) {
  if(isMediaIdValid(id))
    return;

  // Insert at the top of the list
  for(int i = mediaIdHistoryLen - 1; i > 1; --i)
    validMediaIds[i] = validMediaIds[i - 1];
  validMediaIds[0] = id;
}

bool PrivDTA::isValid() const {
  // TOS DTAs start with a file name: if the first byte is ASCII, it's a TOS
  // DTA. OTOH, having more than 0x2000 files in a single directory is unlikely
  if(index.bytes[0] >= 0x20)
    return false;

  // This must match a known SD card mediaId.
  if(!isMediaIdValid(mediaId))
    return false;

  for(unsigned int i = 0; i < sizeof(pattern); ++i)
    if(pattern[i] < 0x20)
      return false;

  return true;
}

static const int driveCount = Devices::sdCount;
Drive drives[driveCount];
static const int filesMax = ACSI_GEMDRIVE_MAX_FILES;
GemFile files[filesMax]; // File descriptors
uint8_t relTableCache[ACSI_GEMDRIVE_RELTABLE_CACHE_SIZE];
Word curDriveId;
Long curDta;
int curDrive; // Drive index. -1 if unknown.

// Cache of stable OSHEADER values
Long os_beg;
Word os_version;
Word os_conf;
Long p_run;

GemFile * GemDrive::createFd(uint32_t &stfd, int driveIndex, Long basePage) {
  for(int i = 0; i < filesMax; ++i) {
    if(!files[i]) {
      // Found a free FD
      files[i].mediaId = Devices::sdSlots[driveIndex].mediaId();
      if(!files[i].mediaId) {
        files[i].close();
        return nullptr;
      }
      files[i].drive = driveIndex;
      files[i].basePage = basePage;
      stfd = uint32_t(0x32 + Devices::acsiFirstId) << 8 | i;
      return &files[i];
    }
  }
  return nullptr;
}

void GemDrive::setDta(FsFile *file, const PrivDTA &priv, DTA &dta) {
  memcpy(dta.d_reserved, &priv, sizeof(priv));
  uint16_t date;
  uint16_t time;
  file->getModifyDateTime(&date, &time);
  if(file->isDirectory())
    dta.d_attrib = FS_ATTRIB_DIRECTORY;
  else
    dta.d_attrib = file->attrib() & (FS_ATTRIB_READ_ONLY);
  dta.d_date = date;
  dta.d_time = time;
  dta.d_length = file->isDirectory() ? 0 : file->fileSize();
  TinyPath::nameToAtari(dta.d_fname, sizeof(dta.d_fname));
}

char Drive::letter() const {
  return 'A' + id;
}

void GemDrive::process(uint8_t cmd) {
  switch(cmd) {
    case 0x08:
      {
        // Read command: inject syshook driver into a boot sector

        // Read subsequent command bytes
        for(int b = 0; b < 5; ++b)
          buf[b] = DmaPort::readIrq();

        if(buf[0] != 0x00 || buf[1] != 0x00 || buf[2] != 0x00 || buf[3] != 0x01 || buf[4] != 0x00) {
          // Not a boot query: send the 'no operation' SCSI status
          dbg("reject non-boot query\n");
          DmaPort::sendIrq(0x08);
        }

        // Build a boot sector
        memcpy(buf, syshook_boot_bin, syshook_boot_bin_len);

        // Patch ACSI id
        buf[3] = SdDev::gemBootDrive << 5;

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

        // Wait for the command byte telling that the ST is ready
        DmaPort::waitCommand();
        // The ST is now waiting for commands

        // Process initialization
        onBoot();
      }
      break;

    case 0x0e:
      // GEMDOS system call hook
      dbg("GEMDOS ");
      onGemdos();
      break;

    case 0x0f:
      // BIOS system call hook
      dbg("BIOS ");
      onBios();
      break;

    case 0x10:
      // XBIOS system call hook
      dbg("XBIOS ");
      onXbios();
      break;

    case 0x11:
      // ACSI2STM extensions hook
      dbg("EXT ");
      onExtCmd();
      break;

    default:
      // For unknown commands, play dead to avoid confusing other drivers
      dbg("Unknown command\n");
      break;
  }
}

bool GemDrive::onPterm0(const Tos::Pterm0_p &) {
  closeProcessFiles();
  return false;
}

bool GemDrive::onDsetdrv(const Tos::Dsetdrv_p &p) {
  // Track current drive

  setCurDrive(p.drv);

  if(!checkMedium(curDrive)) {
    rte(EDRIVE);
    return true;
  }

  return false;
}

bool GemDrive::onTsetdate(const Tos::Tsetdate_p &p) {
  // TODO
  (void)p;
  return false;
}

bool GemDrive::onTsettime(const Tos::Tsettime_p &p) {
  // TODO
  (void)p;
  return false;
}

bool GemDrive::onDfree(const Tos::Dfree_p &p) {
  // TODO
  (void)p;
  return false;
}

bool GemDrive::onDcreate(const Tos::Dcreate_p &p) {
  int driveIndex;
  TinyPath path;
  if(openPath(2, p.path, 0, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false; 

  rte(E_OK);
  return true;
}

bool GemDrive::onDdelete(const Tos::Ddelete_p &p) {
  int driveIndex;
  TinyPath path;
  if(openPath(2, p.path, 0, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false; 

  Drive &drive = drives[driveIndex];
  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  if(path == drive.curPath) {
    rte(ECWD);
    return true;
  }

  if(!sd.isWritable()) {
    rte(EACCDN);
    return true;
  }

  FsFile file;
  path.open(volume, &file);
  if(!file.rmdir()) {
    rte(EACCDN);
    return true;
  }

  rte(E_OK);
  return true;
}

bool GemDrive::onDsetpath(const Tos::Dsetpath_p &p) {
  if(curDrive < 0)
    // Current drive is not mounted
    return false;

  if(!checkMedium(curDrive)) {
    rte(EDRIVE);
    return true;
  }

  readStringAt((char *)buf, p.path, sizeof(buf));
  dbg("path=", (const char *)buf, ' ');
  int result = drives[curDrive].curPath.set(Devices::sdSlots[curDrive].fs, (const char *)buf);
  rte(result == 0 ? E_OK : EPTHNF);
  return true;
}

bool GemDrive::onFcreate(const Tos::Fcreate_p &p) {
  return onFcreateopen(1, p.fname, O_RDWR | O_CREAT, p.attr.bytes[1]);
}

bool GemDrive::onFopen(const Tos::Fopen_p &p) {
  return onFcreateopen(0, p.fname, (p.mode.bytes[1] & 0x03) ? O_RDWR : O_RDONLY, 0);
}

bool GemDrive::onFclose(const Tos::Fclose_p &p) {
  GemFile *file = getFile(p.handle);
  if(!file)
    return false;

  file->close();
  rte(E_OK);
  return true;
}

bool GemDrive::onFread(const Tos::Fread_p &p) {
  GemFile *fd = getFile(p.handle);
  if(!fd)
    return false;

  if(!checkMedium(fd->drive)) {
    rte(EMEDIA);
    return true;
  }

  auto &sd = Devices::sdSlots[fd->drive];
  FsVolume &volume = sd.fs;

  if(sd.mediaId() != fd->mediaId) {
    rte(E_CHNG);
    return true;
  }

  int size = p.count;
  int done = 0;
  int bufSize;
  uint32_t ptr = p.buf;

  while(size > 0) {
    if(size > (int)sizeof(buf))
      bufSize = sizeof(buf);
    else
      bufSize = size;

    // Read data from SD
    int readBytes = fd->read(volume, buf, bufSize);

    if(readBytes > 0) {
      // Send data to Atari
      sendAt(ptr, buf, readBytes);
      done += readBytes;
      ptr += readBytes;
      size -= readBytes;
    } else if(readBytes < 0) {
      // Return error
      rte(EREADF);
      return true;
    } else {
      break;
    }
  }

  if(done < 0)
    rte(EREADF);
  else
    rte(ToLong(done));

  return true;
}

bool GemDrive::onFwrite(const Tos::Fwrite_p &p) {
  GemFile *fd = getFile(p.handle);
  if(!fd)
    return false;

  if(!checkMedium(fd->drive)) {
    rte(EMEDIA);
    return true;
  }

  auto &sd = Devices::sdSlots[fd->drive];
  FsVolume &volume = sd.fs;

  if(sd.mediaId() != fd->mediaId) {
    rte(E_CHNG);
    return true;
  }

  if(!sd.isWritable()) {
    rte(EACCDN);
    return true;
  }

  uint32_t ptr = p.buf;
  int size = p.count;
  int done = 0;
  int bufSize;

  while(size > 0) {
    if(size > (int)sizeof(buf))
      bufSize = sizeof(buf);
    else
      bufSize = size;

    // Read data from Atari
    readAt(buf, ptr, bufSize);

    // Write data onto SD
    int writtenBytes = fd->write(volume, buf, bufSize);

    if(writtenBytes > 0) {
      done += writtenBytes;
      ptr += writtenBytes;
      size -= writtenBytes;
    } else if(writtenBytes < 0) {
      rte(EWRITF);
      return true;
    } else {
      break;
    }
  }

  // Return read bytes
  rte(ToLong(done));
  return true;
}

bool GemDrive::onFdelete(const Tos::Fdelete_p &p) {
  int driveIndex;
  TinyPath path;
  if(openPath(0, p.fname, 0, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false; 

  FsVolume &volume = Devices::sdSlots[driveIndex].fs;
  if(!Devices::sdSlots[driveIndex].isWritable()) {
    rte(EACCDN);
    return true;
  }

  // Check that the file isn't already opened
  TinyFile tf;
  tf.open(volume, path);
  for(int i = 0; i < filesMax; ++i) {
    if(files[i] && files[i] == tf) {
      verbose("File opened\n");
      rte(EACCDN);
      return true;
    }
  }

  FsFile file;
  path.open(volume, &file, O_RDWR);

  if(!file) {
    rte(EFILNF);
    return true;
  }

  if(!file.remove()) {
    rte(ERROR);
    return true;
  }

  rte(E_OK);
  return true;
}

bool GemDrive::onFseek(const Tos::Fseek_p &p) {
  GemFile *fd = getFile(p.handle);
  if(!fd)
    return false;

  if(!checkMedium(fd->drive)) {
    rte(EMEDIA);
    return true;
  }

  auto &sd = Devices::sdSlots[fd->drive];
  FsVolume &volume = sd.fs;

  if(sd.mediaId() != fd->mediaId) {
    rte(E_CHNG);
    return true;
  }

  FsFile *file = fd->acquire(volume);
  if(!file) {
    fd->close();
    rte(EIHNDL);
    return true;
  }

  auto pos = fd->seek(volume, p.offset, p.seekmode.bytes[1]);
  if(pos < 0) {
    rte(ERROR);
    return true;
  }

  rte(ToLong(pos));
  return true;
}

bool GemDrive::onFattrib(const Tos::Fattrib_p &p) {
  int driveIndex;
  TinyPath path;
  if(openPath(0, p.fname, 0, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false; 

  FsVolume &volume = Devices::sdSlots[driveIndex].fs;
  FsFile file;
  path.open(volume, &file);

  if(!file) {
    rte(ERROR);
    return true;
  }

  if(p.wflag.bytes[1]) {
    if(!Devices::sdSlots[driveIndex].isWritable()) {
      rte(EACCDN);
      return true;
    }
    if(!file.attrib(p.attrib.bytes[1])) {
      rte(EWRITF);
      return true;
    }
  }

  rte(file.attrib());
  return true;
}

bool GemDrive::onDgetpath(const Tos::Dgetpath_p &p) {
  int driveIndex = getDrive(p.driveno);
  if(driveIndex < 0)
    return false; // Unknown device: forward

  if(!checkMedium(driveIndex)) {
    rte(EDRIVE);
    return true;
  }

  Drive &drive = drives[driveIndex];
  FsVolume &volume = Devices::sdSlots[driveIndex].fs;
  if(!drive.curPath.getAbsolute(volume, (char *)buf, sizeof(buf))) {
    rte(EDRIVE);
    return true;
  }

  sendAt(p.path, buf, strlen((const char *)buf) + 1);

  rte(E_OK);
  return true;
}

bool GemDrive::onPexec(const Tos::Pexec_p &p) {
  if(p.mode != 0 && p.mode != 3)
    return false;

  // Interpret parameters as Pexec0 / Pexec3 (same structure)
  Pexec_0_p &p0 = *(Pexec_0_p *)&p;

  int driveIndex;
  TinyPath path;
  if(openPath(0, p0.name, 0, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false; 

  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  FsFile prgFile;
  path.open(volume, &prgFile);

  // Read program header
  PH ph;
  if(prgFile.read(&ph, sizeof(ph)) != sizeof(ph)) {
    rte(EPLFMT);
    return true;
  }

  // Check program format and file size
  if(ph.ph_branch != ToWord(0x60, 0x1a)
     || ph.ph_tlen.bytes[0]
     || ph.ph_dlen.bytes[0]
     || ph.ph_slen.bytes[0]) {
    rte(EPLFMT);
    return true;
  }

  if(prgFile.fileSize() < sizeof(ph) + ph.ph_tlen + ph.ph_dlen + ph.ph_slen + (ph.ph_absflag ? 0 : 4)) {
    rte(EPLFMT);
    return true;
  }

  // Check free memory
  if(Malloc(ToLong(0xff, 0xff, 0xff, 0xff)) < sizeof(PD) + ph.ph_tlen + ph.ph_dlen + ph.ph_blen) {
    rte(ENSMEM);
    return true;
  }

  // Create base page
  uint32_t basepage;
  if(os_version < 0x200) {
    basepage = Pexec_5(p0.cmdline, p0.env);
  } else {
    basepage = Pexec_7(ph.ph_prgflags, p0.cmdline, p0.env);
  }

  if(!isDma(basepage)) {
    dbg("Can't load in non-DMA memory\n");
    Mfree(basepage);
    rte(EIMBA);
    return true;
  }

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

  if(!(ph.ph_prgflags.bytes[3] & 1))
    // FASTLOAD not set: clear BSS
    clearAt(ph.ph_blen, pd.p_bbase);

  /* The relocation table itself starts with a 32-bit value which marks the
   * offset of the first value to be relocated relative to the start of the
   * TEXT segment.
   * Single bytes are then used for all following offsets. To be able to handle
   * offsets greater than 255 correctly, one proceeds as follows:
   * If a 1 is found as an offset then the value 254 is added automatically to
   * the offset.
   * For very large offsets this procedure can of course be repeated.
   * Incidentally, an empty relocation table is flagged with a LONG value of 0.
   */

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
    verbose("Program has relocations\n");
  else
    verbose("Program has no relocation\n");

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
        value += prgStart;
        value.set(&buf[relOffset]);

        verboseHex("Patching at offset ", relOffset + prgOffset, '\n');

        // Load more relocation info if needed
loadRelocationInfo:
        if(relTableIndex == relTableSize) {
          // Need to load more relocation info
          relTableSize = relFile.read(relTableCache, sizeof(relTableCache));
          if(relTableSize < 0)
            goto relocationFailed;
          if(!relTableSize) {
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

  // Finished: run the program or RTE depending on the mode
  if(p.mode == 3)
    rte(basepage);
  else if(os_version < 0x104)
    pexec4ThenRte(basepage);
  else
    pexec6ThenRte(basepage);

  return true;

relocationFailed:
  verbose("Relocation error\n");
  Mfree(basepage);
  rte(EPLFMT);
  return true;
}

bool GemDrive::onPterm(const Tos::Pterm_p &) {
  closeProcessFiles();
  return false;
}

bool GemDrive::onFsfirst(const Tos::Fsfirst_p &p) {
  // TODO: handle volume label
  DTA dta;

  // Read parameters
  const char *filename;
  if(!p.filename)
    return false;
  readStringAt((char *)Devices::buf, p.filename, sizeof(Devices::buf));
  dbg("pattern='", (char *)Devices::buf, "' ");

  // Get drive from filename
  int driveIndex = getDrive((const char *)Devices::buf, &filename);
  if(driveIndex < 0)
    return false; // Unknown device: forward

  if(!checkMedium(driveIndex)) {
    rte(EDRIVE);
    return true;
  }

  Drive &drive = drives[driveIndex];
  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  TinyPath path = drive.curPath;
  int pathSet = path.set(volume, filename);

  switch(pathSet) {
    case 0:
      break;
    case 1:
      rte(ENMFIL);
      return true;
    case 2:
    case 3:
      rte(EPTHNF);
      return true;
  }

  PrivDTA priv;
  memcpy(&priv, dta.d_reserved, sizeof(priv));
  priv.mediaId = sd.mediaId();
  priv.insertMediaId(priv.mediaId);
  TinyFile tf;
  FsFile *file = tf.open(volume, path);
  if(!file) {
    rte(EFILNF);
    return true;
  }

  // Update DTA
  memcpy(priv.pattern, path.lastPattern(), sizeof(priv.pattern));
  priv << tf;
  setDta(file, priv, dta);

  // Success: upload DTA and return from system call
  sendAt(dta, Fgetdta());
  dbg("->", dta.d_fname, ' ');
  rte(E_OK);
  return true;
}

bool GemDrive::onFsnext(const Tos::Fsnext_p &) {
  DTA dta;
  readAt(dta, Fgetdta());

  PrivDTA priv;
  memcpy(&priv, dta.d_reserved, sizeof(priv));
  if(!priv.isValid())
    // This DTA wasn't emitted by GemDrive
    return false;

  int driveIndex = findDriveByMediaId(priv.mediaId);
  if(driveIndex < 0) {
    // This DTA matches an old SD card that was ejected/swapped
    rte(ENMFIL);
    return true;
  }

  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  TinyFile tf(priv);
  FsFile *file = tf.openNext(volume, O_RDONLY, priv.pattern);

  if(!file || !*file) {
    rte(ENMFIL);
    return true;
  }

  priv << tf;
  setDta(file, priv, dta);

  // Success: upload updated DTA and return from system call
  sendAt(dta, Fgetdta());
  dbg("->", dta.d_fname, ' ');
  rte(E_OK);
  return true;
}

bool GemDrive::onFrename(const Tos::Frename_p &p) {
  int driveIndex;
  TinyPath path;
  if(openPath(0, p.oldname, 0x1f, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false;
  return false;

  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  readStringAt((char *)buf, p.newname, sizeof(buf));
  dbg("to='", (char *)buf, "'\n");

  const char *filename;
  if(getDrive((char *)buf, &filename) != driveIndex) {
    rte(ENSAME);
    return true;
  }
  
  char *lastsep = (char *)filename;
  for(char *c = (char *)filename; *c; ++c)
    if(*c == '\\')
      lastsep = c;

  TinyPath newPath = path;
  if(lastsep > filename) {
    // Move
    *lastsep = 0;
    if(newPath.set(volume, filename)) {
      rte(EPTHNF);
      return true;
    }
    filename = lastsep + 1;
  } else {
    // Just rename: the new path is current file's parent
    newPath.setParent();
  }

  FsFile source;
  FsFile targetDir;

  // Convert Atari file name to unicode
  TinyPath::parseAtariPattern(filename);
  TinyPath::patternToUnicode((char *)buf, sizeof(buf));

  if(!source.rename(&targetDir, (const char *)buf)) {
    rte(EACCDN);
    return true;
  }

  rte(E_OK);
  return true;
}

bool GemDrive::onFdatime(const Tos::Fdatime_p &p) {
  // TODO
  (void)p;
  return false;
}

void GemDrive::onBoot() {
  dbg("GemDrive boot\n");

  // Update phystop for this machine
  verbose("Read phystop\n");
  SysHook::phystop = phystop();

  // Prepare the driver binary
  memcpy(buf, syshook_boot_bin, syshook_boot_bin_len);

  // Patch ACSI id
  buf[3] = SdDev::gemBootDrive << 5;

  // Patch parameter offset
  verbose("Query longframe\n");
  buf[5] = _longframe() ? 8 : 6;

  // Upload the driver to resident memory
  verbose("Allocate driver memory\n");

#if ACSI_GEMDRIVE_TOPRAM
  uint32_t driverSize = (syshook_boot_bin_len + 0xff) & 0xffffff00;

  // Shift memory to allocate the driver
  ToLong physScreenMem = Physbase() - driverSize;
  ToLong logScreenMem = Logbase() - driverSize;
  ToWord screenRez = (int16_t)Getrez();

  _memtop(_memtop() - driverSize);
  Setscreen(physScreenMem, logScreenMem, screenRez);

  ToLong driverMem = SysHook::phystop - driverSize;
  phystop(driverMem);
#else
  uint32_t driverSize = (syshook_boot_bin_len + 0xf) & 0xfffffff0;
  ToLong driverMem = Malloc(driverSize);
#endif

  memvalid(0); // Don't keep anything memory resident on reset

  delay(21); // Let enough time for the screen to be refresh

  verbose("Upload driver code\n");
  sendAt(driverMem, buf, syshook_boot_bin_len);

  // Install system call hooks
  verbose("Install hooks\n");
  installHook(driverMem, 0x84); // GEMDOS
  //installHook(driverMem, 0xb4); // BIOS
  //installHook(driverMem, 0xb8); // XBIOS

  // Driver splash screen
  tosPrint("\eE" "ACSI2STM " ACSI2STM_VERSION " by Jean-Matthieu Coulon\r\n",
           "GPLv3 license. Source & doc at\r\n",
           " https://github.com/retro16/acsi2stm\r\n\r\n");

  // Cache OSHEADER values
  verbose("Read OSHEADER\n");
  os_beg = _sysbase();
  verbose("Read OSHEADER from ROM\n");
  os_beg = readLongAt(os_beg + offsetof(OSHEADER, os_beg));
  os_version = readWordAt(os_beg + offsetof(OSHEADER, os_version));
  dbgHex("TOS ", os_version, '\n');
  os_conf = readWordAt(os_beg + offsetof(OSHEADER, os_conf));
  if(os_version < 0x102) {
    if(os_conf >> 1 == 4)
      p_run = 0x873c; // Spanish TOS 1.00 basePage pointer
    else
      p_run = 0x602c; // TOS 1.00 basePage pointer
  } else {
    p_run = readLongAt(os_beg + offsetof(OSHEADER, p_run));
  }

  // Unmount all drives
  for(int d = 0; d < driveCount; ++d)
    drives[d].id = -1;

  // Mount drives
  verbose("Get boot drive\n");
  setCurDrive(Dgetdrv());

#if ! ACSI_GEMDOS_SNIFFER
  dbg("Mount SD\n");
  // Compute first drive letter
#if ACSI_GEMDRIVE_FIRST_LETTER
  static const int firstDriveLetter = ACSI_GEMDRIVE_FIRST_LETTER;
#else
  int firstDriveLetter = 'C';
  for(int d = 0; d < driveCount; ++d)
    if(Devices::sdSlots[d]->bootable)
      // Avoid conflicts with legacy drivers that don't respect _drvbits.
      firstDriveLetter = 'L';
#endif
  uint32_t drvbits = _drvbits();
  for(int d = 0; d < driveCount; ++d) {
    if(Devices::sdSlots[d].mode != SdDev::GEMDRIVE)
      continue;

    buf[1] = ':';
    buf[2] = ' ';
    for(int i = (firstDriveLetter - 'A'); i < 26; ++i) {
      if(!(drvbits & (1 << i))) {
        drives[d].id = i;
        drvbits |= (1 << i);

        buf[0] = 'A' + i;
        Devices::sdSlots[d].getDeviceString((char *)&buf[3]);
        memcpy(&buf[27], "\r\n", 3);
        tosPrint((const char *)buf);

        break;
      }
    }
    verbose('\n');
  }
  _drvbits(drvbits);

  // Set boot drive on the ST
  for(int d = 0; d < driveCount; ++d) {
    if(Devices::sdSlots[d].mode == SdDev::GEMDRIVE && Devices::sdSlots[d].mediaId()) {
      setCurDrive(drives[d].id);
      _bootdev(curDriveId);
      Dsetdrv(curDriveId);
      verbose("Set boot drive to ", drives[d].letter(), ":\n");
      break;
    }
  }
#endif

  // Return to boot sequence
  rts();
}

void GemDrive::onGemdos() {
  Word op = readWord();
  switch(op) {
#if ACSI_GEMDOS_SNIFFER
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: { name ## _p p; \
    dbg(" " #name "("); \
    read(p); \
    notVerboseDump(&p, sizeof(p)); \
    dbg(")\n"); \
  } break

#if ! ACSI_VERBOSE
  default:
    notVerboseDump(&op, 2);
    dbg('\n');
#endif

  DECLARE_CALLBACK(Fsetdta);

#else
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: { name ## _p p; \
    dbg(#name "("); \
    read(p); \
    notVerboseDump(&p, sizeof(p)); \
    dbg("): "); if(on ## name(p)) return; \
  } break
#endif

  DECLARE_CALLBACK(Pterm0);
  DECLARE_CALLBACK(Dsetdrv);
  DECLARE_CALLBACK(Tsetdate);
  DECLARE_CALLBACK(Tsettime);
  DECLARE_CALLBACK(Dfree);
  DECLARE_CALLBACK(Fclose);
  DECLARE_CALLBACK(Fread);
  DECLARE_CALLBACK(Fwrite);
  DECLARE_CALLBACK(Fseek);
  DECLARE_CALLBACK(Fattrib);
  DECLARE_CALLBACK(Dgetpath);
  DECLARE_CALLBACK(Pexec);
  DECLARE_CALLBACK(Pterm);
  DECLARE_CALLBACK(Fsnext);
  DECLARE_CALLBACK(Fdatime);

#if ACSI_GEMDOS_SNIFFER
#undef DECLARE_CALLBACK
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: { name ## _p p; \
    dbg(#name "("); \
    read(p); \
    notVerboseDump(&p, sizeof(p)); \
    dbg(")\n"); sniff ## name(p); \
  } break
#endif

  DECLARE_CALLBACK(Dcreate);
  DECLARE_CALLBACK(Ddelete);
  DECLARE_CALLBACK(Dsetpath);
  DECLARE_CALLBACK(Fcreate);
  DECLARE_CALLBACK(Fopen);
  DECLARE_CALLBACK(Fdelete);
  DECLARE_CALLBACK(Fsfirst);
  DECLARE_CALLBACK(Frename);

  // Just log these callbacks
#if ACSI_DEBUG
#undef DECLARE_CALLBACK
#define DECLARE_CALLBACK(name) \
  case Tos::name ## _op: { name ## _p p; \
    dbg(#name "("); \
    read(p); \
    notVerboseDump(&p, sizeof(p)); \
    dbg("): "); \
  } break
#endif

  DECLARE_CALLBACK(Cconin);
  DECLARE_CALLBACK(Cconout);
  DECLARE_CALLBACK(Cauxin);
  DECLARE_CALLBACK(Cauxout);
  DECLARE_CALLBACK(Cprnout);
  DECLARE_CALLBACK(Crawio);
  DECLARE_CALLBACK(Crawcin);
  DECLARE_CALLBACK(Cnecin);
  DECLARE_CALLBACK(Cconws);
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

#undef DECLARE_CALLBACK

  default:
    dbgHex((uint32_t)op, ' ');

  }
  forward();
}

void GemDrive::onBios() {
  Word op = readWord();
  dbgHex(op, '\n');
  switch(op) {
    default:
      forward();
  }
}

void GemDrive::onXbios() {
  Word op = readWord();
  dbgHex(op, '\n');
  switch(op) {
    default:
      forward();
  }
}

void GemDrive::onExtCmd() {
  uint8_t cmd = DmaPort::readIrq();
  uint8_t param = DmaPort::readIrq();
  dbgHex(cmd, '(', param, ")\n");
}

bool GemDrive::openPath(int create, ToLong fname, uint8_t attr, int &driveIndex, TinyPath &path) {
  readStringAt((char *)buf, fname, sizeof(buf));
  dbg("path='", (char *)buf, "' ");

  const char *filename;
  driveIndex = getDrive((char *)buf, &filename);
  if(driveIndex < 0)
    // Unknown drive: forward call to the OS
    return false;

  if(!checkMedium(driveIndex)) {
    rte(EDRIVE);
    return true;
  }

  Drive &drive = drives[driveIndex];
  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  if(create && !sd.isWritable()) {
    rte(EACCDN);
    return true;
  }

  path = drive.curPath;
  int pathSet = path.set(volume, filename, create, attr);

  switch(pathSet) {
    case 0:
      break;
    case 1:
      rte(create ? EACCDN : EFILNF);
      return true;
    case 2:
    case 3:
      rte(EPTHNF);
      return true;
  }

  return false;
}

bool GemDrive::onFcreateopen(int create, ToLong fname, oflag_t oflag, uint8_t attr) {
  int driveIndex;
  TinyPath path;
  if(openPath(create, fname, attr, driveIndex, path))
    return true;
  if(driveIndex < 0)
    return false; 

  auto &sd = Devices::sdSlots[driveIndex];
  FsVolume &volume = sd.fs;

  uint32_t stfd;
  GemFile *fd = createFd(stfd, driveIndex, getBasePage());
  if(!fd) {
    rte(ENHNDL);
    return true;
  }

  FsFile *file = fd->open(volume, path, oflag);
  if(!file) {
    // File exists but cannot be opened: the only possible case is opening
    // read-write a readonly file.
    rte(EACCDN);
    return true;
  }

  if(file->isDirectory()) {
    // Cannot open directories
    rte(EPTHNF);
    return true;
  }

  rte(ToLong(stfd));
  return true;
}

void GemDrive::installHook(uint32_t driverMem, ToLong vector) {
  static const Long xbra = ToLong('X', 'B', 'R', 'A');
  static const Long a2st = ToLong('A', '2', 'S', 'T');

  for(unsigned int i = 0; i < syshook_boot_bin_len - 14; i += 2) {
    // Scan XBRA/A2ST marker
    if(syshook_boot_bin[i] == 'X') {
      Long *lbin = (Long *)(&syshook_boot_bin[i]);
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

Long GemDrive::getBasePage() {
  return readLongAt(p_run);
}

bool GemDrive::checkMedium(int driveIndex) {
  // If the drive doesn't exist, it can't work.
  if(driveIndex < 0)
    return false;

  // Check SD card mediaId
  return Devices::sdSlots[driveIndex].mediaId();
}

int GemDrive::findDriveByMediaId(uint32_t mediaId) {
  if(!mediaId)
    return -1;
  for(int i = 0; i < driveCount; ++i)
    if(mediaId == Devices::sdSlots[i].mediaId())
      return i;
  return -1;
}

void GemDrive::closeProcessFiles() {
  Long basePage = getBasePage();
  for(int fi = 0; fi < filesMax; ++fi) {
    GemFile &file = files[fi];
    if(file && file.basePage == basePage) {
      dbgHex("Closing leaked fd ", fi, '\n');
      file.close();
    }
  }
}

void GemDrive::setCurDrive(int driveId) {
  curDriveId = driveId;
  verbose("Switching to drive ", (char)('A' + curDriveId), ": ");
  curDrive = getDrive(driveId);
  if(curDrive >= 0)
    verbose("Effective drive is ", drives[curDrive].letter(), ":\n");
}

GemFile * GemDrive::getFile(ToWord fd) {
  // Check ACSI2STM marker
  if(fd.bytes[0] != 0x32 + Devices::acsiFirstId)
    return false;

  uint8_t fi = fd.bytes[1];
  if(fi >= filesMax)
    return false;

  return &files[fi];
}

int GemDrive::getDrive(const char *path, const char **outPath) {
  if(!path || !*path)
    return -1;

  if(path[1] == ':') {
    // Absolute path: check drive letter
    char letter = path[0];
    if(letter < 'A')
      return -1;
    if(letter > 'Z')
      letter -= 'a' - 'A';
    if(letter > 'Z')
      return -1;
    if(outPath)
      *outPath = &path[2];
    for(int i = 0; i < driveCount; ++i)
      if(drives[i].letter() == letter)
        return i;
    return -1;
  }

  // Device name
  if(path[0] && path[1] && path[2] && path[3] == ':')
    return -1;

  // Relative path: return current drive
  if(outPath)
    *outPath = path;
  return curDrive;
}

int GemDrive::getDrive(ToWord driveId) {
  verbose("getDrive(", driveId);
  for(int i = 0; i < driveCount; ++i)
    if(drives[i].id == driveId) {
      verbose("):", drives[i].letter(),":\n");
      return i;
    }
  verbose(") not mounted\n");
  return -1;
}


#if ACSI_GEMDOS_SNIFFER

void GemDrive::sniffDcreate(const Tos::Dcreate_p &p) {
  readStringAt((char *)buf, p.path, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("path='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffDdelete(const Tos::Ddelete_p &p) {
  readStringAt((char *)buf, p.path, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("path='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffDsetpath(const Tos::Dsetpath_p &p) {
  readStringAt((char *)buf, p.path, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("path='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffFcreate(const Tos::Fcreate_p &p) {
  readStringAt((char *)buf, p.fname, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("fname='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffFopen(const Tos::Fopen_p &p) {
  readStringAt((char *)buf, p.fname, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("fname='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffFdelete(const Tos::Fdelete_p &p) {
  readStringAt((char *)buf, p.fname, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("fname='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffFsfirst(const Tos::Fsfirst_p &p) {
  readStringAt((char *)buf, p.filename, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("filename='", (char *)buf, "'\n");
#endif
}

void GemDrive::sniffFrename(const Tos::Frename_p &p) {
  readStringAt((char *)buf, p.oldname, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("oldname='", (char *)buf, "'\n");
#endif
  readStringAt((char *)buf, p.newname, sizeof(buf));
#if ! ACSI_VERBOSE
  dbg("newname='", (char *)buf, "'\n");
#endif
}
#endif

// vim: ts=2 sw=2 sts=2 et
