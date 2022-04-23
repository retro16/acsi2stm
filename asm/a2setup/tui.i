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

; ACSI2STM text user interface macros

termini	macro
	clr.w	-(sp)
	bsr.w	tui.termctrl
	endm

cls	macro
	move.w	#2,-(sp)
	bsr.w	tui.termctrl
	endm

savepos	macro
	move.w	#4,-(sp)
	bsr.w	tui.termctrl
	endm

loadpos	macro
	move.w	#6,-(sp)
	bsr.w	tui.termctrl
	endm

curson	macro
	move.w	#8,-(sp)
	bsr.w	tui.termctrl
	endm

cursoff	macro
	move.w	#10,-(sp)
	bsr.w	tui.termctrl
	endm

clrtail	macro
	move.w	#12,-(sp)
	bsr.w	tui.termctrl
	endm

clrbot	macro
	move.w	#14,-(sp)
	bsr.w	tui.termctrl
	endm

crlf	macro
	ifc	'','\1'
	move.w	#16,-(sp)
	bsr.w	tui.termctrl
	elseif
	move.w	#(\1)-1,-(sp)
	bsr.w	tui.crlf
	endc
	endm

hlon	macro
	move.w	#18,-(sp)
	bsr.w	tui.termctrl
	endm

hloff	macro
	move.w	#20,-(sp)
	bsr.w	tui.termctrl
	endm

backspc	macro
	move.w	#22,-(sp)
	bsr.w	tui.termctrl
	endm

clrline	macro
	move.w	#24,-(sp)
	bsr.w	tui.termctrl
	endm

setterm	macro
	lea	tui.curterm(pc),a0
	lea	tui.\1(pc),a1
	move.l	a1,(a0)
	endm

kbflush	macro
	bsr.w	kbflush
	endm

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
