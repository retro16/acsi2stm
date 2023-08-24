Hardware compatibility
======================

ACSI2STM was successfully tested on the following configurations:

* Atari 520 STF, TOS 1.04, GemDrive + ICD driver
* Atari 1040 STE, TOS 1.62, GemDrive + ICD driver
* Atari 1040 STE, TOS 1.62, GemDrive + PP driver
* Atari 1040 STE, TOS 2.06, GemDrive + ICD driver
* Atari 1040 STE, EmuTOS, integrated ACSI driver + GemDrive
* Atari TT030, ACSI mode (driver not specified)

GemDrive mode is currently tested on Atari ST and STE (no TT or Falcon). It
might work on the TT or the Falcon. If anybody owns this hardware and is
interested, please open a GitHub issue. Testing is safe for the hardware, not
for data.

TOS >= 1.04 ("rainbow TOS") is strongly recommended because older TOS will leak
a small amount of memory when a program stops. It may or may not have an impact
depending on how you use the machine.

TOS replacements such as MultiTOS, MiNT or others are incompatible with GemDrive
mode. Implementing multitasking in GemDrive is nearly impossible on such a small
microcontroller.


Firmware compatibility matrix
=============================

Since the ACSI2STM project now has a rather long history with breaking changes,
it can be difficult to keep track of what is compatible with what.

Here is a compatibility matrix that shows firmware revisions and their hardware
compatibility:

|                      Hardware board | 1.x | 2.x | 3.0+ | 4.0+ legacy |
|------------------------------------:|:---:|:---:|:----:|:-----------:|
|         Custom board built for v1.0 | ✓   | 🛇   | 🛇    | 🛇           |
|         Custom board built for v2.0 | 🛇   | ✓   | 🛇    | ✓           |
|         Custom board built for v3.0 | 🛇   | 🛇   | ✓    | ✓           |
|         Custom board built for v4.0 | 🛇   | 🛇   | ✓    | ✓           |
|              Full featured PCB v1.0 | 🛇   | 🛇   | ✓    | ✓           |
|              Full featured PCB v1.1 | 🛇   | 🛇   | ✓    | ✓           |
|                 SOVAJA Mega STE PCB | 🛇   | 🛇   | ✓    | ✓           |
|  Official ACSI2STM compact PCB v1.0 | 🛇   | 🛇   | ✓    | ✓           |

**Note:** 3.0+ means version 3.0 and higher, including any 4.x, 5.x,...

**Note:** Hardware can be upgraded by making changes. See [hardware](hardware.md).

**Info:** Hardware compatible with 3.0+ and 4.0+ will be supported by all future
firmware revisions.


SD card, partition and filesystem compatibility
===============================================

ACSI2STM is compatible with all SD cards that can work in SPI mode, meaning most
old SD cards, all SDHC and all SDXC cards. SDUC was not tested and probably
won't work.

In GemDrive mode, the SD card must be formated either in FAT16, FAT32 or ExFAT
format, with a single partition (the standard format for SD cards). The
partition size is limited to 2TB.

In ACSI mode, the SD card must be formated with Atari tools. TOS restrictions
apply.

In ACSI image mode, the SD card must be formated with standard SD format (like
GemDrive) and the image itself must be formated with Atari tools.

Floppy disk images in ST format can be used as ACSI images and will appear as a
small C drive on the ST. This won't make games compatible though since it is not
a real floppy emulator.


Emulator compatibility
======================

ACSI images are compatible with Hatari ACSI images. Using a SD writing tool
like *Raspberry Pi Imager*, you can transfer an image to the physical SD card.

GemDrive cards are mostly compatible with Hatari's GEMDOS drives, with a few
differences in unicode translation, long file name support or other details.

Other emulators provide similar features but were not tested.


Atari software compatibility
============================

This section explains why some programs are compatible and some are not.

## Software properly using the operating system

These programs use the normal GEMDOS interface to access disk drives. This
means that they have no path restrictions and follow the rules.

**Programs usually working like this:**

* Most desktop programs
* A few games with no disk protection
* Basically everything using the standard file selector to open files

**Compatible with**

* Internal floppy disk (A:)
* External floppy disk (B:)
* ACSI hard disk
* GemDrive
* Hatari GEMDOS

## Software relying on bugs

These programs use the normal GEMDOS interface to access disk drives but rely
on weird patterns or buggy TOS error codes to work properly.

**Compatible with**

* Internal floppy disk (A:)
* External floppy disk (B:)
* ACSI hard disk
* GemDrive

**Incompatible with**

* Hatari GEMDOS

## Software doing BIOS access

These programs access low level disks using BIOS or XBIOS interfaces.

**Programs usually working like this:**

* Most disk utilities
* Maybe some very weirdly programmed games

**Compatible with**

* Internal floppy disk (A:)
* External floppy disk (B:)
* ACSI hard disk

**Incompatible with**

* GemDrive
* Hatari GEMDOS

## Software doing direct floppy controller access

These programs directly access the floppy controller.

**Programs usually working like this:**

* Most games
* Most programs relying on copy protected floppy disks
* Floppy disk utilities (copy/format/repair)

**Compatible with**

* Internal floppy disk (A:)
* (not always) External floppy disk (B:)

**Incompatible with**

* ACSI hard disk
* GemDrive
* Hatari GEMDOS


Choosing a hard disk driver for ACSI mode
=========================================

GemDrive mode is recommended. However in some situations you might want to use
ACSI mode with a hard disk driver.

There are many hard disk drivers for the Atari ST out there. All of them come
with their pros and cons.

Here is the list of the free drivers I'm aware of, in no particular order:


## ICD PRO Festplatentreiber 6.55

Free (not open source) driver that works well and is very stable.

**Pros:**

* Officially supported by ACSI2STM. Tested before each release.
* Good set of tools.
* Supports SD card hot swapping (the new SD card must have the same number of
  partitions).

**Cons:**

* Incompatible with BigDOS.
* Eats up memory like crazy if you leave cache enabled (disable cache, ACSI2STM
  is nearly as fast as memcpy).
* Not open source.


## P.Putnik's ACSID07 driver (free, 2008 version)

**Pros:**

* Supports MS-DOS partition tables.
* Compatible with BigDOS.

**Cons:**
* Supports only ACSI id 0.
* Not 100% ACSI standard compliant, does funky stuff on boot (re-enables A1
  mid-command).

## Uwe Seimet's HDDriver

**Pros:**

* Fully supporting the SCSI command set.
* Supports more than 1 LUN per drive.
* Very high quality set of tools.
* Supports MS-DOS partition tables.
* Compatible with BigDOS.

**Cons:**

* The free version is very limited in functionality.
* Does not support ACSI2STM officially (later versions should work).
* Not open source.

## AHDI

The antique driver provided by Atari. While it *should* work, nobody seem to use
it anymore.

**Pros:**

* Authentic, "pure" Atari experience.
* None, really.

**Cons:**

* Unsupported by ACSI2STM. Meaning it is never tested, your mileage may vary.
* Incompatible with BigDOS.
* Supports only Atari partition tables.
* Not open source.

