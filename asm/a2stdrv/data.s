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
; Initialized data

; ACSI commands

	even
acsi.rw		; Read-write commands
	dc.b	9                       ; 9 intermediate bytes
	dc.b	$1f,$28                 ; Read extended command
	dc.b	$00                     ; Obsolete
	dc.b	$00,$00,$00,$00         ; Block number
	dc.b	$00                     ; LUN
	dc.b	$00,$00                 ; Block count
	dc.b	$00                     ; Control byte

	even
acsi.tst	; Test unit ready
	dc.b	4
	dc.b	$00,$00,$00,$00,$00,$00	; This one is easy

	even
acsi.sns	; Request sense
	dc.b	4
	dc.b	$03,$00,$00,$00,$10,$00

	even
acsi.inq	; Inquiry
	dc.b	4
	dc.b	$12,$00,$00,$00,$20,$00

	even
acsi.cap	; Read capacity
	dc.b	9
	dc.b	$1f,$25
	dc.b	$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00

	; PUN_INFO struct
	even
pun	dc.w	0			; pun.puns
	dc.b	$ff,$ff,$ff,$ff         ; pun.pun
	dc.b	$ff,$ff,$ff,$ff         ;
	dc.b	$ff,$ff,$ff,$ff         ;
	dc.b	$ff,$ff,$ff,$ff         ;
	dc.l	0,0,0,0,0,0,0,0         ; pun.part_start
	dc.l	0,0,0,0,0,0,0,0         ;
	dc.l	'AHDI'                  ; pun.p_cookie
	dc.l	pun+pun.p_cookie        ; pun.p_cookptr
	dc.w	$0300                   ; pun.p_version
	dc.w	$0200                   ; Maximum sector size
	ds.l	16                      ; Reserved (used for sector sizes)

	; Extended pun table for drives >= 16
punext	dc.w	0			; pun.puns
	dc.b	$ff,$ff,$ff,$ff         ; pun.pun
	dc.b	$ff,$ff,$ff,$ff         ;
	dc.b	$ff,$ff,$ff,$ff         ;
	dc.b	$ff,$ff,$ff,$ff         ;
	dc.l	0,0,0,0,0,0,0,0         ; pun.part_start
	dc.l	0,0,0,0,0,0,0,0         ;
	dc.l	'AHDI'                  ; pun.p_cookie
	dc.l	punext+pun.p_cookie     ; pun.p_cookptr
	dc.w	$0300                   ; pun.p_version
	dc.w	$0200                   ; Maximum sector size
	ds.l	16                      ; Reserved (used for sector sizes)

		; Partition printout strings
		even
prtpart.txt1	dc.b	'  '
prtpart.drv	dc.b	'C: SD'
prtpart.sd	dc.b	'? ',0
prtpart.end	dc.b	'M',13,10,0

		; Masks
mchmask		dc.l	0               ; Media change mask
devmask		dc.w	0               ; Present ACSI devices mask

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
