; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2024 by Jean-Matthieu Coulon

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

; Hard disk drive updater, using the GemDrive PIO protocol

	include	tui.s
	even

main:	print	.header

	; Load the firmware

	lea	_start-127,a3           ; Parse parameter as a file name
	tst.b	(a3)                    ;
	bne.b	.prmok                  ;
	lea	.file,a3                ; No parameter: use default file name
.prmok		                        ; a3 = firmware file name

	print	.lding                  ; Print file name
	print	(a3)                    ;
	crlf	                        ;

	clr.w	-(sp)                   ; Open the firmware file
	pea	(a3)                    ;
	gemdos	Fopen,8                 ;
	tst.w	d0                      ;
	bmi	.nfirm                  ;
	move.w	d0,d3                   ; d3 = firmware file handle

	moveq	#0,d4                   ; d4 = actual firmware length
	move.l	#firmlen,d5             ; d5 = bytes to read
	move.l	#firm,d6                ; d6 = read pointer

.rdloop	move.l	d6,-(sp)                ; Read the firmware to RAM
	move.l	d5,-(sp)                ;
	move.w	d3,-(sp)                ;
	gemdos	Fread,12                ;
	add.l	d0,d6                   ; Move buffer pointer
	add.l	d0,d4                   ; Count firmware size
	sub.l	d0,d5                   ; Count remaining bytes in the buffer
	tst.l	d0                      ; Check return code
	bmi	.clfirm                 ;
	tst.l	d0                      ; Check end of file
	bne	.rdloop                 ;
	move.w	d3,-(sp)                ; Close the file
	gemdos	Fclose,4                ;
	tst.l	d5                      ; Check buffer overflow
	beq	.bigfw                  ;

	; Select target hard disk

.devrq	print	.askid                  ;
	gemdos	Cnecin,2                ; Read drive letter

	cmp.b	#$1b,d0                 ; Exit if pressed Esc
	beq	.exit                   ;

	sub.b	#'0',d0                 ; Transform to id
	and.w	#$00ff,d0               ;

	cmp.w	#7,d0                   ; Check if it is a valid letter
	bhi	.devrq                  ; Not a letter: try again

	lsl.w	#5,d0                   ; Store to d7
	move.w	d0,d7                   ;

	print	.sure                   ; Ask if really sure to flash
	gemdos	Cnecin,2                ;
	cmp.b	#'Y',d0                 ;
	bne	.exit                   ;

	; Send upload command

	print	.ulding                 ;

	lea	firmcmd(pc),a0          ; a0 = Command buffer
	lea	dmactrl.w,a1            ; a1 = DMA control register
	lea	dmadata.w,a2            ; a2 = DMA data register
	lea	firm(pc),a3             ; a3 = pointer to firmware data

	or.b	d7,(a0)                 ; Set device id
	moveq	#0,d0                   ; d0 = byte to send
	moveq	#5,d1                   ; d1 = byte count - 1
	move.w	d4,4(a0)                ; Set firmware length

	st	flock.w                 ; Lock floppy controller

	move.w	#$0088,(a1)             ; Enable A1 line
.cmdbyt	move.b	(a0)+,d0                ; Read command byte from buffer
	move.w	d0,(a2)                 ; Send command byte
	bsr.b	.waitiq                 ; Wait for IRQ
	move.w	#$008a,(a1)             ; Disable A1
	dbra	d1,.cmdbyt              ; Next command byte

	move.w	(a2),d0                 ; Read result byte
	tst.b	d0                      ; Check if successful
	bne	.refusd                 ;

	; Upload firmware data

	moveq	#0,d0                   ; d0 = byte to send
	subq	#1,d4                   ; Adjust size for dbra

.fwbyte	bsr.b	.waitiq                 ; Wait for IRQ
	move.b	(a3)+,d0                ; Read firmware byte from buffer
	move.w	d0,(a2)                 ; Send firmware byte
	dbra	d4,.fwbyte              ;

	move.l	4.w,a0                  ; Reboot
	jmp	(a0)                    ;

.exitky	sf	flock.w                 ; Unlock floppy controller
	gemdos	Cnecin,2                ; Wait for a key
.exit	Pterm0

.refusd	print	.refus                  ; Print error
	bra.b	.exitky                 ;

.waitiq	moveq	#20,d2                  ; 100ms timeout
	add.l	hz200.w,d2              ;
.await	cmp.l	hz200.w,d2              ; Test timeout
	bmi.b	.timout                 ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;
	rts	                        ;
.timout	print	.noresp                 ;
	bra	.exitky                 ;

.clfirm	move.w	d3,-(sp)                ; Close the file
	gemdos	Fclose,4                ;
.nfirm	print	.nffile                 ;
	print	(a3)                    ;
	crlf	                        ;
	bra	.exitky                 ;

.bigfw	print	.toobig                 ;
	bra	.exitky                 ;

.header	dc.b	$1b,'E','PIO firmware flasher v'
	incbin	..\..\VERSION
	dc.b	$0d,$0a
	dc.b	'By Jean-Matthieu Coulon',$0d,$0a
	dc.b	'https://github.com/retro16/acsi2stm',$0d,$0a
	dc.b	'License: GPLv3',$0d,$0a
	dc.b	$0d,$0a
	dc.b	0

.askid	dc.b	$0d,$1b,'K','Please input the ACSI device (0-7):',0

.lding	dc.b	'Loading firmware file ',0

.file	dc.b	'PIOFLASH.BIN',0

.nffile	dc.b	'Cannot open firmware file ',0

.toobig	dc.b	'Firmware image is too big.',$0d,$0a
	dc.b	0

.sure	dc.b	$0d,$0a
	dc.b	$0d,$0a
	dc.b	'Flashing firmware cannot be cancelled.',$0d,$0a
	dc.b	'If flashing is successful, the ST will',$0d,$0a
	dc.b	'reboot automatically.',$0d,$0a
	dc.b	'If you are really sure you want to flash',$0d,$0a
	dc.b	'the firmware, type capital Y. Any other',$0d,$0a
	dc.b	'key will exit now',$0d,$0a
	dc.b	0

.ulding	dc.b	$0d,$0a
	dc.b	'Flashing firmware ...',0

.refus	dc.b	' Refused by device',$0d,$0a
	dc.b	0

.noresp	dc.b	' Timeout',$0d,$0a
	dc.b	0

.inqry	dc.b	3,$12,$00,$00,$00,$ff,$00
.inqext	dc.b	4,$1f,$12,$00,$00,$00,$ff,$00

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
