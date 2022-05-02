ACSI2STM user manual
====================

ACSI2STM allows you to use SD cards as Atari ST ACSI hard drives. This manual
will explain how to setup and use a SD card.


Powering the unit
-----------------

How to apply power depends on the unit you built or bought. There are a few
things to make sure of:

 * When powering the unit via USB, make sure you do not use a data cable. The
   unit must be powered through a USB cable with no data line ("charge only"
   cables) or a charger that has nothing connected to its data lines (most
   "fast" chargers short their data lines or have resistors connected to them).

 * Power the ACSI2STM unit at the same time or before the Atari ST.

 * When power cycling the ST (turn off, then turn on), turn off the ACSI2STM
   unit. If you keep the unit powered, voltage on data lines may keep some chips
   inside the ST powered by the data lines, which will prevent a full cold boot
   from happening. Don't go too fast, wait at least 3 seconds before turning
   things back on. If you soldered the RST line to PA15, you have less risks to
   crash the ACSI2STM.


Checking whether you own an up to date ACSI2STM unit
----------------------------------------------------

To check the version of a recent unit, simply plug the ACSI2STM unit to the ACSI
port and boot with no SD card or floppy disk. A message will be displayed,
indicating the firmware version along with other information.

**WARNING**: Units based on the old 1.x firmware cannot be upgraded to 2.x
because of an incompatibility. The hardware needs to be changed to upgrade to
the new version.

Units built for the 2.x firmware should be upgraded to use the RST line.


Use a ready-made disk image
---------------------------

If you have a bootable hard disk image, the following sections will describe how
to use it.

### Using the image directly

 * Create a folder named *acsi2stm* at the root of the SD card.
 * Copy your image inside that folder.
 * Rename your image *hd0.img*.
 * Don't forget to properly unmount/eject your SD card before removing it from
   your computer.
 * Insert the SD card in the ACSI2STM unit.
 * Turn everything on.
 * Enjoy.

The file format is the same used by the Hatari emulator. You can test your image
in Hatari: go to the menu, click *Hard disks*, then click *Browse* on the first
line (*ACSI HD 0*) then reboot the emulated ST. You can even use the image
directly on the SD card by opening hd0.img from within Hatari !

When working with disk images, the SD card can be of any size, as long as it
uses a standard filesystem (FAT, FAT32 or ExFAT). The ST only sees the content
of the hd0.img file.

**Note**: You can also mount *.st floppy images ! Rename them to hd0.img and the
integrated driver will read them easily. This trick is limited to ordinary
non-bootable data disks.


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
again on your PC (or any other device).

 * Open Raspberry Pi Imager.
 * Click *Choose Os* under *Operating System*.
 * Select *Erase* in the list.
 * Under *Storage*, click *Choose storage*.
 * Select the SD card you want to write to.
 * Click *Write* to start writing. **Existing data on the SD card will be
   erased**. Click *Yes* to confirm.
 * The SD card is now formatted to the standard format.

You can also use the ACSI2STM setup tool to reformat the SD card for a PC.

See [a2setup.md](a2setup.md) for more details on the setup tool.


Create your own image
---------------------

### Format a SD card with the integrated driver

 * Boot the ST and press Shift+S on boot to start the ACSI2STM setup tool.
 * Select the ACSI2STM device containing the SD card to format.
 * Press Q for quick setup.
 * Press Esc to exit the menu and reboot the ST.
 * The SD card will show up as C: on the desktop.

See [a2setup.md](a2setup.md) for more details on the setup tool.

### Create an ICD PRO image

There is a very good tutorial on
[Jookie's home page](http://joo.kie.sk/?page_id=306).

**Hint**: To access files from within Hatari, use the GEMDOS drive feature.


Installing the integrated driver onto an image
----------------------------------------------

The integrated driver is incompatible with strict mode, so the only way to use
it in strict mode is to install it directly onto a disk image.

To do this, the image must be already compatible with the integrated driver and
the first partition must start after sector 8.

Boot into the ACSI2STM setup tool (Shift+S on boot), select your device, press
P to enter the partitioning tool, then press I to install the driver onto the
SD card.

If you cannot boot the ACSI2STM setup tool (it is unavailable in strict mode),
you can transfer `A2SETUP.TOS` by other means and run it from GEM.

See [a2setup.md](a2setup.md) for more details on the setup tool.


Using the real-time clock
-------------------------

If your ACSI2STM unit comes with a battery, it can keep the time. The
integrated driver will set the time automatically.

To set the clock, enter the ACSI2STM setup tool.

See [a2setup.md](a2setup.md) for more details on the setup tool.


Strict mode
-----------

ACSI2STM offers extra features that can be dynamically turned on or off with the
BOOT1 jumper near the reset button. Since these features aren't 100% SCSI
compliant, you can turn them off to have a strict implementation of the SCSI
standard.

If BOOT1 is in the 0 position, extra features will be enabled. If BOOT1 is in
position 1, extra features will be disabled.

The following features are disabled in strict mode:

 * Dummy boot sector if no SD card is present: displays a "No SD card" message
   on boot if no SD card is inserted.
 * Integrated driver.
 * Test pattern checking.
 * Remote payload execution: Ability to upload and run STM32 code from the Atari
   ST. This feature is not used.


Choosing a hard disk driver
---------------------------

There are many hard disk drivers for the Atari ST out there. All of them come
with their pros and cons.

Here is the list of the free drivers I'm aware of, in no particular order:

### Integrated ACSI2STM driver

Just plug the ACSI2STM, insert a non-bootable FAT12/FAT16 MS-DOS
partitioned/formatted SD card and boot your Atari.

Pros:
 * Officially supported by ACSI2STM. Tested before each release.
 * Open source.
 * No installation, driver is built-in.
 * Reads ST floppy disk images easily (as C:).

Cons:
 * Does not support TOS extended partitions.
 * No support for BigDOS.

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

Normal mode, full featured. ACSI id 0 to 4

     _______________________________
    |                     _         |
    |   [==] o        /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 1 to 5, full featured

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|||| <- Jumper here
    |     (o)         \/ |_|       -||||
    |_______________________________|


ACSI id 2 to 6, full featured

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |   [==] o       /  \| |       -|||| <- Jumper here
    |                \  /| |       -||||
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 3 to 7, full featured

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|||| <- Jumper here
    |   [==] o       /  \| |       -||||
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


Strict mode, ACSI id 0 to 4

     _______________________________
    |                     _         |
    |   [==] o        /\ | |       -|--
    |    o [==]      /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


Strict mode, ACSI id 1 to 5

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |    o [==]      /  \| |       -|--
    |                \  /| |       -|||| <- Jumper here
    |     (o)         \/ |_|       -||||
    |_______________________________|


The ACSI id selection jumper on the right works the same as in full featured
mode


Firmware programming mode

     _______________________________
    |                     _         |
    |    o [==]       /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|

