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
; TOS executable version

	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i
	include	structs.i
	include	hook.i

	text
text
	Super
	bsr.w	drvinit

	clr.w	-(sp)                   ; Stay resident
	move.l	#pd...+end-text,-(sp)   ;
	gemdos	Ptermres                ;

	include	init.s
	even
	include	parts.s
	even
	include	prtpart.s
	even
	include	print.s
	even
	include	blkdev.s
	even
	include	acsicmd.s
	even
	include	rtc.s
	even
	include	rodata.s
	even

	data

	include	data.s

	bss
	include	bss.s
bss	ds.b	bss...
end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80

