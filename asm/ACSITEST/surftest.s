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

; Test disk surface by spamming READ and WRITE SCSI commands

surftest:

.tstpat	equ	buffer+1024

	print	.desc

	move.w	#$0001,d0               ; Request device size
	move.l	#buffer,d1              ;
	lea	.rccmd,a0               ;
	bsr	acsicmd.flush           ;

	lea	.rcfail,a5              ; Check that the command is successful
	tst.b	d0                      ;
	bne	.failed                 ;

	lea	buffer,a0

	lea	.invsc,a5               ; Check sector count
	move.l	buffer,d3               ; d3 = sector count
	beq	.failed                 ;
	moveq	#0,d4                   ; d4 = current sector

	lea	.invss,a5               ; Check sector size
	cmp.l	#$00000200,4(a0)        ;
	bne	.failed                 ;

	crlf	                        ;
	pchar2	$1b,'f'                 ; Hide cursor

	lea	.tstpat,a0              ; Fill test pattern
	move.w	#511,d0                 ;
.fill	move.b	d0,(a0)+                ;
	dbra	d0,.fill                ;

.loop	gemdos	Cconis,2                ; Exit on key press
	tst.l	d0                      ;
	bne	.exit                   ;

	move.l	d4,d0                   ; Print current block
	tst.b	d0                      ; every 256 blocks
	bne.b	.noprt                  ;
	bsr	.prtblk                 ;
.noprt

	cmp.l	#$1fffff,d4             ; Do we need long commands ?
	bhi	.long                   ;

	swap	d4                      ; Update block number in commands
	move.b	d4,surftest.read6.blk   ;
	move.b	d4,surftest.write6.blk  ;
	swap	d4                      ;
	move.w	d4,surftest.read6.blk+1	;
	move.w	d4,surftest.write6.blk+1;

	lea	surftest.read6,a3       ; Set pointers to read and write
	lea	surftest.write6,a4      ; commands

	bra.b	.szset

.long	move.l	d4,surftest.read10.blk  ; Update block number in commands
	move.l	d4,surftest.write10.blk ;

	lea	surftest.read6,a3       ; Set pointers to read and write
	lea	surftest.write6,a4      ; commands
.szset

	moveq	#$00000001,d0           ; Read original data
	move.l	#buffer,d1              ;
	lea	(a3),a0                 ;
	bsr	acsicmd.sense           ;
	bsr	.chkret                 ;

	move.w	#$0101,d0               ; Write pattern data
	move.l	#.tstpat,d1             ;
	lea	(a4),a0                 ;
	bsr	acsicmd.sense           ;
	bsr	.chkret                 ;

	clr.l	.tstpat                 ; Corrupt pattern in memory to detect
	clr.l	.tstpat+508             ; incomplete read

	moveq	#$00000001,d0           ; Read back pattern data
	move.l	#.tstpat,d1             ;
	lea	(a3),a0                 ;
	bsr	acsicmd.sense           ;
	bsr	.chkret                 ;

	moveq	#4,d5                   ; Retry writing 5 times

.wretry	move.w	#$0101,d0               ; Write back original data
	move.l	#buffer,d1              ;
	lea	(a4),a0                 ;
	bsr	acsicmd.sense           ;
	tst.b	d0                      ; Retry before giving up
	dbeq	d5,.wretry              ;

	cmp.w	#4,d5                   ; Warn if retried
	beq.b	.wok                    ;
	bsr	.retrid                 ;

.wok	bsr	.chkret                 ; Check and display error

	lea	.tstpat,a0              ; Check pattern data
	move.w	#511,d0                 ;
.ckpat	cmp.b	(a0)+,d0                ;
	bne	.corupt                 ;
	dbra	d0,.ckpat               ;

	addq	#1,d4                   ; Go to next block
	cmp.l	d4,d3                   ;
	bne	.loop                   ;

	subq	#1,d4                   ; Cancel last increment
	move.l	d4,d0                   ; Print current block
	bsr	.prtblk                 ;

	pchar2	$1b,'e'                 ; Show cursor
	print	.succss                 ; Success !

.exit	gemdos	Cnecin,2
	crlf
	rts

.retrid	cmp.w	#$ffff,d5               ; Only warn if successful
	beq.b	.nret                   ;

	move.l	d0,-(sp)                ; Save return code

	print	.tried                  ; Print "Tried XX times"
	move.w	#4,d0                   ;
	sub.w	d5,d0                   ;
	bsr	tui.phbyte              ;
	print	.times                  ;
	move.l	(sp)+,d0                ;

.nret	rts

.failed	pchar2	$1b,'e'                 ; Show cursor
	print	(a5)                    ; Print error
	bra	.exit                   ; Wait for a key and exit

.prtblk	bsr	tui.phlong              ; Print current block
	pchar	'/'                     ;
	move.l	d3,d0                   ;
	subq	#1,d0                   ; Print last block instead of size
	bsr	tui.phlong              ;
	pchar	$0d                     ; Overwrite next line
	rts

.chkret	tst.b	d0                      ; Quick check for success
	bne.b	.reterr                 ;
	rts	                        ;
.reterr	move.l	d0,-(sp)                ; Store error code
	move.l	d4,d0                   ; Print current block
	bsr	.prtblk                 ;
	crlf	                        ; Print error message
	pchar2	$1b,'e'                 ; Show cursor
	print	.err                    ;
	move.l	(sp)+,d0                ;
	addq	#4,sp                   ; Don't return
	cmp.l	#$00110302,d0           ; Check for standard errors
	beq.b	.prderr                 ;
	cmp.l	#$000c0302,d0           ;
	beq.b	.pwrerr                 ;
	cmp.l	#$00270702,d0           ;
	beq.b	.pwrpro                 ;
	cmp.l	#$003a0202,d0           ;
	beq.b	.pnomed                 ;

	bsr	tui.phlong              ; Print raw error code
	crlf	                        ;
	bra	.exit                   ;

.prderr	lea	.rderr,a5
	bra	.failed
.pwrerr	lea	.wrerr,a5
	bra	.failed
.pwrpro	lea	.wrpro,a5
	bra	.failed
.pnomed	lea	.nomed,a5
	bra	.failed

.corupt

.desc	dc.b	'Disk surface test. Press any key to exit.',$0d,$0a
	dc.b	0

.succss	dc.b	$0d,$0a
	dc.b	'Surface test successful.',$0d,$0a
	dc.b	0

.err	dc.b	'Error:',0

.rcfail	dc.b	'Cannot read disk capacity',$0d,$0a
	dc.b	0

.invsc	dc.b	'Invalid sector count',$0d,$0a
	dc.b	0

.invss	dc.b	'Invalid sector size',$0d,$0a
	dc.b	0

.rderr	dc.b	'Read error',$0d,$0a
	dc.b	0

.wrerr	dc.b	'Write error',$0d,$0a
	dc.b	0

.wrpro	dc.b	'Write protected',$0d,$0a
	dc.b	0

.nomed	dc.b	'No medium inserted',$0d,$0a
	dc.b	0

.tried	dc.b	$0d,$0a
	dc.b	'WARN: Retried ',0

.times	dc.b	' times',$0d,$0a
	dc.b	0

.rccmd	dc.b	8                       ; Read capacity command
	dc.b	$1f                     ; Extended command
	dc.b	$25,$00,$00,$00,$00     ;
	dc.b	$00,$00,$00,$00,$00     ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
