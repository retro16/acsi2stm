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

; Text user interface routines

areyousure
	; Ask "Are you sure", then wait for either Y or N to be pressed
	; Output:
	;  d0.l: 0 if answered Y, 1 if answered N
	;  Z: set if answered Y, clear otherwise
	asksil	.msg(pc)
	bsr.w	curson

	and.b	#$df,d0
	cmp.b	#'Y',d0
	beq.b	.yes
	cmp.b	#'N',d0
	beq.b	.no
	bra.b	areyousure
.yes	pchar	'Y'
	bsr.b	crlf
	bsr.w	cursoff
	moveq	#0,d0
	rts
.no	pchar	'N'
	bsr.b	crlf
	bsr.w	cursoff
	moveq	#1,d0
	rts

.msg	dc.b	'Are you sure ? (Y/N) ',$1b,'e',0
.crlf	dc.b	13,10,0
	even

crlf	; Print a carriage return
	; Preserves all registers except CCR
	movem.l	d0-d2/a0-a2,-(sp)
	print	.crlf(pc)
	movem.l	(sp)+,d0-d2/a0-a2
	rts

.crlf	dc.b	13,10,0
	even

presskey
	; Displays "Press a key to continue" then waits for a key
	asksil	.msg(pc)
	rts

.msg	dc.b	'Press a key to continue',13,10,0
	even

success	; Displays "Successful" or "Failed"
	; Of course, "Failed" rings the bell
	; Input:
	;  d0.b: 0 to display successful, otherwise display failed
	tst.b	d0
	beq.b	.prtok
	print	tui.ko(pc)
	rts
.prtok	print	tui.ok(pc)
	rts

succsky	; Displays "Successful" or "Failed" then wait for a key
	; Of course, "Failed" rings the bell
	; Input:
	;  d0.b: 0 to display successful, otherwise display failed
	tst.b	d0
	beq.b	.prtok
	print	tui.ko(pc)
	bra.b	presskey
.prtok	print	tui.ok(pc)
	bra.b	presskey

tui.ok	dc.b	'Successful',13,10,0
tui.ko	dc.b	7,'Failed',13,10,0
	even

phex_in	macro
	movem.l	d0-d5/a0-a2,-(sp)
	endm

phex_out	macro
	movem.l	(sp)+,d0-d5/a0-a2
	endm

phbyte	; Print an hexadecimal byte
	; Input:
	;  d0.b: Number to print
	; Output:
	;  Preserves all registers except CCR

	phex_in

	move.b	d0,d3
	ror.l	#8,d3
	moveq	#1,d4
	bra.b	phex

phshort	; Print a short hexadecimal number
	; Input:
	;  d0.w: Number to print
	; Output:
	;  Preserves all registers except CCR

	phex_in

	move.w	d0,d3
	swap	d3
	moveq	#3,d4
	bra.b	phex

phlong	; Print a long hexadecimal number
	; Input:
	;  d0.l: Number to print
	; Output:
	;  Preserves all registers except CCR

	phex_in

	move.l	d0,d3
	moveq	#7,d4

phex	; Subroutine for phbyte, phshort and phlong
	; Do not call directly
	; Input:
	;  d3: value to print in the MSB
	;  d4.w: number of digits

.loop	rol.l	#4,d3
	move.w	d3,d0
	and.w	#$f,d0
	
	cmp.w	#$a,d0
	blt.b	.digit

	add.w	#'A'-$a,d0
	bra.b	.prtd1

.digit	add.w	#'0',d0

.prtd1	move.w	d0,-(sp)
	gemdos	Cconout,4

	dbra	d4,phex

	phex_out
	rts


puint_in	macro
	movem.l	d0-d4/a0-a2,-(sp)
	endm

puint_out	macro
	movem.l	(sp)+,d0-d4/a0-a2
	endm

puint	; Print a long unsigned number as decimal
	; Input:
	;  d0.l: Number to display
	;  d1.w: Minimum digit count
	;  d1[16]: Set to fill with spaces
	
	puint_in

	move.l	d1,d4

.notnul	; Compute digits and push them on the stack
	clr.w	-(sp)

.nxtdig	bsr.b	divby10
	move.l	d1,d0
	or.l	d2,d1
	beq.b	.zfill
	add.w	#'0',d2
	move.w	d2,-(sp)
	subq.w	#1,d4

	bra.b	.nxtdig

.zfill	; Leading zeroes/spaces
	moveq	#'0',d2
	btst	#16,d4
	beq.b	.fill
	moveq	#' ',d2
.fill	subq.w	#1,d4
	bmi.b	.print
	move.w	d2,-(sp)
	bra.b	.zfill

.print	; Print digits on the stack (in reverse order)
	gemdos	Cconout,2
	tst.w	(sp)+
	bne.b	.print

.end	puint_out
	rts

random	; Compute a random 32 bits value
	xbios	Random,2
	swap	d0
	move.l	hz200.w,d1
	eor.l	d1,d0
	rts

log2	; Compute log2 of a value
	; Input:
	;  d0.l: Input value
	; Output:
	;  d1.l: log2
	;  All other registeres unaltered except CCR

	moveq	#31,d1
.loop	btst	d1,d0
	dbne	d1,.loop
	rts

tsr	; Top shift right
	; Right shifts a value by a number of bits with rounding to the topmost
	; value.
	; Input:
	;  d0.l: value to shift
	;  d1: shift bit count (modulo 64)
	; Output:
	;  d0.l: shifted value

	moveq	#0,d2
	bset	d1,d2
	subq.l	#1,d2
	add.l	d2,d0
	lsr.l	d1,d0
	rts

divby10	; Divide by 10
	; Input:
	;  d0.l: Numerator
	; Output:
	;  d1.l: Quotient
	;  d2.w: Remainder
	; Alters:
	;  d3.w

	moveq	#31,d3
	moveq	#0,d2
	moveq	#0,d1

.loop	lsl.w	d2                      ; R := R << 1

	btst	d3,d0                   ; R(0) := N(i)
	beq.b	.rz                     ;
	bset	#0,d2                   ;
.rz
	cmp.w	#10,d2                  ; If R >= 10
	blt.b	.nr                     ;
	sub.w	#10,d2                  ; R := R - 10
	bset	d3,d1                   ; Q(i) := 1
.nr
	dbra	d3,.loop
	rts

atoi	; Convert a decimal string to an integer
	; Input:
	;  a0: String to convert
	; Output:
	;  d0.l: 0 if success, 1 if failed
	;  Z: set if success, clear otherwise
	;  d1.l: Number output

	moveq	#0,d1

.loop	tst.b	(a0)                    ; Check for end of string
	beq.b	.end                    ;

	lsl.l	#2,d1                   ; N *= 10
	move.l	d1,d2                   ;
	lsl.l	#6,d1                   ;
	add.l	d2,d1                   ;

	moveq	#0,d2                   ; d2 = ASCII digit
	move.b	(a0)+,d2                ;

	sub.b	#'0',d2                 ; Convert ASCII to digit
	bmi.b	.err                    ; If negative, not a digit

	cmp.b	#10,d2                  ; Check that it was a digit
	bpl.b	.err                    ;

	add.l	d2,d1                   ; Add the digit to the number

	bra.b	.loop                   ; Next digit

.end	moveq	#0,d0                   ; Return success
	rts                             ;

.err	moveq	#1,d0                   ; Return failure
	rts                             ;

curson	; Show cursor
	movem.l	d0-d2/a0-a2,-(sp)
	print	.curson(pc)
	movem.l	(sp)+,d0-d2/a0-a2
	rts
.curson	dc.b	$1b,'e',0
	even

cursoff	; Hide cursor
	movem.l	d0-d2/a0-a2,-(sp)
	print	.cursof(pc)
	movem.l	(sp)+,d0-d2/a0-a2
	rts
.cursof	dc.b	$1b,'f',0
	even

kbflush	; Flush keyboard buffer
	movem.l	d0-d2/a0-a2,-(sp)

.more	gemdos	Cconis,2
	tst.w	d0
	beq.b	.ok
	gemdos	Cnecin,2
	bra.b	.more

.ok	movem.l	(sp)+,d0-d2/a0-a2
	rts

readint	; Read an unsigned number from the console
	; Input:
	;  d0.l: Maximum value
	;  a0: pointer to a sufficiently large buffer
	; Output:
	;  d0.l: Number read

	movem.l	d3-d5,-(sp)

	curson
	kbflush

	moveq	#0,d4                   ; d4 = output digit
	move.l	d0,d5                   ; d5 = Maximum value

.rddigi	gemdos	Cnecin,2

	cmp.b	#$1b,d0                 ; Esc: return 0 immediately
	beq.b	.zero                   ;

	cmp.b	#$08,d0                 ; Backspace
	beq.b	.bs                     ;

	cmp.b	#$7f,d0                 ; Also backspace (VT100)
	beq.b	.bs                     ;

	cmp.b	#$0d,d0                 ; Return
	beq.b	.done                   ;

	sub.b	#'0',d0
	cmp.b	#9,d0
	bhi.b	.rddigi

	cmp.l	#$19999999,d4           ; Check if we are out of digits
	bhi.b	.rddigi                 ;

	move.l	d4,d2                   ; d2 = last successful value

	lsl.l	#1,d4                   ; Multiply d4 by 10
	move.l	d4,d1                   ;
	lsl.l	#2,d4                   ;
	add.l	d1,d4                   ;

	moveq	#0,d1                   ; Add the digit to d4
	move.b	d0,d1                   ;
	add.l	d1,d4                   ;

	beq.b	.rddigi                 ; Don't display leading 0

	bcc.b	.nof                    ; In case of overflow, revert
.of	move.l	d2,d4                   ; and go back to digit read
	bra.b	.rddigi                 ;
.nof
	cmp.l	d5,d4                   ; Check maximum value
	bhi.b	.of                     ;

	add.w	#'0',d0                 ; Display the digit
	move.w	d0,-(sp)                ;
	gemdos	Cconout,4               ;

	bra.b	.rddigi

.done	tst.l	d4
	bne.b	.move
	pchar	'0'
.move	move.l	d4,d0
.ret	cursoff
	movem.l	(sp)+,d3-d5
	rts

.zero	moveq	#0,d4
	bra.b	.done

.bs	tst.l	d4                      ; If 0,
	beq.w	.rddigi                 ; nothing to do

	backspc

	move.l	d4,d0
	bsr.w	divby10
	move.l	d1,d4
	bra.w	.rddigi

.erase	dc.b	8,' ',8,0

; Terminal handling

tui.crlf
	movem.l	d0-d2/a0-a2,-(sp)       ; Save registers
	move.w	28(sp),d0
.loop	crlf
	dbra	d0,.loop
	bra.b	tui..termexit

tui.termctrl
	; Terminal control function
	; Used by terminal control macros
	; Input:
	;  4(sp).w: Function to call
	; Preserves all registers except CCR
	
	movem.l	d0-d2/a0-a2,-(sp)       ; Save registers

	move.l	tui.curterm(pc),a0      ; Load terminal control codes table
	move.w	28(sp),d0
	move.w	(a0,d0),d0
	pea	(a0,d0)
	gemdos	Cconws,6
tui..termexit
	movem.l	(sp)+,d0-d2/a0-a2

	move.l	(sp),2(sp)
	addq	#2,sp
	rts

tui.curterm	; Current terminal control codes base address
	dc.l	0

tui.vt52
	dc.w	vt52.termini-tui.vt52
	dc.w	vt52.cls-tui.vt52
	dc.w	vt52.savepos-tui.vt52
	dc.w	vt52.loadpos-tui.vt52
	dc.w	vt52.curson-tui.vt52
	dc.w	vt52.cursoff-tui.vt52
	dc.w	vt52.clrtail-tui.vt52
	dc.w	vt52.clrbot-tui.vt52
	dc.w	vt52.crlf-tui.vt52
	dc.w	vt52.hlon-tui.vt52
	dc.w	vt52.hloff-tui.vt52
	dc.w	vt52.backspc-tui.vt52
	dc.w	vt52.clrline-tui.vt52

vt52.termini
	dc.b	$1b,'f'                 ; Hide cursor
	dc.b	$1b,'E'                 ; Clear screen
	dc.b	$1b,'q'                 ; Disable highlight
	dc.b	$1b,'j'                 ; Save cursor position
	dc.b	0
vt52.cls
	dc.b	$1b,'E',0
vt52.savepos
	dc.b	$1b,'j',0
vt52.loadpos
	dc.b	$1b,'k',$1b,'j',0       ; Load then save again cursor position
vt52.curson
	dc.b	$1b,'e',0
vt52.cursoff
	dc.b	$1b,'f',0
vt52.clrtail
	dc.b	$1b,'K',0
vt52.clrbot
	dc.b	$1b,'J',0
vt52.crlf
	dc.b	$0d,$0a,0
vt52.hlon
	dc.b	$1b,'p',0
vt52.hloff
	dc.b	$1b,'q',0
vt52.backspc
	dc.b	$8,' ',$8,0
vt52.clrline
	dc.b	$0d,$1b,'K',0

	even

tui.vt100
	dc.w	vt100.termini-tui.vt100
	dc.w	vt100.cls-tui.vt100
	dc.w	vt100.savepos-tui.vt100
	dc.w	vt100.loadpos-tui.vt100
	dc.w	vt100.curson-tui.vt100
	dc.w	vt100.cursoff-tui.vt100
	dc.w	vt100.clrtail-tui.vt100
	dc.w	vt100.clrbot-tui.vt100
	dc.w	vt100.crlf-tui.vt100
	dc.w	vt100.hlon-tui.vt100
	dc.w	vt100.hloff-tui.vt100
	dc.w	vt100.backspc-tui.vt100
	dc.w	vt100.clrline-tui.vt100

vt100.termini
	dc.b	$1b,'[2J',$1b,'[H'      ; Clear screen
	dc.b	$1b,'[?25l'             ; Cursor off
	dc.b	$1b,'[m'                ; Highlight off
	dc.b	0
vt100.cls
	dc.b	$1b,'[2J',$1b,'[H',0
vt100.savepos
	dc.b	$1b,'7',0
vt100.loadpos
	dc.b	$1b,'8',$1b,'7',0       ; Load then save again cursor position
vt100.curson
	dc.b	$1b,'[?25h',0
vt100.cursoff
	dc.b	$1b,'[?25l',0
vt100.clrtail
	dc.b	$1b,'[K',0
vt100.clrbot
	dc.b	$1b,'[J',0
vt100.crlf
	dc.b	$0d,$0a,0
vt100.hlon
	dc.b	$1b,'[7m',0
vt100.hloff
	dc.b	$1b,'[m',0
vt100.backspc
	dc.b	$8,' ',$8,0
vt100.clrline
	dc.b	$0d,$1b,'[K',0

	even

; Menu handling subroutines

menu.wait
	; Wait for a menu event
	; In case of device event, restart
	; In case of device error, exit
	; In case of key pressed, rts

	bsr.w	blkdev.waitkey

	cmp.w	#blkerr.mchange,d1      ; Restart if medium was changed
	rsteq	                        ;

	cmp.w	#blkerr.nomedium,d1     ; Restart if no medium
	rsteq	                        ;

	tst.w	d1                      ; If error: exit to devsel
	exitne	                        ;

	tst.w	d0                      ; If no key pressed, wait again
	beq.b	menu.wait

	rts

menu.chkdev
	; Check that the device is working
	; Exit on error/timeout
	; rts if success, no medium or medium changed

	bsr.w	blkdev.tst

	cmp.w	#blkerr.mchange,d0      ; rts if medium was changed
	rtseq	                        ;

	cmp.w	#blkerr.nomedium,d0     ; rts if no medium
	rtseq	                        ;

	tst.w	d0                      ; exit if error
	exitne	                        ;

	rts

menu.waitmed
	; Wait for a menu event, exit if no medium
	; Exit on error/timeout
	; Exit if no medium or medium changed
	; In case of key pressed, rts

	bsr.w	blkdev.waitkey

	cmp.w	#blkerr.mchange,d1      ; Restart if medium was changed
	exiteq	                        ;

	cmp.w	#blkerr.nomedium,d1     ; Restart if no medium
	exiteq	                        ;

	tst.w	d1                      ; If error: exit to devsel
	exitne	                        ;

	tst.w	d0                      ; If no key pressed, wait again
	beq.b	menu.waitmed

	rts

menu.chkmed
	; Check that the medium is ready
	; Exit on error/timeout
	; Exit if no medium
	; rts if success or medium changed

	bsr.w	blkdev.tst

	cmp.w	#blkerr.mchange,d0      ; rts if medium was changed
	rtseq	                        ;

	cmp.w	#blkerr.nomedium,d0     ; exit if no medium
	exiteq	                        ;

	tst.w	d0                      ; exit if error
	exitne	                        ;

	rts
; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
