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

; RTC clock reading functions

synctime
	; Set the system clock from an UltraSatan compatible RTC clock
	; Input:
	;  a0: A temporary buffer to store the date (16 bytes)
	;  d7.b: ACSI id
	; Output:
	;  d0.l: 0 iif successful
	;  Z: clear if successful, set otherwise

	bsr.b	readrtc
	bne.b	.nset
	cmp.b	#224,3(a0)
	bhi.b	.nset
	bra.b	settime

.nset	moveq	#1,d0                   ; Date is probably not set on the device
	rts

readrtc	; Read time from an UltraSatan compatible RTC clock
	; Input:
	;  a0: output buffer
	;  d7.b: ACSI id
	; Output:
	;  a0: left intact
	;  d0.l: 0 iif successful
	;  Z: clear if successful, set otherwise
	;  Date in the output buffer in UltraSatan format

	move.l	a0,-(sp)

	moveq	#1,d0
	move.l	a0,d1
	lea	.cmd(pc),a0
	bsr	acsicmd

	move.l	(sp)+,a0

	tst.b	d0
	bne.b	.fail

	cmp.w	#'RT',(a0)
	bne.b	.fail

	cmp.b	#'C',2(a0)
	bne.b	.fail

	moveq	#0,d0
	rts

.fail	moveq	#1,d0
	rts

.cmd	dc.b	9
	dc.b	$1f,$20
	dc.b	'USRdClRTC'

	even


settime	; Set systime time from an UltraSatan data buffer
	; Input:
	;  a0: Buffer containing an UltraSatan-formatted date
	; Output:
	;  d0.l: 0 iif successful
	;  Z: clear if successful, set otherwise

	moveq	#0,d0

	move.b	3(a0),d0                ; Year
	add.b	#20,d0                  ; UStn starts at 2000, ST starts at 1980

	lsl.w	#4,d0                   ; Month
	addq.b	#1,4(a0)                ;
	or.b	4(a0),d0                ;

	lsl.w	#5,d0                   ; Day
	addq.b	#1,4(a0)                ;
	or.b	5(a0),d0                ;

	move.w	d0,-(sp)                ; Set date
	gemdos	Tsetdate,4              ;
	tst.w	d0                      ;
	bne.b	.fail                   ;

	moveq	#0,d0

	move.b	6(a0),d0                ; Hours

	lsl.w	#6,d0                   ; Minutes
	or.b	7(a0),d0                ;

	lsl.l	#6,d0                   ; Seconds
	or.b	8(a0),d0                ;
	lsr.l	#1,d0                   ; Uses seconds/2 (DOS style)

	move.w	d0,-(sp)                ; Set time
	gemdos	Tsettime,4              ;
	tst.w	d0                      ;
	bne.b	.fail                   ;

	moveq	#0,d0
	rts
.fail	moveq	#1,d0
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
