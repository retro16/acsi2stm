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

#ifndef TOS_H
#define TOS_H

#include "acsi2stm.h"

#include "SysHook.h"

#define TOS_PACKED __attribute__((__packed__))

// TOS handlers
struct Tos: public SysHook {

#define DECLARE_SYSVAR(address, type, name) \
  static type name() { return read ## type ## At(address); } \
  static void name(To ## type p) { sendAt(p, address); } \
  static const uint32_t name ## _addr = address;

  DECLARE_SYSVAR(0x400,Long,etv_timer);
  DECLARE_SYSVAR(0x404,Long,etv_critic);
  DECLARE_SYSVAR(0x408,Long,etv_term);
  DECLARE_SYSVAR(0x40c,Long,etv_xtra);
  DECLARE_SYSVAR(0x420,Long,memvalid);
  DECLARE_SYSVAR(0x424,Byte,memcntrl);
  DECLARE_SYSVAR(0x426,Long,resvalid);
  DECLARE_SYSVAR(0x42a,Long,resvector);
  DECLARE_SYSVAR(0x42e,Long,phystop);
  DECLARE_SYSVAR(0x432,Long,_membot);
  DECLARE_SYSVAR(0x436,Long,_memtop);
  DECLARE_SYSVAR(0x43a,Long,memval2);
  DECLARE_SYSVAR(0x43e,Word,flock);
  DECLARE_SYSVAR(0x440,Word,seekrate);
  DECLARE_SYSVAR(0x442,Word,_timr_ms);
  DECLARE_SYSVAR(0x444,Word,_fverify);
  DECLARE_SYSVAR(0x446,Word,_bootdev);
  DECLARE_SYSVAR(0x448,Word,palmode);
  DECLARE_SYSVAR(0x44a,Byte,defshiftmd);
  DECLARE_SYSVAR(0x44c,Byte,sshiftmd);
  DECLARE_SYSVAR(0x44e,Long,_v_bas_ad);
  DECLARE_SYSVAR(0x452,Word,vblsem);
  DECLARE_SYSVAR(0x454,Word,nvbls);
  DECLARE_SYSVAR(0x456,Long,_vblqueue);
  DECLARE_SYSVAR(0x45a,Long,colorptr);
  DECLARE_SYSVAR(0x45e,Long,screenpt);
  DECLARE_SYSVAR(0x462,Long,_vbclock);
  DECLARE_SYSVAR(0x466,Long,_frclock);
  DECLARE_SYSVAR(0x46a,Long,hdv_init);
  DECLARE_SYSVAR(0x46e,Long,swv_vec);
  DECLARE_SYSVAR(0x472,Long,hdv_bpb);
  DECLARE_SYSVAR(0x476,Long,hdv_rw);
  DECLARE_SYSVAR(0x47a,Long,hdv_boot);
  DECLARE_SYSVAR(0x47e,Long,hdv_mediach);
  DECLARE_SYSVAR(0x482,Word,_cmdload);
  DECLARE_SYSVAR(0x484,Byte,conterm);
  DECLARE_SYSVAR(0x486,Long,trp14ret);
  DECLARE_SYSVAR(0x48a,Long,criticret);
  DECLARE_SYSVAR(0x49e,Long,_md);
  DECLARE_SYSVAR(0x4a2,Long,savptr);
  DECLARE_SYSVAR(0x4a6,Word,_nflops);
  DECLARE_SYSVAR(0x4a8,Long,con_state);
  DECLARE_SYSVAR(0x4ac,Word,sav_row);
  DECLARE_SYSVAR(0x4ae,Long,sav_context);
  DECLARE_SYSVAR(0x4b2,Long,_bufl);
  DECLARE_SYSVAR(0x4ba,Long,_hz_200);
  DECLARE_SYSVAR(0x4be,Long,the_env);
  DECLARE_SYSVAR(0x4c2,Long,_drvbits);
  DECLARE_SYSVAR(0x4c6,Long,_dskbufp);
  DECLARE_SYSVAR(0x4ca,Long,_autopath);
  DECLARE_SYSVAR(0x4ce,Long,_vbl_list);
  DECLARE_SYSVAR(0x4ee,Word,prt_cnt);
  DECLARE_SYSVAR(0x4f0,Word,_prtabt);
  DECLARE_SYSVAR(0x4f2,Long,_sysbase);
  DECLARE_SYSVAR(0x4f6,Long,_shell_p);
  DECLARE_SYSVAR(0x4fa,Long,end_os);
  DECLARE_SYSVAR(0x4fe,Long,exec_os);
  DECLARE_SYSVAR(0x502,Long,scr_dump);
  DECLARE_SYSVAR(0x506,Long,prv_lsto);
  DECLARE_SYSVAR(0x50a,Long,prv_lst);
  DECLARE_SYSVAR(0x50e,Long,prv_auxo);
  DECLARE_SYSVAR(0x512,Long,prv_aux);
  DECLARE_SYSVAR(0x516,Long,pun_ptr);
  DECLARE_SYSVAR(0x51a,Long,memval3);
  DECLARE_SYSVAR(0x51e,Long,xconstat);
  DECLARE_SYSVAR(0x53e,Long,xconin);
  DECLARE_SYSVAR(0x55e,Long,xcostat);
  DECLARE_SYSVAR(0x57e,Long,xconout);
  DECLARE_SYSVAR(0x59e,Word,_longframe);
  DECLARE_SYSVAR(0x5a0,Long,_p_cookies);
  DECLARE_SYSVAR(0x5a4,Long,ramtop);
  DECLARE_SYSVAR(0x5a8,Long,ramvalid);
  DECLARE_SYSVAR(0x5ac,Long,bell_hook);
  DECLARE_SYSVAR(0x5b0,Long,kcl_hook);

#undef DECLARE_SYSVAR

  static const int8_t E_OK = 0; // OK. No error has arisen
  static const int8_t ERROR = -1; // Generic error (not specified precisely)
  static const int8_t EDRVNR = -2; // Addressed device/drive not ready
  static const int8_t EUNCMD = -3; // The specified command is unknown
  static const int8_t E_CRC = -4; // Error when reading a sector / CRC error
  static const int8_t EBADRQ = -5; // Bad request / The device cannot execute the command
  static const int8_t E_SEEK = -6; // Drive couldn't reach the specified track
  static const int8_t EMEDIA = -7; // Read error (medium has a wrong boot sector)
  static const int8_t ESECNF = -8; // Sector was not found
  static const int8_t EPAPER = -9; // Printer is not ready / Out of paper
  static const int8_t EWRITF = -10; // Error during a write operation
  static const int8_t EREADF = -11; // Error during a read operation
  static const int8_t EGENRL = -12; // General error
  static const int8_t EWRPRO = -13; // Medium is write-protected
  static const int8_t E_CHNG = -14; // Medium was changed after a write operation
  static const int8_t EUNDEV = -15; // Device is not known to the operating system
  static const int8_t EBADSF = -16; // Bad sectors detected during formatting
  static const int8_t EOTHER = -17; // Insert other floppy (trigger Drive B: emulator).

  static const int8_t EINVFN = -32; // Unknown function number
  static const int8_t EFILNF = -33; // DF: File not found
  static const int8_t EPTHNF = -34; // DE: Directory (folder) not found
  static const int8_t ENHNDL = -35; // No more handles available
  static const int8_t EACCDN = -36; // DC: Access denied
  static const int8_t EIHNDL = -37; // Invalid file handle
  static const int8_t ENSMEM = -39; // Insufficient memory
  static const int8_t EIMBA = -40; // Invalid memory block address
  static const int8_t EDRIVE = -46; // Invalid drive specification
  static const int8_t ECWD = -47; // Current directory cannot be deleted
  static const int8_t ENSAME = -48; // Files on different logical drives
  static const int8_t ENMFIL = -49; // No more files can be opened

  static const int8_t ELOCKED = -58; // Segment of a file is protected (network)
  static const int8_t ENSLOCK = -59; // Invalid lock removal request
  static const int8_t ERANGE = -64; // File pointer in invalid segment (see also FreeMiNT message -88)
  static const int8_t EINTRN = -65; // Internal error of GEMDOS
  static const int8_t EPLFMT = -66; // Invalid program load format
  static const int8_t EGSBF = -67; // Allocated memory block could not be enlarged
  static const int8_t EBREAK = -68; // Program termination by Control-C
  static const int8_t EXCPT = -69; // 68000 exception (bombs)
  static const int8_t EPTHOV = -70; // Path overflow
  static const int8_t ELOOP = -80; // Endless loop with symbolic links
  static const int8_t EPIPE = -81; // Write to broken pipe.

  struct TOS_PACKED OSHEADER {
    Word os_entry;
    Word os_version;
    Long reseth;
    Long os_beg;
    Long os_end;
    Long is_rsv1;
    Long os_magic;
    Long os_date;
    Word os_conf;
    Word os_dosdate;
    // Available as of TOS 1.02 (Blitter-TOS)
    Long p_root;
    Long pkbshift;
    Long p_run;
    Long p_rsv2;
  };

  struct TOS_PACKED BASEPAGE {
    Long p_lowtpa;
    Long p_hitpa;
    Long p_tbase;
    Long p_tlen;
    Long p_dbase;
    Long p_dlen;
    Long p_bbase;
    Long p_blen;
    Long p_dta;
    Long p_parent;
    Long p_resrvd0;
    Long p_env;
    int8_t p_reservd1[80];
    char p_cmdlin[128];
  };

  typedef struct BASEPAGE PD;

  struct TOS_PACKED DISKINFO {
    Long b_free;
    Long b_total;
    Long b_secsiz;
    Long b_clsiz;
  };

  struct TOS_PACKED DOSTIME {
    Word time;
    Word date;
  };

  struct TOS_PACKED DTA {
    uint8_t d_reserved[21];
    uint8_t d_attrib;
    Word d_time;
    Word d_date;
    Long d_length;
    char d_fname[14];
  };

  struct TOS_PACKED PH {
    Word ph_branch; // 0x601a
    Long ph_tlen; // text section length
    Long ph_dlen; // data section length
    Long ph_blen; // bss section length
    Long ph_slen; // symbol table length
    Long ph_res1; // reserved - always zero
    Long ph_prgflags; // flags
    Word ph_absflag; // if zero, relocation
  };

  // TOS functions
#define DECLARE_FUNCTION(name, opCode, params) \
  static Long name params; \
  static const int16_t name ## _op = opCode; \
  struct TOS_PACKED name ## _p

  // GEMDOS functions

  DECLARE_FUNCTION(Pterm0, 0, ()) {
  };
  DECLARE_FUNCTION(Cconin, 1, ()) {
  };
  DECLARE_FUNCTION(Cconout, 2, (char c)) {
    Word c;
  };
  DECLARE_FUNCTION(Cauxin, 3, ()) {
  };
  DECLARE_FUNCTION(Cauxout, 4, (char c)) {
    Word c;
  };
  DECLARE_FUNCTION(Cprnout, 5, (char c)) {
    Word c;
  };
  DECLARE_FUNCTION(Crawio, 6, (ToWord w)) {
    Word w;
  };
  DECLARE_FUNCTION(Crawcin, 7, ()) {
  };
  DECLARE_FUNCTION(Cnecin, 8, ()) {
  };
  DECLARE_FUNCTION(Cconws, 9, (ToLong buf, int len = 0)) {
    Long buf;
  };
  DECLARE_FUNCTION(Cconrs, 10, (ToLong buf)) {
    Long buf;
  };
  DECLARE_FUNCTION(Cconis, 11, ()) {
  };
  DECLARE_FUNCTION(Dsetdrv, 14, (ToWord drv)) {
    Word drv;
  };
  DECLARE_FUNCTION(Cconos, 16, ()) {
  };
  DECLARE_FUNCTION(Cprnos, 17, ()) {
  };
  DECLARE_FUNCTION(Cauxis, 18, ()) {
  };
  DECLARE_FUNCTION(Cauxos, 19, ()) {
  };
  DECLARE_FUNCTION(Dgetdrv, 25, ()) {
  };
  DECLARE_FUNCTION(Fsetdta, 26, (ToLong buf)) {
    Long buf;
  };
  DECLARE_FUNCTION(Super, 32, (ToLong stack)) {
    Long stack;
  };
  DECLARE_FUNCTION(Tgetdate, 42, ()) {
  };
  DECLARE_FUNCTION(Tsetdate, 43, (ToWord date)) {
    Word date;
  };
  DECLARE_FUNCTION(Tgettime, 44, ()) {
  };
  DECLARE_FUNCTION(Tsettime, 45, (ToWord time)) {
    Word time;
  };
  DECLARE_FUNCTION(Fgetdta, 47, ()) {
  };
  DECLARE_FUNCTION(Ptermres, 49, (ToLong keepcnt, ToWord retcode)) {
    Long keepcnt;
    Word retcode;
  };
  DECLARE_FUNCTION(Dfree, 54, (const DISKINFO &buf, ToWord driveno)) {
    Long buf;
    Word driveno;
  };
  DECLARE_FUNCTION(Dcreate, 57, (const char *path)) {
    Long path;
  };
  DECLARE_FUNCTION(Ddelete, 58, (const char *path)) {
    Long path;
  };
  DECLARE_FUNCTION(Dsetpath, 59, (const char *path)) {
    Long path;
  };
  DECLARE_FUNCTION(Fcreate, 60, (const char *fname, ToWord attr)) {
    Long fname;
    Word attr;
  };
  DECLARE_FUNCTION(Fopen, 61, (const char *fname, ToWord mode)) {
    Long fname;
    Word mode;
  };
  DECLARE_FUNCTION(Fclose, 62, (ToWord handle)) {
    Word handle;
  };
  DECLARE_FUNCTION(Fread, 63, (ToWord handle, ToLong count, void *buf)) {
    Word handle;
    Long count;
    Long buf;
  };
  DECLARE_FUNCTION(Fwrite, 64, (ToWord handle, ToLong count, void *buf)) {
    Word handle;
    Long count;
    Long buf;
  };
  DECLARE_FUNCTION(Fdelete, 65, (const char *fname)) {
    Long fname;
  };
  DECLARE_FUNCTION(Fseek, 66, (ToLong offset, ToWord handle, ToWord seekmode)) {
    Long offset;
    Word handle;
    Word seekmode;
  };
  DECLARE_FUNCTION(Fattrib, 67, (const char *fname, ToWord wflag, ToWord attrib)) {
    Long fname;
    Word wflag;
    Word attrib;
  };
  DECLARE_FUNCTION(Dgetpath, 71, (char *path, ToWord driveno)) {
    Long path;
    Word driveno;
  };
  DECLARE_FUNCTION(Malloc, 72, (ToLong number)) {
    Long number;
  };
  DECLARE_FUNCTION(Mfree, 73, (ToLong block)) {
    Long block;
  };
  DECLARE_FUNCTION(Mshrink, 74, (ToLong block, ToLong newsiz)) {
    Word z1;
    Long block;
    Long newsiz;
  };
  DECLARE_FUNCTION(Pexec, 75, (ToWord mode, ToLong l1, ToLong l2, ToLong l3)) {
    Word mode;
    Long l1;
    Long l2;
    Long l3;
  };
  DECLARE_FUNCTION(Pexec_0, 75, (const char *name, const char *cmdline, const char *env)) {
    Word mode;
    Long name;
    Long cmdline;
    Long env;
  };
  DECLARE_FUNCTION(Pexec_3, 75, (const char *name, const char *cmdline, const char *env)) {
    Word mode;
    Long name;
    Long cmdline;
    Long env;
  };
  DECLARE_FUNCTION(Pexec_4, 75, (ToLong basepage)) {
    Word mode;
    Long z1;
    Long basepage;
    Long z2;
  };
  DECLARE_FUNCTION(Pexec_5, 75, (ToLong cmdline, ToLong env)) {
    Word mode;
    Long z1;
    Long cmdline;
    Long env;
  };
  DECLARE_FUNCTION(Pexec_6, 75, (ToLong basepage)) {
    Word mode;
    Long z1;
    Long basepage;
    Long z2;
  };
  DECLARE_FUNCTION(Pexec_7, 75, (ToLong prgflags, ToLong cmdline, ToLong env)) {
    Word mode;
    Long prgflags;
    Long cmdline;
    Long env;
  };
  DECLARE_FUNCTION(Pterm, 76, (ToWord retcode)) {
    Word retcode;
  };
  DECLARE_FUNCTION(Fsfirst, 78, (const char *filename, ToWord attr)) {
    Long filename;
    Word attr;
  };
  DECLARE_FUNCTION(Fsnext, 79, ()) {
  };
  DECLARE_FUNCTION(Frename, 86, (const char *oldname, const char *newname)) {
    Word z1;
    Long oldname;
    Long newname;
  };
  DECLARE_FUNCTION(Fdatime, 87, (const DOSTIME& timeptr, ToWord handle, ToWord wflag)) {
    Long timeptr;
    Word handle;
    Word wflag;
  };
#undef DECLARE_FUNCTION

  // System call templates

  template<typename Params>
  static Long gemdos(ToWord opCode, const Params &params, int extraData = 0) {
    return sysCall(trap1, opCode, (uint8_t *)&params, sizeof(params), extraData);
  }

  static Long gemdos(ToWord opCode) {
    return sysCall(trap1, opCode, 0, 0, 0);
  }

  // Perform a system call with parameters
  static Long sysCall(void (*trap)(), Word opCode, uint8_t *paramBytes, int paramSize, int extraData = 0);

  static void tosPrint(const char c);
  static void tosPrint(const char *text);

  template<typename T>
  static void tosPrint(T txt) {
    tosPrint(txt);
  }

  template<typename T, typename... More>
  static void tosPrint(T txt, More... more) {
    tosPrint(txt);
    tosPrint(more...);
  }
};

// vim: ts=2 sw=2 sts=2 et
#endif
