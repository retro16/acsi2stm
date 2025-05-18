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

; Tests Gsetdrv on an unknown drive

tdsetdrv:
	print	.desc

	move.l	drvmask,d0              ; Load drive mask

	lea	.nfree,a5               ; Search for a non-existing drive
	moveq	#2,d1                   ;
.nxtdrv	btst	d1,d0                   ;
	beq.b	.drvok                  ;
	addq	#1,d1                   ;

	cmp.w	#26,d1                  ; Test if out of letters
	bhs	testfailed              ;

	bra	.nxtdrv                 ;

.drvok	move.w	d1,-(sp)                ; Try to switch to the non-existing
	gemdos	Dsetdrv,4               ; drive

	lea	.reterr,a5              ; Check return values

	cmp.l	drvmask,d0              ; TOS must return drive mask in any case
	bne	testfailed              ;

	move.w	drive,-(sp)             ; Switch back to test drive
	gemdos	Dsetdrv,4               ;

	cmp.l	drvmask,d0              ; TOS must return drive mask in any case
	bne	testfailed              ;

	bra	testok                  ; Test successful

.desc	dc.b	'Test Dsetdrv',$0d,$0a
	dc.b	0

.nfree	dc.b	7,'No free drive letter found',$0d,$0a
	dc.b	0

.reterr	dc.b	'Dsetdrv returned an error.',$0d,$0a
	dc.b	'Should return a drive mask',$0d,$0a
	dc.b	0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
