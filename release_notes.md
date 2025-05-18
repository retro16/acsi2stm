5.1b: Super Compact PCB, minor hardware revision, software bug fixes
====================================================================

A minor version that fixes small details and brings a new PCB.

New Super Compact PCB
---------------------

In order to address many use cases, a new PCB was introduced: the Super Compact.

This PCB has less features, but is much smaller. To achieve this, the bulky RTC
backup battery was removed and there is only one microSD card slot.

The PCB should obstruct less ports on "pro" Atari cases such as the MegaSTE or
the TT.

Build price is about 10-20% lower.

It's the perfect version for people who use their ST just for games.

It matches "pro" Atari variants pretty well: these computers already have a
builtin RTC and an internal hard disk, so there is less needs for multiple
slots.

Don't neglect the flexibility brought by multiple SD slots, especially for
desktop workflows (1 slot for system, 1 slot for data, 1 slot for hot swapping).

Compact and Super Compact PCBs will have their version numbers synchronized, so
both are at version 1.1 right now.

Official release package now built from podman / docker
-------------------------------------------------------

Release packages are now generated inside a podman container. This guarantees a
much more stable environment, and it will allow non-Linux users to build
releases more easily.

Commands to build the docker image are found in the Dockerfile itself, or in
doc/firmware.md.

Changes since 5.00
------------------

* Fixed file date/time on non-GemDrive drives such as floppy or ACSI in GemDrive
  mode
* Fixed GemDrive program loading, improves compatibility
* Fixed incompatibility with Alt-RAM addons (MonSTEr, Magnum ST, Storm ST, ...)
* Reworked components of the Compact PCB
  * Switched to 0805 components to make hand soldering easier
  * Use 12pF capacitors to improve 32kHz crystal stability. Fixes the "one out
    of 5 units not working"
* Added the Super Compact PCB
* Added the release build Dockerfile
* Doc changes
  * Moved ordering tutorial, so end-user documentation appears first
  * Added copy operations in the tutorial section
  * Added Super Compact documentation where needed
  * Documented the podman-based build procedure
  * Minor changes


5.00: Professionally assembled PCB, EmuTOS, PIO mode, multiple devices and fixes
================================================================================

5.00 is the final version of this project. Development is officially stopped.

This is a new major version because the project shifted direction: it's not
officially based on the Blue Pill anymore, but a custom PCB based on the exact
same microcontroller: the STM32F103C8T6.

Don't worry, your existing hardware is still supported with zero changes and is
perfectly fine. Don't feel bad if you don't have the new PCB design.

New Compact PCB
---------------

This release adds a new PCB with less features, but that can be built entirely
by JLCPCB's assembly services. It does not require a Blue Pill as it integrates
the STM32 directly.

Total cost is around $50 for 5 units (this is the minimum amount you can buy).
Prices are of 07/2023 and may vary.

Sources for EasyEda, Gerber, BOM and component placement are included.

This PCB can also be connected using UltraSatan cables (IDC20 format), both for
sharing the port to other devices or being connected using an IDC20 cable.

Note that buying from JLCPCB does not imply any warranty of any form from
ACSI2STM authors. ACSI2STM authors don't receive any money from this.

It also includes a 3D printable enclosure to have a finished product.

This is now the official design, all Blue Pill based units are still supported
(and will be in the future) but it is discouraged to build new designs based on
blue pill boards because of clone/bad chip issues found on too many Blue Pill
boards available for sale. You **will** lose money buying these.

GemDrive loader program
-----------------------

GemDrive can now be loaded as a TOS program. The main reason to do that is
EmuTOS support since EmuTOS does not boot hard disk boot sectors.

EmuTOS loader
-------------

GemDrive can now boot `EMUTOS.SYS` from the 1st SD card slot. It needs a special
setup to reload GemDrive from within EmuTOS, described in
[gemdrive.md](doc/gemdrive.md).

PIO firmware
------------

Many Atari ST's have a broken DMA chip. The PIO firmware uses a protocol that
does not use DMA transfers at all. The price to pay is speed: it is 10x slower
and it does not support ACSI at all nor auto booting. It requires a special
driver `GEMDRPIO.PRG` provided in the release package.

Multiple devices support
------------------------

A lot of improvements and testing has been done to make sure ACSI2STM plays well
with other devices on the DMA port. This includes other ACSI2STM units in any
mode.

Changes since 4.12
------------------

Compatibility:

* Fixed SD card frequencies to 50MHz, 25MHz and 1MHz to match the actual
* Changed debug output speed to 1Mbps: helps with laggy USB-UART converters
  standard speeds
* Removed self-modifying code in GemDrive: it should now work with CPU cache
* Added support for TT-RAM in GemDrive
* Added support for up to 6 ACSI2STM units in `GEMDRIVE.PRG`
* Added support for PIO mode in `HDDFLASH.TOS`
* Verbose firmware is now less than 64k allowing to flash it with `HDDFLASH.TOS`
* Improved ACSI performance of some commands. Fixes multi device with GemDrive

Bug fixes:

* Found and fixed the root cause for memory corruptions with ACSI_FAST_DMA = 5
* Fixed GemDrive boot when ACSI id 0 is not an ACSI2STM unit
* Fixed a lot of issues when multiple hard drives and ACSI2STM units are used at
  the same time
* Introduced GemDrive command 0x09 to avoid crashes when reading boot sector
* Fixed GemDrive drive letter allocation
* Improved SD card hot swapping a lot
* Fixed and added `GEMDRIVE.PRG` to load GemDrive from desktop and `AUTO`
* Removed timeout in GemDrive boot program as it is useless
* Fixed command byte timeout handling
* Fixed fast CS/IRQ protocol implementation
* Code cleanup pass (dead code removal, code formating, comments review, ...)

Features:

* Boot `EMUTOS.SYS` on startup if present on the SD card
* Added PIO mode to GemDrive to work on broken DMA chips

Hardware:

* Added the *Compact PCB*
* Swapped ID_SHIFT jumper positions in software to match the actual Compact PCB
  configuration.
* Removed "full-featured" PCB as it's not really safe nor easy to build

Build chain:

* Arduino 2.x is now the official IDE
* arduino-cli is now the official build platform for release packages

Release package:

* Added back the whole history for 4.x in release_notes.md, as it should be
* Provide a ready to use GemDrive boot image for EmuTOS, both hard drive and
  floppy disk formats
* Reworked documentation to put more emphasis on the new PCB design
* Simplified documentation


4.12: Date handling fix
=======================

Fix a stupid bug that breaks dates with months between august and december.

Backported from upcoming 4.20.


4.11: Clock fix
===============

Very small bug fix for the realtime clock that didn't run correctly.
No other change.


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

