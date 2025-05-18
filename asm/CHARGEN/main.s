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

; Generates a folder containing files with all special characters in their names

main:
	print	.header                 ; Print program header

	gemdos	Cnecin,2                ; Get key
	cmp.b	#$1b,d0                 ;
	beq.b	.end                    ;

	print	.start                  ;

	pea	.folder                 ; Create the folder
	gemdos	Dcreate,6               ;
	tst.l	d0                      ;
	bne	.perror                 ;

	pea	.folder                 ; Go into the folder
	gemdos	Dsetpath,6              ;
	tst.l	d0                      ;
	bne	.perror                 ;

	lea	buffer,a4               ; a4 = buffer
	moveq	#0,d4                   ; d4 = index in buffer

	move.w	#'.A',d5                ; d5 = file extension

	moveq	#1,d3                   ; d3 = character

.nxtchr	bsr	.append                 ; Append the character

	addq.w	#1,d3                   ;

	cmp.w	#$20,d3                 ; Skip $20 -> $7f
	bne.b	.notspc                 ;
	move.w	#$7f,d3                 ;
	bra	.nxtchr                 ;

.notspc	tst.b	d3                      ;
	bne	.nxtchr                 ;

	print	.fini                   ; Finished !

.keyend	gemdos	Cnecin,2                ; Wait for a key and exit
.end	rts	                        ; Success

.perror	print	.err                    ; Print error and exit
	bra.b	.keyend                 ;

.append	move.b	d3,0(a4,d4.w)           ; Write the character in the buffer
	addq.w	#1,d4                   ; Increment index

	cmp.w	#8,d4                   ; If the name is full, generate the file
	beq.b	.gen                    ;

	rts	                        ;

.gen	move.w	d5,0(a4,d4.w)           ; Append '.A' - '.Z'
	addq.w	#1,d5                   ;
	clr.b	2(a4,d4.w)              ; Terminate file name
	moveq	#0,d4                   ; Reset file name index

	clr.w	-(sp)                   ; Create a file
	pea	(a4)                    ;
	gemdos	Fcreate,8               ;
	tst.l	d0                      ;
	bmi	.perror                 ;

	move.w	d0,-(sp)                ; Close the file descriptor
	gemdos	Fclose,4                ;

	rts

.header	dc.b	$1b,'E','Character generator v'
	incbin	..\..\VERSION
	dc.b	$0d,$0a
	dc.b	'By Jean-Matthieu Coulon',$0d,$0a
	dc.b	'https://github.com/retro16/acsi2stm',$0d,$0a
	dc.b	'License: GPLv3',$0d,$0a
	dc.b	$0a
	dc.b	'Generates a folder containing files with',$0d,$0a
	dc.b	'all special characters in their names.',$0d,$0a
	dc.b	$0a
	dc.b	'Press a key to start or ESC to quit.',$0d,$0a
	dc.b	$0a
	dc.b	0

.folder	dc.b	'CHARGEN.OUT',0

.start	dc.b	'Generating ...',$0d,$0a
	dc.b	0

.fini	dc.b	'Finished.',$0d,$0a
	dc.b	0

.err	dc.b	'Error.',$0d,$0a
	dc.b	0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
