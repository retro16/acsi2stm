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

	org	0

; Microprograms injected by the GemDrive driver
; All programs are 4 bytes long
; a2 points at the current DMA address

PGM_NOP:
	nop                             ; Currently unused
	nop

PGM_TRAP:
	trap	#0                      ; Trap number patched by the STM32
	move.l	d0,-(sp)

PGM_PUSHSP:
        move.l	sp,-(sp)
	nop	                        ; Align on 4 bytes boundary

PGM_ADDSP:
	lea	0(sp),sp                ; Stack offset patched by the STM32

PGM_READSPB:
	move.l	(sp)+,a0
	move.b	(a0),-(sp)

PGM_READSPW:
	move.l	(sp)+,a0
	move.w	(a0),-(sp)

PGM_READSPL:
	move.l	(sp)+,a0
	move.l	(a0),-(sp)

PGM_WRITESPB:
	move.l	(sp)+,a0
	move.b	(sp)+,(a0)

PGM_WRITESPW:
	move.l	(sp)+,a0
	move.w	(sp)+,(a0)

PGM_WRITESPL:
	move.l	(sp)+,a0
	move.l	(sp)+,(a0)

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
