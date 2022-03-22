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

; ACSI2STM DMA quick test
; Boot sector wrapper

	org	0

	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

	pea	msg(pc)                 ; Display the header message
	gemdos	Cconws,6                ;

	include	main.s                  ; Run the main routine

	tst.w	d0                      ; If d0 = 0, there was an error
	bne.b	waitkey                 ; wait for a key press

	pea	nocard(pc)              ; Display "No SD card" because that's
	gemdos	Cconws,6                ; what this sector is all about

	rts

waitkey	gemdos	Cconin,2                ; Wait for a key
        rts

	include	acsi_drv.s
	include	rodata.s
	include	data.s

	even
glob
	include	glob.s

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
