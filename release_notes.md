TODO for 4.20:

* Test the Compact PCB prototype
* Review all documentation once again

4.20: Professionally assembled PCB and RTC fix
==============================================

New Compact PCB
---------------

This release adds a new PCB with less features, but that can be built entirely
by JLCPCB's assembly services. It does not require a Blue Pill as it integrates
the STM32 directly.

Total cost is around $50 for 5 units (this is the minimum amount you can buy).
Prices are of 07/2023 and may vary.

Sources for EasyEda and Gerber are included, just like the full featured PCB.

This PCB can also be connected using UltraSatan cables (IDC20 format), both for
sharing the port to other devices or being connected using an IDC20 cable.

Note that buying from JLCPCB does not imply any warranty of any form from
ACSI2STM authors. ACSI2STM authors don't receive any money from this.

GemDrive loader program
-----------------------

GemDrive can now be loaded as a TOS program. The main reason to do that is
EmuTOS support since EmuTOS does not boot hard disk boot sectors. Simply start
`GEMDRIVE.TOS` from the AUTO folder or from the desktop to load the GemDrive
driver and all drives will be enabled.

EmuTOS loader
-------------

GemDrive can now boot `EMUTOS.SYS` from the 1st SD card slot.

Changes since 4.10
------------------

* Fixed RTC clock that didn't run when unpowered.
* Added the *Compact PCB*.
* Documentation updates.
* Added back the whole history for 4.x in release_notes.md, as it should be.
* Fixed GemDrive letter allocation when the 1st slot is not GemDrive.
* Fixed and added `GEMDRIVE.TOS` to load GemDrive from desktop.
* Boot `EMUTOS.SYS` on startup if present on the SD card.


4.10: Clock support and unicode for GemDrive
============================================

Clock support
-------------

Adding clock support for GemDrive was easier than anticipated. One more reason
to add a backup cell to your ACSI2STM !

Here is what it does:

* Hooks all system clock functions into the STM32.
* No need to load any utility: the ST is simply always on time.
* Use `CONTROL.ACC`/`XCONTROL.ACC` or any other standard time setting tools to
  set time and date.
* Sets date/time correctly on created files and folders.

Note: for users of machines with an internal clock, ACSI2STM reads the time from
the Atari clock at boot if its internal clock is not already set.

Unicode support
---------------

Now GemDrive properly translates all file names to unicode. Converting back and
forth is 100% guaranteed. Importing files from other systems might be more
difficult, though. Anyway, the system replaces unknown characters with a macron
so you can spot them easily. A few characters such as the euro sign are
transliterated to visually near-equivalent characters.

Changes since 4.01
------------------

* Implemented clock for Tgettime / Tsettime / Tgetdate / Tsetdate.
* Use clock to set file date correctly.
* Improved performance of Fsnext when some SD slots are empty.
* Added proper unicode translation for special Atari characters.
* Fix for unsupported characters in names.
* Added `CHARGEN.TOS` to produce test file names with unicode characters.


4.01: Small fixes in GemDrive and more tests
============================================

Some small bugs prevented GemDrive from working correctly under TOS 2.06. It may
have impacts in some software too.

Changes since 4.00
------------------

Changes in GemDrive:

* Fixed a buffer overwrite in GemDrive that impacted Fsfirst with absolute
  paths.
* Fixed Fsfirst return value when the path is on an ejected drive.

Changes in tests:

* Added some tests for absolute paths.

Other changes:

* Fixed the stack canary that took too much RAM.


4.00: A giant leap for ST-kind
==============================

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
* Added `ACSI_A1_WORKAROUND` to increase compatibility with TOS 1.0 and the
  2008 PP driver.
* Added support for flashing firmware.
* Added `TOSTEST.TOS` to test TOS filesystem functions.
  * Uses TOS 2.06 floppy access as a reference implementation
  * Hatari is currently not fully compliant
* Added `ACSITEST.TOS` to stress test ACSI drives.
* Added the `HDDFLASH.TOS` utility to flash ACSI devices, including ACSI2STM.
* Added the `SWAPTEST.TOS` to stress test GemDrive swapping.


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

