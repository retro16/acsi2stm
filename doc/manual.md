ACSI2STM user manual
====================

ACSI2STM allows you to use SD cards as Atari ST ACSI hard drives. This manual
will explain how to setup and use a SD card.


Two operating modes
-------------------

ACSI2STM can work in 2 different modes: ACSI and GemDrive.

### GemDrive mode

Inspired by Hatari's GEMDOS drive, GemDrive mounts the SD card on the STM32,
then exposes the filesystem to the Atari. This removes most limitations and
brings a much more stable experience, but compatibility is somewhat reduced in
some cases.

GemDrive supports FAT16, FAT32 and ExFAT with no size limit. It supports only
one partition per SD card.

### ACSI mode

ACSI mode tries to mimic an old ACSI hard drive as closely as possible. The SD
card is accessed like a block device and must be specially formated for Atari.

You need to install a hard disk driver to work in ACSI mode. This is detailed
in the sections below.

ACSI mode can work either directly on SD cards, or on hard disk images.


Hardware compatibility
----------------------

ACSI2STM was successfully tested in ACSI mode on the following hardware:

* Atari 520 STF, TOS 1.04
* Atari 1040 STE, TOS 1.62
* Atari 1040 STE, TOS 2.06
* Atari 1040 STE, EmuTOS (no driver needed)
* Atari TT030

GemDrive mode is limited to Atari ST and STE (no TT or Falcon). Tos >= 1.04 is
strongly recommended.


Quick start guide
-----------------

This will use GemDrive.

* Plug the ACSI2STM module to the Atari ST's hard disk port.
* Insert a standard SD card in the first SD slot.
* Plug the power cable to the ACSI2STM.
* Turn on the ST.
* The SD card will show up as C: on the desktop.
* If you have more than 1 SD card slot, they will show up as D:, E:, ...


Use a ready-made ACSI disk image
--------------------------------

If you have a bootable hard disk image, the following sections will describe how
to use it.

### Using the image directly

* Use a SD card formatted for PC (FAT32/ExFAT).
* Create a folder named `acsi2stm` at the root of the SD card.
* Copy your image inside that folder.
* Rename your image `hd0.img`.
* Insert the SD card in the ACSI2STM unit.
* Turn everything on.
* Enjoy.

The file format is the same used by the Hatari emulator. You can test your image
in Hatari: go to the menu, click *Hard disks*, then click *Browse* on the first
line (*ACSI HD 0*) then reboot the emulated ST. You can even use the image
directly on the SD card by opening `hd0.img` from within Hatari !

When working with disk images, the SD card can be of any size, as long as it
uses a standard filesystem (FAT, FAT32 or ExFAT). The ST only sees the content
of the `hd0.img` file.


### Read-only image

If you wish to make your image read-only (for example, to test untrusted
software), simply tick the "Read-only" box in the file properties of your image
file.


### Transfering a disk image to a raw SD card

Using a raw SD card is a bit faster than copying the image file.

To transfer images to the disk, you can use
[Raspberry Pi Imager](https://www.raspberrypi.com/software/):

* Open Raspberry Pi Imager.
* Click *Choose Os* under *Operating System*.
* Select *Use custom* in the list.
* Select the image file you wish to transfer.
* Under *Storage*, click *Choose storage*.
* Select the SD card you want to write to.
* Click *Write* to start writing. **Existing data on the SD card will be
  erased**. Click *Yes* to confirm.
* The SD card can now be used on the ST.


### Revert a SD card to the normal PC format

If you have a SD card formatted for the Atari (or any other weird format), the
Raspberry Pi Imager can revert it back to the standard format so you can use it
again on your PC or in GemDrive mode.

* Open Raspberry Pi Imager.
* Click *Choose Os* under *Operating System*.
* Select *Erase* in the list.
* Under *Storage*, click *Choose storage*.
* Select the SD card you want to write to.
* Click *Write* to start writing. **Existing data on the SD card will be
  erased**. Click *Yes* to confirm.
* The SD card is now formatted to the standard format.


Creating an ICD PRO image
-------------------------

ICD PRO is the recommended driver to use in ACSI mode.

There is a very good tutorial on
[Jookie's home page](http://joo.kie.sk/?page_id=306).

**Hint**: To access files from within Hatari, use the GEMDOS drive feature.


Strict mode
-----------

ACSI2STM tries to autodetect ACSI / GemDrive mode, but you may want to force
ACSI mode in some cases.

Use the BOOT1 jumper on the STM32 (the jumper near the reset button)

If BOOT1 is in the 0 position, GemDrive will be enabled. If BOOT1 is in
position 1, ACSI mode will be forced.


Checking whether you own an up to date ACSI2STM unit
----------------------------------------------------

To check the version of a recent unit, simply plug the ACSI2STM unit to the ACSI
port and boot with no SD card or floppy disk. A message will be displayed,
indicating the firmware version along with other information.

**WARNING**: See [hardware.md](hardware.md) if you wish to upgrade a 1.x or 2.x
unit to 3.x or later: you may need to make changes.


Software compatibility table
----------------------------

This section explains why some programs are compatible and some are not.

### Software properly using the operating system

These programs use the normal GEMDOS interface to access disk drives. This
means that they have no path restrictions and follow the rules.

**Programs usually working like this:**

* Most desktop programs
* A few games with no disk protection
* Basically everything using the standard file selector to open files

**Compatible with**

* Internal floppy disk (A:)
* External floppy disk (B:)
* ACSI hard disk
* GemDrive
* Hatari GEMDOS

### Software relying on bugs

These programs use the normal GEMDOS interface to access disk drives but rely
on weird patterns to work properly.

**Compatible with**

* Internal floppy disk (A:)
* External floppy disk (B:)
* ACSI hard disk
* GemDrive

**Incompatible with**

* Hatari GEMDOS

### Software doing BIOS access

These programs access low level disks using BIOS or XBIOS interfaces.

**Programs usually working like this:**

* Most disk utilities
* Maybe some very weirdly programmed games

**Compatible with**

* Internal floppy disk (A:)
* External floppy disk (B:)
* ACSI hard disk

**Incompatible with**

* GemDrive
* Hatari GEMDOS

### Software doing direct floppy controller access

These programs directly access the floppy controller.

**Programs usually working like this:**

* Most games
* Most programs relying on copy protected floppy disks
* Floppy disk utilities (copy/format/repair)

**Compatible with**

* Internal floppy disk (A:)
* (not always) External floppy disk (B:)

**Incompatible with**

* ACSI hard disk
* GemDrive
* Hatari GEMDOS


Choosing a hard disk driver for ACSI mode
-----------------------------------------

There are many hard disk drivers for the Atari ST out there. All of them come
with their pros and cons.

Here is the list of the free drivers I'm aware of, in no particular order:


### ICD PRO Festplatentreiber 6.55

Free (not open source) driver that works well and is very stable.

Pros:
* Officially supported by ACSI2STM. Tested before each release.
* Good set of tools.
* Supports SD card hot swapping (the new SD card must have the same number of
  partitions).

Cons:
* Incompatible with BigDOS.
* Eats up memory like crazy if you leave cache enabled (disable cache, ACSI2STM
  is nearly as fast as memcpy).
* Not open source.


### P.Putnik's ACSID07 driver (free, 2008 version)

Pros:
* Supports MS-DOS partition tables.
* Compatible with BigDOS.

Cons:
* Supports only ACSI id 0.
* Not 100% ACSI standard compliant, does funky stuff on boot (re-enables A1
  mid-command).

### Uwe Seimet's HDDriver

Pros:
* Fully supporting the SCSI command set.
* Supports more than 1 LUN per drive.
* Very high quality set of tools.
* Supports MS-DOS partition tables.
* Compatible with BigDOS.

Cons:
* The free version is very limited in functionality.
* Does not support ACSI2STM officially (later versions should work).
* Not open source.

### AHDI

The antique driver provided by Atari. While it *should* work, nobody seem to use
it anymore.

Pros:
* Authentic, "pure" Atari experience.
* None, really.

Cons:
* Unsupported by ACSI2STM. Meaning it is never tested, your mileage may vary.
* Incompatible with BigDOS.
* Supports only Atari partition tables.
* Not open source.


Changing operation modes with jumpers
-------------------------------------

The STM32 blue pill has 2 jumpers. You can access to different operation modes
just by switching these jumpers to different places.

**WARNING:** Do not attempt any other combination than what is explained here.
You might damage your product.

**Note**: The *Compact PCB* has its own jumpers since it doesn't use a Blue
Pill. See [compact_pcb_manual.md](compact_pcb_manual.md) for details on its
jumpers.

ACSI id 0 to 4, GemDrive enabled

     _______________________________
    |                     _         |
    |   [==] o        /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 1 to 5, GemDrive enabled

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -||"| <- Jumper here
    |     (o)         \/ |_|       -||_|
    |_______________________________|


ACSI id 2 to 6, GemDrive enabled

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |   [==] o       /  \| |       -||"| <- Jumper here
    |                \  /| |       -||_|
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 3 to 7, GemDrive enabled

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -||"| <- Jumper here
    |   [==] o       /  \| |       -||_|
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 0 to 4, GemDrive disabled - ACSI mode forced

     _______________________________
    |                     _         |
    |   [==] o        /\ | |       -|--
    |    o [==]      /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


GemDrive disabled, other ACSI ids

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |    o [==]      /  \| |       -|--
    |                \  /| |       -||"| <- Jumper here
    |     (o)         \/ |_|       -||_|
    |_______________________________|


The ACSI id selection jumper on the right works the same as in GemDrive mode


Firmware programming mode

     _______________________________
    |                     _         |
    |    o [==]       /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|

