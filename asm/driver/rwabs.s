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

rwabs
	move.w	rwabs.dev(sp),d1        ; d1 = current drive

	btst	#1,rwabs.rwflag+1(sp)   ; Pay attention to media change ?
	bne.b	.nomch                  ;

	move.l	mchmask(pc),d0          ; d0 = mchmask
	btst	d1,d0                   ; Check media change flag
	beq.b	.nomch                  ;
	moveq	#E_CHNG,d0              ; Media changed
	rts

.nomch	link	a6,#0                   ; Now we get serious
	movem.l	d3-d7,-(sp)             ; Save registers

	bsr.w	getpart                 ; Get partition from pun
	cmp.b	#$ff,d7                 ; Is the drive mounted
	bne.w	.mountd                 ;

	; Pass the call to the next driver
	movem.l	(sp)+,d3-d7             ; Restore registers
	unlk	a6                      ; Free stack frame
	hkchain rwabs

.mountd	; The drive is mounted
	; Returned from getpart:
	;  d2.l = partition offset
	;  d7.b = ACSI id

	cmp.l	#$ffffffff,d2           ; Test if no medium
	bne.b	.hasmed                 ;

	moveq	#ERR,d0                 ; Return a generic error
	bra.w	.end                    ; XXX try something smarter

	; Compute final offset
.hasmed	moveq	#0,d5                   ;
	move.w	rwabs.recnt+4(a6),d5    ; Load 16 bits rec number
	cmp.w	#$ffff,d5               ; If rec number == $ffff
	bne.b	.srecno                 ;
	move.l	rwabs.lrecno+4(a6),d5   ; Load 32 bits rec number
.srecno	
	btst	#3,rwabs.rwflag+1+4(a6) ; Check physical flag
	bne.b	.phys
	add.l	d2,d5                   ; d5 = physical sector
.phys
	moveq	#0,d3                   ;
	btst	#2,rwabs.rwflag+1+4(a6) ; Check no retry flag
	bne.b	.nretry
	bset	#16,d3                  ; d3.16 = retry flag
.nretry
	move.w	rwabs.cnt+4(a6),d3      ; d3 = sector count
	move.l	rwabs.buff+4(a6),d4     ; d4 = buffer address
	beq.w	.nulptr                 ; Check for null pointer
	btst	#0,d4                   ; Check for unaligned pointer
	bne.b	.unalig                 ;

	moveq	#0,d0                   ; Preload success code
	tst.w	d3                      ; If no more sectors
	beq.b	.end                    ; end

	move.l	#$ff,d6                 ; d6 = transfer size ($ff)

.next	move.w	d6,d0                   ; d0 = min(d6,d3)
	cmp.w	d6,d3                   ;
	bgt.b	.last                   ;
	move.w	d3,d0                   ;
.last
	move.l	d4,d1                   ; d1 = buffer address
	move.l	d5,d2                   ; d2 = sector number

	btst	#0,rwabs.rwflag+1+4(a6) ; Check read or write
	beq.b	.read                   ;
	bsr.w	blk.wr                  ; Call write
	bra.b	.endop                  ;
.read	bsr.w	blk.rd                  ; Call read
.endop
	tst.b	d0                      ; Check for error
	beq.b	.nerr                   ;

	cmp.w	#$3a06,d0               ; Check for "no medium"
	bne.b	.nnomed                 ;
	bsr.w	mount                   ; No medium: remount
	moveq	#EUNDEV,d0              ; Return "unknown device"
	bra.b	.end                    ;

.nnomed	bsr.w	acsierr                 ; Convert ACSI error to TOS

	cmp.w	#E_CHNG,d0              ; Check for media change
	beq.b	.mch                    ;

	btst	#16,d3                  ; d3.16 = retry flag
	beq.b	.end                    ; If retry unset, stop now
	bclr	#16,d3                  ; Clear retry flag
	bra.b	.next                   ; Try again
.nerr
	add.l	#$ff*512,d4             ; Move buffer address
	add.l	d6,d5                   ; Move sector number
	sub.w	d6,d3                   ; Subtract transfer size to sector count
	bge.b	.next                   ;

.end	movem.l	(sp)+,d3-d7             ; Restore registers
	unlk	a6                      ; Free stack frame
	rts

.mch	; Media changed
	move.w	rwabs.dev+4(a6),d1      ; d1 = current drive

	lea	mchmask(pc),a0          ; Set media change flag
	move.l	(a0),d2                 ;
	bset	d1,d2                   ;
	move.l	d2,(a0)                 ;

	bra.b	.end

.unalig
	; TODO: implement unaligned I/O

.nulptr	moveq	#-1,d0
	bra.b	.end

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
