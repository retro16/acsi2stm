; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2022 by Jean-Matthieu Coulon

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

; ACSI2STM setup program
; Partition and filesystem handling routines

; tpart: TOS partition entry
		rsreset
tpart.status	rs.b	1   ; $00       ; Status: bit 0 = exists
			                ;         bit 7 = bootable
tpart.id	rs.b	3   ; $01       ; Partition type (GEM / BGM / ...)
tpart.start 	rs.l	1   ; $04       ; Partition offset in 512 bytes sectors
tpart.size	rs.l	1   ; $08       ; Partition size in 512 bytes sectors
tpart...	rs.b	0

; ttbl: TOS partition table
		rsreset
ttbl.boot	rs.b	440 ; $000      ; Boot code
		rs.b	10  ; $1b8      ; Legacy fields (ignored by the driver)
ttbl.nsects	rs.l	1   ; $1c2      ; Hard disk size in sectors
ttbl.parts	rs.b	tpart... ;$1c6  ; Partition entries
ttbl.bso	rs.l	1   ; $1f6      ; Bad sector list offset
ttbl.bsc	rs.l	1   ; $1fa      ; Bad sector count
ttbl.cksum	rs.w	1   ; $1fe      ; Boot sector offset
ttbl...		rs.b	0

; mpart: MBR partition entry
; All values are little endian
		rsreset
mpart.status	rs.b	1   ; $00       ; $80: Bootable, $00: non-bootable
			                ; CHS of the first sector
mpart.fhead	rs.b	1   ; $01       ; Head of the first sector
mpart.fsect	rs.b	1   ; $02       ; Sector of the first sector
mpart.fcyl	rs.b	1   ; $03       ; Cylinder of the first sector
mpart.type	rs.b	1   ; $04       ; Partition type
mpart.lhead	rs.b	1   ; $05       ; Head of the last sector
mpart.lsect	rs.b	1   ; $06       ; Sector of the last sector
mpart.lcyl	rs.b	1   ; $07       ; Cylinder of the last sector
mpart.start	rs.l	1   ; $08       ; First sector in LBA addressing
mpart.size	rs.l	1   ; $0c       ; Total number of sectors
mpart...	rs.b	0   ; $10       ; Size of the partition structure

; mtbl: MBR partition table
; All values are little endian
		rsreset
mtbl.boot	rs.b	440 ; $00       ; Boot loader code
mtbl.id		rs.l	1   ; $1b8      ; Optional disk signature
		rs.w	1   ; $1bc      ; Usually null
mtbl.parts	rs.b	4*mpart... ;$1be; Partition entries
mtbl.sig	rs.w	1   ; $1fe      ; $55aa signature


; fat: FAT boot sector
; All values are little endian
		rsreset
fat.bra		rs.b	3   ; $00       ; Jump instruction
fat.oem		rs.b	8   ; $03       ; OEM name padded with spaces
fat.bps		rs.b	2   ; $0b  $0200; Bytes per sector
fat.spc		rs.b	1   ; $0d  $02  ; Sectors per cluster
fat.res		rs.w	1   ; $0e  $0001; Reserved sector count
fat.nfats	rs.b	1   ; $10  $02  ; Number of FATs (0 means 1)
fat.ndirs	rs.b	2   ; $11  $0070; Root directory entries
fat.nsects	rs.b	2   ; $13  $05a0; Total number of sectors
fat.media	rs.b	1   ; $15  $f9  ; Media descriptor (0xf8 for HD)
fat.spf		rs.w	1   ; $16  $0005; Sectors per FAT
fat.spt		rs.w	1   ; $18  $0009; Sectors per track
fat.nheads	rs.w	1   ; $1a  $0002; Drive heads
fat.nhid	rs.l	1   ; $1c       ; Hidden sectors before the partition
fat.hsects	rs.l	1   ; $20       ; Number of sectors if nsects==0
fat.drnum	rs.b	1   ; $24       ; Drive ID: 0x80=main drive, 0x00=other
		rs.b	1   ; $25       ; Reserved
fat.ebsig	rs.b	1   ; $26       ; Extended boot signature (0x28 or 0x29)
fat.volid	rs.b	4   ; $27       ; Volume serial number
fat.vlab	rs.b	11  ; $2b       ; Volume name
fat.fstype	rs.b	8   ; $36       ; FAT type: "FAT12   ","FAT16   "
fat.boot	rs.b	448 ; $3e       ; Boot code
fat.sig		rs.w	1   ; $1fe      ; $55aa signature
fat...		rs.b	0

; bpb: Bios Parameter Block
		rsreset
bpb.recsiz	rs.w	1 ;   $200 512  ; Bytes per sector
bpb.clsiz	rs.w	1 ;   $2   2    ; Sectors per cluster
bpb.clsizb	rs.w	1 ;   $400 1024 ; Bytes per cluster
bpb.rdlen	rs.w	1 ;   $7   7    ; Sectors in root dir
bpb.fsiz	rs.w	1 ;   $5   5    ; Length of the FAT in sectors
bpb.fatrec	rs.w	1 ;   $6   6    ; Start sector of the 2nd FAT
bpb.datrec	rs.w	1 ;   $12  18   ; Sector of first cluster
bpb.numcl	rs.w	1 ;   $2c7 711  ; Number of clusters
bpb.bflags	rs.w	1 ;             ; Flags
			                ; Bit 0: 0 = FAT12, 1 = FAT16
			                ; Bit 1: 0 = 2 FATs, 1 = 1 FAT
bpb...		rs.b	0

; Internal drive / partition entry
		rsreset
part.format	rs.l	1               ; Autodetected content format
part.csize	rs.l	1               ; Size of the content
part.start	rs.l	1               ; Start sector (first/EBR sector)
part.first	rs.l	1               ; First sector
part.last	rs.l	1               ; Last sector (unused for save)
part.size	rs.l	1               ; Size in sectors
part.type	rs.l	1               ; Type as a 3 char string
part.id		rs.l	1               ; Disk / partition identifier
part.extpart	rs.b	1               ; Extended partition index (1-4)
part.flags	rs.b	1               ; 
part.flags_ok	equ	0               ; Set if first, last and size are valid
part.flags_fs	equ	1               ; Set if it contains a filesystem
part.flags_pt	equ	2               ; Set if it contains a partition table
part.flags_bs	equ	3               ; Is the boot sector valid ?
part.flags_boot	equ	4               ; Bootable (checksum == 0x1234)
part.flags_b	equ	5               ; Boot flag (for MBR)
part.flags_pend	equ	6               ; Set if there are unsaved changes
part.bpb	rs.b	bpb...          ; Filesystem BPB (if any)
		rs.b	6               ; Align to 8 bytes
part.bootsect	rs.b	512             ; Boot sector data
part...align	rs.b	0               ; Align at 16 bytes boundary
	ifne	part...align&$f
		rs.b	($10-part...align)&$f
	endc
part...		rs.b	0

pt...		equ	part...*maxparts; Partition table size

; Partition format parameters structure
		rsreset
		rs.w	1
		rs.b	1
pfmt.fat12	rs.b	1               ; $ff if FAT12, 0 if FAT16
pfmt.ssize	rs.w	1               ; Logical sector size in log2 sectors
pfmt.csize	rs.w	1               ; Logical sectors per cluster in log2
pfmt.res	rs.l	1               ; Reserved sectors
pfmt.fatsz	rs.l	1               ; FAT size in logical sectors
pfmt.root	rs.l	1               ; Root directory entries
pfmt.dclust	rs.l	1               ; Total number of data clusters
pfmt.serial	rs.l	1               ; Serial number
pfmt.label	rs.b	12              ; Label (11 characters + zero)
pfmt.head	rs.l	1               ; Total header size in logical sectors
pfmt.tsect	rs.l	1               ; Total number of logical sectors
pfmt.offset	rs.l	1               ; Device offset in sectors
pfmt.psect	rs.l	1               ; Partition/device size in sectors
pfmt.spt	rs.w	1               ; Sectors per track
pfmt.nheads	rs.w	1               ; Drive heads
		rs.l	1
pfmt...		rs.b	0

copyblk	macro
	ifne	(\3)&7
	fail	Incorrect copy size
	endc
	moveq	#((\3)/8)-1,d0
	lea	\1,a0
	lea	\2,a1
	bsr.w	parts.copyblk
	endm

clrblk	macro
	ifne	(\2)&7
	fail	Incorrect clr size
	endc
	iflt	((\2)/8)-128
	moveq	#((\2)/8)-1,d0
	elseif
	move.w	#((\2)/8)-1,d0
	endc
	ifnc	'\1','(a0)'
	lea	\1,a0
	endc
	bsr.w	parts.clrblk
	endm

flagtst	macro
	ifc	'','\2'
	btst	#part.flags_\1,part.flags(a3)
	elseif
	btst	#part.flags_\1,part.flags\2
	endc
	endm

flagset	macro
	ifc	'','\2'
	bset	#part.flags_\1,part.flags(a3)
	elseif
	bset	#part.flags_\1,part.flags\2
	endc
	endm

flagclr	macro
	ifc	'','\2'
	bclr	#part.flags_\1,part.flags(a3)
	elseif
	bclr	#part.flags_\1,part.flags\2
	endc
	endm

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
