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

; ACSI2STM specific defines

a2st_version	macro
	; The following line is patched automatically by build_asm.sh
	dc.b	'2.41'			; ACSI2STM VERSION NUMBER
	endm

a2st_header	macro
	dc.b	13,'ACSI2STM '
	a2st_version
	dc.b	' by Jean-Matthieu Coulon',13,10
	dc.b	'GPLv3 license. Source & doc at',13,10
	dc.b	' https://github.com/retro16/acsi2stm',13,10
	endm

a2st_head_short	macro
	dc.b	13,'ACSI2STM '
	a2st_version
	dc.b	' by Jean-Matthieu Coulon',13,10
	dc.b	' https://github.com/retro16/acsi2stm',13,10
	endm

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
