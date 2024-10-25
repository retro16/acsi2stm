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

; File descriptors

fdread	ds.w	1                       ; Read 1 byte
fdseek1	ds.w	1                       ; Seek to offset 1
fdseek2	ds.w	1                       ; Seek to offset 2
fdwri	ds.w	1                       ; Write 1 byte after swap
fdwpend	ds.w	1                       ; Write 1 byte before write

buffer	ds.b	16                      ; Buffer for file operations

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
