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
; TOS program wrapper

	text

	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

	pea	msg(pc)                 ; Display the header message
	gemdos	Cconws,6                ;

	Super                           ; Enter supervisor mode
	move.w	d7,-(sp)                ; Store d7

again	pea	devsel(pc)              ; Ask for the device id
	gemdos	Cconws,6                ;
	gemdos	Cconin,2                ;

	move.w	d0,-(sp)                ;
	pea	crlf(pc)                ; Print new line
	gemdos	Cconws,6                ;
	move.w	(sp)+,d0                ;

	cmp.b	#'q',d0                 ; Check 'Q' to quit
	beq.w	exit                    ;
	cmp.b	#'Q',d0                 ;
	beq.w	exit                    ;

	cmp.b	#'0',d0                 ; Check that a valid ID was entered
	blt.b	again                   ;
	cmp.b	#'7',d0                 ;
	bge.b	again                   ;

	sub.b	#'0',d0                 ; Convert to the expected format
	lsl.b	#5,d0                   ;
	move.b	d0,d7                   ;

	; Check the device
chkdev	moveq	#0,d1                   ; No DMA
	lea	tstunit(pc),a0          ; Test unit ready command
	bsr.w	acsi_exec_cmd           ;

	cmp.w	#-1,d0                  ;
	bne.b	.dmaok                  ;

	pea	nodev(pc)               ; Print "Device not responding"
	gemdos	Cconws,6                ;
	bra.w	again                   ; Try again

.dmaok	tst.b	d0                      ; Test DMA execution error
	beq.b	.ready                  ;

	bsr.w	sense                   ; Sense error code

	cmp.l	#$060028,d0             ; Returned medium change, meaning "OK"
	beq.b	.ready                  ;

	cmp.l	#$050020,d0               ; Didn't understand the query.
	beq.w	na2st                   ; Not an acsi2stm
.ready

qryvrs	lea	glob+buf(pc),a0         ; Return in disk buffer
	move.l	a0,d0                   ;
	moveq	#1,d1                   ; Read 1 block
	lea	inquiry(pc),a0          ; Inquiry command
	bsr.w	acsi_exec_cmd           ;

	tst.b	d0                      ; Test DMA execution error
	beq.b	.ready                  ;

	pea	iqerr(pc)               ; Print "Inquiry error"
	gemdos	Cconws,6                ;
	bra.w	again                   ; Try again

.ready	lea	glob+buf(pc),a0         ; Print the device string
	move.l	#$0d*$1000000+$0a*$10000,8+24+4(a0)
	pea	8(a0)                   ;
	gemdos	Cconws,6                ;

	lea	glob+buf+8(pc),a0       ; Check the device string

	cmp.l	#'ACSI',(a0)            ; Check for "ACSI2STM"
	bne.w	na2st                   ; in the device string
	cmp.l	#'2STM',4(a0)           ;
	bne.w	na2st                   ;
	cmp.w	#'2.',24(a0)            ; Needs to be version 2.xx
	blt.w	na2st                   ;
	bne.b	.not2xx                 ; Don't check minor if > 2.xx
	cmp.b	#'4',24+2(a0)           ; Needs to be 2.4x or greater
	blt.w	na2st                   ;
.not2xx
	lea	acsi.echorw(pc),a0      ; Switch acsi.echorw command to write
	move.b	#$3b,(a0)               ;

	; Run the main routine
	include	main.s

	tst.w	d0                      ; If there was no error
	bne.w	again                   ;
	pea	success(pc)             ; Display "Test successful"
	gemdos	Cconws,6                ;

	bra.w	again                   ; Go back to selection

exit	move.w	(sp)+,d7                ; Restore d7

	Pterm0                          ; Exit to TOS

na2st	; Not an ACSI2STM
	pea	na2stm(pc)              ; Display "Not an ACSI2STM device"
	gemdos	Cconws,6                ;

	bra.w	again                   ; Try again

sense	; Execute a request sense command and return its error code
	
	lea	glob+buf(pc),a0         ; Return in disk buffer
	move.l	a0,d0                   ;
	moveq	#1,d1                   ; Read 1 block
	lea	rqsense(pc),a0          ; Request sense command
	bsr.w	acsi_exec_cmd           ;

	tst.b	d0                      ; Test DMA execution error
	bne.b	.err                    ;

	move.b	glob+buf(pc),d0         ; Sense byte
	lsl.w	#8,d0                   ;
	move.b	glob+buf+3(pc),d0       ; ACKQ byte
	lsl.w	#8,d0                   ;
	move.b	glob+buf+2(pc),d0       ; ACK byte
	rts

.err	moveq	#-1,d0                  ; Return -1 for command error
	rts

devsel	dc.b	'Type the device id of the ACSI2STM (0-7) or Q to quit.',13,10,0
success	dc.b	'Test successful !',13,10,0
nodev	dc.b	'Device not responding',13,10,0
na2stm	dc.b	'Not an ACSI2STM device',13,10,0
iqerr	dc.b	'Device inquiry error',13,10,0

tstunit	dc.b	4                       ; Test unit ready ACSI command
	dc.b	$00,$00,$00,$00,$00,$00 ;

inquiry	dc.b	4                       ; Inquiry ACSI command
	dc.b	$12,$00,$00,$00,$30,$00 ;

rqsense	dc.b	4                       ; Request sense ACSI command
	dc.b	$00,$00,$00,$00,$20,$00 ;

	even

	
	include	acsi_drv.s
	include	rodata.s

	data
	include	data.s

	bss
	include	glob.s
glob	ds.b	glob...

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
