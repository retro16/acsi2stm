; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2025 by Jean-Matthieu Coulon

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

; PRG loader for the GemDrive system hook
; Initialization code - shared with GEMDRPIO

main	lea	stack,sp                ; Initialize stack

	Super	                        ; This program needs super user

	; Check if the driver is already installed

	move.l	gemdos.vector.w,a0      ; Start at interrupt vector
.nxtvec	cmp.l	#'XBRA',-12(a0)         ; Check if it is a XBRA marker
	bne.b	.notins                 ;

	cmp.l	#XBRA,-8(a0)            ; Check GemDrive XBRA marker
	bne.b	.na2st                  ;

	print	alrdyin(pc)             ; Found XBRA marker in the chain,
	Pterm0                          ; Don't install and quit now.

.na2st	move.l	-4(a0),a0               ; Check next vector in the chain
	bra.b	.nxtvec                 ;

.notins	; GemDrive not installed
	; Scan for devices and install the driver

	move.w	#$700e,d7               ; d7 = pre-shifted ACSI id and moveq
	lea	start-$80(pc),a5        ; a5 = handler generator pointer
	move.w	#$6070,d6               ; d6 = "bra.b" to syshook
	lea	gemdos.vector.w,a3      ; a3 = gemdos vector address
	lea	start-$10,a4            ; a4 = last interrupt handler address

	lea	prmoff(pc),a0           ; Compute parameter offset (prmoff)
	tst.w	_longframe.w            ; Test _longframe
	beq.b	.shrtfr                 ;
	move.w	#8,(a0)                 ; prmoff = 8
.shrtfr

.test	; Test for ACSI device in d7

	st	flock.w                 ; Lock floppy controller

	moveq	#0,d0                   ; Clear command byte register
	moveq	#5,d2                   ; 6 command bytes
	lea	bootcmd(pc),a2          ; a2 = command buffer
	bsr.w	syshook.setdmaaddr      ;
	move.w	#$0088,(a1)             ; Switch to command.
	move.b	d7,d0                   ; Device id to first command byte
	and.b	#$e0,d0                 ;
	or.b	(a2)+,d0                ; Read first command byte
	moveq	#20,d3                  ; Short timeout
.nxcmdb	move.w	d0,(a0)                 ;

	move.l	d3,d1                   ; Set timeout
	add.l	hz200.w,d1              ;
.await	cmp.l	hz200.w,d1              ; Test timeout
	bmi.b	.nxtid                  ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Disable A1
	move.l	#600,d3                 ; Long timeout
	move.b	(a2)+,d0                ; Next command byte
	dbra	d2,.nxcmdb              ;

	move.w	(a0),d0                 ; Read command/status byte

	tst.b	d0                      ; 0 = success
	bne.b	.nxtid                  ;

	; All good, found device in d7

	; Enter syshook mode to run onInit on the STM32

	move.b	d7,d0                   ;
	bsr	syshook.init

	; Install system call hook

	move.l	#'XBRA',(a5)+           ; Generate new interrupt vector
	move.l	#XBRA,(a5)+             ;
	move.l	(a3),(a5)+              ; Old vector
	move.l	a5,(a3)                 ; Install new vector address
	move.l	#$2F3AFFFA,(a5)+        ; "move.l oldvector(pc),-(sp)"
	move.w	d7,(a5)+                ; d7 = "moveq #acsiid+command,d0"
	move.w	d6,(a5)+                ; d6 = "bra.b syshook"
	sub.w	#$0014,d6               ; Adjust bra pointer for next handler

	cmp.l	a4,a5                   ; Stop searching for devices if there is
	bhi.b	.instok                 ; no more room for handlers

.nxtid	add.b	#$20,d7                 ; Point at next ACSI id
	cmp.b	#$20,d7                 ;
	bhi.b	.test                   ; Try next ACSI id

	; Installation finished for all devices

.instok	sf	flock.w                 ; Unlock floppy controller

	cmp.w	#$6070,d6               ; Check if a vector was written
	bne.b	.gores                  ; If yes, stay resident

	print	devnfnd(pc)             ; No device found
	Pterm0	                        ; Exit normally

.gores	; Shrink memory usage, terminate and stay resident

	clr.w	-(sp)                   ; TSR return code
	move.l	#$100+(syshook.end-start),-(sp) ; TSR memory size
	gemdos	Ptermres                ; Terminate and stay resident

	; data
bootcmd	dc.b	BOOTCMD,$00,'G','D','R','V',0
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
