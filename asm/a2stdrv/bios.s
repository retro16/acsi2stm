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

bios_handler
	move.w	bss+traplen(pc),d0
	lea	0(sp,d0),a2
	move.w	(a2)+,d1

	cmp.w	#Rwabs,d1
	blt.b	.chain
	beq.b	rwabs_handler

	cmp.w	#Drvmap,d1
	bgt.b	.chain
	beq.w	drvmap_handler

	cmp.w	#Mediach,d1
	bne.b	.nmch
	move.w	(a2),d1
	bra.w	mediach_handler
.nmch
	cmp.w	#Getbpb,d1
	bne.b	.chain
	move.w	(a2),d1
	bra.w	getbpb_handler

.chain
	hkchain	bios

	include	rwabs.s
	include	drvmap.s
	include	mediach.s
	include	getbpb.s

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
