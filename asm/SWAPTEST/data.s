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


	; Paths
root	dc.b	'\',0
topdir	dc.b	'\SWAPTEST.TMP',0
abs1sub	dc.b	'Z:\SWAPTEST.TMP\DISK1.DIR\SUB1',0
dsk1dir	dc.b	'DISK1.DIR',0
dsk1sub	dc.b	'DISK1.DIR\SUB1',0
dsk2dir	dc.b	'DISK2.DIR',0
comdir	dc.b	'COMMON.DIR',0
	even
pathcnt	equ	4
paths	dc.l	abs1sub,dsk1dir,dsk2dir,comdir

ordf	dc.b	'OPENRD.FIL',0
owrf	dc.b	'OPENWR.FIL',0
wrpendf	dc.b	'WRITPEND.FIL',0
	even
filecnt	equ	3
files	dc.l	ordf,owrf,wrpendf

srchpat	; Search patterns
abssch	dc.b	'Z:\*.*',0
dsk1sch	dc.b	'DISK1.DIR\*.*',0
dsk2sch	dc.b	'DISK2.DIR\*.*',0
topsch	dc.b	'*.*',0
	even
srchcnt	equ	4
srches	dc.l	abssch,dsk1sch,dsk2sch,topsch

	; Absolute paths to patch at drive selection
abscnt	equ	2
abspath	dc.l	abs1sub,abssch

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
