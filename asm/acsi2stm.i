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

; Settings

; Maximum sector size
; Must be a power of 2 between 512 and 16384
; Setting this to more than 512 allocates much more RAM and uses slightly more
; complex algorithms.
maxsecsize	equ	16384

; Minimum time between partition rescan
; In 200hz timer units
rescanperiod	equ	200/2           ; 200/2 = 500ms

; Enable Shift+S at boot for setup
enablesetup	equ	1

; Enable serial port setup if receiving a character over serial during boot
enableserial	equ	1

; Maximum number of partitions in the partitioning tool
maxparts	equ	4

; Number of displayed partitions in the partitioning tool
partlines	equ	4

; Constants
a2st_version	macro
	; The following line is patched automatically by build_asm.sh
	dc.b	'3.01'			; ACSI2STM VERSION NUMBER
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

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
