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
	setterm	vt52

	ifne	stm32flash
	gemdos	Cauxis,2                ; Set output to VT100 if running from
	tst.w	d0                      ; the serial port
	beq.b	.screen                 ;
	setterm	vt100                   ;
.screen
	leal	driver,a0               ; Read driver using 1byte command
	moveq	#$d,d1                  ;
	bsr.w	blkdev.1byte            ;
	endc                            ;

	enter

	termini
	print	.header(pc)             ; Print the header
	savepos
	print	.devslt(pc)             ; Print device selection text
	loadpos

	moveq	#0,d7                   ; Reset to device 0
	lea	.devid(pc),a0           ;
	move.b	#'0',(a0)               ;

	moveq	#0,d5                   ; Scan interval: start fast

.scan	print	.dev(pc)                ; Scan device
	bsr.w	blkdev.pname            ; Print device name
	clrtail	                        ; Clear to end of line

	move.l	hz200.w,d3              ; d3 = device scan timeout
	add.l	d5,d3

	lea	.devid(pc),a0           ; Select next device
	addq.b	#1,(a0)                 ;
	add.b	#$20,d7                 ;
	bne.b	.kwait                  ;

	moveq	#30,d5                  ; Increase scan period for refreshes

.scan0	lea	.devid(pc),a0           ; Reset to device 0
	move.b	#'0',(a0)               ;
	loadpos	                        ; Reset device display line

.kwait	gemdos	Cconis,2                ; Check for a key
	tst.w	d0                      ;
	bne.b	.keyprs                 ;

	cmp.l	hz200.w,d3              ; Check for scan timeout
	blt.b	.scan                   ;

	bra.b	.kwait                  ; Loop until key pressed

.keyprs	gemdos	Cnecin,2                ; Wait for the selection

	cmp.b	#$1b,d0                 ; Check Esc to quit
	bne.b	.nexit                  ;
	ifd	main                    ; If started from TOS
	return	                        ; return to TOS
	elseif                          ;
	reboot                          ; else reboot to exit
	endc                            ;
.nexit
	sub.b	#'0',d0                 ; Check that a valid ID was entered
	cmp.b	#7,d0                   ;
	bhi.b	.kwait                  ;

	lsl.b	#5,d0                   ; d7 = ACSI id in the correct format
	move.b	d0,d7                   ;

.tst	bsr.w	blkdev.tst              ; Test the device
	cmp.w	#blkerr.mchange,d0      ;
	beq.b	.tst                    ;
	cmp.w	#blkerr.nomedium,d0     ;
	beq.b	.menu                   ;
	tst.w	d0                      ;
	bne.b	.nready                 ;

.menu	lea	bss+cont(pc),a3         ; Use global descriptors
	lea	bss+pt(pc),a4           ;
	bsr.w	mainmenu                ; Display the main menu for this device
	restart	                        ; Go back to the device selection

.nready	bell	                        ; Ding !
	moveq	#0,d5                   ; Scan fast again
	moveq	#0,d7                   ; Restart scan at ACSI id 0
	bra.w	.scan0                  ; Try again

.header	a2st_header
	dc.b	0

.devslt	dc.b	10,10,10,10,10,10,10,10 ; Keep blank lines for device names

	dc.b	10,10
	dc.b	'Select the device to setup (0-7)',13,10
	dc.b	'or press Esc to quit',0

.dev	dc.b	13,10,' '
.devid	dc.b	'0: ',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
