; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2024 by Jean-Matthieu Coulon

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

	incdir	..\inc\
	include	tos.i

start:

	bra.b	load                    ; Send the load ACSI command

	org	2
	dc.b	0                       ; Patched-in variables
acsiid	dc.b	$ff                     ; Invalid values to check for correct
prmoff	dc.w	$ffff                   ; patching code in the STM32

load	st	flock.w                 ; Lock floppy controller

	bsr.w	syshook.setdmaaddr      ; Reset DMA chip
	move.w	#$0088,(a1)             ; Switch to command.
	moveq	#$09,d1                 ; Send command $09 (GemDrive boot)
	or.b	acsiid(pc),d1           ; Take ACSI id into account
	move.w	d1,(a0)                 ;

	moveq	#20,d1                  ; 100ms timeout

.await	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Prepare to read command/status
	move.w	(a0),d0                 ; Read command/status byte

	tst.b	d0                      ; 0 = success
	bne.b	load                    ; If not successful, retry

	include	syshook.s               ; Enter syshook mode

end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
