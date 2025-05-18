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

; Test matrix for error values
; This test tries to cover returned error codes systematically

	; Actions that can be triggered after the call
AEND	equ	$F0000000               ; End of list
ALOGD0	equ	$F0000001               ; Log the return value
ACHKD0	equ	$F0000002               ; Check d0 >= 0
ADDELE	equ	$F0000003               ; Check d0 >= 0 and Ddelete on the path
AFDELE	equ	$F0000004               ; Check d0 >= 0 and Fdelete on the path
ACLOSE	equ	$F0000005               ; Fclose d0
ACLDEL	equ	$F0000006               ; Fclose d0 and Fdelete on the path
ADCREA	equ	$F0000007               ; Check d0 >= 0 and Dcreate on the path
AFCREA	equ	$F0000008               ; Check d0 >= 0 and Fcreate on the path

tmx:
	print	.desc

	bsr	.create

	lea	.matrices,a6            ; a6 = matrix pointer

.nxtmx	tst.l	(a6)                    ; Test end of matrix
	beq	.clean                  ; Clean and exit

	movem.l	(a6)+,a3-a5             ; Load function and matrix pointers
	print	.testmx                 ;
	print	(a3)                    ;
	crlf	                        ;

.nxttst	movem.l	(a5)+,d3/a3             ; Load value, name and path pointer

	cmp.l	#AEND,d3                ; Check for end of matrix
	beq	.nxtmx                  ;

	print	.wpath                  ; Print tested path
	print	(a3)                    ;
	crlf	                        ;

	move.w	drive,-(sp)             ; Reset correct current path
	gemdos	Dsetdrv,4               ;
	pea	.topdir                 ;
	gemdos	Dsetpath,6              ;

	jsr	(a4)                    ; Execute the function
	move.l	d0,d4                   ; Store d0

	cmp.l	#ALOGD0,d3              ;
	beq	.alogd0                 ;
	cmp.l	#ACHKD0,d3              ;
	beq	.achkd0                 ;
	cmp.l	#ADDELE,d3              ;
	beq	.addele                 ;
	cmp.l	#AFDELE,d3              ;
	beq	.afdele                 ;
	cmp.l	#ACLOSE,d3              ;
	beq	.aclose                 ;
	cmp.l	#ACLDEL,d3              ;
	beq	.acldel                 ;
	cmp.l	#ADCREA,d3              ;
	beq	.adcrea                 ;
	cmp.l	#AFCREA,d3              ;
	beq	.afcrea                 ;

	cmp.l	d4,d3                   ; Check error code
	bne	.wrngec                 ;

.tstok	add.w	#1,success              ;
	bra	.nxttst                 ;

.wrngec	print	.expct                  ; Wrong error code
	move.l	d3,d0                   ;
	bsr	tui.phlong              ;
	print	.got                    ;
	move.l	d4,d0                   ;
	bsr	tui.phlong              ;
	crlf	                        ;

.tsterr	add.w	#1,failed               ;
	gemdos	Cnecin,2                ; Wait for a key
	bra	.nxttst                 ;


.alogd0	print	.got                    ; Log d0 and go on
	move.l	d4,d0                   ;
	bsr	tui.phlong              ;
	crlf	                        ;
	gemdos	Cnecin,2                ; Wait for a key
	bra	.nxttst                 ;

.addele	tst.l	d4                      ; Check if ok
	bne	.nddele                 ;
	pea	(a3)                    ; Delete directory
	gemdos	Ddelete,6               ;
.nddele	bra	.achkd0                 ;

.afdele	tst.l	d4                      ; Check if ok
	bne	.nfdele                 ;
	pea	(a3)                    ; Delete file
	gemdos	Fdelete,6               ;
.nfdele	bra	.achkd0                 ;

.aclose	tst.w	d4                      ; Check descriptor
	bmi	.fdnok                  ;
	move.w	d4,-(sp)                ; Close descriptor
	gemdos	Fclose,4                ;
	bra	.fdck

.acldel	tst.w	d4                      ; Check descriptor
	bmi	.fdnok                  ;
	move.w	d4,-(sp)                ; Close descriptor
	gemdos	Fclose,4                ;
	pea	(a3)                    ; Delete file
	gemdos	Fdelete,6               ;
.fdck	cmp.w	#4,d4                   ; Check that the descriptor is a file
	blt	.fdnok                  ;
	bra	.tstok                  ;
.fdnok	print	.wrval                  ;
	bra	.tsterr                 ;

.adcrea	tst.l	d4                      ; Check if ok
	bne	.ndcrea                 ;
	move.l	(a5)+,a0                ; Create directory
	pea	(a0)                    ;
	gemdos	Dcreate,6               ;
.ndcrea	bra	.achkd0                 ;

.afcrea	tst.l	d4                      ; Check if ok
	bne	.nfcrea                 ;
	move.l	(a5)+,a0                ; Create normal file
	clr.w	-(sp)                   ;
	pea	(a0)                    ;
	gemdos	Fcreate,8               ;
.nfcrea	bra	.achkd0                 ;

.achkd0	tst.l	d4                      ; Check for d0 >= 0
	bmi	.d0nok                  ;
	bra	.tstok                  ;
.d0nok	print	.expct                  ;
	print	.positv                 ;
	print	.got                    ;
	move.l	d4,d0                   ;
	bsr	tui.phlong              ;
	crlf	                        ;
	bra	.tsterr                 ;

.create	link	a6,#0                   ; Simple way to free stack

	bsr	.clean                  ; Cleanup before starting

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv                 ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath                ;

	pea	.topdir                 ; Create directories
	gemdos	Dcreate                 ;
	pea	.fuldir                 ;
	gemdos	Dcreate                 ;
	pea	.subdir                 ;
	gemdos	Dcreate                 ;

	clr.w	-(sp)                   ; Create files
	pea	.filerw                 ;
	gemdos	Fcreate                 ;
	clr.w	-(sp)                   ;
	pea	.filena                 ;
	gemdos	Fcreate                 ;
	clr.w	-(sp)                   ;
	pea	.filero                 ;
	gemdos	Fcreate                 ;

	clr.w	-(sp)                   ; Set file attributes
	move.w	#1,-(sp)                ;
	pea	.filena                 ;
	gemdos	Fattrib                 ;
	move.w	#1,-(sp)                ;
	move.w	#1,-(sp)                ;
	pea	.filero                 ;
	gemdos	Fattrib                 ;

	unlk	a6                      ; Free all calls at once

	rts

.clean	link	a6,#0                   ;

	move.w	drive,-(sp)             ; Switch to test drive
	gemdos	Dsetdrv                 ;

	pea	.root                   ; Dsetpath '\'
	gemdos	Dsetpath                ;
	
	clr.w	-(sp)                   ; Disable read-only flag
	move.w	#1,-(sp)                ;
	pea	.filero                 ;
	gemdos	Fattrib                 ;

	pea	.filero                 ; Delete files
	gemdos	Fdelete                 ;
	pea	.filena                 ;
	gemdos	Fdelete                 ;
	pea	.filerw                 ;
	gemdos	Fdelete                 ;

	pea	.subdir                 ; Delete directories
	gemdos	Ddelete                 ;
	pea	.fuldir                 ;
	gemdos	Ddelete                 ;
	pea	.topdir                 ;
	gemdos	Ddelete                 ;

	cmp.l	#EACCDN,d0              ; Check if the directory is clean
	beq	abort                   ; Abort if not

	unlk	a6                      ; Free all calls at once

	rts


	; Sample test matrix

;.name_:
;	dc.b	'',0
;	even
;
;.do_:
;
;	rts
;
;.mx_:
;	dc.l	ALOGD0,.root
;	dc.l	ALOGD0,.topdir
;	dc.l	ALOGD0,.fuldir
;	dc.l	ALOGD0,.subdir
;	dc.l	ALOGD0,absdir
;	dc.l	ALOGD0,absfile
;	dc.l	ALOGD0,.filerw
;	dc.l	ALOGD0,.filena
;	dc.l	ALOGD0,.filero
;
;	dc.l	ALOGD0,.fulrel
;	dc.l	ALOGD0,.subrel
;	dc.l	ALOGD0,.filrel
;	dc.l	ALOGD0,.empty
;	dc.l	ALOGD0,.dot
;	dc.l	ALOGD0,.dotdot
;	dc.l	ALOGD0,.dotslh
;	dc.l	ALOGD0,.ddtslh
;	dc.l	ALOGD0,.dirslh
;	dc.l	ALOGD0,absdslh
;	dc.l	ALOGD0,.filslh
;	dc.l	ALOGD0,.pthfrw
;	dc.l	ALOGD0,.pthfro
;	dc.l	ALOGD0,.pthne
;	dc.l	ALOGD0,.filne
;	dc.l	ALOGD0,absne
;	dc.l	ALOGD0,absnes
;	dc.l	ALOGD0,.invdrv
;	dc.l	ALOGD0,.dirptn
;	dc.l	ALOGD0,.filptn
;	dc.l	ALOGD0,.nfilpt
;
;	dc.l	AEND,0

.name_dcreate:
	dc.b	'Dcreate',0
	even

.do_dcreate:
	pea	(a3)
	gemdos	Dcreate,6
	rts

.mx_dcreate:
	dc.l	EPTHNF,.root
	dc.l	EACCDN,.topdir
	dc.l	EACCDN,.fuldir
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
	dc.l	EACCDN,absfile
	dc.l	EACCDN,.filerw
	dc.l	EACCDN,.filena
	dc.l	EACCDN,.filero

	dc.l	EACCDN,.fulrel
	dc.l	EACCDN,.subrel
	dc.l	EACCDN,.filrel
	dc.l	EPTHNF,.empty
	dc.l	EPTHNF,.dot
	dc.l	EPTHNF,.dotdot
	dc.l	EPTHNF,.dotslh
	dc.l	EPTHNF,.ddtslh
	dc.l	EPTHNF,.dirslh
	dc.l	EPTHNF,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	ADDELE,.filne
	dc.l	ADDELE,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
	dc.l	EACCDN,.filptn
;	dc.l	$00000000,.nfilpt       ; Disabled: produces an invalid name

	dc.l	AEND,0

.name_ddelete:
	dc.b	'Ddelete',0
	even

.do_ddelete:
	pea	(a3)
	gemdos	Ddelete,6
	rts

.mx_ddelete:
;	dc.l	ALOGD0,.root            ; Disabled: crashes TOS on floppy
	dc.l	EACCDN,.topdir
	dc.l	EACCDN,.fuldir
	dc.l	ADCREA,.subdir,.subdir
	dc.l	EACCDN,absdir
	dc.l	EPTHNF,absfile
	dc.l	EPTHNF,.filerw
	dc.l	EPTHNF,.filena
	dc.l	EPTHNF,.filero

	dc.l	EACCDN,.fulrel
	dc.l	ADCREA,.subrel,.subdir
	dc.l	EPTHNF,.filrel
	dc.l	EACCDN,.empty
	dc.l	EACCDN,.dot
;	dc.l	ALOGD0,.dotdot          ; Disabled: crashes TOS on floppy
	dc.l	EACCDN,.dotslh
;	dc.l	ALOGD0,.ddtslh          ; Disabled: crashes TOS on floppy
	dc.l	ADCREA,.dirslh,.subdir
	dc.l	EACCDN,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	EPTHNF,.filne
	dc.l	EPTHNF,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
	dc.l	EPTHNF,.filptn
	dc.l	EPTHNF,.nfilpt

	dc.l	AEND,0

.name_dsetpath:
	dc.b	'Dsetpath',0
	even

.do_dsetpath:
	pea	(a3)
	gemdos	Dsetpath,6
	rts

.mx_dsetpath:
	dc.l	$00000000,.root
	dc.l	$00000000,.topdir
	dc.l	$00000000,.fuldir
	dc.l	$00000000,.subdir
	dc.l	$00000000,absdir
	dc.l	EPTHNF,absfile
	dc.l	EPTHNF,.filerw
	dc.l	EPTHNF,.filena
	dc.l	EPTHNF,.filero

	dc.l	$00000000,.fulrel
	dc.l	$00000000,.subrel
	dc.l	EPTHNF,.filrel
	dc.l	$00000000,.empty
	dc.l	$00000000,.dot
	dc.l	$00000000,.dotdot
	dc.l	$00000000,.dotslh
	dc.l	$00000000,.ddtslh
	dc.l	$00000000,.dirslh
	dc.l	$00000000,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	EPTHNF,.filne
	dc.l	EPTHNF,absne
	dc.l	EPTHNF,absnes
	dc.l	$00000000,.invdrv
	dc.l	EPTHNF,.dirptn
	dc.l	EPTHNF,.filptn
	dc.l	EPTHNF,.nfilpt

	dc.l	AEND,0

.name_fattrib_get:
	dc.b	'Fattrib (get)',0
	even

.do_fattrib_get:
	clr.w	-(sp)
	clr.w	-(sp)
	pea	(a3)
	gemdos	Fattrib,10
	rts

.mx_fattrib_get:
	dc.l	EFILNF,.root
	dc.l	EFILNF,.topdir
	dc.l	EFILNF,.fuldir
	dc.l	EFILNF,.subdir
	dc.l	EFILNF,absdir
	dc.l	$00000020,absfile
	dc.l	$00000020,.filerw
	dc.l	$00000000,.filena
	dc.l	$00000001,.filero

	dc.l	EFILNF,.fulrel
	dc.l	EFILNF,.subrel
	dc.l	$00000020,.filrel
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EFILNF,.filslh
	dc.l	EFILNF,.pthfrw
	dc.l	EFILNF,.pthfro
	dc.l	EFILNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EFILNF,absnes
	dc.l	EFILNF,.invdrv
	dc.l	EFILNF,.dirptn
	dc.l	$00000020,.filptn       ; Points at FILE.RW
	dc.l	EFILNF,.nfilpt

	dc.l	AEND,0

.name_fattrib_set:
	dc.b	'Fattrib (set)',0
	even

.do_fattrib_set:
	move.w	#$0020,-(sp)
	move.w	#1,-(sp)
	pea	(a3)
	gemdos	Fattrib,10
	rts

.mx_fattrib_set:
	dc.l	EFILNF,.root
	dc.l	EFILNF,.topdir
	dc.l	EFILNF,.fuldir
	dc.l	EFILNF,.subdir
	dc.l	EFILNF,absdir
	dc.l	$00000020,absfile
	dc.l	$00000020,.filerw
;	dc.l	$00000020,.filena       ; Disabled: would clobber attribute
;	dc.l	$00000020,.filero       ; Disabled: would clobber attribute

	dc.l	EFILNF,.fulrel
	dc.l	EFILNF,.subrel
	dc.l	$00000020,.filrel
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EFILNF,.filslh
	dc.l	EFILNF,.pthfrw
	dc.l	EFILNF,.pthfro
	dc.l	EFILNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EFILNF,absnes
	dc.l	EFILNF,.invdrv
	dc.l	EFILNF,.dirptn
	dc.l	$00000020,.filptn
	dc.l	EFILNF,.nfilpt


	dc.l	AEND,0

.name_fcreate:
	dc.b	'Fcreate',0
	even

.do_fcreate:
	clr.w	-(sp)
	pea	(a3)
	gemdos	Fcreate,8
	rts

.mx_fcreate:
	dc.l	EPTHNF,.root
	dc.l	EACCDN,.topdir
	dc.l	EACCDN,.fuldir
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
	dc.l	ACLOSE,absfile
	dc.l	ACLOSE,.filerw
	dc.l	ACLOSE,.filena
	dc.l	EACCDN,.filero

	dc.l	EACCDN,.fulrel
	dc.l	EACCDN,.subrel
	dc.l	ACLOSE,.filrel
	dc.l	EPTHNF,.empty
	dc.l	EPTHNF,.dot
	dc.l	EPTHNF,.dotdot
	dc.l	EPTHNF,.dotslh
	dc.l	EPTHNF,.ddtslh
	dc.l	EPTHNF,.dirslh
	dc.l	EPTHNF,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	ACLDEL,.filne
	dc.l	ACLDEL,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
;	dc.l	ACLOSE,.filptn          ; Disabled: Renames FILE.RW to FILE.???
;	dc.l	ACLDEL,.nfilpt          ; Disabled: produces an invalid name

	dc.l	AEND,0

.name_fopen_ro:
	dc.b	'Fopen (ro)',0
	even

.do_fopen_ro:
	clr.w	-(sp)
	pea	(a3)
	gemdos	Fopen,8
	rts

.mx_fopen_r:
	dc.l	EFILNF,.root
	dc.l	EFILNF,.topdir
	dc.l	EFILNF,.fuldir
	dc.l	EFILNF,.subdir
	dc.l	EFILNF,absdir
	dc.l	ACLOSE,absfile
	dc.l	ACLOSE,.filerw
	dc.l	ACLOSE,.filena
	dc.l	ACLOSE,.filero

	dc.l	EFILNF,.fulrel
	dc.l	EFILNF,.subrel
	dc.l	ACLOSE,.filrel
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EFILNF,.filslh
	dc.l	EFILNF,.pthfrw
	dc.l	EFILNF,.pthfro
	dc.l	EFILNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EFILNF,absnes
	dc.l	EFILNF,.invdrv
	dc.l	EFILNF,.dirptn
	dc.l	ACLOSE,.filptn          ; Opens the first matching file
	dc.l	EFILNF,.nfilpt


	dc.l	AEND,0

.name_fopen_wo:
	dc.b	'Fopen (wo)',0
	even

.do_fopen_wo:
	move.w	#1,-(sp)
	pea	(a3)
	gemdos	Fopen,8
	rts

.name_fopen_rw:
	dc.b	'Fopen (rw)',0
	even

.do_fopen_rw:
	move.w	#2,-(sp)
	pea	(a3)
	gemdos	Fopen,8
	rts

.mx_fopen_w:	; Same matrix for Fopen wo and rw
	dc.l	EFILNF,.root
	dc.l	EFILNF,.topdir
	dc.l	EFILNF,.fuldir
	dc.l	EFILNF,.subdir
	dc.l	EFILNF,absdir
	dc.l	ACLOSE,absfile
	dc.l	ACLOSE,.filerw
	dc.l	ACLOSE,.filena
	dc.l	EACCDN,.filero

	dc.l	EFILNF,.fulrel
	dc.l	EFILNF,.subrel
	dc.l	ACLOSE,.filrel
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EFILNF,.filslh
	dc.l	EFILNF,.pthfrw
	dc.l	EFILNF,.pthfro
	dc.l	EFILNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EFILNF,absnes
	dc.l	EFILNF,.invdrv
	dc.l	EFILNF,.dirptn
	dc.l	ACLOSE,.filptn
	dc.l	EFILNF,.nfilpt


	dc.l	AEND,0

.name_fdelete:
	dc.b	'Fdelete',0
	even

.do_fdelete:
	pea	(a3)
	gemdos	Fdelete,6
	rts

.mx_fdelete:
	dc.l	EFILNF,.root
	dc.l	EFILNF,.topdir
	dc.l	EFILNF,.fuldir
	dc.l	EFILNF,.subdir
	dc.l	EFILNF,absdir
	dc.l	AFCREA,absfile,.filerw
	dc.l	AFCREA,.filerw,.filerw
;	dc.l	AFCREA,.filena          ; Disabled: would clobber attributes
	dc.l	EACCDN,.filero

	dc.l	EFILNF,.fulrel
	dc.l	EFILNF,.subrel
	dc.l	AFCREA,.filrel,.filerw
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EFILNF,.filslh
	dc.l	EFILNF,.pthfrw
	dc.l	EFILNF,.pthfro
	dc.l	EFILNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EFILNF,absnes
	dc.l	EFILNF,.invdrv
	dc.l	EFILNF,.dirptn
	dc.l	AFCREA,.filptn,.filerw
	dc.l	EFILNF,.nfilpt


	dc.l	AEND,0

.name_frename_to_path:
	dc.b	'Frename (to path)',0
	even

.do_frename_to_path:
	pea	.frename_to_path
	pea	(a3)
	clr.w	-(sp)
	gemdos	Frename,12
	rts

.frename_to_path:
	dc.b	'\TOSTEST.TMP\FRENAME.TGT',0
	even

.mx_frename_to_path:
	; Note: only failing functions are tested to avoid messing test files
	dc.l	EFILNF,.root
	dc.l	EACCDN,.topdir
;	dc.l	$00000000,.fuldir       ; Disabled
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
;	dc.l	$00000000,absfile       ; Disabled
;	dc.l	$00000000,.filerw       ; Disabled
;	dc.l	$00000000,.filena       ; Disabled
	dc.l	EACCDN,.filero

;	dc.l	$00000000,.fulrel       ; Disabled
	dc.l	EACCDN,.subrel
;	dc.l	$00000000,.filrel       ; Disabled
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
;	dc.l	$00000000,.filptn       ; Disabled
	dc.l	EFILNF,.nfilpt

	dc.l	AEND,0

.name_frename_to_name:
	dc.b	'Frename (to name)',0
	even

.do_frename_to_name:
	pea	.frename_to_name
	pea	(a3)
	clr.w	-(sp)
	gemdos	Frename,12
	rts

.frename_to_name:
	dc.b	'FRENAME.TGT',0
	even

.mx_frename_to_name:
	; Note: only failing functions are tested to avoid messing test files
	dc.l	EFILNF,.root
	dc.l	EACCDN,.topdir
;	dc.l	$00000000,.fuldir       ; Disabled
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
;	dc.l	$00000000,absfile       ; Disabled
;	dc.l	$00000000,.filerw       ; Disabled
;	dc.l	$00000000,.filena       ; Disabled
	dc.l	EACCDN,.filero

;	dc.l	$00000000,.fulrel       ; Disabled
	dc.l	EACCDN,.subrel
;	dc.l	$00000000,.filrel       ; Disabled
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
;	dc.l	$00000000,.filptn       ; Disabled
	dc.l	EFILNF,.nfilpt

	dc.l	AEND,0

.name_frename_from_file:
	dc.b	'Frename (from file)',0
	even

.do_frename_from_file:
	pea	(a3)
	pea	.frename_from_file
	clr.w	-(sp)
	gemdos	Frename,12
	rts

.frename_from_file:
	dc.b	'\TOSTEST.TMP\FILE.RW',0
	even

.mx_frename_from_file:
	; Note: only failing functions are tested to avoid messing test files
	dc.l	EBADRQ,.root
	dc.l	EACCDN,.topdir
	dc.l	EACCDN,.fuldir
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
	dc.l	EACCDN,absfile
	dc.l	EACCDN,.filerw
	dc.l	EACCDN,.filena
	dc.l	EACCDN,.filero

	dc.l	EACCDN,.fulrel
	dc.l	EACCDN,.subrel
	dc.l	EACCDN,.filrel
	dc.l	EBADRQ,.empty
;	dc.l	$00000000,.dot          ; Disabled: TOS creates a null filename
;	dc.l	$00000000,.dotdot       ; Disabled: TOS creates a null filename
	dc.l	EBADRQ,.dotslh
	dc.l	EBADRQ,.ddtslh
	dc.l	EBADRQ,.dirslh
	dc.l	EBADRQ,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
;	dc.l	$00000000,.filne        ; Disabled
;	dc.l	$00000000,absne         ; Disabled
	dc.l	EPTHNF,absnes
;	dc.l	EPTHNF,.invdrv          ; Disabled: GemDrive returns ENSAME
	dc.l	EPTHNF,.dirptn
	dc.l	EACCDN,.filptn
;	dc.l	$00000000,.nfilpt       ; Disabled: creates an invalid name

	dc.l	AEND,0

.name_frename_from_dir:
	dc.b	'Frename (from directory)',0
	even

.do_frename_from_dir:
	pea	.frename_from_dir
	pea	(a3)
	clr.w	-(sp)
	gemdos	Frename,12
	rts

.frename_from_dir:
	dc.b	'\TOSTEST.TMP\FULDIR',0
	even

.mx_frename_from_dir:
	; Note: only failing functions are tested to avoid messing test files
	dc.l	EFILNF,.root
	dc.l	EACCDN,.topdir
	dc.l	EACCDN,.fuldir
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
	dc.l	EACCDN,absfile
	dc.l	EACCDN,.filerw
	dc.l	EACCDN,.filena
	dc.l	EACCDN,.filero

	dc.l	EACCDN,.fulrel
	dc.l	EACCDN,.subrel
	dc.l	EACCDN,.filrel
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
	dc.l	EACCDN,.filptn
	dc.l	EFILNF,.nfilpt

	dc.l	AEND,0

.name_frename_from_subdir:
	dc.b	'Frename (from subdirectory)',0
	even

.do_frename_from_subdir:
	pea	.frename_from_subdir
	pea	(a3)
	clr.w	-(sp)
	gemdos	Frename,12
	rts

.frename_from_subdir:
	dc.b	'\TOSTEST.TMP\FULDIR\SUBDIR',0
	even

.mx_frename_from_subdir:
	; Note: only failing functions are tested to avoid messing test files
	dc.l	EFILNF,.root
	dc.l	EACCDN,.topdir
	dc.l	EACCDN,.fuldir
	dc.l	EACCDN,.subdir
	dc.l	EACCDN,absdir
	dc.l	EACCDN,absfile
	dc.l	EACCDN,.filerw
	dc.l	EACCDN,.filena
	dc.l	EACCDN,.filero

	dc.l	EACCDN,.fulrel
	dc.l	EACCDN,.subrel
	dc.l	EACCDN,.filrel
	dc.l	EFILNF,.empty
	dc.l	EFILNF,.dot
	dc.l	EFILNF,.dotdot
	dc.l	EFILNF,.dotslh
	dc.l	EFILNF,.ddtslh
	dc.l	EFILNF,.dirslh
	dc.l	EFILNF,absdslh
	dc.l	EPTHNF,.filslh
	dc.l	EPTHNF,.pthfrw
	dc.l	EPTHNF,.pthfro
	dc.l	EPTHNF,.pthne
	dc.l	EFILNF,.filne
	dc.l	EFILNF,absne
	dc.l	EPTHNF,absnes
	dc.l	EPTHNF,.invdrv
	dc.l	EPTHNF,.dirptn
	dc.l	EACCDN,.filptn
	dc.l	EFILNF,.nfilpt

	dc.l	AEND,0

.matrices
	dc.l	.name_dcreate,.do_dcreate,.mx_dcreate
	dc.l	.name_ddelete,.do_ddelete,.mx_ddelete
	dc.l	.name_dsetpath,.do_dsetpath,.mx_dsetpath
	dc.l	.name_fattrib_get,.do_fattrib_get,.mx_fattrib_get
	dc.l	.name_fattrib_set,.do_fattrib_set,.mx_fattrib_set
	dc.l	.name_fcreate,.do_fcreate,.mx_fcreate
	dc.l	.name_fopen_ro,.do_fopen_ro,.mx_fopen_r
	dc.l	.name_fopen_wo,.do_fopen_wo,.mx_fopen_w
	dc.l	.name_fopen_rw,.do_fopen_rw,.mx_fopen_w
	dc.l	.name_fdelete,.do_fdelete,.mx_fdelete
	dc.l	.name_frename_to_path,.do_frename_to_path,.mx_frename_to_path
	dc.l	.name_frename_to_name,.do_frename_to_name,.mx_frename_to_name

	dc.l	.name_frename_from_file
	dc.l	.do_frename_from_file
	dc.l	.mx_frename_from_file

	dc.l	.name_frename_from_dir,.do_frename_from_dir,.mx_frename_from_dir

	dc.l	.name_frename_from_subdir
	dc.l	.do_frename_from_subdir
	dc.l	.mx_frename_from_subdir

	dc.l	0,0

.desc	dc.b	'Error code test matrix',$0d,$0a
	dc.b	0

.testmx	dc.b	$0d,$0a
	dc.b	'Test error codes for ',0
.wpath	dc.b	'Path=',0
.expct	dc.b	'Expected:',0
.positv	dc.b	'positive',0
.got	dc.b	' got:',0
.wrval	dc.b	'Wrong return value',$0d,$0a
	dc.b	0

	; Directories and files
.root	dc.b	'\',0
.topdir	dc.b	'\TOSTEST.TMP',0
.fuldir	dc.b	'\TOSTEST.TMP\FULDIR',0
.subdir	dc.b	'\TOSTEST.TMP\FULDIR\SUBDIR',0
.filerw	dc.b	'\TOSTEST.TMP\FILE.RW',0
.filena	dc.b	'\TOSTEST.TMP\FILE.NA',0
.filero	dc.b	'\TOSTEST.TMP\FILE.RO',0

	; Non-existing and problematic paths
.fulrel	dc.b	'FULDIR',0
.subrel	dc.b	'FULDIR\SUBDIR',0
.filrel	dc.b	'FILE.RW',0
.empty	dc.b	0
.dot	dc.b	'.',0
.dotdot	dc.b	'..',0
.dotslh	dc.b	'.\',0
.ddtslh	dc.b	'..\',0
.dirslh	dc.b	'\TOSTEST.TMP\FULDIR\SUBDIR\',0
.filslh	dc.b	'\TOSTEST.TMP\FILE.RW\',0
.pthfrw	dc.b	'\TOSTEST.TMP\FILE.RW\NONFILE',0
.pthfro	dc.b	'\TOSTEST.TMP\FILE.RO\NONFILE',0
.pthne	dc.b	'\TOSTEST.TMP\NOTEXIST.ING\NONFILE',0
.filne	dc.b	'\TOSTEST.TMP\NONFILE',0
.invdrv	dc.b	'I:\TOSTEST.TMP',0
.dirptn	dc.b	'\TOSTEST.TMP\F*.*\SUBDIR',0
.filptn	dc.b	'\TOSTEST.TMP\FILE.*',0
.nfilpt	dc.b	'\TOSTEST.TMP\NONFILE.*',0

	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
