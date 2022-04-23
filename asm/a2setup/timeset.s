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

; ACSI2STM setup program
; Real-time clock setup

timeset
	enter

	cls
	print	.menu1(pc)
	savepos
	print	.menu2(pc)

.refrsh	loadpos
	bsr.w	timeset.print

	move.l	hz200.w,d0
	add.l	#40,d0
.wait	cmp.l	hz200.l,d0
	bpl.b	.wait

	gemdos	Cconis,2
	tst.w	d0
	beq.b	.refrsh

	gemdos	Cnecin,2

	cmp.b	#$1b,d0
	exiteq

	cmp.b	#$0d,d0
	bsreq.w	timeset.set

	restart

.menu1	dc.b	'Time settings',13,10
	dc.b	10
	dc.b	'     Time:',0
.menu2	dc.b	13,10
	dc.b	10
	dc.b	'Return: set time',13,10
	dc.b	'Esc: main menu',13,10
	dc.b	0


	even

timeset.print
	lea	bss+buf(pc),a0
	bsr.w	readrtc
	beq.b	.ok

	print	.notime(pc)
	moveq	#1,d0
	rts

.ok	lea	bss+buf+3(pc),a0
	cmp.b	#224,(a0)
	bls.b	.set

	print	.nset(pc)
	moveq	#1,d0
	rts

.set	moveq	#0,d0                   ; Print year
	move.b	(a0)+,d0                ;
	add.w	#2000,d0                ; USatan clock starts at year 2000
	moveq	#4,d1                   ;
	bsr.w	puint                   ;

	moveq	#2,d1                   ; All other numbers are 2 digits

	pchar	'-'                     ;
	bsr.b	.p1                     ; Print month
	pchar	'-'                     ;
	bsr.b	.p1                     ; Print day
	pchar	' '                     ;
	bsr.b	.p0                     ; Print hours
	pchar	':'                     ;
	bsr.b	.p0                     ; Print minutes
	pchar	':'                     ;
	bra.b	.p0                     ; Print seconds

.p1	moveq	#0,d0                   ; Print 1-based 2 digits number
	move.b	(a0)+,d0                ;
	addq.b	#1,d0                   ;
	bra.w	puint                   ;

.p0	moveq	#0,d0                   ; Print 0-based 2 digits number
	move.b	(a0)+,d0                ;
	moveq	#2,d1                   ;
	bra.w	puint                   ;
	
.notime	dc.b	'Cannot read clock  ',0
.nset	dc.b	'Not set/no battery ',0
	even

timeset.set
	cls
	print	.settim(pc)
	movem.l	d3-d4/a3,-(sp)

	lea	-12(sp),sp
	move.l	#'RTC ',-(sp)

	move.l	#2000,d3
	move.l	#2224,d4
	lea	.year(pc),a3
	bsr.b	.ask
	move.b	d0,3(sp)

	moveq	#1,d3

	moveq	#12,d4
	lea	.month(pc),a3
	bsr.b	.ask
	move.b	d0,4(sp)

	moveq	#31,d4
	lea	.day(pc),a3
	bsr.b	.ask
	move.b	d0,5(sp)

	moveq	#0,d3

	moveq	#23,d4
	lea	.hour(pc),a3
	bsr.b	.ask
	move.b	d0,6(sp)

	moveq	#59,d4
	lea	.minute(pc),a3
	bsr.b	.ask
	move.b	d0,7(sp)

	lea	.second(pc),a3
	bsr.b	.ask
	move.b	d0,8(sp)

	; Date is on the stack
	move.w	#$0101,d0               ; Write 1 block
	move.l	sp,d1                   ; Data is on the stack
	lea	.cmd(pc),a0             ;
	bsr.w	acsicmd                 ; Set the clock

	lea	16(sp),sp
	movem.l	(sp)+,d3-d4/a3
	rts

.ask	crlf
.askagn	clrline
	print	(a3)
	lea	bss+buf(pc),a0
	move.l	d4,d0
	bsr.w	readint

	sub.l	d3,d0
	blt.b	.askagn
	rts

.settim	dc.b	'Set time:',13,10,0
.year	dc.b	'Year:',0
.month	dc.b	'Month:',0
.day	dc.b	'Day:',0
.hour	dc.b	'Hour:',0
.minute	dc.b	'Minute:',0
.second	dc.b	'Second:',0
	even
.cmd	dc.b	9
	dc.b	$1f,$20
	dc.b	'USWrClRTC'
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
