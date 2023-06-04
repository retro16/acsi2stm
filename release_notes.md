**4.0f: RELEASE CANDIDATE**

4.0: A giant leap for ST-kind
=============================

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

And ... this actually works !

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
only **512 bytes of RAM** on the ST for maximum software compatibility.

Hot swapping SD cards is supported, with a lot of checks to make sure SD cards
aren't corrupted if programs try to access files from the old SD card.

The only limitation is that BIOS calls are unimplemented. The rule of thumb is:
everything that works on Hatari's GEMDOS drives should work with the new
GemDrive driver. And even more, since GemDrive mimics the weirdness of TOS
much more closely than Hatari.

A BIOS and XBIOS-level floppy emulator could be developed, but in these days of
cheap hardware-level floppy emulators, I don't think it's worth the effort. I
rarely play games on my ST anyway, and if I do I just use a real floppy.

A TOS loader could also be implemented, based on TOS relocation efforts
available online. Would require 128k of STM32 flash though, to store relocation
patches. Support for EmuTOS is also doable, but only if it brings more benefits
than simply putting EMUTOS.PRG in the AUTO folder.


ACSI hard drives aren't forgotten
---------------------------------

Besides the new GemDrive feature, a few fixes and logic changes were made to the
ACSI block device emulation (i.e. "normal" Atari hard disk). This proved to be a
very useful use case for most users, so I won't ditch it like that.

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


Future-proof for end-users
--------------------------

The ACSI2STM firmware can now be updated from the Atari itself. This means that
people buying units won't need fancy serial-USB adapters or fiddly Dupont wires
to do a firmware upgrade procedure. Just provide the files and voilà, firmware
updated.

The tool uses generic ACSI commands from the Seagate specification to update the
firmware, so it may work for other hard drives as well.


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
* Added GemDrive mode (TOS >= 1.04 "rainbow TOS" recommended)
* Added a tool to test TOS filesystem functions: `TOSTEST.TOS`
  * Uses TOS 2.06 floppy access as a reference implementation
  * Hatari is currently not fully compliant
* Added a tool to stress test ACSI drives: `ACSITEST.TOS`
* Added `ACSI_A1_WORKAROUND` to increase compatibility with TOS 1.0 and the
  2008 PP driver.
* Added support for flashing firmware.
* Added the `HDDFLASH.TOS` utility to flash ACSI devices, including ACSI2STM.


Pushed back for a later release
-------------------------------

* Cleanup redundent tests because of test matrix
* Implement date/time functions with RTC in GemDrive mode
* Set date/time correctly on all created files
* Test/fix Pexec command-line that seems to be broken (1 / 2 extra bytes)
* Fix top RAM allocation. I missed something. Need help.
* Fix the `GEMDRIVE.TOS` loader that releases its hooks memory !
  * Need to use Pexec / Ptermres instead of Malloc.
* Support for using GemDrive from within EmuTOS.
* Support for unicode file names. (may not fit in flash)
* Work around long delay on boot (long timeout on ACSI id 1 by TOS)


Features that can't be implemented / unfixable bugs
---------------------------------------------------

* Closing file descriptors on Ctrl-C: no GEMDOS callback for Ctrl-C.
* Adding more fancy features: not enough flash memory.
  * Floppy emulator
  * RAM TOS loader and relocator
* Implement filesystem label in Fsfirst/Fsnext: SdFat doesn't expose this.
* The SdFat library has issues with 8.3 long file names. For example, lower case
  file names aren't correctly handled.
* SYS file loader: not enough room in the boot sector.

