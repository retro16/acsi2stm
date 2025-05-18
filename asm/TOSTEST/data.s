; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2025 by Jean-Matthieu Coulon

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

absdir	dc.b	'Z:\TOSTEST.TMP',0
absfile	dc.b	'Z:\TOSTEST.TMP\FILE.RW',0
absdslh	dc.b	'Z:\TOSTEST.TMP\',0
absne	dc.b	'Z:\TOSTEST.TMP\NONFILE',0
absnes	dc.b	'Z:\TOSTEST.TMP\NONDIR\',0
	even

abspath	dc.l	absdir,absfile,absdslh,absne,absnes,0

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
