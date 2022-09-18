Running EmuTOS on the ACSI2STM
==============================

[EmuTOS](https://emutos.sourceforge.io/) offers an open source alternative to
the builtin ROM TOS.

EmuTOS provides an integrated driver for standard ACSI drives formated with
FAT16. It removes a lot of the TOS limitations and bugs. This is the preferred
OS for file operations and running compatible GEM software.

Some programs aren't compatible with it, but the situation is gradually
improving. The bottom line is: if it works with EmuTOS, run it under EmuTOS.


Installing EmuTOS
=================

There are many ways to run EmuTOS. Below you will find small tutorials to
install it in a few different ways.

[EmuTOS Installation Guide](https://emutos.github.io/manual/#installation)
provides information to install EmuTOS with various methods.

 * Installing in a ROM chip: Very hard to do and requires hardware
   modifications, but by far the most stable option and reduces RAM usage.
 * Installing in the AUTO folder: Easy to do but be careful of AUTO ordering.

[EmuTOS Bootloader](https://github.com/czietz/emutos-bootloader) is an
alternative, providing an image named `sdcard-acsi.img` that can be copied
directly as `hd0.img` for the ACSI2STM (see [manual.md](manual.md)).


Installing EmuTOS for the ACSI2STM integrated driver
====================================================

The ACSI2STM bootloader includes the functionality of the EmuTOS bootloader.

 * Download [emutos-prg](https://emutos.sourceforge.io/download.html)
 * In the zip file, choose `emutosXX.prg` matching your language. You can also
   choose the multilingual `emutos.prg` file.
 * Extract the chosen `emutosXX.prg` to the root of your Atari boot filesystem.
 * Rename the file to `EMUTOS.SYS`.
 * Boot on that partition.

This is compatible with partition remapping, so you can put `EMUTOS.SYS` on the
D: partition and hit the D key at boot to start EmuTOS.
