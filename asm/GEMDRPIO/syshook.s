; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2024 by Jean-Matthieu Coulon

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

; Hooks TOS system calls into the STM32
; This is the PIO version: it doesn't use DMA transfers at all

savereg	macro
	; Save registers on stack
	; ... because some poorly written apps rely on scratch register being
	; preserved !
	movem.l	d1-d2/a0-a2,-(sp)
	endm

resreg	macro
	; Restore registers from stack
	movem.l	(sp)+,d1-d2/a0-a2
	endm

	; Stack offset introduced by savereg
spoff	equ	5*4

syshook.init:
	savereg	                        ; Save registers
	moveq	#0,d0                   ; Send zero command
	bra.w	syshook.sendcmd

syshook.setprm:
	; Point a2 at the parameters of the initial call
	; The supervisor stack must point at the trap stack frame
	; Alters d2 and a2 only
	btst	#5,8+spoff(sp)          ; Check if supervisor mode
	beq.b	.usp                    ; Branch if user mode

	move.w	prmoff(pc),d2           ; Fetch parameter offset
	lea	8+spoff(sp,d2.w),a2     ; Compute pointer to call parameters
	rts

.usp	move	usp,a2                  ; Point at USP directly
	rts

	; GEMDOS hook

syshook.header:
	dc.l	'XBRA'                  ; XBRA marker
	dc.l	'A2ST'                  ;
syshook.old:
	dc.l	$00000084               ; Put vector address in old vector
syshook:
	move.l	syshook.old(pc),-(sp)   ; Push old vector
	tst.b	flock.w                 ;
	beq.b	syshook.exec            ;
	rts	                        ; Reentrant call: forward the call
syshook.exec:
	moveq	#$0e,d0                 ; Set one byte command

	; Initialize registers for hook subroutines
	; Input:
	;  d0.b: Command byte
	;  a1: forwarding address
	;  syshook.acsiid: ACSI Device ID
	;  syshook.prmoff: Offset to a6 to find params (platform dependent)
	; Output:
	;  d0.b: Command byte with ACSI ID
	;  a0: DMA controller command port
	;  a1: DMA controller status port
	;  a2: Pointer to parameters

	savereg	                        ; Save registers
	bsr.b	syshook.setprm          ; Set a2 (DMA address) at the parameters

	cmp.w	#$0020,(a2)             ; Don't hook Super because it breaks
	beq.b	syshook.forward         ; some programs such as ICDFMT.PRG

syshook.sendcmd:
	or.b	acsiid(pc),d0           ; Set ACSI identifier

	st	flock.w                 ; Lock floppy controller
	bsr.w	syshook.setdmaaddr      ; Set DMA address on chip

	move.w	#$0088,(a1)             ; Enable CS+A1 byte transfer
	move.w	d0,(a0)                 ; Send command byte to the STM32

syshook.reply:
	; Handle single byte reply

.await	btst.b	#5,gpip.w               ; Wait for acknowledge on IRQ
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Prepare to read command/status
	move.w	(a0),d0                 ; Read command/status byte

	cmp.b	#$9a,d0                 ; Check if command byte
	beq.b	syshook.forward         ; Check command $9a (forward to TOS)
	blt.b	syshook.execcmd         ; Other commands with parameter

.qret	ext.w	d0                      ; Quick return sign-extended d0
	ext.l	d0                      ;

	; Fall through syshook.return
syshook.return:
	; Return from interrupt
	sf	flock.w                 ; Unlock floppy controller
	resreg	                        ; Restore registers
	addq	#4,sp                   ; Pop forward address
	rte	                        ; Return

syshook.forward:
	; Command $98: forward the call to the next handler
	sf	flock.w                 ; Unlock floppy controller
	resreg	                        ; Restore registers
	rts	                        ; Jump to forwarding address

syshook.execcmd:
	; Received a command in d0

	; Read parameter (4 bytes) into d1
	swap	d0                      ; Save command byte into upper d0
	moveq	#3,d2                   ; Repeat 4 times
.rdbyte	move.w	(a0),d0                 ; Fast byte read (no ack)
	lsl.l	#8,d1                   ;
	move.b	d0,d1                   ;
	dbra	d2,.rdbyte              ;
	swap	d0                      ; Restore command byte

	; Route the call using a jump table
	move.b	d0,d2                   ; Jump table for command byte
	and.w	#$007e,d2               ; Filter out comand pair
	move.w	.jmptbl(pc,d2.w),d2     ;
.jmp	jmp	.jmptbl(pc,d2.w)        ;
.jmptbl	dc.w	syshook.rte-.jmptbl     ; $80
	dc.w	syshook.bytecp-.jmptbl  ; $82
	dc.w	syshook.dmaset-.jmptbl  ; $84
	dc.w	syshook.pexec6-.jmptbl  ; $86
	dc.w	syshook.pexec4-.jmptbl  ; $88
	dc.w	syshook.rdlong-.jmptbl  ; $8a
	dc.w	syshook.rdword-.jmptbl  ; $8c
	dc.w	syshook.rdbyte-.jmptbl  ; $8e
	dc.w	syshook.addsp-.jmptbl   ; $90
	dc.w	syshook.pshword-.jmptbl ; $92
	dc.w	syshook.pushsp-.jmptbl  ; $94
	dc.w	syshook.trap01-.jmptbl  ; $96
	dc.w	syshook.piocpy-.jmptbl  ; $98

syshook.rte
	; Command $80: Return long from exception
	move.l	d1,d0                   ; Put parameter in d0
	bra.b	syshook.return          ; Return from exception

syshook.pexec4:
	; Command $88: Pexec4 and rte
	moveq	#4,d0
	bra.b	syshook.pexec

syshook.pexec6:
	; Command $86: Pexec6 and rte
	moveq	#6,d0

	; Fall through syshook.pexec

syshook.pexec:
	sf	flock.w                 ; Unlock floppy controller

	; Patch the current Pexec call, then forward
	bsr.w	syshook.setprm          ; Point at Pexec parameters

	addq	#2,a2                   ; Skip Pexec opcode
	move.w	d0,(a2)+                ; Pexec.mode (set to 4 or 6)
	clr.l	(a2)+                   ; Pexec.z1
	move.l	d1,(a2)+                ; Pexec.basepage
	clr.l	(a2)+                   ; Pexec.z2

	resreg	                        ; Restore registers
	rts	                        ; Forward to GEMDOS

syshook.rdlong:
	move.l	d1,a0
	move.l	(a0),-(sp)
	bra.b	syshook.dmasp

syshook.rdword:
	move.l	d1,a0
	move.w	(a0),-(sp)
	bra.b	syshook.dmasp

syshook.rdbyte:
	move.l	d1,a0
	move.b	(a0),-(sp)
	bra.b	syshook.dmasp

syshook.addsp:
	adda.l	d1,sp
	bra.b	syshook.dmasp

syshook.pshword:
	move.w	d1,-(sp)
	bra.b	syshook.dmanset

syshook.pushsp:
	move.l	sp,-(sp)
	bra.b	syshook.dmasp

syshook.trap01:
	lea	syshook.oldd0(pc),a0
	move.l	d0,(a0)
	trap	#01
	move.l	d0,-(sp)
	move.l	syshook.oldd0(pc),d0
	bra.b	syshook.dmasp

syshook.piocpy:
	bsr.b	syshook.await           ; Wait for IRQ

	move.w	#$008a,(a1)             ; Enable CS byte transfer

	moveq	#0,d2                   ; d2 = byte buffer
	subq	#1,d1                   ; Adjust for DBRA

	btst	#0,d0                   ;
	bne.b	.piord                  ;

.wloop	move.b	(a2)+,d2                ; Do the transfer byte per byte
	move.w	d2,(a0)                 ;
	dbra	d1,.wloop               ;

	bra.w	syshook.reply           ;

.piord	move.w	(a0),d2                 ; Do the transfer byte per byte
	move.b	d2,(a2)+                ;
	dbra	d1,.piord               ;

	bra.w	syshook.reply           ;

syshook.dmasp:
	move.l	sp,d1                   ;

	; DMA setup
syshook.dmaset:
	move.l	d1,a2                   ; Set parameter as DMA address
syshook.dmanset:

	; Continue the command stream in DMA read mode
	; This sends a command byte $00 to signal the STM32 that we are ready.
	bsr.b	syshook.setdmaaddr      ; Set DMA address to a2

	move.w	#$008a,(a1)             ; Switch to command
	clr.w	(a0)                    ; Send zero command byte

	bra.w	syshook.reply

syshook.bytecp:
	; Commands $82/$83: Byte copy operations
	move.l	sp,a1                   ; Use a1 to leave sp untouched
	move.w	(a1)+,d2                ; Pop byte count and point a1 at data
	move.l	a1,a2                   ; Set DMA on stack data
	move.l	d1,a0                   ; Memory address

	btst	#0,d0                   ; Check if read or write
	beq.b	syshook.byteread        ;

	; Command $83: Copy from stack to memory

.cpy    move.b	(a1)+,(a0)+             ; Byte copy from stack to memory
	dbra	d2,.cpy                 ;

	bra.b	syshook.dmanset

syshook.byteread:
	; Command $82: Copy from memory to stack

.cpy    move.b	(a0)+,(a1)+             ; Byte copy from memory to stack
	dbra	d2,.cpy                 ;

	bra.b	syshook.dmanset

syshook.await:
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	syshook.await           ;
	rts	                        ;

syshook.setdmaaddr:
	; Set DMA address and size
	; Input:
	;  a2: DMA address to set

	movem.w	syshook.dmareg(pc),a0-a1; Set DMA controller registers

	rts

; Variables
syshook.dmareg	dc.w	dmadata,dmactrl ; DMA port addresses
syshook.oldd0	ds.l	1               ; Temporary storage for d0
	

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
