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

; ACSI2STM boot sector when no SD card is inserted.
; Does a quick DMA buffer check and displays a message.

	org	0

	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

	pea	msg(pc)                 ; Display the header message
	gemdos	Cconws,6                ;

diag	move.b	d7,d0                   ; Get the acsi id
	lea	acsiid(pc),a0           ; Patch acsi id in the text
	lsr.b	#5,d0                   ;
	add.b	d0,(a0)                 ; Add acsi id to '0'

	move.l	#$f00f55aa,d0           ; Challenge data integrity
	bsr.b	fillbuf                 ;

	move.w	#$0101,d0               ; Write 1 block
	bsr.b	echoop                  ; Do the echo buffer operation

	move.l	#$0ff0aa55,d0           ; Flip all bits in RAM
	bsr.b	fillbuf                 ;

	lea	acsidta+3(pc),a0        ; Patch acsi command to
	move.b	#$3c,(a0)               ;  read data buffer
	moveq	#1,d0                   ; Read 1 block
	bsr.b	echoop                  ; Do the echo buffer operation

	lea	bss+buf(pc),a0
	moveq	#127,d0
.check	cmp.l	#$f00f55aa,(a0)+
	bne.b	dmaerr
	dbra	d0,.check

	pea	nocard(pc)              ; Display "No SD card" because that's
	gemdos	Cconws,6                ; what this sector is all about

	rts	                        ; Return to system

dmaerr	pea	dataerr(pc)
	bra.b	diagerr

fillbuf	lea	bss+buf(pc),a0
	moveq	#127,d1
.copy	move.l	d0,(a0)+
	dbra	d1,.copy
	rts

echoop	lea	bss+buf(pc),a0          ; DMA from/to echo buffer
	move.l	a0,d1                   ;
	lea	acsidta(pc),a0          ; ACSI data buffer command
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Check for acsi error
	bne.b	dcmderr                 ; Display "Error"

	rts

dcmderr	
	addq	#4,sp                   ; Don't return from echoop
	pea	cmderr(pc)              ; Print "Error"
diagerr	pea	sdid(pc)                ; Display the SD card id
	gemdos	Cconws,6                ;
	gemdos	Cconws,6                ; Print the error message

waitkey	gemdos	Cconin,2                ; Wait for a key and return to system
        rts

	include	acsicmd.s

msg	a2st_header                     ; Welcome header text
	dc.b	13,10,0
nocard	dc.b	'No SD card'            ; "No SD card" message
	dc.b	13,10
	dc.b	13,10,0
dataerr	dc.b	'DMA '                  ; "DMA Error" message
cmderr	dc.b	'Error'                 ; "Error" message
	dc.b	7,13,10
crlf	dc.b	13,10,0                 ; A single CRLF
sdid  	dc.b	'SD'                    ; "SD0", patched to match the SD id
acsiid	dc.b	'0: ',0
	even

acsidta	; ACSI data buffer command
	dc.w	9                       ; 9 intermediate bytes
	dc.b	$1f                     ; Extended ICD command
	dc.b	$3b,$02                 ; Write data buffer
	dc.b	$01,$00,$00,$00         ; Buffer id and offset
	dc.b    $00,$02,$00             ; 512 bytes
	dc.b	$00                     ; Control byte

	even

	; Uninitialized global data
	rsreset
buf...	equ	512                     ; Buffer size
buf	rs.b	buf...                  ; Main buffer
bss...	rs.b	0                       ; Total size of BSS

bss		                        ; Falls into the globl disk buffer

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
