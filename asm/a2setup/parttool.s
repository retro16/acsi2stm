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
	; Partition and filesystem tool
	; Input:
	;  a3: Buffer to containing partition descriptor
	;  a4: Buffer to partition table
	;  d7.b: ACSI id

	flagclr	pend                    ; Clear pending flag to force load

	enter

	bsr.w	menu.chkmed             ; Exit if no medium

	flagtst	pend                    ; Don't reload if there are changes
	bne.b	.devrdy                 ;

	bsr.w	parttool.load           ; Load and parse boot sector
	flagtst	ok

	exiteq	                        ; No valid data: back to devsel

.devrdy	bsr.w	parttool.refrsh         ; Refresh screen
	print	.menu(pc)               ; Print main menu and reset cursor
	bsr.w	escback
	loadpos

.again	bsr.w	menu.waitmed

	gemdos	Cnecin,2                ; Read key

	cmp.b	#$1b,d0                 ; ESC key to return
	beq.w	parttool.exit           ;

	cmp.b	#'-',d0                 ; Up key
	bsreq	parttool.scrlup         ;

	cmp.w	#'+',d0                 ; Down key
	bsreq	parttool.scrldn         ;

	cmp.b	#'1',d0                 ; Quick shortcuts for partition edit
	blt.b	.npart                  ;
	cmp.b	#'9',d0                 ;
	bgt.b	.npart                  ;
	sub.w	#'1',d0                 ;
	bra.w	partedit                ;
.npart
	and.b	#$df,d0                 ; Case insensitive checks

	cmp.b	#'E',d0                 ; Ask for a partition number
	beq.w	parttool.edit           ; then call partition editor

	cmp.b	#'Q',d0
	beq.w	parttool.quick

	cmp.b	#'N',d0
	beq.w	parttool.newmbr

	cmp.b	#'K',d0
	beq.w	parttool.killboot

	cmp.b	#'I',d0
	beq.w	parttool.install

	cmp.b	#'F',d0
	beq.w	parttool.format

	cmp.b	#'P',d0
	beq.w	parttool.save

	cmp.b	#'U',d0
	beq.w	parttool.undo           ;

	swap	d0                      ; Check raw scan codes

	cmp.w	#$0061,d0               ; Undo key
	beq.w	parttool.undo           ;

	cmp.w	#$0048,d0               ; Up arrow key
	bsreq	parttool.scrlup         ;

	cmp.w	#$0050,d0               ; Down arrow key
	bsreq	parttool.scrldn         ;

	bra.w	.again

.menu	dc.b	'  Q:Quick partition  F:Format whole disk',13,10
	dc.b	'  N:Create new MBR',13,10
	dc.b	'1-4:Edit part 1 to 4 E:Edit partition',13,10
	dc.b	'  I:Install driver   K:Kill boot sector',13,10
	dc.b	'  P:Save pending     U:Undo changes',13,10
	dc.b	0
	even

parttool.exit
	flagtst	pend
.exit	exiteq

	bsr.w	parttool.pskip

	print	.sure(pc)
	bsr.w	areyousure
	beq.b	.exit

	restart

.sure	dc.b	'Revert and exit',13,10,0
	even

parttool.refrsh
	; Refresh screen

	cls
	print	.parttl(pc)             ; Print device name
	bsr.w	blkdev.pname            ;
	exitne	                        ;

	print	.devsz1(pc)             ; Print device size
	move.l	part.size(a3),d0        ;
	moveq	#1,d1                   ;
	bsr.w	puint                   ;
	print	.devsz2(pc)             ;

	print	.bst1(pc)               ; Print partition table type
	print	(a3)                    ;

	flagtst	boot ; Print boot flags
	bne.b	.boot
	print	.bst2(pc)
.boot	print	.bst2b(pc)

	flagtst	pend
	bne.b	.pend
	crlf
	bra.b	.savok
.pend	print	.unsav(pc)
.savok

	print	.parthd(pc)             ; Print partition header

	moveq	#0,d3                   ; d3 = partition display offset
	bsr.w	parttool.ptable         ; Print partition table

	bra.w	parttool.pskip          ; Skip partition table

.parttl	dc.b	'Partitioning ',0
.devsz1	dc.b	13,10
	dc.b	'Device is ',0
.devsz2	dc.b	' sectors',13,10,0
.bst1	dc.b	'Boot sector type: ',0
.bst2b	dc.b	' bootable',13,10,0
.bst2	dc.b	' non',0
.unsav	dc.b	'Changes pending',13,10,0
.parthd	dc.b	13,10
	dc.b	'Partitions:',13,10
	dc.b	'  Typ      First       Last Size:MB Fmt',13,10
		; 1 06 4294967295 4294967295 2097151 FAT
		; 2 00
		;1234567890123456789012345678901234567890
	dc.b	0
	even

parttool.pskip
	savepos
	crlf	partlines+1
	clrbot
	rts

parttool.err
	cls
	print	.err(pc)
	bsr.w	presskey
	exit
.err	dc.b	'Device error',13,10,0
	even

parttool.format
	; Format the whole disk

	bsr.w	parttool.pskip
	lea	(a3),a5
	bra.w	partfmt

parttool.killboot
	; Kill the boot sector
	flagset	pend                    ; Mark as pending changes
	flagclr	boot                    ; Clear bootable flag
	restart	                        ; Back to the menu

parttool.undo
	flagclr	pend                    ; When restarting with no pending flag
	restart	                        ; data will be reloaded

parttool.edit
	; Edit a partition
	; Input:
	;  d0.w: partition number

	bsr.w	parttool.pskip          ; Point below partition table

	print	.askprt(pc)             ; Ask for a partition number
	lea	bss+buf(pc),a0          ;
	moveq	#maxparts,d0            ;
	bsr.w	readint                 ;

	move.w	d0,-(sp)                ;
	loadpos	                        ; Cursor at partition table
	move.w	(sp)+,d0                ;

	tst.w	d0                      ; If partition == 0
	rsteq	                        ; none selected: back to menu

	subq.w	#1,d0                   ; Pass partition as zero-based 
	bra.w	partedit

.askprt	dc.b	'Partition to edit:',0
	even

parttool.newmbr
	bsr.w	parts.newpt
	restart

parttool.install
	; Install the boot loader onto the drive

	bsr.w	parttool.pskip

	leal	driver,a0               ; Check that the driver is loaded
	cmp.l	#'A2ST',(a0)            ;
	beq.b	.drvok                  ;
	print	.nodrv(pc)              ;
	bsr.w	presskey                ;
	restart                         ;
.drvok
	bsr.w	parttool.save1st        ; Changes must be saved

	print	.warn(pc)
	bsr.w	areyousure
	loadpos
	tst.w	d0
	rstne
	bsr.w	parttool.pskip

	move.l	d3,-(sp)

	moveq	#0,d3                   ; d3 = sectors required to install
	move.b	7(a0),d3                ;

	flagtst	ok                      ; Check that data is present
	beq.w	.unknwn                 ;

	flagtst	bs                      ; Check that we have read boot sector
	beq.w	.unknwn                 ;

	cmp.l	part.size(a3),d3        ; Check that the drive is big enough
	bhi.w	.small                  ;

	flagtst	fs                      ; If there is a filesystem
	beq.b	.nofs                   ;
	moveq	#0,d0                   ;
	move.w	part.bootsect+fat.res(a3),d0; Check reserved sectors
	rol.w	#8,d0                   ; FIXME: these are logical sectors
	cmp.w	d0,d3                   ; so sector size must be accounted for
	bhi.w	.small                  ;
	bra.b	.instal                 ;
.nofs
	flagtst	pt                      ; If there is a partition table
	beq.b	.instal                 ;
	lea	.pfchk(pc),a0           ;
	bsr.w	parts.iter              ; Check partitions' first sector

.instal	flagtst	fs                      ; Check if a filesystem is there
	bne.b	.instfs                 ;

	lea	part.bootsect+$1b2(a3),a2 ; a2 = Allocsz address
	lea	part.bootsect(a3),a1    ; a1 = boot code address
	bra.b	.patch

.instfs	move.w	#$603c,part.bootsect(a3); Patch 2 first bytes (bsr.b boot)
	lea	part.bootsect+$1f0(a3),a2 ; a2 = Allocsz address
	lea	part.bootsect+fat.boot(a3),a1 ; a1 = boot code address

.patch	move.l	(sp)+,d3

	lea	.boot(pc),a0            ; Copy boot
	move.w	#.bootsz/2-1,d0         ;
.bootcp	move.w	(a0)+,(a1)+             ;
	dbra	d0,.bootcp              ;

	leal	driver+4,a0             ;
	move.l	(a0),d0                 ; Allocsz patch
	move.l	d0,(a2)                 ;

	flagset	boot                    ; Make bootable

	leal	driver,a0               ; Write the driver
	moveq	#0,d0                   ;
	move.b	7(a0),d0                ;
	move.l	a0,d1                   ;
	moveq	#1,d2                   ;
	bsr.w	blkdev.wr               ;
	bne.w	parttool.err            ;

	bra.w	parttool.save           ; Save boot sector

.small	print	.toosmall(pc)
.rstart	bsr.w	presskey
	move.l	(sp)+,d3
	restart
.unknwn	print	.unkfmt(pc)
	bra.b	.rstart

.pfchk	cmp.l	part.first(a0),d3       ; Subroutine on each partition
	bhi.b	.small                  ; Check that partition is far enough
	rts

.boot
	incbin	..\drvboot\drvboot.bin
.bootend
.bootsz	equ	$1b2

.nodrv	dc.b	'Driver not loaded',13,10,0
.unkfmt	dc.b	'Unknown boot format',13,10,0
.toosmall
	dc.b	'Not enough space',13,10,0

.warn	dc.b	'Boot sector cannot be recovered',13,10
	dc.b	'All changes will be saved',13,10,0
	even

parttool.quick
	bsr.w	parttool.pskip          ; Display message
	print	.quick(pc)

	lea	bss+buf(pc),a0          ; Read partition count
	moveq	#maxparts,d0            ;
	bsr.w	readint                 ;

	tst.w	d0                      ; Don't do anything if 0 (cancel)
	rsteq	                        ;

	move.w	d0,-(sp)                ; Store for later

	crlf
	bsr.w	areyousure
	rstne

	crlf
	bsr.w	parts.newpt             ; Reset everything

	move.l	part.size(a3),d0        ;
	move.l	#32*1024*1024*2,d1      ; Cap to 32G because of umul limitation
	cmp.l	d1,d0                   ;
	bls.b	.comput                 ;
	move.l	d1,d0                   ;
.comput	bsr.w	parttool.sec2mb         ;
	divu.w	(sp),d0                 ;

	move.l	#511,d1                 ; 511MB is the max for a ST anyway
	cmp.l	d1,d0                   ;
	bls.b	.small                  ;
	move.l	d1,d0                   ;
.small
	bsr.w	parttool.mb2sec         ;
	move.l	d0,-(sp)                ; Use maximum value if 0 is entered
	rsteq	                        ; Stop if 0

	; Allocate partitions
	movem.l	d3-d6/a3-a5,-(sp)       ; 24(sp).l:size, 28(sp).w:count

	moveq	#0,d3                   ; d3 = partition index
	move.l	28(sp),d4               ; d4 = partition size
	move.w	32(sp),d5               ; d5 = partition count
	moveq	#32,d6                  ; d6 = current offset
	sub.l	d6,d4                   ; (suboptimal) make room for reserved
	lea	(a4),a3                 ; a3 = partition to allocate

.alloc	move.l	d6,part.start(a3)       ; Declare partition
	move.l	d6,part.first(a3)
	move.l	d4,part.size(a3)
	move.l	d6,-(sp)
	add.l	d4,d6
	subq.l	#1,d6
	move.l	d6,part.last(a3)
	move.l	(sp)+,d6

	flagset	ok                      ; Start and size are valid

	lea	(a3),a5                 ; Format partition
	bsr.w	partfmt.auto            ; using default values

	bsr.w	parts.settype           ; Set MBR type:01 for FAT12,06 for FAT16

	add.l	d4,d6                   ; Skip to next partition
	lea	part...(a3),a3          ;
	addq.w	#1,d3                   ;

	cmp.w	d5,d3                   ;
	blt.b	.alloc                  ;

.exit
	movem.l	(sp)+,d3-d6/a3-a5

	bra.w	parttool.save

.quick	dc.b	'Disk will be formatted',13,10
	dc.b	'Esc to cancel',13,10,10
	dc.b	'How many partitions:',0
	even

parttool.save1st
	; Check if data is saved before proceeding
	; If not saved, print an error and restart
	flagtst	pend
	rtseq

	print	.err(pc)
	bsr.w	presskey
	restart

.err	dc.b	'Changes must be saved to do this',13,10,0
	even

parttool.load
	; Load data from disk into (a3) and (a4)
	bsr.w	parts.sensedrv
	bsr.w	parts.parsembr

	rts

parttool.save
	; Save the boot sector
	bsr.w	parts.save
	bne.w	parttool.err
	restart

parttool.ptable
	; Print a partition table
	; Input:
	;  d3.w: partition to print
	;  a4: partition table pointer

	flagtst	pt                      ; Don't print a partition table
	bne.b	.ptok                   ; if there isn't any

	savepos
	print	.nopt(pc)
	loadpos

	rts
.nopt	dc.b	13,10,'No partition table',0
	even

.ptok	movem.l	d3-d4/a4,-(sp)

	move.w	d3,d0                   ; d3 = current partition
	mulu	#part...,d0             ; Point a4 at the first partition
	lea	0(a4,d0),a4             ; to print

	addq.w	#1,d3                   ; Start numbering at 1
	moveq	#partlines,d4           ; d4 = counter
	subq.w	#1,d4                   ;

	savepos	                        ; Save cursor position

.ppart	moveq	#0,d0                   ; Print partition index
	move.w	d3,d0                   ;
	move.l	#$10002,d1              ;
	bsr.w	puint                   ;

	flagtst	ok,(a4)                 ; Skip if unset
	beq.b	.next                   ;

	print	part.type(a4)           ; Print type

	move.l	part.first(a4),d0       ; Print first sector
	move.l	#$1000b,d1              ;
	bsr.w	puint                   ;

	move.l	part.last(a4),d0        ; Print first sector
	bsr.w	puint                   ;

	move.l	part.size(a4),d0        ; Convert size to MB
	bsr.w	parttool.sec2mb

	move.l	#$10008,d1              ; Print size in MB
	bsr.w	puint                   ;

	pchar	' '

	print	(a4)                    ; Print content format

.next	clrtail	                        ; Clear end of line
	crlf	                        ; Next line

	lea	part...(a4),a4          ; Print next partition
	addq.w	#1,d3                   ;
	dbra	d4,.ppart               ;

	loadpos	                        ; Replace cursor at start

	movem.l	(sp)+,d3-d4/a4
	rts

parttool.sec2mb
	; Convert a sector count in d0 to MB
	; Input:
	;  d0.l: sector count
	; Output:
	;  d0.l: size in MB
	; Preserves all registers except CCR and d0

	lsr.l	#1,d0                   ; Truncate to KB
	add.l	#1023,d0                ; Round to the upper MB

	lsr.l	#8,d0                   ; Convert KB to MB
	lsr.l	#2,d0                   ;
	rts

parttool.mb2sec
	; Convert a size in MB to a sector count
	; Input:
	;  d0.l: size in MB
	; Output:
	;  d0.l: sector count
	; Preserves all registers except CCR and d0

	lsl.l	#8,d0                   ; Multiply by 2048
	lsl.l	#3,d0                   ;

	rts

parttool.scrlup
	movem.l	d0-d2/a0-a2,-(sp)

	tst.w	d3                      ; Check that we don't scroll
	beq.b	parttool..scrlok        ; before first partition

	subq.w	#1,d3                   ; Scroll up

parttool..scrlok
	bsr.w	parttool.ptable         ;Refresh display

parttool..scrlno
	movem.l	(sp)+,d0-d2/a0-a2
	rts

parttool.scrldn
	movem.l	d0-d2/a0-a2,-(sp)

	cmp.w	#maxparts-partlines,d3  ; Check that we dont't scroll
	bge.b	parttool..scrlno        ; after last partition

	addq.w	#1,d3                   ; Scroll down
	bra.b	parttool..scrlok

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
