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

; ACSI2STM integrated driver
; Print number routine

puint_in	macro
	movem.l	d0-d3/a0-a2,-(sp)
	endm

puint_out	macro
	movem.l	(sp)+,d0-d3/a0-a2
	endm

puint	; Print a short unsigned number as decimal
	
	puint_in

	tst.w	d0
	bne.b	.notnul

	move.w	#'0',-(sp)              ; Handle '0' as an exception
	gemdos	Cconout,4               ; because it's easier like that

	puint_out
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
	gemdos	Cconout,2
	tst.w	(sp)+
	bne.b	.print

	puint_out
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
