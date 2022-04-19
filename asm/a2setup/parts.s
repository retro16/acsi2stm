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
; Partition and filesystem handling routines

	include	parts.i

parts.ismbr
	; Tries to detect if this is a valid MBR partition table
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	; Output:
	;  d0.l: Device capacity if it is a valid MBR, 0 otherwise

	lea	bss+boot(pc),a0

	; Check MBR signature
	cmp.w	#$55aa,mtbl.sig(a0)
	bne.b	.no

	; Check if at least 1 partition is defined
	moveq	#3,d2                   ; d2 = partition iterator counter
	lea	mtbl.parts(a0),a1       ; a1 = partition entry address
.ckepty	tst.b	mpart.type(a1)          ; Test partition type
	bne.b	.nempty                 ; Jump out if found at least one
.nxepty	lea	mpart...(a1),a1         ; Next partition
	dbra	d2,.ckepty              ;
	bra.w	.no                     ; No partition !
.nempty

	tst.l	d6
	bne.b	.in_ext
	moveq	#3,d2                   ; d2 = partition iterator counter
	bra.b	.it_set                 ;
.in_ext	moveq	#0,d2                   ;
.it_set
	lea	mtbl.parts(a0),a1       ; a1 = partition entry address

	; Check if this partition entry makes sense
.ckpart	moveq	#$7f,d1                 ; mpart.status must be $00 or $80
	and.b	(a1),d1                 ;
	bne.b	.no                     ;

	tst.b	mpart.type(a1)          ; Check for an empty partition
	bne.b	.defind                 ;
	tst.l	mpart.start(a1)         ; Empty partitions have 0 values
	bne.b	.no                     ;
	tst.l	mpart.size(a1)          ;
	bne.b	.no                     ;
	bra.b	.nxpart                 ; Valid empty entry

.defind	move.l	mpart.start(a1),d1      ; Read partition start sector
	beq.b	.no                     ; Cannot start at 0 for a defined part
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ;

	cmp.l	d1,d4                   ; Cannot start outside the device
	ble.b	.no                     ; XXX not sure if ble is correct

.ckpsiz	move.l	mpart.size(a1),d0       ; Read partition size
	beq.b	.no                     ; Cannot be 0 for a defined part
	rol.w	#8,d0                   ;
	swap	d0                      ;
	rol.w	#8,d0                   ;

	add.l	d0,d1                   ; d1 = start+size

	cmp.l	d1,d4                   ; Cannot end outside the device
	blt.b	.no                     ; XXX not sure if blt is correct

.nxpart	lea	mpart...(a1),a1         ; Next partition
	dbra	d2,.ckpart              ;

	; This is a valid MBR. Return the size in d0.
	move.l	d4,d0
	rts

.no	moveq	#0,d0
	rts

parts.istos
	; Tries to detect if this is a valid TOS partition table
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	; Output:
	;  d0.l: Device capacity if it is a valid TOS table, 0 otherwise

	lea	bss+boot(pc),a0

	cmp.l	ttbl.nsects(a0),d4      ; Check disk size
	blt.b	.no                     ; Partition table bigger than the disk !

	moveq	#3,d2                   ; d2 = partition iterator counter
	lea	ttbl.parts(a0),a1       ; a1 = partition entry

.ckpart	lea	(a1),a2                 ; a2 = moving pointer
	btst	#0,(a2)+                ; Check that the partition exists
	beq.b	.nxpart                 ;

	moveq	#2,d0                   ; Check that partition type is made of
.nxtchr	cmp.b	#'A',(a2)               ; 3 upper-case letters
	blt.b	.no                     ;
	cmp.b	#'Z',(a2)+              ;
	bgt.b	.no                     ;
	dbra	d0,.nxtchr              ;

	move.l	(a2)+,d0                ; d0 = partition offset

	cmp.l	d0,d4                   ; Check that it starts inside the disk
	blt.b	.no                     ;

	add.l	(a2)+,d0                ; Check that it ends inside the disk
	cmp.l	d0,d4                   ;
	blt.b	.no                     ;

.nxpart	lea	tpart...(a1),a1         ; Point at next partition entry
	dbra	d2,.ckpart              ;

	; This is a valid TOS partition. Return the size in d0.
	move.l	d4,d0
	rts

.no	moveq	#0,d0
	rts

parts.isfatfs
	; Detects whether this is a valid FAT boot sector
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	; Output:
	;  d0.l: Filesystem size in sectors if it is a valid FAT, 0 otherwise.

	lea	bss+boot(pc),a0

	cmp.b	#$f0,fat.media(a0)      ; Check media type
	blt.w	.no

	tst.b	fat.bps(a0)             ; Check sector size is a multiple of 256
	bne.w	.no                     ;
	move.b	fat.bps+1(a0),d0        ;
	cmp.b	#2,d0                   ; Check sector size is >= 512

	ifgt	maxsecsize-$200         ; If sector size limit is > 512

	blt.w	.no                     ;
	cmp.b	#maxsecsize/$100,d0     ; Check sector size <= maxsecsize
	bgt.b	.no                     ;
	subq.b	#1,d0                   ; Check that sector size is a power of 2
	and.b	fat.bps+1(a0),d0        ;
	bne.b	.no                     ;

	else	                        ; If sector size limit is 512

	bne.b	.no                     ; Only accept $200

	endif

	move.b	fat.spc(a0),d1          ; Check sectors per cluster
	beq.w	.no                     ; It can't be 0
	cmp.b	#64,d1                  ; It can't be more than 64
	bhi.w	.no                     ;
	move.b	d1,d2                   ; It must be a power of 2
	subq.b	#1,d2                   ;
	and.b	d1,d2                   ;
	bne.b	.no                     ;

	moveq	#0,d1                   ; Clear MSB
	move.b	fat.nsects+1(a0),d1     ;
	lsl.w	#8,d1                   ;
	move.b	fat.nsects(a0),d1       ; d1 = fat.nsects

	tst.w	d1
	bne.b	.nsecok                 ; If fat.nsects == 0
	move.l	fat.hsects(a0),d1       ; Use fat.hsects
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ; d1 = fat.hsects
.nsecok
	cmp.l	d1,d4                   ; Check that the filesystem does not
	blt.b	.no                     ; go beyond the size of its container XXX is blt correct ?

	move.l	d1,d0                   ; Return the real size of the filesystem

	; This looks like a proper FAT to me.
	rts

.no	moveq	#0,d0
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
