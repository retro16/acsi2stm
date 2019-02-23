Atari ST ACSI hard drive emulator
=================================

This code provides a hard drive emulator for your Atari ST using an inexpensive STM32 microcontroller and a SD card.

The aim of this project is to be very easy to build, extremely cheap, reliable and safe for your precious vintage machine.

This is NOT as polished as the UltraSatan or other big name projects. Performance is worse (~300k/s, varies a bit with SD
performance), features are practically non-existant, and you have to partition the SD card using an emulator.

Hardware needed
---------------

 * A STM32F103C8T6 or compatible board. You can find them for a few dollars online. The "blue pill" works out of the box and the "black pill" requires minor modifications.
 * A SD card port for your STM32. You can also solder wires on a SD to microSD adapter.
 * A SD card.
 * A male DB19 port (you can modify a DB25 port to fit) with a ribbon cable.
 * (recommended) A protoboard PCB to solder all the components and wires together.


Software needed
---------------

 * The Arduino software with the STM32duino library.
 * A hard disk driver for your Atari ST (AHDI and ICD pro are tested).


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
|  10  | PA12  | IRQ | Interrupt        |
|  11  | GND   | GND | Ground           |
|  12  | (nc)  | RST | Reset            |
|  13  | GND   | GND | Ground           |
|  14  | PA8   | ACK | Acknowledge      |
|  15  | GND   | GND | Ground           |
|  16  | PB6   | A1  | Address bit      |
|  17  | GND   | GND | Ground           |
|  18  | (nc)  | R/W | Read/Write       |
|  19  | PA11  | DRQ | Data request     |

Notes:

 * GND is soldered together on the ST side. You can use only one wire for ground.
 * Reset is not needed as the STM32 resets itself if it stays in an inconsistent state for too long.
 * Keep the wires short. I had strange behavior with cables longer than 10cm/3 inches.
 * The read/write pin is not needed.
 * You can build a DB19 out of a DB25 by cutting 6 pins on one side and part of the external shielding. Male DB25 were used for parallel port cables or serial port sockets.

Connecting the SD card
----------------------

SD card pins


       ------------------------
      /|  |  |  |  |  |  |  | |
     /_|01|02|03|04|05|06|07|8|
    |  |__|__|__|__|__|__|__|_|
    |09|                      |
    |__|                      |


Use this table to match pins on the SD card port and the STM32:

| SD  | STM32 | PIN |
|:---:|:-----:|:---:|
| 01  | PA4   | CS  |
| 02  | PA7   | MOSI|
| 03  | GND   | VSS |
| 04  | +3.3V | VDD |
| 05  | PA5   | CLK |
| 06  | GND   | VSS |
| 07  | PA6   | MISO|
| 08  | (nc)  | RSV |
| 09  | (nc)  | RSV |

Notes:

 * The SD card had 2 GND pins. I don't know if they have to be both grounded, maybe one wire is enough.
 * Multiple SD cards could be added by using unused pins as supplementary chip select.


Using on a "Black pill" STM32 board
-----------------------------------

If you have these cheap "STM32 minimum development boards" from eBay, Amazon, Banggood or other chinese sellers, chances are that
you have either a "blue pill" or a "black pill" board. The "blue" or "black" refers to the color of the PCB.

The problem with black pill designs is that the onboard LED is wired on PB12 instead of PC13, messing with data signals.

You will have to desolder the onboard LED (or its current-limiting resistor right under).

If you want an activity LED, put an external one with a 1k resistor in series on PC13.

Other boards were not tested and may require further adjustments.


Creating a SD card
------------------

This project does not support enough commands to be used by the ICD partitioning tool, so you will have to use an emulator.

I describe the process for Hatari running under linux.

Create an image of the desired size, less than the size of your target SD card. Use a small image like 50MB for the first attempt.

    dd if=/dev/zero of=hdd.img bs=1M count=50

For windows, use any tool that creates blank files of a given size. The file size must be a multiple of 512 bytes.

Download a floppy image of ICD PRO drivers. They are available online as ST floppy images.

Download a TOS image that matches the machine you use.

Setup Hatari so it uses the correct TOS image, the ICD PRO floppy as drive A, the hdd.img file you just generated as a ACSI HD
image and disable GEMDOS.

Boot the emulated Atari ST, open the A floppy drive and run INSTALL.PRG. The program will create partitions and a boot sector
automatically.

Now test the setup by ejecting the virtual floppy image and rebooting the emulated Atari. The desktop should have extra icons for
your newly created partitions (C, D, E, ...).

When you are happy with this setup, close Hatari and transfer the file onto the SD card by using the following command:

    sudo dd if=hdd.img of=/dev/sdX

Replace /dev/sdX with the device of your SD card drive (cat /proc/partitions will display the size of the disks, it might help).
Double-check that you typed it correctly, you might damage your other drives if you put the wrong sdX entry !!!

For Windows users, use a tool like Win32 Disk Imager.

The card will be ready to use. Put it in the STM32 card slot and boot your real Atari with it !


Credits
-------

I would like to thanks the people that put invaluable information online that made this project possible in a finite amount of
time. Without them, this project would have not existed.

 * The http://atari.8bitchip.info website and his author, who also contributes on various forums.
 * The Hatari developpers. I used its source code as a reference in some places.
 * The UltraSatan project for their documentation.

