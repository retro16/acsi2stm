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
; Tests TOS / GEMDOS filesystem functions

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

	; Parse command-line
	tst.b	_start-128              ; Do we have parameters ?
	bne.b	.params                 ;

	; No parameters: just call main and exit
.main	bsr	main                    ; Call main
.pterm0	Pterm0	                        ; Exit cleanly

.params	cmp.b	#'/',_start-127         ; Check for '/' character
	bne.b	.main                   ;

	move.b	_start-126,d0           ; Read parameter
	sub.b	#'0',d0                 ; Check parameter range
	bmi.b	.main                   ;
	cmp.b	#'0',d0                 ;
	bgt.b	.main                   ;

	lsl.b	#1,d0                   ; Parameter jump table
	ext.w	d0                      ;
	move.w	.prmtbl(pc,d0.w),d0     ;
.prm	jmp	.prmtbl(pc,d0.w)        ;
.prmtbl	dc.w	.pterm0-.prmtbl         ; /0 = Pterm0
	dc.w	tpexec.1-.prmtbl        ; /1
	dc.w	tpexec.2-.prmtbl        ; /2

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
