/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2025 by Jean-Matthieu Coulon
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

#define ACSI2STM_VERSION "5.1b"

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// Number of bytes per DMA transfer to dump in verbose mode
// Set to 0 to disable data dump
#define ACSI_DUMP_LEN 48

// Serial port and speed used for debug/verbose output.
#define ACSI_SERIAL Serial
#define ACSI_SERIAL_SPEED 1000000

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

// Set this to limit SD capacity artificially in ACSI mode.
// Does not apply to disk images.
//#define ACSI_MAX_BLOCKS 0x0FFFFF // 512MB limit

// Maximum SD card speed in MHz.
// Modern SD cards can go up to 50MHz.
// The driver automatically downgrades to 25MHz for older standard SD cards.
// Tries 1MHz to try to make pathological hardware work anyway.
#define ACSI_SD_MAX_SPEED 50

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
// The main issue is STM32 flash being too slow for DMA, now all DMA uploads are
// done from STM32 RAM to make sure data is correct.
//
// Algorithms apply to STM32->ST transfers, for ST->STM32 any non-zero value
// will enable fast DMA.
#define ACSI_FAST_DMA 5

// Adds an additional delay between the last command byte received and the
// beginning of a DMA transfer. There is an inherent write hole in the ST and
// if unlucky enough a bus lock can happen, delaying the time between the CPU
// sending the last command byte and the CPU actually turning DMA on.
// The code supposes that an SD card operation is always long enough so this
// delay is only applied for write operations or synthesized replies.
// Delay in microseconds.
#define ACSI_DMA_START_DELAY 1

// Activity LED pin. Set to 1 to enable the activity LED on PC13. Set to 0 to
// disable it completely.
#define ACSI_ACTIVITY_LED 1

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
// or a size in bytes to enable the feature.
// If more than 75% of this amount of stack is used, debug messages will be
// displayed.
// Automatically disabled if ACSI_DEBUG is disabled.
#define ACSI_STACK_CANARY 3072

// If set, fakes firmware update
// Flashing through HDDFLASH.TOS or PIOFLASH.TOS won't actually write to flash
// memory. This is useful to test tools without having to reflash the chip again
// and again.
#define ACSI_FAKE_FLASH_FIRMWARE 0

// Boot EmuTOS if found on the SD card during GemDrive boot
// The value is the path to search for EMUTOS.SYS on the SD card
// Leave undefined to disable loading EmuTOS
#define ACSI_GEMDRIVE_LOAD_EMUTOS "/EMUTOS.SYS"

// First drive letter to scan when allocating drive letters to GemDrive.
// In all cases, GemDrive will skip drive letters already reserved by drivers
// loaded before it (such as ACSI drivers).
// Define either an uppercase letter such as 'C', or 0 for dynamic mode.
// In dynamic mode, it uses 'L' if an Atari bootable SD card is detected, 'C'
// otherwise.
//#define ACSI_GEMDRIVE_FIRST_LETTER 'C'
#define ACSI_GEMDRIVE_FIRST_LETTER 0

// If set, offset first GemDrive drive letter by the ACSI ID offset.
// For example, if the ID_SHIFT jumper is set in 3-5 position, GemDrive letters
// will start at F: instead of C:
// Note: dynamic letter shift always start at L:
#define ACSI_GEMDRIVE_LETTER_ID_OFFSET 1

// Set to 1 to convert all file names to upper case.
// If disabled, filesystem operations will preserve case and will become case
// insensitive.
#define ACSI_GEMDRIVE_UPPER_CASE 1

// If set, use a fallback character for characters that cannot be converted.
// The character needs to be encoded in Atari ST encoding.
// If not set, hide any file that contains incompatible characters in its name.
// If not set, any unsupported character in Atari filenames will be skipped.
// 0xff encodes a macron, which is easily spotted.
#define ACSI_GEMDRIVE_FALLBACK_CHAR 0xff

// Hide files with names starting with '.'
// This is a good idea because dot files are usually hidden in UNIX-like OSes.
// These files can crash GEMDOS anyway. Leave this enabled.
#define ACSI_GEMDRIVE_HIDE_DOT_FILES 1

// Hide files that don't fit 8.3.
// Contrary to MS-DOS that does the ~1 trick to avoid duplicates, here file
// names are simply truncated, leaving possible duplicates (and their glitches).
// Hiding any file not fitting the 8.3 standard is the safest option.
#define ACSI_GEMDRIVE_HIDE_NON_8_3 1

// Size in bytes for the relocation table cache. Bigger means faster Pexec,
// smaller means less memory used by Pexec on the STM32.
#define ACSI_GEMDRIVE_RELTABLE_CACHE_SIZE 512

// Maximum number of files that can be opened at the same time. Consumes static
// RAM on the STM32. Maximum is 256.
#define ACSI_GEMDRIVE_MAX_FILES 64

// Maximum depth of a path, in folders. Impacts RAM usage on the STM32.
#define ACSI_GEMDRIVE_MAX_PATH 64

// Disable direct DMA access in GemDrive (used for testing/debug)
// Simulates how GemDrive works with TT-RAM on a ST
#define ACSI_GEMDRIVE_NO_DIRECT_DMA 0

// Don't use DMA at all, use programmed input/output instead (A1/CS/IRQ)
// This is a workaround for dead DMA chips (a common issue on STs).
// Only GemDrive will work, and you can't self-boot it, you need to use
// GEMDRPIO.TOS to start it.
// Performance will be horrible, but still better than floppy disks.
#define ACSI_PIO 0

// vim: ts=2 sw=2 sts=2 et
#endif
