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

debug.out
	st	flock.w
	move.w	d0,-(sp)
	clr.w	d0
	move.w	#$88,dmactrl.w
	move.l	#$000f008a,dma.w
	move.w	6(sp),d0
	bsr.b	.send
	move.w	#$8a,dmactrl.w
	move.b	8(sp),d0
	bsr.b	.send
	subq.w	#1,4(sp)
	beq.b	.end
	move.w	#$8a,dmactrl.w
	move.b	9(sp),d0
	bsr.b	.send
	subq.w	#1,4(sp)
	beq.b	.end
	move.w	#$8a,dmactrl.w
	move.b	10(sp),d0
	bsr.b	.send
	subq.w	#1,4(sp)
	beq.b	.end
	move.w	#$8a,dmactrl.w
	move.b	11(sp),d0
	bsr.b	.send
	move.w	(sp)+,d0
.end	sf	flock.w
	rts

.send	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.send
	move.w	d0,dma.w
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
