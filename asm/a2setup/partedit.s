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
; Partition edit

partedit
	; Edit a partition
	; Input:
	;  d0.b: partition number (1-32)
	;  d3.l: partition table offset
	;  a3: disk descriptor
	;  a4: partition table

	ext.w	d0
	ext.l	d0
	move.l	d0,d4                   ; d4 = partition number

	enter

	bsr.w	parttool.refrsh         ; Refresh partition table

	move.l	d4,d0                   ; a5 = pointer to current partition
	mulu	#part...,d0             ;
	lea	0(a4,d0),a5             ;

	print	.part(pc)               ; Print selected partition
	move.l	d4,d0                   ;
	addq.w	#1,d0                   ;
	moveq	#1,d1                   ;
	bsr.w	puint                   ;

	cmp.l	#'MBR'<<8,(a3)
	beq.b	.mbrok
	print	.nombr(pc)
	bsr.w	presskey
	exit
.nombr	dc.b	13,10,'Error: No MBR',13,10,0
.mbrok

	print	.menu(pc)
	bsr.w	escback
	loadpos

	flagtst	ok,(a5)                 ; If the partition is not set:
	beq.w	partedit.new            ; create it

	bsr.w	partedit.refresh        ; Refresh current partition and display

	; Partition edit menu
.again	bsr.w	menu.waitmed

	gemdos	Cnecin,2

	cmp.b	#$1b,d0
	exiteq

	cmp.b	#$7f,d0
	beq.w	partedit.delete

	and.b	#$df,d0                 ; Case insensitive checks

	cmp.b	#'P',d0
	beq.w	parttool.save

	cmp.b	#'D',d0
	beq.w	partedit.delete

	cmp.b	#'T',d0
	beq.w	partedit.asktype

	cmp.b	#'S',d0
	beq.w	partedit.askfirst

	cmp.b	#'L',d0
	beq.w	partedit.asklast

	cmp.b	#'R',d0
	beq.w	partedit.resize

	cmp.b	#'U',d0
	beq.w	partedit.undo           ;

	cmp.b	#'F',d0
	beq.w	partfmt

	swap	d0                      ; Check raw scan codes

	cmp.w	#$0061,d0               ; Undo key
	beq.w	partedit.undo           ;

	bra.b	.again

.part	dc.b	'Edit partition ',0
.menu	dc.b	13,10,10
		;1234567890123456789|12345678901234567890
	dc.b	'  F:Format            D:Delete partition',13,10
	dc.b	'  S:Set first sector  L:Set last sector',13,10
	dc.b	'  T:Set type          R:Resize',13,10
	dc.b	'  P:Save pending      U:Undo changes',13,10
	dc.b	0
	even

partedit.undo
	unlk	a6
	bra.w	parttool.undo

partedit.delete
	flagset	pend
	flagclr	ok,(a5)
	exit

partedit.new
	; Reset partition to create a new one

	flagclr	ok,(a5)                 ; Clear the partition
	flagset	pend                    ; Mark as changes pending

	bsr.w	partedit.settype
	bsr.w	partedit.setfirst
	bsr.w	partedit.setsize

	flagset	ok,(a5)                 ; Successfully set size

	restart

partedit.asktype
	bsr.b	partedit.settype
	restart

partedit.settype
	bsr.w	parttool.pskip          ; Ask for the type
	print	.type(pc)               ;
	curson
	lea	bss+buf(pc),a0          ;
	move.w	#$0200,(a0)             ; 2 bytes max, currently 0 bytes
	clr.l	2(a0)                   ; Clear buffer
	pea	(a0)                    ;
	gemdos	Cconrs,6                ;
	loadpos
	cursoff

	lea	bss+buf+2(pc),a0        ;
	tst.b	(a0)                    ; Check for empty string (abort)
	beq.b	.abort                  ;

	bsr.w	parts.t2b               ; Convert to hex

	tst.b	d0                      ; Check if the type is non-null
	bne.b	.typset                 ;

	; Type is null
.abort	flagtst	ok,(a5)                 ; If the partition already exists
	rstne	                        ; return to menu
	exit	                        ; if not, just exit

.typset	flagset	pend                    ; Data altered
	lea	part.type(a5),a0        ;
	bsr.w	parts.b2t               ;

	rts

.type	dc.b	'1=FAT12 6=FAT16',13,10
	dc.b	'Partition type:',0
	even

partedit.askfirst
	bsr.b	partedit.setfirst
	restart

partedit.setfirst
	bsr.w	parttool.pskip          ; Display
	print	.first(pc)

	lea	bss+buf(pc),a0          ; Read sector
	move.l	part.last(a3),d0        ;
	bsr.w	readint                 ;

	loadpos	                        ; Reset cursor

	tst.b	d0                      ; Check if the sector is non-null
	bne.b	.ok                     ;

	; Sector cannot be 0
	flagtst	ok,(a5)                 ; If the partition already exists
	rstne	                        ; return to menu
	exit	                        ; if not, just exit

.ok	flagset	pend                    ; Data altered
	move.l	d0,part.start(a5)       ;

	rts

.first	dc.b	'Enter start sector:',0
	even

partedit.asklast
	bsr.b	partedit.setlast
	bsr.w	partedit.warnosz
	restart

partedit.setlast
	bsr.w	parttool.pskip          ; Display
	print	.last(pc)

	lea	bss+buf(pc),a0          ; Read sector
	move.l	part.last(a3),d0        ;
	bsr.w	readint                 ;

	loadpos	                        ; Reset cursor

	cmp.l	part.first(a5),d0       ; Check if the sector is correct
	bhi.b	.ok                     ;

	; Sector overlap
	flagtst	ok,(a5)                 ; If the partition already exists
	rstne	                        ; return to menu
	exit	                        ; if not, just exit

.ok	flagset	pend                    ; Data altered
	addq.l	#1,d0                   ;
	move.l	part.start(a5),d1       ;
	sub.l	d1,d0                   ;
	move.l	d0,part.size(a5)        ;

	rts

.last	dc.b	'Enter last sector:',0
	even

partedit.resize
	bsr.b	partedit.setsize
	bsr.w	partedit.warnosz
	restart

partedit.setsize
	bsr.w	parttool.pskip          ; Reset display

	move.l	part.last(a3),d0        ; Compute maximum size in MB
	sub.l	part.first(a5),d0       ;
	bsr.w	parttool.sec2mb         ;
	subq.l	#1,d0                   ;

	bsr.b	partedit.asksize        ; Ask for partition size

	loadpos	                        ; Reset cursor

.ok	flagset	pend                    ; Data altered
	move.l	d0,part.size(a5)        ;

	rts

partedit.asksize
	move.l	d0,-(sp)
	print	.size(pc)
	move.l	(sp)+,d0

	lea	bss+buf(pc),a0          ; Read size
	bsr.w	readint                 ;

	tst.l	d0                      ; If 0
	rtseq	                        ; Return effectively 0

	bra.w	parttool.mb2sec         ; Convert to sector count

.size	dc.b	'Size in MB:',0
	even

partedit.warnosz
	; Display a warning if oversize

	move.l	part.csize(a5),d0       ; Check csize
	cmp.l	part.size(a5),d0        ;

	bhi.b	.oversz
	rts

.oversz	bsr.w	parttool.pskip
	print	.oszwrn(pc)
	bsr.w	presskey
	loadpos
	rts

.oszwrn	dc.b	'Content may be bigger than partition',13,10,0
	even

partedit.refresh
	; Refresh display in the partition list

	movem.l	a3,-(sp)                ; Refresh this partition
	move.l	a5,a3                   ;
	bsr.w	parts.sensesz           ;
	movem.l	(sp)+,a3                ;

	bsr.w	parttool.ptable         ; Display refreshed partition table

	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
