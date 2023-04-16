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

; Atari ST hardware registers and macros

; Align code to 16 bytes boundary for DMA transfers
align16	macro
.\@
	ifne	.\@&$f
	ds.b	$10-(.\@&$f)
	endif
	endm

reboot	macro
	move.l	4.w,a0
	jmp	(a0)
	endm

leal	macro	; lea, long version. Example: leal abcd,a0 will lea abcd(pc)
.leal\@	
	lea	.leal\@(pc),\2
	opt	O-
	add.l	#(\1)-.leal\@,\2
	opt	O+
	endm

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
