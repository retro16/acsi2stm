Running EmuTOS on the ACSI2STM
==============================

[EmuTOS](https://emutos.sourceforge.io/) offers an open source alternative to
the builtin ROM TOS.

EmuTOS provides an integrated driver for standard ACSI drives formated with
FAT16 (and even FAT32). It removes a lot of the TOS limitations and bugs. This
is the preferred OS for file operations and running compatible GEM software.

Some programs aren't compatible with it, but the situation is gradually
improving. The bottom line is: if it works with EmuTOS, run it under EmuTOS.

The tutorials below are condensed versions of the 
[EmuTOS Installation Guide](https://emutos.github.io/manual/#installation).

Installing EmuTOS
=================

There are many ways to run EmuTOS. Below you will find small tutorials to
install it in a few different ways.

Installing in a ROM chip
------------------------

This is clearly the best way to run EmuTOS on STE or any computer with 256k
ROM chips. It leaves more free RAM, it boots faster, it cannot be corrupted by a
mistake, ...

You should make your ROM chip switchable (e.g. switch between EmuTOS and
original TOS) to keep Atari TOS because of EmuTOS limited compatibility with
Atari software.

A tutorial on how to do this is way beyond the scope of this documentation
though, but mentioning this alternative is worth it as it's the best way to run
EmuTOS.

Installing on a floppy
----------------------

This is the easiest way to run EmuTOS.

 * Download the emutos-prg zip file
   [from here](https://emutos.sourceforge.io/download.html)
 * Extract `EMUTOS.PRG` into the `AUTO` folder of a floppy disk
 * Run the floppy on your ST

Installing as a hard disk image
-------------------------------

Check out [EmuTOS Bootloader](https://github.com/czietz/emutos-bootloader).

Use the provided `sdcard-acsi.img` image file. [manual.md](manual.md) describes
how to use a hard disk image, either copying it onto the SD card or writing the
image onto the SD card.

Installing is as straight-forward as restoring an image file to an SD card. A
couple of things to note about this method:

* This will wipe all the data from the card, but the linked website offers
  other methods of installation.
* This method does not play nice with multiple partitions yet, so is only
  really suitable if you're happy with a single partition on your card.

To skip booting from the SD card, hold down the **Alternate** key when turning
on your computer.

Installing on a hard disk
-------------------------

 * Download the emutos-prg zip file
   [from here](https://emutos.sourceforge.io/download.html)
 * Format the hard disk for Atari using any tool you like. See [a2setup.md] to
   use the ACSI2STM setup tool
 * Extract `EMUTOS.PRG` into the `AUTO` folder of the `C:` partition
 * Reboot on the hard disk, EmuTOS will start

Installing on a hard disk boot sector
-------------------------------------

This provides the fastest boot speed (except ROM image of course). As this
replaces the hard disk driver, its features (such as boot partition selection)
will be removed.

 * Format the hard disk for Atari using any tool you like. EmuTOS is compatible
   with virtually every partition/filesystem for the ST.
 * Install EmuTOS in the `AUTO` folder of `C:` (see above)
 * Download
  [EmuTOS Bootloader](https://github.com/czietz/emutos-bootloader/releases)
 * Extract `INSTALL.PRG` and `INSTALL.RSC` from the `INSTALLER` folder to C:\
 * Boot EmuTOS using the AUTO method
 * Run `INSTALL.PRG`
 * Select "File/Locate EMUTOS.PRG"
 * Select `AUTO\EMUTOS.PRG`
 * Select "File/Install to C:"
 * Quit the program
 * Delete `AUTO\EMUTOS.PRG` as EmuTOS is now loaded from `C:\EMUTOS.SYS`

