Creating your own ACSI2STM hardware
===================================

This page helps hardware designers to design new hardware from scratch. If you
simply want to build the official PCB, see [build_pcb.md](build_pcb.md)


Hardware needed
---------------

 * A STM32F103C8T6 or compatible board. You can find them for a few dollars
   online. The "blue pill" works out of the box and the older "black pill"
   requires minor modifications.
 * A USB-serial dongle for programming the STM32 chip, with a 3.3V USART.
 * One or more SD card port(s) for your STM32. You can also solder wires on a SD
   to microSD adapter.
 * One or more SD card(s).
 * A male DB19 port (you can modify a DB25 port to fit) with a ribbon cable.
 * One 10k-100k resistor if you need SD card hotplug capabilities.
 * One 100nF decoupling capacitor for the SD card (optional but recommended).
 * Do *NOT* connect USB data lines on the STM32. Use the +5V or +3.3V pin to
   power it if you are unsure. To power from USB, you need to modify the blue
   pill itself (see below).

You can use the PCB design provided in the PCB folder. See
[build_pcb.md](build_pcb.md) for more information.


Modifying the Blue Pill board
-----------------------------

While this section is optional, you may want to do a few modifications to your
blue pill board:

### Removing R10

R10 is a 1.5k pull-up resistor required for USB operation of the STM32.
Unfortunately R10 is connected to PA12 and this is connected to a very
important data line on the ST ACSI connector.

This resistor may cause problems on some DMA chips, also this resistor tends to
feed power from the data line back to the STM32 power pin if you turn on the
Atari before the ACSI2STM unit, which is bad.

You may want to remove R10 entirely. For this you can either try to unsolder it
(a quite difficult operation) or just destroy it with cutting pliers, then
clean up residues. Check with an ohmmeter between the 2 pads of R10, you should
see an open loop.

Removing R10 will compromise the ability to use USB on that blue pill board.


### Removing R9 and R11

R9 and R11 are mounted in series between the STM32 and the USB port data lines.

Removing these resistors allow powering the STM32 with a USB cable.

Of course, removing R9 and R11 will compromise the ability to use USB on that
blue pill board. USB is not used at all in ACSI2STM.


Building the ACSI connector
---------------------------

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
|  12  | PA15  | RST | Reset (optional) |
|  13  | GND   | GND | Ground           |
|  14  | PA12  | ACK | Acknowledge      |
|  15  | GND   | GND | Ground           |
|  16  | PB6   | A1  | Address bit      |
|  17  | GND   | GND | Ground           |
|  18  | (nc)  | R/W | Read/Write       |
|  19  | PA11  | DRQ | Data request     |

**WARNING**: Pinout changed since v1.0: PA8 and PA12 are swapped.

**Notes**:

 * GND is soldered together on the ST side. You can use a single wire for
   ground.
 * Reset is not needed as the STM32 resets itself if it stays in an inconsistent
   state for more than 2.5 seconds.
 * Keep the wires short. I had strange behavior with cables longer than 10cm (4
   inches).
 * The read/write pin is not needed.
 * You can build a DB19 out of a DB25 by cutting 6 pins on one side and part of
   the external shielding. Male DB25 are easy to find because they were used for
   parallel port cables or serial port sockets.
 * You will have to power the STM32 separately (if you use USB, don't use a
   cable with data lines connected).


Connecting the SD cards
-----------------------

SD card pins

                  100nF      10k-100k
                  _||__    _/\  /\  /\__+3.3V
                 | ||  |  |   \/  \/
        _________|_____|__|___
      /|  |  |  |  |  |  |  | |
     /_|01|02|03|04|05|06|07|8|
    |  |__|__|__|__|__|__|__|_|
    |09|                      |
    |__|                      |
    |                        ||
    |                   Lock ||


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

If you want to use multiple SD cards, connect all SD card pins to the same STM32
pins except CS (SD pin 1).

Here is the table that indicates the STM32 pin for each CS pin of the different
SD cards:

| ACSI ID | STM32 | Connect to |
|--------:|:------|------------|
|       0 | PA4   | SD 0 pin 1 |
|       1 | PA3   | SD 1 pin 1 |
|       2 | PA2   | SD 2 pin 1 |
|       3 | PA1   | SD 3 pin 1 |
|       4 | PA0   | SD 4 pin 1 |

Leave unused CS pins unconnected.

**WARNING**: Pinout changed in v2.0: PA0 was added, PBx were removed and unused
SD card CS pins *must not* be grounded anymore.

**Notes**:

 * If you need to hot swap your SD card, you need to put a 10k-100k pull-up
   resistor between +3.3V and PA6. A single resistor is enough if you have
   multiple SD card slots.
 * The ACSI2STM module **will** respond to all ACSI IDs, whether a SD card is
   inserted or not. Change ACSI_SD_CARDS and ACSI_FIRST_ID in
   acsi2stm/acsi2stm.h to change ACSI IDs, or see the table below to disable IDs
   by connecting pins to +3.3V.
 * The SD card had 2 GND pins. Connecting only one is enough.
 * You should put decoupling capacitors of about 100nF between VDD and VSS, as
   close as possible from the SD card pins. If you use a pre-built SD slot
   module it should be properly decoupled already.
 * Some microSD slot boards for Arduino have logic level adapters to allow using
   SD cards on 5V Arduino boards. This will reduce speed and compatibility.
   Connect SD card pins directly to the STM32 pins for best results.
 * microSD to SD adapters are a quick, cheap way to obtain a microSD reader.
   Simply solder on the SD adapter pads.

Some pins can be used to configure each SD card slot:

| ACSI ID | STM32 | Connect to enable    | Connect to disable |
|--------:|:------|----------------------|--------------------|
|       0 | PB0   | SD0 write lock / GND | +3.3V              |
|       1 | PB1   | SD1 write lock / GND | +3.3V              |
|       2 | PB3   | SD2 write lock / GND | +3.3V              |
|       3 | PB4   | SD3 write lock / GND | +3.3V              |
|       4 | PB5   | SD4 write lock / GND | +3.3V              |

When the pin is connected to GND, the SD card will be writable. When the pin is
left floating, the SD card will be read-only. You can connect this pin to the
physical write lock switch if you have a full size SD card reader with this
ability. This logic can be inverted or disabled using the ACSI_SD_WRITE_LOCK
define in acsi2stm/acsi2stm.h.

When the pin is connected to +3.3V, the SD card is completely disabled (the ACSI
ID is freed for other devices).


Battery-powered real-time clock
-------------------------------

To use the RTC feature, you need to connect a lithium battery to the VB pin of
the STM32. Using a CR2032 with a standard battery holder is recommended.


Using on an old "Black pill" STM32F103 board
--------------------------------------------

If you have these cheap "STM32 minimum development boards" from eBay, Amazon,
Banggood or other chinese sellers, chances are that you have either a "blue
pill" or a "black pill" board. "blue" or "black" refers to the color of the PCB.

**WARNING**: There are newer STM32F4xx boards also called "black pill". These
newer boards are currently not tested. This section refers to older
STM32F103C8T6 black pill boards.

The problem with black pill designs is that the onboard LED is wired on PB12
instead of PC13, messing with data signals.

You will have to desolder the onboard LED (or its current-limiting resistor
right under).

If you want an activity LED, put an external one with a 1k resistor in series on
PC13.

Other boards such as red pills were not tested and may require further
adjustments.


Required changes for older ACSI2STM hardware
============================================

If you have a unit built for 1.x or 2.x firmware, you need to make changes.


Changes required for 2.xx units
-------------------------------

### Add a reset line

You need to connect the ACSI pin 12 (RST) to PA15. It is optional, but stability
will be greatly improved by doing that.

### Fix SD cards appearing read-only

Solder PB0, PB1, PB3, PB4 and/or PB5 to GND to make SD cards permanently
read-write. See the table mentioning these pins above for more details.

Alternatively, you can rebuild a firmware with ACSI_SD_WRITE_LOCK set to 0 to
ignore write lock switch completely.


Changes required for 1.xx units
-------------------------------

 * Do all changes required for 2.xx units
 * Swap PA8 and PA12

