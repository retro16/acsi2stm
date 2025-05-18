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

; Tests the "mode sense" command to fetch drive size

tmodsens:
	print	.desc

	move.w	#$0001,d0               ; Request mode parameter list
	move.l	#buffer,d1              ;
	lea	.cmd,a0                 ;
	bsr	acsicmd.flush           ;

	lea	.failed,a5              ;
	tst.b	d0                      ; Check that the command is successful
	bne	testfailed              ;

	lea	buffer,a0               ; Analyze data

	lea	.invmt,a5               ; Check medium type (0 = block device)
	tst.b	1(a0)                   ;
	bne	testfailed              ;

	tst.b	(a0)                    ;
	beq	testok                  ;

	moveq	#0,d2                   ; d2 = remaining data length
	move.b	(a0),d2                 ;

	addq	#4,a0                   ; Skip header
	subq	#3,d2                   ; Byte count does not include itself

.ckpage	lea	.invlen,a5              ; Check page length
	moveq	#0,d1                   ;
	move.b	1(a0),d1                ;
	addq	#2,d1                   ; Compensate for header size
	cmp.b	d2,d1                   ;
	bhi	testfailed              ;

	move.b	(a0),d0                 ; Check page type
	and.b	#$3f,d0                 ;

	tst.b	d0                      ; Check mode sense 0
	bne.b	.nmode0                 ;

	lea	.invlen,a5              ; Check mode 0 page length
	cmp.b	#$10,d1                 ;
	bne	testfailed              ;

	lea	.invsc,a5               ; Check sector count
        tst.b	5(a0)                   ;
	bne.b	.m0scok                 ;
	tst.w	6(a0)                   ;
	beq	testfailed              ;
.m0scok

	lea	.invss,a5               ; Check sector size
	tst.b	9(a0)                   ;
	bne	testfailed              ;
	cmp.w	#$0200,10(a0)           ;
	bne	testfailed              ;

	bra.b	.next

.nmode0	cmp.b	#$04,d0                 ; Check mode sense 4
	bne.b	.next                   ;

	lea	.invlen,a5              ; Check mode 4 page length
	cmp.b	#$18,d1                 ;
	bne	testfailed              ;

	lea	.invsc,a5               ; Check sector count
        tst.w	2(a0)                   ;
	bne.b	.m4scok                 ;
	tst.b	4(a0)                   ;
	beq	testfailed              ;
.m4scok

	lea	.invhc,a5               ; Check head count
	tst.b	5(a0)                   ;
	beq	testfailed              ;

.next	sub.w	d1,d2                   ; Point at next page
	beq	testok                  ;
	lea	0(a0,d1.w),a0           ;
	bra	.ckpage                 ;


.desc	dc.b	'Test mode sense in normal conditions',$0d,$0a
	dc.b	0

.failed	dc.b	'Command failed',$0d,$0a
	dc.b	0

.invmt	dc.b	'Invalid medium type',$0d,$0a
	dc.b	0

.invlen	dc.b	'Invalid page length',$0d,$0a
	dc.b	0

.invsc	dc.b	'Invalid sector count',$0d,$0a
	dc.b	0

.invss	dc.b	'Invalid sector size',$0d,$0a
	dc.b	0

.invhc	dc.b	'Invalid head count',$0d,$0a
	dc.b	0

.cmd	dc.b	3                       ; Request sense command
	dc.b	$1a,$00,$3f,$00,$ff,$00 ;

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
