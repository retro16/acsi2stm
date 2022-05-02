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

; ACSI2STM setup program
; Main menu

mainmenu
	enter

	cls
	print	.devsld(pc)             ; Print selected device
	savepos                         ;

	print	.menu(pc)               ;

	lea	bss+lasterr(pc),a0      ; Clear last error
	clr.w	(a0)                    ;

.refrsh	loadpos	                        ; Print device name
	bsr.w	blkdev.pname            ;
	exitne	                        ; Exit immediately in case of error

.wait	bsr.w	blkdev.waitkey          ; Wait for a key or a device event

	cmp.w	#blkerr.mchange,d1      ; Check media change
	beq.b	.refrsh                 ;

	lea	bss+lasterr(pc),a0      ; If error value changed
	cmp.w	(a0),d1                 ;
	beq.b	.nrfrsh                 ;
	move.w	d1,(a0)                 ; Store new value
	bra.b	.refrsh                 ; Refresh display
.nrfrsh
	gemdos	Cnecin,2

	cmp.b	#$1b,d0                 ; ESC key to return
	exiteq                          ;

	and.b	#$df,d0                 ; Turn everything upper case

	cmp.b	#'T',d0
	beq.w	a2sttest

	cmp.b	#'C',d0
	beq.w	timeset

	cmp.b	#'S',d0
	beq.w	formatsd

	cmp.b	#'I',d0
	beq.w	creatimg

	cmp.b	#'Q',d0
	beq.w	quickset

	cmp.b	#'P',d0
	beq.w	parttool

	bra.b	.wait

.devsld	dc.b	'Selected device:',0
.menu	dc.b	13,10,10
	dc.b	'Main menu:',13,10
	dc.b	10
	dc.b	'  T:Test ACSI2STM',13,10
	dc.b	'  C:Clock setup',13,10
	dc.b	'  S:Format SD for PC',13,10
	dc.b	'  I:Create image',13,10
	dc.b	'  Q:Quick setup',13,10
	dc.b	'  P:Partition/format tool',13,10
	dc.b	10
	dc.b	'Esc:Back',13,10
	dc.b	0
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
