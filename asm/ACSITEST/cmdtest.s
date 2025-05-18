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

; Test lots of "Test unit ready" commands with the worst case at DMA port level

cmdtest:
	print	.desc

.loop	moveq	#39,d3                  ; Send grouped by 40
	moveq	#0,d4                   ; Reset error flag

.pass	gemdos	Cconis,2                ; Exit if a key was pressed
	tst.l	d0                      ;
	bne	.exit                   ;

	move.w	#$01ff,d0               ; Send command with data on the bus
	move.l	#.ffdata,d1             ;
	lea	.cmd,a0                 ;
	bsr	acsicmd                 ;

	tst.b	d0                      ; Check write result
	beq.b	.nerr                   ;
	bsr	.perr                   ;
.nerr
	dbra	d3,.pass                ;

	tst.w	d4                      ; Next line only if it failed
	beq	.loop                   ;
	crlf	                        ;
	bra	.loop                   ;

.perr	pchar	'X'                     ; Fill the line with an X
	moveq	#1,d4                   ; Toggle error flag
	rts	                        ;

.exit	gemdos	Cnecin,2                ; Flush keyboard buffer
	crlf	                        ;
	rts	                        ;

.desc	dc.b	'Command load test.Press any key to exit.',$0d,$0a
	dc.b	0

.cmd	dc.b	3,$00,$00,$00,$00,$00,$00

	even
.ffdata	dc.b	$ffffffff

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
