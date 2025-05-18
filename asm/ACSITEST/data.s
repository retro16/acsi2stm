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

buftest.read
	dc.b	8
	dc.b	$1f,$3c,$02,$00         ; Read data buffer 0
	dc.b	$00,$00,$00             ; Offset 0
buftest.read.len
	dc.b	$00,$00,$00             ; Read size in bytes
	dc.b	$00                     ;

buftest.write
	dc.b	8
	dc.b	$1f,$3b,$02,$00         ; Write data buffer 0
	dc.b	$00,$00,$00             ; Offset 0
buftest.write.len
	dc.b	$00,$00,$00             ; Write size in bytes
	dc.b	$00                     ;

	even
	ds.b	1                       ; Align block address
surftest.read6
	dc.b	3
	dc.b	$08
surftest.read6.blk
	dc.b	$00,$00,$00
	dc.b	$01
	dc.b	$00

	even
	ds.b	1                       ; Align block address
surftest.read10
	dc.b	8
	dc.b	$28,$00
surftest.read10.blk
	dc.b	$00,$00,$00,$00
	dc.b	$00
	dc.b	$00,$01
	dc.b	$00

	even
	ds.b	1                       ; Align block address
surftest.write6
	dc.b	3
	dc.b	$0a
surftest.write6.blk
	dc.b	$00,$00,$00
	dc.b	$01
	dc.b	$00

	even
	ds.b	1                       ; Align block address
surftest.write10
	dc.b	8
	dc.b	$2a,$00
surftest.write10.blk
	dc.b	$00,$00,$00,$00
	dc.b	$00
	dc.b	$00,$01
	dc.b	$00

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
