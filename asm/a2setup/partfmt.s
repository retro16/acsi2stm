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
; Partition / disk format

partfmt
	; Filesystem tool
	; Input:
	;  a3: Device descriptor
	;  a5: Target partition descriptor
	;  d7.b: ACSI id

	cls
	bsr.w	parttool.save1st        ; Changes must be saved to disk
	bsr.w	partfmt.init            ; Initialize pfmt with best defaults

	enter

	print	.header(pc)
	lea	bss+pfmt(pc),a0         ;
	bsr.w	partfmt.pfmt
	savepos
	bsr.w	partfmt.pskip
	print	.keys(pc)

.again	bsr.w	menu.waitmed
	gemdos	Cnecin,2

	lea	bss+pfmt(pc),a0

	cmp.b	#$1b,d0
	exiteq

	and.b	#$df,d0                 ; Case insensitive checks
	
	cmp.b	#'F',d0
	beq.w	partfmt.format

	cmp.b	#'O',d0
	beq.w	partfmt.optimz

	cmp.b	#'M',d0
	beq.w	partfmt.maxize

	cmp.b	#'S',d0
	beq.w	partfmt.setss

	cmp.b	#'C',d0
	beq.w	partfmt.setcs

	cmp.b	#'D',d0
	beq.w	partfmt.setroot

	cmp.b	#'N',d0
	beq.w	partfmt.newsn

	cmp.b	#'L',d0
	beq.w	partfmt.newlbl

	cmp.b	#'R',d0
	beq.w	partfmt.setrsv

	cmp.b	#'X',d0
	beq.w	partfmt.setcc

	bra.b	.again

.header	dc.b	'Parameters:',13,10
	dc.b	10,0

.keys	dc.b	13,10
	dc.b	10
	dc.b	'  O:Optimize  M:Maximize size',13,10
	dc.b	'  F:Format',13,10
	dc.b	'Esc:Back',13,10,10,0
	even

partfmt.auto
	; Format a partition automatically
	; Input:
	;  a5: partition to format
	bsr.b	partfmt.init
	bra.w	partfmt.dofmt

partfmt.init
	; Initialize the pfmt data structure
	; Input:
	;  a5: partition to format

	lea	bss+pfmt(pc),a0         ; Clear structure
	clrblk	(a0),pfmt...            ;

	lea	bss+pfmt(pc),a0

	move.l	part.last(a5),d0        ; Compute content size of the partition
	move.l	part.first(a5),d1       ;

	move.l	d1,pfmt.offset(a0)      ; Set partition offset
	sub.l	d1,d0                   ;
	addq.l	#1,d0                   ;
	move.l	d0,pfmt.psect(a0)       ; Set partition size

	bsr.w	partfmt.gensn           ; Set a random serial number
	lea	bss+pfmt(pc),a0
	bra.w	partfmt.optim           ; Compute sensible defaults

partfmt.setcc
	; Set cluster count

	move.l	#32767,d0               ; Maximum value for TOS
	bsr.w	readint

	tst.l	d0
	rsteq

	lea	bss+pfmt(pc),a0         ; Set cluster count
	move.l	d0,pfmt.dclust(a0)      ;

	bsr.w	partfmt.head            ; Refresh header size
	bsr.w	partfmt.tsect           ; Refresh sector count

	move.w	pfmt.ssize(a0),d1
	move.l	pfmt.tsect(a0),d0
	lsl.l	d1,d0

	cmp.l	pfmt.psect(a0),d0
	bls.b	.ok

	print	.oversz(pc)
	bsr.w	presskey

.ok	restart

.oversz	dc.b	13,10,7,'Warning: FS bigger than partition',13,10,0
	even

partfmt.newlbl
	; New label

	clrblk	bss+buf(pc),16          ; Clear text buffer
	lea	bss+buf(pc),a0          ; Buffer to read a 11 char string
	move.b	#11,(a0)                ;

	curson
	pea	(a0)                    ; Read string
	gemdos	Cconrs,6                ;
	cursoff

	lea	bss+buf+2(pc),a0        ;
	lea	bss+pfmt+pfmt.label(pc),a2 ; TODO: filter out invalid characters
	bsr.w	partfmt.cpylabl         ; Copy label to the structure

	restart

partfmt.newsn
	; New serial number

	bsr.b	partfmt.gensn
	restart

partfmt.gensn
	; Generate a serial number

	bsr.w	random                  ; Set a random serial number
	lea	bss+pfmt+pfmt.serial(pc),a0 ;
	move.l	d0,(a0)                 ;

	rts

partfmt.setss
	; Set sector size

	moveq	#64,d0                  ; Maximum value:16384
	lsl.l	#8,d0                   ;
	bsr.w	readint

	move.l	#511,d1                 ; Minimum value: 512
	bsr.w	partfmt.chkval          ;

	bsr.w	log2                    ; Convert to ssize
	sub.w	#9,d1                   ;

	lea	bss+pfmt+pfmt.ssize(pc),a0 ;
	move.w	d1,(a0)                 ; Set ssize

	bra.b	partfmt.maxize          ; Maximize size and check values

partfmt.setrsv
	; Set reserved sectors

	move.l	pfmt.psect(a0),d0       ; Maximum value
	move.w	pfmt.ssize(a0),d1       ;
	lsr.w	d1,d0                   ;
	sub.l	#512,d0                 ; Keep 512 sectors for actual data
	bsr.w	readint                 ;

	moveq	#0,d1                   ; Minimum value:1
	moveq	#0,d2                   ; Can be a non-power of 2
	bsr.w	partfmt.chkval          ;

	lea	bss+pfmt+pfmt.res(pc),a0 ;
	move.l	d0,(a0)                 ; Set root

	bra.b	partfmt.maxize          ; Maximize size and check values

partfmt.setroot
	; Set root directory entries

	moveq	#64,d0                  ; Maximum value:1024
	lsl.l	#4,d0                   ;
	bsr.w	readint                 ;

	moveq	#15,d1                  ; Minimum value:16 (1 sector)
	moveq	#0,d2                   ; Can be a non-power of 2
	bsr.w	partfmt.chkval          ;

	lea	bss+pfmt+pfmt.root(pc),a0 ;
	move.l	d0,(a0)                 ; Set root

	bra.b	partfmt.maxize          ; Maximize size and check values

partfmt.setcs
	; Set cluster size

	moveq	#32,d0                  ; Maximum value:32
	bsr.w	readint

	moveq	#0,d1                   ; Minimum value: 1
	moveq	#1,d2                   ; Must be a power of 2
	bsr.w	partfmt.chkval          ;

	bsr.w	log2                    ; Convert to csize

	lea	bss+pfmt+pfmt.csize(pc),a0 ;
	move.w	d1,(a0)                 ; Set ssize

	; Fall through partfmt.maxize
partfmt.maxize
	; Maximize cluster count to fit partition

	bsr.w	partfmt.max
	restart

partfmt.max
	; Maximize cluster count to fit partition
	lea	bss+pfmt(pc),a0
	bsr.w	partfmt.totalcl

	; Fall through partfmt.fixprm
partfmt.fixprm
	; Fix parameters

	lea	bss+pfmt(pc),a0
	move.l	pfmt.dclust(a0),d0      ; d0 = cluster count

	cmp.l	#4087,d0                ; Switch to FAT12 if too small
	sls	pfmt.fat12(a0)          ;
	bls.b	.fat12                  ;

	move.w	#32767,d1               ; Cap to maximum number of clusters
	cmp.l	d1,d0                   ;
.compar	bls.b	.ok                     ; for FAT16 partition
	move.l	d1,d0                   ;
	bra.b	.ok                     ;

.fat12	cmp.l	#4083,d0                ; Cap to maximum number of clusters
	bls.b	.ok                     ; for FAT12 partition
	move.l	#4083,d0                ;

.ok	move.l	d0,pfmt.dclust(a0)      ; Refresh cluster count
	bsr.w	partfmt.head            ; Refresh header
	bsr.w	partfmt.tsect           ; Refresh sector count

	rts

partfmt.format
	; Do the actual format operation

	bsr.w	areyousure
	rstne

	bsr.b	partfmt.dofmt
	exit

partfmt.dofmt
	clrblk	bss+buf(pc),512         ; Clear boot sector

	flagset	fs,(a5)                 ; Mark as a valid filesystem
	flagclr	bs,(a5)                 ; Invalidate boot data

	; Patch in boot data

	lea	bss+buf(pc),a1
	move.w	#$55aa,fat.sig(a1)

	lea	fat.oem(a1),a2          ; a2 = pointer inside the boot sector

	move.b	#'A',(a2)+              ;
	move.l	#'2SET',(a2)+           ;
	move.w	#'UP',(a2)+             ;
	move.b	#' ',(a2)+              ; fat.oem

	move.w	bss+pfmt+pfmt.ssize(pc),d1 ;
	add.w	#9,d1                   ;
	moveq	#0,d0                   ;
	bset	d1,d0                   ;
	bsr.w	partfmt.wrshort         ; fat.bps

	move.w	bss+pfmt+pfmt.csize(pc),d1 ;
	moveq	#0,d0                   ;
	bset	d1,d0                   ;
	move.b	d0,(a2)+                ; fat.spc

	move.l	bss+pfmt+pfmt.res(pc),d0 ;
	bsr.w	partfmt.wrshort         ; fat.res

	move.b	#2,(a2)+                ; fat.nfats

	move.l	bss+pfmt+pfmt.root(pc),d0 ;
	bsr.w	partfmt.wrshort         ; fat.ndirs

	move.l	bss+pfmt+pfmt.tsect(pc),d0 ;
	cmp.l	#$0000ffff,d0           ;
	bhi.b	.bigdsk                 ;
	clr.l	fat.hsects-fat.nsects-2(a2) ; fat.hsects
	bsr.w	partfmt.wrshort         ; fat.nsects
	bra.b	.sectok                 ;
.bigdsk	
	lea	fat.hsects-fat.nsects(a2),a2
	bsr.w	partfmt.wrlong          ; fat.hsects
	lea	-fat.hsects+fat.nsects-4(a2),a2
	clr.b	(a2)+                   ;
	clr.b	(a2)+                   ; fat.nsects
.sectok
	move.b	#$f8,(a2)+              ; fat.media

	move.l	bss+pfmt+pfmt.fatsz(pc),d0 ;
	bsr.w	partfmt.wrshort         ; fat.spf

	move.w	bss+pfmt+pfmt.spt(pc),d0 ;
	bsr.w	partfmt.wrshort         ; fat.spt

	move.w	bss+pfmt+pfmt.nheads(pc),d0 ;
	bsr.w	partfmt.wrshort         ; fat.nheads

	clr.l	(a2)+                   ; fat.nhid

	addq.l	#4,a2                   ; Skip fat.hsects (already written)

	move.b	#$80,(a2)+              ; fat.drnum

	clr.b	(a2)+                   ; reserved byte

	move.b	#$29,(a2)+              ; fat.ebsig

	move.l	bss+pfmt+pfmt.serial(pc),d0 ;
	bsr.w	partfmt.wrlong          ; fat.volid

	lea	bss+pfmt+pfmt.label(pc),a0 ;
	bsr.w	partfmt.cpylabl         ; fat.vlab

	move.l	#'FAT1',(a2)+           ;
	move.b	bss+pfmt+pfmt.fat12(pc),d0 ;
	bne.b	.f12typ                 ;
	move.l	#'6   ',(a2)+           ; fat.fstype
	bra.b	.typok                  ;
.f12typ	move.l	#'2   ',(a2)+           ; fat.fstype
.typok
	movem.l	d3-d5,-(sp)             ;
	move.l	bss+pfmt+pfmt.offset(pc),d4 ; d4 = current sector to write

	; Write boot sector

	moveq	#1,d0                   ; Write 1 sector
	move.l	a1,d1                   ; Boot sector pointer
	move.l	d4,d2                   ; Boot sector offset on the drive
	bsr.w	blkdev.wr

	; Skip reserved sectors

	move.l	bss+pfmt+pfmt.res(pc),d3 ; Compute reserved physical sectors
	bsr.b	.l2p                    ;

	add.l	d3,d4                   ; Skip reserved sectors

	; Write FATs

	moveq	#1,d5

.fats	bsr.w	partfmt.genfat
	moveq	#0,d3
	bsr.b	partfmt.bufwr

	clrblk	bss+buf(pc),512         ; Empty FAT sectors

	move.l	bss+pfmt+pfmt.fatsz(pc),d3 ;
	bsr.b	.l2p                    ;
	subq.w	#2,d3                   ; Empty physical sectors for FAT
	bmi.b	.nfat

	bsr.b	partfmt.bufwr
.nfat
	dbra	d5,.fats

	; Write root directory

	bsr.w	partfmt.genlabl         ; Generate label entry
	moveq	#0,d3                   ;
	bsr.b	partfmt.bufwr           ; Write disk label if any

	clrblk	bss+buf(pc),512         ; Empty root sectors

	move.l	bss+pfmt+pfmt.root(pc),d3 ;
	bsr.b	.l2p                    ;
	subq.w	#2,d3                   ; Physical sectors for root directory
	bmi.b	.nroot

	bsr.b	partfmt.bufwr           ; Write empty root directory
.nroot
	movem.l	(sp)+,d3-d5             ; Restore registers

	rts

.l2p	; Convert logical to physical sectors
	; Input:
	;  d3.l: Logical sector count
	;  pfmt.ssize
	; Output:
	;  d3.l: Physical sector count
	move.w	bss+pfmt+pfmt.ssize(pc),d1
	lsl.l	d1,d3
	rts

partfmt.bufwr
	; Write the content of buf n times
	; Input:
	;  bss+buf(pc): Data to write (512 bytes)
	;  d3.w: Write repeats - 1
	;  d4.l: Target sector
	; Output:
	;  d4.l: Updated with sector count

	moveq	#1,d0                   ;
	lea	bss+buf(pc),a0          ;
	move.l	a0,d1                   ;
	move.l	d4,d2                   ;
	bsr.w	blkdev.wr               ; Write one sector

	tst.w	d0                      ; Exit if error (unclean registers)
	exitne	                        ;

	addq.l	#1,d4                   ; Point at next sector on disk

	dbra	d3,partfmt.bufwr        ; Loop

	rts

partfmt.cpylabl
	; Copy a disk label
	; Pads with spaces
	; Input:
	;  a0: source
	;  a2: target
	; Output:
	;  a2: 11(a2)

	moveq	#10,d0

.cpy	move.b	(a0)+,(a2)+
	dbeq	d0,.cpy

	bne.b	.nnul
	move.b	#$20,-1(a2)

.nnul	subq.w	#1,d0
	bmi.b	.done

.fill	move.b	#$20,(a2)+
	dbra	d0,.fill

.done	rts

partfmt.genlabl
	; Generate a disk label if any
	; Input:
	;  pfmt.label
	; Output:
	;  bss+buf(pc): Sector data

	clrblk	bss+buf(pc),512

	moveq	#' ',d0
	cmp.b	bss+pfmt+pfmt.label(pc),d0
	rtseq	                        ; Return if empty label

	lea	bss+buf(pc),a2
	lea	bss+pfmt+pfmt.label(pc),a0
	bsr.b	partfmt.cpylabl         ; Copy label name

	move.b	#$08,(a2)               ; Label entry

	rts

partfmt.genfat
	; Generate an empty fat sector
	; Input:
	;  pfmt.fat12
	; Output:
	;  bss+buf(pc): Sector data

	clrblk	bss+buf(pc),512

	lea	bss+buf(pc),a0
	move.b	bss+pfmt+pfmt.fat12(pc),d0
	bne.b	.fat12

	move.l	#$f8ffffff,(a0)+
	rts

.fat12	move.l	#$f8ffff00,(a0)+
	rts

partfmt.wrlong
	; Write the long little-endian number in d0 to (a2)
	move.b	d0,(a2)+
	lsr.l	#8,d0
	move.b	d0,(a2)+
	lsr.l	#8,d0

partfmt.wrshort
	; Write the short little-endian number in d0 to (a2)
	move.b	d0,(a2)+
	lsr.w	#8,d0
	move.b	d0,(a2)+
	rts

partfmt.optimz
	; Menu entry that just calls optim and restarts
	bsr.b	partfmt.optim
	restart

partfmt.optim
	; Compute optimal values for a given filesystem
	; Input:
	;  a0: pfmt struct
	;  part.first(a3)
	;  part.last(a3)

	move.l	pfmt.psect(a0),d0       ; Get partition size

	cmp.l	#$2000,d0               ; Small filesytems = FAT12
	sls	pfmt.fat12(a0)          ;
	bls.b	.fat12r
	move.l	#512,pfmt.root(a0)      ; 512 root entries
	bra.b	.rootok
.fat12r	move.l	#64,pfmt.root(a0)       ; 64 root entries for FAT12
.rootok
	clr.w	pfmt.ssize(a0)          ; Start with 512 bytes sectors

	move.b	#16,pfmt.res+3(a0)      ; Reserve 16 sectors for driver

	move.w	#1,pfmt.csize(a0)       ; Start with 2 sectors per cluster

.comput	bsr.w	partfmt.totalcl         ; Compute total cluster count to fit
	bsr.w	partfmt.tsect           ; Compute logical sector count

	move.l	pfmt.dclust(a0),d0      ; Check cluster count

	tst.b	pfmt.fat12(a0)
	bne.b	.fat12

	cmp.l	#32767,d0               ; Check maximum number of clusters
.compar	bls.b	.ok

	cmp.b	#4,pfmt.ssize+1(a0)     ; Limit to 8192 bytes sectors
	beq.b	.ok                     ;

	addq.b	#1,pfmt.ssize+1(a0)     ; Increase sector size
	bra.b	.comput                 ;

.fat12	cmp.w	#4083,d0
	bra.b	.compar
.ok
	bra.w	partfmt.max             ; Maximize size with current sector size

partfmt.fatsz
	; Computes FAT size
	; Input:
	;  pfmt.fat12(a0)
	;  pfmt.dclust(a0)
	;  pfmt.ssize(a0)
	;  pfmt.csize(a0)
	; Output:
	;  pfmt.fatsz(a0)
	;  d0.w: FAT size

	move.l	pfmt.dclust(a0),d0      ; Compute cluster entries
	addq.w	#2,d0                   ; Add 2 reserved FAT entries

	tst.b	pfmt.fat12(a0)
	bne.b	.fat12
	lsl.l	#1,d0                   ; 2 bytes per cluster
	bra.b	.entok

.fat12	mulu	#3,d0                   ; 3 bytes for 2 clusters
	lsr.l	#1,d0                   ;
	bcc.b	.entok                  ;
	addq.l	#1,d0                   ;
.entok		                        ; d0 = FAT size in bytes

	move.w	pfmt.ssize(a0),d1       ; d1 = Logical sector size bits
	add.w	#9,d1                   ;
	bsr.w	tsr                     ; Divide by sector size

	move.l	d0,pfmt.fatsz(a0)       ; Update structure

	rts

partfmt.rootsz
	; Computes root directory size in sectors
	; Input:
	;  pfmt.ssize(a0)
	;  pfmt.root(a0)
	; Output:
	;  d0.l: Number of logical sectors

	move.l	pfmt.root(a0),d0        ; d0 = root entries
	move.w	pfmt.ssize(a0),d1       ; d1 = logical sectors log2
	addq.w	#5,d1                   ; 32 bytes per entry
	bsr.w	tsr                     ; Divide with rounding
	rts

partfmt.head
	; Computes the header size
	; Input:
	;  pfmt.fat12(a0)
	;  pfmt.dclust(a0)
	;  pfmt.ssize(a0)
	;  pfmt.csize(a0)
	;  pfmt.root(a0)
	;  pfmt.res(a0)
	;  pfmt.fatsz(a0)
	; Output:
	;  pfmt.head(a0)
	;  d0.l: Header size

	bsr.w	partfmt.fatsz           ; Refresh FAT size estimate
	bsr.w	partfmt.rootsz          ; d0 = root directory size

	add.l	pfmt.res(a0),d0         ;
	add.l	pfmt.fatsz(a0),d0       ;
	add.l	pfmt.fatsz(a0),d0       ; d0 = header size in logical sectors

	move.l	d0,pfmt.head(a0)

	rts

partfmt.tsect
	; Computes total filesystem size
	; Input:
	;  pfmt.head(a0)
	;  pfmt.dclust(a0)
	; Output:
	;  pfmt.tsect(a0)
	;  d0.l: filesystem size in logical sectors

	move.l	pfmt.dclust(a0),d0      ; Compute data size
	move.w	pfmt.csize(a0),d1       ;
	lsl.l	d1,d0                   ;

	add.l	pfmt.head(a0),d0        ; Add header size

	move.l	d0,pfmt.tsect(a0)       ; Store result

	rts

partfmt.totalcl
	; Compute number of total clusters to fit in the partition
	; Input:
	;  pfmt.ssize(a0)
	;  pfmt.csize(a0)
	;  pfmt.res(a0)
	;  pfmt.fatsz(a0)
	;  pfmt.root(a0)
	;  pfmt.psect(a0)
	; Output:
	;  pfmt.dclust(a0)
	;  d0.l: number of clusters

	bsr.w	partfmt.approx          ; Approximate cluster count

	cmp.l	#32768+1024,d0          ; Quick sanity check
	bhi.b	.end                    ;

	move.w	d3,-(sp)                ;
	moveq	#0,d3                   ; d3 = loop counter

.twice	bsr.w	partfmt.head            ; Compute header size

	move.l	pfmt.psect(a0),d1       ;
	move.w	pfmt.ssize(a0),d2       ;
	lsr.l	d2,d1                   ; d1 = partition size in logical sectors

	sub.l	d0,d1                   ; Compute data sector count

	move.w	pfmt.csize(a0),d2       ; Convert to clusters
	lsr.l	d2,d1                   ;

	move.l	d1,d0                   ; Return value
	move.l	d0,pfmt.dclust(a0)      ;

	dbra	d3,.twice               ; Do a second pass with realistic values

	move.w	(sp)+,d3                

.end	rts

partfmt.approx
	; Approximate the number of clusters in a partition
	; Also sets FAT12 or FAT16
	; Input:
	;  pfmt.ssize(a0)
	;  pfmt.csize(a0)
	;  pfmt.psect(a0)
	; Output:
	;  pfmt.dclust(a0)
	;  d0.l: cluster count

	move.l	pfmt.psect(a0),d0       ;
	move.w	pfmt.ssize(a0),d1       ;
	add.w	pfmt.csize(a0),d1       ;
	bsr.w	tsr                     ; d0 = sectors / sectors per cluster

	move.l	d0,pfmt.dclust(a0)      ; Save intermediate value

	rts

partfmt.pskip
	loadpos
	clrbot
	rts

partfmt.chkval
	; Check that d0 is above a minimum value
	; Restart if d0 is 0
	; Optionally, check that d0 contains a power of 2
	; If not the case, display a warning and restart
	; Input:
	;  d0.l: Value to check
	;  d1.l: Minimum value
	;  d2.b: If non-zero, check that the value is a power of 2
	; Output:
	;  d0.l: Checked value

	tst.l	d0                      ; If zero, just restart
	rsteq	                       

	cmp.l	d1,d0                   ; Check minimum value
	bhi.b	.ok                     ;

	print	.toolow(pc)             ; Error: value too low
	bra.b	.askrst                 ;

.ok	tst.b	d2                      ; Test if we need to check POT
	rtseq	                        ;

	move.l	d0,d2                   ; Check that d0 is a power of 2
	subq.l	#1,d2                   ;
	and.l	d0,d2                   ;
	rtseq	                        ;

	print	.notpot(pc)             ; Not a power of 2: complain
.askrst	bsr.w	presskey                ; Wait for a key and
	restart	                        ; restart

.notpot	dc.b	13,10,'The value must be a power of 2',13,10,0
.toolow	dc.b	13,10,'Value is too low',13,10,0
	even

partfmt.pfmt
	; Print current format settings
	; Input:
	;  a0: data structure

	move.l	a3,-(sp)
	lea	pfmt.fat12(a0),a3

	print	.fmt(pc)
	tst.b	(a3)+
	bne.b	.fat12
	print	.fmt.16(pc)
	bra.b	.fmtok
.fat12	print	.fmt.12(pc)
.fmtok
	print	.ssize(pc)
	move.w	(a3)+,d1
	add.w	#9,d1
	bsr.w	.plog2

	print	.csize(pc)
	move.w	(a3)+,d1
	bsr.b	.plog2

	print	.res(pc)
	move.l	(a3)+,d0
	bsr.b	.plong

	print	.fatsz(pc)
	move.l	(a3)+,d0
	bsr.b	.plong

	print	.root(pc)
	move.l	(a3)+,d0
	bsr.b	.plong

	print	.dclust(pc)
	move.l	(a3)+,d0
	bsr.b	.plong

	print	.serial(pc)
	move.l	(a3)+,d0
	bsr.w	phlong
	crlf

	print	.label(pc)
	pea	(a3)
	gemdos	Cconws,6

	move.l	(sp)+,a3
	rts

.plog2	moveq	#0,d0
	bset	d1,d0
	moveq	#1,d1
	bsr.w	puint
	crlf
	rts

.plong	moveq	#1,d1
	bsr.w	puint
	crlf
	rts

.fmt	dc.b	'FAT type   :FAT1',0
.fmt.12	dc.b	'2',13,10,0
.fmt.16	dc.b	'6',13,10,0
.ssize	dc.b	' Sect.sz[S]:',0
.csize	dc.b	'Clust.sz[C]:',0
.res	dc.b	'Reserved[R]:',0
.fatsz	dc.b	'FAT size   :',0
.root	dc.b	'Root dir[D]:',0
.dclust	dc.b	'Clusters[X]:',0
.serial	dc.b	'  Serial[N]:',0
.label	dc.b	'   Label[L]:',0
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
