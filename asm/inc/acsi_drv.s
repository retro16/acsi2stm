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


acsi_exec_cmd
; Execute an ACSI command in the acsicmd global buffer
; d7: Device id
; a0: Command address
; d0: Target DMA address
; d1: write flag in [8], blocks in [0..7]
; Returns: d0.b: status byte or -1 if timeout

	st	flock.w                 ; Lock floppy drive

	lea	dmactrl.w,a1            ; a1 = DMA control register
	lea	dma.w,a2                ; a2 = DMA data register

	moveq	#0,d2                   ; d2 = command/data

	; Initialize the DMA chip
	btst	#8,d1                   ; Check for write flag
	bne.b	.dmarst                 ;
	move.w	#$100,d2                ; Read mode: set write flag

.dmarst	bclr	#8,d1                   ; d1 = DMA length
	tst.w	d1                      ; Skip DMA init if length=0
	beq.b	.nodma                  ;
	move.b	#$90,d2                 ; DMA initialization
	move.w	d2,(a1)                 ;
	eor.w	#$100,d2                ; Switch write flag
	move.w	d2,(a1)                 ;

	; DMA transfer
	move.b	d0,dmalow.w             ; Set DMA address low
	lsr.l	#8,d0                   ;
	move.b	d0,dmamid.w             ; Set DMA address mid
	lsr.w	#8,d0                   ;
	move.b	d0,dmahigh.w            ; Set DMA address high

	bclr	#8,d1                   ; Clear write flag
	move.w	d1,(a2)                 ; Set DMA length

.nodma	move.b	#$88,d2                 ;
	move.w	d2,(a1)                 ; Assert A1

	move.b	#$8a,d2                 ; d2 = $0w8a = write command byte

	swap	d1                      ; Keep DMA length for later

	move.b	(a0)+,d1                ; d1 = Command byte counter
	ext.w	d1                      ;      (except last byte)

	swap	d2                      ;
	move.b	(a0)+,d2                ; Read first command byte
	or.b	d7,d2                   ; Patch in device id

.next	swap	d2                      ;
	move.l	d2,(a2)                 ; Send $00xx0w8a to DMA

	bsr.b	.ack                    ; Wait for ack

	swap	d2                      ;
	move.b	(a0)+,d2                ; Read next command byte

	dbra	d1,.next                ; Next byte

	; Send last command byte and trigger DMA
	swap	d2                      ;

	swap	d1                      ; Restore d1 = DMA length
	tst.b	d1                      ; If no DMA,
	beq.b	.lstcmd                 ;  don't switch DMA flag

	and.w	#$0100,d2               ; Keep only the write flag
.lstcmd	move.l	d2,(a2)                 ;

	; Read status byte
	bsr.b	.ack                    ; Wait for status byte
	move.w	#$008a,(a1)             ; Acknowledge status byte
	move.w	(a2),d0                 ; Read status to d0

.abort	sf	flock.w                 ; Unlock floppy drive

	rts                             ; Exit acsi_exec_cmd

	; Wait until DMA ack (IRQ pulse)
.ack	move.l	#600,d0                 ; 3 second timeout
	add.l	hz200.w,d0              ;
.await	cmp.l	hz200.w,d0              ; Test timeout
	blt.b	.timout                 ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;
	rts

.timout	moveq	#-1,d0                  ; Return -1
	addq.l	#4,sp                   ; to the caller of acsi_exec_cmd

	bra.b	.abort                  ; Uninitialize and return

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
