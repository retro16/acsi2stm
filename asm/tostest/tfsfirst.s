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

; Tests Fsfirst and Fsnext
; TODO: file attributes
; TODO: volume label

tfsfirst:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.topdir,a4              ; Create directory structure
	bsr	.crdir                  ;
	lea	.sub1,a4                ;
	bsr	.crdir                  ;
	lea	.sub2,a4                ;
	bsr	.crdir                  ;
	lea	.sub3,a4                ;
	bsr	.crdir                  ;

	lea	.file1,a4               ;
	bsr	.crfile                 ;
	lea	.file2,a4               ;
	bsr	.crfile                 ;
	lea	.fsub1,a4               ;
	bsr	.crfile                 ;
	lea	.fsub2,a4               ;
	bsr	.crfile                 ;
	lea	.fsub3,a4               ;
	bsr	.crfile                 ;
	lea	.fsub4,a4               ;
	bsr	.crfile                 ;

	pea	buffer                  ; Set DTA to buffer
	gemdos	Fsetdta,6               ;

	pea	.topdir                 ; Set path to top dir
	gemdos	Dsetpath,6              ;

	; Pattern matching tests

	moveq	#7,d5                   ; Simple pattern test
	moveq	#5,d4                   ;
	lea	.pat1a,a4               ;
	bsr	.test                   ;
	lea	.pat1b,a4               ;
	bsr	.test                   ;
	lea	.pat1c,a4               ;
	bsr	.test                   ;

	lea	.pat2a,a4               ; Question mark pattern
	moveq	#2,d5                   ;
	moveq	#0,d4                   ;
	bsr	.test                   ;
	lea	.pat2b,a4               ;
	bsr	.test                   ;
	lea	.pat2c,a4               ;
	bsr	.test                   ;
	lea	.pat2d,a4               ;
	bsr	.test                   ;
	lea	.pat2e,a4               ;
	bsr	.test                   ;
	lea	.pat2f,a4               ;
	bsr	.test                   ;
	lea	.pat2g,a4               ;
	bsr	.test                   ;

	lea	.pat3a,a4               ; Relative pattern
	moveq	#3,d5                   ;
	moveq	#3,d4                   ;
	bsr	.test                   ;
	lea	.pat3b,a4               ;
	bsr	.test                   ;
	lea	.pat3c,a4               ;
	bsr	.test                   ;
	lea	.pat3d,a4               ;
	bsr	.test                   ;
	lea	.pat3e,a4               ;
	bsr	.test                   ;
	lea	.pat3f,a4               ;
	moveq	#1,d5                   ;
	moveq	#1,d4                   ;
	bsr	.test                   ;

	lea	.pat4a,a4               ; Subdirectory wildcards
	moveq	#4,d5                   ;
	moveq	#1,d4                   ;
	bsr	.test                   ;
	lea	.pat4b,a4               ;
	moveq	#5,d5                   ;
	moveq	#2,d4                   ;
	bsr	.test                   ;
	lea	.pat4c,a4               ;
	moveq	#5,d5                   ;
	moveq	#2,d4                   ;
	bsr	.test                   ;
	lea	.pat4e,a4               ;
	moveq	#5,d5                   ;
	moveq	#2,d4                   ;
	bsr	.test                   ;
	lea	.pat4g,a4               ;
	moveq	#4,d5                   ;
	moveq	#1,d4                   ;
	bsr	.test                   ;
	lea	.pat4h,a4               ;
	moveq	#4,d5                   ;
	moveq	#1,d4                   ;
	bsr	.test                   ;
	lea	.pat4i,a4               ;
	moveq	#4,d5                   ;
	moveq	#1,d4                   ;
	bsr	.test                   ;
	lea	.pat4j,a4               ;
	moveq	#4,d5                   ;
	moveq	#1,d4                   ;
	bsr	.test                   ;

	lea	.pat5a,a4               ; Path traversal pattern
	moveq	#3,d5                   ;
	moveq	#3,d4                   ;
	bsr	.test                   ;
	lea	.pat5b,a4               ;
	bsr	.test                   ;
	lea	.pat5c,a4               ;
	bsr	.test                   ;
	lea	.pat5d,a4               ;
	bsr	.test                   ;
	lea	.pat5e,a4               ;
	bsr	.test                   ;
	lea	.pat5f,a4               ;
	bsr	.test                   ;

	; Test Fsfirst error management

	moveq	#EFILNF,d5              ; Non-existing file
	moveq	#$11,d4                 ;
	lea	.pat6a,a4               ;
	bsr	.first                  ;
	lea	.pat6b,a4               ;
	bsr	.first                  ;
	moveq	#EPTHNF,d5              ; Non-existing path
	lea	.pat6c,a4               ;
	bsr	.first                  ;

	moveq	#EPTHNF,d5              ; Patterns in paths
	lea	.pat7a,a4               ;
	bsr	.first                  ;
	lea	.pat7b,a4               ;
	bsr	.first                  ;
	lea	.pat7c,a4               ;
	bsr	.first                  ;
	lea	.pat7d,a4               ;
	bsr	.first                  ;

	moveq	#EFILNF,d5              ; Directories
	lea	.pat8a,a4               ;
	bsr	.first                  ;
	lea	.pat8b,a4               ;
	bsr	.first                  ;
	lea	.pat8c,a4               ;
	bsr	.first                  ;
	lea	.pat8d,a4               ;
	bsr	.first                  ;
	lea	.pat8e,a4               ;
	bsr	.first                  ;

	bsr	.clean                  ; Cleanup before leaving

	bra	testok


.test	; Do a simple test, returning at least 2 entries
	; Input:
	;  a4: pointer to path
	;  d5.w: number of expected entries
	;  d4.w: number of expected directories

	movem.w	d4-d5,-(sp)             ; Store expected results

	moveq	#0,d5                   ; Call Fsfirst
	moveq	#$11,d4                 ;
	bsr	.first                  ;

	movem.w	(sp),d4-d5              ; Restore expected results
	bsr	.nxtcnt                 ; Call Fsnext

	movem.w	(sp)+,d4-d5             ; Restore registers
	rts

.first	; Call Fsfirst and check its return value
	; Input:
	;  a4: pointer to path
	;  d4.w: attributes
	;  d5.l: expected return value

	lea	.nfirst,a5

	print	.fsting                 ; Print message
	print	(a4)                    ;
	crlf	                        ;

	move.w	d4,-(sp)                ; Call Fsfirst
	pea	(a4)                    ;
	gemdos	Fsfirst,8               ;

	cmp.l	d0,d5                   ; Check return value
	bne	testfailed              ;

	rts

.nxtcnt	; Call Fsnext repeatedly until there is no more file
	; Count that the number of files is what is expected
	; Input:
	;  d5.w: number of expected entries
	;  d4.w: number of expected directories
	; Alters: a3

	lea	.nnxt,a5

	subq	#1,d5                   ; Adjust for dbra

	gemdos	Fgetdta,2               ; a3 = pointer to file attributes
	move.l	d0,a3                   ;
	lea	21(a3),a3               ;

	btst	#4,(a3)                 ; Check if the first entry is a dir
	beq.b	.nxtnfd                 ;
	subq	#1,d4                   ;
.nxtnfd		                        ;

.nxtfsn	gemdos	Fsnext,2                ; Call Fsnext

	tst.w	d0                      ; Count directories
	bne.b	.nxtnd                  ;
	btst	#4,(a3)                 ;
	beq.b	.nxtnd                  ;
	subq	#1,d4                   ;
.nxtnd		                        ;

	tst.w	d0                      ; Count files
	dbne	d5,.nxtfsn              ;

	cmp.w	#ENMFIL,d0              ; The last iteration must have returned
	bne	testfailed              ; "no more files"

	tst.w	d5                      ; If entry counter is wrong: test failed
	bne	testfailed              ;

	tst.w	d4                      ; If dir counter is wrong: test failed
	bne	testfailed              ;

	rts

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath,6              ;

	pea	.file1                  ;
	gemdos	Fdelete,6               ;
	pea	.file2                  ;
	gemdos	Fdelete,6               ;
	pea	.fsub1                  ;
	gemdos	Fdelete,6               ;
	pea	.fsub2                  ;
	gemdos	Fdelete,6               ;
	pea	.fsub3                  ;
	gemdos	Fdelete,6               ;
	pea	.fsub4                  ;
	gemdos	Fdelete,6               ;

	pea	.sub1                   ;
	gemdos	Ddelete,6               ;
	pea	.sub2                   ;
	gemdos	Ddelete,6               ;
	pea	.sub3                   ;
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

.desc	dc.b	'Test Fsfirst and Fsnext',$0d,$0a
	dc.b	0

.ncreat	dc.b	'Could not create path',$0d,$0a
	dc.b	0

.nfirst	dc.b	'Error in Fsfirst',$0d,$0a
	dc.b	0

.nnxt	dc.b	'Wrong file list',$0d,$0a
	dc.b	0

.fsting	dc.b	'Test ',0

.root	dc.b	'\',0
.topdir	dc.b	'\TFSFIRST.TMP',0

.sub1	dc.b	'\TFSFIRST.TMP\SUB1',0
.sub2	dc.b	'\TFSFIRST.TMP\SUB2',0
.sub3	dc.b	'\TFSFIRST.TMP\SUB3',0

.file1	dc.b	'\TFSFIRST.TMP\FILE1.TMP',0
.file2	dc.b	'\TFSFIRST.TMP\FILE2.TMP',0
.fsub1	dc.b	'\TFSFIRST.TMP\SUB1\1',0
.fsub2	dc.b	'\TFSFIRST.TMP\SUB1\2',0
.fsub3	dc.b	'\TFSFIRST.TMP\SUB1\3',0
.fsub4	dc.b	'\TFSFIRST.TMP\SUB2\4',0

	; File list patterns

.pat1a	dc.b	'*.*',0
.pat1b	dc.b	'\TFSFIRST.TMP\*.*',0
.pat1c	dc.b	'\tfsfirst.tmp\*.*',0

.pat2a	dc.b	'\TFSFIRST.TMP\F?LE?.*',0
.pat2b	dc.b	'\TFSFIRST.TMP\F?LE?.T*',0
.pat2c	dc.b	'\TFSFIRST.TMP\F?LE?.T??',0
.pat2d	dc.b	'\TFSFIRST.TMP\????????.T??',0
.pat2e	dc.b	'\TFSFIRST.TMP\*.T??',0
.pat2f	dc.b	'\TFSFIRST.TMP\F*.*',0
.pat2g	dc.b	'\TFSFIRST.TMP\f*.???',0

.pat3a	dc.b	'SUB?',0
.pat3b	dc.b	'SUB?.',0
.pat3c	dc.b	'SUB?.??',0
.pat3d	dc.b	'SUB?.???',0
.pat3e	dc.b	'SUB?.*',0
.pat3f	dc.b	'SUB1',0

.pat4a	dc.b	'SUB1\?',0
.pat4b	dc.b	'SUB1\*',0
.pat4c	dc.b	'SUB1\*.',0
.pat4e	dc.b	'SUB1\??',0
.pat4g	dc.b	'SUB1\?.',0
.pat4h	dc.b	'SUB1\?.?',0
.pat4i	dc.b	'SUB1\?.???',0
.pat4j	dc.b	'SUB1\?.*',0

.pat5a	dc.b	'.\SUB?',0
.pat5b	dc.b	'..\TFSFIRST.TMP\SUB?',0
.pat5c	dc.b	'SUB3\..\SUB?',0
.pat5d	dc.b	'SUB3\..\..\TFSFIRST.TMP\SUB?',0
.pat5e	dc.b	'.\SUB3\..\..\.\TFSFIRST.TMP\SUB?',0
.pat5f	dc.b	'\TFSFIRST.TMPEXTRA\SUB?',0

.pat6a	dc.b	'NOTEXIST.ING',0
.pat6b	dc.b	'SUB1\NOTEXIST.ING',0
.pat6c	dc.b	'NOTEXIST.ING\FILE.TMP',0

.pat7a	dc.b	'SUB?\1',0
.pat7b	dc.b	'*\1',0
.pat7c	dc.b	'SUB1\.?\SUB1\*.*',0
.pat7d	dc.b	'SUB1\.*\*.*',0

.pat8a	dc.b	'SUB1\',0
.pat8b	dc.b	'SUB1\.',0
.pat8c	dc.b	'SUB1\..',0
.pat8d	dc.b	'SUB1\.\',0
.pat8e	dc.b	'SUB1\..\',0


	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
