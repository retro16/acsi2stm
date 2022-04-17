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
; Block device commands data section

blkdev.rw.c	; Read-write commands
	dc.b	9                       ; 9 intermediate bytes
	dc.b	$1f,$28                 ; Read extended command (patched for wr)
	dc.b	$00                     ; Obsolete
	dc.b	$00,$00,$00,$00         ; Block number (patched)
	dc.b	$00                     ; LUN
	dc.b	$00,$00                 ; Block count (patched)
	dc.b	$00                     ; Control byte
	even

blkdev.cim.c	; Create an image on the SD card (ACSI2STM extension)
	dc.b	9
	dc.b	$1f,$20
	dc.b	'A2STCIm'
	dc.b	$00,$00                 ; Patched to specify image size
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
