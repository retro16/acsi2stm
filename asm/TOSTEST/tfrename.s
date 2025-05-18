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

; Tests Frename

tfrename:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.topdir,a4              ; Create directory structure
	bsr	.crdir                  ;
	lea	.sdir1,a4               ;
	bsr	.crdir                  ;
	lea	.sdir2,a4               ;
	bsr	.crdir                  ;

	pea	.topdir                 ;
	gemdos	Dsetpath,6              ;

	moveq	#0,d5                   ; Tests that must succeed

	lea	.file1,a4               ; Create FILE1.TMP
	bsr	.crfile                 ;

	lea	.file2,a3               ; Rename to FILE2.TMP
	bsr	.rename                 ;

	lea	.file2,a4               ; Move and rename to SUBDIR\FILE3.TMP
	lea	.file3,a3               ;
	bsr	.rename                 ;

	pea	.sdir1                  ; Move and rename to FILE4.TMP
	gemdos	Dsetpath,6              ;
	lea	.file3n,a4              ;
	lea	.file4,a3               ;
	bsr	.rename                 ;

	pea	.sdir2                  ; Rename to FILE5.TMP
	gemdos	Dsetpath,6              ;
	lea	.file4n,a4              ;
	lea	.file5,a3               ;
	bsr	.rename                 ;

	lea	.cln5,a4                ; Use absolute paths to rename
	lea	.cln4,a3                ;
	bsr	.rename                 ;

	lea	.cln4,a4                ; Use absolute paths to move
	lea	.cln1,a3                ;
	bsr	.rename                 ;


	moveq	#EACCDN,d5              ; Access denied

	lea	.cln2,a4                ; Rename over an existing file
	bsr	.crfile                 ;
	lea	.cln2,a4                ;
	lea	.cln1,a3                ;
	bsr	.rename                 ;


	moveq	#EPTHNF,d5              ; Invalid path

	lea	.cln1,a4                ; To invalid path
	lea	.file6,a3               ;
	bsr	.rename                 ;

	lea	.file6,a4               ; From invalid path
	lea	.cln1,a3                ;
	bsr	.rename                 ;

	moveq	#EFILNF,d5              ; Invalid file

	lea	.cln4,a4                ; From non-existing file
	lea	.cln5,a3                ;
	bsr	.rename                 ;


	moveq	#ENSAME,d5              ; Other drive

	lea	.cln1,a4                ; Move to other drive
	lea	.file7,a3               ;
	bsr	.rename                 ;

	; Note about moving to other drive:
	; In TOS, moving to an existing path of a different drive returns ENSAME
	; but moving to a non-existing path of a different drive returns EPTHNF.
	; This case is not tested, because in an alternative GEMDOS
	; implementation you may not have access to the other drive so it has to
	; return ENSAME preemptively. But again, who cares ? ENSAME is already a
	; very rare error anyway.

	bsr	.clean                  ; Cleanup before leaving

	bra	testok

.rename	; Test Frename
	; Input:
	;  a4: source
	;  a3: destination
	;  d5.l: expected return value

	lea	.nren,a5

	print	.rening                 ; Print action
	print	(a4)                    ;
	print	.to                     ;
	print	(a3)                    ;
	crlf                            ;

	pea	(a3)                    ; Call Frename
	pea	(a4)                    ;
	clr.w	-(sp)                   ;
	gemdos	Frename,12              ;

	cmp.l	d0,d5                   ; Check return value
	beq.b	.renok                  ;

	move.l	d0,d5                   ; Print returned error value
	print	.errret                 ;
	move.l	d5,d0                   ;
	bsr	tui.phlong              ;
	crlf	                        ;

	bra	testfailed              ;
.renok
	tst.l	d0
	beq.b	.renamd

	rts

.renamd bsr	.exist                  ; Check that the destination file exists
	bne	testfailed              ;

	rts

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath,6              ;

	pea	.cln1                   ;
	gemdos	Fdelete,6               ;
	pea	.cln2                   ;
	gemdos	Fdelete,6               ;
	pea	.cln3                   ;
	gemdos	Fdelete,6               ;
	pea	.cln4                   ;
	gemdos	Fdelete,6               ;
	pea	.cln5                   ;
	gemdos	Fdelete,6               ;

	pea	.sdir1                  ;
	gemdos	Ddelete,6               ;
	pea	.sdir2                  ;
	gemdos	Ddelete,6               ;
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

.exist	; Tests if a file exists
	; Input:
	;  a3: pointer to path
	; Output:
	;  Z: set if the file exists

	clr.w	-(sp)                   ; Try to open the file
	move.l	a3,-(sp)                ;
	gemdos	Fopen,8                 ;

	cmp.w	#4,d0                   ;
	bge.b	.fileok                 ;

	moveq	#-1,d0                  ;
	tst.w	d0                      ;

	rts

.fileok	move.w	d0,-(sp)                ; Close the file
	gemdos	Fclose,4                ;

	tst.w	d0                      ; Check for success
	bne	abort                   ;

	rts

.cd	; Set path, with a proper print
	; Input:
	;  a4: pointer to the path

	move.l	a4,-(sp)                ; Set path
	gemdos	Dsetpath,6              ;
	tst.w	d0                      ; Check return value
	beq	testfailed              ;

	rts

.deldir	; Delete a directory
	; Input:
	;  a4: pointer to the path

	move.l	a4,-(sp)                ; Set path
	gemdos	Ddelete,6               ;
	tst.w	d0                      ; Check return value
	beq	abort                   ;

	rts

.delfil	; Delete a file
	; Input:
	;  a4: pointer to the path

	move.l	a4,-(sp)                ; Set path
	gemdos	Fdelete,6               ;
	tst.w	d0                      ; Check return value
	beq	abort                   ;

	rts

.desc	dc.b	'Test Frename',$0d,$0a
	dc.b	0

.nren	dc.b	'Rename failed',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create path',$0d,$0a
	dc.b	0

.errret	dc.b	'Error: returned ',0

.rening	dc.b	'Renaming ',0
.to	dc.b	$0d,$0a
	dc.b	' to ',0

.root	dc.b	'\',0
.topdir	dc.b	'\TFRENAME.TMP',0

.sdir1	dc.b	'\TFRENAME.TMP\SUBDIR1',0
.sdir2	dc.b	'\TFRENAME.TMP\SUBDIR2',0

.file1	dc.b	'FILE1.TMP',0
.file2	dc.b	'FILE2.TMP',0
.file3	dc.b	'SUBDIR1\'
.file3n	dc.b	'FILE3.TMP',0
.file4	dc.b	'..\SUBDIR2\'
.file4n	dc.b	'FILE4.TMP',0
.file5	dc.b	'.\FILE5.TMP',0
.file6	dc.b	'NOTASUB.DIR\FILE6.TMP',0
.file7	dc.b	'B:\FILE7.TMP',0

.cln1	dc.b	'\TFRENAME.TMP\FILE1.TMP',0
.cln2	dc.b	'\TFRENAME.TMP\FILE2.TMP',0
.cln3	dc.b	'\TFRENAME.TMP\SUBDIR1\FILE3.TMP',0
.cln4	dc.b	'\TFRENAME.TMP\SUBDIR2\FILE4.TMP',0
.cln5	dc.b	'\TFRENAME.TMP\SUBDIR2\FILE5.TMP',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
