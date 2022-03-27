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

; Boot sector to load the driver from a normal disk
; Loads a payload with the ACSI read command
;
; Boot sector format:
;  $000-$1b5: this code
;  $1b6-$1b7: checksum
;  $1b8-$1ff: partition table
;
; Return value in d0:
;  Bit 0: if set, Mfree will not be called on return
;  Bit 1: if set, skip other boot drives

	org	0
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

load	pea	msg.loading(pc)
	gemdos	Cconws,6

	move.l	allocsz(pc),-(sp)       ; Allocate memory
	gemdos	Malloc,6                ;

	tst.l	d0                      ; Check that malloc worked
	beq.b	memfail                 ;

	lea	allocsz(pc),a0          ;
	move.l	d0,(a0)                 ; Save address into alloc size

	move.l	d0,d1                   ; Set DMA target
	beq.b	fail                    ; Check that we didn't have a NULL ptr

	move.w	#sectors,d0             ; Set DMA sector count
	lea	acsi.read(pc),a0        ; Read the driver
	bsr.b	acsicmd                 ;

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
	move.l	allocsz(pc),-(sp)       ; Free allocated memory
	gemdos	Mfree,6                 ;

memfail
	pea	msg.fail(pc)            ;
	gemdos	Cconws,6                ;
	rts

	include	acsicmd.s

	; Data

sectors	equ	(bss-payload+$1ff)/$200 ; Driver size in sectors

	even
acsi.read
	dc.b	4
	dc.b	$08,$00,$00,$01
	dc.b	sectors
	dc.b	$00
msg.loading
	a2st_header
	dc.b	13,10,0
msg.fail
	dc.b	'Error'
	dc.b	7,13,10,0

	even
signature
	dc.b	'ACSI2STM OVERLAY'
	even
allocsz
	dc.l	bss+bss...-payload

	org	$1b6                    ; Reserve space for the
	ds.w	1                       ; checksum

	org	$1b8                    ; Reserve space for the
	ds.b	$48                     ; partition table

	org	$200                    ; Next sector

payload
	incbin	..\driver\driver.bin
	include	..\driver\structs.i
	include	..\driver\bss.s
bss

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
