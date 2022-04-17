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

; Atari ST hardware registers and macros

; DMA hardware registers

gpip=$fffffa01
dma=$ffff8604
dmadata=dma
dmactrl=dma+2
dmahigh=dma+5
dmamid=dma+7
dmalow=dma+9

; Video registers

screenh=$ffff8201
screenm=$ffff8203
screenpal=$ffff8240

; Align code to 16 bytes boundary for DMA transfers
align16	macro
.\@
	ifne	.\@&$f
	ds.b	$10-(.\@&$f)
	endif
	endm

; Create a stack frame and save current PC in it
; Use the restart macro to go back to this point
; Use the return macro to unwind stack and do a rts
; Alters a0 and a6.
enter	macro
	link	a6,#-4
	lea	._enter_\@(pc),a0
	move.l	a0,(sp)
._enter_\@
	endm

; Unwind stack and jump back to the matching enter call
; Alters a0.
restart	macro
	lea	-4(a6),sp
	move.l	(sp),a0
	jmp	(a0)
	endm

; Restart if equal
rsteq	macro
	bne.b	.rst\@
	restart
.rst\@
	endm

; Restart if not equal
rstne	macro
	beq.b	.rst\@
	restart
.rst\@
	endm

; Exit the stack frame created by enter but do not return
; Alters a6
exit	macro
	unlk	a6
	endm

; Unwind stack and execute rts, returning to the caller of the "enter" macro
; Input:
;  \1: Value to moveq into d0. d0 is not modified if ignored.
; Alters a6
return	macro
	ifnc	'','\1'
	moveq	#\1,d0
	endc
	unlk	a6
	rts
	endm

; Return if equal
reteq	macro
	bne.b	.ret\@
	return	\1
.ret\@
	endm

; Return if not equal
retne	macro
	beq.b	.ret\@
	return	\1
.ret\@
	endm

; Conditional branch to subroutines

bsreq	macro
	bne.b	.bsr\@
	bsr.\0	\1
.bsr\@
	endm

bsrne	macro
	beq.b	.bsr\@
	bsr.\0	\1
.bsr\@
	endm

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
