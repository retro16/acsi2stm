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
; Shared read-only data

text.init	dc.b	'Driver init',13,10,0
text.scan	dc.b	'Scan for drives',13,10,13,10,0
text.started	dc.b	13,10,'Driver started',13,10,13,10,0
text.notime	dc.b	'Could not set time',13,10,0

prtpart.none	dc.b	7,'No partition detected',13,10,0

init.emutos	dc.b	'EMUTOS.SYS'
init.zero	dc.b	0

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
