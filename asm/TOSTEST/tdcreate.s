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

; Tests Dcreate and Ddelete

tdcreate:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	moveq	#0,d5                   ; Tests that must succeed

	lea	.topdir,a0              ; Test top dir
	bsr	.create                 ;

	lea	.subrel,a0              ; Test relative subdirectory
	bsr	.create                 ;

	lea	.topdir,a0              ; Test delete relative subdirectory
	bsr	.cd                     ;
	lea	.subrel,a0              ;
	bsr	.delete                 ;

	lea	.sdir2,a0               ; Test absolute subdirectory
	bsr	.create                 ;

	lea	.up,a0                  ; Test relative to parent
	bsr	.create                 ;

	lea	.sdir2,a0               ; Test delete relative to parent
	bsr	.cd                     ;
	lea	.up,a0                  ;
	bsr	.delete                 ;

	lea	.topdir,a0              ; Test delete relative subdirectory
	bsr	.cd                     ; with trailing backspace
	lea	.subbs,a0               ;
	bsr	.delete                 ;

	lea	.topdir,a0              ; Test with lower case
	bsr	.cd                     ;
	lea	.sublc,a0               ;
	bsr	.create                 ;
	lea	.sdir4,a0               ;
	bsr	.cd                     ;
	bne	testfailed              ;

	lea	.topdir,a0              ; Test dot files
	bsr	.cd                     ;

	moveq	#EACCDN,d5              ;

	lea	.root,a0                ; Test non-empty directory
	bsr	.cd                     ;
	lea	.topdir,a0              ;
	bsr	.delete                 ;

	moveq	#EPTHNF,d5              ;

	bsr	.clean                  ; Cleanup to test non-existing paths

	lea	.sdir2,a0               ; Test missing directory
	bsr	.create                 ;

	lea	.sdir2,a0               ; Test missing directory
	bsr	.delete                 ;

	bra	testok

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	lea	.nclean,a5              ; Delete temporary directories

	lea	.root,a0                ; Dsetpath '\'
	bsr	.cd                     ;
	bne	testfailed              ;

	pea	.subdir                 ;
	gemdos	Ddelete,6               ; Ignore errors for cleanup
	pea	.sdir2                  ;
	gemdos	Ddelete,6               ;
	pea	.sdir3                  ;
	gemdos	Ddelete,6               ;
	pea	.sdir4                  ;
	gemdos	Ddelete,6               ;
	pea	.topdir                 ;
	gemdos	Ddelete,6               ;

	rts

.create	; Create a directory, testing everything
	; Input:
	;  a0: pointer to the path
	;  d5.w: expected return value
	; Alters: a5

	lea	.ncreat,a5

	move.l	a0,-(sp)                ; Print path
	print	.crting                 ;
	gemdos	Cconws,2                ; Leave the path pointer on stack
	crlf	                        ;

	gemdos	Dcreate,2               ; Create directory
	move.l	(sp)+,a0                ; a0 = directory

	cmp.w	d0,d5                   ; Check that the error is what we
	bne	testfailed              ; expected

	tst.w	d0                      ;
	bne.b	.crok                   ;

	tst.w	d5                      ; If we expected an error, fail
	bne	testfailed              ;

	bsr.b	.cd                     ; Go into the directory
	bne	testfailed              ; This must succeed

.crok	rts	                        ;

.delete	; Delete a directory, testing everything
	; Input:
	;  a0: pointer to the path
	;  d5.w: expected return value
	; Alters: a5

	lea	.ndel,a5

	move.l	a0,-(sp)                ; Print path
	print	.dlting                 ;
	gemdos	Cconws,2                ; Leave the path pointer on stack
	crlf	                        ;

	gemdos	Ddelete,6               ; Delete directory

	cmp.w	d0,d5                   ; Check that the error is what we
	bne	testfailed              ; expected

	rts	                        ;

.cd	; Set path, with a proper print
	; Input:
	;  a0: pointer to the path
	; Output:
	;  z flag: set if successful

	move.l	a0,-(sp)                ; Print path
	print	.cdin                   ;
	gemdos	Cconws,2                ; Leave the path pointer on stack
	crlf	                        ;

	gemdos	Dsetpath,6              ; Set path
	tst.w	d0                      ; Check return value

	rts

.cdin	dc.b	'Set path to directory ',0
.invcd	dc.b	'Could not set path',$0d,$0a
	dc.b	0

.desc	dc.b	'Test Dcreate and Ddelete',$0d,$0a
	dc.b	0

.crting	dc.b	'Create directory ',0
.dlting	dc.b	'Delete directory ',0

.ncreat	dc.b	'Could not create directory',$0d,$0a
	dc.b	0

.ndel	dc.b	'Could not delete directory',$0d,$0a
	dc.b	0

.nclean	dc.b	'Could not clean directory',$0d,$0a
	dc.b	0

.root	dc.b	'\',0
.topdir	dc.b	'\TDCREATE.TMP',0
.subdir	dc.b	'\TDCREATE.TMP\'
.subrel	dc.b	'SUBDIR',0
.subbs	dc.b	'SUBDIR2\',0
.up	dc.b	'..\SUBDIR3',0
.sublc	dc.b	'subDir4',0

.sdir2	dc.b	'\TDCREATE.TMP\SUBDIR2',0
.sdir3	dc.b	'\TDCREATE.TMP\SUBDIR3',0
.sdir4	dc.b	'\TDCREATE.TMP\SUBDIR4',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
