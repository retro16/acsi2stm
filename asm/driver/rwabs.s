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
		rs.l	1
rwabs.rwflag	rs.w	1
rwabs.buff	rs.l	1
rwabs.cnt	rs.w	1
rwabs.recnt	rs.w	1
rwabs.dev	rs.w	1
rwabs.lrecno	rs.l	1

; Parameters within the stack frame
		rsreset
		rs.l	1
		rs.l	1
rwabs.f.rwflag	rs.w	1
rwabs.f.buff	rs.l	1
rwabs.f.cnt	rs.w	1
rwabs.f.recnt	rs.w	1
rwabs.f.dev	rs.w	1
rwabs.f.lrecno	rs.l	1

	; Stack frame macros
rwabs_framein	macro
	link	a6,#0
	ifgt	maxsecsize-$200
	movem.l	d3-d7/a3-a4,-(sp)
	else
	movem.l	d3-d7/a4,-(sp)
	endif
	endm

rwabs_frameout	macro
	ifgt	maxsecsize-$200
	movem.l	(sp)+,d3-d7/a3-a4
	else
	movem.l	(sp)+,d3-d7/a4
	endif
	unlk	a6
	endm

rwabs
	move.w	rwabs.dev(sp),d1        ; d1 = current drive

	btst	#1,rwabs.rwflag+1(sp)   ; Pay attention to media change ?
	bne.b	.nomch                  ;

	move.l	mchmask(pc),d0          ; d0 = mchmask
	btst	d1,d0                   ; Check media change flag
	beq.b	.nomch                  ;
	moveq	#E_CHNG,d0              ; Media changed
	rts

.nomch	rwabs_framein                   ; Now we get serious

	bsr.w	getpart                 ; Get partition from pun
	cmp.b	#$ff,d7                 ; Is the drive mounted
	bne.w	.mountd                 ;

	; Pass the call to the next driver
	rwabs_frameout
	hkchain rwabs

.mountd	; The drive is mounted
	; Returned from getpart:
	;  d0.b: Sector size shift (0 = 512, 1 = 1024, 2 = 2048, ...)
	;  d2.l = partition offset
	;  d7.b = ACSI id

	cmp.l	#$ffffffff,d2           ; Test if no medium
	bne.b	.hasmed                 ;

	moveq	#ERR,d0                 ; Return a generic error
	bra.w	.end                    ; XXX try something smarter

	; Compute final offset
.hasmed
	move.l	d2,a4                   ; a4 = Partition offset

	ifgt	maxsecsize-$200         ; If big sectors

	move.l	#$ff*512,d1             ; a3 = address increment
	lsl.l	d0,d1                   ;
	move.l	d1,a3                   ;

	move.b	d0,d6                   ;
	swap	d6                      ; d6[16..23] = Sector size shift

	endif

	btst	#2,rwabs.f.rwflag+1(a6) ; Check no retry flag
	seq	d6                      ; d6[0..7] = retry flag
.retry
	moveq	#0,d5                   ;
	move.w	rwabs.f.recnt(a6),d5    ; Load 16 bits rec number
	cmp.w	#$ffff,d5               ; If rec number == $ffff
	bne.b	.srecno                 ;
	move.l	rwabs.f.lrecno(a6),d5   ; Load 32 bits rec number
.srecno
	ifgt	maxsecsize-$200
	swap	d6
	lsl.l	d6,d5                   ; Adjust for sector size
	swap	d6
	endif

	btst	#3,rwabs.f.rwflag+1(a6) ; Check physical flag
	bne.b	.phys
	add.l	a4,d5                   ; d5 = physical sector
.phys
	moveq	#0,d3                   ;
	move.w	rwabs.f.cnt(a6),d3      ; d3 = sector count

	ifgt	maxsecsize-$200         ;
	swap	d6                      ;
	lsl.l	d6,d3                   ; Adjust count for sector size
	swap	d6                      ;
	endif

	move.l	rwabs.f.buff(a6),d4     ; d4 = buffer address
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

	btst	#0,rwabs.f.rwflag+1(a6) ; Check read or write
	beq.b	.read                   ;
	bsr.w	blk.wr                  ; Call write
	bra.b	.endop                  ;
.read	bsr.w	blk.rd                  ; Call read
.endop
	tst.b	d0                      ; Check for error
	beq.b	.nerr                   ;

.onerr	cmp.w	#$3a06,d0               ; Check for "no medium"
	bne.b	.nnomed                 ;
	bsr.w	mount                   ; No medium: remount
	moveq	#EUNDEV,d0              ; Return "unknown device"
	bra.b	.end                    ;

.nnomed	bsr.w	acsierr                 ; Convert ACSI error to TOS

	cmp.w	#E_CHNG,d0              ; Check for media change
	beq.b	.mch                    ;

	tst.b	d6                      ; Check retry flag
	beq.b	.end                    ; If retry unset, stop now
	sf	d6                      ; Clear retry flag
	bra.w	.retry                  ; Try again
.nerr
	ifgt	maxsecsize-$200
	add.l	a3,d4                   ; Move buffer address
	else
	add.l	#$ff*512,d4             ; Move buffer address $ff sectors
	endif

	add.l	#$ff,d5                 ; Move sector number
	sub.l	#$ff,d3                 ; Subtract transfer size to sector count
	bge.b	.next                   ;

.end	rwabs_frameout
	rts

.mch	; Media changed
	move.w	rwabs.f.dev(a6),d1      ; d1 = current drive

	lea	mchmask(pc),a0          ; Set media change flag
	move.l	(a0),d2                 ;
	bset	d1,d2                   ;
	move.l	d2,(a0)                 ;

	bra.b	.end

.unalig	; Specialized unaligned memory operation
	; This is optimized for size

	moveq	#1,d0                   ; d0 = 1 sector operation
	lea	bss+buf(pc),a0          ; Use local temporary buffer
	move.l	a0,d1                   ; d1 = buffer address
	move.l	d5,d2                   ; d2 = sector number

	btst	#0,rwabs.f.rwflag+1(a6) ; Check read or write
	beq.b	.uread                   ;
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

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
