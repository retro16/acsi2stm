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

; Boot sector injected into non-bootable hard disks
; Loads a payload with the short command 0x0d
;
; Boot sector format:
;  $000-$001: bra.b $70(pc) ; $606e
;  $002-$059: FAT header
;  $05a-$05b: checksum
;  $05c-$05f: alloc size (patched from payload)
;  $060-$06f: 'ACSI2STM OVERLAY' (patched from payload)
;  $070-$1b7: this code
;  $1b8-$1ff: partition table
;
; Return value in d0:
;  Bit 0: if set, Mfree will not be called on return
;  Bit 1: if set, skip other boot drives

	org	$70
	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

allocsz		equ	$5c
signature	equ	$60

load	pea	msg.loading(pc)
	gemdos	Cconws,6

	move.l	allocsz(pc),-(sp)       ; Allocate memory
	gemdos	Malloc,6                ;

	tst.l	d0                      ; Check that malloc worked
	beq.w	memfail                 ;

	lea	allocsz(pc),a0          ;
	move.l	d0,(a0)                 ; Save address into alloc size

	; Specialized single byte ACSI driver

	st	flock.w                 ; Lock floppy drive

	lea	dmactrl.w,a1
	move.w	#$190,(a1)              ; Reset DMA
	move.w	#$90,(a1)               ; Read mode, set DMA length

	; DMA transfer address
	move.b	d0,dmalow.w             ; Set DMA address low
	lsr.l	#8,d0                   ;
	move.b	d0,dmamid.w             ; Set DMA address mid
	lsr.w	#8,d0                   ;
	move.b	d0,dmahigh.w            ; Set DMA address high

	move.l	#$00ff0088,dma.w        ; Read 255 blocks. Switch to command.

	move.b	d7,d0                   ; Build command: ACSI id | $0d
	or.b	#$0d,d0                 ;
	swap	d0                      ; Command in data register, then DMA.
	move.l	d0,dma.w                ; Send command $d and start DMA

	; Wait until DMA ack (IRQ pulse)
	move.l	#20,d0                  ; 100ms timeout
	add.l	hz200.w,d0              ;
.await	cmp.l	hz200.w,d0              ; Test timeout
	blt.b	fail                    ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Acknowledge status byte
	move.w	dma.w,d0                ;

	sf	flock.w                 ; Unlock floppy drive

	tst.b	d0                      ; If DMA failed,
	bne.b	fail                    ; free RAM and continue
	
	move.l	allocsz(pc),a0          ; Recall driver address

	lea	4(a0),a1                ; Check payload signature
	lea	signature(pc),a2        ;
	moveq	#3,d0                   ;
.chk	cmp.l	(a1)+,(a2)+             ;
	bne.b	fail                    ;
	dbra	d0,.chk                 ;

	jmp	$14(a0)                 ; Call the driver

fail
	sf	flock.w                 ; Unlock floppy drive
	move.l	allocsz(pc),-(sp)       ; Free RAM
	gemdos	Mfree,6                 ;
memfail
	pea	msg.fail(pc)
	gemdos	Cconws,6
	rts

	; Data

	even
msg.loading
	a2st_header
	dc.b	'Loading...'
	dc.b	13,10,0
msg.fail
	dc.b	'Error'
	dc.b	7,13,10,0

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
