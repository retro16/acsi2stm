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

#define ACSI2STM_VERSION "3.10"

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// Number of bytes per DMA transfer to dump in verbose mode
// Set to 0 to disable data dump
#define ACSI_DUMP_LEN 26

// Serial port and speed used for debug/verbose output.
#define ACSI_SERIAL Serial
#define ACSI_SERIAL_SPEED 2000000

// Number of SD cards (1 to 5)
#define ACSI_SD_CARDS 5

// Enable strict mode.
// This disables some features but increases SCSI compatibility.
// When set to 0, the feature can be turned on or off at runtime with the
// BOOT1 jumper on PB2.
// Breaks ACSITEST.TOS if enabled
#define ACSI_STRICT 0

// Set to 1 to make all SD cards readonly (returns an error if writing)
// Set to 2 to ignore writes silently (returns OK but does not actually write)
// Falls back to mode 1 if strict mode is enabled.
#define ACSI_READONLY 0

// Include a dummy boot sector if no SD card is inserted.
// This will display an alert message during the ST boot process.
// This makes the device less SCSI-conformant.
// The variable indicates how many SD card slots have this feature.
// Disabled in strict mode.
#define ACSI_DUMMY_BOOT_SECTOR 1

// Overlay a dummy boot sector if the SD card is not bootable.
// This will display an alert message during the ST boot process.
// This makes the device absolutely weird and may break some system tools.
// The variable indicates how many SD card slots have this feature.
// Disabled in strict mode.
#define ACSI_BOOT_OVERLAY 5

// Set this to limit SD capacity artificially.
//#define ACSI_MAX_BLOCKS 0x0FFFFF // 512MB limit

// Maximum SD card speed in MHz.
// Standard SD cards can go up to 50MHz.
// The driver automatically downgrades to a slower speed on each retry.
#define ACSI_SD_MAX_SPEED 36

// SD card write lock pin behavior (PB0, PB1 and PB3-PB5).
// In every case, soldering these pins to VCC (+3.3V) will disable the SD card
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
#define ACSI_ACK_FILTER 2

// Filter/delay data acquisition on CS pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Set this to 3 to sample 97.1ns later
// Only impacts command transfers
#define ACSI_CS_FILTER 0

// Push data faster in DMA transfers
// Setting to 1 unrolls the DMA transfer code but may be less compatible
// with some ST DMA controllers.
#define ACSI_FAST_DMA 1

// Adds an additional delay between the last command byte received and the
// beginning of a DMA transfer. There is an inherent write hole in the ST and
// if unlucky enough a bus lock can happen, delaying the time between the CPU
// sending the last command byte and the CPU actually turning DMA on.
// The code supposes that an SD card operation is always long enough so this
// delay is only applied for write operations or synthetized replies.
// Delay in microseconds.
#define ACSI_DMA_START_DELAY 2

// Activity LED pin. Leave undefined to remove activity LED.
#define ACSI_ACTIVITY_LED LED_BUILTIN

// Maximum number of LUNs. For driver supporting multiple LUNs, this allows
// multiple images on the same SD card. Still work in progress.
#define ACSI_MAX_LUNS 1

// Folder containing disk images
// It must not end with a "/"
#define ACSI_IMAGE_FOLDER "/acsi2stm"

// File folder name and extension of LUN images
// The LUN number is inserted between the prefix and extension.
// Example:
//   ACSI_IMAGE_FOLDER "/acsi2stm"
//   ACSI_LUN_IMAGE_PREFIX "hd"
//   ACSI_LUN_IMAGE_EXT ".img"
//   The image file for LUN 0 will be "/acsi2stm/hd0.img"
//   The image file for LUN 1 will be "/acsi2stm/hd1.img"
#define ACSI_LUN_IMAGE_PREFIX "hd"
#define ACSI_LUN_IMAGE_EXT ".img"

// Set to 1 to enable UltraSatan-compatible RTC
#define ACSI_RTC 1

// vim: ts=2 sw=2 sts=2 et
#endif
