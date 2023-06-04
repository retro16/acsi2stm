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

testcnt	equ	5

test	; Test pass

	lea	descr,a3                ; a3 = file descriptors

	print	.wr1byt                 ; Write 1 byte to each file
	lea	wr1byte,a4              ;
	bsr	tstfile                 ;

	print	.rd1byt                 ;
	lea	rd1byte,a4              ; Read 1 byte from each file
	bsr	tstfile                 ;

	print	.clsfil                 ; Close the file
	lea	clsfile,a4              ;
	bsr	tstfile                 ;

	print	.seek1                  ; Seek at offset 1
	lea	seek1,a4                ;
	bsr	tstfile                 ;

	print	.seek2                  ; Seek at offset 2
	lea	seek2,a4                ;
	bsr	tstfile                 ;

	lea	paths,a3                ; Test paths
	moveq	#0,d3                   ; d3 = path count
.nxtpth	bsr	tstpath                 ; Test the path
	addq	#4,a3                   ; Next path
	addq.w	#1,d3                   ;
	cmp.w	#pathcnt,d3             ;
	bne	.nxtpth                 ;

	rts	                        ;

.wr1byt	dc.b	'Write 1 byte to',$0d,$0a
	dc.b	0

.rd1byt	dc.b	'Read 1 byte from',$0d,$0a
	dc.b	0

.clsfil	dc.b	'Close file descriptor of',$0d,$0a
	dc.b	0

.seek1	dc.b	'Seek at offset 1 of',$0d,$0a
	dc.b	0

.seek2	dc.b	'Seek at offset 2 of',$0d,$0a
	dc.b	0

	even

tstpath	; Do a test pass on a path

	move.l	(a3),a4                 ; a4 = path to test

	print	.delete                 ; Delete directory
	print	(a4)                    ;
	crlf	                        ;
	pea	(a4)                    ;
	gemdos	Ddelete,6               ;
	bsr	tstcode                 ;

.ddltst	tst.l	d0                      ; Undo delete if successful
	bne	.ndel                   ;
	pea	(a4)                    ;
	gemdos	Dcreate,6               ;
.ndel

	print	.create                 ; Create directory
	print	(a4)                    ;
	crlf	                        ;
	pea	(a4)                    ;
	gemdos	Dcreate,6               ;
	bsr	tstcode                 ;

.dcrtst	tst.l	d0                      ; Undo create if successful
	bne	.ncreat                 ;
	pea	(a4)                    ;
	gemdos	Ddelete,6               ;
.ncreat
	rts

.delete	dc.b	'Delete directory ',0
.create	dc.b	'Create directory ',0
	even


tstfile	; Call a function in a4 on all file descriptors

	moveq	#0,d3                   ; d3 = file

.nxtfil	move.l	d3,d0                   ; Print file name
	lsl.l	#2,d0                   ;
	lea	files,a0                ;
	move.l	0(a0,d0.w),a0           ;
	print	(a0)                    ;
	crlf	                        ;

	jsr	(a4)                    ; Call the test function
	move.l	d0,d4                   ; Store result
	bsr	tstcode                 ; Test result code
	addq	#1,d3                   ; Next file
	cmp.w	#filecnt,d3             ;
	blo	.nxtfil                 ;

	rts

tstcode	cmp.l	(a5),d0                 ; Check result code
	beq	.ok                     ;

	move.l	d0,-(sp)                ; Store result
	print	.wrong                  ; Wrong result
	move.l	(a5),d0                 ;
	bsr	tui.phlong              ; Print expected value
	print	.got                    ;
	move.l	(sp),d0                 ;
	bsr	tui.phlong              ; Print returned value
	crlf	                        ;
	add.w	#1,failed               ;

	gemdos	Cnecin,2                ; Wait for a key

	move.l	(sp)+,d0                ; Restore return code
	bra	.next                   ;

.ok	add.w	#1,success              ;
.next	addq	#4,a5                   ; Next expected value

	rts

.wrong	dc.b	'Wrong return code.',$0d,$0a
	dc.b	'Expected:',0
.got	dc.b	' got:',0
	even

wr1byte	; Write 1 byte to the file descriptor

	pea	.byte
	moveq	#1,d0
	move.l	d0,-(sp)
	move.w	(a3)+,-(sp)
	gemdos	Fwrite,12

	rts

.byte	dc.b	'!'
	even

rd1byte	; Read 1 byte from the file descriptor

	pea	.byte
	moveq	#1,d0
	move.l	d0,-(sp)
	move.w	(a3)+,-(sp)
	gemdos	Fread,12
	rts

.byte	dc.b	'!'
	even

clsfile	; Close file descriptor

	move.w	(a3)+,-(sp)
	gemdos	Fclose,4
	tst.w	d0
	bmi	.fail
	moveq	#0,d0
.fail	rts

seek1	; Seek to offset 1

	clr.w	-(sp)
	move.w	(a3)+,-(sp)
	moveq	#1,d0
	move.l	d0,-(sp)
	gemdos	Fseek,10
	rts

seek2	; Seek to offset 2

	clr.w	-(sp)
	move.w	(a3)+,-(sp)
	moveq	#2,d0
	move.l	d0,-(sp)
	gemdos	Fseek,10
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
