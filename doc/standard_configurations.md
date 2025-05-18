Standard configurations
=======================

This document lists a few recommended configurations, depending on your hardware
software and what you want out of it.

These templates are provided as starting points, it's possible to do things
differently to match your specific needs.


The "normal" ST
---------------

This will be the most common configuration.

### What you have

* A 520/1040 STF/STE: any "everything in the keyboard" variation
* One ACSI2STM unit
* No other device

### What you want to achieve

* Run desktop programs
* Save and load files
* Run hard drive compatible games

### How you should set things up

* Use the standard firmware for your ACSI2STM
* Plug the ACSI2STM unit at the back of your ST
* GemDrive will auto-load at boot, just use SD cards as you would use floppies
* Add extra drive icons to the desktop


Normal ST with ACSI images
--------------------------

### What you have

* A 520 or 1040 (any STF/STE variation)
* One ACSI2STM unit
* No other device
* A hard disk image file

### What you want to achieve

* Use the disk image as you would use a normal Atari hard disk

### How you should set things up

* Use the standard firmware for your ACSI2STM
* Plug the ACSI2STM unit at the back of your ST
* Rename your image `hd0.img` and put it in a folder named `acsi2stm` at the
  root of your SD card
* Insert the SD card into the first slot (SD0)


Mega ST / Mega STE / Stacy without internal hard drive
------------------------------------------------------

### What you have

* A machine comparable to the STF/STE with a different physical shape
* One ACSI2STM unit
* No internal hard drive
* No other device

### What you want to achieve

* Run desktop programs
* Save and load files
* Run hard drive compatible games

### How you should set things up

* Use the standard firmware for your ACSI2STM
* Add IDC20 header pins to your compact PCB
* Plug the ACSI2STM unit using a DB19-IDC20 cable to avoid clutter or forcing
  physical ports
* GemDrive will auto-load at boot, just use SD cards as you would use floppies


Machine with an internal hard drive
-----------------------------------

### What you have

* Any ST/STE/TT/Falcon or derivative with an internal hard drive
* One ACSI2STM unit

### What you want to achieve

* Boot on the internal hard drive, keep it on C:
* Copy files between the internal drive and SD cards
* Run programs from any drive

### How you should set things up

* If you have an ACSI hard drive (Mega STE), make sure your hard drive is on
  ACSI id 0 (this is the default)
* Make sure your computer runs normally without an ACSI2STM plugged in
* Copy `GEMDRIVE.PRG` to your `AUTO` folder on the internal drive
* Set the ID_SHIFT jumper of the ACSI2STM to position 1-3. You can put a solder
  blob on the small pads if you prefer
* Plug the ACSI2STM unit either directly or through a DB19-IDC20 cable,
  depending on your hardware
* Boot the computer, GemDrive should load from the `AUTO` folder and expose SD
  cards as new disk drives

[jumpers](jumpers.md) explains how to change ID_SHIFT.


Machine running EmuTOS
----------------------

EmuTOS doesn't read the boot sector of hard drives so GemDrive doesn't load
automatically.

### What you have

* A machine with EmuTOS in ROM
* One ACSI2STM unit with at least 2 SD card slots
* No internal hard drive
* No other device

### What you want to achieve

* Run desktop programs
* Save and load files
* Run hard drive compatible games

### How you should set things up

* On an empty SD card, create a folder named `acsi2stm`
* From the release archive, copy the file `images/acsi2stm-xxxx-hd0.img` to the
  folder
* Rename the image `hd0.img`
* Put this SD card into any ACSI2STM SD slot
* Install the ACSI2STM unit in a way that fits your hardware

### How to use

The image will be shown as C:. It contains the GemDrive driver in its `AUTO`
folder. Other SD slots will work in GemDrive mode and will be available starting
at L:.


Machine with a broken DMA chip
------------------------------

This is so commonplace that it's become a standard configuration !

### What you have

* A machine that displays bombs or exhibits weird behaviors when booting with an
  ACSI2STM unit plugged in
* A machine with a floppy drive (or a floppy drive emulator)

### What you want to achieve

* Run desktop programs
* Save and load files
* Run hard drive compatible games

### How you should set things up

* Flash your ACSI2STM unit with the *pio* firmware variant
* Create a boot floppy from the file `images/acsi2stm-xxxx-floppy.st`
* Boot from the floppy, it contains the PIO driver `GEMDRPIO.PRG` in its `AUTO`
  folder
