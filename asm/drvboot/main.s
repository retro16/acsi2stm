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
; Needs to be patched at $1b2 with malloc size and sector count
;
; Boot sector format:
;  $000-$1b1: this code
;  $1b2-$1b4: malloc size
;       $1b5: sector count
;  $1b6-$1b7: checksum
;  $1b8-$1ff: partition table

	org	0
	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i

load	print	msg.loading(pc)

	move.l	allocsz(pc),d0          ; Compute allocation size and sectors
	bne.b	.szset                  ; Check that values have been patched
	rts	                        ; If not, return
.szset
	lea	acsi.sc(pc),a0          ; Patch sector count
	move.b	d0,(a0)                 ;

	lsr.l	#8,d0                   ; Shift to get allocation size

	move.l	d0,-(sp)                ; Allocate memory
	gemdos	Malloc,6                ;

	lea	allocsz(pc),a0          ;
	move.l	(a0),d2                 ; Keep original value for later
	move.l	d0,(a0)                 ; Save address into alloc size
	beq.b	memfail                 ; Check that we didn't have a NULL ptr

	move.l	d0,d1                   ; Set DMA target

	moveq	#0,d0                   ;
	move.b	d2,d0                   ; Set sector count

	lea	acsi.read(pc),a0        ; Read the driver
	bsr.b	acsicmd                 ;

	tst.b	d0                      ; If DMA failed,
	bne.b	fail                    ; free RAM and continue
	
	move.l	allocsz(pc),a0          ; Recall driver address

	cmp.l	#'A2ST',(a0)            ; Check signature
	bne.b	fail                    ;

	jmp	8(a0)                   ; Call the driver

fail
	move.l	allocsz(pc),-(sp)       ; Free allocated memory
	gemdos	Mfree,6                 ;

memfail
	pea	msg.fail(pc)            ;
	gemdos	Cconws,6                ;
	rts

	include	acsicmd.s

	; Data

	even
acsi.read
	dc.b	4
	dc.b	$08,$00,$00,$01
acsi.sc	dc.b	$00
	dc.b	$00
msg.loading
	a2st_header
	dc.b	13,10
	dc.b	'Boot sector'
	dc.b	13,10,0
msg.fail
	dc.b	'Error'
	dc.b	7,13,10,0

	even

	org	$1b2                    ; Allocation size
allocsz	ds.l	1                       ; Patched by tools

	org	$1b6                    ; Reserve space for the
	ds.w	1                       ; checksum

	org	$1b8                    ; Reserve space for the
	ds.b	$48                     ; partition table


; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
