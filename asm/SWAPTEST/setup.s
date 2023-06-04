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

clean	; Clean everything created by both setup routines

	pea	root                    ; Go to a safe space
	gemdos	Dsetpath,6              ;

	pea	topdir                  ; If you can't enter the test directory
	gemdos	Dsetpath,6              ; everything is already clean
	tst.l	d0                      ;
	bmi	.ok                     ;

	; Close all descriptors

	lea	descr,a3                ; Loop on all descriptors
	moveq	#filecnt*testcnt-1,d3   ;

.close	move.w	d3,d0                   ; Get file descriptor
	lsl.w	#1,d0                   ;
	lea	0(a3,d0.w),a4           ;
	move.w	(a4),d0                 ;

	tst.w	d0                      ; Don't close if not opened
	ble.b	.nopen                  ;

	move.w	d0,-(sp)                ; Force close descriptor
	gemdos	Fclose,4                ;

	clr.w	(a4)                    ;
.nopen	dbra	d3,.close               ; Close next

	moveq	#testcnt-1,d3           ;
.ddir	move.b	d3,d0                   ; Create test subdir name (A-Z)
	add.b	#'A',d0                 ;
	move.b	d0,-(sp)                ; Push name on the stack
	clr.b	1(sp)                   ; Add NUL terminator
	pea	(sp)                    ; Enter test directory
	gemdos	Dsetpath,6              ;
	tst.l	d0                      ; Skip if the dir doesn't exist
	bne.b	.ndir

	moveq	#filecnt-1,d4           ; Delete files
	lea	files(pc),a4            ;
.dfile	move.w	d4,d0                   ; Push file name
	lsl.w	#2,d0                   ;
	move.l	0(a4,d0.w),-(sp)        ;
	gemdos	Fdelete,6               ;
	dbra	d4,.dfile               ;

	pea	topdir                  ; Exit test dir
	gemdos	Dsetpath,6              ;
	pea	(sp)                    ; Delete test dir
	gemdos	Ddelete,6               ; Free Ddelete

.ndir	addq	#2,sp                   ; Pop test dir name
	pea	topdir                  ; Make sure we are in the correct dir
	gemdos	Dsetpath,6              ;
	dbra	d3,.ddir                ; Next test directory

	pea	comdir                  ; Delete directories
	gemdos	Ddelete,6               ;
	pea	dsk2dir                 ;
	gemdos	Ddelete,6               ;
	pea	dsk1dir                 ;
	gemdos	Ddelete,6               ;
	pea	root                    ; Leave topdir to delete it
	gemdos	Dsetpath,6              ;
	pea	topdir                  ; Delete top level directory
	gemdos	Ddelete,6               ;

.ok	rts

setup1	; Disk 1 setup

	bsr	setcom                  ; Common setup

	pea	dsk1dir                 ; Create disk specific directory
	gemdos	Dcreate,6               ;

	lea	descr,a3                ; a3 = current descriptor
	moveq	#0,d3                   ; d3 = current folder

.crdir	move.b	d3,d0                   ; Create test subdir name (A-Z)
	add.b	#'A',d0                 ;
	move.b	d0,-(sp)                ; Push name on the stack
	clr.b	1(sp)                   ; Add NUL terminator
	pea	(sp)                    ; Create folder
	gemdos	Dcreate,6               ;
	pea	(sp)                    ; Enter test directory
	gemdos	Dsetpath,6+2            ; Free Dsetpath + file name

	moveq	#0,d4                   ; Create files
.crfile	move.l	d4,d0                   ; Get file name
	lsl.l	#2,d0                   ;
	lea	files(pc),a0            ;
	move.l	0(a0,d0.w),a0           ;
	bsr	crfile                  ; Create file
	addq	#1,d4                   ; Next file
	cmp.w	#filecnt,d4             ;
	blo	.crfile                 ;

	clr.w	-(sp)                   ; Open files
	pea	ordf                    ;
	gemdos	Fopen,8                 ;
	move.w	d0,(a3)+                ;

	move.w	#1,-(sp)                ;
	pea	owrf                    ;
	gemdos	Fopen,8                 ;
	move.w	d0,(a3)+                ;

	move.w	#1,-(sp)                ;
	pea	wrpendf                 ;
	gemdos	Fopen,8                 ;
	move.w	d0,(a3)+                ;

	pea	root                    ; Write a backslash to differentiate
	moveq	#1,d1                   ;
	move.l	d1,-(sp)                ;
	move.w	d0,-(sp)                ;
	gemdos	Fwrite,12               ;

	pea	topdir                  ; Exit test directory
	gemdos	Dsetpath,6              ;

	addq	#1,d3                   ; Next test directory
	cmp.w	#testcnt,d3             ;
	blo	.crdir                  ;

	rts

setup2	; Disk 2 setup

	bsr	setcom                  ; Common setup

	pea	dsk2dir                 ; Create disk specific directory
	gemdos	Dcreate,6               ;

	rts	                        ; That's enough for disk 2

setcom	; Common setup code, before disk specific

	pea	root                    ; Go to a safe space
	gemdos	Dsetpath,6              ;
	pea	topdir                  ; Create top-level directory
	gemdos	Dcreate,6               ;
	pea	topdir                  ; Enter top-level directory
	gemdos	Dsetpath,6              ;

	pea	comdir                  ; Create common directory
	gemdos	Dcreate,6               ;

	rts	                        ;

crfile	; Create a single byte long file
	; Input: a0: file name

	clr.w	-(sp)                   ; Create the file
	pea	(a0)                    ;
	gemdos	Fcreate,8               ;
	move.l	d0,d5                   ;
	bmi	abort                   ;

	pea	root+1                  ; Fill with a NUL byte
	moveq	#1,d0                   ;
	move.l	d0,-(sp)                ;
	move.w	d5,-(sp)                ;
	gemdos	Fwrite,12               ;

	move.w	d5,-(sp)                ; Close the file
	gemdos	Fclose,4                ;

	rts	                        ;

	; Paths
root	dc.b	'\',0
topdir	dc.b	'\SWAPTEST.TMP',0
dsk1dir	dc.b	'DISK1.DIR',0
dsk2dir	dc.b	'DISK2.DIR',0
comdir	dc.b	'COMMON.DIR',0
	even
pathcnt	equ	3
paths	dc.l	dsk1dir,dsk2dir,comdir

ordf	dc.b	'OPENRD.FIL',0
owrf	dc.b	'OPENWR.FIL',0
wrpendf	dc.b	'WRITPEND.FIL',0
	even
filecnt	equ	3
files	dc.l	ordf,owrf,wrpendf

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
