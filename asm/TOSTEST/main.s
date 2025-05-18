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

	; Include all tests
	include	tdsetdrv.s
	include	tdsetpth.s
	include	tdcreate.s
	include	tfcropen.s
	include	tfileio.s
	include	tfilecpy.s
	include	tfrename.s
	include	tfattrib.s
	include	tfdatime.s
	include	tfsfirst.s
	include	tpexec.s
	include	tmx.s

	include	tui.s

main:
	move.l	sp,mainsp               ; Used for abort

	gemdos	Dgetdrv,2               ; Get startup drive
	move.w	d0,strtdrv              ; Store startup drive
	move.w	d0,-(sp)                ;
	gemdos	Dsetdrv,4               ;
	move.l	d0,drvmask              ; Store drive mask

	move.w	strtdrv,d0              ; Get startup path
	add.w	#'A',d0                 ;
	move.b	d0,exepath              ;
	move.b	#':',exepath+1          ;
	clr.w	-(sp)                   ;
	pea	exepath+2               ;
	gemdos	Dgetpath,8              ;

	lea	exepath+2,a0            ; Append executable name
	tst.b	(a0)                    ;
	bne.b	.nempat                 ;
	move.b	#'\',(a0)+              ;
	clr.b	(a0)                    ;
.nempat	tst.b	(a0)                    ;
	lea	1(a0),a0                ;
	bne.b	.nempat                 ;
	lea	-1(a0),a0               ;
	cmp.b	#'\',-1(a0)             ;
	beq.b	.execat                 ;
	move.b	#'\',(a0)+              ;
.execat	lea	.exefil,a1              ;
.execpy	move.b	(a1)+,(a0)+             ;
	bne.b	.execpy                 ;

	print	.welcom                 ; Welcome screen

	print	.expth                  ; Print startup path
	print	exepath                 ;
	crlf	                        ;
	crlf	                        ;

	print	.drvlrq                 ; Welcome screen. Ask for a drive letter
	bsr	.ltrq                   ;
	move.w	d0,drive                ; Store wanted drive letter
	crlf	                        ;

	; Do the actual tests
	bsr	tdsetdrv
	bsr	tdsetpth
	bsr	tdcreate
	bsr	tfcropen
	bsr	tfileio
	bsr	tfilecpy
	bsr	tfrename
	bsr	tfattrib
	bsr	tfdatime
	bsr	tfsfirst
	bsr	tpexec
	bsr	tmx                     ; The final boss: test matrix

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

	rts

.ltrq	gemdos	Cnecin,2                ; Read drive letter

	cmp.b	#$1b,d0                 ; Exit if pressed Esc
	beq	exit                    ;

.nesc	cmp.b	#'a',d0                 ; Change to upper case
	bmi.b	.upper                  ;
	add.b	#'A'-'a',d0             ;

.upper	lea	abspath,a0              ; Patch absolute paths with drive letter
.absnxt	move.l	(a0)+,d1                ;
	beq.b	.absend                 ;
	move.l	d1,a1                   ;
	move.b	d0,(a1)                 ;
	bra.b	.absnxt                 ;
.absend		                        ;

	sub.b	#'A',d0                 ; Transform to id
	and.w	#$00ff,d0               ;

	cmp.w	#26,d0                  ; Check if it is a valid letter
	bhi	.ltrq                   ; Not a letter: try again

	move.l	drvmask,d1              ; Check if the drive actually exists
	btst	d0,d1                   ;
	beq	.ltrq                   ;

	move.w	d0,-(sp)                ; Temp storage
	add.b	#'A',d0                 ; Print selected drive letter
	move.w	d0,-(sp)                ;
	print	.usedr1                 ;
	gemdos	Cconout,4               ;
	print	.usedr2                 ;
	move.w	(sp)+,d0                ; Restore d0

	rts	                        ; Success

.welcom	dc.b	$1b,'E','GEMDOS file functions tester v'
	incbin	..\..\VERSION
	dc.b	$0d,$0a
	dc.b	'By Jean-Matthieu Coulon',$0d,$0a
	dc.b	'https://github.com/retro16/acsi2stm',$0d,$0a
	dc.b	'License: GPLv3',$0d,$0a
	dc.b	$0d,$0a
	dc.b	'Tests file system functions on a drive.',$0d,$0a
	dc.b	$0d,$0a
	dc.b	0

.drvlrq	dc.b	'Please input the drive letter to test:',$0d,$0a
	dc.b	$1b,'e'
	dc.b	0

.usedr1	dc.b	$1b,'f','Using drive ',0
.usedr2	dc.b	':',$0d,$0a,$0a
	dc.b	0

.expth	dc.b	'Test executable path: ',0

.reslt1	dc.b	'________________________________________',$0d,$0a,$0a
	dc.b	'Test results:',$0d,$0a,$0a
	dc.b	'  ',0
.reslt2	dc.b	' successful tests',$0d,$0a
	dc.b	'  ',0
.reslt3	dc.b	' failed tests',$0d,$0a
	dc.b	0

.exefil	dc.b	'TOSTEST.TOS',0

	even

clrbuf	; Clear the buffer
	moveq	#0,d0
	; Fall through fillbuf

fillbuf	; Fill the buffer with a long word pattern in d0
	lea	buffer,a0
	move.w	#65536/4,d1
.clr	move.l	d0,(a0)+
	dbra	d1,.clr
	rts

testok:
	move.l	mainsp,sp               ; Adjust stack for the test return addr
	subq	#4,sp                   ;

	add.w	#1,success              ; Success counter
	print	.succss                 ; Print result

	rts

.succss	dc.b	' -> successful',$0d,$0a
	dc.b	$0a
	dc.b	0

	even

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

exit:	move.l	mainsp,sp
	rts

abort:
	move.l	mainsp,sp               ; Restore main stack pointer
	print	(a5)                    ; Print error message
	print	.abort                  ;
	gemdos	Cnecin,2                ; Wait for a key
	rts	                        ; Exit from main

.abort	dc.b	$0d,$0a,7,'Program aborted',$0d,$0a
	dc.b	0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
