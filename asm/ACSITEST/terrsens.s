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

; Test error sense and CHECK CONDITION behavior

terrsens:
	print	.desc

	moveq	#0,d0                   ; Request rewind, which makes no sense
	lea	.rwncmd,a0              ;
	bsr	acsicmd.sense           ;

	lea	.succss,a5              ; Check that the command has failed
	cmp.l	#$00200502,d0           ; with the correct code
	bne	testfailed              ;

	moveq	#0,d0                   ; Test if ready
	lea	.tcmd,a0                ;
	bsr	acsicmd                 ;

	lea	.nreset,a5              ; Check that the flag was reset
	tst.b	d0                      ;
	bne	testfailed              ;

	moveq	#0,d0                   ; Request rewind, do not request sense
	lea	.rwncmd,a0              ;
	bsr	acsicmd                 ;

	lea	.nset,a5                ; CHECK CONDITION should have been
	cmp.b	#$02,d0                 ; returned
	bne	testfailed              ;

	moveq	#0,d0                   ; Test unit ready with a CHECK CONDITION
	lea	.tcmd,a0                ; flag already set
	bsr	acsicmd.sense           ;

	lea	.nreset,a5              ; CHECK CONDITION should have been
	tst.l	d0                      ; reset by test unit ready
	bne	testfailed              ;

	bra	testok                  ;


.desc	dc.b	'Test CHECK CONDITION flag behavior',$0d,$0a
	dc.b	0

.succss	dc.b	'Did not return any error, but should',$0d,$0a
	dc.b	0

.nset	dc.b	'Flag was not set correctly',$0d,$0a
	dc.b	0

.nreset	dc.b	'Flag did not reset',$0d,$0a
	dc.b	0

.rwncmd	dc.b	3                       ; Rewind command: invalid for hard disks
	dc.b	$01,$02,$03,$04,$05,$06 ;

.tcmd	dc.b	3                       ; Test unit ready
	dc.b	$00,$00,$00,$00,$00,$00 ;

.rqcmd	dc.b	3                       ; Request sense command
	dc.b	$03,$00,$00,$00,$12,$00 ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
