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

; Print the list of mounted partitions

; Example:
;   C: SD0 224M
;   D: SD0 12M
;   E: SD1 2243M

prtpart_in	macro
	movem.l	d3/a3,-(sp)
	endm

prtpart_out	macro
	movem.l	(sp)+,d3/a3
	endm

prtpart
	prtpart_in

	move.l	pun_ptr.w,a3
	move.w	pun.puns(a3),d0
	add.w	punext+pun.puns(pc),d0
	beq.b	.nodrv

	lea	prtpart.drv(pc),a0
	move.b	#'C',(a0)

	; Start at C:
	moveq	#2,d3
	bsr.b	prtpun

	moveq	#0,d3
	lea	punext(pc),a3
	bsr.b	prtpun

.end	prtpart_out
	rts

.nodrv	pea	prtpart.none(pc)
	gemdos	Cconws,6
	bra.b	.end

prtpun	; Print a pun table
	; Input:
	;  d3.w: Offset in the pun table
	;  a3: address to the pun table

	move.b	pun.pun(a3,d3),d0
	bmi.b	.noprt

	and.b	#$7,d0
	add.b	#'0',d0
	lea	prtpart.sd(pc),a0
	move.b	d0,(a0)

	pea	prtpart.txt1(pc)
	gemdos	Cconws,6

	move.w	d3,d0
	lsl.w	#1,d0
	move.w	pun.size_mb(a3,d0),d0

	bsr.w	puint

	pea	prtpart.end(pc)
	gemdos	Cconws,6
.noprt
	lea	prtpart.drv(pc),a0
	addq.b	#1,(a0)

	addq.w	#1,d3
	cmp.w	#16,d3
	bne.b	prtpun

	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
