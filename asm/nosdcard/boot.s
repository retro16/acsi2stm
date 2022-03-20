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

; Boot sector that indicates that no SD card is present

	org	0
	incdir	..\inc
	include	acsi2stm.i
	include	tos.i

boot	movem.l d0-d7/a0-a6,-(sp)       ; Keep registers intact

	lsr.b	#5,d7			; Compute acsi id (0-7)
	lea	.acsiid(pc),a0		; Patch acsi id in the text
	add.b	d7,(a0)			; Add acsi id to '0'

	pea	.msg(pc)		; Display the message
	gemdos	Cconws,6		;

	movem.l (sp)+,d0-d7/a0-a6	; Restore registers
	rts

.msg	acsi2stm_header
	dc.b	13,10
	dc.b	'SD'
.acsiid	dc.b	'0: no SD card',13,10
	dc.b	13,10,0

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81
