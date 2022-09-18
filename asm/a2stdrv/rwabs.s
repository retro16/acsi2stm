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
; Rwabs handler

; Parameters
		rsreset
rwabs.rwflag	rs.w	1
rwabs.buff	rs.l	1
rwabs.cnt	rs.w	1
rwabs.recnt	rs.w	1
rwabs.dev	rs.w	1
rwabs.lrecno	rs.l	1

	; Stack frame macros
rwabs_in	macro
	ifgt	maxsecsize-$200
	movem.l	d3-d6/a3-a5,-(sp)
	else
	movem.l	d3-d6/a4-a5,-(sp)
	endif
	move.l	a2,a5                   ; a5 = parameters address
	endm

rwabs_out	macro
	ifgt	maxsecsize-$200
	movem.l	(sp)+,d3-d6/a3-a5
	else
	movem.l	(sp)+,d3-d6/a4-a5
	endif
	endm

rwabs_handler
	lea	4(sp),a2                ; Point a2 at parameters
	move.w	rwabs.dev(a2),d1        ; d1 = device number

	btst	#3,rwabs.rwflag+1(a2)   ; Check physical flag
	beq.b	.nphys

	subq.w	#2,d1                   ; Compute ACSI id
	and.w	#$3f,d1                 ; Remove "removable" flag (workaround)
	bmi.b	.nowned                 ; id < 2: floppy call (ignore)
	cmp.w	#7,d1                   ; id > 7: not an ACSI device call
	bgt.b	.nowned                 ;

	move.w	d7,-(sp)                ; Set ACSI id
	move.w	d1,d7                   ;
	moveq	#0,d0                   ; Sector size is always 512 bytes
	moveq	#0,d2                   ; No partition offset
	bra.b	.mok                    ;
.nphys

	btst	#1,rwabs.rwflag+1(a2)   ; Pay attention to media change ?
	bne.b	.nmch                   ;

	lea	mchmask(pc),a0          ; Do a quick flag check
	move.l	(a0),d0                 ;
	btst	d1,d0                   ;
	beq.b	.nmch                   ;

	bclr	d1,d0                   ; Flag was set: clear it
	move.l	(a0),d0                 ;
	
	moveq	#E_CHNG,d0              ; Return media change
	rts

.nmch	move.w	d7,-(sp)

	bsr.w	getpart                 ; Find the partition matching device

	cmp.b	#$ff,d7                 ; Check if we own the partition
	bne.b	.mountd                 ;

	move.w	(sp)+,d7                ; Not our drive: pass the call
.nowned	hkchain	rwabs                   ;

.mountd	btst	#8,d7                   ; Check media present flag
	bne.b	.mok                    ;

	moveq	#EUNDEV,d0              ; No media: return "invalid device"
	move.w	(sp)+,d7                ;
	rts	                        ;

.mok	rwabs_in

	; The drive is mounted
	; Returned from getpart:
	;  d0.b: Sector size shift (0 = 512, 1 = 1024, 2 = 2048, ...)
	;  d2.l = partition offset
	;  d7.b = ACSI id

	; Compute final offset
.hasmed
	move.l	d2,a4                   ; a4 = Partition offset

	ifgt	maxsecsize-$200         ; If big sectors

	move.b	d0,d6                   ;
	swap	d6                      ; d6[16..23] = Sector size shift

	endif

	btst	#2,rwabs.rwflag+1(a5)   ; Check no retry flag
	seq	d6                      ; d6[0..7] = retry flag
.retry
	moveq	#0,d5                   ;
	move.w	rwabs.recnt(a5),d5      ; Load 16 bits rec number
	cmp.w	#$ffff,d5               ; If rec number == $ffff
	bne.b	.srecno                 ;
	move.l	rwabs.lrecno(a5),d5     ; Load 32 bits rec number
.srecno
	ifgt	maxsecsize-$200
	swap	d6
	lsl.l	d6,d5                   ; Adjust for sector size
	swap	d6
	endif

	add.l	a4,d5                   ; d5 = physical sector

	moveq	#0,d3                   ;
	move.w	rwabs.cnt(a5),d3        ; d3 = sector count

	ifgt	maxsecsize-$200         ;
	swap	d6                      ;
	lsl.l	d6,d3                   ; Adjust count for sector size
	swap	d6                      ;
	endif

	move.l	rwabs.buff(a5),d4       ; d4 = buffer address
	beq.w	.nulptr                 ; Check for null pointer

	moveq	#0,d0                   ; Preload success code
	tst.l	d3                      ; If no more sectors
	beq.b	.end                    ; end

	btst	#0,d4                   ; Check for unaligned pointer
	bne.b	.unalig                 ;

.next	move.l	#$ff,d0                 ; d0 = min($ff,d3)
	cmp.l	d0,d3                   ;
	bgt.b	.nlast                  ;
	move.w	d3,d0                   ;
.nlast
	move.l	d4,d1                   ; d1 = buffer address
	move.l	d5,d2                   ; d2 = sector number

	btst	#0,rwabs.rwflag+1(a5)   ; Check read or write
	beq.b	.read                   ;
	bsr.w	blk.wr                  ; Call write
	bra.b	.endop                  ;
.read	bsr.w	blk.rd                  ; Call read
.endop
.onerr	bsr.w	acsierr                 ; Get error code in TOS format

	beq.b	.nerr                   ;

	cmp.w	#E_CHNG,d0              ; Check for media change
	beq.b	.mch                    ;

	tst.b	d6                      ; Check retry flag
	beq.b	.end                    ; If retry unset, stop now
	sf	d6                      ; Clear retry flag
	bra.w	.retry                  ; Try again
.nerr
	add.l	#$ff*512,d4             ; Move buffer address $ff sectors

	add.l	#$ff,d5                 ; Move sector number
	sub.l	#$ff,d3                 ; Subtract transfer size to sector count
	bge.b	.next                   ;

.end	rwabs_out
	move.w	(sp)+,d7
	rts

.mch	move.w	rwabs.dev(a5),d1        ; d1 = current drive
	bsr.w	setmch                  ; Set media change flag
	bra.b	.end

.unalig	; Specialized unaligned memory operation
	; This is optimized for size

	moveq	#1,d0                   ; d0 = 1 sector operation
	lea	bss+buf(pc),a0          ; Use local temporary buffer
	move.l	a0,d1                   ; d1 = buffer address
	move.l	d5,d2                   ; d2 = sector number

	btst	#0,rwabs.rwflag+1(a5)   ; Check read or write
	beq.b	.uread                  ;
	bsr.w	blk.wr                  ; Call write
	bra.b	.uendop                 ;
.uread	bsr.w	blk.rd                  ; Call read
.uendop
	tst.b	d0                      ; Check for error
	bne.w	.onerr                  ;

	move.w	#($200/4)-1,d0          ; Copy the buffer to the target address
	lea	bss+buf(pc),a0          ;
	move.l	d4,a1                   ;
.ubcopy	move.b	(a0)+,(a1)+             ; Copy 4 bytes at a time to minimize
	move.b	(a0)+,(a1)+             ; performance loss
	move.b	(a0)+,(a1)+             ;
	move.b	(a0)+,(a1)+             ;
	dbra	d0,.ubcopy              ;

	move.l	a1,d4                   ; Move buffer address
	addq.l	#1,d5                   ; Move sector number
	subq.l	#1,d3                   ; Update sector count
	bne.b	.unalig

	bra.b	.end

.nulptr	moveq	#ERR,d0
	bra.b	.end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
