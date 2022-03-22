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
; Initialized data

sdid  	dc.b	'SD'
acsiid	dc.b	'0: ',0

	even
acsi.echo
	dc.b	9                       ; 9 intermediate bytes
	dc.b	$1f                     ; Extended ICD command
acsi.echorw
	dc.b	$3b,$0a                 ; Write echo buffer
	dc.b	$00,$00,$00,$00         ; Buffer id and offset
	dc.b    $00,$02,$00             ; 512 bytes
	dc.b	$00                     ; Control byte

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
