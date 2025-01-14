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

	incdir	..\inc\
	include	tos.i

start:

	bra.w	load                    ; Send the load ACSI command

prmoff	dc.w	$00ff                   ;
	dc.l	'XBRA','A2ST'           ;
oldvec	dc.l	$00000084               ; Old vector
	move.l	oldvec(pc),-(sp)        ; Push old vector
acsiid	moveq	#$0e,d0                 ; Set command (patched by code)

	include	syshook.s               ; Enter syshook mode

load	st	flock.w                 ; Lock floppy controller

	bsr.w	syshook.setdmaaddr      ; Reset DMA chip
	move.w	#$0088,(a1)             ; Switch to command.
	move.w	acsiid(pc),d0           ; Get ACSI id
	and.w	#$00e0,d0               ; Filter out command
	moveq	#$09,d1                 ; Send command $09 (GemDrive boot)
	or.b	d0,d1                   ; Take ACSI id into account
	move.w	d1,(a0)                 ;

.await	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Prepare to read command/status
	move.w	(a0),d0                 ; Read command/status byte

	tst.b	d0                      ; 0 = success
	bne.b	load                    ; If not successful, retry

	move.w	acsiid(pc),d0           ; Read acsi id
	bra.w	syshook.init            ; Initialize

	end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
