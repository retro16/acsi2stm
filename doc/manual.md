ACSI2STM user manual
====================

ACSI2STM allows you to use SD cards as Atari ST ACSI hard drives. This manual will explain how to setup and use a SD card.


Powering the unit
-----------------

How to apply power depends on the unit you built or bought. There are a few things to make sure of:

 * When powering the unit via USB, make sure you do not use a data cable. The unit must be powered through a USB cable with no
   data line ("charge only" cables) or a charger that has nothing connected to its data lines (most "fast" chargers short their
   data lines or have resistors connected to them).

 * Power the ACSI2STM unit at the same time or before the Atari ST.

 * When power cycling the ST (turn off, then turn on), turn off the ACSI2STM unit. If you keep the unit powered, voltage on data
   lines may keep some chips inside the ST powered by the data lines, which will prevent a full cold boot from happening.
   Don't go too fast, wait at least 3 seconds before turning things back on. If you soldered the RST line to PA15, you have less
   risks to crash the ACSI2STM.


Checking whether you own an up to date ACSI2STM unit
----------------------------------------------------

To check the version of a 2.3 unit, simply plug the ACSI2STM unit to the ACSI port and boot with no SD card or floppy disk. A
message will be displayed, indicating the firmware version along with other information.

**WARNING**: Units based on the old 1.x firmware cannot be upgraded to 2.x because of an incompatibility. The hardware needs to be
changed to upgrade to the new version.


Making sure you use the right driver
------------------------------------

There are many hard disk drivers for the Atari ST out there. All of them come with their pros and cons.

Here is the list of the free drivers I'm aware of, in no particular order:

### Integrated ACSI2STM driver

Just plug the ACSI2STM, insert a non-bootable FAT12/FAT16 MS-DOS partitioned/formatted SD card and boot your Atari.

Pros:
 * Officially supported by ACSI2STM. Tested before each release.
 * Open source.
 * No installation, driver is built-in.
 * Reads ST floppy disk images easily (as C:).

Cons:
 * Unfinished.
 * Limited to FAT12/FAT16 partitions with 512 bytes sectors.
 * Hot swap has rough edges.
 * No support for BigDOS.
 * Poor set of tools.
 * Does not boot in strict mode.

### ICD PRO Festplatentreiber 6.55

Free (not open source) driver that works well and is very stable.

Pros:
 * Officially supported by ACSI2STM. Tested before each release.
 * Good set of tools.
 * Supports SD card hot swapping (the new SD card must have the same number of partitions).

Cons:
 * Incompatible with BigDOS.
 * Eats up memory like crazy if you leave cache enabled (disable cache, ACSI2STM is nearly as fast as memcpy).
 * Not open source.

### P.Putnik's ACSID07 driver (free, 2008 version)

Pros:
 * Supports MS-DOS partition tables.
 * Compatible with BigDOS.

Cons:
 * Supports only ACSI id 0.
 * Not 100% ACSI standard compliant, does funky stuff on boot (re-enables A1 mid-command).

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

The antique driver provided by Atari. While it *should* work, nobody seem to use it anymore.

Pros:
 * Authentic, "pure" Atari experience.
 * None, really.

Cons:
 * Unsupported by ACSI2STM. Meaning it is never tested, your mileage may vary.
 * Incompatible with BigDOS.
 * Supports only Atari partition tables.
 * Not open source.


Use a ready-made disk image
---------------------------

If you have a bootable hard disk image, the following sections will describe how to use it.

The file [hd0.zip](hd0.zip) provides an empty 15MB image that you can use as a starting point.

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

**Note**: You can also mount *.st floppy images ! Rename them to hd0.img and the integrated driver will read them easily. This
trick is limited to ordinary non-bootable data disks.


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

### Format a SD card for use with the integrated driver

The partition table must be a MBR type. You can create any number of partitions (up to 24), primary and extended.

The filesystem is mounted by TOS, so the usual TOS restrictions apply: FAT12 or FAT16, maximum 32767 clusters. The integrated
driver only supports 512 bytes sectors for now, which limits even more compatibility.

The integrated driver also supports non-partitioned disks (a single FAT filesystem spanning the entire disk).

Recommended settings for formating:

| Partition size | Filesystem type| Sector size | Sectors per clusters |
|---------------:|---------------:|------------:|---------------------:|
|          < 4M  |         FAT12  |        512  |                   2  |
|          < 8M  |         FAT12  |        512  |                   4  |
|         < 15M  |         FAT12  |        512  |                   8  |
|         < 31M  |         FAT16  |        512  |                   2  |
|         < 63M  |         FAT16  |        512  |                   4  |
|        < 127M  |         FAT16  |        512  |                   8  |
|        < 255M  |         FAT16  |        512  |                  16  |

### Create an ICD PRO image

There is a very good tutorial on [Jookie's home page](http://joo.kie.sk/?page_id=306).

**Hint**: To access files from within Hatari, use the GEMDOS drive feature.


Installing the integrated driver onto an image
----------------------------------------------

The integrated driver is incompatible with strict mode, so the only way to use it in strict mode is to install itdirectly onto a
disk image.

To do this, the image must be already compatible with the integrated driver and the first partition must start after sector 8.

On Windows, just drag the image onto the provided A2STBOOT.EXE file to make it bootable.

On Linux or MacOS, you need to compile the program from source. It has no weird dependencies beyond the normal C library.

**Notes**
 * This allows using the ACSI2STM driver on emulators such as Hatari.
 * Once installed, the usual embedded driver will not be used anymore. Make the disk non-bootable again to go back to the
   integrated driver.


Using the real-time clock
-------------------------

If your ACSI2STM unit comes with a battery, it can keep the time with the help of UltraSatan's clock tool.

Download [Jookie's UltraSatan clock tools](http://joo.kie.sk/wp-content/uploads/2013/05/clock.zip). Put the US_GETCL.PRG file in
your C:\AUTO folder so the clock is correctly set on boot. Use US_SETCL.PRG to set the clock.


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


The ACSI id selection jumper on the right works the same as in full featured mode


Firmware programming mode

     _______________________________
    |                     _         |
    |    o [==]       /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|



Strict mode
-----------

ACSI2STM offers extra features that can be dynamically turned on or off with the BOOT1 jumper near the reset button. Since these
features aren't 100% SCSI compliant, you can turn them off to have a strict implementation of the SCSI standard.

If BOOT1 is in the 0 position, extra features will be enabled. If BOOT1 is in position 1, extra features will be disabled.

The following features are disabled in strict mode:

 * Dummy boot sector if no SD card is present: displays a "No SD card" message on boot if no SD card is inserted.
 * Integrated driver.
 * Test pattern checking.
 * Remote payload execution: Ability to upload and run STM32 code from the Atari ST. This feature is not used.


Testing your unit
-----------------

### Quick self-test

If your unit is working, boot the Atari ST with no media inserted (no floppy, no SD card in the ACSI2STM). If you briefly see the
"No SD card" message, a quick DMA read/write test has been performed. If there is any error, it will be displayed and you will have
to press a key to continue.


### Using ACSITEST.TOS

This method does not require a fully working unit and will do more in-depth tests.

In the release package zip, you will find a tool named ACSITEST.TOS. Transfer it onto a floppy drive (or any other working drive)
and run it on your ST with the ACSI2STM connected.

The tool can also be run from a SD card inside the ACSI2STM, but in that case you need to be sure to put back the same SD card
before leaving the program, or simply reset the ST in case of doubt.

Once the tool is loaded in memory, the DMA port will be hot-pluggable and no SD card is needed for testing. This way you can test
many units at once or do changes on your unit without power cycling the ST all the time.

**Note**: The ACSI2STM unit must not be in strict mode to do a DMA check. Put the BOOT1 jumper in position 0.

Just press the key 0 to 7 to select which device to test (usually 0).

The following tests will be done:

 * Test unit ready. It will report media change events as well as no media (no SD card).
 * Inquiry. It will query the device string. It will check that the unit is a supported ACSI2STM unit.
 * Command pattern test. It will spam commands at high speed, both in read and write mode.
 * DMA pattern test. It will do 4k transfers, checking data integrity in both sides.
 * Interrupted command. This simulates the behavior of the old PPDRIVER by sending half a command, then resuming normal operation.
