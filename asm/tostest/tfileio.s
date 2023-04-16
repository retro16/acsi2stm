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

; Tests Fread, Fwrite, Fseek and truncate with Fcreate

tfileio:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	lea	.file,a4                ; Create test file
	bsr	.create                 ;

	lea	buffer,a4               ;

	move.l	#'TEST',(a4)            ; Normal write test
	move.l	#'TEST',512-4(a4)       ;
	move.l	#512,d3                 ;
	move.l	d3,d5                   ;
	bsr	.write                  ;

	bsr	.seek0                  ; Normal read test
	clr.l	(a4)                    ;
	clr.l	512-4(a4)               ;
	move.l	#'OUT.',512(a4)         ;
	move.l	#512,d3                 ;
	move.l	d3,d5                   ;
	bsr	.read                   ;
	lea	.normal,a5              ;
	cmp.l	#'TEST',(a4)            ; Check data
	bne	testfailed              ;
	cmp.l	#'TEST',512-4(a4)       ;
	bne	testfailed              ;
	cmp.l	#'OUT.',512(a4)         ;
	bne	testfailed              ;

	moveq	#2,d0                   ; Test seek from end of file
	moveq	#-2,d3                  ;
	move.l	#510,d5                 ;
	bsr	.seek                   ;

	moveq	#2,d0                   ; Test file size query
	moveq	#0,d3                   ;
	move.l	#512,d5                 ;
	bsr	.seek                   ;

	moveq	#1,d0                   ; Test seek from current position
	moveq	#-2,d3                  ;
	move.l	#510,d5                 ;
	bsr	.seek                   ;

	moveq	#2,d0                   ; Test seek outside the file
	moveq	#2,d3                   ;
	move.l	#ERANGE,d5              ;
	bsr	.seek                   ;

	moveq	#0,d0                   ; Test "precision" seek and small read
	move.l	#512-4,d3               ;
	move.l	d3,d5                   ;
	bsr	.seek                   ;
	clr.l	(a4)                    ;
	clr.l	4(a4)                   ;
	move.l	#'OUT.',8(a4)           ;
	moveq	#4,d3                   ;
	move.l	d3,d5                   ;
	bsr	.read                   ;
	lea	.small,a5               ;
	cmp.l	#'TEST',(a4)            ;
	bne	testfailed              ;
	tst.l	4(a4)                   ;
	bne	testfailed              ;
	cmp.l	#'OUT.',8(a4)           ;
	bne	testfailed              ;

	moveq	#0,d0                   ; Seek back to file beginning
	moveq	#0,d3                   ;
	moveq	#0,d5                   ;
	bsr	.seek                   ;

	move.l	#'TEST',buffer+65536-4  ; Big write test
	move.l	#65536,d3               ;
	move.l	d3,d5                   ;
	bsr	.write                  ; Write 64k at once
	bsr	.seek0                  ;
	clr.l	buffer+65536-4          ; Big read test
	move.l	#65536,d3               ;
	move.l	d3,d5                   ;
	bsr	.read                   ;
	lea	.big,a5                 ;
	cmp.l	#'TEST',buffer+65536-4  ;
	bne	testfailed              ;

	lea	1(a4),a4                ; Test unaligned buffers

	bsr	.seek0                  ; Unaligned write
	move.l	#'_EST',buffer          ;
	move.l	#'OUT.',buffer+65536    ;
	move.l	#'TEST',buffer+65532    ;
	move.l	#65535,d3               ;
	move.l	d3,d5                   ;
	bsr	.write                  ;

	bsr	.seek0                  ; Unaligned read
	move.l	#'TTTT',buffer          ;
	clr.l	buffer+65532            ;
	move.l	#'XXXX',buffer+65536    ;
	move.l	#65535,d3               ;
	move.l	d3,d5                   ;
	bsr.w	.read                   ;
	lea	.unalrd,a5              ;
	cmp.l	#'TEST',buffer          ;
	bne	testfailed              ;
	cmp.l	#'TEST',buffer+65532    ;
	bne	testfailed              ;
	cmp.l	#'XXXX',buffer+65536    ;
	bne	testfailed              ;

	bsr	.close                  ; Test file truncate
	lea	.file,a4                ;
	bsr	.create                 ;
	moveq	#2,d0                   ;
	moveq	#0,d3                   ;
	moveq	#0,d5                   ;
	bsr	.seek                   ;

	bsr	.close                  ; Close file
	bsr	.clean                  ; Cleanup

	bra	testok

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	lea	.root,a4                ; Dsetpath '\'
	bsr	.cd                     ;

	pea	.file                   ;
	gemdos	Fdelete,6               ;

	rts

.read	; Do a Fread, testing everything
	; Input:
	;  a4: data pointer
	;  d4.w: File descriptor
	;  d3.l: Length
	;  d5.l: Expected return value

	lea	.nread,a5

	print	.rding                  ; Print operation
	move.l	d3,d0                   ;
	bsr	tui.phlong              ;

	pea	(a4)                    ; Do Fread
	move.l	d3,-(sp)                ;
	move.w	d4,-(sp)                ;
	gemdos	Fread,12                ;

	move.l	d0,-(sp)                ;
	print	.got                    ; Display result
	move.l	(sp),d0                 ;
	bsr	tui.phlong              ;
	crlf	                        ;

	cmp.l	(sp)+,d5                ; Check return value
	bne	testfailed              ;

	rts

.write	; Do a Fwrite, testing everything
	; Input:
	;  a4: data pointer
	;  d4.w: File descriptor
	;  d3.l: Length
	;  d5.l: Expected return value

	lea	.nwrite,a5

	print	.wrting                 ; Print operation
	move.l	d3,d0                   ;
	bsr	tui.phlong              ;

	pea	(a4)                    ; Do Fread
	move.l	d3,-(sp)                ;
	move.w	d4,-(sp)                ;
	gemdos	Fwrite,12               ;

	move.l	d0,-(sp)                ;
	print	.got                    ; Display result
	move.l	(sp),d0                 ;
	bsr	tui.phlong              ;
	crlf	                        ;

	cmp.l	(sp)+,d5                ; Check return value
	bne	testfailed              ;

	rts

.seek0	; Seek at the beginning of the file
	moveq	#0,d0                   ;
	moveq	#0,d3                   ;
	moveq	#0,d5                   ;

	; Fall through .seek

.seek	; Do a Fseek, testing everything
	; Input:
	;  a4: data pointer
	;  d4.w: File descriptor
	;  d0.l: whence (0=start, 1=cur, 2=end)
	;  d3.l: Offset
	;  d5.l: Expected return value

	lea	.nseek,a5

	move.w	d0,-(sp)                ; Push whence

	tst.w	d0                      ; Print operation
	beq.b	.wh0                    ;
	subq	#1,d0                   ;
	beq.b	.wh1                    ;
	pea	.sk2                    ;
	bra.b	.whok                   ;
.wh0	pea	.sk0                    ;
	bra.b	.whok                   ;
.wh1	pea	.sk1                    ;
.whok	print	.sking                  ;
	gemdos	Cconws,6                ;
	move.l	d3,d0                   ;
	bsr	tui.phlong              ;

	move.w	d4,-(sp)                ; Push other Fseek parameters
	move.l	d3,-(sp)                ;
	gemdos	Fseek,10                ; Do Fseek

	move.l	d0,-(sp)                ;
	print	.got                    ; Display result
	move.l	(sp),d0                 ;
	bsr	tui.phlong              ;
	crlf	                        ;

	cmp.l	(sp)+,d5                ; Check return value
	bne	testfailed              ;

	rts

.create	; Create a file
	; Input:
	;  a4: pointer to the path
	; Returns:
	;  d4.w: file descriptor
	; Alters: a5

	lea	.ncreat,a5
	clr.w	-(sp)                   ; Neutral attributes
	move.l	a4,-(sp)                ; Push path
	gemdos	Fcreate,8               ; Create the file
	cmp.w	#4,d0                   ; Check descriptor
	blt	abort                   ; Cannot be a standard descriptor or an
		                        ; error

	move.w	d0,d4                   ; Store file descriptor for other tests
	rts

.open	; Open a file
	; Input:
	;  a4: pointer to the path
	;  d5.w: expected return value
	; Returns:
	;  d4.w: file descriptor
	; Alters: a5

	lea	.nopen,a5
	move.w	#2,-(sp)                ; Open read-write
	move.l	a4,-(sp)                ; Push path
	gemdos	Fopen,8                 ; Open the file
	cmp.w	#4,d0                   ; Check descriptor
	blt	abort                   ; Cannot be a standard descriptor or an
		                        ; error

	move.w	d0,d4                   ; Store file descriptor for other tests
	rts

.close	; Close a file
	; Input:
	;  d4: file descriptor
	; Alters: a5

	lea	.nclose,a5
	move.w	d4,-(sp)                ; Push parameter before printing
	gemdos	Fclose,4                ; Close the file
	tst.w	d0                      ; Success required
	bne	abort                   ;

	rts

.delete	; Delete a file
	; Input:
	;  a4: pointer to the path
	;  d5.w: expected return value
	; Returns:
	;  d0.w: file descriptor
	; Alters: a5

	lea	.ndelet,a5
	move.l	a4,-(sp)                ; Print path
	gemdos	Fdelete,6               ;
	cmp.w	d0,d5                   ; The error must be what was expected
	bne	abort                   ;

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


.desc	dc.b	'Test Fread, Fwrite and Fseek',$0d,$0a
	dc.b	0

.nread	dc.b	'Error while reading',$0d,$0a
	dc.b	0

.nwrite	dc.b	'Error while writing',$0d,$0a
	dc.b	0

.nseek	dc.b	'Error while seeking',$0d,$0a
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

.ncd	dc.b	'Could not set current directory',$0d,$0a
	dc.b	0

.rding	dc.b	'Test read length ',0

.wrting	dc.b	'Test write length ',0

.sking	dc.b	'Test seek from ',0
.sk0	dc.b	'start at ',0
.sk1	dc.b	'current at ',0
.sk2	dc.b	'end at ',0

.got	dc.b	$0d,$0a
	dc.b	' returned ',0

.root	dc.b	'\',0

.file	dc.b	'\TFILEIO.TMP',0

.normal	dc.b	'Error in normal read test',$0d,$0a
	dc.b	0
.small	dc.b	'Error in small read test',$0d,$0a
	dc.b	0
.big	dc.b	'Error in big write/read test',$0d,$0a
	dc.b	0
.eof	dc.b	'Error in EOF read test',$0d,$0a
	dc.b	0
.unalrd	dc.b	'Error in unaligned read test',$0d,$0a
	dc.b	0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
