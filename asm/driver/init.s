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


drvinit	; Driver initialization

	prints	'Driver initialization',13,10

.ack	move.l	#5,d1
.doack	add.l	hz200.w,d1              ;
.await	cmp.l	hz200.w,d1              ; Test timeout
	beq.b	.await                  ;
	

	; Initialize the pun_info structure
	lea	pun(pc),a0              ; a0 = local pun table

	move.l	pun.p_cookptr(a0),d0    ; Adjust p_cookptr
	add.l	a0,d0                   ;
	move.l	d0,pun.p_cookptr(a0)    ;

	lea	pun_ptr.w,a1            ;
	move.l	a0,(a1)                 ; Install the main pun table

	hkinst	getbpb                  ; Let's thrash that poor system
	hkinst	rwabs                   ; Install hooks
	hkinst	mediach                 ;

	prints	'Scan for drives',13,10

	bsr.w	scan                    ; Scan devices and mount them
	
	prints	'Driver loaded',13,10   ; Signal that everything is okay

	; TODO: set boot drive

	move.b	#$e0,d7                 ; Don't boot other drives
	rts

; Hook declarations
	hook	getbpb
	hook	rwabs
	hook	mediach

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
