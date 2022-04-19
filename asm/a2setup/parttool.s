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
; Partitioning tool

parttool
	; Load boot sector
	bsr.w	parttool.load
	tst.b	d0
	rstne

	enter
	bsr.w	parttool.boot           ; d6 = bootable flag

	moveq	#0,d5                   ; d5 = first sector

	bsr.w	blkdev.cap              ; d4 = device size in sectors
	move.l	d0,d4                   ;
	exiteq

	; Print device name
	print	.parttl(pc)
	bsr.w	blkdev.pname

	; Print device size
	print	.devsz1(pc)
	move.l	d4,d0
	moveq	#1,d1
	bsr.w	puint
	print	.devsz2(pc)

	; Print partition table type
	print	.bst1(pc)
	bsr.w	parttool.ptype
	tst.b	d6
	beq.b	.nboot
	print	.bst2b(pc)
	bra.b	.ptypok
.nboot	print	.bst2(pc)
.ptypok

	; Print the menu
	print	.menu(pc)

.again	gemdos	Cnecin,2

	cmp.l	#$00610000,d0
	beq.w	parttool.undo

	cmp.b	#$1b,d0                 ; ESC key to return
	exiteq                          ;

	and.b	#$df,d0                 ; Turn everything upper case

	cmp.b	#'T',d0
	beq.w	parttool.tglbt

	cmp.b	#'I',d0
	beq.w	parttool.install

	cmp.b	#'S',d0
	beq.w	parttool.save

	cmp.b	#'U',d0
	beq.w	parttool.undo

	bra.b	.again

.parttl	dc.b	$1b,'E'
	dc.b	'Partitioning ',0
.devsz1	dc.b	13,10
	dc.b	'Device is ',0
.devsz2	dc.b	' sectors',13,10,0
.bst1	dc.b	'Boot sector type: ',0
.bst2b	dc.b	' bootable',13,10,0
.bst2	dc.b	' non-bootable',13,10,0
.parts	dc.b	13,10
	dc.b	'Partitions:',13,10,0
.menu	dc.b	13,10
	dc.b	13,10
	dc.b	'  I: Install driver in the boot sector',13,10
	dc.b	'  T: Toggle bootable',13,10
	dc.b	'  U/Undo: Undo changes',13,10
	dc.b	'  S: Save changes to disk',13,10
	dc.b	13,10
	dc.b	'Esc: Main menu',13,10
	dc.b	0
	even

parttool.err
	print	.err(pc)
	bsr.w	presskey
	exit
.err	dc.b	'Error',13,10,0

parttool.tglbt
	lea	bss+boot(pc),a0
	eor.w	#$55aa,(a0)
	bsr.w	parttool.boot	
	restart

parttool.undo
	bsr.w	parttool.load
	restart

parttool.install
	print	.warn(pc)
	bsr.w	areyousure
	rstne

	ifne	stm32flash
	; Running from flash: fetch the code from the STM32
	lea	bss+buf(pc),a0          ; Fetch driver code
	moveq	#$d,d1                  ;
	bsr.w	blkdev.1byte            ;
	bne.w	parttool.err            ;

	elseif
	; Running from TOS: code is embedded
	lea	bss+buf(pc),a1          ; Copy driver code
	lea	parttool.driver(pc),a0
	move.w	#(parttool.drvend-parttool.driver)/2-1,d0
.dcopy	move.w	(a0)+,(a1)+
	dbra	d0,.dcopy

	endc

	move.w	d3,d0                   ; Dispatch based on the boot type
	beq.w	.nopatch                ;
	subq.w	#1,d0                   ;
	beq.w	.patchfat               ;
	subq.w	#1,d0                   ;
	beq.w	.patchmbr               ;
	subq.w	#1,d0                   ;
	beq.w	.patchtos               ;
.nopatch
	pea	.unkfmt(pc)
.err	gemdos	Cconws,6
	bsr.w	presskey
	restart

.patchfat
	lea	bss+buf+7(pc),a1        ; a1 = Boot code size in sectors
	lea	bss+boot+fat.res(pc),a0 ; a0 = FAT reserved sectors
	move.b	1(a0),d0                ;
	bne.b	.fatok                  ; More than 256 reserved sectors: OK !
	cmp.b	(a0)+,(a1)+             ;
	bls.b	.fatok                  ;

	pea	.toosmall(pc)           ; Not enough reserved sectors !
	bra.b	.nopatch                ;

.fatok	pea	bss+boot+$1f4(pc)       ; Checksum address
	move.w	#$603c,-(sp)            ; Patch 2 first bytes
	pea	bss+boot+$1f0(pc)       ; Allocsz address
	pea	bss+boot+$3e(pc)        ; Boot sector address
	bra.b	.patch

.patchmbr
	moveq	#mpart...-4,d0          ; d0 = partition descriptor size
	bset	#16,d0                  ; Little endian flag
	lea	bss+boot+mtbl.parts+mpart.start(pc),a0
	pea	bss+boot+$1b6(pc)       ; Checksum address
.patchtbl
	moveq	#0,d1                   ; d1 = driver sector count
	move.b	bss+buf+7(pc),d1        ;
	addq.b	#1,d1                   ; Add 1 for boot sector

	swap	d0                      ; d0[swap] = partition counter
	move.w	#3,d0                   ;

.nxtprt	move.l	(a0)+,d2                ; d2 = partition start

	btst	#16,d0                  ; Byte swap if necessary
	beq.b	.nswap                  ;
	rol.w	#8,d2                   ;
	swap	d2                      ;
	rol.w	#8,d2                   ;
.nswap

	tst.l	(a0)                    ; Check if partition is empty
	beq.b	.partok                 ;

	cmp.l	d2,d1                   ; Check that the partition starts
	bls.w	.partok                 ; after the driver

	pea	.toosmall(pc)           ; Not enough space before the 1st
	bra.b	.nopatch                ; partition

.partok	swap	d0                      ; Point at next partition
	lea	0(a0,d0),a0             ;
	swap	d0                      ;
	dbra	d0,.nxtprt              ;

	clr.w	-(sp)                   ; Don't patch the first 2 bytes
	pea	bss+boot+$1b2(pc)       ; Allocsz address
	pea	bss+boot(pc)            ; Boot sector address
	bra.b	.patch

.patchtos
	moveq	#tpart...-4,d0          ;
	lea	bss+boot+ttbl.parts+tpart.start(pc),a0
	pea	bss+boot+$1b6(pc)       ; Checksum address
	bra.b	.patchtbl

.patch	lea	.boot(pc),a0            ; Copy boot
	move.l	(sp)+,a1                ;
	move.w	#.bootsz/2-1,d0         ;
.bootcp	move.w	(a0)+,(a1)+             ;
	dbra	d0,.bootcp              ;

	move.l	bss+buf+4(pc),d0        ; Allocsz patch
	move.l	(sp)+,a1                ;
	move.l	d0,(a1)                 ;

	move.w	(sp)+,d0                ; Initial branch patch
	beq.b	.nbra                   ;
	lea	bss+boot(pc),a0         ;
	move.w	d0,(a0)                 ;
.nbra
	move.l	(sp),a0                 ; Patch boot checksum
	clr.w	(a0)                    ;
	bsr.w	parttool.boot           ;
	sub.w	#$1234,d0               ;
	neg.w	d0                      ;
	move.l	(sp)+,a0                ;
	move.w	d0,(a0)                 ;

	lea	bss+buf(pc),a0          ; Write the driver
	moveq	#0,d0                   ;
	move.b	7(a0),d0                ;
	move.l	a0,d1                   ;
	moveq	#1,d2                   ;
	bsr.w	blkdev.wr               ;
	bne.w	parttool.err            ;

	bra.w	parttool.save           ; Save boot sector

.unkfmt	dc.b	'Unknown boot format',13,10,0
.toosmall
	dc.b	'Not enough space to install',13,10,0
	even

.boot
	incbin	..\drvboot\drvboot.bin
.bootend
.bootsz	equ	.bootend-.boot

.warn	dc.b	'Previous boot sector cannot be recovered',13,10
	dc.b	'All changes will be saved immediately',13,10,0
	even

parttool.load
	; Load the boot sector
	moveq	#1,d0
	lea	bss+boot(pc),a0
	move.l	a0,d1
	moveq	#0,d2
	bsr.w	blkdev.rd

	rts

parttool.save
	; Save the boot sector
	moveq	#1,d0
	lea	bss+boot(pc),a0
	move.l	a0,d1
	moveq	#0,d2
	bsr.w	blkdev.wr

	tst.b	d0
	bne.w	parttool.err

	restart

parttool.ptype
	; Print partition table type

	bsr.w	parts.isfatfs
	tst.l	d0
	beq.b	.nfat
	moveq	#1,d3
	lea	.fat(pc),a0
	bra.b	.print
.nfat

	bsr.w	parts.ismbr
	tst.l	d0
	beq.b	.nmbr
	moveq	#2,d3
	lea	.mbr(pc),a0
	bra.b	.print
.nmbr

	bsr.w	parts.istos
	tst.l	d0
	beq.b	.ntos
	moveq	#3,d3
	lea	.tos(pc),a0
	bra.b	.print
.ntos
	moveq	#0,d3
	lea	.unk(pc),a0

.print	print	(a0)
	rts

.fat	dc.b	'FAT',0                 ; d3 = 1
.mbr	dc.b	'MBR',0                 ; d3 = 2
.tos	dc.b	'TOS',0                 ; d3 = 3
.unk	dc.b	'???',0                 ; d3 = 0

parttool.boot
	; Updates d6 with the bootable flag
	; Input:
	;  boot: boot sector data
	;  d7.b: ACSI id
	; Output:
	;  d0.w: Boot sector checksum
	;  d6.b: $ff if bootable, 0 otherwise

	lea	bss+boot(pc),a0
	moveq	#0,d0
	move.w	#255,d1
.cksum	add.w	(a0)+,d0
	dbra	d1,.cksum
	cmp.w	#$1234,d0
	seq	d6
	rts

parttool.pmbr
	; Print a MBR partition table


	; Embed driver code for the standalone TOS version

	ifeq	stm32flash
parttool.driver
	incbin	..\a2stdrv\a2stdrv.bin
parttool.drvend
	endc

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
