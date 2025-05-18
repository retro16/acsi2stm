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

; Tests the "test unit ready" command

ttstunit:
	print	.desc

	moveq	#0,d0                   ; Send command without DMA
	moveq	#0,d1                   ;
	lea	.cmd,a0                 ;
	bsr	acsicmd                 ;

	lea	.failed,a5              ;
	tst.b	d0                      ; Check that the command is successful
	bne	testfailed              ;

	bra	testok                  ;


.desc	dc.b	'Test unit ready',$0d,$0a
	dc.b	0

.failed	dc.b	'Did not return expected code 0',$0d,$0a
	dc.b	0

.cmd	dc.b	3,$00,$00,$00,$00,$00,$00

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
