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

; Tests the "inquiry" command

tinquiry:
	print	.desc

	move.w	#$0001,d0               ;
	move.l	#buffer,d1              ;
	lea	.cmd,a0                 ;
	bsr	acsicmd                 ;

	lea	.failed,a5              ;
	tst.b	d0                      ; Check that the command is successful
	bne	testfailed              ;

	print	.rmb1                   ; Print if removable
	btst	#7,buffer+1             ;
	bne.b	.isrmb                  ;
	print	.rmb2n                  ;
.isrmb	print	.rmb3                   ;

	cmp.b	#27,buffer+4            ; Check if the device returns product id
	blo	testok                  ;

	print	.devstr                 ; Print product ID
	move.l	buffer+32,buffer+36     ; Move version away to make room for the
	clr.b	buffer+32               ; string terminator
	print	buffer+8                ;
	crlf	                        ;

	cmp.b	#31,buffer+4            ; Check if the device returns version
	blo	testok                  ;

	clr.b	buffer+40               ; Terminate version
	print	.devver                 ;
	print	buffer+36               ;
	crlf	                        ;

	bra	testok                  ;


.desc	dc.b	'Test inquiry',$0d,$0a
	dc.b	0

.failed	dc.b	'Did not return expected code 0',$0d,$0a
	dc.b	0

.devstr	dc.b	'Device string:',$0d,$0a
	dc.b	0

.devver	dc.b	'Revision: ',0

.rmb1	dc.b	'Medium is ',0
.rmb2n	dc.b	'not ',0
.rmb3	dc.b	'removable',$0d,$0a
	dc.b	0

.cmd	dc.b	3,$12,$00,$00,$00,$ff,$00

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
