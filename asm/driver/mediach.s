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
; Mediach handler

; int32_t Mediach ( int16_t dev );

; Parameters
		rsreset
		rs.l	1
mediach.dev	rs.w	1

	move.w	mediach.dev(sp),d1	; d1 = current device

	lea	mchmask(pc),a0          ;
	move.l	(a0),d0                 ; d0 = change mask

	btst	d1,d0                   ; Test the flag as-is
	beq.b	.query                  ;

	bclr	d1,d0                   ; Clear the flag
	move.l	d0,(a0)                 ;

	moveq	#2,d0                   ; Return "changed"
	rts

.query	; Query the device
	move.w	d7,-(sp)

	bsr.w	getpart
	cmp.b	#$ff,d7
	bne.b	.mountd

	move.w	(sp)+,d7                ; Pass the call
	hkchain	mediach

.mountd
	cmp.l	#$ffffffff,d2           ; Test if no medium
	bne.b	.hasmed                 ;

	bsr.w	remount                 ; Try to remount the drive

	moveq	#0,d0                   ; Return no change for now
	move.w	(sp)+,d7
	rts

.hasmed	bsr.w	blk.tst

	cmp.l	#$2806,d0               ; Check for media changed
	bne.b	.nmch                   ;
	moveq	#2,d0                   ; Return "changed"
	move.w	(sp)+,d7
	rts

.nmch	moveq	#0,d0
	move.w	(sp)+,d7
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
