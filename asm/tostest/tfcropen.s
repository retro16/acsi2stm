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

; Tests Fcreate, Fopen, Fclose and Fdelete

tfcropen:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	pea	.topdir                 ; Create directory structure
	gemdos	Dcreate,6               ;
	pea	.subdir                 ;
	gemdos	Dcreate,6               ;

	lea	.ncrdir,a5              ; Check that directory is okay
	tst.w	d0                      ;
	bne	abort                   ; Abort if not

	; Normal tests, with no quirks

	lea	.topdir,a4              ; Go into the temp directory
	bsr	.cd                     ;

	lea	.file1,a4               ; Absolute path
	bsr	.test                   ; Do the whole set of tests

	lea	.file2,a4               ; Relative path
	bsr	.test                   ;

	lea	.file3,a4               ; Relative path with current dir
	bsr	.test                   ;

	lea	.file4,a4               ; Relative path with subdir
	bsr	.test                   ;

	lea	.subdir,a4              ; Go into the subdirectory
	bsr	.cd                     ;

	lea	.file5,a4               ; Relative path with parent directory
	bsr	.test                   ;

	; Test that a file name with empty extension is equivalent to a file
	; name without an extension ('FILE6' == 'FILE6.')

	moveq	#0,d5                   ; Must succeed
	lea	.file6,a4               ;
	bsr	.create                 ; Create and close
	bsr	.close                  ;

	lea	.file6x,a4              ; Try to open with the alt file name
	bsr	.open                   ;
	bsr	.close                  ;

	bsr	.clean                  ; Remove everything

	moveq	#EFILNF,d5              ; Try to open a file in a non-existing
	lea	.file1,a4               ; path
	bsr	.open                   ;

	bra	testok

.test	; A "normal" set of tests
	; Input:
	;  a4: path of the file to test
	; Alters: a5, d5.l

	moveq	#0,d5                   ; Must succeed
	bsr	.create                 ;
	bsr	.close                  ;
	bsr	.open                   ;
	move.w	d0,-(sp)                ; Save file descriptor
	bsr	.close                  ;
	bsr	.delete                 ;

	moveq	#EBADF,d5               ; Closed: the file descriptor isn't
	move.w	(sp)+,d0                ; valid anymore
	bsr	.close                  ;

	moveq	#EFILNF,d5              ; Deleted: file doesn't exist anymore
	bsr	.open                   ;
	bsr	.delete                 ;

	rts

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	lea	.root,a4                ; Dsetpath '\'
	bsr	.cd                     ;

	pea	.file1                  ;
	gemdos	Fdelete,6               ;
	pea	.file2a                 ;
	gemdos	Fdelete,6               ;
	pea	.file3a                 ;
	gemdos	Fdelete,6               ;
	pea	.file4a                 ;
	gemdos	Fdelete,6               ;
	pea	.file5a                 ;
	gemdos	Fdelete,6               ;
	pea	.file6                  ;
	gemdos	Fdelete,6               ;

	pea	.subdir                 ;
	gemdos	Ddelete,6               ;
	pea	.topdir                 ;
	gemdos	Ddelete,6               ;

	rts

.create	; Create a file, testing everything
	; Input:
	;  a4: pointer to the path
	;  d5.w: expected return value
	; Returns:
	;  d0.w: file descriptor
	; Alters: a5

	lea	.ncreat,a5

	print	.crting                 ;
	move.l	a4,-(sp)                ; Print path
	gemdos	Cconws,6                ;
	crlf	                        ;

	clr.w	-(sp)                   ; Neutral attributes
	move.l	a4,-(sp)                ; Push path

	gemdos	Fcreate,8               ; Create the file

	tst.w	d5                      ; Check return value
	bmi.b	.crerr                  ; Expecting an error

	cmp.w	#4,d0                   ; Check descriptor
	blt	testfailed              ; Cannot be a standard descriptor or an
		                        ; error
	rts

.crerr	cmp.w	d0,d5                   ; The error must be what was expected
	bne	testfailed              ;

	rts

.open	; Open a file, testing everything
	; Input:
	;  a4: pointer to the path
	;  d5.w: expected return value
	; Returns:
	;  d0.w: file descriptor
	; Alters: a5

	lea	.nopen,a5

	print	.opning                 ;
	move.l	a4,-(sp)                ; Print path
	gemdos	Cconws,6                ;
	crlf	                        ;

	clr.w	-(sp)                   ; Neutral flags
	move.l	a4,-(sp)                ; Push path

	gemdos	Fopen,8                 ; Open the file

	tst.w	d5                      ; Check return value
	bmi.b	.opnerr                 ; Expecting an error

	cmp.w	#4,d0                   ; Check descriptor
	blt	testfailed              ; Cannot be a standard descriptor or an
		                        ; error

	rts

.opnerr	cmp.w	d0,d5                   ; The error must be what was expected
	bne	testfailed              ;

	rts


.close	; Close a file, testing everything
	; Input:
	;  d0: file descriptor
	;  d5.w: expected return value
	; Alters: a5

	lea	.nclose,a5

	move.w	d0,-(sp)                ; Push parameter before printing

	print	.clsing                 ;

	gemdos	Fclose,4                ; Close the file

	cmp.w	d0,d5                   ; The error must be what was expected
	bne	testfailed              ;

	rts

.delete	; Delete a file, testing everything
	; Input:
	;  a4: pointer to the path
	;  d5.w: expected return value
	; Returns:
	;  d0.w: file descriptor
	; Alters: a5

	lea	.ndelet,a5

	print	.dlting                 ;
	move.l	a4,-(sp)                ; Print path
	gemdos	Cconws,2                ;
	crlf	                        ;

	gemdos	Fdelete,6               ;

	cmp.w	d0,d5                   ; The error must be what was expected
	bne	testfailed              ;

	rts

.cd	; Set directory
	; Input:
	;  a4: pointer to path
	; Alters: a5

	lea	.ncd,a5                 ;
	move.l	a4,-(sp)                ;
	gemdos	Dsetpath,6              ;
	tst.w	d0                      ;
	bne	abort                   ;
	rts	                        ;


.desc	dc.b	'Test Fcreate, Fopen, Fclose and Fdelete',$0d,$0a
	dc.b	0

.crting	dc.b	'Creating file ',0
.opning	dc.b	'Opening file ',0
.clsing	dc.b	'Closing file',$0d,$0a
	dc.b	0
.dlting	dc.b	'Deleting file ',0

.ncrdir	dc.b	'Could not create dir structure',$0d,$0a
	dc.b	0

.ncd	dc.b	'Could not change directory',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create file',$0d,$0a
	dc.b	0

.nopen	dc.b	'Could not open file',$0d,$0a
	dc.b	0

.nclose	dc.b	'Could not close file',$0d,$0a
	dc.b	0

.ndelet	dc.b	'Could not delete file',$0d,$0a
	dc.b	0

.nclean	dc.b	'Could not clean files',$0d,$0a
	dc.b	0

.root	dc.b	'\',0
.topdir	dc.b	'\TDCROPEN.TMP',0
.subdir	dc.b	'\TDCROPEN.TMP\'
.subrel	dc.b	'SUBDIR',0

.file1	dc.b	'\TDCROPEN.TMP\FILE1.TMP',0
.file2	dc.b	'FILE2.TMP',0
.file3	dc.b	'.\FILE3.TMP',0
.file4	dc.b	'SUBDIR\FILE4.TMP',0
.file5	dc.b	'..\FILE5.TMP',0
.file6	dc.b	'\TDCROPEN.TMP\FILE6',0
.file6x	dc.b	'\TDCROPEN.TMP\FILE6.',0

.file2a	dc.b	'\TDCROPEN.TMP\FILE2.TMP',0
.file3a	dc.b	'\TDCROPEN.TMP\FILE3.TMP',0
.file4a	dc.b	'\TDCROPEN.TMP\FILE4.TMP',0
.file5a	dc.b	'\TDCROPEN.TMP\SUBDIR\FILE5.TMP',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
