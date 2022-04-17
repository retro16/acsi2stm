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
; Displays a message and waits 1 second to allow entering setup.
;
; Program format:
;  $00-$03: 'A2ST' signature
;  $04-$07: memory allocation size
;      $08: entry point

	org	0

	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

nosd
	move.b	d7,d0                   ; Get the acsi id
	lea	acsiid(pc),a0           ; Patch acsi id in the text
	lsr.b	#5,d0                   ;
	add.b	d0,(a0)                 ; Add acsi id to '0'

	pea	msg.nosd(pc)            ; Display the header message
	gemdos	Cconws,6                ;

	move.l	d3,-(sp)                ; d3 = hz200 + 2 second
	move.l	hz200.w,d3              ;
	add.l	#400,d3                 ;

.wait	gemdos	Cconis,2                ; Check if a key is pressed
	tst.b	d0                      ;
	beq.b	.nokey                  ;

	gemdos	Cnecin,2                ;
	cmp.b	#'S',d0                 ; If Shift+S was pressed
	beq.w	setup                   ; Run setup

	bra.b	.quit                   ; Else quit right now

.nokey	cmp.l	hz200.w,d3              ; Loop for 1 second
	bpl.b	.wait                   ;

.quit	move.l	(sp)+,d3                ; Exit to boot
	rts                             ;

msg.nosd
	a2st_header                     ; Welcome header text
	dc.b	13,10
 	dc.b	'SD'                    ; "SD0", patched to match the SD id
acsiid	dc.b	'0: '
	dc.b	'No SD card',13,10      ; "No SD card" message
	dc.b	'Shift+S to run setup'	;
	dc.b	13,10
	dc.b	13,10,0
	even

setup	; Load setup from the STM32 firmware using the single byte command 0x0c
	; Any kind of error triggers a full reset
	; Input:
	;  d7.b: ACSI id

	pea	-1.w                    ; Allocate all available RAM for setup
	gemdos	Malloc,6                ;
	tst.l	d0                      ;
	beq.b	reset                   ;

	move.l	d0,a2                   ; Save program address

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

	move.b	d7,d0                   ; Build command: ACSI id | command
	or.b	#$0c,d0                 ;
	swap	d0                      ; Command in data register, then DMA.
	move.l	d0,dma.w                ; Send command and start DMA

	; Wait until DMA ack (IRQ pulse)
	move.l	#20,d0                  ; 100ms timeout
	add.l	hz200.w,d0              ;
.await	cmp.l	hz200.w,d0              ; Test timeout
	bmi.b	reset                   ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Acknowledge status byte
	move.w	dma.w,d0                ;

	sf	flock.w                 ; Unlock floppy drive

	tst.b	d0                      ; If DMA failed,
	bne.b	reset                   ; just reset

	cmp.l	#'A2ST',(a2)            ; Check signature
	bne.b	reset                   ;

	jsr	8(a2)                   ; Call the code

reset	move.l	4.w,a0                  ; Reset instead of trying to clean up
	jmp	(a0)                    ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
