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

; Hooks TOS system calls into the STM32

; DMA port hardware registers
dma	equ	$ffff8604
dmadata	equ	dma
dmactrl	equ	dma+2
dmahigh	equ	dma+5
dmamid	equ	dma+7
dmalow	equ	dma+9
gpip	equ	$fffffa01

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

	bra.b	syshook.init

	dc.b	0                       ; Patched-in variables
acsiid	dc.b	$ff                     ; Invalid values to check for correct
prmoff	dc.w	$ff                     ; patching code in the STM32

syshook.init:
	savereg	                        ; Save registers
	move.b	d7,d0                   ; Send a command with the correct id
	bra.w	syshook.sendcmd

syshook.setprm:
	; Point a2 at the parameters of the initial call
	; The supervisor stack must point at the trap stack frame
	; Alters d2 and a2 only
	btst	#5,8+spoff(sp)          ; Check if supervisor mode
	beq.b	.usp                    ; Branch if user mode

	move.w	prmoff(pc),d2           ; Fetch parameter offset
	lea	8+spoff(sp,d2),a2       ; Compute pointer to call parameters
	rts

.usp	move	usp,a2                  ; Point at USP directly
	rts


syshook	macro
	; \1 = one-byte ACSI command
	; \2 = trap address

\@.syshook.header:
	dc.l	'XBRA'
	dc.l	'A2ST'
\@.syshook.old:
	dc.l	\2
\@.syshook:
	move.l	\@.syshook.old(pc),-(sp); Push old vector
	tst.b	flock.w                 ;
	beq.b	\@.syshook.exec         ;
	rts	                        ; Reentrant call: forward the call
\@.syshook.exec:
	moveq	#\1,d0                  ; Set one byte command

	endm

	; XBIOS hook
	syshook	$10,$b8
	bra.b	syshook.start

	; BIOS hook
	syshook	$0f,$b4
	bra.b	syshook.start

	; GEMDOS hook
	syshook	$0e,$84
	; Fall through syshook.start

syshook.start:
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

syshook.sendcmd:
	or.b	acsiid(pc),d0           ; Set ACSI identifier

	st	flock.w                 ; Lock floppy controller
	bsr.w	syshook.setdmaaddr      ; Set DMA address on chip

	move.l	#$00ff0188,(a0)         ; Send 255 blocks. Switch to command.
	move.l	#$01000000,d1           ;
	move.b	d0,d1                   ;
	swap	d1                      ; d1 = 00cc0100
	move.l	d1,(a0)                 ; Send command to the STM32

syshook.reply:
	; Handle single byte reply

.await	btst.b	#5,gpip.w               ; Wait for acknowledge on IRQ
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Prepare to read command/status
	move.w	(a0),d0                 ; Read command/status byte

	cmp.b	#$8b,d0                 ; Check if command byte
	beq.b	syshook.forward         ; Check command $8b (forward to TOS)
	blt.b	syshook.execcmd         ; Other commands with parameter

.qret	ext.w	d0                      ; Quick return sign-extended d0
	ext.l	d0                      ;

	; Fall through syshook.return
syshook.return:
	; Return from interrupt
	bsr.b	syshook.onexit          ; Release hardware
	resreg	                        ; Restore registers
	addq	#4,sp                   ; Pop forward address
	rte	                        ; Return

syshook.forward:
	; Command $8b: forward the call to the next handler
	bsr.b	syshook.onexit          ; Release hardware
	resreg	                        ; Restore registers
	rts	                        ; Jump to forwarding address

syshook.onexit:
	move.w	#$0190,dmactrl.w        ; Reset DMA controller
	move.l	#$0000008a,dma.w        ;
	sf	flock.w                 ; Unlock floppy controller
	rts

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
	and.w	#$000e,d2               ; Filter out comand pair
	move.w	.jmptbl(pc,d2.w),d2     ;
.jmp	jmp	.jmptbl(pc,d2.w)        ;
.jmptbl	dc.w	syshook.byteop-.jmptbl  ; $80
	dc.w	syshook.dmaset-.jmptbl  ; $82
	dc.w	syshook.exec-.jmptbl    ; $84
	dc.w	syshook.pexec6-.jmptbl  ; $86
	dc.w	syshook.pexec4-.jmptbl  ; $88
	dc.w	syshook.rte-.jmptbl     ; $8a

syshook.rte
	; Command $8c: Return long from exception
	move.l	d1,d0                   ; Put parameter in d0
	bra.b	syshook.return          ; Return from exception

syshook.pexec4:
	; Command $86: Pexec4 and rte
	moveq	#4,d0
	bra.b	syshook.pexec

syshook.pexec6:
	; Command $86: Pexec6 and rte
	moveq	#6,d0

	; Fall through syshook.pexec

syshook.pexec:
	bsr.b	syshook.onexit          ; Release hardware

	; Patch the current Pexec call, then forward
	bsr.w	syshook.setprm          ; Point at Pexec parameters

	addq	#2,a2                   ; Skip Pexec opcode
	move.w	d0,(a2)+                ; Pexec.mode (set to 4 or 6)
	clr.l	(a2)+                   ; Pexec.z1
	move.l	d1,(a2)+                ; Pexec.basepage
	clr.l	(a2)+                   ; Pexec.z2

	resreg	                        ; Restore registers
	rts	                        ; Forward to GEMDOS

syshook.exec:
	; Commands $85/$84: Machine code execute
	lea	.code(pc),a0            ; Modify code to execute
	move.l	d1,(a0)                 ;
	move.w	d0,syshook.oldd0-.code(a0); Store d0 for later without altering
		                        ; the stack

.code	nop	                        ; This code will be self-modified
	nop	                        ;

	move.w	syshook.oldd0(pc),d0    ; Restore d0
	move.l	sp,d1                   ; Set stack pointer as DMA address

	; Commands $83/$82: DMA setup
syshook.dmaset:
	move.l	d1,a2                   ; Set parameter as DMA address
	btst	#0,d0                   ; Check if DMA is read or write
	beq.b	syshook.wcmd            ; DMA write

syshook.rcmd:
	; Continue the command stream in DMA read mode
	; This sends a command byte $00 to signal the STM32 that we are ready.
	bsr.b	syshook.setdmaaddr      ; Set DMA address to a2

	move.w	#$0090,(a1)             ; Set block count
	move.w	#$00ff,(a0)             ; Send 255 blocks
	move.w	#$008a,(a1)             ; Switch to command
	clr.w	(a0)                    ; Send zero command byte
	clr.w	(a1)                    ; Enable DMA

	bra.w	syshook.reply

syshook.byteop:
	; Commands $81/$80: Byte copy operations
	move.l	sp,a1                   ; Use a1 to leave sp untouched
	move.w	(a1)+,d2                ; Pop byte count and point a1 at data
	move.l	a1,a2                   ; Set DMA on stack data
	move.l	d1,a0                   ; Memory address

	btst	#0,d0                   ; Check if read or write
	beq.b	syshook.byteread        ;

	; Command $81: Copy from stack to memory

.cpy    move.b	(a1)+,(a0)+             ; Byte copy from stack to memory
	dbra	d2,.cpy                 ;

	bra.b	syshook.rcmd

syshook.byteread:
	; Command $80: Copy from memory to stack

.cpy    move.b	(a0)+,(a1)+             ; Byte copy from memory to stack
	dbra	d2,.cpy                 ;

	; Fall through syshook.wcmd

syshook.wcmd:
	; Continue the command stream in DMA write mode
	; This sends a command byte $88 to signal the STM32 that we are ready.
	bsr.b	syshook.setdmaaddr      ; Set DMA address to a2

	move.w	#$00ff,(a0)             ; Send 255 blocks
	move.w	#$018a,(a1)             ; Switch to command
	move.w	#$0088,(a0)             ; Send $88 command byte
	move.w	#$0100,(a1)             ; Enable DMA

	bra.w	syshook.reply

syshook.setdmaaddr:
	; Set DMA address and size
	; Input:
	;  a2: DMA address to set

	movem.w	syshook.dmareg(pc),a0-a1; Set DMA controller registers

	move.w	#$0090,(a1)             ; Reset DMA pipeline
	move.w	#$0190,(a1)             ;

	move.l	a2,d1                   ; Set DMA address
	move.b	d1,dmalow.w             ;
	lsr.l	#8,d1                   ;
	move.b	d1,dmamid.w             ;
	lsr.l	#8,d1                   ;
	move.b	d1,dmahigh.w            ;

	rts

; Variables
syshook.dmareg	dc.w	dmadata,dmactrl ; DMA port addresses
syshook.oldd0	ds.w	0               ; Temporary storage for d0
	

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm68k tw=80
