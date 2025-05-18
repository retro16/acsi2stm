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

; Tests file copy, for multiple file descriptors at the same time

tfilecpy:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.ncreat,a5              ; Create files

	pea	.topdir                 ; Create top directory
	gemdos	Dcreate,6               ;

	clr.w	-(sp)                   ; Create source file
	pea	.sfile                  ;
	gemdos	Fcreate,8               ;
	move.w	d0,d3                   ; d3 = source file descriptor

	bmi	testfailed              ;

	clr.w	-(sp)                   ; Create dest file
	pea	.dfile                  ;
	gemdos	Fcreate,8               ;
	move.w	d0,d4                   ; d4 = dest file descriptor

	bmi	testfailed              ;

	move.l	#'1234',d0              ; Fill the buffer with dummy data
	bsr	fillbuf                 ;

	lea	.nwrite,a5              ; Fill source file with data
	pea	buffer                  ;
	move.l	#512,-(sp)              ;
	move.w	d3,-(sp)                ;
	gemdos	Fwrite,12               ;

	cmp.l	#512,d0                 ;
	bne	testfailed              ;

	lea	.nclose,a5              ; Close source file
	move.w	d3,-(sp)                ;
	gemdos	Fclose,4                ;
	tst.w	d0                      ;
	bmi	testfailed              ;

	clr.l	d0                      ; Clear buffer
	bsr	fillbuf                 ;

	lea	.nopen,a5               ; Reopen source file in read mode

	clr.w	-(sp)                   ;
	pea	.sfile                  ;
	gemdos	Fopen,8                 ;
	move.w	d0,d3                   ;
	bmi	testfailed              ;

	lea	.nread,a5               ; Read half the file minus 1 byte
	pea	buffer                  ;
	move.l	#255,-(sp)              ;
	move.w	d3,-(sp)                ;
	gemdos	Fread,12                ;
	cmp.l	#255,d0                 ;
	bne	testfailed              ;

	lea	.nwrite,a5              ; Write half the file minus 1 byte
	pea	buffer                  ;
	move.l	#255,-(sp)              ;
	move.w	d4,-(sp)                ;
	gemdos	Fwrite,12               ;
	cmp.l	#255,d0                 ;
	bne	testfailed              ;

	lea	.nread,a5               ; Read half the file plus 1 byte
	pea	buffer                  ;
	move.l	#257,-(sp)              ;
	move.w	d3,-(sp)                ;
	gemdos	Fread,12                ;
	cmp.l	#257,d0                 ;
	bne	testfailed              ;

	lea	.nwrite,a5              ; Write half the file plus 1 byte
	pea	buffer                  ;
	move.l	#257,-(sp)              ;
	move.w	d4,-(sp)                ;
	gemdos	Fwrite,12               ;
	cmp.l	#257,d0                 ;
	bne	testfailed              ;

	lea	.nclose,a5              ; Close files

	move.w	d3,-(sp)                ;
	gemdos	Fclose,4                ;
	tst.w	d0                      ;
	bmi	testfailed              ;

	move.w	d4,-(sp)                ;
	gemdos	Fclose,4                ;
	tst.w	d0                      ;
	bmi	testfailed              ;

	bsr	.clean                  ; Cleanup

	bra	testok

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath,6              ;

	pea	.sfile                  ; Delete files
	gemdos	Fdelete,6               ;
	pea	.dfile                  ;
	gemdos	Fdelete,6               ;

	pea	.topdir                 ; Delete test directory
	gemdos	Ddelete,6               ;

	rts


.desc	dc.b	'Test file copy',$0d,$0a
	dc.b	0

.nread	dc.b	'Error while reading',$0d,$0a
	dc.b	0

.nwrite	dc.b	'Error while writing',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create file',$0d,$0a
	dc.b	0

.nopen	dc.b	'Could not open file',$0d,$0a
	dc.b	0

.nclose	dc.b	'Could not close file',$0d,$0a
	dc.b	0

.root	dc.b	'\',0

.topdir	dc.b	'\TFILECPY.TMP',0

.sfile	dc.b	'\TFILECPY.TMP\SOURCE',0
.dfile	dc.b	'\TFILECPY.TMP\DEST',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
