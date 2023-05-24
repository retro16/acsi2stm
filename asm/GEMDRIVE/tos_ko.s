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

; Structures

devstr		rsreset
devstr.mode	rs.b	1               ; 0 = disabled, 1 = acsi, 2 = gemdrive
devstr.letter	rs.b	1               ; 0 = not mounted, 2 = C:, 3 = D:, ...
devstr.product	rs.b	7               ; 'ACSI2STM'
		rs.b	1               ; ' '
devstr.slottype	rs.b	2               ; 'SD'
devstr.slot	rs.b	1               ; '0'
		rs.b	1               ; ' '
devstr.fs 	rs.b	3               ; 'F32','EXF','IMG','RAW',...
		rs.b	1               ; ' '
devstr.size	rs.b	3               ; '128G'
devstr.capped	rs.b	1               ; ' ','+'
devstr.ro	rs.b	1               ; ' ','R'
devstr.boot	rs.b	1               ; ' ','B'
devstr.version	rs.b	4               ; '4.0a'
devstr.eos	rs.b	1               ; zero byte
		rs.b	1               ; zero byte padding
devstr...	rs.b	0

	text

start
	lea	stacktop,sp             ; Initialize stack

	move.l	sp,d0                   ; Shrink memory
	lea	start-$100,a0           ;
	sub.l	a0,d0                   ;
	move.l	d0,-(sp)                ;
	pea	start-$100              ;
	clr.w	-(sp)                   ;
	gemdos	Mshrink,12              ;

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

.test	; Test for ACSI device in d7

	lea	devices,a2              ; Load data into the device list
	bsr.w	syshook.setdmaaddr      ;

	move.l	#$00010088,(a0)         ; Read 1 block. Switch to command.
	move.l	#$01000000,d1           ;
	move.b	d7,d1                   ;
	or.b	#$02,d1                 ; Command $02
	swap	d1                      ; d1 = 00i20100 (i being the device id)
	move.l	d1,(a0)                 ; Send command to the STM32

	; Timeout for IRQ
	moveq	#20,d1                  ; 100ms timeout

.doack	add.l	hz200.w,d1              ;
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

	print	devnfnd
	gemdos	Cconin,2                ; Wait for a key
	Pterm0	                        ;  then exit

.found	; Check device string
	moveq	#7,d0
	lea	devices,a0

.nxtdev	cmp.b	#2,(a0)
	bne.b	.invdev

	cmp.l	#'ACSI',devstr.product(a0)
	bne.b	.invdev
	cmp.l	#'2STM',devstr.product+4(a0)
	bne.b	.invdev
	cmp.b	#'4',devstr.version(a0)
	blt.b	.invdev
	cmp.b	#'9',devstr.version(a0)
	bgt.b	.invdev

	; All good, run system hook init
	bsr.b	syshook.init
	Pterm0

.invdev	lea	devstr...(a0),a0
	dbra	d0,.nxtdev

	; System hook code
	include	syshook.s

	; Strings
alrdyin	dc.b	7,'GemDrive already installed',13,10,0
devnfnd	dc.b	7,'GemDrive error: could not find a device',13,10,0
	even

end

detect

	; Try to detect a GemDrive device

	bss

devices	ds.b	devstr...*8

stack:
	ds.b	32
stacktop:

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
