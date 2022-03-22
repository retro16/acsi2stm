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

; ACSI2STM DMA quick test
; Main routine shared between tos and boot versions

diag	move.b	d7,d0                   ; Get the acsi id
	lea	acsiid(pc),a0           ; Patch acsi id in the text
	lsr.b	#5,d0                   ;
	add.b	d0,(a0)                 ; Add acsi id to '0'

	move.w	#$f00f,d0               ;
	bsr.b	fillbuf                 ;

	move.w	#$0101,d1               ; Write 1 block
	bsr.b	echoop                  ; Do the echo buffer operation

	move.w	#$0ff0,d0               ;
	bsr.b	fillbuf                 ;

	lea	acsi.echorw(pc),a0      ; Patch acsi command
	move.b	#$3c,(a0)               ;
	moveq	#1,d1                   ; Read 1 block
	bsr.b	echoop                  ; Do the echo buffer operation

	lea	glob+buf(pc),a0
	move.w	#255,d0
.check	cmp.w	#$f00f,(a0)+
	bne.b	dmaerr
	dbra	d0,.check

	moveq	#0,d0                   ; Success.
	bra.b	diagend                 ; Jump to the end if successful

dmaerr	pea	dataerr(pc)             ;
	bra.b	diagerr

fillbuf	lea	glob+buf(pc),a0
	move.w	#255,d1
.copy	move.w	d0,(a0)+
	dbra	d1,.copy
	rts

echoop	lea	glob+buf(pc),a0         ; DMA from/to echo buffer
	move.l	a0,d0
	lea	acsi.echo(pc),a0        ;
	bsr.w	acsi_exec_cmd           ;

	tst.b	d0                      ; Check for acsi error
	bne.b	dcmderr                 ; Display "Error"

	rts

dcmderr	
	lea	4(sp),sp                ; Don't return from echoop
	pea	cmderr(pc)              ; Print "Command error"
diagerr	pea	sdid(pc)                ; Display the SD card id
	gemdos	Cconws,6                ;
	gemdos	Cconws,6                ; Print the error message

	moveq	#1,d0                   ; Error

diagend

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
