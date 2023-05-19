/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
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

#define ACSI2STM_VERSION "4.0e"

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// Number of bytes per DMA transfer to dump in verbose mode
// Set to 0 to disable data dump
#define ACSI_DUMP_LEN 48

// Serial port and speed used for debug/verbose output.
#define ACSI_SERIAL Serial
#define ACSI_SERIAL_SPEED 2000000

// Number of SD cards (1 to 5)
#define ACSI_SD_CARDS 5

// Enable strict mode.
// This disables some features but increases SCSI compatibility.
// When set to 0, the feature can be turned on or off at runtime with the
// BOOT1 jumper on PB2.
#define ACSI_STRICT 0

// Set to 1 to make all SD cards readonly (returns an error if writing)
// Set to 2 to ignore writes silently (returns OK but does not actually write)
// Falls back to mode 1 if strict mode is enabled.
#define ACSI_READONLY 0

// Set this to limit SD capacity artificially.
//#define ACSI_MAX_BLOCKS 0x0FFFFF // 512MB limit

// Maximum SD card speed in MHz.
// Standard SD cards can go up to 50MHz.
// The driver automatically downgrades to a slower speed on each retry.
#define ACSI_SD_MAX_SPEED 36

// SD card write lock pin behavior (PB0, PB1 and PB3-PB5).
// In every case, soldering these pins to VCC (+3.3V) will disable the SD slot
// and free the corresponding ACSI id on the bus.
//
// This #define indicates how the pin behaves when connected to the SD card
// reader's "write lock" pin.
// If set to 0: the pin is completely ignored, the SD card is always writable
// If set to 1: the pin is floating when read-write, tied to GND when read-only
// If set to 2: the pin is tied to GND when read-write, floating when read-only
#define ACSI_SD_WRITE_LOCK 2

// Data buffer size in 512 bytes blocks
#define ACSI_BLOCKS 8

// Device ID of the first SD card on the ACSI bus
#define ACSI_FIRST_ID 0

// Use jumpers on debug pins to offset ACSI IDs
// ACSI_FIRST_ID must be 0 to enable this feature
#define ACSI_ID_OFFSET_PINS 1

// Set this to 1 to use the RST line on the ACSI port
// Set this to 0 ignore the PA15 pin completely
// In every case the pin PA15 will be setup as a pull-up so this should work
// even if you don't connect PA15 to anything.
#define ACSI_HAS_RESET 1

// Filter/delay data acquisition on ACK pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Only impacts STM->ST DMA transfers
#define ACSI_ACK_FILTER 1

// Filter/delay data acquisition on CS pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Set this to 3 to sample 97.1ns later
// Only impacts command transfers
#define ACSI_CS_FILTER 1

// Push data faster in DMA transfers
// Setting to non-zero unrolls the DMA transfer code but may be less compatible
// with some ST DMA controllers.
//
// Values 1 to 5 select different algorithms, from the most conservative to the
// fastest. It seems that the STM32 has hardware glitches in some corner cases,
// and different algorithms do different tradeoffs for speed and compatibility.
// Versions 3.x used algorithm 5 (the fastest) but had known issues.
//
// Algorithms apply to STM32->ST transfers, for ST->STM32 any non-zero value
// will enable fast DMA.
#define ACSI_FAST_DMA 1

// Adds an additional delay between the last command byte received and the
// beginning of a DMA transfer. There is an inherent write hole in the ST and
// if unlucky enough a bus lock can happen, delaying the time between the CPU
// sending the last command byte and the CPU actually turning DMA on.
// The code supposes that an SD card operation is always long enough so this
// delay is only applied for write operations or synthesized replies.
// Delay in microseconds.
#define ACSI_DMA_START_DELAY 4

// Activity LED pin. Leave undefined to remove activity LED.
#define ACSI_ACTIVITY_LED LED_BUILTIN

// File name of the hd image
#define ACSI_IMAGE_FILE "/acsi2stm/hd0.img"

// Set to 1 to enable UltraSatan-compatible RTC
#define ACSI_RTC 1

// Workaround bad drivers that trigger A1 mid-command.
// The 2008 PP driver, as well as the TOS 1.00 boot loader need this.
// If disabled, any A1 issue will trigger a quick reset, which is safer.
#define ACSI_A1_WORKAROUND 1

// Stack canary
// Used to check that RAM was not overwritten. Set to 0 for normal operation,
// or a size in bytes to enable the feature. Standard size is 4096 bytes.
// If more than 75% of this amount of stack is used, debug messages will be
// displayed.
#define ACSI_STACK_CANARY 0

// First drive letter to scan when allocating drive letters to GemDrive.
// In all cases, GemDrive will skip drive letters already reserved by drivers
// loaded before it (such as ACSI drivers).
// Define either an uppercase letter such as 'C', or 0 for dynamic mode.
// In dynamic mode, it uses 'L' if a bootable SD card is detected, 'C'
// otherwise.
//#define ACSI_GEMDRIVE_FIRST_LETTER 'C'
#define ACSI_GEMDRIVE_FIRST_LETTER 0

// If set to 1, allocate GemDrive in top RAM. As I don't know yet all the
// details, and as I saw a few glitches, I must be doing something wrong
// somewhere. So by setting this to 1 you can allocate GemDrive to top RAM,
// but don't complain if it crashes.
#define ACSI_GEMDRIVE_TOPRAM 0

// Size in bytes for the relocation table cache. Bigger means faster Pexec,
// smaller means less memory used by Pexec on the STM32.
#define ACSI_GEMDRIVE_RELTABLE_CACHE_SIZE 512

// Maximum number of files that can be opened at the same time. Consumes static
// RAM on the STM32. Maximum is 256.
#define ACSI_GEMDRIVE_MAX_FILES 64

// Maximum depth of a path, in folders. Impacts RAM usage on the STM32.
#define ACSI_GEMDRIVE_MAX_PATH 64

// If set to 0 (disabled), try to convert all file names to the Atari 8.3 format.
// If set to 1, hide files starting by a dot (the unix way to hide files).
// If set to 2, hide any non-8.3 files or files with non-ASCII characters.
#define ACSI_GEMDRIVE_HIDE_INCOMPATIBLE_FILES 1

// GEMDOS sniffer
// In GEMDOS sniffer mode, GemDrive is passthrough. Used to transparently log
// GEMDOS calls for debugging purposes.
// Does not make much sense if debug mode is not enabled.
#define ACSI_GEMDOS_SNIFFER 0

// vim: ts=2 sw=2 sts=2 et
#endif
