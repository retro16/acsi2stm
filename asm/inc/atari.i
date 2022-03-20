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

; Atari ST hardware registers and macros

; DMA hardware registers

gpip=$fffffa01
dma=$ffff8604
dmadata=dma
dmactrl=dma+2
dmahigh=dma+5
dmamid=dma+7
dmalow=dma+9


; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81
