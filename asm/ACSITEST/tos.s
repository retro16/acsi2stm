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

; Test suite for ACSI2STM >= 4.0
; Tests ACSI drives. Targets ACSI2STM, but should be compatible with other ACSI
; drives if they implement SCSI.

	incdir	..\inc\

	; Include declarations
	include	tos.i

	; Of course, we want optimized code ! Who doesn't ?
	opt	O+                      ; Enable all optimizations
	opt	OW1-                    ; Disable branch optim warnings
	opt	D+                      ; Enable debugging symbols

	text

_start:	; Standard code preamble

	lea	_stacktop,sp            ; Initialize stack

	move.l	sp,d0                   ; Shrink memory
	lea	_start-$100,a0          ;
	sub.l	a0,d0                   ;
	move.l	d0,-(sp)                ;
	pea	_start-$100             ;
	clr.w	-(sp)                   ;
	gemdos	Mshrink,12              ;

	Super	                        ; Switch to super user mode

.main	bsr	main                    ; Call main
.pterm0	Pterm0	                        ; Exit cleanly

	; Include main files
	include	main.s
	even
	data
	include	data.s
	even
	bss
	include	bss.s
	even

_stack:	; Put stack in BSS, after everything else
	ds.b	4096
_stacktop:
	end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
