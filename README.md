ACSI2STM: Atari ST ACSI hard drive emulator
===========================================

This code provides a hard drive emulator for your Atari ST using an inexpensive STM32 microcontroller and a SD card.

The aim of this project is to be very easy to build, extremely cheap, reliable and safe for your precious vintage machine.

This is NOT as polished as the UltraSatan or other big name projects. Performance is worse (~300kB/s, varies a bit with SD
performance), features are practically non-existant.

The module supports up to 8 SD card readers, showing them as 8 different ACSI devices plugged in. You can choose the ACSI
ID of each SD card by soldering CS wires on the matching STM32 pin.

Hardware needed
---------------

 * A STM32F103C8T6 or compatible board. You can find them for a few dollars online. The "blue pill" works out of the box
   and the "black pill" requires minor modifications.
 * A USB-serial dongle for programming the STM32 chip, with a 3.3V USART.
 * One or more SD card port(s) for your STM32. You can also solder wires on a SD to microSD adapter.
 * One or more SD card(s).
 * A male DB19 port (you can modify a DB25 port to fit) with a ribbon cable.
 * (recommended) A protoboard PCB to solder all the components and wires together.


Software needed
---------------

 * The Arduino software with the STM32duino library.
 * A hard disk driver for your Atari ST (AHDI and ICD pro are tested).


Programming the STM32
---------------------

Set the USB dongle to 3.3V if you have a jumper for that. Connect TX to PA10, RX to PA11 and the GND pins together.

On the board itself, set the BOOT0 jumper to 1 to enable the flash bootloader.

In the Arduino interface, set the card type to 'Generic STM32F103C series', select your variant (C8 or CT), set
'Upload method' to serial, CPU speed to 72 MHz (very important), then select the correct serial port.

Then, you will be able to upload the program to the STM32.

Note: the debug output sends data at 115200bps. Set the serial monitor accordingly.

Note: Debian 9 has buggy driver for some USB-serial dongles. You should update your kernel to the latest backport
version if uploading fails for mysterious reasons.

Once the chip is programmed, you can switch the BOOT0 jumper back to 0.


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
 * Reset is not needed as the STM32 resets itself if it stays in an inconsistent state for more than 1 second.
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
|       4 | PB0   | SD 4 pin 1 or GND |
|       5 | PB1   | SD 5 pin 1 or GND |
|       6 | PB3   | SD 6 pin 1 or GND |
|       7 | PB4   | SD 7 pin 1 or GND |

In order to detect if a SD card reader is present or not, connect unused pins in the table above to GND.

For example, if you want 3 SD cards detected on ACSI IDs 0, 1 and 5:
 * Connect PA4 to pin 1 of the first SD card.
 * Connect PA3 to pin 1 of the second SD card.
 * Connect PB1 to pin 1 of the third SD card.
 * Connect PA2, PA1, PB0, PB3 and PB4 to GND.
 
Notes:

 * The SD card had 2 GND pins. I don't know if they have to be both grounded, maybe one wire is enough.
 * You should put a decoupling capacitor of about 100nF between VDD and VSS, as close as possible from the SD card pins.


Using on a "Black pill" STM32 board
-----------------------------------

If you have these cheap "STM32 minimum development boards" from eBay, Amazon, Banggood or other chinese sellers, chances are that
you have either a "blue pill" or a "black pill" board. The "blue" or "black" refers to the color of the PCB.

The problem with black pill designs is that the onboard LED is wired on PB12 instead of PC13, messing with data signals.

You will have to desolder the onboard LED (or its current-limiting resistor right under).

If you want an activity LED, put an external one with a 1k resistor in series on PC13.

Other boards were not tested and may require further adjustments.


Compile-time options
--------------------

The source code contains a few #define that you can change. They are described in the source itself.

Do not change ACSI pins without knowing exactly what you do. This code does direct port access in order to reach the required
speed for proper communication with the ST.


Creating a SD card
------------------

Download a floppy disk of ICD PRO drivers. They are available online as ST floppy images. Transfer it to a real floppy your ST can
read (or use a floppy simulator).

Boot the floppy, open the A floppy drive and run INSTALL.PRG. The program will create partitions and a boot sector automatically.

Now test the setup by ejecting the floppy and rebooting the emulated Atari. The desktop should have extra icons for your newly
created partitions (C, D, E, ...).

Alternatively, you can partition the drive manually with ICDFMT.PRG and make it bootable with HDUTILS.PRG. You should set
verification passes to 0 in ICDFMT to avoid the lengthy (and useless) surface scan.

Maximum partition sizes are the following:

 * 32MB for TOS 1.04 (ST and STF series)
 * 64MB for modern Linux kernels
 * 512MB for TOS 1.62 and 2.06 (STE series)

Other TOS versions were not tested.

With different drivers, you may have different limits. This bridge supports 32 bits access for disks bigger than 8GB.


Write issues
------------

Some people reported write issues with this project. There are 2 possible causes:

 * You have hardware problems in your ST

This one is common, it also happens with other products (SatanDisk / UltraSatan and other). It seems to be a hardware issue within some STs.

If you have such a machine, there is no known solution to work around the issue. If you have a machine with a "bad DMA" and a good logic analyzer (10 channels at 16MHz or better), I would be interested to have a full trace of a write to try some non-standard workarounds to make it work.

 * There is a timing problem within the pulseDrqRead function

The ACSI interface requires very narrow timings (200ns reaction time), reaching the limit of the STM32 chip. Because of that, I had to make some assumptions about the speed of the data bus and hardcode a very tight delay by repeating a write to the DRQ pin. This delay seems to vary depending on the Arduino library version and compiler optimizations, so you may need to tune the number of lines in pulseDrqRead (e.g. remove 3 or 4 lines in the middle of the function).


Why shipping Sd2CardX ?
-----------------------

This project includes a modified copy of the Sd2Card files provided by the Arduino library. I couldn't find a way to allow writing
to sector 0 with the standard code so I brought my own copy with the project (there is a #define but you can't overload it).

If you know a better library to access the SD card from a STM32 (especially if it can do background DMA transfers), contact me and
I may integrate it to the project.


Credits
-------

I would like to thanks the people that put invaluable information online that made this project possible in a finite amount of
time. Without them, this project would have not existed.

 * The http://atari.8bitchip.info website and his author, who also contributes on various forums.
 * The Hatari developpers. I used its source code as a reference for ACSI commands.
 * The UltraSatan project for their documentation.

The Sd2 files of this project have been copied from the Arduino SD library, also released under GPL v3. This has been done
to disable sector 0 protection.
