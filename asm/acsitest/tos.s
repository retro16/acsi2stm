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

	text

	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

print	macro
	pea	\1
	gemdos	Cconws,6
	endm

	Super                           ; Enter supervisor mode
	move.w	d7,-(sp)                ; Store d7

	print	msg.header(pc)          ; Display the header message

again	print	crlf(pc)
	print	msg.devsel(pc)          ; Ask for the device id

	gemdos	Cconin,2                ; Wait for the selection

	cmp.b	#27,d0                  ; Check Esc to quit
	beq.w	exit                    ;

	cmp.b	#'0',d0                 ; Check that a valid ID was entered
	blt.b	again                   ;
	cmp.b	#'7',d0                 ;
	bgt.b	again                   ;

	sub.b	#'0',d0                 ; Convert to the expected format
	lsl.b	#5,d0                   ;
	move.b	d0,d7                   ;

	print	msg.testing(pc)

chkdev	; Check that the device is responding with Test Unit Ready
	moveq	#0,d0                   ; No DMA
	lea	acsi.tstunit(pc),a0     ; Test unit ready command
	bsr.w	execcmd                 ;
	beq.b	.ready                  ;

	bsr.w	sense                   ; Sense error code

	cmp.l	#$060028,d0             ; Returned medium change, meaning "OK"
	bne.b	.tstnc                  ;
	print	msg.newcard(pc)         ; Print the issue
	bra.b	.ready                  ; It doesn't really matter

.tstnc	lea	msg.nocard(pc),a0       ; No SD card
	cmp.l	#$06003a,d0             ; Returned no medium
	bne.b	.unkerr                 ;
	print	msg.nocard(pc)          ; Print the issue
	bra.b	.ready                  ; It doesn't really matter

.unkerr	lea	msg.cmderr(pc),a0       ; Command error
	bra.w	err                     ;

.ready

chkvers	; Do an Inquiry and check the hardware version
	moveq	#1,d0                   ; Read 1 block
	lea	bss+buf(pc),a0          ;
	move.l	a0,d1                   ;
	lea	acsi.inquiry(pc),a0     ; Inquiry command
	bsr.w	execcmd                 ;
	beq.b	.ready                  ;

	lea	msg.inqerr(pc),a0
	bra.w	err

.ready	lea	bss+buf+8(pc),a0        ; Print the device string
		                        ; Add \r\n\0 to the end of the string
	move.l	#$0d*$1000000+$0a*$10000,24+4(a0)
	pea	(a0)                    ;
	gemdos	Cconws,6                ;

	lea	msg.nota2st(pc),a0      ; Prepare the error message

	lea	bss+buf+8(pc),a1        ; Check the device string

	cmp.l	#'ACSI',(a1)            ; Check for "ACSI2STM"
	bne.w	err                     ; in the device string
	cmp.l	#'2STM',4(a1)           ;
	bne.w	err                     ;
	cmp.w	#'2.',24(a1)            ; Needs to be version 2.xx
	blt.w	err                     ;
	bne.b	.not2xx                 ; Don't check minor if > 2.xx
	cmp.b	#'4',24+2(a1)           ; Needs to be 2.4x or greater
	blt.w	err                     ;
.not2xx

tstcmd	lea	bss+loops(pc),a0        ; Initialize loop counter
	move.w	#64,(a0)                ; Do 64 test loops

.next	; Command loopback test
	moveq	#0,d0                   ; No DMA
	lea	acsi.cmdts,a0           ; ACSI command loopback test
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Test result
	beq.b	.ok                     ;

	print	msg.cmderr(pc)          ; Print error
	bra.w	again                   ;

.ok	lea	bss+loops(pc),a0        ; Decrement test loop counter
	sub.w	#1,(a0)                 ;
	bne.b	.next                   ; Loop tests until successful

tstzcmd	lea	bss+loops(pc),a0        ; Initialize loop counter
	move.w	#64,(a0)                ; Do 64 test loops

.next	; Zero command loopback test
	moveq	#0,d0                   ; No DMA
	lea	acsi.zcmdts,a0          ; ACSI zero command loopback test
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Test result
	beq.b	.ok                     ;

	print	msg.cmderr(pc)          ; Print error
	bra.w	again                   ;

.ok	lea	bss+loops(pc),a0        ; Decrement test loop counter
	sub.w	#1,(a0)                 ;
	bne.b	.next                   ; Loop tests until successful

tstfcmd	lea	bss+loops(pc),a0        ; Initialize loop counter
	move.w	#64,(a0)                ; Do 64 test loops

.next	; 0xff command loopback test
	moveq	#0,d0                   ; No DMA
	lea	acsi.fcmdts,a0          ; ACSI 0xff command loopback test
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Test result
	beq.b	.ok                     ;

	print	msg.cmderr(pc)          ; Print error
	bra.w	again                   ;

.ok	lea	bss+loops(pc),a0        ; Decrement test loop counter
	sub.w	#1,(a0)                 ;
	bne.b	.next                   ; Loop tests until successful

qrybsz	; Read data buffer descriptor and adjust the ACSI transfer length
	moveq	#1,d0
	lea	bss+buf(pc),a0
	move.l	a0,d1
	lea	acsi.rwbuffer(pc),a0    ; Adjust the command
	move.b	#$3c,3(a0)              ;  Read buffer
	move.b	#$03,4(a0)              ;  Read buffer descriptor
	bsr.w	execcmd

	lea	msg.strict(pc),a0       ; If the command failed, it means that
	bne.w	err                     ; strict mode is selected.

	move.w	#$0201,d0               ; Do a chain read to flush the DMA buffer
	lea	bss+buf(pc),a0
	move.l	a0,d1
	lea	acsi.rqsense(pc),a0
	bsr.w	execcmd

	move.w	bss+buf+2(pc),d0        ; Read the buffer size
	cmp.w	#buf...,d0              ; Cap to the local buffer size
	ble.b	.bufok
	move.w	#buf...,d0

.bufok	lea	acsi.rwbuffer(pc),a0    ; Update transfer size in the command
	move.w	d0,10(a0)               ;

diag	move.l	#$f00f55aa,d0           ; Fill the buffer with the test pattern
	bsr.b	fillbuf                 ;

	lea	bss+loops(pc),a0        ; Initialize loop counter
	move.w	#16,(a0)                ; Do 16 test loops

.next	lea	acsi.rwbuffer(pc),a0    ; Switch acsi buffer command to write
	move.b	#$3b,3(a0)              ; Read buffer
	move.b	#$02,4(a0)              ; Read data buffer

	move.w	#$0120,d0               ; Write 32 buffers max
	bsr.b	bufop                   ; Do the acsi buffer operation

	move.l	#$0ff0aa55,d0           ; Flip all bits in RAM
	bsr.b	fillbuf                 ;

	lea	acsi.rwbuffer+3(pc),a0  ; Patch acsi command to read
	move.b	#$3c,(a0)               ;
	moveq	#$20,d0                 ; Read 32 buffers max
	bsr.b	bufop                   ; Do the buffer buffer operation

	lea	msg.dataerr(pc),a0      ;
	lea	bss+buf(pc),a1          ; Compare the buffer
	bsr.b	setrpt                  ;
.check	cmp.l	#$f00f55aa,(a1)+        ; Test the correct pattern
	bne.w	err                     ;
	dbra	d1,.check               ;

	lea	bss+loops(pc),a0        ; Decrement test loop counter
	sub.w	#1,(a0)                 ;
	bne.b	.next                   ; Loop tests until successful

	print	msg.success(pc)         ; Display "Test successful"

	bra.w	again                   ; Go back to device selection

fillbuf	lea	bss+buf(pc),a0
	bsr.b	setrpt
.copy	move.l	d0,(a0)+
	dbra	d1,.copy
	rts

setrpt	; Set repeat count for loops to cover the whole buffer
	; Output:
	;  d1.w: number of repeats for use with dbra
	move.w	acsi.rwbuffer+10(pc),d1 ; Read buffer size in bytes
	lsr	#2,d1                   ; Convert to longs
	subq	#1,d1                   ; Adjust for dbra
	rts

bufop	lea	bss+buf(pc),a0          ; DMA from/to SCSI data buffer
	move.l	a0,d1
	lea	acsi.rwbuffer(pc),a0    ;
	bsr.w	acsicmd                 ;

	tst.b	d0
	bne.b	.fail
	rts

.fail	addq	#4,sp                   ; At this point, we won't return

	lea	msg.cmderr(pc),a0       ; Check for command error
	cmp.b	#2,d0                   ; Not something that requires sense
	bne.w	err                     ; Just print error and retry

	bsr.b	sense                   ; Sense error code
	and.l	#$00ff00ff,d0           ; Filter out ASCQ

	lea	msg.writerr(pc),a0      ; Check for write error
	cmp.l	#$00030003,d0           ;
	beq.b	err                     ;

	print	msg.cmderr(pc)          ; No idea what happened !
	bra.w	again                   ;

exit	move.w	(sp)+,d7                ; Restore d7
	Pterm0                          ; Exit to TOS

sense	; Execute a request sense command and return its error code
	; Output:
	;  d0.l: Sense/ASCQ/ASC values

	print	msg.sensing(pc)

	moveq	#1,d0                   ; Read 1 block
	lea	bss+buf(pc),a0          ; Return in disk buffer
	move.l	a0,d1                   ;
	lea	acsi.rqsense(pc),a0     ; Request sense command
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Test DMA execution error
	bne.b	.err                    ;

	moveq	#0,d0                   ; Clear high byte
	move.b	bss+buf+2(pc),d0        ; Sense byte
	lsl.w	#8,d0                   ;
	move.b	bss+buf+13(pc),d0       ; ACKQ byte
	lsl.l	#8,d0                   ;
	move.b	bss+buf+12(pc),d0       ; ACK byte
	rts

.err	print	msg.senserr(pc)         ; Display error
	addq	#4,sp                   ; Pop return address
	bra.w	again                   ; Return to device selection

	; Routines

execcmd	; Call acsicmd and check for a timeout
	; Jumps back to "again" if the command failed
	; Input: see acsicmd
	; Output: see acsicmd
	;  flags: result of tst.w d0
	bsr.b	acsicmd
	tst.w	d0                      ; If d0.w is negative,
	bmi.b	.nodev                  ;  timeout
	rts

.nodev	print	msg.nodev(pc)           ; Load error message
	addq	#4,sp                   ; Pop return address
	bra.w	again                   ; Try again

err	; Print the error message in a0, waits for a key and goes to "again"
	print	(a0)                    ; Print an error message
	bra.w	again                   ; jump back to the selection menu

	; External subroutines

	include	acsicmd.s

	; Data sections
	include	rodata.s
	data
	include	data.s
	bss
	include	bss.s
bss	ds.b	bss...

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm

