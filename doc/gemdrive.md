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

A few considerations should be made when mixing both kinds of drives:

* ACSI drivers that require ACSI id 0 and break the boot chain won't allow
  GemDrive loading itself.
* In general putting GemDrive first and the ACSI drives last is your best bet.

If your driver has problems with GemDrive, then only solution is to enable
strict mode to force ACSI everywhere.


How to install EmuTOS with GemDrive
-----------------------------------

Since version 4.2, GemDrive is compatible with EmuTOS. Setting it up however is
a bit challenging. This file explains in details how to properly install it.


### Setting up boot SD card

You need at least 2 SD cards and 2 slots on your ACSI2STM. EmuTOS cannot boot on
GemDrive, so you need at least 1 Atari-formated SD card.

**Alternative:** Use a floppy disk as boot drive. In that case you need only a
single SD card.

* Create a small disk image (`hd0.img`) on the boot SD card. 30MB is
  recommended.
* Partition the image using ICD PRO's `ICDFMT.PRG`.
  * No need to make the disk bootable.
  * If you want multiple boot disks (such as a different set of `AUTO` programs
    or accessories), create multiple partitions.
* Copy `GEMDRIVE.TOS` onto the boot disk.

**Hint:** You can run ICD and GemDrive easily together. Just run `ICDBOOT.PRG`
manually from GEM, then install the C: drive icon on the desktop. You may have
to install L:, M: and so on to access GemDrive drives.


### Installing EmuTOS

If you run EmuTOS from ROM, you can skip that section.

* Download the PRG version of EmuTOS.
* On the GemDrive SD card (**not** the boot disk),
  * Copy `EMUTOS.PRG` at the root of the SD card
  * Rename `EMUTOS.PRG` to `EMUTOS.SYS`.

### Setting up GemDrive from within EmuTOS

* Insert the GemDrive SD card with `EMUTOS.SYS` in the first SD card slot of the
  ACSI2STM.
* Insert the boot SD card in the last slot. If you use a boot floppy instead,
  insert the floppy disk.
* Reboot the system, EmuTOS should start at boot.
  * Once EmuTOS is booted, you should see the boot disk as C: (or A: if it is a
    floppy disk).
* Open the boot disk on the desktop
* Launch `GEMDRIVE.TOS`. GemDrive drives should be detected starting at L:.
* In the menu bar, click *Options/Install devices*. GemDrive drives should
  appear on the desktop.
* Select `GEMDRIVE.TOS`. In the menu bar,
  click *Options/Install application...*.
  * Set *Boot status* to *Auto*.
  * Click *Install* to close the dialog.
* In the menu bar, click *Options/Save desktop...*

**Note:** all your `AUTO` programs and accessories need to be installed on C:

**Note:** `AUTO` programs won't have access to GemDrive. Currently there is no
way around that.
