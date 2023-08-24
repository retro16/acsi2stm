Troubleshooting
===============

If you have an issue, check this place first.

First of all, ACSI2STM is not a hardware nor software vendor. It is **not** a
finished product that is guaranteed to work. Your old ST is also not guaranteed
to work. You need technical knowledge to assemble, test and debug the project.


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
  debug firmware outputs data at 2Mbps.

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


SD cards not detected / malfunctioning
--------------------------------------

Check in the debug output that the SD card are effectively detected. For
GemDrive, the SD card should be specified as "mountable". If the SD card is not
marked as "mountable" or marked as "bootable", then it will be set to ACSI mode.

The best cards are the most modern SDHC/SDXC cards. Reputable brands offer
better reliability. Be careful with the many bootleg/knockoffs, some of them
even include the whole packaging and look very convincing.

The SdFat library uses SD cards in SPI mode. Normally, all cards are compatible,
but some full size SD cards may not support this mode.

Some old SD cards don't work at 36MHz and will fall back at 12MHz.

If SD cards aren't detected, check connections and make sure you don't use a SD
slot board with logic level adapters for 5V Arduinos. Connections between the SD
card and the microcontroller must be direct.


Read-Only SD cards
------------------

You need to solder PB0..PB5 pins. See [hardware](hardware.md).

If you use the full featured PCB, you need solder blobs on JP0..JP3.


Programs not working in GemDrive mode
-------------------------------------

Unfortunately GemDrive isn't 100% compatible due to the way it works.

Mainly, most games and low level disk tools probably won't work. Games that
were adapted to work on hard disks should work though.

See [compatibility](compatibility.md) for information about software
compatibility.


"Bad DMA" chips
---------------

[This article](https://www.chzsoft.de/site/hardware/new-atari-ste-bad-dma-investigation/)
describes a phenomenon that introduces DMA issues on some ST. It mentions a
possible software workaround. GemDrive implemented this workaround, so it
should be immune to the issue.

For ACSI, if you use a modern driver, contact the developer. If you use an
old legacy driver, there is nothing you can do. Use GemDrive instead.

**Note:** ACSI2STM firmwares version 3.x and lower had random issues. Many
people were confused by this and thought that they had a bad DMA chip because of
this. 4.00 fixed the issue so it might be worth trying an up to date version on
older hardware that didn't work previously.


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
of 64k. Both kinds of chips will work, and only CBT6 (or 128k C8T6) will support
verbose mode (verbose mode requires 128k of flash).

STM32 series other than STM32F103 work differently and won't work without
modifying the code substantially.

It seems that JLCPCB / LCSC provides good quality STM32 chips, so the compact
PCB assembled by JLCPCB should work okay.

**Note:** Some STM32 didn't work with versions 3.x and lower, but this was
caused by a hardware issue in all STM32 (including good ones). A workaround was
implemented in version 4.00 so if you have old non-working ACSI2STM units,
updating to the latest version may fix your issues.
