Troubleshooting
===============

If you have an issue, check this place first.

First of all, ACSI2STM is not a hardware nor software vendor. It is **not** a
finished product that is guaranteed to work, though it's very mature now.
Your old ST is also not guaranteed to work. You need technical knowledge to
assemble, test and debug the project. Hopefully, this documentation provides all
the information you will need to troubleshoot issues.


Reporting issues
----------------

You can report issues on the GitHub project page. Feedback is welcome.

Things that you should do before reporting an issue:

* Check this page.
* Check if similar issues were not already solved.
* The project is well tested and mature. If the issue is trivial (i.e. nothing
  works), please research what you could have done differently from the
  documented configuration and mention it in the GitHub issue.
* Try to reproduce the issue in the simplest possible case.
* Flash the debug firmware and capture its output.
* If your hardware never worked correctly, check signals with an oscilloscope if
  possible.


"Nothing works" - where to start ?
----------------------------------

ACSI2STM will display a message on the ST screen during boot. If it doesn't
appear, check this section.

### Things to check first

* The power LED must be on, bright and steady at all times. If not you have a
  power supply issue.
* The activity LED must stay on when the ST is off. If it is not, you have an
  issue with the STM32 (bad firmware upload ? hardware issue ?)
* The activity LED must turn off nearly immediately when powering the ST on. If
  it doesn't, you may have a hardware fault on the ST or a bad STM32 chip.
* Flash the debug firmware in case of issues. Debug messages help a lot. The
  debug firmware outputs data at 1Mbps.

### Check that your ST actually works

If you don't have a working hard disk (or emulator) to test your port, here is
what you can do:

With nothing connected to the DB19 HD port, the following signals must be
present during the boot process (after the first floppy disk access and before
the desktop appears):

* RST must be high and steady
* CS must pulse low exactly 8 times, pulses are around 250ns long and spaced by
  about 50ms (more or less)
* A1 must pulse low from time to time. A1 must be low anytime CS pulses low.
* R/W must be high when CS pulses low
* IRQ, DRQ and ACK must be high around CS pulses
* See [protocols](protocols.md) and [hardware](hardware.md) for technical
  details that will help you do all the necessary checks.

Check these signals with a logic analyzer or (better) a digital oscilloscope.

You will need a digital oscilloscope with single capture mode and at least 20MHz
bandwidth.

If CS, A1 and IRQ works, but DRQ/ACK doesn't, try the PIO firmware variant (see
[firmware](firmware.md)).


SD cards not detected / malfunctioning
--------------------------------------

Check in the debug output that the SD card are effectively detected. For
GemDrive, the SD card should be specified as "mountable". If the SD card is not
marked as "mountable" or marked as "bootable", then it will be set to ACSI mode.

The best cards are the most modern SDHC/SDXC cards. Reputable brands offer
better reliability. Be careful with the many bootleg/knockoffs, some of them
even include the whole packaging and look very convincing.

Some lower grade SD cards seem to be unable to cooperate: as soon as you plug
more than 1 card on the unit, it fails. If that's the case, use reputable brands
for your microSD cards.

The SdFat library uses SD cards in SPI mode. Normally, all cards are compatible,
but some full size SD cards may not support this mode.

Some old SD cards don't work at 50MHz and will fall back at 25MHz.

If SD cards aren't detected, check connections and make sure you don't use a SD
slot board with logic level adapters for 5V Arduinos. Connections between the SD
card and the microcontroller must be direct.

If you need slower speed, change `ACSI_SD_MAX_SPEED` to *25* or to *1* in
`acsi2stm.h` and recompile the firmware.


Read-Only SD cards
------------------

You need to solder PB0..PB5 pins. See [hardware](hardware.md).

If you can't change hardware, change `ACSI_SD_WRITE_LOCK` to *0* in `acsi2stm.h`
and recompile the firmware.


Programs not working in GemDrive mode
-------------------------------------

Unfortunately GemDrive isn't 100% compatible due to the way it works.

Mainly, most games and low level disk tools probably won't work. Games that
were adapted to work on hard disks should work though.

See [compatibility](compatibility.md) for information about software
compatibility.


No debug output with debug/verbose firmware variants
----------------------------------------------------

First, check that you effectively have a debug variant. GemDrive mentions this
on its splash screen on the ST.

Make sure you have the correct settings on your serial port:

* 1000000 bauds (1Mbps)
* 8 bits
* 1 stop bit
* no parity

If you need a slower speed, change `ACSI_SERIAL_SPEED` in `acsi2stm.h' and
recompile the firmware.


Random errors while copying a lot of files
------------------------------------------

TOS has a poor FAT filesystem implementation, with a lot of bugs. This gets
better with each new version, especially TOS 2.06, but it still has issues.

Some workaround programs were released, patching various parts of the filesystem
but this may have adverse effects with GemDrive:

* FOLDR100.PRG (and its variants)
* CACHE064.PRG (and its variants)
* BigDOS

Even with this, the filesystem is laden with bugs, memory leaks, bad error code
handling and other quirks.

The best way to limit possible interaction between these patching tools is to
load GemDrive through `GEMDRIVE.PRG` and make sure it's loaded after all these
tools. That way, access to GemDrive drives will be done with pristine system
calls.

The safest solution is to stay away from TOS/ACSI as much as possible and use
GemDrive only. If you really need to do ACSI file management, use EmuTOS.


Issues with multiple ACSI2STM units on the same computer
--------------------------------------------------------

It should be possible to use multiple units at the same time when using ACSI
strict mode. Just make sure you don't have ACSI id conflicts (use ID_SHIFT).

MegaSTE with an internal ACSI hard drive reserves ACSI id 0 for its drive by
default. Set ID_SHIFT on the ACSI2STM to avoid conflicts.


"Bad DMA" chips
---------------

"The" bad DMA issue is in fact a collection of slightly different hardware
faults that happen on many variants of ST's.

[This article](https://www.chzsoft.de/site/hardware/new-atari-ste-bad-dma-investigation/)
describes a phenomenon that introduces DMA issues on some ST. It mentions a
possible software workaround. GemDrive implemented this workaround, so it
should be immune to the issue.

For ACSI, if you use a modern driver, contact the developer. If you use an
old legacy driver, there is nothing you can do. Use GemDrive instead.

Despite all these precautions, it seems that some Atari really have defective
chips. This is very difficult to diagnose. If your ACSI2STM unit is working on
one atari and not another, you can suspect the Atari. All ST and STE with TOS
versions between 1.04 and 2.06 work exactly the same way. ACSI2STM units seem to
work equally well on buffered and unbuffered DMA ports if the computer is
healthy.

**Warning:** ACSI2STM firmwares version 3.x and lower had random issues. Many
people were confused by this and thought that they had a bad DMA chip because of
this. New versions fixed many subtle bugs so it might be worth trying an up to
date version on older hardware that didn't work previously.

### Workaround for bad DMA

ACSI2STM provides a special firmware that doesn't use DMA at all: this is called
the PIO variant. Only GemDrive works in that mode.

You need to load GemDrive through `GEMDRPIO.PRG` because that mode cannot be
automatically started at boot.

This mode offers less performance: 50-100KB/s instead of 500-1500KB/s for DMA.
It's still plenty fast for these old machines, and certainly faster than floppy
drives or older hard drives.


The problem of STM32 clones / variants
--------------------------------------

Most STM32 clones won't work with ACSI2STM. The DMA code makes very heavy usage
of timers and the STM32 DMA engine, even using undocumented features. All of
this is very specific to the STM32F103 chip.

You really need a quality source of STM32F103 chips, beware of fake chips. Chip
shortage really increased the odds of buying fake chips, so be careful.

CH32F103 chips are known not to work.

Some official STM32 chips are sold as STM32F103C8T6 but in reality they are
STM32F103CBT6. The only difference is that the chip provides 128k flash instead
of 64k. Both kinds of chips will work equally well with the same binary firmware
image.

STM32 series other than STM32F103 work differently and won't work without
modifying the code substantially.

It seems that JLCPCB / LCSC provides good quality STM32 chips, so the compact
PCB assembled by JLCPCB should work okay.

**Note:** Some STM32 didn't work with versions 3.x and lower, but this was
caused by a hardware issue in all STM32 (including good ones). A workaround was
implemented in version 4.00 so if you have old non-working ACSI2STM units,
updating to the latest version may fix your issues.
