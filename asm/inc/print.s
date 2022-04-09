; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2022 by Jean-Matthieu Coulon

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

; Print routines

phex_framein	macro
	movem.l	d0-d5/a0-a2,-(sp)
	endm

phex_frameout	macro
	movem.l	(sp)+,d0-d5/a0-a2
	endm

phbyte	; Print an hexadecimal byte
	; Input:
	;  d0.b: Number to print
	; Output:
	;  Preserves all registers except CCR

	phex_framein

	move.b	d0,d3
	ror.l	#8,d3
	moveq	#1,d4
	bra.b	phex

phshort	; Print a short hexadecimal number
	; Input:
	;  d0.w: Number to print
	; Output:
	;  Preserves all registers except CCR

	phex_framein

	move.w	d0,d3
	swap	d3
	moveq	#3,d4
	bra.b	phex

phlong	; Print a long hexadecimal number
	; Input:
	;  d0.l: Number to print
	; Output:
	;  Preserves all registers except CCR

	phex_framein

	move.l	d0,d3
	moveq	#7,d4

phex	; Subroutine for phbyte, phshort and phlong
	; Do not call directly
	; Input:
	;  d3: value to print in the MSB
	;  d4.w: number of digits

.loop	rol.l	#4,d3
	move.w	d3,d0
	and.w	#$f,d0
	
	cmp.w	#$a,d0
	blt.b	.digit

	add.w	#'A'-$a,d0
	bra.b	.prtd1

.digit	add.w	#'0',d0

.prtd1	move.w	d0,-(sp)
	gemdos	Cconout,4

	dbra	d4,phex

	phex_frameout
	rts


puint_framein	macro
	movem.l	d0-d5/a0-a2,-(sp)
	endm

puint_frameout	macro
	movem.l	(sp)+,d0-d5/a0-a2
	endm

puint	; Print a short unsigned number as decimal
	
	puint_framein

	tst.w	d0
	bne.b	.notnul

	move.w	#'0',-(sp)              ; Handle '0' as an exception
	gemdos	Cconout,4               ; because it's easier like that

	puint_frameout
	rts

.notnul	; Compute digits and push them on the stack
	clr.w	-(sp)

	moveq	#0,d2
	move.w	d0,d2

.nxtdig	divu	#10,d2
	tst.l	d2
	beq.b	.print
	swap	d2
	add.w	#'0',d2
	move.w	d2,-(sp)
	clr.w	d2
	swap	d2

	bra.b	.nxtdig

.print	; Print digits on the stack (in reverse order)
	gemdos	Cconout,4
	tst.w	(sp)
	bne.b	.print

	addq.l	#2,sp

	puint_frameout
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
