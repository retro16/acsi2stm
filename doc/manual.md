ACSI2STM user manual
====================

ACSI2STM allows you to use SD cards as Atari ST ACSI hard drives. This manual
will explain how to setup and use a SD card.


Compatibility
-------------

ACSI2STM was successfully tested on the following hardware:

 * Atari 520 STF, TOS 1.04
 * Atari 1040 STE, TOS 1.62
 * Atari 1040 STE, TOS 2.06
 * Atari 1040 STE, EmuTOS (no driver needed)
 * Atari TT030


Quick start guide
-----------------

 * Plug the ACSI2STM module to the Atari ST's hard disk port.
 * Insert a SD card in the first SD slot.
 * Plug the power cable to the ACSI2STM.
 * Turn on the ST and press Shift+S repeatedly during boot to start the
   ACSI2STM setup tool.
 * Select the ACSI2STM device containing the SD card to format (press '0' for
   the first SD card).
 * Press Q for quick setup.
 * Press Y to confirm formating. This may take a few minutes.
 * Press Esc twice to exit the menu and reboot the ST.
 * The SD card will show up as C: on the desktop.
 * The SD card should be compatible with most modern computers.

See [a2setup.md](a2setup.md) for more details on the setup tool.


Use a ready-made disk image
---------------------------

If you have a bootable hard disk image, the following sections will describe how
to use it.

### Using the image directly

 * Use a SD card formatted for PC (FAT32/ExFAT).
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


Creating an ICD PRO image
-------------------------

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


Booting to another partition
----------------------------

The integrated driver allows selecting the boot partition.

During boot, press the key of the partition to be remapped as C:. This allows
having alternate sets of utilities started at boot, such as different desktop
accessories or different DESKTOP.INF files.

For example, if the SD cards provide C:, D: and E:, pressing the 'e' key during
boot will swap the E: and C: partitions.

Note that, while this feature is perfectly compatible with SD card hotplug,
switching the card providing the C: partition will remap drive letters in a
strange way. Also, unplugging then replugging the same card will revert
partitions to their normal drive letters, partition remapping won't carry over.


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


Checking whether you own an up to date ACSI2STM unit
----------------------------------------------------

To check the version of a recent unit, simply plug the ACSI2STM unit to the ACSI
port and boot with no SD card or floppy disk. A message will be displayed,
indicating the firmware version along with other information.

**WARNING**: See [hardware.md](hardware.md) if you wish to upgrade a 1.x or 2.x
unit to 3.x, you may need to make changes.


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


Flashing / upgrading the firmware
---------------------------------

**WARNING**: If you bought pre-built hardware, make sure that the firmware is
compatible with the hardware. In case of doubt, contact the seller to ask for
compatibility. Some boards might require special compilation options to work
correctly.

Programming via anything else than the serial bootloader is not supported and
will break the code. ST-link and the USB bootloader simply don't work for
various reasons, don't lose your time trying.

### Connect the hardware

You need a USB to USART converter supporting 3.3V operation.

![Compatible USART adapter](images/usb_serial.jpg)

Depending on the hardware you have, there are multiple possibilities:

 * If you have the official PCB and a compatible USART converter, you can just
   plug the converter directly on the PCB.
 * If your PCB contains dedicated firmware flash pins, please consult its user
   manual (if any) or contact the manufacturer of the PCB.
 * If you can detach the Blue Pill from the PCB:
   * Connect a 3.3V or 5V power source on the Blue Pill (you can power via USB)
   * Connect PA10 on the Blue Pill to the TX pin of your adapter
   * Connect PA9 on the Blue Pill to the RX pin of your adapter
   * Connect any GND on the Blue Pill to the GND pin of your adapter

### Put the Blue Pill in firmware flash mode

Set the Blue Pill jumpers to the firmware flash position, then press the reset
button on the board.

     _______________________________
    |                     _         |
    |    o [==]       /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o) reset   \/ |_|       -|--
    |_______________________________|

### Use STM32FLASH

You need [stm32flash](https://sourceforge.net/projects/stm32flash/files/).

The easiest way to run the command is to unzip the acsi2stm release zip file and
copy the stm32flash binary in the same directory as acsi2stm-X.XX.ino.bin file.

Now, the STM32 is in firmware flash mode. Use the **stm32flash** command to
upload the new firmware:

On Windows:

    stm32flash -w acsi2stm-X.XX.ino.bin COM1:

On Linux:

    ./stm32flash -w acsi2stm-X.XX.ino.bin /dev/ttyUSB0

COM1: and /dev/ttyUSB0 are just examples, you need to find the actual port of
the USART adapter. There is a lot of tutorials online explaining how to find
this.

### Using the Arduino IDE

You can also use the Arduino IDE if it is properly set up. See
[compiling.md](compiling.md) for  more information.
