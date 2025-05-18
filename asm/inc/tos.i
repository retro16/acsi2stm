; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2025 by Jean-Matthieu Coulon

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

; TOS definitions and macros

; System calls
syscall	macro
	move.w	#\2,-(sp)               ; Push syscall identifier
	trap	#\1                     ; Do the call

	ifnc	'','\3'                 ; If a stack rewind parameter is passed
	ifgt	\3-8                    ;
	lea	\3(sp),sp               ; Rewind the stack
	elseif                          ;
	addq.l	#\3,sp                  ; Rewind using addq
	endc                            ;
	endc                            ;
	endm

; GEMDOS system call
gemdos	macro
	syscall	1,\1,\2
	endm

Pterm0	macro
	clr.w	-(sp)
	trap	#1
	endm

Super	macro
	clr.l	-(sp)
	move.w	#Super,-(sp)
	trap	#1
	addq.l	#6,sp
	endm

print	macro	; Print a string
	pea	\1
	gemdos	Cconws,6
	endm

pchar	macro	; Print a character
	move.l	#(\1)!(Cconout<<16),-(sp)
	trap	#1
	addq.l	#4,sp
	endm

pchar2	macro
	movem.l	d0-d2/a0-a2,-(sp)
	pchar	\1
	pchar	\2
	movem.l	(sp)+,d0-d2/a0-a2
	endm

crlf	macro
	movem.l	d0-d2/a0-a2,-(sp)
	pchar	$0d
	pchar	$0a
	movem.l	(sp)+,d0-d2/a0-a2
	endm

; GEMDOS calls
Cconin=1
Cconout=2
Cauxout=4
Crawcin=7
Cnecin=8
Cconws=9
Cconrs=10
Cconis=11
Dsetdrv=14
Cauxis=18
Dgetdrv=25
Fsetdta=26
Super=32
Tsetdate=43
Tsettime=45
Fgetdta=47
Sversion=48
Ptermres=49
Dcreate=57
Ddelete=58
Dsetpath=59
Fcreate=60
Fopen=61
Fclose=62
Fread=63
Fwrite=64
Fdelete=65
Fseek=66
Fattrib=67
Fdup=69
Fforce=70
Dgetpath=71
Malloc=72
Mfree=73
Mshrink=74
Pexec=75
Pterm=76
Fsfirst=78
Fsnext=79
Frename=86
Fdatime=87

; BIOS system call
bios	macro
	syscall	13,\1,\2
	endm

Bconin=2
Bconout=3
Rwabs=4
Setexc=5
Getbpb=7
Mediach=9
Drvmap=10

; XBIOS system calls
xbios	macro
	syscall	14,\1,\2
	endm

Setcolor=7
Floprd=8
Flopwr=9
Flopfmt=10
Random=17

; System variables
flock=$43e                              ; Floppy semaphore
vbclock=$462                            ; vblank counter
bootdev=$446                            ; Boot device
hz200=$4ba                              ; 200Hz timer
nflops=$4a6                             ; Number of mounted floppies
drvbits=$4c2                            ; Mounted drives
sysbase=$4f2                            ; OSHEADER pointer
pun_ptr=$516                            ; PUN_INFO table
phystop=$42e                            ; Top of physical RAM
memtop=$436                             ; Top of TOS RAM
dskbufp=$4c6                            ; Disk buffers
bufl=$4b2                               ; Buffer lists
_longframe=$59e                         ; Word: true if using long frames
memvalid=$420                           ; Magic number to detect if RAM is valid

; Exception vectors
gemdos.vector=$84
bios.vector=$b4
xbios.vector=$b8
getbpb.vector=$472
rwabs.vector=$476
mediach.vector=$47e

; GEMDOS error codes
; From emuTOS
E_OK=0          ; OK, no error
ERR=-1          ; basic, fundamental error
EBADRQ=-5       ; bad request
ESECNF=-8       ; sector not found
EWRITF=-10      ; write fault
EREADF=-11      ; read fault
EWRPRO=-13      ; write protect
E_CHNG=-14      ; media change
EUNDEV=-15      ; Unknown device
EBADSF=-16      ; bad sectors on format
EOTHER=-17      ; insert other disk
EINVFN=-32      ; invalid file name
EFILNF=-33      ; file not found
EPTHNF=-34      ; path not found
EACCDN=-36      ; access denied
EBADF=-37       ; bad file descriptor
EDRIVE=-46      ; invalid drive specification
ECWD=-47        ; current dir cannot be deleted
ENSAME=-48      ; not the same drive
ENMFIL=-49      ; no more files
ERANGE=-64      ; seek out of range
EPLFMT=-66      ; invalid program load format

; DMA port hardware registers
dma	equ	$ffff8604
dmadata	equ	dma
dmactrl	equ	dma+2
dmahigh	equ	dma+5
dmamid	equ	dma+7
dmalow	equ	dma+9
gpip	equ	$fffffa01


; Structures

; PD/BASEPAGE size
pd...		equ	256

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
