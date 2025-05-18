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

; Tests Fdatime

tfdatime:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.topdir,a4              ; Create directory structure
	bsr	.crdir                  ;

	pea	.topdir                 ;
	gemdos	Dsetpath,6              ;

	lea	.file,a4                ; Create FILE.TMP
	bsr	.crfile                 ;

	move.w	d4,-(sp)                ; Reopen read-only
	gemdos	Fclose,4                ;
	clr.w	-(sp)                   ;
	pea	.file                   ;
	gemdos	Fopen,8                 ;

	tst.w	d0                      ;
	bmi	testfailed              ;

	; Sample date is 2019-02-23 20:55:16

	lea	.nset,a5                ; Set file time
	move.l	#((16/2)<<16)!(55<<21)!(20<<27)!(23)!(2<<5)!(39<<9),buffer
	move.w	#1,-(sp)                ;
	move.w	d4,-(sp)                ;
	pea	buffer                  ;
	gemdos	Fdatime,10              ;

	clr.l	buffer                  ;
	lea	.nget,a5                ; Get file time
	clr.w	-(sp)                   ;
	move.w	d4,-(sp)                ;
	pea	buffer                  ;
	gemdos	Fdatime,10              ;

	cmp.l	#((16/2)<<16)!(55<<21)!(20<<27)!(23)!(2<<5)!(39<<9),buffer
	bne	testfailed              ; Check that date/time is correct

	bsr	.close                  ; Close the file
	bsr	.clean                  ; Cleanup before leaving

	bra	testok


.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath,6              ;

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
	blo	abort                   ; Cannot be a standard descriptor or an
		                        ; error
	move.w	d0,d4                   ; Store descriptor
	rts

.close	move.w	d4,-(sp)                ; Close the file
	gemdos	Fclose,4                ;
	tst.w	d0                      ; Success required
	bne	abort                   ;

	rts

.desc	dc.b	'Test Fdatime',$0d,$0a
	dc.b	0

.nset	dc.b	'Could not set date time',$0d,$0a
	dc.b	0

.nget	dc.b	'Could not get date time',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create path',$0d,$0a
	dc.b	0

.root	dc.b	'\',0
.topdir	dc.b	'\TFDATIME.TMP',0

.file	dc.b	'\TFDATIME.TMP\FILE.TMP',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
