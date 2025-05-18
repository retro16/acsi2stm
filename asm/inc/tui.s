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

; Text user interface routines

tui_in	macro
	movem.l	d0-d5/a0-a2,-(sp)
	endm

tui_out	macro
	movem.l	(sp)+,d0-d5/a0-a2
	endm

tui.phbyte:
	; Print an hexadecimal byte
	; Input:
	;  d0.b: Number to print
	; Output:
	;  Preserves all registers except CCR

	tui_in

	move.b	d0,d3
	ror.l	#8,d3
	moveq	#1,d4
	bra.b	tui.phex

tui.phshort:
	; Print a short hexadecimal number
	; Input:
	;  d0.w: Number to print
	; Output:
	;  Preserves all registers except CCR

	tui_in

	move.w	d0,d3
	swap	d3
	moveq	#3,d4
	bra.b	tui.phex

tui.phlong:
	; Print a long hexadecimal number
	; Input:
	;  d0.l: Number to print
	; Output:
	;  Preserves all registers except CCR

	tui_in

	move.l	d0,d3
	moveq	#7,d4

tui.phex:
	; Subroutine for phbyte, phshort and phlong
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

	dbra	d4,tui.phex

	tui_out
	rts


tui.puint
	; Print a long unsigned number as decimal
	; Input:
	;  d0.l: Number to display
	;  d1.w: Minimum digit count
	;  d1[16]: Set to fill with spaces
	
	tui_in

	move.l	d1,d4

.notnul	; Compute digits and push them on the stack
	clr.w	-(sp)

.nxtdig	bsr.b	tui.divby10
	move.l	d1,d0
	or.l	d2,d1
	beq.b	.zfill
	add.w	#'0',d2
	move.w	d2,-(sp)
	subq.w	#1,d4

	bra.b	.nxtdig

.zfill	; Leading zeroes/spaces
	moveq	#'0',d2
	btst	#16,d4
	beq.b	.fill
	moveq	#' ',d2
.fill	subq.w	#1,d4
	bmi.b	.print
	move.w	d2,-(sp)
	bra.b	.zfill

.print	; Print digits on the stack (in reverse order)
	gemdos	Cconout,2
	tst.w	(sp)+
	bne.b	.print

.end	tui_out
	rts

tui.divby10
	; Divide by 10
	; Input:
	;  d0.l: Numerator
	; Output:
	;  d1.l: Quotient
	;  d2.w: Remainder
	; Alters:
	;  d3.w

	moveq	#31,d3
	moveq	#0,d2
	moveq	#0,d1

.loop	lsl.w	d2                      ; R := R << 1

	btst	d3,d0                   ; R(0) := N(i)
	beq.b	.rz                     ;
	bset	#0,d2                   ;
.rz
	cmp.w	#10,d2                  ; If R >= 10
	blt.b	.nr                     ;
	sub.w	#10,d2                  ; R := R - 10
	bset	d3,d1                   ; Q(i) := 1
.nr
	dbra	d3,.loop
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
