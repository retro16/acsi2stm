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
	dc.b	0
msg.devsel
	dc.b	13,10
	dc.b	'Type the device id of the ACSI2STM (0-7)'
	dc.b	13,10
	dc.b	'or press Esc to quit'
	dc.b	13,10,0
msg.testing
	dc.b	13,10
	dc.b	'Testing ...'
	dc.b	13,10,0
msg.chkdev
	dc.b	'Test unit ready'
	dc.b	13,10,0
msg.chkvers
	dc.b	'Checking ACSI2STM version'
	dc.b	13,10,0
msg.tstcmd
	dc.b	'Testing command burst'
	dc.b	13,10,0
msg.tstwcmd
	dc.b	'Testing command burst in write mode'
	dc.b	13,10,0
msg.qrybsz
	dc.b	'Querying buffer size'
	dc.b	13,10,0
msg.diag
	dc.b	'Testing DMA with pattern'
	dc.b	13,10,0
msg.halfcmd
	dc.b	'Testing interrupted command'
	dc.b	13,10,0
msg.success
	dc.b	'Test successful !'
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
msg.sensing
	dc.b	7
	dc.b	'Sensing error code'
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
	dc.b	4
	dc.b	$00,$00,$00,$00,$00,$00 ;
	even

acsi.inquiry	; Inquiry ACSI command
	dc.b	4
	dc.b	$12,$00,$00,$00,$30,$00
	even

acsi.rqsense	; Request sense ACSI command
	dc.b	4
	dc.b	$03,$00,$00,$00,$20,$00
	even

acsi.cmdts	; ACSI2STM command loopback test
	dc.b	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	dc.b	'A2STCmdTs'             ; Command test
	even

acsi.zcmdts	; ACSI2STM zero command loopback test
	dc.b	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	ds.b	9                       ; Zero bytes
	even

acsi.fcmdts	; ACSI2STM 0xff command loopback test
	dc.b	9
	dc.b	$1f                     ; Extended ICD command
	dc.b	$20                     ; Vendor-specific command
	dc.b	$ff,$ff,$ff,$ff,$ff     ; All ones
	dc.b	$ff,$ff,$ff,$ff         ;
	even

acsi.incomplt	; Incomplete command
	dc.b	1
	dc.b	$00,$00,$00             ; Only 3 bytes !
	even

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
