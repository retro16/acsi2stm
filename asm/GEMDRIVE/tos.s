; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2023 by Jean-Matthieu Coulon

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

; TOS loader for the GemDrive system hook

	incdir	..\inc\
	include	tos.i

	opt	O+

	text

start	bra	main                    ; Main program is in the freed zone

syshook
	include	syshook.s

	; These variables need to be in the text segment because the main
	; entry point as well as everything after will be freed when the driver
	; will be made resident.
	dc.b	0
acsiid	dc.b	$ff                     ; Patched by device detection
prmoff	dc.w	$ff                     ; Detected during initialization
syshook.end

	; Freed zone: everything after this is freed when the driver is made
	; resident.

main
	lea	stack,sp                ; Initialize stack

	Super	                        ; This program needs super user

	; Check if the driver is already installed

.nxtvec	move.l	gemdos.vector.w,a0
	cmp.l	#'XBRA',-12(a0)
	bne.b	.notins

	cmp.l	#'A2ST',-8(a0)
	bne.b	.na2st

	print	alrdyin
	gemdos	Cconin,2                ; Wait for a key
	Pterm0                          ;  then exit

.na2st	move.l	-4(a0),a0
	bra.b	.nxtvec

.notins	moveq	#0,d7                   ; d7 = pre-shifted ACSI id
	st	flock.w                 ; Lock floppy controller

.test	; Test for ACSI device in d7

	moveq	#0,d1                   ; Disable DMA
	bsr.w	syshook.setdmaaddr      ;
	move.w	#$0088,(a1)             ; Switch to command.
	move.w	#$0011,(a0)             ; Send command $11 to the STM32

	moveq	#20,d1                  ; 100ms timeout

	add.l	hz200.w,d1              ;
.await	cmp.l	hz200.w,d1              ; Test timeout
	bmi.b	.nxtid                  ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Prepare to read command/status
	move.w	(a0),d0                 ; Read command/status byte

	tst.b	d0                      ; 0 = success
	beq.b	.found                  ;

.nxtid	add.b	#$20,d7                 ; Point at next ACSI id
	bne.b	.test                   ; Try next ACSI id

	sf	flock.w                 ; Unlock floppy controller
	print	devnfnd
	gemdos	Cconin,2                ; Wait for a key
	Pterm0	                        ;  then exit

.found	sf	flock.w                 ; Unlock floppy controller

	; All good, found device in d7

setvars	lea	acsiid(pc),a0           ; Save ACSI id to RAM
	move.b	d7,(a0)+                ;

	move.w	#6,(a0)                 ; Compute parameter offset
	tst.w	_longframe.w            ; Test _longframe
	beq.b	.shrtfr                 ;
	move.w	#8,(a0)                 ;
.shrtfr

	; Install system call hooks

	move.l	#'XBRA',d3
	move.l	#'A2ST',d4

	; Warning: this list must be synchronized with GemDrive::onBoot()

	lea	gemdos.vector.w,a3
	bsr.b	install

	; Enter syshook mode to run onInit on the STM32

	bsr	syshook.init

	; Shrink memory usage, terminate and stay resident

termres	lea	start-72(pc),a0         ; Copy termres code into cmdline space
	lea	termres.start(pc),a1    ;
	move.w	#termres.end-termres.start-1,d0
.loop	move.w	(a1)+,(a0)+             ;
	dbra	d0,.loop                ;

	bra	start-72                ; Jump to copied code

termres.start
	move.l	#$100+(syshook.end-start),-(sp) ; Shrink memory
	move.l	8(sp),-(sp)             ;
	clr.w	-(sp)                   ;
	gemdos	Mshrink,12              ;

	clr.w	-(sp)                   ; Terminate and stay resident
	gemdos	Ptermres                ;

	even
termres.end

install	; Install a hook
	; Input:
	;  d3: #'XBRA'
	;  d4: #'A2ST'
	;  a3: vector address

	lea	syshook,a0              ; Search for XBRA signature
	move.w	#(syshook.end-syshook)/2-1,d0
.sig1	cmp.l	(a0),d3                 ;
	beq.b	.sig1ok                 ;
.cont	addq	#2,a0                   ;
	dbra	d0,.sig1                ;

	rts

.sig1ok	cmp.l	4(a0),d4                ; Search for A2ST signature
	bne.b	.cont                   ;
	cmp.l	8(a0),a3                ; Check vector to install
	bne.b	.cont                   ;

	; Marker found: install hook

	addq	#8,a0                   ; Point a0 to old vector
	move.l	(a3),(a0)+              ; Save old vector and point at hook code
	move.l	a0,(a3)                 ; Install hook vector

	rts

	; Strings
alrdyin	dc.b	7,'GemDrive already installed',13,10,0
devnfnd	dc.b	7,'No GemDrive device detected',13,10,0
	even

	bss

	ds.b	256                     ; Temporary stack for initialization
stack		                        ;

end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
