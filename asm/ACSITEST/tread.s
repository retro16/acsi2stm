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

; Test the "read" command in normal conditions

tread:
	print	.desc

	lea	buffer,a0               ; Fill 516 bytes with 0 in buffer
	move.w	#128,d0                 ;
.zfill	clr.l	(a0)+                   ;
	dbra	d0,.zfill               ;

	lea	buffer+1020,a0          ; Fill 516 bytes with $ff in buffer+1024
	move.w	#129,d0                 ;
.fffill	move.l	#$deadc0de,(a0)+        ;
	dbra	d0,.fffill              ;

	move.l	#buffer,d1              ; Read block 0 into the first buffer
	bsr	.read                   ;

	move.l	#buffer+1024,d1         ; Read block 0 into the second buffer
	bsr	.read                   ;

	lea	.overwr,a5              ; Check buffer overwrite
	tst.l	buffer+512              ; Check after the first buffer
	bne	testfailed              ;
	cmp.l	#$deadc0de,buffer+1020  ; Check before the second buffer
	bne	testfailed              ;
	cmp.l	#$deadc0de,buffer+1536  ; Check after the second buffer
	bne	testfailed              ;

	lea	.differ,a5              ; Compare both buffers
	lea	buffer,a0               ;
	lea	buffer+1024,a1          ;
	move.w	#127,d0                 ;
.blkcmp	cmp.l	(a0)+,(a1)+             ;
	bne	testfailed              ;
	dbra	d0,.blkcmp              ;

	bra	testok

.read	move.w	#$000f,d0               ; Read 1 block at address 0
	lea	.cmd,a0                 ;
	bsr	acsicmd                 ;

	lea	.failed,a5              ;
	tst.b	d0                      ;
	bne	testfailed              ;

	rts


.desc	dc.b	'Test read in normal conditions',$0d,$0a
	dc.b	0

.failed	dc.b	'Command failed',$0d,$0a
	dc.b	0

.overwr	dc.b	'Overwrite at the end of the buffer',$0d,$0a
	dc.b	0

.differ	dc.b	'Reading twice gave different results',$0d,$0a
	dc.b	0

.cmd	dc.b	3
	dc.b	$08,$00,$00,$00,$01,$00

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
