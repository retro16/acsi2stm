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

	include	tui.s
	even
	include	acsicmd.s
	even
	include	ttstunit.s
	even
	include	tinquiry.s
	even
	include	trqsense.s
	even
	include	tmodsens.s
	even
	include	treadcap.s
	even
	include	tread.s
	even
	include	treadlng.s
	even
	include	tinvlun.s
	even
	include	terrsens.s
	even
	include	buftest.s
	even
	include	surftest.s
	even
	include	cmdtest.s
	even

main:
	move.l	sp,mainsp               ; Used for abort

	clr.l	success                 ; Reset variables in BSS
	clr.l	failed                  ;
	clr.l	blocks                  ;

	print	.header                 ; Welcome screen. Ask for a device

.devrq	gemdos	Cnecin,2                ; Read drive letter

	cmp.b	#$1b,d0                 ; Exit if pressed Esc
	beq	.exit                   ;

	sub.b	#'0',d0                 ; Transform to id
	and.w	#$00ff,d0               ;

	cmp.w	#7,d0                   ; Check if it is a valid letter
	bhi	.devrq                  ; Not a letter: try again

	lsl.w	#5,d0                   ; Store to d7
	move.w	d0,d7                   ;

	; Do the actual tests

	bsr	ttstunit
	bsr	tinquiry
	bsr	trqsense
	bsr	tmodsens
	bsr	treadcap
	bsr	tread
	bsr	treadlng
	bsr	tinvlun
	bsr	terrsens

	; End of tests
	print	.reslt1

	move.w	success,d0              ; Print successful tests count
	ext.l	d0                      ;
	moveq	#1,d1                   ;
	bsr	tui.puint               ;

	print	.reslt2

	move.w	failed,d0               ; Print failed tests count
	ext.l	d0                      ;
	moveq	#1,d1                   ;
	bsr	tui.puint               ;
	print	.reslt3                 ;

	gemdos	Cnecin,2                ; Wait for a key

	cmp.b	#'a',d0                 ; Transform to upper case
	blo.b	.ucase                  ;
	add.b	#'A'-'a',d0             ;

.ucase	cmp.b	#'S',d0                 ; Surface scan
	bne.b	.nsurf                  ;
	bsr	surftest                ;
	bra	main                    ;

.nsurf	cmp.b	#'B',d0                 ; DMA load test
	bne.b	.nbuft                  ;
	bsr	buftest                 ;
	bra	main                    ;

.nbuft	cmp.b	#'C',d0                 ; Command load test
	bne.b	.ncmdt                  ;
	bsr	cmdtest                 ;
	bra	main                    ;

.ncmdt	cmp.b	#'T',d0                 ; Go back to the beginning
	beq	main                    ;

.exit	rts

.header	dc.b	$1b,'E','ACSI device tester v'
	incbin	..\..\VERSION
	dc.b	$0d,$0a
	dc.b	'By Jean-Matthieu Coulon',$0d,$0a
	dc.b	'https://github.com/retro16/acsi2stm',$0d,$0a
	dc.b	'License: GPLv3',$0d,$0a
	dc.b	$0d,$0a
	dc.b	'Please input the ACSI device (0-7):',$0d,$0a
	dc.b	$1b,'e'
	dc.b	0

.reslt1	dc.b	$0d,$0a
	dc.b	'Test results:',$0d,$0a
	dc.b	'  ',0
.reslt2	dc.b	' successful tests',$0d,$0a
	dc.b	'  ',0
.reslt3	dc.b	' failed tests',$0d,$0a
	dc.b	$0d,$0a
	dc.b	'Press B for buffer load test,',$0d,$0a
	dc.b	'      C for command load test,',$0d,$0a
	dc.b	'      S for surface scan test,',$0d,$0a
	dc.b	'      T to restart basic test,',$0d,$0a
	dc.b	'or any other key to exit.',$0d,$0a
	dc.b	$0a
	dc.b	0

	even

testok:
	move.l	mainsp,sp               ; Adjust stack for the test return addr
	subq	#4,sp                   ;

	add.w	#1,success              ; Success counter

	rts

testfailed:
	move.l	mainsp,sp               ; Adjust stack for the test return addr
	subq	#4,sp                   ;

	add.w	#1,failed               ; Increment failure counter
	print	(a5)                    ; Print error message
	print	.fail                   ;

	rts

.fail	dc.b	' -> failed',$0d,$0a
	dc.b	$0a
	dc.b	0

	even

abort:
	move.l	mainsp,sp               ; Restore main stack pointer
	print	(a5)                    ; Print error message
	print	aborted                 ;
	gemdos	Cnecin,2                ; Wait for a key
	rts	                        ; Exit from main

aborted	dc.b	$0d,$0a,7,'Program aborted',$0d,$0a
eos	dc.b	0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
