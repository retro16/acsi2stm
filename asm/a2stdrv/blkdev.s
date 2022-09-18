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
	;  d0.l: ASC/Key or -1 if timeout

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
	;  d0.l: ASC/Key or -1 if timeout

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
	bne.b	.rts
	moveq	#0,d0
.rts	rts

blk.sns	; Sense error code
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.l: ASC/Key or -1 if timeout

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
	lea	bss+buf(pc),a0          ; Read ASC/Key
	move.b	12(a0),-(sp)            ; ASC
	move.w	(sp)+,d0                ;
	move.b	2(a0),d0                ; Sense key
	rts

blk.inq	; Inquiry
	; Input:
	;  d7.b: Device id
	; Output:
	;  bss+buf: inquiry data
	;  d0.b: 0 iif successful

	lea	acsi.inq(pc),a0         ; Send inquiry
	moveq	#1,d0                   ;
	lea	bss+buf(pc),a1          ;
	move.l	a1,d1                   ;
	bra.w	acsicmd                 ;


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
	;  d0.l: ASC/Key or -1 if timeout

	moveq	#0,d0
	lea	acsi.tst(pc),a0
	bsr.w	acsicmd

	tst.w	d0
	beq.b	.end
	bmi.b	.end

	bsr.w	blk.sns                 ; Error returned: do a request sense

.end	rts

; ACSI to TOS error code conversion

acsierr	; Converts an ACSI ASCQ/ASC/Sense error code to a TOS error code
	; Input:
	;  d0.w:ACSI error code
	; Output:
	;  d0.l:TOS error code
	;  Z flag: set if success
	move.w	d0,d1
	bne.b	.nok
	moveq	#0,d0
	rts

.nok	lea	.errtbl(pc),a0
.loop	movem.w	(a0)+,d0/d2
	tst.w	d2
	beq.b	.end
	cmp.w	d1,d2
	bne.b	.loop

.end	ext.l	d0
	rts

; Error code matching table

.errtbl
	dc.w	EREADF,blkerr.read
	dc.w	EWRITF,blkerr.write
	dc.w	E_CHNG,blkerr.mchange
	dc.w	EUNDEV,blkerr.nomedium
	dc.w	ESECNF,blkerr.invaddr
	dc.w	EWRPRO,blkerr.wprot
	dc.w	EUNDEV,blkerr.invlun
	dc.w	ERR,0

; ACSI errors

blkerr.timeout	equ	-1
blkerr.ok	equ	0
blkerr.read	equ	$1103
blkerr.write	equ	$0303
blkerr.wprot	equ	$2707
blkerr.opcode	equ	$2005
blkerr.invaddr	equ	$2105
blkerr.invarg	equ	$2405
blkerr.invlun	equ	$2505
blkerr.mchange	equ	$2806
blkerr.nomedium	equ	$3a06

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
