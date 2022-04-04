Creating your own ACSI2STM hardware
===================================


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
|  12  | (nc)  | RST | Reset            |
|  13  | GND   | GND | Ground           |
|  14  | PA12  | ACK | Acknowledge      |
|  15  | GND   | GND | Ground           |
|  16  | PB6   | A1  | Address bit      |
|  17  | GND   | GND | Ground           |
|  18  | (nc)  | R/W | Read/Write       |
|  19  | PA11  | DRQ | Data request     |

**WARNING**: Pinout changed in v2.0: PA8 and PA12 are swapped.

**Notes**:

 * GND is soldered together on the ST side. You can use a single wire for ground.
 * Reset is not needed as the STM32 resets itself if it stays in an inconsistent state for more than 2.5 seconds.
 * Keep the wires short. I had strange behavior with cables longer than 10cm (4 inches).
 * The read/write pin is not needed.
 * You can build a DB19 out of a DB25 by cutting 6 pins on one side and part of the external shielding. Male DB25 are easy to find
   because they were used for parallel port cables or serial port sockets.
 * You will have to power the STM32 separately (if you use USB, don't use a cable with data lines connected).


Connecting the SD cards
-----------------------

SD card pins


        ______________________
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

If you want to use multiple SD cards, connect all SD card pins to the same STM32 pins except CS (SD pin 1).

Here is the table that indicates the STM32 pin for each CS pin of the different SD cards:

| ACSI ID | STM32 | Connect to |
|--------:|:------|------------|
|       0 | PA4   | SD 0 pin 1 |
|       1 | PA3   | SD 1 pin 1 |
|       2 | PA2   | SD 2 pin 1 |
|       3 | PA1   | SD 3 pin 1 |
|       4 | PA0   | SD 4 pin 1 |

Leave unused CS pins unconnected.

**WARNING**: Pinout changed in v2.0: PA0 was added, PBx were removed and unused SD card CS pins *must not* be grounded anymore.

**Notes**:

 * If you need to hot swap your SD card, you need to put a 47k-100k pull-up resistor between +3.3V and PA6.
 * The ACSI2STM module **will** respond to all ACSI IDs, whether a SD card reader is connected or not. Change ACSI_SD_CARDS and
   ACSI_FIRST_ID in acsi2stm/acsi2stm.h to change ACSI IDs.
 * The SD card had 2 GND pins. I don't know if they have to be both grounded, maybe one wire is enough.
 * You should put decoupling capacitors of about 100nF and 10uF (in parallel) between VDD and VSS, as close as possible from the
   SD card pins. If you use a pre-built SD slot module it should be properly decoupled already.
 * If you need other ACSI IDs, you can change the sdCs array in the source code. See "Compile-time options" below.
 * CS pins must be on GPIO port A (PA pins).
 * Some microSD slot boards for Arduino have logic level adapters to allow using SD cards on 5V Arduino boards. This will reduce
   speed and compatibility. Connect SD card pins directly to the STM32 pins.
 * microSD to SD adapters are a quick, cheap way to obtain a microSD reader. Simply solder on the SD adapter pads.

Some pins can be used to configure each SD card slot:

| ACSI ID | STM32 | Connect to       | Connect to disable |
|--------:|:------|------------------|--------------------|
|       0 | PB0   | SD 0 write lock  | +3.3V              |
|       1 | PB1   | SD 1 write lock  | +3.3V              |
|       2 | PB3   | SD 2 write lock  | +3.3V              |
|       3 | PB4   | SD 3 write lock  | +3.3V              |
|       4 | PB5   | SD 4 write lock  | +3.3V              |

When the pin is connected to GND, the SD card will be read-only. When the pin is left floating, the SD card will be writable. You
can connect this pin to the physical write lock switch if you have a full size SD card reader with this ability.
When the pin is connected to +3.3V, the SD card is completely disabled (the ACSI ID is freed for other devices).

Battery-powered real-time clock
-------------------------------

To use the RTC feature, you need to connect a lithium battery to the VB pin of the STM32. Using a CR2032 with a standard battery
holder is recommended.


Using on an old "Black pill" STM32 board
----------------------------------------

If you have these cheap "STM32 minimum development boards" from eBay, Amazon, Banggood or other chinese sellers, chances are that
you have either a "blue pill" or a "black pill" board. "blue" or "black" refers to the color of the PCB.

**WARNING**: There are newer STM32F4xx boards also called "black pill". These newer boards are currently not tested. This part
refers to older STM32F103C8T6 black pill boards.

The problem with black pill designs is that the onboard LED is wired on PB12 instead of PC13, messing with data signals.

You will have to desolder the onboard LED (or its current-limiting resistor right under).

If you want an activity LED, put an external one with a 1k resistor in series on PC13.

Other boards were not tested and may require further adjustments.