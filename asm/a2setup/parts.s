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

parts.loadbs
	; Load boot sector if necessary
	; Input:
	;  a3: Descriptor address
	;  d7.b: ACSI id
	; Output:
	;  (a3): Data read

	flagtst	bs                      ; Check if already set
	rtsne

	moveq	#1,d0                   ; Read boot sector
	lea	part.bootsect(a3),a0    ;
	move.l	a0,d1                   ;
	move.l	part.start(a3),d2       ;
.read	bsr.w	blkdev.rd               ;

	cmp.w	#blkerr.mchange,d0      ; Try again if media changed
	tst.w	d0                      ; Check for read error
	exitne	                        ; Exit if it failed

	flagset	bs

	rts

	; Combined reset functions
	; Resets fields associated to each parts.sense* function
	; Input:
	;  a0: pointer to part structure to reset
parts.resetdrv
	move.l	#'   '<<8,part.type(a0)
	flagclr	ok,(a0)
	clr.l	part.start(a0)
	clr.l	part.size(a0)
parts.resetsz
	move.l	part.start(a0),d0
	move.l	d0,part.first(a0)
	move.l	d0,part.last(a0)
	clr.l	part.csize(a0)
parts.resetbs
	flagclr	bs,(a0)
	move.l	a0,-(sp)
	clrblk	part.bootsect(a0),512
	move.l	(sp)+,a0
parts.resetfmt
	move.l	#'   '<<8,(a0)
	clr.l	part.id(a0)
parts.resetfat
	flagclr	fs,(a0)
parts.resetbpb
	move.l	a0,-(sp)
	clrblk	part.bpb(a0),bpb...+6
	move.l	(sp)+,a0
parts.resetmbr
	flagclr	b,(a0)
	flagclr	pt,(a0)
	clr.b	part.extpart(a0)
parts.resetboot
	flagclr	boot,(a0)
	rts

parts.sensedrv
	; Sense a drive and fill its partition descriptor in (a3)
	; Input:
	;  a3: Descriptor address
	;  d7.b: ACSI id
	; Output:
	;  (a3): Data read

	move.l	a3,a0
	bsr.w	parts.resetdrv

	bsr.w	blkdev.cap              ; Read device size in sectors
	tst.l	d0                      ;
	rtseq                           ;

	move.l	d0,part.size(a3)        ; Set size

	flagset	ok                      ; Start and size are valid

	; Fall through sensesz

parts.sensesz
	; Update first, last and csize
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Data read

	flagtst	ok
	rtseq

	move.l	a3,a0
	bsr.w	parts.resetsz

	move.l	part.start(a3),d0       ; Compute first, last and csize
	move.l	d0,part.first(a3)       ; to neutral values
	move.l	part.size(a3),d1        ;
	move.l	d1,part.csize(a3)       ;
	add.l	d1,d0                   ;
	subq.l	#1,d0                   ;
	move.l	d0,part.last(a3)        ;

	; Fall through

parts.sensebs
	; Sense boot sector of the current partition
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Updated format, flags.boot, bootsect, bpb

	move.l	a3,a0
	bsr.w	parts.resetbs

	; Fall through sensefmt

parts.sensefmt
	; Sense partition format, based on its boot sector
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Updated format, flags.fs, flags.pt, flags.boot

	move.l	a3,a0
	bsr.w	parts.resetfmt

	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	bsr.w	parts.sensefat
	bsr.w	parts.sensembr

	; Fall through senseboot

parts.senseboot
	; Sense if a partition is bootable by the Atari
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Updated flags.boot

	move.l	a3,a0
	bsr.w	parts.resetboot

	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	lea	part.bootsect(a3),a0    ; Compute checksum
	bsr.w	parts.cksum             ;

	cmp.w	#$1234,d0               ; Is it the correct checksum ?
	rtsne

	flagset	boot                    ; Bootable !
	rts

parts.sensembr
	; Tries to detect if this is a valid MBR partition table
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Updated format (only if unset), flags.pt

	move.l	a3,a0
	bsr.w	parts.resetmbr

	flagtst	fs                      ; If it has a filesystem
	rtsne	                        ; it's not a MBR

	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	lea	part.bootsect(a3),a0

	move.l	d3,-(sp)                ; d3 = partition table size
	moveq	#0,d3                   ;

	; Check MBR signature
	cmp.w	#$55aa,mtbl.sig(a0)
	bne.w	.no

	moveq	#3,d2                   ; d2 = partition iterator counter
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
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ;

	cmp.l	part.size(a3),d1        ; Cannot start outside the device
	bhi.b	.no                     ;

.ckpsiz	move.l	mpart.size(a1),d0       ; Read partition size
	beq.b	.no                     ; Cannot be 0 for a defined part
	bsr.w	parts.byteswap

	add.l	d0,d1                   ; d1 = start+size

	cmp.l	part.size(a3),d1        ; Cannot end outside the device
	bhi.b	.no                     ;

	cmp.l	d1,d3                   ; Keep track of the end of the last
	bhi.b	.nxpart                 ; partition
	move.l	d1,d3                   ;

.nxpart	lea	mpart...(a1),a1         ; Next partition
	dbra	d2,.ckpart              ;

	; This is a valid MBR.

	move.l	d3,part.csize(a3)       ; Update partition table size

	tst.l	part.first(a3)          ; If first sector is 0
	bne.b	.ext                    ;
	move.l	#'MBR'<<8,(a3)          ; it's a MBR partition table
	bra.b	.fmtok

.ext 	move.l	#'EXT'<<8,(a3)          ; else it's an extended partition

.fmtok	flagset	pt ; This disk contains a table
.no	move.l	(sp)+,d3
	rts

parts.sensefat
	; Detects whether this is a valid FAT boot sector
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Updated format, flags.fs, bpb

	move.l	a3,a0
	bsr.w	parts.resetfat

	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	lea	part.bootsect(a3),a0    ; a0 = boot sector data

	cmp.b	#$ef,fat.media(a0)      ; Check media type
	bls.w	.no

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
	cmp.l	part.size(a3),d1        ; Check that the filesystem does not
	bhi.b	.no                     ; go beyond the size of its container

	; This looks like a proper FAT to me.
	flagset	fs

	move.l	d1,part.csize(a3)       ; Save filesystem size

	bsr.w	parts.parsebpb

	btst	#0,part.bpb+bpb.bflags+1(a3)
	bne.b	.fat16
	move.l	#'F12'<<8,(a3)
	rts

.fat16	move.l	#'F16'<<8,(a3)
.no	rts

parts.parsembr
	; Parse a MBR partition table
	; Input:
	;  a3: MBR descriptor address
	;  a4: Target partition table
	; Output:
	;  (a4): Fully populated partition table

	; Check that a partition table is present
	flagtst	pt
	rtseq
	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	movem.l	d3/a3-a5,-(sp)

	exg	a3,a4                   ; Keep main descriptor in a4
	moveq	#1,d3                   ; d3 = Current partition

	lea	part.bootsect+mtbl.parts(a4),a5 ; a5 = current MBR partition
	move.l	part.bootsect+mtbl.id(a4),part.id(a4) ; Read disk id

.ppart	move.l	a3,a0                   ; Reset partition entry
	bsr.w	parts.resetdrv          ;

	tst.b	mpart.type(a5)          ; Skip empty partitions
	beq.b	.nxtprt                 ;

	move.l	mpart.start(a5),d0      ; Read partition first sector
	bsr.w	parts.byteswap          ;
	move.l	d0,part.start(a3)       ;

	move.l	mpart.size(a5),d0       ; Read partition size
	bsr.w	parts.byteswap          ;
	move.l	d0,part.size(a3)        ;

	flagset	ok                      ; Sector and size are valid

	btst	#7,(a5)                 ; Set boot flag
	beq.b	.nboot                  ;
	flagset	b                       ;
.nboot
	bsr.w	parts.sensesz           ; Sense partition content 

	move.b	mpart.type(a5),d0       ; Read partition type

	cmp.b	#$05,d0                 ; Set extended partition index
	beq.b	.ext                    ;
	cmp.b	#$0f,d0                 ;
	bne.b	.next                   ;
.ext	move.b	d3,part.extpart(a4)     ;
	addq.b	#1,part.extpart(a4)     ;
.next
	lea	part.type(a3),a0        ; Convert type to printable format
	bsr.w	parts.b2t               ;

.nxtprt	lea	mpart...(a5),a5         ; Next partition
	lea	part...(a3),a3          ;
	addq.w	#1,d3                   ;
	cmp.w	#5,d3                   ;
	bne.b	.ppart                  ;

	movem.l	(sp)+,d3/a3-a5
	rts

parts.parsebpb
	; Parse the BPB from a FAT filesystem
	; Input:
	;  a3: Descriptor address
	; Output:
	;  (a3): Updated format, bpb

	; Check that a filesystem is present
	flagtst	fs
	rtseq
	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	lea	part.bootsect(a3),a0    ; a0 = boot sector
	lea	part.bpb(a3),a1         ; a1 = bpb

	ifgt	maxsecsize-$200
	move.b	fat.bps+1(a0),d1        ; d1.b = logical sector size / 256
	move.b	d1,(a1)+                ; bpb.recsiz
	clr.b	(a1)+                   ;
	else
	move.w	#$200,(a1)+             ; bpb.recsiz = 512
	endif

	clr.b	(a1)+                   ;
	moveq	#0,d0                   ;
	move.b	fat.spc(a0),d0          ;
	move.b	d0,(a1)+                ; bpb.clsiz = fat.spc

	ifgt	maxsecsize-$200         ;
	mulu.w	-4(a1),d0               ;
	move.w	d0,(a1)+                ; bpb.clsizb = bpb.clsiz * bpb.recsiz
	else                            ;
	lsl.w	#1,d0                   ; bpb.clsizb = bpb.clsiz * 512
	move.b	d0,(a1)+                ;
	clr.b	(a1)+                   ;
	endif                           ;

	moveq	#0,d0                   ; Clear d0 MSB

	move.b	fat.ndirs+1(a0),d0      ; d0 = bpb.rdlen = (fat.ndirs + 15) / 16
	lsl.w	#8,d0                   ;                  / (fat.bps / 512)
	move.b	fat.ndirs(a0),d0        ;
	add.w	#$f,d0                  ;
	lsr.w	#4,d0                   ;
	ifgt	maxsecsize-$200         ;
	lsr.b	#1,d1                   ;
.rdldiv	lsr.b	#1,d1                   ; rdlen is in logical sectors
	beq.b	.rdlok                  ;
	lsr.w	#1,d0                   ;
	bra.b	.rdldiv                 ;
.rdlok                                  ;
	endif                           ;
	move.w	d0,(a1)+                ; 

	move.w	fat.spf(a0),d1          ;
	rol.w	#8,d1                   ;
	move.w	d1,(a1)+                ; d1 = bpb.fsiz = fat.spf

	move.w	fat.res(a0),d2          ; d2 = fat.res
	rol.w	#8,d2                   ;
	beq.b	.onefat                 ;
.nres	cmp.b	#2,fat.nfats(a0)        ; Are there 2 FATs ?
	blt.b	.onefat                 ;
	add.w	d1,d2                   ; d2 = fat.res + fat.spf
.onefat move.w	d2,(a1)+                ; bpb.fatrec

	add.w	d2,d0                   ; bpb.datrec =
	add.w	d1,d0                   ;  bpb.fatrec + bpb.fsiz + bpb.rdlen
	move.w	d0,(a1)+                ; d0 = bpb.datrec

	moveq	#0,d1                   ; Clear MSB
	move.b	fat.nsects+1(a0),d1     ;
	lsl.w	#8,d1                   ;
	move.b	fat.nsects(a0),d1       ; d1 = fat.nsects

	tst	d1                      ; 
	bne.b	.nsecok                 ; If fat.nsects == 0
	move.l	fat.hsects(a0),d1       ; Use fat.hsects
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ; d1 = fat.hsects
.nsecok
	sub.l	d0,d1                   ; bpb.numcl =
	move.b	fat.spc(a0),d0          ;  (fat.nsects - bpb.datrec) / fat.spc
.clsdiv	lsr.b	#1,d0                   ;
	beq.b	.numcl                  ;
	lsr.l	#1,d1                   ;
	bra.b	.clsdiv                 ;
.numcl
	move.w	d1,(a1)+                ; bpb.numcl

	cmp.l	#'ICDI',2(a0)           ; ICD always formats as FAT16, breaking
	bne.b	.nicd                   ; FAT12 autodetection.
	cmp.w	#'NC',6(a0)             ;
	beq.b	.fat16                  ;

.nicd	cmp.w	#4086,d1                ; A FAT with more than 4086 clusters
	bls.b	.fat12                  ; is FAT16.
.fat16	move.w	#1,(a1)+                ;
	bra.b	.bpbok                  ;
.fat12	clr.w	(a1)+                   ; bpb.bflags
.bpbok
	rts

parts.updparts
	; Update MBR primary partitions based on partitions in the RAM partition
	; table
	; Input:
	;  a3: Descriptor address
	;  a4: Partition table
	; Output:
	;  part.bootsect(a3): Updated MBR

	flagtst	pt                      ; Check that we have a MBR table
	rtseq                           ;

	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	moveq	#3,d2                   ; d2 = iterator
	lea	(a4),a1                 ; a1 = Current partition
	lea	part.bootsect+mtbl.id(a3),a2 ; = MBR partition entry

	move.l	part.id(a3),(a2)+       ; Write disk id
	clr.w	(a2)+                   ; Usually 0 ... so we write 0

.updprt	flagtst	ok,(a1)                 ; Check if there is a partition
	beq.b	.nopart                 ;

	flagtst	b,(a1)                  ; Check bootable flag
	beq.b	.nboot                  ;
	move.l	#$80000000,(a2)+        ; Set boot flag, clear CHS first
	bra.b	.bootok                 ;
.nboot	clr.l	(a2)+                   ; Clear boot flag and CHS first
.bootok

	movem.l	d1-d2/a1-a2,-(sp)       ; Convert partition type to MBR
	lea	part.type(a1),a0        ;
	bsr.w	parts.t2b               ;
	movem.l	(sp)+,d1-d2/a1-a2       ;
	move.b	d0,(a2)                 ; Write partition type

	and.l	#$ff000000,(a2)+        ; Clear size CHS

	move.l	part.first(a1),d0       ; Set first sector
	bsr.w	parts.byteswap          ;
	move.l	d0,(a2)+                ;

	move.l	part.size(a1),d0        ; Set partition size
	bsr.w	parts.byteswap          ;
	move.l	d0,(a2)+                ;

.nxtprt	lea	part...(a1),a1          ; Point at next partition
	dbra	d2,.updprt              ;

	move.w	#$55aa,(a2)+            ; Write signature

	rts

.nopart	clrblk	(a2),mpart...           ; Clear MBR partition entry
	move.l	a0,a2                   ; Update pointer
	bra.b	.nxtprt                 ;

parts.newpt
	; Scratch everything and create a new MBR partition table

	bsr.w	blkdev.cap              ; Read device capacity
	move.l	d0,d1                   ; d1 is not altered by clrblk !
	beq.w	parttool.err            ;

	clrblk	(a3),part...            ; Trash everything
	clrblk	(a4),pt...              ;

	move.l	d1,part.size(a3)        ; Set block device size
	subq.l	#1,d1                   ;
	move.l	d1,part.last(a3)        ;
	flagset	ok                      ;

	flagset	bs                      ; Boot sector content is valid

	move.l	#'MBR'<<8,(a3)          ; Set format as MBR
	flagset	pt                      ; It has an empty partition table

	move.l	hz200.w,d0              ; Set a vaguely pseudorandom id
	swap	d0                      ;
	move.l	vbclock.w,d1            ;
	eor.l	d1,d0                   ;
	move.l	d0,d1                   ;
	rol.l	#5,d1                   ;
	eor.l	d1,d0                   ;
	move.l	d0,part.id(a3)          ;

	bsr.w	parts.updparts          ; Update partitions
	move.w	#$1b6,d0                ; Patch boot sector
	bsr.w	parts.patchboot         ; Make sure it's not bootable

	flagset	pend                    ; Pending modifications (not kidding !)

	rts

parts.settype
	; Set partition MBR type based on its filesystem
	; Input:
	;  a3: Descriptor address

	bsr.w	parts.sensebs           ; Sense partition content

	cmp.l	#'F16'<<8,(a3)          ; Set partition type
	beq.b	.f16                    ;

	move.l	#' 01'<<8,part.type(a3) ; Partition is FAT12
	rts

.f16	move.l	#' 06'<<8,part.type(a3) ; Partition is FAT16
	rts

parts.patchboot
	; Patch the boot sector checksum to make it match flags_boot
	; Input:
	;  a3: Descriptor address
	;  part.flags_boot(a3): desired bootable state
	; Output:
	;  (a3): A sector matching

	; Check that the boot sector is loaded
	bsr.w	parts.loadbs

	lea	part.bootsect(a3),a0    ; Test the current boot status
	bsr.w	parts.cksum             ;
	cmp.w	#$1234,d0               ;
	bne.b	.nboot                  ;

	; The partition is bootable
	flagtst	boot                    ; Check if it should be
	rtsne	                        ; Return if boot sector matches the flag
	bra.b	.chktyp                 ; Mismatch: patch the boot sector

.nboot	; Thr partition is not bootable
	flagtst	boot                    ; Check if it should be
	rtseq	                        ; Return if boot sector matches the flag

.chktyp	bsr.w	parts.cksumoffset	

	lea	part.bootsect(a3,d0),a1 ; a1 = checksum address

	clr.w	(a1)                    ; Clear current checksum

	lea	part.bootsect(a3),a0    ; Compute checksum
	bsr.w	parts.cksum             ;

	sub.w	#$1234,d0               ; Correct checksum to make it bootable
	neg.w	d0                      ;

	flagtst	boot                    ; Check if it should be bootable
	bne.b	.write                  ;

	addq.w	#1,d0                   ; Make it non-bootable

.write	move.w	d0,(a1)                 ; Write updated checksum

	rts

parts.save
	; Save changes in the descriptor to the disk
	; Input:
	;  a3: Descriptor address
	;  a4: Partition table
	; Output:
	;  d0.l: 0 iif successfully saved
	;  Z: set iif successful

	flagtst	pt                      ; Test if the partition table must be
	beq.b	.write                  ; updated

	bsr.w	parts.updparts          ; Update partitions
.write	bsr.w	parts.patchboot         ;

	lea	part.bootsect(a3),a0    ; Write the boot sector
	moveq	#1,d0                   ;
	move.l	a0,d1                   ;
	moveq	#0,d2                   ;
	bsr.w	blkdev.wr               ;
	bne.b	.err                    ;

	flagclr	pend                    ; No more pending changes

	moveq	#0,d0
	rts
.err	moveq	#1,d0
	rts

parts.cksumoffset
	; Returns the offset of the checksum based on the partition type
	; Input:
	;  a3: Descriptor address
	; Output:
	;  d0.w: Checksum offset

	flagtst	fs
	beq.b	.notfs
	move.w	#$1f4,d0
	rts
.notfs
	move.w	#$1b6,d0
	rts

parts.iter
	; Iterate over all defined partitions of a partition table
	; Input:
	;  a0: routine to call
	;  a4: partition table start address
	; In callback:
	;  a0: partition address

	lea	.raddr(pc),a1
	move.l	a0,(a1)
	move.l	a4,4(a1)
	move.b	#maxparts,8(a1)

.it	move.l	.paddr(pc),a0           ; Check if the partition is defined
	flagtst	ok,(a0)                 ;
	beq.b	.npart                  ;

	move.l	.raddr(pc),a1           ; Call the callback
	jsr	(a1)                    ;

.npart	lea	.paddr(pc),a1           ; Point paddr at next partition
	move.l	(a1),a0                 ;
	lea	part...(a0),a0          ;
	move.l	a0,(a1)                 ;

	subq.b	#1,4(a1)                ; Iterate
	bne.b	.it                     ;

	rts

.raddr	ds.l	1
.paddr	ds.l	1
.cnt	ds.b	1
	even

parts.b2t
	; Converts a binary MBR partition type to part.type (hexadecimal)
	; Input:
	;  d0.b: Value to convert
	;  a0: Output buffer
	
	move.b	#' ',(a0)+

	move.b	d0,d1                   ; Compute first digit
	lsr.b	#4,d1                   ;
	bsr.b	.digit                  ; Output 1st digit

	move.b	d0,d1                   ; Compute second digit
	and.b	#$f,d1                  ;
	bsr.b	.digit                  ;

	clr.b	(a0)                    ; Terminate string
	rts

.digit	add.b	#'0',d1
	cmp.b	#'9',d1
	bls.b	.dok
	addq.b	#'A'-'9'-1,d1
.dok	move.b	d1,(a0)+
	rts

parts.t2b
	; Convert a hexadecimal ASCII partition type string
	; to a MBR partition type
	; In case of doubt, outputs 0
	; Input:
	;  a0: String to parse
	; Output:
	;  d0.l: Partition type

	moveq	#0,d0

.parse	move.b	(a0)+,d1
	rtseq

	cmp.b	#'0'-1,d1               ; Less than a digit: ignore
	bls.b	.parse                  ;

	cmp.b	#'9',d1                 ; Check if that is a digit
	bhi.b	.ndigit                 ;

	sub.b	#'0',d1                 ; Add digit
.add	lsl.b	#4,d0                   ;
	or.b	d1,d0                   ;
	bra.b	.parse                  ;

.ndigit
	and.b	#$df,d1                 ; Convert to upper case

	cmp.b	#'A'-1,d1               ; Ignore if it is not hexadecimal
	bls.b	.parse                  ;
	cmp.b	#'F',d1                 ;
	bhi.b	.parse                  ;

	sub.b	#'A'-10,d1              ; Convert to binary
	bra.b	.add                    ;

parts.cksum
	; Does the checksum of a 512 bytes block
	; Input:
	;  a0: block to check
	; Output:
	;  d0.w: checksum

	moveq	#0,d0
	move.w	#255,d1
.cksum	add.w	(a0)+,d0
	dbra	d1,.cksum
	rts

parts.readu32le
	; Read unaligned 32 bits little-endian number
	; Input:
	;  a0: address to read from
	; Output:
	;  a0: address after the number
	;  d0.l: number read

	move.b	(a0)+,d0
	lsl.w	#8,d0
	move.b	(a0)+,d0
	lsl.l	#8,d0
	move.b	(a0)+,d0
	lsl.l	#8,d0
	move.b	(a0)+,d0
	rts

parts.writeu32le
	; Write unaligned 32 bits little-endian number
	; Input:
	;  a0: address to write to
	;  d0.l: number to write
	; Output:
	;  a0: address after the number

	move.b	d0,(a0)+
	lsr.w	#8,d0
	move.b	d0,(a0)+
	lsr.l	#8,d0
	move.b	d0,(a0)+
	lsr.l	#8,d0
	move.b	d0,(a0)+
	rts

parts.byteswap
	; Byte swap d0
	rol.w	#8,d0
	swap	d0
	rol.w	#8,d0
	rts

parts.clrblk
	; Clear a block
	; Input:
	;  d0: number of 8 bytes blocks - 1
	;  a0: destination
	clr.l	(a0)+
	clr.l	(a0)+
	dbra	d0,parts.clrblk
	rts

parts.copyblk
	; Copy a block
	; Input:
	;  d0: number of 8 bytes blocks - 1
	;  a0: source
	;  a1: destination
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,parts.copyblk
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
