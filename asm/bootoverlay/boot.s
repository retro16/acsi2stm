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

; Boot sector injected into non-bootable hard disks

	org	0
	incdir	..\inc
	include	acsi2stm.i
	include	tos.i

boot	move.b	d7,d0                   ; Get acsi id in d0
	lsr.b	#5,d0                   ; Compute acsi id (0-7)
	lea	.acsiid(pc),a0          ; Patch acsi id in the text
	add.b	d0,(a0)                 ; Add acsi id to '0'

	pea	.msg(pc)                ; Display the message
	gemdos	Cconws,6                ;

	gemdos	Cconin,2		; Wait until a key is pressed

	rts

.msg	a2st_header
	dc.b	13,10,'SD'
.acsiid	dc.b	'0 is not bootable !',13,10
	dc.b	'To use this SD card, you need a driver',13,10
	dc.b	13,10,0

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
