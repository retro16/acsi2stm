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

acsicmd	; Execute an ACSI command
	; Input:
	;  d0.w: write flag in [8]
	;        chain flag in [9]
	;        disable DMA timeout flag in [10]
	;        block count in [0..7]
	;  d1.l: Target DMA address
	;  d7.b: Device id in [5..7], other bits 0
	;  a0  : Command buffer address
	; Returns:
	;  d0.l: status byte or -1 if timeout
	;  a0  : points after the command buffer if d0 is not -1

	st	flock.w                 ; Lock floppy drive

	lea	dmactrl.w,a1            ; a1 = DMA control register
	lea	dmadata.w,a2            ; a2 = DMA data register

	moveq	#0,d2                   ; d2 = command/data

	tst.w	d0                      ; Skip DMA init if length=0
	beq.b	.nodma                  ;

	; Initialize the DMA chip
	btst	#8,d0                   ; Check for write flag
	bne.b	.dmarst                 ;
	move.w	#$100,d2                ; Read mode: set write flag

.dmarst	btst	#9,d0                   ; Check command chain flag
	bne.b	.nreset                 ;

	move.w	d2,(a1)                 ; d2 = Command with inverted write flag
	move.b	#$90,d2                 ; DMA initialization

.nreset	eor.w	#$100,d2                ; Switch write flag
	btst	#9,d0                   ; Check command chain flag
	bne.b	.nodma                  ;

	move.w	d2,(a1)                 ; d2 = Command to set transfer size

	; DMA transfer address
	move.b	d1,dmalow.w             ; Set DMA address low
	lsr.l	#8,d1                   ;
	move.b	d1,dmamid.w             ; Set DMA address mid
	lsr.w	#8,d1                   ;
	move.b	d1,dmahigh.w            ; Set DMA address high

.naddr	move.w	d0,d1                   ; Clear flags
	and.w	#$00ff,d1               ;
	move.w	d1,(a2)                 ; Set DMA length

.nodma	move.b	#$88,d2                 ;
	move.w	d2,(a1)                 ; Assert A1

	swap	d0                      ; Keep DMA length for later

	move.b	(a0)+,d0                ; d0 = Command byte counter
	and.w	#$00ff,d0               ;

	moveq	#0,d1                   ; Read first command byte
	move.b	(a0)+,d1                ;
	or.b	d7,d1                   ; Patch in device id

	move.w	d1,(a2)                 ; Send first command byte

	move.b	#$8a,d2                 ; Disable A1
	move.w	d2,(a1)                 ;

	bsr.b	.sak                    ; Wait for ack
	
.next	moveq	#0,d1                   ; Read command byte
	move.b	(a0)+,d1                ;
	move.w	d1,(a2)                 ; Send command byte
	
	bsr.b	.sak                    ; Wait for ack

	dbra	d0,.next                ; Next byte

	; Send last command byte and trigger DMA

	swap	d0                      ; Restore d0 = DMA length
	tst.b	d0                      ; If no DMA,
	bne.b	.lstdma                 ;  don't switch DMA flag

	moveq	#0,d1                   ; Read last command byte
	move.b	(a0)+,d1                ;
	move.w	d1,(a2)                 ; Send last command byte

	bra.b	.rstat

.lstdma	and.w	#$0100,d2               ; Keep only the write flag
	moveq	#0,d1                   ; Read last command byte
	move.b	(a0)+,d1                ;
	move.w	d1,(a2)                 ; Send last command byte
	move.w	d2,(a1)                 ; Enable DMA

	; Read status byte
.rstat	btst	#10,d0                  ; Check infinite timeout flag
	beq.b	.ninf                   ;
.inf	btst.b	#5,gpip.w               ; Wait for command with no time limit
	bne.b	.inf                    ;
.ninf	bsr.b	.ack                    ; Wait for status byte
.ackok	move.b	#$8a,d2                 ; Disable DMA
	move.w	d2,(a1)                 ;
	move.w	(a2),d0                 ; Read status to d1
	and.l	#$000000ff,d0           ; Keep only the byte value

.ret	sf	flock.w                 ; Unlock floppy drive

	rts	                        ; Exit acsicmd

	; Wait until DMA ack (IRQ pulse)
.ack	move.l	#600,d1                 ; 3 second timeout
	bra.b	.dak                    ;

.sak	move.l	#20,d1                  ; 100ms timeout

.dak	add.l	hz200.w,d1              ;
.await	cmp.l	hz200.w,d1              ; Test timeout
	blo.b	.timout                 ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;
	rts

.timout	moveq	#-1,d0                  ; Return -1
	addq.l	#4,sp                   ; to the caller of acsicmd

	bra.b	.ret                    ; Uninitialize and return

acsicmd.sense
	; Execute an ACSI command and fetch sense key if failed
	; Input:
	;  d0.w: write flag in [8], chain flag in [9], block count in [0..7]
	;  d1.l: Target DMA address
	;  d7.b: Device id in [5..7], other bits 0
	;  a0  : Command buffer address
	; Returns:
	;  d0.l: ASCQ (MSB), ASC, SENSE KEY, status byte (LSB) or -1 if timeout
	;  a0  : points after the command buffer if d0 is not -1

	bsr	acsicmd

	moveq	#-1,d1                  ; Check for timeout
	cmp.l	d0,d1                   ;
	bne.b	.ntime                  ;

	rts	                        ; Return timeout

.ntime	tst.b	d0                      ; Check for success
	bne.b	.sense                  ;

	moveq	#0,d0                   ; Clear MSB
	rts	                        ; Return success

.sense	and.l	#$000000ff,d0           ; Keep only status code in d0
	move.l	d0,-(sp)                ; Store current d0

	cmp.b	#2,d0                   ; Check for "CHECK CONDITION" ret code
	bne.b	.ret                    ; If not, just return

	moveq	#$0001,d0               ; Read 1 block
	move.l	#sensbuf,d1             ;
	lea	.rqsnse,a0              ; Send REQUEST SENSE
	bsr	acsicmd.flush           ;

	moveq	#-1,d1                  ; Check for sense timeout
	cmp.l	d0,d1                   ;
	bne.b	.nsnsto                 ;

	addq	#4,sp                   ; Cancel current d0
	rts	                        ; Return sense timeout

.nsnsto	lea	sensbuf,a0              ; Analyze sense values

	bclr	#7,(a0)                 ; Check sense value
	cmp.b	#$70,(a0)               ;
	beq.b	.sensok                 ;

	moveq	#-1,d0                  ; Return invalid sense format
	addq	#4,sp                   ; Cancel current d0
	rts	                        ;

.sensok	move.b	2(a0),2(sp)             ; Extract KEY
	and.b	#$0f,2(sp)              ;

	cmp.b	#4,7(a0)                ; Extract ASC
	bls.b	.ret                    ;
	move.b	12(a0),1(sp)            ;

	cmp.b	#5,7(a0)                ; Extract ASCQ
	bls.b	.ret                    ;
	move.b	13(a0),(sp)             ;

.ret	move.l	(sp)+,d0                ; Return final value
	rts	                        ;

.rqsnse	dc.b	3                       ;
	dc.b	$03,$00,$00,$00,$12,$00 ;

	even

acsicmd.flush
	; Call acsicmd, then flush the DMA FIFO
	; Required to read data that is not a multiple of 16 bytes in size
	; Will write up to 32 bytes in RAM, past the current DMA buffer position
	bsr	acsicmd                 ; Do the actual call

	moveq	#-1,d1                  ; Return if timed out
	cmp.l	d1,d0                   ;
	bne.b	.ntout                  ;
	rts

.ntout	move.w	#$0201,d0               ; Append inquiry data to flush DMA FIFO
	lea	.inqry,a0               ;
	bra	acsicmd                 ;

.inqry	dc.b	3                       ; Inquiry (best command to flush buffer)
	dc.b	$12,$00,$00,$00,$ff,$00 ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
