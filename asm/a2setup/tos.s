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

; ACSI2STM setup program
; TOS program version

	; Flag to indicate that we don't run from the STM32 flash
stm32flash	equ	0

	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

	include	bss.i

	opt	O+

	text

	Super	                        ; Enter supervisor mode
	lea	stacktop,sp             ; Set local stack

	bsr.w	main

	Pterm0                          ; Exit cleanly
main
	include	text.s                  ; Subroutines and code includes

driver
	incbin	..\a2stdrv\a2stdrv.bin

	data

	include	data.s                  ; Initialized data

	bss
bss	ds.b	bss...                  ; Allocate BSS from the bss... struct
	ds.b	1024                    ; Stack size
stacktop

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
