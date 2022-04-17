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
; Disk image creation

creatimg
	bsr.w	blkdev.tsta2st          ; Check if the image can be created
	cmp.w	#3,d0                   ;
	blt.b	.no                     ;
	bne.b	.new                    ;

	print	.owrite(pc)             ; Overwrite the current image
	bsr.w	areyousure              ;
	beq.b	.getsz                  ;
.rstart	restart                         ;

.new	print	.newimg(pc)             ; Create a new image on the SD card

.getsz	print	.asksz(pc)              ; Ask the size
	lea	bss+buf(pc),a0          ;
	move.l	#4095,d0                ;
	bsr.w	readint                 ;

	lsl.l	#4,d0                   ; Convert to 64k blocks
	bsr.w	blkdev.cim              ; Ask the STM32 to create the image

	tst.b	d0
	bne.b	.no

	print	.wait(pc)
	bsr.w	blkdev.wait

	restart

.no	print	.cannot(pc)
	bsr.w	presskey
	restart

.newimg	dc.b	'Create a new image on the SD card',13,10,0

.owrite	dc.b	'An image already exists. All data will',13,10
	dc.b	'be cleared if you press Y.',13,10,0

.asksz	dc.b	'Image size in Mb:',0

.cannot	dc.b	7,'Cannot create the image',13,10,0

.wait	dc.b	'Creating the image ...',13,10
	dc.b	'This can take a very long time',13,10,0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
