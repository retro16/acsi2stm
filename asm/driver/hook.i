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

; Hook macros

	; Declare a hook
	; Parameter:
	;  \1 name of the hook
	; Includes the file <hook>.s as the implementation
hook	macro
	even
	dc.b	'XBRA','A2ST'
hook.\1.old
	ds.l	1
hook.\1
	include	\1.s                    ; Implementation
	even
	endm

	; Call the next function in the call chain of a hook
	; Parameter:
	;  \1 name of the hook
hkchain	macro
	move.l	hook.\1.old(pc),a0      ; Forward to the previous handler
	jmp	(a0)                    ;
	endm

	; Install a hook
	; Parameter:
	;  \1 name of the hook
hkinst	macro
	lea	hook.\1.old(pc),a0
	move.l	\1.vector.w,(a0)+
	move.l	a0,\1.vector.w
	endm

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
