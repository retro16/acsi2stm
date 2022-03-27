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


acsicmd	; Execute an ACSI command
	; Input:
	;  d0.w: write flag in [8], chain flag in [9], block count in [0..7]
	;  d1.l: Target DMA address
	;  d7.b: Device id in [5..7], other bits 0
	;  a0  : Command buffer address
	; Returns:
	;  d0.l: status byte or -1 if timeout
	;  a0  : points after the command buffer if d0 is not -1

	st	flock.w                 ; Lock floppy drive

	lea	dmactrl.w,a1            ; a1 = DMA control register
	lea	dma.w,a2                ; a2 = DMA data register

	moveq	#0,d2                   ; d2 = command/data

	tst.w	d0                      ; Skip DMA init if length=0
	beq.b	.nodma                  ;

	; Initialize the DMA chip
	btst	#8,d0                   ; Check for write flag
	bne.b	.dmarst                 ;
	move.w	#$100,d2                ; Read mode: set write flag

.dmarst	move.b	#$90,d2                 ; DMA initialization

	btst	#9,d0                   ; Check command chain flag
	bne.b	.nreset                 ;

	move.w	d2,(a1)                 ; d2 = Command with inverted write flag

.nreset	eor.w	#$100,d2                ; Switch write flag
	move.w	d2,(a1)                 ; d2 = Command to set transfer size

	btst	#9,d0                   ; Check command chain flag
	bne.b	.naddr                  ;

	; DMA transfer address
	move.b	d1,dmalow.w             ; Set DMA address low
	lsr.l	#8,d1                   ;
	move.b	d1,dmamid.w             ; Set DMA address mid
	lsr.w	#8,d1                   ;
	move.b	d1,dmahigh.w            ; Set DMA address high

.naddr	and.w	#$00ff,d0               ; Clear flags
	move.w	d0,(a2)                 ; Set DMA length

.nodma	move.b	#$88,d2                 ;
	move.w	d2,(a1)                 ; Assert A1

	move.b	#$8a,d2                 ; d2 = $0w8a = write command byte

	swap	d0                      ; Keep DMA length for later

	move.b	(a0)+,d0                ; d0 = Command byte counter
	and.w	#$00ff,d0               ;

	swap	d2                      ;
	move.b	(a0)+,d2                ; Read first command byte
	or.b	d7,d2                   ; Patch in device id

.next	swap	d2                      ;
	move.l	d2,(a2)                 ; Send $00xx0w8a to DMA

	bsr.b	.ack                    ; Wait for ack

	swap	d2                      ;
	move.b	(a0)+,d2                ; Read next command byte

	dbra	d0,.next                ; Next byte

	; Send last command byte and trigger DMA
	swap	d2                      ;

	swap	d0                      ; Restore d0 = DMA length
	tst.b	d0                      ; If no DMA,
	beq.b	.lstcmd                 ;  don't switch DMA flag

	and.w	#$0100,d2               ; Keep only the write flag
.lstcmd	move.l	d2,(a2)                 ;

	; Read status byte
	bsr.b	.acklng                 ; Wait for status byte
	move.w	#$008a,(a1)             ; Acknowledge status byte
	move.w	(a2),d0                 ; Read status to d1
	and.w	#$00ff,d0               ; Keep only the byte value

.abort	sf	flock.w                 ; Unlock floppy drive

	rts	                        ; Exit acsicmd

	; Wait until DMA ack (IRQ pulse)
.acklng	move.l	#600,d1                 ; 3 second timeout
	bra.b	.doack                  ;

.ack	move.l	#20,d1                  ; 100ms timeout

.doack	add.l	hz200.w,d1              ;
.await	cmp.l	hz200.w,d1              ; Test timeout
	blt.b	.timout                 ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;
	rts

.timout	moveq	#-1,d0                  ; Return -1
	addq.l	#4,sp                   ; to the caller of acsicmd

	bra.b	.abort                  ; Uninitialize and return

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
