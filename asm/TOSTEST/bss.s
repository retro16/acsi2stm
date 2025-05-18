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

drvmask	ds.l	1                       ; Available drives

; Drive selection
drive	ds.w	1                       ; Drive to apply the test to

; Statistics
success	ds.w	1                       ; Successful tests
failed	ds.w	1                       ; Failed tests

; Stack pointer at the beginning of main, used by abort
mainsp	ds.l	1

; Startup status
strtdrv	ds.w	1                       ; Startup drive
exepath	ds.b	1024                    ; Path of the current executable

; Buffer
buffer	ds.b	65536+4                 ; Big buffer for file operations

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
