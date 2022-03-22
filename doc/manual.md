ACSI2STM 2.3 user manual
========================

ACSI2STM allows you to use SD cards as Atari ST ACSI hard drives. This manual will explain how to setup and use a SD card.

**Note**: this manual applies for ACSI2STM version 2.3 and above. The instructions may or may not work for older versions or
modified versions.


Powering the unit
-----------------

How to apply power depends on the unit you built or bought. There are a few things to make sure of:

 * When powering the unit via USB, make sure you do not use a data cable. The unit must be powered through a USB cable with no
   data line ("charge only" cables) or a charger that has nothing connected to its data lines (most "fast" chargers short their
   data lines or have resistors connected to them).

 * Power the ACSI2STM unit at the same time or before the Atari ST.

 * When power cycling the ST (turn off, then turn on), turn off the ACSI2STM unit. If you keep the unit powered, voltage on data
   lines may keep some chips inside the ST powered by the data lines, which will prevent a full cold boot from happening.
   Don't go too fast, wait at least 3 seconds before turning things back on.


Checking whether you own an up to date ACSI2STM unit
----------------------------------------------------

To check the version of a 2.3 unit, simply plug the ACSI2STM unit to the ACSI port and boot with no SD card or floppy disk. A
message will be displayed, indicating the firmware version along with other information.

**WARNING**: Units based on the old 1.x firmware cannot be upgraded to 2.x because of an incompatibility. The hardware needs to be
changed to upgrade to the new version.


Use a ready-made disk image
---------------------------

If you have a bootable hard disk image, the following sections will describe how to use it.

### Using the image directly

 * Create a folder named *acsi2stm* at the root of the SD card.
 * Copy your image inside that folder.
 * Rename your image *hd0.img*.
 * Don't forget to properly unmount/eject your SD card before removing it from your computer.
 * Insert the SD card in the ACSI2STM unit.
 * Turn everything on.
 * Enjoy.

The file format is the same used by the Hatari emulator. You can test your image in Hatari: go to the menu, click *Hard disks*,
then click *Browse* on the first line (*ACSI HD 0*) then reboot the emulated ST. You can even use the image directly on the SD card
by opening hd0.img from within Hatari !

When working with disk images, the SD card can be of any size, as long as it uses a standard filesystem (FAT, FAT32 or ExFAT). The
ST only sees the content of the hd0.img file.


### Read-only image

If you wish to make your image read-only (for example, to test untrusted software), simply tick the "Read-only" box in the file
properties of your image file.


### Transfering a disk image to a raw SD card

Using a raw SD card is a bit faster than copying the image file.

To transfer images to the disk, you can use [Raspberry Pi Imager](https://www.raspberrypi.com/software/):

 * Open Raspberry Pi Imager.
 * Click *Choose Os* under *Operating System*.
 * Select *Use custom* in the list.
 * Select the image file you wish to transfer.
 * Under *Storage*, click *Choose storage*.
 * Select the SD card you want to write to.
 * Click *Write* to start writing. **Existing data on the SD card will be erased**. Click *Yes* to confirm.
 * The SD card can now be used on the ST.


### Revert a SD card to the normal PC format

If you have a SD card formatted for the Atari (or any other weird format), the Raspberry Pi Imager can revert it back to the
standard format so you can use it again on your PC (or any other device).

 * Open Raspberry Pi Imager.
 * Click *Choose Os* under *Operating System*.
 * Select *Erase* in the list.
 * Under *Storage*, click *Choose storage*.
 * Select the SD card you want to write to.
 * Click *Write* to start writing. **Existing data on the SD card will be erased**. Click *Yes* to confirm.
 * The SD card is now formatted to the standard format.


Create your own image
---------------------

**Note**: if you don't have a floppy drive (or a floppy disk), you can use the Hatari emulator to prepare it.

The doc folder contains a zip file [empty_images.zip](empty_images.zip) that contains 3 empty files that you can use as a starting
point.

There is a very good tutorial on [Jookie's home page](http://joo.kie.sk/?page_id=306). To access files from within Hatari, use the
GEMDOS drive feature.


Using the real-time clock
-------------------------

If your ACSI2STM unit comes with a battery, it can keep the time with the help of UltraSatan's clock tool.

Download [Jookie's UltraSatan clock tools](http://joo.kie.sk/wp-content/uploads/2013/05/clock.zip). Put the US_GETCL.PRG file in
your C:\AUTO folder so the clock is correctly set on boot. Use US_SETCL.PRG to set the clock.


Strict mode
-----------

ACSI2STM offers extra features that can be dynamically turned on or off with the BOOT1 jumper near the reset button. Since these
features aren't 100% SCSI compliant, you can turn them off to have a strict implementation of the SCSI standard.

If BOOT1 is in the 0 position, extra features will be enabled. If BOOT1 is in position 1, extra features will be disabled.

The following features are affected:

 * Dummy boot sector if no SD card is present: displays a "No SD card" message on boot if no SD card is inserted.
 * Boot sector overlay if a non-bootable SD card is inserted: displays a message and waits for a key if trying to boot a
   non-bootable SD card.
 * Remote payload execution: Ability to upload and run STM32 code from the Atari ST. This feature is not used.


Testing your unit
-----------------

Boot the Atari ST with no media inserted (no floppy, no SD card in the ACSI2STM).
