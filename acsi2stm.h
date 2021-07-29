/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
 *
 * This Library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ACSI2STM_H
#define ACSI2STM_H

#include <Arduino.h>

// acsi2stm global configuration

#define ACSI2STM_VERSION "2.1"

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// Number of bytes per DMA transfer to dump in verbose mode
// Set to 0 to disable data dump
#define ACSI_DUMP_LEN 16

// Serial port used for debug/verbose output.
#define ACSI_SERIAL Serial

// Filter/delay data acquisition on ACK pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Only impacts DMA writes (ST -> STM32)
#define ACSI_ACK_FILTER 0

// Filter/delay data acquisition on CS pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Set this to 3 to sample 97.1ns later
// Only impacts command send (ST -> STM32)
#define ACSI_CS_FILTER 1

// Set to 1 to make all SD cards readonly (returns an error if writing)
// Set to 2 to ignore writes silently (returns OK but does not actually write)
#define AHDI_READONLY 0

// Set this to limit SD capacity artificially.
// Set to ~0 if you don't want any limit
#define AHDI_MAX_BLOCKS ~0 // No limit
//#define AHDI_MAX_BLOCKS 0x0FFFFF // 512MB limit

// Activity LED pin. Leave undefined to remove activity LED.
#define ACTIVITY_LED LED_BUILTIN

// Hard disk image file name. It can be placed in a subfolder.
#define IMAGE_FILE_NAME "/acsi2stm.img"


// vim: ts=2 sw=2 sts=2 et
#endif
