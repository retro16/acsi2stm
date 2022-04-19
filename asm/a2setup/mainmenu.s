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

	print	.device(pc)
	bsr.w	blkdev.pname
	retne

	print	.menu(pc)
.retry	gemdos	Cnecin,2

	cmp.b	#$1b,d0                 ; ESC key to return
	reteq                           ;

	and.b	#$df,d0                 ; Turn everything upper case

	cmp.b	#'T',d0
	beq.w	a2sttest

	cmp.b	#'C',d0
	beq.w	timeset

	cmp.b	#'S',d0
	beq.w	formatsd

	cmp.b	#'I',d0
	beq.w	creatimg

	cmp.b	#'P',d0
	beq.w	parttool

	bell

	bra.b	.retry

.device	dc.b	$1b,'E'
	dc.b	'Selected device: ',0

.menu	dc.b	13,10,13,10             ; Main menu text
	dc.b	'Main menu:',13,10
	dc.b	13,10
	dc.b	'  T: Test the ACSI2STM device',13,10
	dc.b	'  C: Real-time clock setup',13,10
	dc.b	'  S: Format the SD card (FAT32/ExFAT)',13,10
	dc.b	'  I: Create an image on the SD card',13,10
	dc.b	'  P: Partition/format tool',13,10
	dc.b	13,10
	dc.b	'Esc: Back to device selection',13,10
	dc.b	13,10,0
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
