GemDrive: high level filesystem driver
======================================

GemDrive enables reading SD cards from the Atari ST, without the hassle of the
ancient TOS/BIOS filesystem implementation. It works more or less like the
GEMDOS drive functionality provided by the Hatari emulator: hook high level
filesystem calls and implement them directly in the STM32, using modern SD
card libraries.

It tries to imitate the behavior of GEMDOS as implemented in TOS versions 1.04,
1.62 and 2.06 on a floppy disk.


Benefits
--------

* Handles all standard PC-formatted SD cards (FAT16/FAT32/ExFAT).
* No SD card size limit.
* Avoids most TOS filesystem bugs.
* Consumes much less RAM on the ST than a normal driver.
* Can be combined with a normal hard drive or a floppy drive.
* Fully supports medium swap.
* Everything that runs on Hatari GEMDOS drives should run on GemDrive.
* Imitates GEMDOS much more closely than Hatari, especially weird error codes.
  It is even closer to TOS than EmuTOS in some unimportant areas.
* Translates all Atari characters to matching unicode characters. Fuji logo and
  "Bob" characters are translated to blocks that get converted back properly.
  Some usual non-atari unicode characters are transliterated to Atari
  equivalents.


Limitations
-----------

* Truncates long file names, as TOS doesn't support them.
* Only one partition per SD card.
* Works around some TOS limitations by using (relatively safe) heuristics,
  but there may be issues in some very extreme corner cases.
* Hooks the whole system unconditionally: may decrease performance in some
  extreme cases. Also, the STM32 can stall the whole TOS in case of error.
* TOS versions below 1.04 (Rainbow TOS) lack necessary APIs to implement Pexec
  properly, meaning that running a program will leak a small amount of RAM.
  This is also the case in Hatari.
* File descriptors are leaked when terminating a process with Ctrl-C. There is
  no system call to catch this event.
* Not compatible with MiNT or any other TOS replacement.
* Not compatible with OS-level multitasking (MultiTOS, ...).
* Mimics TOS 1.04, TOS 1.62 and TOS 2.06 behavior (and some of its bugs), so
  software relying on other TOS versions can have issues.


How to use
----------

When the ST boots (cold boot or reset), ACSI2STM scans all SD cards then
decide whether each SD card slot is in ACSI mode, GemDrive mode or disabled,
in that order:

* If the slot doesn't exist, it is completely disabled and the ACSI id is freed.
* If strict mode is enabled (via jumper or "strict" firmware variant), ACSI
  mode is enabled.
* If the SD card contains an ACSI disk image, ACSI mode is enabled.
* If the SD card is Atari bootable, ACSI mode is enabled.
* If the SD card can be mounted by the STM32, GemDrive mode is enabled.
* If no SD card is detected in the slot, GemDrive mode is enabled.
* If no other condition is satisfied, the SD card has an unknown format: ACSI
  mode is enabled.

If at least one SD slot is in GemDrive mode, then the driver will load by
providing a boot sector through the first GemDrive slot only (to avoid loading
the driver multiple times). All further GemDrive communication will go through
the ACSI id matching this slot.

If no SD card is present, GemDrive mode is enabled because it supports hot
inserting and hot swapping cards.

If GemDrive detects at least one SD slot running in ACSI mode, it will shift its
drive letters to L: in order to avoid conflicts with ACSI drivers.

At boot, GemDrive designates the first SD card it finds as boot drive (even if
it is not C:). If no SD card is detected, it leaves boot drive untouched
(usually the floppy drive is designated as boot). Note that "boot drive" isn't
taken into account by the "Save Desktop": it saves to C:, or A: if C: doesn't
exist.

GemDrive doesn't respond to any ACSI command, except reading the boot sector.
Most ACSI drivers and tools will ignore such a strange behavior and will skip
the drive successfully.

**Note**: in order to avoid drive letter confusion, only the first partition of
the SD card is used by GemDrive. This should not be a problem in most cases as
the need for multiple partitions arised from disk size limitations, and
GemDrive doesn't have any of them.


How GemDrive works
------------------

GemDrive injects itself in the system by providing a boot sector. This boot
sector takes over the whole operating system and the STM32 can access freely
to the whole ST RAM and hardware.

When booted, the STM32 injects the driver in RAM, then installs a hook for all
GEMDOS calls. The driver is just a small stub taking less than 512 bytes of
memory.

Each GEMDOS call sends a single byte command to the STM32, then waits for
remote commands from the STM32 program. The command set is extremely reduced,
so the whole algorithm is actually implemented in the STM32.

The STM32 decodes the call, then can decide to either implement it, or to
forward the call to the TOS.

The communication protocol is detailed in [protocols](protocols.md).


Mixing GemDrive and ACSI
------------------------

### Mixing GemDrive and ICD PRO

To mix GemDrive with ICD PRO, you must proceed like this:

* You must have only one bootable ICD PRO SD card.
* Insert the ICD PRO SD cards after the GemDrive cards.

The GemDrive driver will boot before the ICD PRO driver. GemDrive will use L:
and above as drive letters.

**Alternative:** Instead of making the ICD disk bootable, just put `ICDBOOT.PRG`
in the `AUTO` folder of the GemDrive SD card.

### Mixing GemDrive and the PP driver (ACSID07)

To mix GemDrive with the PP driver, proceed like this:

* Make sure ACSI2STM is configured to start at ACSI id 0.
* Insert the card with the PP driver in the first slot.
* Insert any other SD card in the extra slots.

The GemDrive driver will load after the PP driver. GemDrive will use L: and
above as drive letters.

### Mixing GemDrive and other ACSI drivers

If your driver has problems booting GemDrive, the easiest solution is to install
`GEMDRIVE.PRG` into the `AUTO` folder.


Mixing ACSI2STM and other devices
---------------------------------

Instructions in the previous section also apply.

You can use the ID_SHIFT jumper to change the ACSI id of the ACSI2STM unit.
Ensure that each device has a unique id. Some drivers require a specific id,
which can limit combinations.

### Multiple ACSI2STM compact PCBs

The ACSI2STM compact PCB has 3 slots, so it occupies 3 ACSI ids on the bus.

To use 2 compact PCBs together at the same time:

* Connect the first unit to the ST through the DB19 port.
* Connect the 2 units together using the IDC20 port.
* On the second unit, set the ID_SHIFT jumper to the 3-5 position.
* Power both units through their USB-C ports.


How to install EmuTOS with GemDrive
-----------------------------------

Since version 4.2, GemDrive is compatible with EmuTOS. Setting it up however is
a bit challenging. This file explains in details how to properly install it.

### Hardware needed

* One SD card dedicated as boot drive
* One SD card for EmuTOS and all your files

Both SD cards must have standard formatting (SD/SDHC/SDXC, **not** Atari)

### Installing EmuTOS executable

If you run EmuTOS from ROM, you can skip that section.

* Download the PRG version of EmuTOS
* On the EmuTOS SD card,
  * Copy `EMUTOS.PRG` at the root of the SD card
  * Rename `EMUTOS.PRG` to `EMUTOS.SYS`
  * Optionally, you can mark the file as hidden

### Installing the EmuTOS boot image

* On the boot SD card, create a directory named `acsi2stm`
* Copy `images/acsi2stm-xxxx-hd0.img` from the release package into `acsi2stm`
* Rename the image to `hd0.img`

### Booting EmuTOS

* Insert the EmuTOS card into the first SD slot
* Insert the boot card into any other SD slot
* Boot the ST
* EmuTOS will load itself
* GemDrive will load from `C:\AUTO`
* EmuTOS will install all drive icons on the desktop automatically
* GemDrive drive letters will start at L:

**Note:** You can remove one of `C:\AUTO\GEMDRIVE.PRG` or `C:\AUTO\GEMDRPIO.PRG`
depending on the firmware you use. If unsure, it doesn't hurt to have both.

**Note:** All your `AUTO` programs and accessories need to be installed on C:

**Note:** `AUTO` programs will have access to GemDrive if they are placed after
`GEMDRIVE.PRG`. If using the official image, this will be the case.

### How does that work ?

The `acsi2stm-xxxx-hd0.img` image file is a simple FAT16 filesystem with no
partition table, just like a floppy. EmuTOS can read ACSI hard drives that are
formatted like this, ICD Pro seems to handle these correctly too.

At boot, EmuTOS mounts that image as C: and runs the GemDrive driver from its
`AUTO` folder.

**Warning:** For maximum stability, the boot image must be under 32MB to keep
clusters of 1024 bytes. The release package provides a 8MB image, which is more
than enough for most needs in terms of `AUTO` programs and accessories.
