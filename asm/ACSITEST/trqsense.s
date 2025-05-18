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

; Tests the "request sense" command

trqsense:
	print	.desc

	move.w	#$0001,d0               ; Request sense
	move.l	#buffer,d1              ;
	lea	.cmd,a0                 ;
	bsr	acsicmd.flush           ;

	lea	.failed,a5              ;
	tst.b	d0                      ; Check that the command is successful
	bne	testfailed              ;

	lea	buffer,a0               ; Analyze data

	lea	.invcod,a5              ; Analyze response code
	move.b	(a0),d0                 ;
	bclr	#7,d0                   ;
	cmp.b	#$70,d0                 ;
	bne	testfailed              ;

	lea	.reterr,a5              ;

	move.b	2(a0),d0                ; Check sense key (must be successful)
	and.b	#$0f,d0                 ;
	bne	testfailed              ;

	cmp.b	#4,7(a0)                ; Check ASC
	bls	testok                  ;
	tst.b	12(a0)                  ;
	bne	testfailed              ;

	cmp.b	#5,7(a0)                ; Check ASCQ
	bls	testok                  ;
	tst.b	13(a0)                  ;
	bne	testfailed              ;

	bra	testok                  ;


.desc	dc.b	'Test request sense in normal conditions',$0d,$0a
	dc.b	0

.failed	dc.b	'Command failed',$0d,$0a
	dc.b	0

.invcod	dc.b	'Did not return expected code $70',$0d,$0a
	dc.b	0

.reterr	dc.b	'SENSE returned a non-zero error',$0d,$0a
	dc.b	0

.cmd	dc.b	3                       ; Request sense command
	dc.b	$03,$00,$00,$00,$12,$00 ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
