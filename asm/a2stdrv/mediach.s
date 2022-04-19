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

; ACSI2STM integrated driver
; Mediach handler

mediach_handler
	; d1 = current device

	bsr.b	.chk                    ; Do a quick flag check

.nmch	move.w	d7,-(sp)

	bsr.w	rescan                  ; Rescan and remount if necessary
	bsr.w	getpart                 ; Find the partition matching device

	cmp.b	#$ff,d7                 ; Check if we own the partition
	bne.b	.mountd                 ;

	move.w	(sp)+,d7                ; Not our drive: pass the call
	hkchain	bios                    ;

.mountd	move.w	(sp)+,d7                ; Restore d7
	bsr.b	.chk                    ; Check flag again because of rescan

	moveq	#0,d0                   ; Flag was not set
	rte

.chk	lea	mchmask(pc),a0          ; Check the flag
	move.l	(a0),d0                 ;
	btst	d1,d0                   ;
	rtseq	                        ;

	bclr	d1,d0                   ; Flag was set: clear it
	move.l	d0,(a0)                 ;
	
	moveq	#2,d0                   ; Return media change
	addq.l	#4,sp                   ; Skip subroutine return
	rte	                        ; Return BIOS call directly

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
