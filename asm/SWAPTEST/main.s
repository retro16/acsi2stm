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

main:
	print	header                  ;

	print	drvlrq                  ; Ask for a drive letter
	bsr	ltrq                    ;
	move.w	d0,-(sp)                ; Set as current drive
	gemdos	Dsetdrv,4               ;

	; Cleanup everything before starting
	bsr	ask2                    ;
	bsr	cleanup                 ;
	bsr	ask1                    ;
	bsr	cleanup                 ;

	lea	results,a3              ; a3 = Expected result codes

	; Phase 1: test without swapping
	print	phase1                  ;
	bsr	create                  ;
	bsr	open                    ;
	bsr	askejct                 ; Eject and reinsert medium
	bsr	ask1                    ;
	bsr	test                    ;
	bsr	cleanup                 ;

	; Phase 2: test with swapping
	bsr	ask2                    ;
	bsr	create                  ;
	bsr	ask1                    ;
	bsr	create                  ;
	bsr	open                    ;
	bsr	ask2                    ;
	bsr	test                    ;
	bsr	cleanup                 ;
	bsr	ask1                    ;
	bsr	cleanup                 ;

	; Phase 3: test with eject
	bsr	create                  ;
	bsr	open                    ;
	bsr	askejct                 ;
	bsr	test                    ;
	bsr	ask1                    ;
	bsr	cleanup                 ;

	print	finishd                 ;
	bsr	waitkey                 ;
exitnow	Pterm0                          ; Exit program

test:
	print	tsstart                 ;

	print	tfread                  ; Test Fread
	pea	buffer                  ;
	move.l	#1,-(sp)                ;
	move.w	fdread,-(sp)            ;
	gemdos	Fread,12                ;
	bsr	testeq                  ;

	print	tfclose                 ; Close
	move.w	fdread,-(sp)            ;
	gemdos	Fclose,4                ;
	bsr	testeq                  ;

	print	tfseek1                 ; Test Fseek inside file
	clr.w	-(sp)                   ;
	move.w	fdseek1,-(sp)           ;
	move.l	#1,-(sp)                ;
	gemdos	Fseek,10                ;
	bsr	testeq                  ;

	print	tfclose                 ; Close
	move.w	fdseek1,-(sp)           ;
	gemdos	Fclose,4                ;
	bsr	testeq                  ;

	print	tfseek2                 ; Test Fseek outside file
	clr.w	-(sp)                   ;
	move.w	fdseek2,-(sp)           ;
	move.l	#2,-(sp)                ;
	gemdos	Fseek,10                ;
	bsr	testeq                  ;

	print	tfclose                 ; Close
	move.w	fdseek2,-(sp)           ;
	gemdos	Fclose,4                ;
	bsr	testeq                  ;

	print	tfwrite                 ; Test Fwrite
	pea	buffer                  ;
	move.l	#1,-(sp)                ;
	move.w	fdwri,-(sp)             ;
	gemdos	Fwrite,12               ;
	bsr	testeq                  ;

	print	tfclose                 ; Close
	move.w	fdwri,-(sp)             ;
	gemdos	Fclose,4                ;
	bsr	testeq                  ;

	print	tfclose                 ; Write, swap, close
	move.w	fdwpend,-(sp)           ;
	gemdos	Fclose,4                ;
	bsr	testeq                  ;

	print	tsok                    ;

	rts	                        ;

testok:
	print	tsucces                 ;
	rts	                        ;

testeq:
	move.l	(a3)+,d1                ;
	cmp.l	d0,d1                   ;
	beq	testok                  ;

	move.l	d0,-(sp)                ;
	move.l	d1,-(sp)                ;

	print	.wrong                  ; Wrong result
	move.l	(sp)+,d0                ;
	bsr	tui.phlong              ; Print expected value
	print	.got                    ;
	move.l	(sp)+,d0                ;
	bsr	tui.phlong              ; Print returned value

	print	.cont                   ;
	bra	waitkey                 ;

.wrong	dc.b	' KO.',$07,$0d,$0a      ;
	dc.b	'Expected:',0           ;
.got	dc.b	' Got:',0               ;
.cont	dc.b	$0d,$0a,0               ;
	even

cleanup:
	print	clstart                 ;

	pea	rootdir                 ;
	gemdos	Dsetpath,6              ;
	pea	topdir                  ; Go into SWAPTEST.TMP
	gemdos	Dsetpath,6              ;
	tst.l	d0                      ;
	bne	.notop                  ;

	pea	fnread                  ; Delete READ.FIL
	gemdos	Fdelete,6               ;

	pea	fnwrite                 ; Delete WRITE.FIL
	gemdos	Fdelete,6               ;

	pea	fnwpend                 ; Delete WRITPEND.FIL
	gemdos	Fdelete,6               ;

.notop	pea	rootdir                 ; Go back to top directory
	gemdos	Dsetpath,6              ;

	pea	topdir                  ; Delete SWAPTEST.TMP
	gemdos	Ddelete,6               ;

	print	clok                    ;

	rts	                        ;

create:
	print	crstart                 ;

	print	topdir                  ;
	crlf	                        ;

	pea	rootdir                 ; Create topdir
	gemdos	Dsetpath,6              ;
	pea	topdir                  ;
	gemdos	Dcreate,6               ;
	bsr	.chkerr                 ;

	pea	topdir                  ; Go into the \SWAPTEST.TMP directory
	gemdos	Dsetpath,6              ;
	bsr	.chkerr                 ;

	print	fnread                  ;
	crlf	                        ;

	clr.w	-(sp)                   ; Default attributes
	pea	fnread                  ; Create READ.FIL
	gemdos	Fcreate,8               ;
	bsr	.chkerr                 ;
	move.w	d0,d3                   ; d3 = file descriptor

	pea	buffer                  ; Write 1 byte into the file
	move.l	#1,-(sp)                ;
	move.w	d3,-(sp)                ;
	gemdos	Fwrite,12               ;
	bsr	.chkerr                 ;

	move.w	d3,-(sp)                ; Close READ.FIL
	gemdos	Fclose,4                ;
	bsr	.chkerr                 ;

	print	fnwrite                 ;
	crlf	                        ;

	clr.w	-(sp)                   ; Default attributes
	pea	fnwrite                 ; Create WRITE.FIL
	gemdos	Fcreate,8               ;
	bsr	.chkerr                 ;

	move.w	d0,-(sp)                ; Close WRITE.FIL
	gemdos	Fclose,4                ;
	bsr	.chkerr                 ;

	print	fnwpend                 ;
	crlf	                        ;

	clr.w	-(sp)                   ; Default attributes
	pea	fnwpend                 ; Create WRITPEND.FIL
	gemdos	Fcreate,8               ;
	bsr	.chkerr                 ;

	move.w	d0,-(sp)                ; Close WRITPEND.FIL
	gemdos	Fclose,4                ;
	bsr	.chkerr                 ;

	print	crok                    ;

	rts	                        ;

.chkerr	tst.l	d0                      ;
	bmi	.err                    ;
	rts	                        ;

.err	print	crerr                   ;
	bsr	waitkey                 ;
	Pterm0                          ;

open:
	print	opstart                 ;

	print	fnread                  ;
	crlf	                        ;

	clr.w	-(sp)                   ; Open READ.FIL for read
	pea	fnread                  ;
	gemdos	Fopen,8                 ;
	bsr	.chkerr                 ;
	move.w	d0,fdread               ;

	clr.w	-(sp)                   ; Open READ.FIL for seek 1
	pea	fnread                  ;
	gemdos	Fopen,8                 ;
	bsr	.chkerr                 ;
	move.w	d0,fdseek1              ;

	clr.w	-(sp)                   ; Open READ.FIL for seek 2
	pea	fnread                  ;
	gemdos	Fopen,8                 ;
	bsr	.chkerr                 ;
	move.w	d0,fdseek2              ;

	print	fnwrite                 ;
	crlf	                        ;

	move.w	#1,-(sp)                ; Open WRITE.FIL
	pea	fnwrite                 ;
	gemdos	Fopen,8                 ;
	bsr	.chkerr                 ;
	move.w	d0,fdwri                ;

	print	fnwpend                 ;
	crlf	                        ;

	move.w	#1,-(sp)                ; Open WRITPEND.FIL
	pea	fnwpend                 ;
	gemdos	Fopen,8                 ;
	bsr	.chkerr                 ;
	move.w	d0,fdwpend              ;

	print	opok                    ;

	rts	                        ;

.chkerr	tst.l	d0                      ;
	bmi	.err                    ;
	rts	                        ;

.err	print	openerr                 ;
	bra	waitkey                 ;

ltrq:
	gemdos	Cnecin,2                ; Read drive letter

	cmp.b	#$1b,d0                 ; Exit if pressed Esc
	beq	exitnow                 ;

.nesc	cmp.b	#'a',d0                 ; Change to upper case
	bmi.b	.upper                  ;
	add.b	#'A'-'a',d0             ;

.upper	sub.b	#'A',d0                 ; Transform to id
	and.w	#$00ff,d0               ;

	cmp.w	#26,d0                  ; Check if it is a valid letter
	bhi	ltrq                    ; Not a letter: try again

	move.w	d0,-(sp)                ; Temp storage
	add.b	#'A',d0                 ; Print selected drive letter
	move.w	d0,-(sp)                ;
	print	usedr1                  ;
	gemdos	Cconout,4               ;
	print	usedr2                  ;
	move.w	(sp)+,d0                ; Restore d0

	rts	                        ; Success

ask1:
	print	.askdr1
	bra	waitkey
.askdr1	dc.b	'Please insert disk 1 then press any key',$0d,$0a
	dc.b	0
	even

ask2:
	print	.askdr2
	bra	waitkey
.askdr2	dc.b	'Please insert disk 2 then press any key',$0d,$0a
	dc.b	0
	even

askejct:
	print	.askej
	bra	waitkey
.askej	dc.b	'Please eject disk then press any key',$0d,$0a
	dc.b	0
	even

waitkey:
	gemdos	Cnecin,2                ; Wait for a key
	rts	                        ; and that's it

results:
	; Phase 1
	dc.l	$00000001,E_OK          ; Fread,Fclose
	dc.l	$00000001,E_OK          ; Fseek1,Fclose
	dc.l	ERANGE,E_OK             ; Fseek2,Fclose
	dc.l	$00000001,E_OK          ; Fwrite
	dc.l	E_OK                    ; Fclose

	; Phase 2
	dc.l	EACCDN,E_OK             ; Fread,Fclose
	dc.l	EACCDN,E_OK             ; Fseek1,Fclose
	dc.l	EACCDN,E_OK             ; Fseek2,Fclose
	dc.l	EACCDN,E_OK             ; Fwrite
	dc.l	E_OK                    ; Fclose

	; Phase 3
	dc.l	EACCDN,E_OK             ; Fread,Fclose
	dc.l	EACCDN,E_OK             ; Fseek1,Fclose
	dc.l	EACCDN,E_OK             ; Fseek2,Fclose
	dc.l	EACCDN,E_OK             ; Fwrite
	dc.l	E_OK                    ; Fclose

header	dc.b	$1b,'E','Disk swap TOS tester v'
	incbin	..\..\VERSION
	dc.b	$0d,'by Jean-Matthieu Coulon',$0d,$0a
	dc.b	'https://github.com/retro16/acsi2stm',$0d,$0a
	dc.b	'License: GPLv3',$0d,$0a
	dc.b	$0a
	dc.b	'This program requires 2 disks labeled',$0d,$0a
	dc.b	'disk 1 and disk 2. The disks must be',$0d,$0a
	dc.b	'formatted independently (different serial',$0d,$0a
	dc.b	'numbers).',$0d,$0a
	dc.b	$0a
	dc.b	0

drvlrq	dc.b	'Please input the drive letter to test:',$0d,$0a
	dc.b	$1b,'e'
	dc.b	0

usedr1	dc.b	$1b,'f','Using drive ',0
usedr2	dc.b	':',$0d,$0a
	dc.b	$0a
	dc.b	0

finishd	dc.b	'Test finished',$0d,$0a
	dc.b	0

clstart	dc.b	'Cleaning up files',$0d,$0a
	dc.b	0

clok	dc.b	'Cleanup successful',$0d,$0a
	dc.b	0

crstart	dc.b	'Creating files',$0d,$0a
	dc.b	0

crok	dc.b	'Created files successfully',$0d,$0a
	dc.b	0

opstart	dc.b	'Opening files',$0d,$0a
	dc.b	0

opok	dc.b	'Ready to swap',$0d,$0a
	dc.b	0

tsstart	dc.b	'Test system',$0d,$0a
	dc.b	0

tsok	dc.b	'Test phase finished',$0d,$0a
	dc.b	0

crerr	dc.b	'Error while creating files',$0d,$0a
	dc.b	0

openerr	dc.b	'Error while opening files',$0d,$0a
	dc.b	0

phase1	dc.b	'Test phase 1: no medium swap',$0d,$0a
	dc.b	0

tfclose	dc.b	'Test Fclose'
	dc.b	0

tfread	dc.b	'Test Fread'
	dc.b	0

tfseek1	dc.b	'Test Fseek inside file'
	dc.b	0

tfseek2	dc.b	'Test Fseek outside file'
	dc.b	0

tfwrite	dc.b	'Test Fwrite'
	dc.b	0

tfwpend	dc.b	'Test Fclose after write'
	dc.b	0

tsucces	dc.b	' OK',$0d,$0a
	dc.b	0

rootdir	dc.b	'\',0
topdir	dc.b	'SWAPTEST.TMP',0
fnread	dc.b	'READ.FIL',0
fnwrite	dc.b	'WRITE.FIL',0
fnwpend	dc.b	'WRITPEND.FIL',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
