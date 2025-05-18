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

; Tests Fattrib

tfattrib:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.topdir,a4              ; Create directory structure
	bsr	.crdir                  ;

	pea	.topdir                 ;
	gemdos	Dsetpath,6              ;

	lea	.file,a4                ; Create FILE1.TMP
	bsr	.crfile                 ;

	moveq	#0,d5                   ; Tests that must succeed

	lea	.file,a4                ; Test read-only
	moveq	#1,d4                   ;
	move.w	d4,d5                   ;
	bsr	.setatr                 ;
	bsr	.getatr                 ; Test getting attributes

	move.w	#2,-(sp)                ; Try writing the read-only file
	pea	(a4)                    ;
	gemdos	Fopen,8                 ;

	lea	.opendw,a5              ;
	cmp.w	#EACCDN,d0              ; Must return "access denied"
	bne	testfailed              ;

	moveq	#0,d4                   ; Remove read-only
	move.w	d4,d5                   ;
	bsr	.setatr                 ;
	bsr	.getatr                 ;

	moveq	#EFILNF,d5              ; Tests with non-existing file

	lea	.nofile,a4              ; Test read-only
	moveq	#0,d4                   ;
	bsr	.setatr                 ;
	bsr	.getatr                 ;

	lea	.topdir,a4              ; Directories return "file not found"
	bsr	.setatr                 ;
	bsr	.getatr                 ;

	bsr	.clean                  ; Cleanup before leaving

	bra	testok

.getatr	; Get file attributes
	; Input:
	;  a4: pointer to path
	;  d5.w: expected return value

	lea	.nget,a5

	clr.w	-(sp)                   ; Call Fattrib
	clr.w	-(sp)                   ;
	pea	(a4)                    ;
	gemdos	Fattrib,10              ;

	cmp.w	d0,d5                   ; Check return value
	bne	testfailed              ;

	rts

.setatr	; Set file attributes
	; Input:
	;  a4: pointer to path
	;  d4.w: attributes
	;  d5.w: expected return value

	lea	.nset,a5

	move.w	d4,-(sp)                ; Call Fattrib
	move.w	#1,-(sp)                ;
	pea	(a4)                    ;
	gemdos	Fattrib,10              ;

	cmp.w	d0,d5                   ; Check return value
	bne	testfailed              ;

	rts

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath,6              ;

	clr.w	-(sp)                   ; Remove read-only attribute
	move.w	#1,-(sp)                ;
	pea	.file                   ;
	gemdos	Fattrib,10              ;

	pea	.file                   ;
	gemdos	Fdelete,6               ;

	pea	.topdir                 ;
	gemdos	Ddelete,6               ;

	rts

.crdir	; Create a directory
	; Input:
	;  a4: pointer to path

	lea	.ncreat,a5
	move.l	a4,-(sp)                ; Push path
	gemdos	Dcreate,6               ; Create the file
	tst.w	d0                      ; Check return
	bne	abort                   ; Success required

	rts

.crfile	; Create a file
	; Input:
	;  a4: pointer to path

	lea	.ncreat,a5
	clr.w	-(sp)                   ; Neutral attributes
	move.l	a4,-(sp)                ; Push path
	gemdos	Fcreate,8               ; Create the file
	cmp.w	#4,d0                   ; Check descriptor
	blt	abort                   ; Cannot be a standard descriptor or an
		                        ; error

	move.w	d0,-(sp)                ; Close the file
	gemdos	Fclose,4                ;
	tst.w	d0                      ; Success required
	bne	abort                   ;

	rts

.desc	dc.b	'Test Fattrib',$0d,$0a
	dc.b	0

.nset	dc.b	'Could not set attributes',$0d,$0a
	dc.b	0

.nget	dc.b	'Could not get attributes',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create path',$0d,$0a
	dc.b	0

.opendw	dc.b	'Could open read-only for writing',$0d,$0a
	dc.b	0

.root	dc.b	'\',0
.topdir	dc.b	'\TFATTRIB.TMP',0

.file	dc.b	'\TFATTRIB.TMP\FILE.TMP',0
.nofile	dc.b	'\TFATTRIB.TMP\NOTEXIST.ING',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
