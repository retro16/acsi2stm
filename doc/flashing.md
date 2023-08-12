Flashing the ACSI2STM firmware
==============================


Downloading the release package
-------------------------------

The latest binary release package is available on the
[GitHub release section](https://github.com/retro16/acsi2stm/releases)

Using precompiled binary packages removes the hassle of installing a full
Arduino environment.

There are many compile-time options, so if none of these variants match your
needs (or your tastes), see the [compiling](compiling.md) section.


Updating a 4.0 unit from the Atari ST
-------------------------------------

ACSI2STM supports firmware upload via the ACSI port since version 4.0.
It uses the Seagate SCSI standard command to do that.

Steps to update your firmware:

* Download the release package and unzip it.
* Choose which firmware variant you want to use (see below).
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
upload the new firmware using a serial dongle. See below.


Firmware variants in the release package
----------------------------------------

Newer ACSI2STM release packages have many variants to choose from:

### acsi2stm-XXXX.ino.bin

Standard firmware.

### acsi2stm-XXXX-strict.ino.bin

Reduced firmware with GemDrive permanently disabled, just like if you set BOOT1
to force ACSI mode. All SD cards behave like Atari hard drives.

Compile-time options:

    #define ACSI_STRICT 1

### acsi2stm-XXXX-debug.ino.bin

The standard firmware, with limited debug output. Debug output is on the USART
port of the STM32 (PA9) at 2Mbps.

Compile-time options:

    #define ACSI_DEBUG 1

### acsi2stm-XXXX-verbose.ino.bin

The standard firmware, with verbose debug output. Very slow.

Requires 128k of flash on the STM32.

Compile-time options:

    #define ACSI_DEBUG 1
    #define ACSI_VERBOSE 1

### acsi2stm-XXXX-strictverbose.ino.bin

Same as the strict variant, with verbose debug output. Requires only 64k of
flash on the STM32, unlike the full featured verbose variant.

Compile-time options:

    #define ACSI_STRICT 1
    #define ACSI_DEBUG 1
    #define ACSI_VERBOSE 1

### acsi2stm-XXXX-legacy.ino.bin

Same as standard firmware, but for older 2.x units that don't have the necessary
hardware modifications (reset line and read-only switch).

Compile-time options:

    #define ACSI_HAS_RESET 0
    #define ACSI_SD_WRITE_LOCK 0


## Which variant should I choose ?

Most users should use the standard firmware.

If you want to use it as an ACSI drive only, you may prefer the strict variant.

If you are building a unit, you may be interested in the debug firmware to
diagnose potential issues with your hardware.

If you found a bug or a strange behavior and wish to do a bug report, verbose
output may be requested: in that case, use the verbose firmware.

If you know you have an old unit without a reset line, use the "legacy" variant.

If your SD card is stuck in read-only mode, you need to do hardware
modifications. If you cannot do that (or don't want to), use the legacy variant.


Flashing the firmware via serial port
-------------------------------------

If you want to flash using Arduino, it's simpler to just install everything and
compile your own variant. See [compiling](compiling.md) for more details.

The only supported way to program the STM32 is via its serial (USART) port.

To connect to the STM32, you need a 3.3V compatible USB-USART dongle such as
this one:

![USB USART module](images/usb_serial.jpg)

### Flashing the blue pill

Set the USB dongle to 3.3V if you have a jumper for that. Connect TX to PA10, RX
to PA9 and the GND pins together.

On the Blue Pill itself, set the BOOT0 jumper to 1 to enable the serial flash
bootloader:

     _______________________________
    |                     _         |
    |    o [==]       /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|

### Flashing the compact PCB

If you have the recommended USB USART adapter, it should plug right away in the
*UART* port. The adapter will power the board and enable flash mode right away
so you just have to plug it in and start flashing.

If you have a different adapter, put a jumper on the FLASH pins, then connect TX
to RX, RX to TX and GND together. Power the board through USB-C.

### Flashing using STM32CubeProg

Download [STM32CubeProg from st.com](https://www.st.com/en/development-tools/stm32cubeprog.html)

Install STM32CubeProg on your system and start it.

![Screenshot of STM32CubeProg](images/stm32cube-1.png)

On the main window, select *UART* in the programmer type, then select the serial
port matching your UART adapter, then click *Connect*.

Click the *Open file* tab and select the firmware file to upload.

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

Once the chip is programmed, switch the BOOT0 jumper back to 0, then reset the
STM32 (press the button or do a power cycle).


Firmware/hardware compatibility matrix
--------------------------------------

Since the ACSI2STM project now has a rather long history with breaking changes,
it can be difficult to keep track of what is compatible with what.

Here is a compatibility matrix that shows firmware revisions and their hardware
compatibility:

|                      Hardware board | 1.x | 2.x | 3.x | 4.x | 4.x legacy |
|------------------------------------:|:---:|:---:|:---:|:---:|:----------:|
|         Custom board built for v1.0 | ✓   | 🛇   | 🛇   | 🛇   | 🛇          |
|         Custom board built for v2.0 | 🛇   | ✓   | 🛇   | 🛇   | ✓          |
|         Custom board built for v3.0 | 🛇   | 🛇   | ✓   | ✓   | ✓          |
|         Custom board built for v4.0 | 🛇   | 🛇   | ✓   | ✓   | ✓          |
|     Official full featured PCB v1.0 | 🛇   | 🛇   | ✓   | ✓   | ✓          |
|     Official full featured PCB v1.1 | 🛇   | 🛇   | ✓   | ✓   | ✓          |
|        Official SOVAJA Mega STE PCB | 🛇   | 🛇   | ✓   | ✓   | ✓          |
|  Official ACSI2STM compact PCB v1.0 | 🛇   | 🛇   | ✓   | ✓   | ✓          |

**Note:** Hardware can be upgraded by making changes. See [hardware.md](hardware.md).

