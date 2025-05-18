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

; Tests the "read capacity" command to fetch drive size

treadcap:
	print	.desc

	move.w	#$0001,d0               ; Request device size
	move.l	#buffer,d1              ;
	lea	.cmd,a0                 ;
	bsr	acsicmd.flush           ;

	lea	.failed,a5              ;
	tst.b	d0                      ; Check that the command is successful
	bne	testfailed              ;

	lea	buffer,a0

	lea	.invsc,a5               ; Check sector count
	move.l	(a0),blocks             ;
	beq	testfailed              ;

	lea	.invss,a5               ; Check sector size
	cmp.l	#$00000200,4(a0)        ;
	bne	testfailed              ;

	bra	testok


.desc	dc.b	'Test read capacity in normal conditions',$0d,$0a
	dc.b	0

.failed	dc.b	'Command failed',$0d,$0a
	dc.b	0

.invsc	dc.b	'Invalid sector count',$0d,$0a
	dc.b	0

.invss	dc.b	'Invalid sector size',$0d,$0a
	dc.b	0

.cmd	dc.b	8                       ; Read capacity command
	dc.b	$1f                     ; Extended command
	dc.b	$25,$00,$00,$00,$00     ;
	dc.b	$00,$00,$00,$00,$00     ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
