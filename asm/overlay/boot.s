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
;  $000-$001: bra.b $60(pc) ; $605e
;  $002-$059: FAT header
;  $05a-$05b: checksum (patched by the STM32)
;  $05c-$05e: driver alloc size (patched from a2stdrv.bin)
;       $05f: driver size in sectors
;  $060-$1b7: this code
;  $1b8-$1ff: partition table
;
; Program format:
;  $00-$03: 'A2ST' signature
;  $04-$06: memory allocation size
;      $07: sector count
;      $08: entry point

	org	$60
	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

drvaloc	equ	boot-4

boot	pea	msg.loading(pc)
	gemdos	Cconws,6

	ifne	enablesetup

	ifne	enableserial
	gemdos	Cauxis,2                ; Check for data on the serial port
	tst.b	d0                      ;
	bne.b	.serial
	endc

	gemdos	Cconis,2
	tst.b	d0
	beq.b	.drv

	gemdos	Cnecin,2                ; Check for Shift+S
	cmp.b	#'S',d0                 ;
	bne.b	.drv                    ;

.setup	moveq	#3,d0                   ; Load and run configuration tool
	swap	d0                      ;
	moveq	#$c,d1                  ;
	bra.b	load                    ;

	ifne	enableserial
.serial	
	moveq	#1,d3                   ; Remap conout to serial
	bsr.b	.dup                    ;
	moveq	#0,d3                   ; Remap conin to serial
	bsr.b	.dup                    ;

	bra.b	.setup
.dup	
	move.w	#2,-(sp)
	gemdos	Fdup,4
	move.w	d0,-(sp)
	move.w	d3,-(sp)
	gemdos	Fforce,6
	rts
.drv	
	endc

	endc

	move.l	drvaloc(pc),d0
	lsr.l	#8,d0
	moveq	#$d,d1
	; Fall through the ACSI loader

load	; Specialized single byte ACSI loader
	; Input:
	;  d0.l: program size
	;  d1.b: ACSI command to send
	;  d7.b: ACSI id

	move.l	d0,-(sp)                ; Allocate RAM for the program
	gemdos	Malloc,6                ;

	tst.l	d0                      ; Check that malloc worked
	beq.w	fail                    ;

	move.l	d0,a2                   ; Save program address

	st	flock.w                 ; Lock floppy drive

	move.l	a3,-(sp)                ; a3 = DMA port
	lea	dma.w,a3

	lea	dmactrl.w,a1

	move.w	#$190,(a1)              ; Reset DMA
	move.w	#$90,(a1)               ; Read mode, set DMA length

	; DMA transfer address
	move.b	d0,dmalow.w             ; Set DMA address low
	lsr.l	#8,d0                   ;
	move.b	d0,dmamid.w             ; Set DMA address mid
	lsr.w	#8,d0                   ;
	move.b	d0,dmahigh.w            ; Set DMA address high

	move.l	#$00ff0088,(a3)         ; Read 255 blocks. Switch to command.

	move.b	d7,d0                   ; Build command: ACSI id | command
	or.b	d1,d0                   ;
	swap	d0                      ; Command in data register, then DMA.
	move.l	d0,(a3)                 ; Send command $d and start DMA

	; Wait until DMA ack (IRQ pulse)
.await	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Acknowledge status byte
	move.w	(a3),d0                 ;

	sf	flock.w                 ; Unlock floppy drive

	tst.b	d0                      ; If DMA failed,
	bne.b	fail                    ; free RAM and continue

	cmp.l	#'A2ST',(a2)            ; Check signature
	bne.b	fail                    ;

	move.l	(sp)+,a3
	jmp	8(a2)                   ; Call the code

fail	reboot

	; Data

msg.loading
	a2st_header

	ifd	enablesetup
	dc.b	'Shift+S for setup'
	dc.b	13,10
	endc

	dc.b	0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
