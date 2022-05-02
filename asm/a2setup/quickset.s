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
; Quick setup tool

quickset
	; Input:
	;  a3: Buffer to containing partition descriptor
	;  a4: Buffer to partition table
	;  d7.b: ACSI id

	enter

	cls
	print	.ask(pc)
	bsr.w	areyousure
	exitne

	bsr.w	parts.newpt             ; Reset MBR

	; Create a single partition
	moveq	#32,d2                  ; d2 = start sector
	move.l	d2,part.start(a4)       ; Set partition start
	move.l	d2,part.first(a4)       ;

	move.l	part.size(a3),d0        ; Cap partition size to 256MB
	moveq	#8,d1                   ; to maximize compatibility
	swap	d1                      ;
	cmp.l	d1,d0                   ;
	bls.b	.small                  ;
	move.l	d1,d0                   ;
.small
	subq.l	#1,d0                   ;
	move.l	d0,part.last(a4)        ; Set partition last sector
	sub.l	d2,d0                   ;
	addq.l	#1,d0                   ;
	move.l	d0,part.size(a4)        ; Set partition size

	flagset	ok,(a4)                 ; Partition size is valid

	movem.l	a3/a5,-(sp)             ;

	lea	(a4),a5                 ; Auto format partition
	bsr.w	partfmt.auto            ;

	lea	(a4),a3                 ;
	bsr.w	parts.settype           ; Set MBR type:01 for FAT12,06 for FAT16

	movem.l	(sp)+,a3/a5             ;

	bsr.w	parts.save              ; Save MBR
	bne.w	parttool.err            ;

	exit

.ask	dc.b	'Quick setup',13,10,10
	dc.b	'This will wipe all data on the drive',13,10
	dc.b	10,0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
