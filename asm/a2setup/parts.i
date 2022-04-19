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
fat.hsects	rs.l	1   ; $20       ; Number of sectors if nsects==$ffff
fat.drnum	rs.b	1   ; $24       ; Drive ID: 0x80=main drive, 0x00=other
		rs.b	1   ; $25       ; Reserved
fat.ebsig	rs.b	1   ; $26       ; Extended boot signature (0x28 or 0x29)
fat.volid	rs.b	4   ; $27       ; Volume serial number
fat.vlab	rs.b	11  ; $2b       ; Volume name
fat.fstype	rs.b	8   ; $36       ; FAT type: "FAT12   ","FAT16   "
fat.boot	rs.b	448 ; $3e       ; Boot code
fat.sig		rs.w	1   ; $1fe      ; $55aa signature
fat...		rs.b	0

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
