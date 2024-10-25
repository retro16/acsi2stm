Creating your own ACSI2STM hardware
===================================

This page helps hardware designers to design new hardware from scratch. If you
simply want a pre-built unit, see [quick_start](quick_start.md).

**Warning:** Building a unit based on Blue Pill is now heavily discouraged. Too
many clones or bad quality units are being sold, and even though they may work
for many projects, ACSI2STM uses many very advanced and even undocumented
features, so it really requires 100% working original hardware.

The pre-built compact PCB avoids most compatibility pitfalls by using a reliable
supplier.

If you want to sell units based on this project, please consider selling the
compact PCB, and contribute to this project instead of creating your own
hardware.


Hardware needed
---------------

* A STM32F103C8T6 or STM32F103CBT6 development board.
* A USB-serial dongle for programming the STM32 chip, with a 3.3V USART.
* One or more SD card port(s) for your STM32. You can also solder wires on a SD
  to microSD adapter.
* One or more SD card(s).
* A male DB19 port (you can modify a DB25 port to fit) or an IDC20 to connect to
  a SATAN-compatible port.
* One 10k-100k resistor if you need SD card hotplug capabilities or if you
  have multiple SD card slots.
* One 100nF decoupling capacitor for the SD card (optional but recommended).
* Do *NOT* connect USB data lines on the STM32. Use the +5V or +3.3V pin to
  power it if you are unsure. To power from USB, you need to modify the blue
  pill itself (see below).

**Note:** If you build this project, please seriously think about putting
multiple SD card slots. It quickly becomes a must have in many situations.


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
* Reset is not strictly needed, but heavily recommended.
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

* If you need to hot swap your SD card, or if you want multiple SD slots, you
  need to put a 10k-100k pull-up resistor between +3.3V and PA6. A single
  resistor is enough if you have multiple SD card slots.
* The ACSI2STM module **will** respond to all ACSI IDs, whether a SD card is
  inserted or not. Change ACSI_SD_CARDS and ACSI_FIRST_ID in
  `acsi2stm.h` to change ACSI IDs, or see the table below to disable IDs by
  connecting pins to +3.3V.
* The SD card had 2 GND pins. Connecting only one is enough.
* You should put decoupling capacitors of about 100nF between VDD and VSS, as
  close as possible from the SD card pins. If you use a pre-built SD slot
  module it should be properly decoupled already.
* Some microSD slot boards for Arduino have logic level adapters to allow using
  SD cards on 5V Arduino boards. This will reduce speed and compatibility.
  Connect SD card pins directly to the STM32 pins for best results.
* microSD to SD adapters are a quick, cheap way to obtain a microSD reader.
  Simply solder on the SD adapter pads. They aren't very reliable though.

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
define in `acsi2stm.h`.

When the pin is connected to +3.3V, the SD card is completely disabled (the ACSI
ID is freed for other devices).


Battery-powered real-time clock
-------------------------------

To use the RTC feature, you need to connect a lithium battery to the VB pin of
the STM32. Using a CR2032 with a standard battery holder is recommended.


Changing operation modes with jumpers on the Compact board
----------------------------------------------------------

**Note:** Some jumpers can also be permanently set by small solder blobs on the
PCB.

### Serial interface

The serial interface (STM32 PA9/PA10) is available on the PCB as a small 3-pin
interface. This can be used for programming the unit or debug output.

### RESET

The RESET pins will reset the STM32 when shorted, just like the push button on
the Blue Pill.

### ID_SHIFT

The ID_SHIFT pins will change ACSI IDs of the ACSI2STM unit. Refer to the
template on the board to get jumper positions. With no jumper SD cards will have
ACSI ids 0 to 2, and putting the jumper in different positions can shift IDs to
1-3, 2-4 or 3-5.

### FLASH

Put a jumper to enable flashing firmware. This is equivalent to the BOOT0 (top)
jumper of a Blue Pill.

Remove the jumper for normal operation.

### ACSI

Put a jumper to enable ACSI strict mode. GemDrive will be disabled and all 3 SD
cards will behave like Atari hard disks. See [manual](manual.md) for more
information about strict mode.

### SATAN PORT

This can be populated with an IDC20 socket.

This connector is compatible with Satan/UltraSatan cables.

The connector can be used in both directions: either to connect to the ST or to
connect additional devices.

**NOTE:** You can use female headers with long pins to make a stackable unit.
The female part must be on the inner side (backup battery side).
In that case, you won't be able to plug the unit on the DB19 socket anymore.


Changing operation modes with jumpers on the Blue Pill board
------------------------------------------------------------

The STM32 blue pill has 2 jumpers. You can access to different operation modes
just by switching these jumpers to different places.

**WARNING:** Do not attempt any other combination than what is explained here.
You might damage your product.

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
    |    o o o        /\ | |       -||¨| <- Jumper here
    |   [==] o       /  \| |       -||_|
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 2 to 6, GemDrive enabled

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |   [==] o       /  \| |       -||¨| <- Jumper here
    |                \  /| |       -||_|
    |     (o)         \/ |_|       -|--
    |_______________________________|


ACSI id 3 to 7, GemDrive enabled

     _______________________________
    |                     _         |
    |    o o o        /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -||¨| <- Jumper here
    |     (o)         \/ |_|       -||_|
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
    |                \  /| |       -||¨| <- Jumper here
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



Required changes for older ACSI2STM hardware
============================================

If you have a unit built for 1.x or 2.x firmware, you need to make changes.


Changes required for 2.x units
------------------------------

If you don't want to or can't make these changes, you can use the *legacy*
firmware variant. See [compiling](compiling.md).

### Add a reset line

You need to connect the ACSI pin 12 (RST) to PA15. It is optional, but stability
will be greatly improved by doing that.

### Fix SD cards appearing read-only

Solder PB0, PB1, PB3, PB4 and/or PB5 to GND to make SD cards permanently
read-write. See the table mentioning these pins above for more details.

### Hide non-existing slots

Solder PB0, PB1, PB3, PB4 and/or PB5 to +3.3V to disable the corresponding
slots. See the table mentioning these pins above for more details.


Changes required for 1.x units
------------------------------

 * Do all changes required for 2.x units
 * Swap PA8 and PA12
