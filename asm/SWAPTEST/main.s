; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2023 by Jean-Matthieu Coulon

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
	include	setup.s
	even
	include	test.s
	even

main:
	print	.header                 ; Print program header

	print	.drvlrq                 ; Ask for a drive letter
	bsr	.ltrq                   ;
	move.w	d0,-(sp)                ; Set as current drive
	gemdos	Dsetdrv,4               ;

	clr.l	success                 ; Reset variables in BSS
	clr.l	failed                  ;
	lea	expectd,a5              ; a5 = expected result stream

	; Start tests

	bsr	ask2                    ; Setup disk 2
	bsr	clean                   ;
	bsr	setup2                  ;

	bsr	ask1                    ; Blank test on disk 1
	bsr	clean                   ;
	bsr	setup1                  ;
	bsr	test                    ;

	bsr	clean                   ; Test swapping disk 1 to disk 2
	bsr	setup1                  ;
	bsr	ask2                    ;
	bsr	test                    ;
	bsr	clean                   ;

	bsr	ask1                    ; Test ejecting disk 1
	bsr	clean                   ;
	bsr	setup1                  ;
	bsr	askejct                 ;
	bsr	test                    ;

	bsr	ask1                    ; Cleanup disk 1
	bsr	clean                   ;

	; End of tests

	print	.reslt1                 ; Print successful tests count
	move.w	success,d0              ;
	ext.l	d0                      ;
	moveq	#1,d1                   ;
	bsr	tui.puint               ;

	print	.reslt2                 ; Print failed tests count
	move.w	failed,d0               ;
	ext.l	d0                      ;
	moveq	#1,d1                   ;
	bsr	tui.puint               ;
	print	.reslt3                 ;

	gemdos	Cnecin,2                ; Wait for a key

	rts

.ltrq	gemdos	Cnecin,2                ; Read drive letter

	cmp.b	#$1b,d0                 ; Exit if pressed Esc
	beq	.exit                   ;

.nesc	cmp.b	#'a',d0                 ; Change to upper case
	bmi.b	.upper                  ;
	add.b	#'A'-'a',d0             ;

.upper	sub.b	#'A',d0                 ; Transform to id
	and.w	#$00ff,d0               ;

	cmp.w	#26,d0                  ; Check if it is a valid letter
	bhi	.ltrq                   ; Not a letter: try again

	move.w	d0,-(sp)                ; Temp storage
	add.b	#'A',d0                 ; Print selected drive letter
	move.w	d0,-(sp)                ;
	print	.usedr1                 ;
	gemdos	Cconout,4               ;
	print	.usedr2                 ;
	move.w	(sp)+,d0                ; Restore d0

	rts	                        ; Success

.exit	Pterm0                          ; Exit program

.header	dc.b	$1b,'E','Disk swap TOS tester v'
	incbin	..\..\VERSION
	dc.b	$0d,'by Jean-Matthieu Coulon',$0d,$0a
	dc.b	'https://github.com/retro16/acsi2stm',$0d,$0a
	dc.b	'License: GPLv3',$0d,$0a
	dc.b	$0a
	dc.b	'This program requires 2 disks labeled',$0d,$0a
	dc.b	'disk 1 and disk 2. The disks must be',$0d,$0a
	dc.b	'formated independently (different serial',$0d,$0a
	dc.b	'numbers).',$0d,$0a
	dc.b	$0a
	dc.b	0

.drvlrq	dc.b	'Please input the drive letter to test:',$0d,$0a
	dc.b	$1b,'e'
	dc.b	0

.usedr1	dc.b	$1b,'f','Using drive ',0
.usedr2	dc.b	':',$0d,$0a
	dc.b	$0a
	dc.b	0

.reslt1	dc.b	'________________________________________',$0d,$0a,$0a
	dc.b	'Test results:',$0d,$0a,$0a
	dc.b	'  ',0
.reslt2	dc.b	' successful tests',$0d,$0a
	dc.b	'  ',0
.reslt3	dc.b	' failed tests',$0d,$0a
	dc.b	0
	
	even

abort	print	.abortd                 ; Print error message
	gemdos	Cnecin,2                ; Wait for a key
	Pterm0	                        ; Exit
.abortd	dc.b	'Aborted',$0d,$0a
	dc.b	0
	even

ask1	pea	.askdr1
	bra	askdrv
.askdr1	dc.b	'Please insert disk 1 then press any key',$0d,$0a
	dc.b	0
	even

ask2	pea	.askdr2
	bra	askdrv
.askdr2	dc.b	'Please insert disk 2 then press any key',$0d,$0a
	dc.b	0
	even

askejct	pea	.askej
	bra	askdrv
.askej	dc.b	'Please eject disk then press any key',$0d,$0a
	dc.b	0
	even

askdrv	gemdos	Cconws,6                ; Print message
	gemdos	Cnecin,2                ; Wait for a key
	rts	                        ; and that's it

expectd	; Expected results for all tests

	; disk 1 -> disk 1 (no swap) - File descriptor tests
	dc.l	EACCDN,1,1              ; Write 1 byte
	dc.l	1,1,0                   ; Read 1 byte
	dc.l	0,0,0                   ; Close file descriptor
	dc.l	1,1,1                   ; Seek at offset 1
	dc.l	ERANGE,ERANGE,ERANGE    ; Seek at offset 2

	dc.l	0,EACCDN                ; Delete,create path 1
	dc.l	EPTHNF,0                ; Delete,create path 2
	dc.l	0,EACCDN                ; Delete,create path 3

	; disk 1 -> disk 2 - File descriptor tests
	dc.l	EACCDN,EACCDN,EACCDN    ; Write 1 byte
	dc.l	EACCDN,EACCDN,EACCDN    ; Read 1 byte
	dc.l	0,0,0                   ; Close file descriptor
	dc.l	EACCDN,EACCDN,EACCDN    ; Seek at offset 1
	dc.l	EACCDN,EACCDN,EACCDN    ; Seek at offset 2

	dc.l	EPTHNF,EPTHNF           ; Delete,create path 1
	dc.l	EPTHNF,EPTHNF           ; Delete,create path 2
	dc.l	EPTHNF,EPTHNF           ; Delete,create path 3

	; disk 1 -> ejected - File descriptor tests
	dc.l	EACCDN,EACCDN,EACCDN    ; Write 1 byte
	dc.l	EACCDN,EACCDN,EACCDN    ; Read 1 byte
	dc.l	0,0,0                   ; Close file descriptor
	dc.l	EACCDN,EACCDN,EACCDN    ; Seek at offset 1
	dc.l	EACCDN,EACCDN,EACCDN    ; Seek at offset 2

	dc.l	EACCDN,EACCDN           ; Delete,create path 1
	dc.l	EACCDN,EACCDN           ; Delete,create path 2
	dc.l	EACCDN,EACCDN           ; Delete,create path 3

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
