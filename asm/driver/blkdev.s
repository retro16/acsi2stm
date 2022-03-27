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

; ACSI2STM integrated driver
; Block device high level functions

blk.wr	; Write to block device
	; Input:
	;  d0.w: block count (limited to $00ff)
	;  d1.l: Source address
	;  d2.l: Block number
	;  d7.b: Device id
	; Output:
	;  d0.l: ASCQ/ASC/Key or -1 if timeout

	lea	acsi.rw(pc),a0
	move.b	#$2a,2(a0)
	move.l	d2,4(a0)
	and.w	#$00ff,d0
	move.b	d0,10(a0)
	bset	#8,d0
	bra.b	blk.exc

blk.rd	; Read from block device
	; Input:
	;  d0.w: block count (limited to $00ff)
	;  d1.l: Target address
	;  d2.l: Block number
	;  d7.b: Device id
	; Output:
	;  d0.l: ASCQ/ASC/Key or -1 if timeout

	lea	acsi.rw(pc),a0
	move.b	#$28,2(a0)
	move.l	d2,4(a0)
	and.w	#$00ff,d0
	move.b	d0,10(a0)

	; Fall through blk.exc
	
blk.exc ; Execute a command and sense errors
	bsr.w	acsicmd
	tst.b	d0
	bgt.b	blk.sns
	moveq	#0,d0
	rts

blk.sns	; Sense error code
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.l: ASCQ/ASC/Key or -1 if timeout

	lea	acsi.sns(pc),a0         ; Run Request sense
	moveq	#1,d0                   ;
	lea	bss+buf(pc),a1          ;
	move.l	a1,d1                   ;
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Process sense error
	bge.b	.ntmout                 ;
	rts                             ;
.ntmout	beq.b	.snsok                  ;
	moveq	#-1,d0                  ;
	rts                             ;

.snsok	moveq	#0,d0
	lea	bss+buf(pc),a0          ; Read ASCQ/ASC/Key
	move.b	3(a0),d0                ; ASCQ
	swap	d0                      ;
	move.b	12(a0),d0               ; ASC
	lsl.w	#8,d0                   ;
	move.b	2(a0),d0                ; Sense key
	rts

blk.cap	; Read capacity
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.l: Block count or 0 if error

	lea	acsi.cap(pc),a0         ; Send read capacity
	moveq	#1,d0                   ;
	lea	bss+buf(pc),a1          ;
	move.l	a1,d1                   ;
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Check for error
	bne.b	.fail                   ;

	lea	acsi.cap(pc),a0         ; Flush buffer by doing it twice
	move.w	#$0201,d0               ;
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Check for error
	bne.b	.fail                   ;

	move.l	bss+buf(pc),d0          ; Read capacity: returns last sector
	addq.l	#1,d0                   ; Return sector count
	rts

.fail	moveq	#0,d0                   ; Return 0 in case of error
	rts                             ;

blk.tst	; Test unit ready
	; Note: this has a custom implementation with a much reduced timeout
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.l: ASCQ/ASC/Key or -1 if timeout

	moveq	#0,d0
	lea	acsi.tst(pc),a0
	bsr.w	acsicmd

	tst.w	d0
	beq.b	.end
	bmi.b	.end

	bsr.w	blk.sns                 ; Error returned: do a request sense

.end	rts


; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
