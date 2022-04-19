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
; ACSI device selector
; Main entry point code

devsel
	movem.l	d2-d7/a2-a5,-(sp)       ; Save registers

.again	print	.header(pc)             ; Print the header

	moveq	#0,d7                   ; Scan ACSI ids
	moveq	#'0',d6                 ;
.pnext	pchar	' '                     ;
	move.w	d6,-(sp)                ;
	gemdos	Cconout,4               ;
	pchar2	':',' '                 ;
	bsr.w	blkdev.pname            ;
	crlf                            ;
	addq.b	#1,d6                   ;
	add.b	#$20,d7                 ;
	bne.b	.pnext                  ;

	print	.devsel(pc)             ; Ask for the device id

.keyagn	gemdos	Cnecin,2                ; Wait for the selection

	cmp.b	#$1b,d0                 ; Check Esc to quit
	bne.b	.nexit                  ;
	movem.l	(sp)+,d2-d7/a2-a5       ;
	rts                             ;
.nexit
	cmp.b	#$0d,d0                 ; Check Return to refresh
	beq.w	.again                  ;

	sub.b	#'0',d0                 ; Check that a valid ID was entered
	cmp.b	#7,d0                   ;
	bhi.b	.keyagn                 ;

	lsl.b	#5,d0                   ; d7 = ACSI id in the correct format
	move.b	d0,d7                   ;

.tst	bsr.w	blkdev.tst              ; Test the device
	cmp.w	#blkerr.mchange,d0      ;
	beq.b	.tst                    ;
	tst.w	d0                      ;
	bne.b	.nready                 ;

	bsr.w	mainmenu                ; Display the main menu for this device
	bra.w	.again                  ; Go back to the device selection

.nready	print	.deverr(pc)             ; Display an error
	bsr.w	presskey                ; Wait for a key
	bra.w	.again                  ; Try again

.header	dc.b	$1b,'E'
	a2st_header
	dc.b	13,10,0

.devsel	dc.b	13,10
	dc.b	'Select the device to setup (0-7)',13,10
	dc.b	'press Return to refresh the list',13,10
	dc.b	'or press Esc to quit',13,10,0

.deverr	dc.b	7,'Device unavailable',13,10,0
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
