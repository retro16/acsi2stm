**4.0f: ALPHA VERSION**

ACSI mode is release quality.

GemDrive is still alpha quality.

TODO before 4.0
---------------

GemDrive mode (still alpha level):

 * Implement date/time functions with RTC
 * Set date/time correctly on all created files
 * Rewrite TinyFS and pars of GemDrive so tostest passes 100%. This is HUGE.
 * Fix long filenames bug generating ghost files on SD cards

TOSTEST:

 * Cleanup redundent tests because of test matrix
 * Add tests for date/time on files
 * Add archive bit tests for Fattrib in tostest
 * Implement filesystem label in Fsfirst/Fsnext tests in tostest
 * Implement file attributes in Fsfirst/Fsnext tests in tostest

Other:

 * Implement STM32 flash access from the ST, using WRITE BUFFER
  * Create a hard disk flashing program for the ST

Changes since 4.0e:

 * Added support for flashing firmware.
 * Added HDDFLASH utility to flash ACSI devices, including ACSI2STM.

Changes since 4.0d:

 * Added ACSI_A1_WORKAROUND to increase compatibility with TOS 1.0 and the 2008
   PP driver.
 * Fixed ACSI image loading.
 * Some work on GemDrive.
 * Added a huge amount of tests in tostest.

Changes since 4.0c:

 * Fixed so many oddities and quirks in the ACSI/SCSI implementation.
 * ACSI tests completed and 100% working on the ACSI2STM. Hatari fails on some
   of them, maybe I could file a pull request.

Pushed back for a later release
-------------------------------

 * Fix Pexec command-line that seems to be broken (1 / 2 extra bytes header)
 * Implement garbage file filter (non 8.3, dot files)
 * Implement filesystem label in Fsfirst/Fsnext
 * Fix top RAM allocation. I missed something. Need help.
 * Fix gemdrive.tos loader that releases its hooks memory !
 * Support for EmuTOS


4.0: A giant leap for ST-kind
=============================

ACSI mode seems better than any 3.xx but needs testing. Feedback appreciated.

Why version 4.0 ?
-----------------

The project was in a semi-dead state until recently. Not enough spare time.

I wanted to return on the project because I made a lot of decisive observations
lately on the ST, the STM32 and my project:

* The ST operating system (TOS+GEM) is a huge pile of ... well, you get it.
* TOS filesystem is full of bugs. Nothing can be trusted. Anything beyond 32MB
  will break sooner or later if you don't accumulate a lot of patches or 3rd
  party software that eat up your precious RAM and have their own issues.
* TOS 2.06 is barely acceptable, but breaks compatibility with some programs.
  Also, upgrading TOS is not an easy operation.
* The STM32 has a hardware glitch when accessing its GPIO ports. That's why many
  of us had unexplainable data corruptions. I still don't understand it
  completely, but I have a few workarounds in place.
* As fun as it was to write them, my driver and setup tool aren't (and will
  never be) production quality. It was a dead end, these needed to go away.


The ultimate solution
---------------------

I found enough spare time for the huge folly I envisioned a while ago:
reproduce the GEMDOS drive feature of Hatari that hooks a PC filesystem at
GEMDOS level, and not at BIOS level.

Let me introduce GemDrive: a copycat of Hatari's GEMDOS drive, 100% in hardware.

And ... this actually works ! (well, sort of, it's alpha software, it's very
unfinished and full of bugs).

The whole GEMDOS is hooked into the STM32 ! Each and every GEMDOS call will
transit through a STM32 routine, then the STM32 decides if it should pass the
call back to the TOS, or implement the call with its 72MHz 32-bit CPU !

This means that the ST now benefits Bill Greiman's SdFat library in all its
goodness. Speed, compatibility, robustness, no size limitations, you name it;
everything turned to 11.


What GemDrive does
------------------

You can use FAT16, FAT32, and **ExFAT**, up to **2TB** standard SD cards.

SD cards are mounted on the STM32 and directly exposed on the Atari.

The driver is just a shim that implements a few remote-control commands. It uses
only **512 bytes of top RAM** on the ST for maximum software compatibility.

Hot swapping SD cards is supported, with a lot of checks to make sure SD cards
aren't corrupted in case of issues.

The only limitation is that BIOS calls are unimplemented. The rule of thumb is:
everything that works on Hatari's GEMDOS drives should work with the new
GemDrive driver.

A BIOS and XBIOS-level floppy emulator could be developed, but in these days of
cheap hardware-level floppy emulators, I don't think it's worth the effort. I
rarely play games on my ST anyway, and if I do I just use a real floppy.

A TOS loader could also be implemented, based on TOS relocation efforts
available online. Would require 128k of STM32 flash though, to store relocation
patches. Support for EmuTOS is also doable, but only if it brings more benefits
than simply putting EMUTOS.PRG in the AUTO folder.


ACSI hard drives aren't forgotten
---------------------------------

Despite the new GemDrive feature, a few fixes and logic changes were made to the
ACSI block device emulation (i.e. "normal" Atari hard disk). This proved to be a
very useful use case for most users, so I can't ditch it like that.

Depending on your ACSI driver, it is possible to mix GemDrive and Atari SD
cards if you have multiple SD card slots ...

GemDrive uses a heuristic to try to select the best mode (GemDrive or ACSI),
but if all you want is good old ACSI only, just turn on strict mode using the
second jumper on the STM32.

Also, a "clean" (at least, as clean as possible) workaround has been implemented
for drivers that retrigger the A1 line mid-command, among them the TOS 1.00
bootloader.


Your hardware is safe
---------------------

The ACSI2STM hardware is now 100% final. No hardware changes were made since
3.0. A legacy firmware is also provided for owners of 2.x versions that were
not 100% compatible, keeping the necessity to power cycle the STM32 on each ST
reboot (because no reset line :( ).


Documentation revisited
-----------------------

The documentation was entirely verified and updated. In fact, the whole ACSI2STM
project exists mainly for its documentation.


Changes since 3.01
------------------

* Reworked DMA to try to work around some rare STM32 quirks
* Reworked the whole ACSI layer, especially error handling
* Removed the integrated block driver
 * Removed the setup tool
 * Removed the image creation tool
* Added GemDrive mode (requires TOS >= 1.04 "rainbow TOS")
* Added a tool to test TOS filesystem functions: tostest.tos
 * Uses TOS 2.06 floppy access as a reference implementation
 * Hatari is currently not fully compliant

