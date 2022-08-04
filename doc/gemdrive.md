GemDrive: high level filesystem driver
======================================

GemDrive enables reading SD cards from the Atari ST, without the hassle of the
ancient TOS/BIOS filesystem implementation. It works more or less like the
GEMDOS drive functionality provided by the Hatari emulator: hook high level
filesystem calls and implement them directly in the STM32, using modern SD
card libraries.


Benefits
--------

* Handles all standard PC-formatted SD cards (FAT16/FAT32/ExFAT).
* No SD card size limit.
* Avoids most TOS filesystem bugs.
* Consumes much less RAM on the ST than a normal driver.
* Can be combined with a normal hard drive or a floppy drive.
* Fully supports medium swap.
* Everything that runs on Hatari GEMDOS drives should run on GemDrive.


Limitations
-----------

* Truncates long file names, as TOS doesn't support them.
* Only supports ASCII characters in file names, no intl support.
* Only one partition per SD card.
* Works around some TOS limitations by using (relatively safe) heuristics,
  but there may be issues in some very extreme corner cases.
* Hooks the whole filesystem unconditionally: may decrease performance in
  some cases. Also, the STM32 can stall the whole TOS in case of error.
* TOS versions below 1.04 (Rainbow TOS) lack necessary APIs to implement Pexec
  properly, meaning that running a program will leak a small amount of RAM.


How to use
----------

At boot, GemDrive mode will be disabled if:

* Strict mode is enabled by a jumper / compilation flag
* An Atari-bootable SD card is inserted in the first SD slot at startup
* A hard disk image is found on the SD card in the first SD slot at startup

GemDrive will start if no SD card is inserted, to allow hot swapping.

Once started, GemDrive will reserve one drive letter per SD card slot, whether
or not it contains a valid mountable SD card. On each access the STM32 will
check if the SD card is present and/or has been swapped.

The SD card can then be used like any other drive.

GemDrive mounts SD cards if the following conditions are met:

* A SD card with a single FAT16/FAT32/ExFAT partition is inserted
* The SD card can be mounted by the SdFat library
* The SD card is not Atari-bootable

SD cards that cannot be mounted will appear as normal Atari hard drives, just
like in strict mode. This allows mixing GemDrive and other drivers.

If you want to use another hard drive along with GemDrive, you should place it
before the ACSI2STM in the device chain (e.g. hard drive on ID 0 and ACSI2STM
on ID 1).


How it works
------------

GemDrive injects itself in the system by providing a boot sector. This boot
sector takes over the whole operating system and the STM32 can access freely
the whole ST RAM and operating system.

When booted, the STM32 injects the driver in RAM, then installs a hook for all
GEMDOS calls. The driver is just a small stub taking less than 500 bytes of
memory.

Each GEMDOS trap sends a single byte command to the STM32, then waits for
remote commands from the STM32 program. The command set is extremely reduced,
so the whole algorithm is actually implemented in the STM32.

The STM32 decodes the trap call, then can decide to either implement it, or to
forward the call to the TOS.


Future improvements
-------------------

Things that could be done more or less easily (requiring a 128k STM32):

* Install the driver in top RAM.
* Floppy drive emulator, by hooking BIOS and XBIOS calls.
* Hook Pexec on ST files to boot a floppy image by double-clicking it in GEM.
* Support international character sets for filename translation, based on the
  language of the machine.
