Quick start guide
=================

This document explains the steps to get the recommended hardware and software
as quickly and as simply as possible.

There are many possible variations, refer to other documents for more details.

**Warning:** The ACSI2STM authors do not give any warranty on the final product.
Your money goes directly to JLCPCB, these are **not** affiliate links.
ACSI2STM authors do not receive any compensation, directly or indirectly, and
are thus not required to provide support.

JLCPCB is cited purely as a convenience. They provide reliable STM32 chips,
which is the most important problem to solve. You are free to choose any other
service provider for PCB assembly.


Downloading necessary files
---------------------------

Download the latest release package. It contains all PCB design files as well as
the firmware.

The latest binary release package is available on the
[GitHub release section](https://github.com/retro16/acsi2stm/releases)


How to order the pre-assembled compact PCB
------------------------------------------

You can order pre-assembled PCBs, ready to use.

* You will need files in the `pcb/Compact` folder of the release package.
* Create an account on [JLCPCB](https://jlcpcb.com) if you don't have any.
* Log in to your JLCPCB account.
* Open the [JLCPCB ordering page](https://cart.jlcpcb.com/quote).
* Click *Add gerber file* and select `Gerber - ACSI2STM Compact.zip`.
* Check that dimensions are 51.31*64.26 mm
* Change the following settings:
  * *PCB Color*: choose the one you like. Some colors require to build 5 units
    instead of 2, which is more expensive. Choose green if unsure.
  * *Remove order number*: *Specify a location*.
  * Enable *PCB assembly*
  * Select *Assemble top side*
  * *Tooling holes*: select *Added by Customer*
  * *PCBA Qty*: select 5 if you want 5 assembled units, or 2 if you want only
    2 full units and 3 extra unpopulated PCBs. 2 is cheaper than 5, but not by
    a lot.
* In the *Bill of materials* window,
  * Click *Add BOM file* and select `BOM - ACSI2STM Compact.csv`.
  * Click *Add CPL file* and select `PickAndPlace - ACSI2STM Compact.csv`.
* In the next window, the whole BOM is summed up.
  * You should see *17 parts confirmed* above the table.
  * If some parts are missing, make sure to check the *Basic Parts Only* check
    box when searching for a substitute. Basic parts are much cheaper than
    extended parts. The only extended parts are the SD slots, USB port and
    battery holder.
  * Check that the *Total Cost* column has no value more than $2 except the
    STM32 chip that should be below $7. This is for 5 assembled units.
* Make a visual check of component placement. It should match the picture in the
  file `3D view - ACSI2STM Compact.png`.
* In the *Quote & Order* window, you need to select *Product Description*. I use
  the Research/DIY option, but feel free to choose the option that you feel the
  best for you.

### Manually soldered parts

A few optional connectors are on the bottom side of the PCB and are not
assembled by JLCPCB by default:

* Configuration jumpers (RESET, ID_SHIFT, FLASH, ACSI)
* Serial/UART pins
* The Satan/UltraSatan IDC20 connector

All these parts can be built using the same 2.54mm male square pins. It's better
to use a real IDC20 connector though.


Flashing firmware
-----------------

JLCPCB does not offer pre-programming services for the STM32. You have to flash
the firmware using a USB to serial/UART adapter supporting 3.3V signals.

Firmware upgrades can be done from the Atari itself, so the USB adapter is only
needed for first time programming or for debugging/development purposes.

### USB programmer

The compact PCB has to be programmed with a USB to UART adapter. It requires an
adapter with a very specific pinout. Using any other model will require manual
wiring but should work without problems.

The required model usually matches the following keywords on most websites:

* H43 USB to TTL UART CH340
* HW-597 USB to TTL UART CH340

Pinout of the adapter:

* 5V
* VCC (connected to 3.3V or 5V by a jumper)
* 3.3V
* TXD
* RXD
* GND

![USB to UART module](images/usb_serial.jpg)

**Hint:** With a bit of practice, it is possible to program the unit without
soldering a female header. Just insert the adapter's pins inside matching PCB
holes and hold it slightly slanted with a bit of force to keep good contacts
during the flashing operation. PCB holes are metal plated so it should provide
good enough contact.

![Flashing without header](images/compact_pcb_flash.jpg)

**Note:** when using this kind of adapter, you don't need to enable the FLASH
jumper. The PCB is wired to enable flash mode when it senses power on the 5V
pin.

If you don't have that very specific model of adapter, plug as following:

* Make sure your adapter works with 3.3V signals. 5V signals may damage the
  STM32.
* Plug GND to the GND pin of your adapter.
* Plug TX to RX of your adapter, RX to TX of your adapter.
* Enable (short) the FLASH jumper or put 5V on the 5V pin of the UART header.
* Put a 3.3V source on any of the 3.3V pins of the UART header.
* As soon as power is applied, the STM32 is ready to receive its firmware.

### Flashing using STM32CubeProg

Download [STM32CubeProg from st.com](https://www.st.com/en/development-tools/stm32cubeprog.html)

Install STM32CubeProg on your system and start it.

![Screenshot of STM32CubeProg](images/stm32cube-1.png)

On the main window, select *UART* in the programmer type, then select the serial
port matching your UART adapter, then click *Connect*.

Click the *Open file* tab and select the `acsi2stm-XXX.ino.bin` file from the
release package.

![Last STM32CubeProg step](images/stm32cube-2.png)

To program the chip, click the *Download* button.

### Flashing using the stm32flash command-line

You need the `stm32flash` command-line tool available on the
[Arduino_STM32](https://github.com/rogerclarkmelbourne/Arduino_STM32/tree/master/tools)
repository, in the tools subdirectory.

Sample stm32flash command-line:

    stm32flash -w acsi2stm-XXXX.ino.bin /dev/ttyUSB0

You need to adapt the command-line for your setup: /dev/ttyUSB0 should point at
the virtual serial port connected to the STM32. On Windows and MacOS, it may use
slightly different syntax for the port.


Installing the PCB
------------------

### Backup battery

Before installing, insert a CR2032 battery in the socket. The battery is only
needed for keeping the clock running when the ST is off.

### Installing on the DB19 port

* Plug the unit on the back of the ST, components toward the keyboard.
  The mounting holes of the Hard Disk socket should be aligned.
* Put some screws to hold the unit in place.
  If you need screws, you can unscrew the hex screws of the Modem or Printer
  socket.
* Optionally, you can plug other devices such as an UltraSatan on the IDC20
  socket.

![Compact PCB on DB19 port](images/compact_installed.jpg)

### Installing using the UltraSatan (IDC20) port

If you mounted an IDC20 socket, you can connect the ACSI2STM unit through it
instead of the DB19 port. This is useful if you have other IDC20 devices.

![Compact PCB on IDC20 port](images/compact_idc20.jpg)

You can connect things on both the DB19 and IDC20 ports at the same time.


Using the unit
--------------

Power the unit via its USB-C port. It has no specific power requirements, so any
5V USB-C adapter (or PC) should be able to power the unit.

Insert any microSD card in its slots. The SD card can be formatted as FAT32
(SDHC) or ExFAT (SDXC), which are the standard formats for the SD card.

Turn the ST on, the ACSI2STM unit should display a boot message and the C drive
should be readily available on the desktop.

You need to manually install extra drive icons on the desktop to access the D or
E drive. See [tutorial](tutorial.md) for more detailed instructions.

**Note:** If you boot with no SD card inserted, the driver will still load and
mount the C drive. You can hot plug a SD card later on: It works just like a
floppy drive.


Setting date and time
---------------------

In GemDrive mode, you can use any tool to set the date, such as `CONTROL.ACC` or
`XCONTROL.ACC`. GemDrive redirects all system calls to the STM32 so the internal
clock isn't used anymore.

In ACSI mode, ACSI2STM emulates an UltraSatan clock, so you can use UltraSatan
tools such as `US_SETCL.PRG` and `US_GETCL.PRG`. GemDrive mode also responds to
UltraSatan clock queries as a convenience.

When the system is switched off, the STM32 clock is powered by the onboard
CR2032 battery so it will keep time even when powered off.


Updating a 4.0 (or later) unit from the Atari ST
------------------------------------------------

ACSI2STM supports updating the firmware from the ST itself since version 4.0.
It uses the Seagate SCSI standard command to do that, this is supported by
ACSI2STM both in ACSI and GemDrive modes.

Steps to update your firmware:

* Download the release package and unzip it.
* Choose which firmware variant you want to use (see [firmware](firmware.md)).
* Copy the firmware file (`acsi2stm-VERSION-VARIANT.ino.bin`) and rename it to
  `HDDFLASH.BIN`
* Copy `HDDFLASH.TOS` and `HDDFLASH.BIN` files on any medium readable by the
  ST (floppy, ACSI drive, GemDrive SD card, ...).
* On the ST, run `HDDFLASH.TOS`.
* When prompted, choose the hard drive to update (usually ID 0).
* Press Y to start flashing.
* When finished, the ST and the ACSI2STM unit will both restart.

**Note:** when updating an ACSI2STM unit with multiple SD slots, you can select
any slot to update the firmware for the whole unit. No need to do the update
procedure multiple times.

**Note:** `HDDFLASH.TOS` works entirely in RAM, so you can start the program
from the unit to update.

**Note:** If you load GemDrive using `GEMDRIVE.TOS`, upgrade this file as well.
An old version of `GEMDRIVE.TOS` may not be compatible with the newer firmware.

**Warning:** If flashing fails or if the unit is bricked, you will have to
upload the new firmware using the USB to UART dongle. See above.

**Warning:** The PIO firmware variant does not support ACSI commands at all, so
it is incompatible with `HDDFLASH.TOS`. You will need USB to UART to update.
