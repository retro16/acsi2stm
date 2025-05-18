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

; Tests Fsfirst and Fsnext

tpexec:
	print	.desc

	bsr	.clean                  ; Cleanup and set drive

	; Copy the current executable

	clr.w	-(sp)                   ; Create target file
	pea	.file                   ;
	gemdos	Fcreate,8               ;
	cmp.w	#4,d0                   ;
	blt	abort                   ;
	move.w	d0,d4                   ; d4 = dest FD

	clr.w	-(sp)                   ; Open current executable
	pea	exepath                 ;
	gemdos	Fopen,8                 ;
	cmp.w	#4,d0                   ;
	blt	abort                   ;
	move.w	d0,d3                   ; d3 = source FD

.read	pea	buffer                  ; Read executable
	move.l	#$10000,-(sp)           ;
	move.w	d3,-(sp)                ;
	gemdos	Fread,12                ;
	tst.l	d0                      ;
	bmi	abort                   ;

	pea	buffer                  ; Write to target file
	move.l	d0,-(sp)                ;
	move.w	d4,-(sp)                ;
	gemdos	Fwrite,4                ;
	tst.l	d0                      ;
	bmi	abort                   ;
	bne	.read                   ;

	move.w	d3,-(sp)                ; Close files
	gemdos	Fclose,4                ;
	move.w	d4,-(sp)                ;
	gemdos	Fclose,4                ;

	; Test usual Pexec 0

	lea	.p0,a5

	clr.l	-(sp)                   ; env=0
	pea	.tst0                   ; cmdline
	pea	.file                   ; program
	clr.w	-(sp)                   ; mode=0
	gemdos	Pexec,16                ;
	tst.w	d0                      ; Check that the program ran correctly
	bne	testfailed              ;

	clr.l	-(sp)                   ; env=0
	pea	.tst1                   ; cmdline
	pea	.file                   ; program
	clr.w	-(sp)                   ; mode=0
	gemdos	Pexec,16                ;
	cmp.w	#1,d0                   ; Check that the program ran correctly
	bne	testfailed              ;

	; Test file descriptor leak

	clr.w	-(sp)                   ; Open current executable
	pea	exepath                 ;
	gemdos	Fopen,8                 ;
	move.w	d0,d3                   ; d3 = FD before leak
	move.w	d3,-(sp)                ;
	gemdos	Fclose,4                ;

	clr.l	-(sp)                   ; env=0
	pea	.tst2                   ; cmdline
	pea	.file                   ; program
	clr.w	-(sp)                   ; mode=0
	gemdos	Pexec,16                ;
	tst.w	d0                      ; Check that the program ran correctly
	bne	testfailed              ;

	clr.w	-(sp)                   ; Open current executable
	pea	exepath                 ;
	gemdos	Fopen,8                 ;
	move.w	d0,d4                   ; d4 = FD after leak
	move.w	d4,-(sp)                ;
	gemdos	Fclose,4                ;

	lea	.fdleak,a5              ; If we got the same FD: no leak
	cmp.w	d3,d4                   ;
	beq	.fdlkok                 ;

	move.w	d3,-(sp)                ; If old FD can't be closed: no leak
	gemdos	Fclose,4                ;
	cmp.w	#EBADF,d0               ;
	bne	testfailed              ;

.fdlkok	bsr	.clean                  ; Final cleanup
	bra	testok

.clean	; Cleanup routine
	; Must converge to a clean state if executed multiple times

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv,4               ;

	pea	.file                   ;
	gemdos	Fdelete,6               ;

	rts

.desc	dc.b	'Test Pexec',$0d,$0a
	dc.b	0

.p0	dc.b	'Pexec 0 failed',$0d,$0a
	dc.b	0

.fdleak	dc.b	'File descriptor leak',$0d,$0a
	dc.b	0

.file	dc.b	'\TPEXEC.TMP',0

.tst0	dc.b	2,'/0',0
.tst1	dc.b	2,'/1',0
.tst2	dc.b	2,'/2',0

	even

; Pexec subprograms

tpexec.1:
	; Return error code 1 using relocation
	move.w	.reloc,-(sp)
	gemdos	Pterm

.reloc	dc.w	1

tpexec.2:
	; Leak file descriptor
	clr.w	-(sp)
	pea	.file
	gemdos	Fopen,8
	Pterm0

.file	dc.b	'\TPEXEC.TMP',0
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
