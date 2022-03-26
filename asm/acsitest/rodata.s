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

; ACSI2STM DMA quick test
; Shared read-only data

	; Text messages

msg.header	; Welcome header text
	a2st_header
	dc.b	13,10,0
msg.nocard
	dc.b	'No SD card'
	dc.b	13,10
	dc.b	'Proceeding with tests anyway'
	dc.b	13,10,0
msg.newcard
	dc.b	'New SD card inserted'
	dc.b	13,10
	dc.b	'Proceeding with the new card'
	dc.b	13,10,0
msg.senserr
	dc.b	7
	dc.b	'Sense request error'
	dc.b	13,10,0
msg.dataerr
	dc.b	7
	dc.b	'Data integrity error'
	dc.b	13,10,0
msg.devsel
	dc.b	'Type the device id of the ACSI2STM (0-7)'
	dc.b	13,10
	dc.b	'or press Esc to quit'
	dc.b	13,10,0
msg.testing
	dc.b	13,10
	dc.b	'Testing ...'
	dc.b	13,10,0
msg.sensing
	dc.b	7
	dc.b	'Sensing error code'
	dc.b	13,10,0
msg.success
	dc.b	'Test successful !'
	dc.b	13,10,0
msg.nodev
	dc.b	'Device not responding'
	dc.b	7,13,10,0
	dc.b	13,10,0
msg.nota2st
	dc.b	7
	dc.b	'Not an ACSI2STM device'
	dc.b	13,10,0
msg.inqerr
	dc.b	'Device inquiry error'
	dc.b	13,10,0
msg.cmderr
	dc.b	7
	dc.b	'Command error'
	dc.b	13,10,0
msg.writerr
	dc.b	7
	dc.b	'DMA write error'
	dc.b	13,10,0
msg.strict
	dc.b	'Strict mode is unsupported'
crlf	dc.b	13,10,0

	; ACSI commands
	even
acsi.tstunit	; Test unit ready
	dc.w	4
	dc.b	$00,$00,$00,$00,$00,$00 ;
	even

acsi.inquiry	; Inquiry ACSI command
	dc.w	4
	dc.b	$12,$00,$00,$00,$30,$00
	even

acsi.rqsense	; Request sense ACSI command
	dc.w	4
	dc.b	$03,$00,$00,$00,$20,$00
	even

acsi.cmdts	; ACSI2STM command loopback test
	dc.w	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	dc.b	'A2STCmdTs'             ; Command test
	even

acsi.zcmdts	; ACSI2STM zero command loopback test
	dc.w	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	ds.b	9                       ; Zero bytes
	even

acsi.fcmdts	; ACSI2STM 0xff command loopback test
	dc.w	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	dc.b	$ff,$ff,$ff,$ff,$ff     ; All ones
	dc.b	$ff,$ff,$ff,$ff         ;
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
