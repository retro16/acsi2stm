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
really taken into account by TOS, most of the time.

**Note**: in order to avoid drive letter confusion, only the first partition of
the SD card is used by GemDrive. This should not be a problem in most cases as
the need for multiple partitions arised from disk size limitations, and
GemDrive doesn't have any of them.


Mixing GemDrive and ACSI
------------------------

### Mixing GemDrive and ICD PRO

To mix GemDrive with ICD PRO, you must proceed like this:

* You must have only one bootable ICD PRO SD card.
* Insert the ICD PRO SD cards after the GemDrive cards.

The GemDrive driver will boot before the ICD PRO driver. GemDrive will use L:
and above as drive letters.

### Mixing GemDrive and the PP driver (ACSID07)

To mix GemDrive with the PP driver, proceed like this:

* Make sure ACSI2STM is configured to start at ACSI id 0.
* Insert the card with the PP driver in the first slot.
* Insert any other SD card in the extra slots.

The GemDrive driver will load after the PP driver. GemDrive will use L: and
above as drive letters.

### Mixing GemDrive and other ACSI drivers

A few considerations should be made when mixing both kinds of drives:

* ACSI drivers that require ACSI id 0 and break the boot chain won't allow
  GemDrive loading itself.
* GemDrive doesn't respond to any ACSI command, except reading the boot sector.
  Most drivers will ignore such a strange behavior and will skip the drive
  successfully.
* In general putting GemDrive first and the ACSI drives last is your best bet.

If your driver has problems with GemDrive, then only solution is to enable
strict mode to force ACSI everywhere.


How it works
------------

GemDrive injects itself in the system by providing a boot sector. This boot
sector takes over the whole operating system and the STM32 can access freely
to the whole ST RAM and hardware.

When booted, the STM32 injects the driver in RAM, then installs a hook for all
GEMDOS calls. The driver is just a small stub taking less than 512 bytes of
memory.

Each GEMDOS trap sends a single byte command to the STM32, then waits for
remote commands from the STM32 program. The command set is extremely reduced,
so the whole algorithm is actually implemented in the STM32.

The STM32 decodes the trap call, then can decide to either implement it, or to
forward the call to the TOS.

The communication protocol is detailed in [protocols.md](protocols.md).
