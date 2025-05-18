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

; Test DMA using READ BUFFER and WRITE BUFFER SCSI commands

buftest:
	print	.desc

.patcnt	equ	4                       ; Number of times each pattern is looped

	moveq	#1,d0                   ; Read header to get buffer length
	move.l	#buffer,d1              ;
	lea	.bhcmd,a0               ;
	bsr	acsicmd.sense           ;

	lea	.nsuprt,a5              ; Check if supported
	tst.b	d0                      ;
	bne	.failed                 ;

	clr.b	buffer                  ; d3 = buffer size
	move.l	buffer,d3               ;

	cmp.l	#$10000,d3              ; Cap to 64k
	bls.b	.bfszok                 ;
	move.l	#$10000,d3              ;
.bfszok	and.l	#$1fff0,d3              ; Align to 16 bytes

	move.l	d3,d0                   ; Update ACSI commands
	lsl.l	#8,d0                   ;
	move.l	d0,buftest.read.len     ;
	move.l	d0,buftest.write.len    ;

	lsr.l	#2,d3                   ; Adjust for long words
	subq	#1,d3                   ; Adjust for dbra

.loop	lea	.patlst,a3              ; a3 = current pattern

.pat	move.w	d3,d1                   ; Fill the buffer with pattern
	move.l	(a3),d0                 ; Load pattern
	lea	buffer,a0               ; Fill buffer with pattern
.pfill	move.l	d0,(a0)+                ;
	dbra	d1,.pfill               ;

	gemdos	Cconis,2                ; Exit if a key was pressed
	tst.l	d0                      ;
	bne	.exit                   ;

	moveq	#.patcnt-1,d4           ; d4. = buffer r/w pass count
		                        ; d4 bit 16: error flag

.pass	move.w	#$01ff,d0               ; Write pass
	move.l	#buffer,d1              ;
	lea	buftest.write,a0        ;
	bsr	acsicmd                 ;

	tst.b	d0                      ; Check write result
	bne	.perr                   ;

	move.w	#$00ff,d0               ; Read pass
	move.l	#buffer,d1              ;
	lea	buftest.read,a0         ;
	bsr	acsicmd                 ;

	tst.b	d0                      ; Check read result
	bne	.perr                   ;

	dbra	d4,.pass                ;

	move.w	d3,d1                   ; Check the buffer for pattern
	move.l	(a3),d0                 ; Load pattern
	lea	buffer,a0               ;
.pchk	cmp.l	(a0)+,d0                ;
	bne	.perr                   ;
	dbra	d1,.pchk                ;

.pnext	tst.l	(a3)+                   ; Next pattern if not null
	bne	.pat

	btst	#16,d4                  ; Display CRLF only if there was some
	beq	.loop                   ; errors
	crlf	                        ;

	bra	.loop

.perr	pchar	'X'                     ; Fill the line with an X
	bset	#16,d4                  ; Set error flag
	bra	.pnext                  ; Next pattern

.exit	gemdos	Cnecin,2                ; Flush keyboard buffer / wait for a key
	crlf	                        ;
	rts	                        ;

.failed	print	(a5)                    ; Print error
	bra	.exit                   ; Wait for a key and exit

.desc	dc.b	'Buffer load test. Press any key to exit.',$0d,$0a
	dc.b	0

.nsuprt	dc.b	'Device does not support buffer commands.',$0d,$0a
	dc.b	0

.bhcmd	dc.b	8                       ;
	dc.b	$1f,$3c,$00,$00         ; Read buffer and header
	dc.b	$00,$00,$00             ; Offset 0
	dc.b	$00,$00,$10             ; Read 16 bytes
	dc.b	$00                     ;

.patlst	dc.l	$00ff00ff
	dc.l	$ffffffff
	dc.l	$10204080
	dc.l	$01020408
	dc.l	$11224488
	dc.l	$efdfbf7f
	dc.l	$fefdfbf7
	dc.l	$eeddbb77
	dc.l	$55aa55aa
	dc.l	$11002200
	dc.l	$44008800
	dc.l	$11ff22ff
	dc.l	$44ff88ff
	dc.l	$eeffddff
	dc.l	$bbff77ff
	dc.l	$ee00dd00
	dc.l	$bb007700
	dc.l	$00000000

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
