*Version 2.1: More reliability upgrades*

*Beware, the pinout has changed since version 1.0*

ACSI2STM: Atari ST ACSI hard drive emulator
===========================================

This code provides a hard drive emulator for your Atari ST using an inexpensive STM32 microcontroller and a SD card.

The aim of this project is to be very easy to build, extremely cheap, reliable and safe for your precious vintage machine.

The module supports up to 5 SD card readers, showing them as 5 different ACSI devices plugged in. You can choose the ACSI
ID of each SD card by soldering CS wires on the matching STM32 pin.

It can work in 2 ways:
 * Expose a raw SD card as a hard disk to the Atari.
 * Expose a hard disk image file to the Atari.


Hardware needed
---------------

 * A STM32F103C8T6 or compatible board. You can find them for a few dollars online. The "blue pill" works out of the box
   and the "black pill" requires minor modifications.
 * A USB-serial dongle for programming the STM32 chip, with a 3.3V USART.
 * One or more SD card port(s) for your STM32. You can also solder wires on a SD to microSD adapter.
 * One or more SD card(s).
 * A male DB19 port (you can modify a DB25 port to fit) with a ribbon cable.
 * (recommended) A protoboard PCB to solder all the components and wires together.
 * Do *NOT* connect USB data lines on the STM32. Use the +5V or +3.3V pin to power it if you are unsure.

Note: some people reported problems with STM32 clones. I have many variants of the blue pill STM32, all of them work exactly the
same. Variants I had and that worked: round and rectangle reset buttons, some chips marked STM32F / 103 and other marked
STM32 / F103. If anyone has concrete proof of misbehaving clones and information on how to spot them, feel free to contact me
or create an issue on GitHub to let people know about that.


Software needed
---------------

 * The Arduino software with the Roger Clark Melbourne STM32 library.
 * The SdFat Arduino library by Bill Greiman.
 * A hard disk driver for your Atari ST (AHDI and ICD pro are tested).


Installing software
-------------------

Install the [STM32 library](https://github.com/rogerclarkmelbourne/Arduino_STM32/wiki/Installation). The doc says that it only
works on Arduino 1.8.5 but that does seems to work with more recent versions too.

In the Tools / Manage Libraries menu of the Arduino interface, search for "SdFat" and install "SdFat by Bill Greiman".

In the Tools menu of the Arduino interface, select the following:

 * Board: Generic STM32F103C series
 * Variant: STM32F103C8
 * Upload method: Serial
 * CPU speed: 72MHz (normal)
 * Optimize: Faster (-O2)
 * Port: your USB serial dongle

Note: you can use any setting in the "Optimize" menu. O2 is recommended for fastest performance, O3 does not bring any speed
improvement but generates much bigger code.

If you have different options in the Tools menu, it may be because you don't have the correct board installed.

Then, you will be able to upload the program to the STM32.


Programming the STM32
---------------------

Set the USB dongle to 3.3V if you have a jumper for that. Connect TX to PA10, RX to PA9 and the GND pins together.

On the board itself, set the BOOT0 jumper to 1 to enable the serial flash bootloader. Reset the STM32 then click Upload.

Once the chip is programmed, switch the BOOT0 jumper back to 0.

Note: the debug output sends data at 115200bps. Set the serial monitor accordingly.


Building the ACSI cable
-----------------------

ACSI pin numbers, looking at the male connector pins:

    ---------------------------------
    \ 01 02 03 04 05 06 07 08 09 10 /
     \ 11 12 13 14 15 16 17 18 19  /
       ---------------------------

Use this table to match pins on the ACSI port and the STM32:

| ACSI | STM32 | PIN | Description      |
|:----:|:-----:|:---:|------------------|
|  01  | PB8   | D0  | Data 0 (LSB)     |
|  02  | PB9   | D1  | Data 1           |
|  03  | PB10  | D2  | Data 2           |
|  04  | PB11  | D3  | Data 3           |
|  05  | PB12  | D4  | Data 4           |
|  06  | PB13  | D5  | Data 5           |
|  07  | PB14  | D6  | Data 6           |
|  08  | PB15  | D7  | Data 7 (MSB)     |
|  09  | PB7   | CS  | Chip Select      |
|  10  | PA8   | IRQ | Interrupt        |
|  11  | GND   | GND | Ground           |
|  12  | (nc)  | RST | Reset            |
|  13  | GND   | GND | Ground           |
|  14  | PA12  | ACK | Acknowledge      |
|  15  | GND   | GND | Ground           |
|  16  | PB6   | A1  | Address bit      |
|  17  | GND   | GND | Ground           |
|  18  | (nc)  | R/W | Read/Write       |
|  19  | PA11  | DRQ | Data request     |

**WARNING**: Pinout changed in v2.0: PA8 and PA12 are swapped.

Notes:

 * GND is soldered together on the ST side. You can use a single wire for ground.
 * Reset is not needed as the STM32 resets itself if it stays in an inconsistent state for more than 2 seconds.
 * Keep the wires short. I had strange behavior with cables longer than 10cm (4 inches).
 * The read/write pin is not needed.
 * You can build a DB19 out of a DB25 by cutting 6 pins on one side and part of the external shielding. Male DB25
   are easy to find because they were used for parallel port cables or serial port sockets.
 * You will have to power the STM32 separately (e.g. with a USB cable).


Connecting the SD cards
-----------------------

SD card pins


        ______________________
      /|  |  |  |  |  |  |  | |
     /_|01|02|03|04|05|06|07|8|
    |  |__|__|__|__|__|__|__|_|
    |09|                      |
    |__|                      |


Use this table to match pins on the SD card port and the STM32:

| SD  | STM32 | PIN |
|:---:|:-----:|:---:|
| 01  | PA4 * | CS  |
| 02  | PA7   | MOSI|
| 03  | GND   | VSS |
| 04  | +3.3V | VDD |
| 05  | PA5   | CLK |
| 06  | GND   | VSS |
| 07  | PA6   | MISO|
| 08  | (nc)  | RSV |
| 09  | (nc)  | RSV |

If you want to use multiple SD cards, connect all SD card pins to the same STM32 pins except CS (SD pin 1).

Here is the table that indicates the STM32 pin for each CS pin of the different SD cards:

| ACSI ID | STM32 | Connect to        |
|--------:|:------|-------------------|
|       0 | PA4   | SD 0 pin 1 or GND |
|       1 | PA3   | SD 1 pin 1 or GND |
|       2 | PA2   | SD 2 pin 1 or GND |
|       3 | PA1   | SD 3 pin 1 or GND |
|       4 | PA0   | SD 4 pin 1 or GND |

Leave unused CS pins unconnected.

**WARNING**: Pinout changed in v2.0: PA0 was added, PBx were removed and unused SD card CS pins *must not* be grounded anymore.

For example, if you want 3 SD cards detected on ACSI IDs 0, 1 and 4:
 * Connect PA4 to pin 1 of the first SD card.
 * Connect PA3 to pin 1 of the second SD card.
 * Connect PA0 to pin 1 of the third SD card.
 * Leave PA1 and PA2 unconnected.

Notes:

 * The SD card had 2 GND pins. I don't know if they have to be both grounded, maybe one wire is enough.
 * You should put a decoupling capacitor of about 100nF between VDD and VSS, as close as possible from the SD card pins.
 * If you need other ACSI IDs, you can change the sdCs array in the source code. See "Compile-time options" below.
 * CS pins must be on GPIO port A (PA pins).


Using on a "Black pill" STM32 board
-----------------------------------

If you have these cheap "STM32 minimum development boards" from eBay, Amazon, Banggood or other chinese sellers, chances are that
you have either a "blue pill" or a "black pill" board. "blue" or "black" refers to the color of the PCB.

The problem with black pill designs is that the onboard LED is wired on PB12 instead of PC13, messing with data signals.

You will have to desolder the onboard LED (or its current-limiting resistor right under).

If you want an activity LED, put an external one with a 1k resistor in series on PC13.

Other boards were not tested and may require further adjustments.


Compile-time options
--------------------

The file acsi2stm.h contains a few #define that you can change. They are described in the source itself.

Settings that you might wish to change:

 * ACSI_DEBUG: Enables debug output on the serial port. Moderate performance penalty.
 * ACSI_VERBOSE: Requires ACSI_DEBUG. Logs all commands on the serial port. High performance penalty.
 * ACSI_DUMP_LEN: Requires ACSI_VERBOSE. Dumps N bytes for each DMA transfer. It helps finding data corruption. Even higher performance penalty.
 * ACSI_SERIAL: The serial port used for debug output.
 * AHDI_MAX_BLOCKS: Limits the number of SD card blocks exposed to the ST. This may be useful to test specific setups or emulate an old hard drive of a specific size.
 * ACTIVITY_LED: The pin to use as an activity LED.
 * IMAGE_FILE_NAME: The image file to use as a hard disk image on the SD card.
 * ACSI_ACK_FILTER: Enables filtering the ACK line, adding a tiny latency. May improve DMA write reliability at the expense of write speed.
 * ACSI_CS_FILTER: Enables filtering on the CS line, adding a tiny latency. This is necessary to sample the data bus at the right time. Adjust this if commands are corrupt.

If you need a reference debug output, see the debug_output.txt file. This contains a full trace of a standard ICD PRO setup booting.


Creating a SD card
------------------

Download a floppy disk of ICD PRO drivers. They are available online as ST floppy images. Transfer it to a real floppy your ST can
read (or use a floppy simulator).

Boot the floppy, open the A floppy drive and run INSTALL.PRG. The program will create partitions and a boot sector automatically.

Now test the setup by ejecting the floppy and rebooting the Atari. The desktop should have extra icons for your newly
created partitions (C, D, E, ...).

Alternatively, you can partition the drive manually with ICDFMT.PRG and make it bootable with HDUTILS.PRG. You should set
verification passes to 0 in ICDFMT to avoid the lengthy (and useless) surface scan.

Maximum partition sizes are the following:

 * 32MB (65532 sectors) for TOS 1.04 (ST and STF series)
 * 64MB for modern Linux kernels
 * 512MB (1048527 sectors) for TOS 1.62 and 2.06 (STE series)

Other TOS versions were not tested.

With different drivers, you may have different limits. This bridge supports 32 bits access for disks bigger than 8GB.


Working with image files
------------------------

Instead of using a raw SD card, you can use an image file instead.

Place a file named acsi2stm.img at the root of a standard SD card. The file must not be empty and must be a multiple of 512 bytes
to be detected as an image.

If the image file is in use, the ACSI unit name will end in IMG or I(atari logo) if it's bootable. In that case, the reported size
is the size of the image, not the size of the SD card.

The image is exposed as a raw device with no header. This is the same format as used in the Hatari emulator, making the image
directly compatible. You can also transfer data between a raw SD card and an image using tools like Win32 Disk Imager (for Windows)
or the dd command under Linux.

File system size limitations only apply on the Atari file system inside the image. The SD card itself can be of any size and it can
contain any amount of data other than the image itself.

The only downside to use images is performance. There will be a big performance impact when using images because of the extra file
system layer.


Credits
-------

I would like to thanks the people that put invaluable information online that made this project possible in a finite amount of
time. Without them, this project would have not existed.

 * The http://atari.8bitchip.info website and his author, who also contributes on various forums.
 * The Hatari developpers. I used its source code as a reference for ACSI commands.
 * The UltraSatan project for their documentation.
 * Sr Antonio, Edu Arana, Frederick321, Ulises74, Maciej G., Olivier Gossuin and Marcel Prisi for their very detailed feedback
   that helped me a lot for fine tuning the DRQ/ACK signals and other various aspects of the projects.

