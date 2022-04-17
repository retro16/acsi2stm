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

; ACSI to TOS error code conversion


acsierr	; Converts an ACSI ASCQ/ASC/Sense error code to a TOS error code
	; Input:
	;  d0.l:ACSI error code
	; Output:
	;  d0.l:TOS error code
	;  Z flag: set if success
	tst.b	d0
	bne.b	.nok
	moveq	#0,d0
	rts
.nok
	cmp.w	#$1103,d0
	bne.b	.nrd
	moveq	#EREADF,d0
	rts
.nrd
	cmp.w	#$0303,d0
	bne.b	.nwr
	moveq	#EWRITF,d0
	rts
.nwr
	cmp.w	#$2806,d0
	bne.b	.nmch
	moveq	#E_CHNG,d0
	rts
.nmch
	cmp.w	#$3a06,d0
	bne.b	.nnmed
	moveq	#ESECNF,d0
	rts
.nnmed
	cmp.w	#$2105,d0
	bne.b	.ninvad
	moveq	#ESECNF,d0
	rts
.ninvad
	cmp.w	#$2707,d0
	bne.b	.nprot
	moveq	#EWRPRO,d0
	rts
.nprot
	moveq	#ERR,d0
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
