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

; Test commands with invalid LUN

tinvlun:
	print	.rdesc

	move.l	#$bad5eed,buffer        ; Buffer marker

	move.w	#$0001,d0               ; Request read with
	move.l	#buffer,d1              ; wrong LUN
	lea	.rdcmd,a0               ;
	bsr	acsicmd.sense           ;

	lea	.timout,a5              ; Check for timeout
	cmp.l	#-1,d0                  ;
	beq	testfailed              ;

	lea	.failed,a5              ;
	cmp.l	#$00250502,d0           ; Check that the command has failed LUN
	bne	testfailed              ;

	cmp.l	#$bad5eed,buffer        ; Check buffer marker
	bne	testfailed              ;

	print	.mdesc

	move.w	#$0001,d0               ; Mode sense with wrong LUN
	move.l	#buffer,d1              ;
	lea	.mscmd,a0               ;
	bsr	acsicmd.sense           ;

	lea	.failed,a5              ;
	cmp.l	#$00250502,d0           ; Check that the command has failed LUN
	bne	testfailed              ;

	cmp.l	#$bad5eed,buffer        ; Check buffer marker
	bne	testfailed              ;

	bra	testok                  ;


.rdesc	dc.b	'Test read with invalid LUN',$0d,$0a
	dc.b	0

.mdesc	dc.b	'Test mode sense with invalid LUN',$0d,$0a
	dc.b	0

.failed	dc.b	'Command failed',$0d,$0a
	dc.b	0

.timout	dc.b	'Timed out',$0d,$0a
	dc.b	0

.rdcmd	dc.b	3                       ; Read boot sector command on LUN 7
	dc.b	$08,$e0,$00,$00,$01,$00 ;

.mscmd	dc.b	3                       ; Mode sense command on LUN 7
	dc.b	$1a,$e0,$3f,$00,$ff,$00 ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
