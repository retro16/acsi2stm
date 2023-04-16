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

; Tests Dsetpath

tdsetpth:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.unknwn,a0              ; Dsetpath to an unknown directory
	bsr	.cd                     ;

	lea	.npthnf,a5              ; Must return EPTHNF
	cmp.w	#EPTHNF,d0              ;
	bne	testfailed              ;

	lea	.ncreat,a5              ; Create a temporary directory structure
	pea	.topdir                 ;
	gemdos	Dcreate,6               ;
	tst.w	d0                      ;
	bne	abort                   ;
	pea	.subdir                 ;
	gemdos	Dcreate,6               ;
	tst.w	d0                      ;
	bne	abort                   ;

	; Start actual tests

	lea	.topdir,a0              ; Top-level directory
	bsr	.cd                     ;
	lea	.nok,a5                 ;
	tst.w	d0                      ;
	bne	testfailed              ;

	lea	.subdir,a0              ; Subdirectory
	bsr	.cd                     ;
	lea	.nok,a5                 ;
	tst.w	d0                      ;
	bne	testfailed              ;

	lea	.up,a0                  ; Back to top directory
	bsr	.cd                     ;
	lea	.nok,a5                 ;
	tst.w	d0                      ;
	bne	testfailed              ;

	lea	.subbs,a0               ; Subdirectory with trailing backspace
	bsr	.cd                     ;
	lea	.nok,a5                 ;
	tst.w	d0                      ;
	bne	testfailed              ;

	lea	.sublc,a0               ; Subdirectory with wrong case
	bsr	.cd                     ;
	lea	.nok,a5                 ;
	tst.w	d0                      ;
	bne	testfailed              ;

	lea	.root,a0                ; Go back to the root directory
	bsr	.cd                     ;

	lea	.invchr,a0              ; Invalid character
	bsr	.cd                     ;
	lea	.nok,a5                 ;
	cmp.w	#EPTHNF,d0              ;
	bne	testfailed              ;

	bsr	.clean

	bra	testok

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	lea	.root,a0                ; Dsetpath '\'
	bsr	.cd                     ;

	lea	.nok,a5                 ; Must return OK
	tst.w	d0                      ;
	bne	testfailed              ;

	lea	.nrmdir,a5              ; Delete temporary directories
	pea	.subdir                 ;
	gemdos	Ddelete,6               ; Ignore errors for cleanup
	pea	.topdir                 ;
	gemdos	Ddelete,6               ;

	rts

.cd	; Set path, with a proper print
	; Input:
	;  a0: pointer to the path
	; Alters: a5

	lea	.invval,a5

	move.l	a0,-(sp)                ; Print path
	print	.cdin                   ;
	gemdos	Cconws,2                ; Leave the path pointer on stack
	crlf	                        ;

	gemdos	Dsetpath,6              ; Set path
	tst.w	d0                      ; Prepare for test
	beq.b	.cdok

	cmp.w	#EPTHNF,d0              ; This is the only allowed error value
	beq.b	.cdok

	bra	testfailed              ; Wrong return value

.cdok	rts

.desc	dc.b	'Test Dsetpath',$0d,$0a
	dc.b	0

.cdin	dc.b	'Set path to ',0

.invval	dc.b	'Dsetpath returned an invalid value',$0d,$0a
	dc.b	0

.nok	dc.b	'Dsetpath did not return 0 as expected',$0d,$0a
	dc.b	0

.npthnf	dc.b	'Dsetpath did not return EPTHNF',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create temp directory',$0d,$0a
	dc.b	0

.nrmdir	dc.b	'Could not delete temp directory',$0d,$0a
	dc.b	0

.root	dc.b	'\',0
.unknwn	dc.b	'\NOTEXIST.ING',0
.topdir	dc.b	'\TDSETPTH.TMP',0
.subdir	dc.b	'\TDSETPTH.TMP\'
.subrel	dc.b	'SUBDIR',0
.subbs	dc.b	'SUBDIR\',0
.up	dc.b	'..',0
.invchr	dc.b	'/TDSETPTH.TMP',0
.sublc	dc.b	'\TdSeTpTh.TMp\subDir',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
