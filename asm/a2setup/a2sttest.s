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

; ACSI2STM setup tool
; Unit test

a2sttest
	cls

	; Command tests

	moveq	#0,d3
	print	.tstrd(pc)

.cmdtst	print	.cmdp(pc)
	lea	a2sttest.cmd(pc),a3
	bsr.w	a2sttest.tstcmd

	print	.zcmdp(pc)
	lea	a2sttest.zcmd(pc),a3
	bsr.w	a2sttest.tstcmd

	print	.fcmdp(pc)
	lea	a2sttest.fcmd(pc),a3
	bsr.w	a2sttest.tstcmd

	tst.w	d3
	bne.b	.cmdok
	print	.tstwr(pc)
	move.w	#$0100,d3
	bra.b	.cmdtst
.cmdok

	; Set DMA buffer size

	print	.getbuf(pc)

	lea	a2sttest.rwbuffer(pc),a0;
	move.w	#$3c03,2(a0)            ; Read descriptor
	clr.b	4(a0)                   ; Switch to standard buffer
	move.w	#1,d0                   ;
	bsr.w	a2sttest.bufop          ;

	bsr.w	blkdev.flush            ; Flush DMA buffer

	move.l	bss+buf(pc),d0          ; Cap to the local buffer size
	cmp.w	#buf...,d0              ;
	bls.b	.szok                   ;
	move.w	#buf...,d0              ;
.szok
	moveq	#1,d1
	bsr.w	puint
	bsr.w	crlf

	move.l	d0,d5                   ;
	lsr.l	#2,d5                   ; Set buffer size
	subq.l	#1,d5                   ; d5 = fillbuf counter
	lsl.l	#8,d0                   ;
	lea	a2sttest.rwbuffer(pc),a0;
	move.l	d0,8(a0)                ;

	print	.ckpat(pc)              ;
	move.l	#$f00f55aa,d3           ; Pattern expected by the ACSI2STM unit
	lea	a2sttest.rwbuffer(pc),a0; Switch to the pattern check buffer
	move.b	#$01,4(a0)              ;
	bsr.w	a2sttest.tstdma         ;

	lea	a2sttest.rwbuffer(pc),a0; Switch back to the normal buffer
	move.b	#$00,4(a0)              ;

	lea	.patlst(pc),a3
.nextlb	
	move.l	(a3)+,d3

	print	.tstpat(pc)
	move.l	d3,d0
	bsr.w	phlong
	bsr.w	crlf

	bsr.w	a2sttest.tstdma
	tst.l	d3
	bne.b	.nextlb

	print	.succss(pc)

	bra.w	a2sttest.exit

	; Test descriptions
.tstrd	dc.b	'Testing in read mode',13,10,0
.cmdp	dc.b	'Test command',13,10,0
.zcmdp	dc.b	'Zero filled command',13,10,0
.fcmdp	dc.b	'Ones filled command',13,10,0
.tstwr	dc.b	'Testing in write mode',13,10,0
.getbuf	dc.b	'Fetch buffer size:',0
.ckpat	dc.b	'Check DMA with data integrity',13,10,0
.tstpat	dc.b	'Testing DMA with pattern ',0
.succss	dc.b	'All tests successful',13,10,0
	even

.patlst	dc.l	$55aa55aa,$ff00ff00
	dc.l	$f00f55aa,$55aaf00f
	dc.l	$01020408,$10204080
	dc.l	$fefdfbf7,$efdfbf7f
	dc.l	$ffffffff,$00000000

a2sttest.tstcmd
	; Do a mass command test by repeating the same command a lot of times
	; Input:
	;  a3: command
	;  d3.w: $0100 to use write mode, $0000 to use read mode
	;  d7.b: Device id
	; Output:
	;  d0.b: 0 iif successful

	move.w	#32,d4                  ; d4 = loop counter

.again	move.l	d3,d0
	lea	(a3),a0
	bsr.w	acsicmd

	tst.b	d0
	dbne	d4,.again

	tst.b	d0
	bne.w	a2sttest.failed

	rts

a2sttest.tstdma
	bsr.w	a2sttest.fillbuf        ; Fill the buffer with the test pattern

	moveq	#15,d4                  ; Do 16 test loops

.next	lea	a2sttest.rwbuffer(pc),a0; Switch acsi buffer command to write
	move.w	#$3b02,2(a0)            ; Write data buffer
	move.w	#$0140,d0               ; Write 64 buffers max
	bsr.w	a2sttest.bufop          ; Do the acsi buffer operation

	moveq	#-1,d2                  ; Flip all bits in RAM
	eor.l	d2,d3                   ;
	bsr.b	a2sttest.fillbuf        ;
	eor.l	d2,d3                   ;

	lea	a2sttest.rwbuffer(pc),a0; Patch acsi command to read
	move.b	#$3c,2(a0)              ; Switch to read data buffer
	moveq	#$40,d0                 ; Read 64 buffers max
	bsr.w	a2sttest.bufop          ; Do the buffer operation

	lea	bss+buf(pc),a1          ; Compare the buffer
	move.l	d5,d1                   ;
.check	cmp.l	(a1)+,d3                ; Test the correct pattern
	bne.b	a2sttest.failed         ;
	dbra	d1,.check               ;

	dbra	d4,.next                ; Loop tests
	rts

a2sttest.fillbuf
	lea	bss+buf(pc),a0
	move.w	d5,d1
.copy	move.l	d3,(a0)+
	dbra	d1,.copy
	rts

a2sttest.bufop
	lea	bss+buf(pc),a1          ; DMA from/to SCSI data buffer
	move.l	a1,d1                   ;
	bsr.w	acsicmd                 ;

	tst.b	d0
	bne.b	a2sttest.failed
	rts

a2sttest.cmd	; ACSI2STM command loopback test
	dc.b	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	dc.b	'A2STCmdTs'             ; Command test
	even

a2sttest.zcmd	; ACSI2STM zero command loopback test
	dc.b	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	ds.b	9                       ; Zero bytes
	even

a2sttest.fcmd	; ACSI2STM 0xff command loopback test
	dc.b	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	dc.b	$ff,$ff,$ff,$ff,$ff     ; All ones
	dc.b	$ff,$ff,$ff,$ff         ;
	even

a2sttest.failed
	print	a2sttest.failmsg(pc)
a2sttest.exit
	bsr.w	presskey
	restart

a2sttest.failmsg
	dc.b	7,'Test failed',13,10,0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
