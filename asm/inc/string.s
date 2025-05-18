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

; String functions
; Algorithms aren't really optimized, and if they are, they are optimized for
; smallest size

strncpy:
	; Copy a nul-terminated string, with maximum length
	; Input:
	;  a0: destination
	;  a1: source
	;  d1.w: maximum length (must be 1 or more)

	subq	#1,d1
.cpy	move.b	(a1)+,(a0)+
	dbne	d1,.cpy
	rts

strncmp:
	; Compare 2 strings together
	; Input:
	;  a0: string 1
	;  a1: string 2
	;  d1.l: maximum length (0 = unlimited)
	; Output:
	;  Z: set if equal or maximum length reached

	subq	#1,d1
	beq.b	.ret

	move.b	(a0)+,d0
	move.b	(a1)+,d2
	beq.b	.end2

	cmp.b	d0,d2
	beq.b	strncmp

.ret	rts

.end2	tst.b	d0
	bra.b	.ret

strnlen:
	; Compute string length
	; Input:
	;  a0: string
	;  d1.w: maximum length (must be 1 or more)
	; Output:
	;  d0.w: string length

	moveq	#-1,d0
	subq	#1,d1
.cmp	tst.b	(a0)+
	addq	#1,d0
	dbne	d1,.cmp
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
